-- Temporary ship presentation. GameSession alone commits its durable outcome.
import "game/vermilionShipTimeline"
import "game/vermilionShipArt"

Class("VermilionShip")

local gfx <const> = playdate.graphics
local DOCK <const> = "pokered:VERMILION_DOCK"
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"
local views <const> = setmetatable({}, {__mode="k"})
local audioSink

-- Future audio engine seam. No installed sink means cue-only, explicitly
-- unaccepted audio. Sinks receive source symbols/time, never story authority.
function VermilionShip.setAudioSink(callback)
    assert(callback == nil or type(callback) == "function", "ship audio sink must be callable")
    audioSink = callback
end

function VermilionShip:init(owner)
    assert(owner:valid() and owner:isTop(), "current ship event owner required")
    assert(currentZone.stableID == DOCK and owner.session:questFlag(PENDING)
        and owner.session:questFlag("EVENT_GOT_HM01")
        and not owner.session:questFlag("EVENT_SS_ANNE_LEFT"), "authorized ship departure required")
    local previous <const> = views[owner.game]
    if previous then
        previous:dispose()
    end
    self.owner = owner
    self.epoch = owner.epoch
    self.game = owner.game
    self.session = owner.session
    self.player = owner.player
    self.zone = owner.zone
    self.ticks = 0
    self.retained = false
    self.closed = false
    self.cues = {}
    self.nextCue = 1
    self.sink = audioSink
    self.timing = VermilionShipTimeline.data()
    self.timeline = VermilionShipTimeline.at(0)
    local data <const> = VermilionShipArt.data()
    self.image = gfx.image.new(data.map_width_cells * 32, data.band.height_cells * 32, gfx.kColorWhite)
    VermilionShipArt.render(self.image, self.timeline)
    self.sprite = gfx.sprite.new(self.image)
    self.sprite:setCenter(0, 0)
    self.sprite:moveTo(0, data.band.source_y * 32)
    self.sprite:setZIndex(98)
    self.sprite:setUpdatesEnabled(false)
    self.sprite:add()
    views[self.game] = self
    self:emitCues()
end

function VermilionShip:validContext()
    return not self.closed and self.game.session == self.session
        and self.game.player == self.player and currentZone == self.zone
end

function VermilionShip:validOwner()
    return self:validContext() and self.owner.epoch == self.epoch
        and self.owner:valid() and self.owner:isTop()
end

function VermilionShip:emitCues()
    local cues <const> = self.timing.audio_cues
    local cue = cues[self.nextCue]
    while cue and cue.source_frame <= self.timeline.source_frame do
        local emitted = GameSession._copy(cue)
        emitted.sink_installed = self.sink ~= nil
        self.cues[#self.cues + 1] = emitted
        self.nextCue = self.nextCue + 1
        if self.sink then
            self.sink(GameSession._copy(emitted))
        end
        cue = cues[self.nextCue]
    end
end

function VermilionShip:update()
    if not self:validOwner() then
        return false, "stale-ship-owner"
    end
    if self.timeline.complete then
        return true
    end
    self.ticks = self.ticks + 1
    self.timeline = VermilionShipTimeline.at(self.ticks * 2)
    self:emitCues()
    VermilionShipArt.render(self.image, self.timeline)
    self.sprite:markDirty()
    return self.timeline.complete
end

function VermilionShip:retainAfterCommit()
    if not self:validOwner() or not self.timeline.complete
        or not self.session:questFlag("EVENT_SS_ANNE_LEFT") then
        return false, "uncommitted-ship-presentation"
    end
    self.retained = true
    return true
end

function VermilionShip:releaseEvent()
    if not self.retained or not self:validContext() then
        self:dispose()
    end
    -- A retained water band outlives this overlay's pop/door fade, preventing
    -- the unchanged upper source hull from flashing back before map exit.
end

function VermilionShip:dispose()
    if self.closed then
        return
    end
    self.closed = true
    self.sprite:remove()
    if views[self.game] == self then
        views[self.game] = nil
    end
end

function VermilionShip:snapshot()
    local result = GameSession._copy(self.timeline)
    result.ticks = self.ticks
    result.closed = self.closed
    result.retained = self.retained
    result.cues = GameSession._copy(self.cues)
    result.audio_status = self.sink and "sink-unaccepted" or "cue-only-unaccepted"
    return result
end

function VermilionShip.beforeSpawn(game)
    local view <const> = views[game]
    if view and not view:validContext() then
        view:dispose()
    end
end

function VermilionShip.onLeave(game, destination)
    local view <const> = views[game]
    if view and (not view:validContext() or destination ~= DOCK) then
        view:dispose()
    end
end

function VermilionShip.current(game)
    return views[game]
end
