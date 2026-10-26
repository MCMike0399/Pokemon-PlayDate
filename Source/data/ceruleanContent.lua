-- Immutable Blue content for the next source-map batch. Geometry, encounters,
-- bindings, actors and event execution remain in their shared owners.
CeruleanContent = {}
local contentName <const> = "cerulean"
local cached = {}
local installed = false
local signsInstalled = false
local actorMetadata
local rendered = {}
local walks = {}

local function record(name)
    if not cached[name] then
        cached[name] = SourceMaps.record("data/sourceSlice/" .. name .. ".json")
    end
    return cached[name]
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function CeruleanContent.text(label)
    return copy(assert(record("dialogue").texts[label], "missing Blue source text: " .. tostring(label)))
end

function CeruleanContent.trainers()
    return copy(record("trainers").trainers)
end

function CeruleanContent.rivalClasses()
    return copy(record("trainers").rival_classes)
end

function CeruleanContent.events()
    return copy(record("events").events)
end

function CeruleanContent.signs()
    return copy(record("events").signs)
end

function CeruleanContent.sprite(source)
    return copy(assert(record("sprites").sprites[source], "missing Blue source sprite: " .. tostring(source)))
end

function CeruleanContent.key(source)
    assert(record("sprites").sprites[source], "unknown Blue source actor")
    return "cerulean_" .. source:lower()
end

local function frame(source, index)
    local strip = record("sprites").sprites[source]
    return SpriteFactory.makeSprite(assert(strip.frames[tostring(index)], "missing original actor frame"), { 0, 0 })
end

function CeruleanContent.installArt(definition)
    assert(definition.source_revision == "af519899719f0754965776faac0e836a3b906e6d", "unverified actor definition")
    local selected = {}
    for _, event in ipairs(definition.events.objects) do
        local key = CeruleanContent.key(event.sprite)
        assert(SpriteFactory.npc[key] == nil or SpriteFactory.npc[key] == rendered[key], "source actor art replaced")
        selected[event.sprite] = key
    end
    for source, key in pairs(selected) do
        if not rendered[key] then
            local strip = record("sprites").sprites[source]
            local images = {}
            for direction, index in pairs(strip.standing) do images[direction] = frame(source, index) end
            if images.left then images.right = SpriteFactory.flipped(images.left) end
            rendered[key] = images
        end
        SpriteFactory.npc[key] = rendered[key]
    end
end

function CeruleanContent.stepImage(source, facing, tick)
    assert(type(tick) == "number" and tick % 1 == 0 and tick >= 1 and tick <= 8, "bounded source animation tick required")
    local key = CeruleanContent.key(source)
    local standing = assert(SpriteFactory.npc[key], "source actor art not installed")
    if not walks[source] then
        local strip = record("sprites").sprites[source]
        local images, alternate = {}, {}
        for direction, index in pairs(strip.walking) do
            images[direction] = frame(source, index)
            alternate[direction] = (direction == "down" or direction == "up")
                and SpriteFactory.flipped(images[direction]) or images[direction]
        end
        if images.left then
            images.right = SpriteFactory.flipped(images.left)
            alternate.right = images.right
        end
        walks[source] = { images = images, alternate = alternate }
    end
    local frames = walks[source]
    local phase = (tick // 2) % 4
    if phase == 1 then return assert(frames.images[facing], "source actor has no walking pose") end
    if phase == 3 then return assert(frames.alternate[facing], "source actor has no alternate pose") end
    return assert(standing[facing], "source actor has no standing pose")
end

local function metadata(definition, event, runtimeGame)
    local result = {visibility={}}
    if definition.name == "Museum1F" and event.source_index == 5 then
        result.visibility[1] = {group="quest", id="EVENT_GOT_OLD_AMBER", equals=false}
    end
    if actorMetadata then
        local scene = actorMetadata(definition, event, runtimeGame)
        for _, condition in ipairs(scene.visibility or {}) do
            result.visibility[#result.visibility + 1] = copy(condition)
        end
    end
    return result
end

function CeruleanContent.install(metadataResolver)
    assert(metadataResolver == nil or type(metadataResolver) == "function", "actor metadata callback required")
    if installed then
        assert(metadataResolver == nil or metadataResolver == actorMetadata, "actor metadata resolver replaced")
        return
    end
    actorMetadata = metadataResolver
    SourceEvents.registerTextSource(contentName, CeruleanContent.text)
    SourceEvents.registerTrainerSource(contentName, CeruleanContent.trainers)
    SourceEvents.registerEventSource(contentName, CeruleanContent.events())
    SourceActors.registerContent("source", {
        sprite = CeruleanContent.sprite,
        key = CeruleanContent.key,
        stepImage = CeruleanContent.stepImage,
        install = CeruleanContent.installArt,
        metadata = metadata,
    })
    installed = true
end

-- Foundation candidate 9f3e37b accepts only object IDs in registerEventSource.
-- Root widens that validation to background_events before calling this method.
-- The separate name keeps ordinary installation usable until that API repair.
function CeruleanContent.installSigns()
    if signsInstalled then return end
    local signs = CeruleanContent.signs()
    for _, descriptor in pairs(signs) do descriptor.content = "cerulean-signs" end
    SourceEvents.registerTextSource("cerulean-signs", CeruleanContent.text)
    SourceEvents.registerEventSource("cerulean-signs", signs)
    signsInstalled = true
end
