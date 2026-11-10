-- Independent reviewed byte vectors. Terrain and authored Shade callers
-- share the approved Bayer bytes. The legacy table remains only so a test
-- can still name the superseded 12.5%/50% patterns.
ImportedToneReference = {}
local gfx <const> = playdate.graphics
-- Superseded 12.5% / 50% bytes. Callers no longer sample these.
ImportedToneReference.legacy = {
    light = {0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF},
    dark = {0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA},
}
local reviewed <const> = {
    light = {0x55, 0xBB, 0x55, 0xFF, 0x55, 0xBB, 0x55, 0xFF},
    dark = {0x00, 0xAA, 0x44, 0xAA, 0x00, 0xAA, 0x44, 0xAA},
}
local policy

function ImportedToneReference.color(code, x, y, terrain)
    -- "." is flood-fill white. "w" is the same solid white, but the
    -- sprite mask treats it as opaque (imported OBJ color 1).
    if code == "." or code == "w" then
        return gfx.kColorWhite
    end
    if code == "#" then
        return gfx.kColorBlack
    end
    assert(code == "1" or code == "2", "source shade required")
    if terrain then
        policy = policy or assert(json.decodeFile("data/importedTonePatterns.json"))
        assert(policy.enabled and policy.family == "bayer8", "unreviewed terrain tone family")
    end
    local patterns = reviewed
    local byte = (code == "1" and patterns.light or patterns.dark)[y % 8 + 1]
    return byte & (0x80 >> (x % 8)) ~= 0 and gfx.kColorWhite or gfx.kColorBlack
end

function ImportedToneReference.image(grid)
    local image = gfx.image.new(32, 32, gfx.kColorWhite)
    gfx.pushContext(image)
    for y = 0, 31 do
        for x = 0, 31 do
            gfx.setColor(ImportedToneReference.color(grid[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1), x, y, true))
            gfx.fillRect(x, y, 1, 1)
        end
    end
    gfx.popContext()
    return image
end
