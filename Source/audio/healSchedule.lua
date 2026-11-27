-- AnimateHealingMachine in engine/overworld/healing_machine.asm.
-- One SFX_HEALING_MACHINE per party Poké Ball, then DelayFrames(30),
-- then MUSIC_PKMN_HEALED. FlashSprite8Times (8 times DelayFrames(10))
-- overlaps that jingle. The routine returns after the jingle ends and
-- DelayFrames(32). 30 Game Boy frames are 15 Playdate frames.
KantoHeal = {}
KantoHeal.ballFrames = 15
KantoHeal.jingleTicks = 136
KantoHeal.tailFrames = 32
KantoHeal.tickSeconds = 70224 / 4194304

function KantoHeal.gbFrames(frames)
    return math.max(1, math.ceil(frames * KantoHeal.tickSeconds * 30))
end

function KantoHeal.plan(count)
    if type(count) ~= "number" or count < 1 then
        count = 1
    end
    if count > 6 then
        count = 6
    end
    local events = {}
    local at = 0
    for _ = 1, count do
        events[#events + 1] = {name = "healing_machine", at = at}
        at = at + KantoHeal.ballFrames
    end
    events[#events + 1] = {name = "heal", at = at}
    local total = at + KantoHeal.gbFrames(KantoHeal.jingleTicks) + KantoHeal.gbFrames(KantoHeal.tailFrames)
    return events, total
end
