-- game/context.lua — Shared game context
--
-- One instance owns everything the top-level states need: the root state
-- machine, camera, NPC manager, the player sprite (recreated per zone build)
-- and the player's pokemon (persistent across battles). Passed to every
-- state at construction so states never reach for ad-hoc globals.

Class("GameContext")

local TRANSITION_LOG_MAX <const> = 12

function GameContext:init()
    self.machine = StateMachine()
    self.camera = Camera()
    self.npcManager = NPCManager()
    self.debugMenu = DebugMenu()
    self.player = nil          -- created by OverworldState:enter
    self.playerPokemon = nil   -- created lazily, survives state changes
    self.transitionLog = {}    -- ring of recent transitions, for triage

    self.machine:on("changed", function(kind, from, to)
        local log = self.transitionLog
        log[#log + 1] = kind .. ":" .. tostring(from) .. ">" .. tostring(to)
        if #log > TRANSITION_LOG_MAX then
            table.remove(log, 1)
        end
    end)
end

function GameContext:recentTransitions()
    return table.concat(self.transitionLog, " ")
end
