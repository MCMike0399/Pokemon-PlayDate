-- Pure translation of Blue's slot state machine and original reel words.
-- GameSession owns its transient value, RNG continuation and actual coin commits.
CeladonSlots = {}
local CAN_WIN <const> = 0x40
local SEVEN_BAR <const> = 0x80
local reelData
local rewards <const> = {SLOTS7=300,SLOTSBAR=100,SLOTSCHERRY=8,SLOTSFISH=15,SLOTSBIRD=15,SLOTSMOUSE=15}
local function copy(value)
    return GameSession._copy(value)
end
local function sevenOrBar(symbol)
    return symbol == "SLOTS7" or symbol == "SLOTSBAR"
end
local function hasFlag(state, flag)
    return state.flags & flag ~= 0
end
function CeladonSlots.luckyIndex(byte)
    assert(Party._integer(byte,0,255), "source lucky-slot byte required")
    return (byte < 7 and 8 or byte) >> 3
end
function CeladonSlots.open(machine, lucky)
    assert(Party._integer(machine,1,36) and Party._integer(lucky,0,31), "source slot identity required")
    return {phase="bet",machine=machine,chance=machine == lucky and 250 or 253,
        offsets={0,0,0},slips={4,4},flags=0,allow=0,rerolls=0,stopping=0,
        initial=0,clock=0,bet=0,payout=0}
end
local function setFlags(state, rng)
    if hasFlag(state,SEVEN_BAR) then return end
    if state.allow ~= 0 then
        state.flags = state.flags | CAN_WIN
        return
    end
    local byte = rng:random(0,255)
    if byte == 0 then
        state.allow = 60
    elseif byte > state.chance then
        state.flags = state.flags | SEVEN_BAR
    elseif byte > 210 then
        state.flags = state.flags | CAN_WIN
    else
        state.flags = 0
    end
end
function CeladonSlots.bet(before, bet, rng)
    assert(before.phase == "bet" and Party._integer(bet,1,3), "source slot bet phase required")
    local state = copy(before)
    state.bet, state.payout, state.winner = bet, 0, nil
    -- The third consecutive RAM byte is RerollCounter, not wheel3 slip.
    state.slips, state.rerolls = {4,4}, 4
    state.stopping, state.initial, state.clock = 0, 0, 0
    setFlags(state,rng)
    state.phase = "starting"
    return state
end
function CeladonSlots.start(before)
    assert(before.phase == "starting", "source StartSlotMachineText boundary required")
    local state = copy(before)
    state.phase = "initial"
    return state
end
local function animate(state, wheel)
    state.offsets[wheel] = (state.offsets[wheel] + 1) % 30
end
function CeladonSlots.rows(state, wheel)
    if not reelData then reelData = CeladonServiceData.policy().wheels end
    local reel = reelData[wheel]
    local first = state.offsets[wheel] // 2 + 1
    return {reel[first],reel[first+1],reel[first+2]}
end
local function pairMatch(state)
    local a,b = CeladonSlots.rows(state,1), CeladonSlots.rows(state,2)
    for _, pair in ipairs({{1,1},{1,2},{2,2},{3,2},{3,3}}) do
        if a[pair[1]] == b[pair[2]] then return true,b[pair[2]] end
    end
    return false,b[1]
end
local function spinStep(state, pressed)
    if pressed then
        local previous = state.stopping
        if previous == 0 or previous < 3 and state.slips[previous] == 0 then
            state.stopping = math.min(3, previous + 1)
        end
    end
    for wheel = 1,2 do
        if state.stopping >= wheel and state.offsets[wheel] % 2 == 1 then
            if state.slips[wheel] > 0 then
                state.slips[wheel] = state.slips[wheel] - 1
                local stop = false
                if wheel == 1 then
                    -- The original 7/bar branch compares HIGH(symbol)<2,
                    -- which never succeeds. Preserve that source bug.
                    stop = not hasFlag(state,SEVEN_BAR) and CeladonSlots.rows(state,1)[2] ~= "SLOTSCHERRY"
                else
                    local matched, symbol = pairMatch(state)
                    stop = hasFlag(state,SEVEN_BAR) and sevenOrBar(symbol)
                        or not hasFlag(state,SEVEN_BAR) and matched
                end
                if stop then state.slips[wheel] = 0 else animate(state,wheel) end
            end
        else
            animate(state,wheel)
        end
    end
    if state.stopping >= 3 and state.offsets[3] % 2 == 1 then
        state.phase = "checking"
    else
        animate(state,3)
    end
end
function CeladonSlots.match(state)
    local a,b,c = CeladonSlots.rows(state,1),CeladonSlots.rows(state,2),CeladonSlots.rows(state,3)
    local lines = {}
    if state.bet == 3 then lines = {{1,2,3},{3,2,1}} end
    if state.bet >= 2 then
        lines[#lines+1], lines[#lines+2] = {3,3,3}, {1,1,1}
    end
    lines[#lines+1] = {2,2,2}
    for _, line in ipairs(lines) do
        if a[line[1]] == b[line[2]] and a[line[1]] == c[line[3]] then
            return a[line[1]]
        end
    end
end
local function check(state, rng)
    local symbol = CeladonSlots.match(state)
    local enabled = hasFlag(state,CAN_WIN) or hasFlag(state,SEVEN_BAR)
    if not symbol then
        if enabled then
            state.rerolls = (state.rerolls - 1) & 0xff
            if state.rerolls ~= 0 then
                animate(state,3)
                animate(state,3)
                return
            end
        end
        state.phase, state.payout = "result", 0
        return
    end
    if not enabled or not hasFlag(state,SEVEN_BAR) and sevenOrBar(symbol) then
        animate(state,3)
        animate(state,3)
        return
    end
    state.winner, state.payout = symbol, assert(rewards[symbol])
    if symbol == "SLOTS7" then
        if rng:random(0,255) >= 128 then state.flags = 0 end
        state.allow = 0
    elseif symbol == "SLOTSBAR" then
        state.flags = 0
    elseif state.allow ~= 0 then
        state.allow = state.allow - 1
    end
    state.phase = "result"
end
-- One native 30 Hz update represents two Game Boy frames. Initial animation is
-- 20 iterations at two GB frames; steady input/animation uses three GB frames.
-- Source rerolls animate two half-symbol steps with two DelayFrame calls.
function CeladonSlots.tick(before, pressed, rng)
    assert(type(pressed) == "boolean", "explicit slot A edge required")
    assert(before.phase == "initial" or before.phase == "spinning" or before.phase == "checking",
        "source slot tick phase required")
    local state = copy(before)
    state.clock = state.clock + 2
    local pending = pressed
    while true do
        if state.phase == "initial" then
            if state.clock < 2 then break end
            state.clock = state.clock - 2
            for wheel = 1,3 do animate(state,wheel) end
            state.initial = state.initial + 1
            if state.initial == 20 then state.phase = "spinning" end
            pending = false
        elseif state.phase == "spinning" then
            if state.clock < 3 then
                state.pendingA = state.pendingA or pending
                break
            end
            state.clock = state.clock - 3
            spinStep(state, pending or state.pendingA == true)
            pending, state.pendingA = false, false
        elseif state.phase == "checking" then
            if state.clock < 2 then break end
            state.clock = state.clock - 2
            check(state,rng)
        else
            break
        end
    end
    return state
end
function CeladonSlots.again(before)
    assert(before.phase == "result", "completed source slot round required")
    local state = copy(before)
    state.phase = "bet"
    return state
end

function CeladonSlots.previousSymbol(state, wheel)
    if not reelData then reelData = CeladonServiceData.policy().wheels end
    local index = state.offsets[wheel] // 2
    return reelData[wheel][index == 0 and 15 or index]
end
