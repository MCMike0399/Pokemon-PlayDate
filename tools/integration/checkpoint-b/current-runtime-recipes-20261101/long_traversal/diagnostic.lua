-- APPEND ONLY to the privately staged DS1 module; never import in production.
-- No gameplay action, session write, input command, RNG call or native probe.
function DeviceSmoke.installLongTraversal()
    assert(DEVICE_TEST_BUILD == true)
    local clock <const> = playdate.getCurrentTimeMilliseconds
    local sequence, entries, doors, battles = 0, 0, 0, 0
    local distinct, visited = 0, {}
    local pending, lastZone, installed
    local started = clock()
    local function emit(kind, row)
        sequence = sequence + 1
        row.kind, row.seq, row.build = kind, sequence, DEVICE_TEST_ID
        row.clock_ms = clock()
        local encoded = json.encode(row)
        local file = assert(playdate.file.open("long-traversal.jsonl", playdate.file.kFileAppend))
        assert(file:write(encoded .. "\n"))
        file:close()
        print("LTR1 " .. encoded)
    end
    function DeviceSmoke.longTraversalStatus()
        return {entries = entries, doors = doors, battles = battles, maps = distinct,
            pending = pending ~= nil, sequence = sequence}
    end
    function DeviceSmoke.longTraversalResources(game)
        local party, inventory = game.session:party(), game.session:inventory()
        local members = {}
        for index = 1, party:count() do
            local mon = party:get(index)
            local moves = {}
            for slot, key in ipairs(mon.moves) do
                moves[slot] = {key = key, pp = mon.pp[key]}
            end
            members[index] = {species = mon.species, hp = mon.hp, max_hp = mon.maxHP,
                status = mon.status, moves = moves}
        end
        return {party = members, active = party:activeIndex(), money = inventory:money(),
            items = inventory:slots()}
    end
    GameBootstrap.afterReady(function()
        local enterWorld <const> = OverworldState.enter
        function OverworldState:enter(opts)
            assert(not pending, "previous map entry not sampled")
            local origin = lastZone
            enterWorld(self, opts)
            local zone = assert(currentZone.stableID)
            entries = entries + 1
            assert(entries <= 240, "map entry bound")
            if not visited[zone] then
                visited[zone] = true
                distinct = distinct + 1
            end
            local door = opts and opts.fromDoor == true
            if door then
                doors = doors + 1
                assert(doors <= 160, "door bound")
            end
            pending = {entry = entries, zone = zone, origin = origin, door = door,
                x = self.game.player.gridX, y = self.game.player.gridY,
                doors = doors, maps = distinct}
            lastZone = zone
            emit("entry", pending)
        end
        local enterBattle <const> = BattleState.enter
        function BattleState:enter(player, enemy, npc, party)
            enterBattle(self, player, enemy, npc, party)
            battles = battles + 1
            assert(battles <= 48, "battle bound")
            emit("battle", {battle = battles, zone = currentZone.stableID,
                trainer = npc ~= nil, species = self.battle.enemy.species})
        end
        -- Safety proof needs an ordinary Save in disposable Simulator Data to
        -- satisfy the EXISTING admission gate. Hardware saves are prohibited.
        local save <const> = GameSaves.save
        function GameSaves:save(...)
            assert(playdate.isSimulator, "long traversal prohibits hardware Save")
            return save(self, ...)
        end
        installed = true
        emit("start", {platform = playdate.isSimulator and "simulator" or "device"})
    end)
    local run <const> = DeviceSmoke.runFrame
    function DeviceSmoke.runFrame(game, updateGame)
        -- Within the existing guarded frame, BEFORE accepting the next input.
        -- No collection during loading, motion, overlays, battle or rendering.
        run(game, function()
            assert(clock() - started <= 7200000, "two hour traversal deadline")
            assert(not game.session:party():allFainted(), "traversal stopped before blackout")
            if installed and pending and game.machine:getCurrent() == "overworld"
                and game.machine:get("overworld").sub:getCurrent() == "explore"
                and not game.machine:get("overworld").fieldArrival
                and not game.player.isMoving and not game.player.fieldStep then
                local before, began = collectgarbage("count"), clock()
                BootTrace.checkGuard()
                BootTrace.mark("long_traversal.entry_" .. pending.entry .. ".before_gc")
                collectgarbage("collect")
                local after = collectgarbage("count")
                BootTrace.mark("long_traversal.entry_" .. pending.entry .. ".after_gc")
                local row = pending
                pending = nil
                row.before_kib, row.after_kib, row.gc_ms = before, after, clock() - began
                emit("sample", row)
                if not playdate.isSimulator then
                    assert(after <= 6144, "entry live heap exceeds 6 MiB")
                end
                BootTrace.checkGuard()
            end
            updateGame()
        end)
    end
end
