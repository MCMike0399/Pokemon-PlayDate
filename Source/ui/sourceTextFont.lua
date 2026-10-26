-- Extend the current SDK font only for source symbols. Ordinary glyphs keep
-- their font, kerning and draw path. Fallback pixels are pinned in sourceText.json.
SourceTextFont = {}
local gfx <const> = playdate.graphics
local data, images

function SourceTextFont.data()
    if not data then
        data = assert(json.decodeFile("data/sourceText.json"))
        assert(data.schema == 1 and data.source_revision == "af519899719f0754965776faac0e836a3b906e6d")
        images = {}
    end
    return data
end

local function fallback(char)
    if #char == 1 then return nil end
    local entry = SourceTextFont.data().glyphs[char]
    assert(entry, "unsupported dialogue glyph: " .. char)
    return entry
end

local function runs(text, visit)
    assert(utf8.len(text), "valid UTF-8 dialogue required")
    local native = ""
    for _, code in utf8.codes(text) do
        local char = utf8.char(code)
        if fallback(char) then
            if #native > 0 then visit(native, false); native = "" end
            visit(char, true)
        else
            native = native .. char
        end
    end
    if #native > 0 then visit(native, false) end
end

function SourceTextFont.width(text, font)
    local width = 0
    runs(text, function(run, sourceGlyph)
        width = width + (sourceGlyph and 16 or font:getTextWidth(run))
    end)
    return width
end

local function image(char)
    local entry = fallback(char)
    if not images[char] then
        local bitmap = assert(gfx.image.new(16, 16, gfx.kColorClear))
        gfx.pushContext(bitmap)
        gfx.setDrawOffset(0, 0)
        gfx.clearClipRect()
        gfx.clearStencil()
        gfx.setColor(gfx.kColorBlack)
        for y, row in ipairs(entry.rows) do
            for x = 1, 8 do
                if row:sub(x, x) == "#" then gfx.fillRect((x - 1) * 2, (y - 1) * 2, 2, 2) end
            end
        end
        gfx.popContext()
        images[char] = bitmap
    end
    return images[char]
end

function SourceTextFont.draw(text, x, y, font)
    runs(text, function(run, sourceGlyph)
        if sourceGlyph then
            assert(font:getHeight() >= 16, "source fallback requires 16px line height")
            image(run):draw(x, y + math.floor((font:getHeight() - 16) / 2))
            x = x + 16
        else
            font:drawText(run, x, y)
            x = x + font:getTextWidth(run)
        end
    end)
end

-- Return complete display pages, retaining hard paragraph boundaries. A long
-- word only splits when it cannot fit on a whole line; never drop its suffix.
function SourceTextFont.paginate(text, font, width)
    assert(type(text) == "string" and utf8.len(text), "valid dialogue text required")
    width = width or 360
    local height = font:getHeight()
    local advance = height + font:getLeading()
    assert(height >= 1 and height <= 42 and advance > 0, "dialogue font does not fit")
    local capacity = math.max(1, math.floor((42 - height) / advance) + 1)
    local pages, lines = {}, {}
    local function page()
        if #lines > 0 then pages[#pages + 1] = table.concat(lines, "\n"); lines = {} end
    end
    local function line(value)
        if #lines == capacity then page() end
        lines[#lines + 1] = value
    end
    for paragraph in (text .. "\f"):gmatch("(.-)\f") do
        for hardLine in (paragraph .. "\n"):gmatch("(.-)\n") do
            local current = ""
            local separator = hardLine:match("^[ \t\r]*") or ""
            for word, following in hardLine:gmatch("([^ \t\r]+)([ \t\r]*)") do
                local joined = current .. separator .. word
                if SourceTextFont.width(joined, font) <= width then
                    current = joined
                else
                    if current ~= "" then line(current); current = "" end
                    for _, code in utf8.codes(word) do
                        local char = utf8.char(code)
                        if SourceTextFont.width(current .. char, font) > width then
                            assert(current ~= "", "dialogue glyph wider than line")
                            line(current)
                            current = ""
                        end
                        current = current .. char
                    end
                end
                separator = following
            end
            line(current)
        end
        page()
    end
    return pages, advance, capacity
end
