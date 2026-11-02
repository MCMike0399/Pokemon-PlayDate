-- One supplementary behavior case, compiled only by the preparation worker.
-- Reuses the real service scene, controller, dialog and atomic session owners.
CopycatServiceContracts = {}
local function settle(game)
    for _ = 1, 512 do
        if game.machine:getCurrent() == "overworld" then
            return
        end
        if game.machine:getCurrent() == "dialog" then
            local dialog = game.machine:get("dialog")
            dialog.dialog:advance()
            dialog:handleInput()
        else
            game.machine:update()
        end
        local event = game.machine:get("event")
        assert(event.phase ~= "failed", event.waiting)
    end
    error("Copycat service did not settle")
end

function CopycatServiceContracts.run()
    local ok, problem = pcall(function()
        local policy = CopycatService.policy()
        KantoServicesContracts.withScene("CopycatsHouse2F", {x = 0, y = 2}, function(game)
            game.machine:register("event", MidgameServicesState(game))
            local bag = game.session:inventory()
            local function interact(id)
                assert(SourceEvents.dispatch(game, id))
                settle(game)
            end
            interact(policy.copycat)
            assert(bag:quantity("tm31") == 0 and not game.session:questFlag(policy.flag))
            assert(bag:add("pokeDoll", 2))
            local choices = {}
            for id, definition in pairs(ItemData.definitions) do
                if not definition.keyItem and id ~= "pokeDoll" and id ~= "tm31" then
                    choices[#choices + 1] = id
                end
            end
            table.sort(choices)
            for index = 1, Inventory.CAPACITY - 1 do
                assert(bag:add(choices[index], 1))
            end
            interact(policy.copycat)
            assert(bag:quantity("pokeDoll") == 2 and bag:quantity("tm31") == 0)
            assert(not game.session:questFlag(policy.flag))
            assert(bag:consume(choices[1], 1))

            -- Cancel before the optimistic commit, then invoke the old dialog
            -- callback while a fresh visit is active. Its epoch must reject it.
            assert(SourceEvents.dispatch(game, policy.copycat))
            local stale = game.machine:get("dialog").onComplete
            game.machine:pop()
            game.machine:pop()
            assert(bag:quantity("pokeDoll") == 2 and bag:quantity("tm31") == 0)
            assert(SourceEvents.dispatch(game, policy.copycat))
            stale()
            assert(bag:quantity("pokeDoll") == 2 and bag:quantity("tm31") == 0)
            settle(game)
            assert(bag:quantity("pokeDoll") == 1 and bag:quantity("tm31") == 1)
            assert(game.session:questFlag(policy.flag))
            interact(policy.copycat)
            assert(bag:quantity("pokeDoll") == 1 and bag:quantity("tm31") == 1)
            for _, facing in ipairs({"up", "left", "right", "down"}) do
                game.player.facing = facing
                assert(CopycatService.pcLabel(facing) == policy.labels[facing == "up" and "pc_up" or "pc_other"])
                interact(policy.pc)
            end
        end)
    end)
    return {ok = ok, passed = ok and 1 or 0, failed = ok and 0 or 1, tests = {{
        name = "copycat-capacity-cancel-retry-single-exchange-and-pc", ok = ok,
        error = not ok and tostring(problem) or nil,
    }}}
end
