-- TextCommand_SOUND plays the jingle, then WaitForSoundToFinish.
-- The hold is the score length in Playdate frames.
KantoReceipt = {}
KantoReceipt.tickSeconds = 70224 / 4194304

function KantoReceipt.holdFrames(ticks)
    return math.max(1, math.ceil(ticks * KantoReceipt.tickSeconds * 30))
end
