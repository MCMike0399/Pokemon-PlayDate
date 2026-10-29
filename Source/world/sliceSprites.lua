-- Original pinned strips; no NPC fallback, protected sprite tables unchanged.
SliceSprites = {}
local loaded
local rendered = {}
local keys = { youngster="kantoYoungster", gambler="kantoGambler", girl="kantoGirl", gambler_asleep="kantoGamblerAsleep", fisher="kantoFisher", clerk="kantoClerk", cooltrainer_m="kantoCooltrainerM", nurse="kantoNurse", gentleman="kantoGentleman", link_receptionist="kantoLinkReceptionist" }
local function data()
    if not loaded then loaded = assert(json.decodeFile("data/viridianSlice/sprites.json")); assert(loaded.source_revision == "af519899719f0754965776faac0e836a3b906e6d") end
    return loaded.sprites
end
function SliceSprites.key(source)
    local name = assert(source:match("^SPRITE_(.+)$")):lower()
    assert(keys[name] and data()[name], "unmapped original sprite: " .. tostring(source))
    return keys[name]
end
function SliceSprites.install(sources)
    local selected = {}
    if sources then
        for _, source in ipairs(sources) do
            local name = assert(source:match("^SPRITE_(.+)$")):lower()
            selected[name] = SliceSprites.key(source)
        end
    else
        for name, key in pairs(keys) do
            selected[name] = key
        end
    end
    for _, key in pairs(selected) do
        local current = SpriteFactory.npc[key]
        assert(current == nil or current == rendered[key], "conflicting slice sprite key: " .. key)
    end
    for name, key in pairs(selected) do
        if not rendered[key] then
            local source, images = data()[name], {}
            for direction, index in pairs(source.standing) do
                images[direction] = SpriteFactory.makeSprite(assert(source.frames[tostring(index)]), {0, 0})
                if GameBootstrap then
                    GameBootstrap.yieldIfDue()
                end
            end
            if images.left then
                images.right = SpriteFactory.flipped(images.left)
            end
            rendered[key] = images
        end
    end
    for _, key in pairs(selected) do
        SpriteFactory.npc[key] = rendered[key]
    end
end
