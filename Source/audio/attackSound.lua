-- PlayApplyingAttackSound in engine/battle/animations.asm.
-- wDamageMultipliers of 0 plays nothing. 10 is neutral SFX_DAMAGE.
-- Above 10 is SFX_SUPER_EFFECTIVE. Below 10 is SFX_NOT_VERY_EFFECTIVE.
-- The port's type matchup is 0, 0.25, 0.5, 1, 2, or 4.
KantoAttack = {}

function KantoAttack.cue(effectiveness)
    if type(effectiveness) ~= "number" or effectiveness <= 0 then
        return nil
    end
    if effectiveness > 1 then
        return "damage_super"
    end
    if effectiveness < 1 then
        return "damage_not_very"
    end
    return "damage_normal"
end
