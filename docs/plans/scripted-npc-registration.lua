-- Add to the root's harness-only tools/harness/dev_imports.lua event suites.
-- No production main.lua registration is required.
import "dev/scriptedNPCContracts"
Contracts.register("scripted-npc", ScriptedNPCContracts.run)
