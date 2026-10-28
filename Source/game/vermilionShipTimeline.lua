-- Presentation clock only. It never reads or changes quest, terrain or RNG.
VermilionShipTimeline = {}

local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached

local function definition()
    if not cached then
        cached = assert(json.decodeFile("data/vermilionShip/timing.json"))
        assert(cached.schema == 1 and cached.source_revision == REVISION,
            "unverified ship timing")
        assert(cached.source_hz == 60 and cached.native_hz == 30,
            "ship clock requires the production 30 Hz update")
    end
    return cached
end

function VermilionShipTimeline.data()
    return GameSession._copy(definition())
end

function VermilionShipTimeline.at(sourceFrame)
    assert(Party._integer(sourceFrame, 0, 100000), "bounded ship frame required")
    local timing <const> = definition()
    local waitEnd <const> = timing.smoke_load_wait + timing.initial_wait
    local scrollStart <const> = waitEnd + timing.transfer_wait
    local scrollLength <const> = timing.chunks * timing.pixels_per_chunk
        * timing.source_frames_per_pixel
    local eraseFrame <const> = scrollStart + scrollLength
    local hornFrame <const> = eraseFrame + timing.erase_transfer_wait
    local reloadFrame <const> = hornFrame + timing.final_wait
    local walkoutFrame <const> = reloadFrame + timing.player_reload_wait
    local endFrame <const> = walkoutFrame + timing.walkout_wait
    local state = {
        source_frame = sourceFrame,
        scroll_start = scrollStart,
        erase_frame = eraseFrame,
        end_frame = endFrame,
        scroll_pixels = 0,
        chunk = 0,
        puff_visible = false,
        erased = false,
        complete = sourceFrame >= endFrame,
    }

    if sourceFrame < timing.smoke_load_wait then
        state.phase = "smoke-load"
    elseif sourceFrame < waitEnd then
        state.phase = "initial-wait"
    elseif sourceFrame < scrollStart then
        state.phase = "background-transfer"
    elseif sourceFrame < eraseFrame then
        state.phase = "scroll"
        local step <const> = (sourceFrame - scrollStart) // timing.source_frames_per_pixel
        local chunk <const> = step // timing.pixels_per_chunk
        local drift <const> = (step % timing.pixels_per_chunk + 1) * timing.puff_step_drift
        -- WriteOAMBlock always rewrites block 1 (entries 4..7). The source
        -- presents one four-tile puff, not an invented accumulating trail.
        local hardwareX <const> = (timing.oam_initial_x
            - (chunk + 1) * timing.puff_chunk_decrement + drift) & 255
        state.scroll_pixels = step
        state.chunk = chunk + 1
        state.puff_oam_x = hardwareX
        state.puff_visible = hardwareX > 0
            and hardwareX < timing.hardware_width + timing.oam_x_offset
        state.puff_world_x = (timing.reference_view_left + hardwareX - timing.oam_x_offset) * 2
        state.puff_band_y = (timing.oam_y - timing.oam_y_offset - timing.band_top) * 2
    else
        if sourceFrame < hornFrame then
            state.phase = "erase-transfer"
        elseif sourceFrame < reloadFrame then
            state.phase = "final-wait"
        elseif sourceFrame < walkoutFrame then
            state.phase = "player-reload"
        elseif not state.complete then
            state.phase = "walkout-delay"
        else
            state.phase = "complete"
        end
        state.scroll_pixels = timing.chunks * timing.pixels_per_chunk
        state.erased = true
    end
    return state
end
