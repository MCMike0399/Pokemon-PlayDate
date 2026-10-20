import "domain/decimalInteger"

-- Protocol v1. One request at a time; every outcome belongs to one build/session/id.
Harness = { beforeFrame = function() end, afterFrame = function() end, isQuiescent = false }
if not playdate.isSimulator or not HarnessBuild.enabled then return end

local config = HarnessBuild
local tick, request, commands, index, started, complete, failure = 0, nil, nil, 1, 0, false, nil
local entries, seen = {}, {}
local transitions = {}
local watched = setmetatable({}, { __mode = "k" })
local function watch(machine, scope)
    if not machine or watched[machine] then return end
    watched[machine] = true
    machine:on("changed", function(kind, from, to)
        transitions[#transitions + 1] = { tick = tick, scope = scope, kind = kind, from = from, to = to,
            time_ms = playdate.getCurrentTimeMilliseconds() }
    end)
end
local function watchMachines(game)
    watch(game.machine, "root")
    watch(game.machine:get("overworld").sub, "overworld")
    local battle = game.machine:get("battle").battle
    if battle then watch(battle.machine, "battle") end
end
local function envelope(value)
    value.protocol = config.protocol
    value.build_id = config.build_id
    value.session_id = config.session_id
    value.tick = tick
    value.time_ms = playdate.getCurrentTimeMilliseconds()
    return value
end
local function publish(path, value)
    local temporary = path .. ".tmp"
    local file = assert(playdate.file.open(temporary, playdate.file.kFileWrite))
    file:write(json.encode(envelope(value)))
    file:close()
    assert(playdate.file.rename(temporary, path))
end
-- Protocol-v1 value extension; never changes the process-global JSON codec.
local INTEGER_TAG <const> = "__harness_int32_v1"
local INTEGER_PREFIX <const> = "__harness_int32"
local EXACT_SMALL_LIMIT <const> = 16777216
local function wireAssert(condition, message)
    assert(condition, "integer-wire: " .. message)
end

-- Only inspect string keys/container boundaries. SDK JSON remains responsible
-- for parsing all values. Raw shape checks retain fields its null handling may
-- otherwise erase, and detect duplicate reserved fields before any actions.
local function reservedShapes(wire)
    local stack, count, i = {}, 0, 1
    while i <= #wire do
        local character = wire:sub(i, i)
        if character == "{" or character == "[" then
            stack[#stack + 1] = { object = character == "{", keys = 0, reserved = 0 }
        elseif character == "}" or character == "]" then
            local current = table.remove(stack)
            wireAssert(current ~= nil, "unbalanced wire containers")
            if current.reserved > 0 then
                wireAssert(current.object and current.reserved == 1 and current.keys == 1, "reserved tag must be a singleton object")
                count = count + 1
            end
        elseif character == '"' then
            local start, closed = i, false
            i = i + 1
            while i <= #wire do
                local nextCharacter = wire:sub(i, i)
                if nextCharacter == "\\" then i = i + 2
                elseif nextCharacter == '"' then closed = true; break
                else i = i + 1 end
            end
            wireAssert(closed, "unterminated wire string")
            local look = i + 1
            while look <= #wire and wire:sub(look, look):match("%s") do look = look + 1 end
            if wire:sub(look, look) == ":" then
                local current = stack[#stack]
                wireAssert(current and current.object, "wire key outside an object")
                current.keys = current.keys + 1
                local holder = json.decode('{"key":' .. wire:sub(start, i) .. '}')
                local key = holder.key
                if type(key) == "string" and key:sub(1, #INTEGER_PREFIX) == INTEGER_PREFIX then
                    wireAssert(key == INTEGER_TAG, "unknown reserved tag version")
                    current.reserved = current.reserved + 1
                end
            end
        end
        i = i + 1
    end
    wireAssert(#stack == 0, "unbalanced wire containers")
    return count
end
local function decodeIntegerValues(value)
    local kind = type(value)
    if kind == "number" then
        wireAssert(value == value and value > -math.huge and value < math.huge, "nonfinite numeric scalar")
        wireAssert(value > -EXACT_SMALL_LIMIT and value < EXACT_SMALL_LIMIT, "untagged numeric scalar at float32 precision boundary")
        return value, 0
    end
    if kind ~= "table" then return value, 0 end
    local reserved, fields = nil, 0
    for key in pairs(value) do
        fields = fields + 1
        if type(key) == "string" and key:sub(1, #INTEGER_PREFIX) == INTEGER_PREFIX then
            wireAssert(key == INTEGER_TAG and reserved == nil, "unknown or duplicate reserved tag")
            reserved = key
        end
    end
    if reserved then
        wireAssert(fields == 1, "reserved tag must be a singleton object")
        local decoded, problem = DecimalInteger.decode(value[reserved])
        wireAssert(decoded ~= nil and math.type(decoded) == "integer", "invalid signed-int32 tag: " .. tostring(problem))
        return decoded, 1
    end
    local result, count = {}, 0
    for key, item in pairs(value) do
        local decoded, found = decodeIntegerValues(item)
        result[key], count = decoded, count + found
    end
    return result, count
end
local function decodeIntegerWire(value, wire)
    local expected = reservedShapes(wire)
    local decoded, actual = decodeIntegerValues(value)
    wireAssert(actual == expected, "reserved tag was erased or malformed during SDK decoding")
    return decoded
end
local function seedInteger(value)
    if type(value) == "string" then
        local decoded, problem = DecimalInteger.decode(value)
        assert(decoded ~= nil, "invalid seed integer text: " .. tostring(problem))
        return decoded
    end
    assert(type(value) == "number", "seed requires an integer")
    -- Small JSON numbers have no integer/float subtype on the wire. Accept only
    -- a provably exact integral value; Python rejects float seed inputs before
    -- publication. The recursive decoder already refused the unsafe boundary.
    local normalized = math.tointeger(value)
    assert(normalized ~= nil and normalized >= DecimalInteger.MIN and normalized <= DecimalInteger.MAX, "seed requires a native signed-int32 integer")
    return normalized
end

local function read(path)
    if not playdate.file.exists(path) then return nil end
    local file = playdate.file.open(path, playdate.file.kFileRead)
    if not file then return { malformed = true } end
    local wire = file:read(playdate.file.getSize(path))
    file:close()
    local ok, value = pcall(json.decode, wire)
    playdate.file.delete(path)
    if not ok or type(value) ~= "table" then return { malformed = true } end
    return value, wire
end

local function identity(value)
    return value.protocol == config.protocol and value.build_id == config.build_id and value.session_id == config.session_id
end
local function safeName(value)
    return type(value) == "string" and value:match("^[%w_-]+$") ~= nil and #value < 100
end
local function integer(value, low, high)
    return tonumber(value) and tonumber(value) % 1 == 0 and tonumber(value) >= low and tonumber(value) <= high
end
local dirs = { up = true, down = true, left = true, right = true }
local buttons = { a = true, b = true, up = true, down = true, left = true, right = true }
local statuses = { none = true, burn = true, poison = true, paralyze = true, sleep = true, freeze = true }
local function adjustedBattler(mon, values, side)
    local hp = values[side .. "_hp"]
    assert(hp == nil or (integer(hp,1,mon.maxHP)), "fixture HP exceeds maxHP")
    local pp = values[side .. "_pp"] or {}
    for key, amount in pairs(pp) do
        assert(mon:hasMove(key) and integer(amount,0,moveData[key].maxPP), "invalid known-move PP adjustment")
    end
    local requested = values[side .. "_status"]
    local status = requested == "none" and nil or requested or mon.status
    if requested == "none" then status = nil end
    local turns, duration = mon.statusTurns, mon.sleepDuration
    if requested then turns, duration = 0, 0 end
    if values[side .. "_status_turns"] ~= nil then turns = values[side .. "_status_turns"] end
    if values[side .. "_sleep_duration"] ~= nil then duration = values[side .. "_sleep_duration"]
    elseif requested == "sleep" then duration = turns end
    if status == "sleep" then
        assert(integer(duration,1,3) and integer(turns,0,duration), "sleep adjustment needs a valid original duration")
    else
        assert(turns == 0 and duration == 0, "non-sleep adjustment must clear both counters")
    end
    return {hp=hp or mon.hp,pp=pp,status=status,statusTurns=turns,sleepDuration=duration}
end
local function normalize(value)
    if type(value) == "string" then
        local parts = {}
        for part in value:gmatch("%S+") do parts[#parts + 1] = part end
        value = { op = parts[1], args = {} }
        for i = 2, #parts do value.args[#value.args + 1] = parts[i] end
    end
    assert(type(value) == "table" and type(value.op) == "string", "command object/op required")
    local op, args = value.op, value.args or {}
    assert(type(args) == "table", "args must be an array")
    local valid = false
    if op == "assert" or op == "await" then
        valid = type(value.path) == "string" and value.equals ~= nil
        if value.frames ~= nil then valid = valid and integer(value.frames, 1, 18000) end
    elseif op == "fixture" then
        local options = value.options or {}
        assert(type(options) == "table", "fixture options required")
        if options.seed ~= nil then
            assert(type(options.seed) == "number", "fixture seed requires an integer number")
            options.seed = seedInteger(options.seed)
        end
        assert(options.zone == nil or zoneRegistry[options.zone], "unknown fixture zone")
        assert(options.intro == nil or options.intro == "skip" or options.intro == "reset", "invalid fixture intro")
        if options.player_pokemon then
            local mon = options.player_pokemon
            assert(type(mon) == "table" and pokemonData[mon.species]
                and type(mon.level) == "number" and integer(mon.level, 1, 100), "invalid player Pokemon fixture")
        end
        if options.grant_xp then
            local xp = options.grant_xp
            assert(type(xp) == "table" and ((xp.amount == nil) ~= (xp.to_level == nil)),
                "XP fixture requires exactly one of amount/to_level")
            assert(xp.amount == nil or (type(xp.amount) == "number" and integer(xp.amount, 0, 1000000)), "invalid XP amount")
            assert(xp.to_level == nil or (type(xp.to_level) == "number" and integer(xp.to_level, 1, 100)), "invalid XP target level")
        end
        if options.adjust_battle then
            for key in pairs(options) do assert(key == "adjust_battle", "battle adjustment cannot also reset session fields") end
            assert(type(options.adjust_battle) == "table", "battle adjustment object required")
            local hp = options.adjust_battle
            for key in pairs(hp) do
                local side, field = tostring(key):match("^(%a+)_(.+)$")
                assert((side == "player" or side == "enemy")
                    and (field == "hp" or field == "pp" or field == "status" or field == "status_turns" or field == "sleep_duration"),
                    "unknown battle adjustment field")
            end
            assert(hp.player_hp == nil or (type(hp.player_hp) == "number" and integer(hp.player_hp, 1, 9999)), "invalid player fixture hp")
            assert(hp.enemy_hp == nil or (type(hp.enemy_hp) == "number" and integer(hp.enemy_hp, 1, 9999)), "invalid enemy fixture hp")
            for _, side in ipairs({"player", "enemy"}) do
                local pp, status, turns = hp[side .. "_pp"], hp[side .. "_status"], hp[side .. "_status_turns"]
                if pp ~= nil then
                    assert(type(pp) == "table", "PP fixture must be an object")
                    for key, amount in pairs(pp) do
                        assert(moveData[key] and type(amount) == "number" and integer(amount, 0, moveData[key].maxPP), "invalid fixture PP")
                    end
                end
                assert(status == nil or statuses[status], "invalid fixture status")
                assert(turns == nil or (type(turns) == "number" and integer(turns, 0, 3)), "invalid fixture status turns")
                assert(turns == nil or status == nil or status == "sleep" or turns == 0, "only sleep may have a positive counter")
                local duration = hp[side .. "_sleep_duration"]
                assert(duration == nil or (type(duration) == "number" and integer(duration,0,3)), "invalid original sleep duration")
            end
        end
        if options.entry ~= nil then
            assert(type(options.entry) == "table", "fixture entry object required")
            for key in pairs(options.entry) do assert(key == "x" or key == "y" or key == "facing", "unknown fixture entry field") end
            local zone = zoneRegistry[options.zone or "reds_house_2f"]
            assert(integer(options.entry.x, 0, zone.width - 1) and integer(options.entry.y, 0, zone.height - 1), "invalid fixture entry")
            assert(options.entry.facing == nil or dirs[options.entry.facing], "invalid fixture facing")
        end
        HarnessFixtures.validate(options)
        valid = true
    elseif op == "move" then valid = dirs[args[1]] and (#args == 1 or integer(args[2], 1, 1000))
    elseif op == "face" then valid = dirs[args[1]] and #args == 1
    elseif op == "press" or op == "hold" or op == "release" then valid = buttons[args[1]] and #args == 1
    elseif op == "mash" then valid = buttons[args[1]] and integer(args[2], 1, 1000) and (#args == 2 or integer(args[3], 1, 1000))
    elseif op == "wait" then valid = integer(args[1], 1, 18000) and #args == 1
    elseif op == "shot" or op == "dumpimg" then valid = safeName(args[1]) and #args == 1
    elseif op == "record" then valid = safeName(args[1]) and integer(args[2], 1, 18000) and #args == 2
    elseif op == "encounters" then valid = (args[1] == "on" or args[1] == "off") and #args == 1
    elseif op == "debug" then valid = (args[1] == "open" or args[1] == "close") and #args == 1
    elseif op == "intro" then valid = (args[1] == "skip" or args[1] == "reset" or args[1] == "status") and #args == 1
    elseif op == "seed" then
        assert(#args == 1, "seed requires exactly one argument")
        args[1] = assert(DecimalInteger.encode(seedInteger(args[1])))
        valid = true
    elseif op == "battle" then valid = pokemonData[args[1]] and integer(args[2], 1, 100) and #args == 2
    elseif op == "warp" then valid = integer(args[1], 0, 10000) and integer(args[2], 0, 10000) and #args == 2
    elseif op == "snapshot" or op == "gamestate" or op == "state" or op == "pokemon" or op == "dismiss" or op == "atlas" or op == "catalog" or op == "contracts" or op == "quiesce" then valid = #args == 0
    end
    assert(valid, "invalid command: " .. op)
    assert(value.expect == nil or value.expect == "blocked" or value.expect == "interrupted" or value.expect == "edge-door" or value.expect == "ok", "invalid expected outcome")
    value.parts = { op }
    for _, arg in ipairs(args) do value.parts[#value.parts + 1] = tostring(arg) end
    return value
end
local function finish(game, status, message)
    local interruptedSnapshot = HarnessDiagnostics.snapshot(game)
    if status ~= "ok" then
        HarnessCapture.write("failure")
    end
    Autopilot.resetControls()
    -- Cancellation/timeout are whole-session barriers: old movement, door
    -- transitions, battle coroutines and timers cannot leak into a new request.
    if status == "cancelled" or status == "timeout" then
        HarnessFixtures.reset(game, { seed = 0 })
    end
    publish("result.json", { id = request.id, status = status, error = message,
        results = entries, snapshot = HarnessDiagnostics.snapshot(game),
        interrupted_snapshot = (status == "cancelled" or status == "timeout") and interruptedSnapshot or nil,
        catalog = Autopilot.catalog, quiescent = Harness.isQuiescent,
        rng_data = RulesRNG.toData(),
        error_code = message and message:find("integer-wire:", 1, true) and "invalid-integer-wire" or nil })
    request, commands, complete, failure = nil, nil, false, nil
    Autopilot.catalog = nil
end
local function poll(game)
    local incoming, wire = read("request.json")
    if not incoming then return end
    if not identity(incoming) then
        publish("rejected.json", { id = incoming.id or "invalid", status = "rejected", error = "malformed or wrong protocol/build/session" })
        return
    end
    if request then
        publish("rejected.json", { id = incoming.id, status = "rejected", error = "runtime busy" })
        return
    end
    request, entries, index, started = incoming, {}, 1, tick
    local ok, problem = pcall(function()
        assert(safeName(incoming.id) and not seen[incoming.id], "invalid or duplicate request id")
        seen[incoming.id] = true
        incoming = decodeIntegerWire(incoming, wire)
        request = incoming
        assert(type(incoming.commands) == "table" and #incoming.commands > 0 and #incoming.commands <= 1000, "commands array required")
        assert(integer(incoming.max_frames, 1, 18000), "invalid max_frames")
        commands = {}
        for _, value in ipairs(incoming.commands) do commands[#commands + 1] = normalize(value) end
    end)
    if not ok then finish(game, "error", tostring(problem)) end
end

function Harness.beforeFrame(game)
    tick = tick + 1
    HarnessCapture.tick, HarnessCapture.phase = tick - 1, "previous-completed-frame"
    watchMachines(game)
    Autopilot.beginFrame()
    local cancel = read("cancel.json")
    if cancel and request and identity(cancel) and cancel.id == request.id then
        finish(game, "cancelled", "owner cancelled request")
    end
    poll(game)
    if not request then return end
    if tick - started >= request.max_frames then finish(game, "timeout", "request frame limit"); return end
    local command = commands[index]
    if not command then return end
    command.started = command.started or tick
    local ok, problem = pcall(function()
        if command.op == "assert" or command.op == "await" then
            local actual = HarnessDiagnostics.lookup(HarnessDiagnostics.snapshot(game), command.path)
            complete = actual == command.equals
            if not complete and (command.op == "assert" or tick - command.started >= (command.frames or 300)) then
                error("assertion " .. command.path .. " expected " .. tostring(command.equals) .. " got " .. tostring(actual))
            end
        elseif command.op == "fixture" then
            Autopilot.resetControls()
            local options = command.options or {}
            if options.adjust_battle then
                local battle = game.machine:get("battle").battle
                assert(game.machine:is("battle") and battle, "battle adjustment requires a live battle")
                local values = options.adjust_battle
                -- Prepare both actual battlers before applying any mutation.
                local prepared = {}
                for _, side in ipairs({"player", "enemy"}) do
                    prepared[side] = adjustedBattler(battle[side],values,side)
                end
                for _, side in ipairs({"player", "enemy"}) do
                    local mon, value = battle[side], prepared[side]
                    mon.hp, mon.status, mon.statusTurns, mon.sleepDuration = value.hp, value.status, value.statusTurns, value.sleepDuration
                    for key, amount in pairs(value.pp) do mon.pp[key] = amount end
                end
            else
                HarnessFixtures.reset(game, options)
            end
            complete = true
        elseif command.op == "quiesce" then
            assert(index == #commands and not Autopilot.isRecording(), "quiesce must be the final settled command")
            complete = true
        elseif command.op == "snapshot" or command.op == "shot" then complete = true
        elseif command.op == "catalog" then
            assert(VisualCatalog, "visual catalog unavailable")
            Autopilot.catalog = VisualCatalog.write(config.output_dir)
            complete = true
        elseif command.op == "contracts" then
            assert(Contracts, "contracts unavailable")
            command.contracts = Contracts.run()
            assert(command.contracts.ok, "runtime contracts failed")
            complete = true
        else
            complete = Autopilot.step(command.parts, game)
        end
    end)
    if not ok then failure = tostring(problem); complete = true end
end

function Harness.afterFrame(game, runtimeError)
    HarnessCapture.tick, HarnessCapture.phase = tick, runtimeError and "partial-error" or "completed"
    if runtimeError then
        publish("runtime-error.json", { error = runtimeError, snapshot = HarnessDiagnostics.snapshot(game) })
        if request then finish(game, "error", runtimeError) end
        return
    end
    Autopilot.afterFrame()
    HarnessCapture.recent()
    watchMachines(game)
    local snapshot = HarnessDiagnostics.snapshot(game)
    local event = envelope({ active_id = request and request.id, command = request and index,
        input = Autopilot.inputSnapshot(), transitions = transitions, snapshot = snapshot })
    transitions = {}
    local file = assert(playdate.file.open("trace.jsonl", playdate.file.kFileAppend))
    file:write(json.encode(event) .. "\n"); file:close()
    if tick == 1 then publish("ready.json", { status = "ready", sdk_version = config.sdk_version, snapshot = snapshot }) end
    if tick % 15 == 0 then
        publish("heartbeat.json", { status = "alive", active_id = request and request.id, command = index })
    end
    if not request then return end
    local command = commands[index]
    if command and complete then
        local messages = Autopilot.takeResults()
        local outcome = "ok"
        for _, message in ipairs(messages) do
            if message:match("^err ") then failure = message end
            if message:match("^blocked ") then outcome = "blocked" end
            if message:match("^interrupted ") then outcome = "interrupted" end
            if message:match("^edge%-door ") then outcome = "edge-door" end
        end
        if outcome ~= (command.expect or "ok") then failure = "unexpected outcome: " .. outcome end
        if command.op == "shot" then
            HarnessCapture.write(command.args[1])
        end
        entries[#entries + 1] = { command = index, op = command.op, tick = tick, status = failure and "error" or "ok",
            outcome = outcome, messages = messages, snapshot = snapshot, contracts = command.contracts }
        if failure then
            HarnessCapture.write("failure")
            finish(game, "error", failure); return
        end
        if command.op == "quiesce" then
            -- Everything for this completed frame is published before the
            -- terminal acknowledgement. Main never updates this session again.
            Autopilot.resetControls()
            publish("captures-final.json", HarnessCapture.manifest())
            publish("heartbeat.json", { status = "quiescent", active_id = request.id })
            Harness.isQuiescent = true
        end
        index = index + 1
        complete = false
    end
    if index > #commands and not Autopilot.isRecording() then finish(game, "ok") end
end
