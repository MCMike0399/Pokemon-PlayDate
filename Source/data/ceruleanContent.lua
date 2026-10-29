-- Immutable Blue content for the next source-map batch. Geometry, encounters,
-- bindings, actors and event execution remain in their shared owners.
CeruleanContent = {}
local contentName <const> = "cerulean"
local packages = {}
local installed = false
local signsInstalled = false
local actorMetadata
local rendered = {}
local walks = {}
local baseRoot <const> = "data/sourceSlice/"

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function recordIndex(root, recordName, field)
    return SourceEvents._contentIndex(root).records[recordName][field]
end
local function immutableDigest(recordName, field, id)
    local found = recordIndex(baseRoot, recordName, field)[id]
    for _, root in pairs(packages) do
        local candidate = recordIndex(root, recordName, field)[id]
        assert(not found or not candidate or found == candidate, "conflicting immutable source package record")
        found = found or candidate
    end
    return found
end
local function immutableLookup(recordName, field, id)
    return SourceEvents._contentRecord(immutableDigest(recordName, field, id))
end
local function catalog(recordName, field)
    local result = {}
    for id, digest in pairs(recordIndex(baseRoot, recordName, field)) do
        result[id] = copy(SourceEvents._contentRecord(digest))
    end
    return result
end

-- Generated indexes validate duplicate text/art by canonical record checksum.
-- Only explicit registration activates a package; catalog presence does not.
function CeruleanContent.registerPackage(name, root)
    assert(type(name) == "string" and name ~= contentName and not packages[name], "unique source package required")
    assert(type(root) == "string" and root:match("^data/[%w_/]+/$"), "source package data root required")
    local index = SourceEvents._contentIndex(root)
    for recordName, field in pairs({dialogue="texts", sprites="sprites"}) do
        for id, digest in pairs(index.records[recordName][field]) do
            local previous = immutableDigest(recordName, field, id)
            assert(not previous or previous == digest, "conflicting immutable source package record")
        end
    end
    SourceEvents._registerContent(name, index, {"events", "signs"}, index.ordinary_trainers)
    SourceEvents.registerTextSource(name, CeruleanContent.text)
    packages[name] = root
end

function CeruleanContent.text(label)
    return copy(assert(immutableLookup("dialogue", "texts", label), "missing Blue source text: " .. tostring(label)))
end

function CeruleanContent.trainers()
    return catalog("trainers", "trainers")
end

function CeruleanContent.rivalClasses()
    return catalog("trainers", "rival_classes")
end

function CeruleanContent.events()
    return catalog("events", "events")
end

function CeruleanContent.signs()
    return catalog("events", "signs")
end

function CeruleanContent.sprite(source)
    return copy(assert(immutableLookup("sprites", "sprites", source), "missing Blue source sprite: " .. tostring(source)))
end

function CeruleanContent.key(source)
    assert(immutableDigest("sprites", "sprites", source), "unknown Blue source actor")
    return "cerulean_" .. source:lower()
end

-- Pure world-pose policy shared with the catalog. Raw source frames remain
-- four-shade provenance, not a replacement for the protected BLUE family.
function CeruleanContent.poseImage(source, pose, facing)
    assert(pose == "stand" or pose == "walk" or pose == "alternate", "unknown source pose")
    assert(facing == "down" or facing == "up" or facing == "left" or facing == "right",
        "unknown source facing")
    if source == "SPRITE_BLUE" and pose == "stand" then
        return assert(SpriteFactory.npc.rival[facing], "protected BLUE pose missing")
    end
    local strip = assert(immutableLookup("sprites", "sprites", source), "missing Blue source sprite")
    local direction = strip.fixed and "down" or facing == "right" and "left" or facing
    local index = (pose == "stand" and strip.standing or strip.walking)[direction]
    local grid = assert(strip.frames[tostring(index)], "missing original actor frame")
    local image
    if source == "SPRITE_BLUE" then
        -- Existing BLUE uses greyhair and the legacy omitted-phase renderer.
        -- SDK 3.1.2 renders omitted phase differently from explicit zero. Keep
        -- its additive strides in that family; never normalize protected art.
        local greyhair = {}
        for row, cells in ipairs(grid) do greyhair[row] = cells:gsub("1", ".") end
        image = SpriteFactory.makeSprite(greyhair)
    else
        image = SpriteFactory.makeSprite(grid, {0,0})
    end
    if not strip.fixed and (facing == "right"
        or pose == "alternate" and (facing == "down" or facing == "up")) then
        image = SpriteFactory.flipped(image)
    end
    return image
end

function CeruleanContent.poseAtTick(tick)
    assert(type(tick) == "number" and tick % 1 == 0 and tick >= 1 and tick <= 8,
        "bounded source animation tick required")
    local phase = (tick // 2) % 4
    return phase == 1 and "walk" or phase == 3 and "alternate" or "stand"
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
            local strip = immutableLookup("sprites", "sprites", source)
            local images = {}
            for direction in pairs(strip.standing) do
                images[direction] = CeruleanContent.poseImage(source, "stand", direction)
            end
            if images.left then images.right = CeruleanContent.poseImage(source, "stand", "right") end
            rendered[key] = images
        end
        SpriteFactory.npc[key] = rendered[key]
    end
end

function CeruleanContent.stepImage(source, facing, tick)
    local pose = CeruleanContent.poseAtTick(tick)
    local key = CeruleanContent.key(source)
    local standing = assert(SpriteFactory.npc[key], "source actor art not installed")
    if pose == "stand" then return assert(standing[facing], "source actor has no standing pose") end
    if not walks[source] then
        local strip = immutableLookup("sprites", "sprites", source)
        local images, alternate = {}, {}
        for direction in pairs(strip.walking) do
            images[direction] = CeruleanContent.poseImage(source, "walk", direction)
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
    return assert((pose == "walk" and frames.images or frames.alternate)[facing], "source actor has no walking pose")
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
    local index = SourceEvents._contentIndex(baseRoot)
    SourceEvents._registerContent(contentName, index, {"events"}, index.records.trainers.trainers)
    SourceActors.registerContent("source", {
        sprite = CeruleanContent.sprite,
        key = CeruleanContent.key,
        stepImage = CeruleanContent.stepImage,
        install = CeruleanContent.installArt,
        metadata = metadata,
    })
    installed = true
end

-- Keep the established separate sign registration and content identity.
function CeruleanContent.installSigns()
    if signsInstalled then return end
    local index = SourceEvents._contentIndex(baseRoot)
    SourceEvents._registerContent("cerulean-signs", index, {"signs"}, nil, "cerulean-signs")
    SourceEvents.registerTextSource("cerulean-signs", CeruleanContent.text)
    signsInstalled = true
end

-- SourceEvents owns SDK registration scopes, including this adapter's lazy
-- package membership and install guards. Nested/error scopes restore by reference.
function CeruleanContent._registrationScope()
    local oldPackages, oldInstalled, oldSigns, oldMetadata = packages, installed, signsInstalled, actorMetadata
    local scoped = {}
    for name, root in pairs(packages) do scoped[name] = root end
    packages = scoped
    return function()
        packages, installed, signsInstalled, actorMetadata = oldPackages, oldInstalled, oldSigns, oldMetadata
    end
end
