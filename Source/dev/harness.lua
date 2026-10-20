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
local function read(path)
    if not playdate.file.exists(path) then return nil end
    local ok, value = pcall(json.decodeFile, path)
    playdate.file.delete(path)
    if not ok or type(value) ~= "table" then return { malformed = true } end
    return value
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
            assert(not options.player_pokemon and not options.grant_xp, "battle adjustment cannot reset player or XP")
            assert(type(options.adjust_battle) == "table", "battle adjustment object required")
            local hp = options.adjust_battle
            assert(hp.player_hp == nil or (type(hp.player_hp) == "number" and integer(hp.player_hp, 1, 9999)), "invalid player fixture hp")
            assert(hp.enemy_hp == nil or (type(hp.enemy_hp) == "number" and integer(hp.enemy_hp, 1, 9999)), "invalid enemy fixture hp")
            for _, side in ipairs({"player", "enemy"}) do
                local pp, status, turns = hp[side .. "_pp"], hp[side .. "_status"], hp[side .. "_status_turns"]
                if pp then
                    assert(type(pp) == "table", "PP fixture must be an object")
                    for key, amount in pairs(pp) do
                        assert(moveData[key] and type(amount) == "number" and integer(amount, 0, moveData[key].maxPP), "invalid fixture PP")
                    end
                end
                assert(status == nil or statuses[status], "invalid fixture status")
                assert(turns == nil or (type(turns) == "number" and integer(turns, 0, 3)), "invalid fixture status turns")
                assert(turns == nil or status == nil or status == "sleep" or turns == 0, "only sleep may have a positive counter")
            end
        end
        if options.entry then
            local zone = zoneRegistry[options.zone or "reds_house_2f"]
            assert(integer(options.entry.x, 0, zone.width - 1) and integer(options.entry.y, 0, zone.height - 1), "invalid fixture entry")
        end
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
    elseif op == "seed" then valid = integer(args[1], -2147483647, 2147483647) and #args == 1
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
        catalog = Autopilot.catalog, quiescent = Harness.isQuiescent })
    request, commands, complete, failure = nil, nil, false, nil
    Autopilot.catalog = nil
end
local function poll(game)
    local incoming = read("request.json")
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
                -- Validate both actual battlers before applying any mutation.
                for _, side in ipairs({"player", "enemy"}) do
                    local mon = battle[side]
                    assert(not values[side .. "_hp"] or values[side .. "_hp"] <= mon.maxHP, "fixture HP exceeds maxHP")
                    for key in pairs(values[side .. "_pp"] or {}) do
                        assert(mon:hasMove(key), "fixture PP refers to an unknown move")
                    end
                    local turns = values[side .. "_status_turns"]
                    assert(values[side .. "_status"] or turns == nil or mon.status == "sleep" or turns == 0, "status-counter mismatch")
                end
                for _, side in ipairs({"player", "enemy"}) do
                    local mon = battle[side]
                    if values[side .. "_hp"] then mon.hp = values[side .. "_hp"] end
                    for key, amount in pairs(values[side .. "_pp"] or {}) do mon.pp[key] = amount end
                    local status = values[side .. "_status"]
                    if status then
                        mon.status = status ~= "none" and status or nil
                        mon.statusTurns = status == "sleep" and (values[side .. "_status_turns"] or 0) or 0
                    elseif values[side .. "_status_turns"] ~= nil then
                        mon.statusTurns = values[side .. "_status_turns"]
                    end
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
