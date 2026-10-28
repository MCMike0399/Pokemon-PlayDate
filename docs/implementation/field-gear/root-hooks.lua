-- Root adds these imports before constructing GameContext.
-- import "domain/fieldCycling"
-- import "domain/fieldFishing"
-- import "game/fieldGearRequests"
--
-- Root's Bag fieldKeyActions table gets all four keys, using the SAME path for
-- ordinary USE and approved registered A+B. This delegates to the root's field
-- controller, which must prepare before pushing its overlay and cancel on exit.
-- bicycle = function(bag) return gameFieldGearController(bag, "bicycle") end,
-- oldRod = function(bag) return gameFieldGearController(bag, "oldRod") end,
-- goodRod = function(bag) return gameFieldGearController(bag, "goodRod") end,
-- superRod = function(bag) return gameFieldGearController(bag, "superRod") end,
--
-- Preparation:
-- local token, reason = FieldGearRequests.prepare(game, bag, id)
-- Show the source item/rod presentation; cancellation calls cancel(token).
-- On completed presentation:
-- local accepted, result = FieldGearRequests.complete(token, actualOverlay)
-- Success result.kind is "bicycle", "no-bite", "no-fish", or "encounter".
-- Only an encounter result supplies result.pokemon. Pop field/Bag overlays and
-- use existing FieldBattle.start(game, game.session:activePokemon(), result.pokemon).
-- Keep the root's preflight/recovery for fallible native battle entry; never
-- resolve twice to recover a failed transition, or recruit the fish here.

-- Minimal GameContext adapter after root installs the returned session method.
-- Call only from the checked Gear controller, while its movement/render context
-- has been preflighted. No movement occurs during a bicycle mode toggle.
function GameContext:commitCycling(expected, plan)
    if self.session:fieldWorldEpoch() ~= expected.epoch
        or not FieldMoves.same(WorldDeltas.export(), expected.world) then
        return false, "stale-cycling-world"
    end
    return self.session:commitCycling(expected.epoch, expected.travel, expected.forced, plan)
end

-- On real map entry root calls FieldCycling.enter AFTER FieldTravel.enter and
-- commits its plan's travel and forced bit with the entry's world/location/
-- actors in ONE root-owned traversal. Do not use the mode-toggle adapter above
-- after independently publishing a warp. Reuse the existing map transaction.
-- The coordinates supplied to enter/gate are SOURCE coordinates (subtract the
-- provider descriptor.padding); authoring/render coordinates stay padded.
--
-- At settled exploration input, read FieldCycling.motion(travel, sourceMap,
-- {up=..., down=..., left=..., right=..., a=..., b=...}, scripted, trainer).
-- Feed .automatic to Player only if no real movement direction wins. Its
-- .accelerated requests the source's extra advancement over the SAME existing
-- step/interpolation owner; never add another logical step or encounter check.
