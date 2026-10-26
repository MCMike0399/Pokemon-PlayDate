-- SDK-only: real fonts, UTF-8, images, production adapter and Dialog.
-- Root owns execution and native PNG inspection; no fake SDK or Lua rewriting.
SourceTextContracts = {}
local gfx <const> = playdate.graphics
local function equal(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
local function rejects(fn) assert(not pcall(fn), "expected explicit source-text rejection") end
local function compact(text) return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")) end
local function native(image, name)
    if HarnessBuild and HarnessBuild.enabled and playdate.simulator then
        playdate.simulator.writeToFile(image, HarnessBuild.output_dir .. name .. ".png")
    end
end
local function render(fn)
    local image = assert(gfx.image.new(400, 240, gfx.kColorWhite))
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorBlack)
    local ok, problem = pcall(fn)
    gfx.popContext()
    assert(ok, problem)
    return image
end
local function drawDialog(dialog) return render(function() dialog:draw() end) end
local function pageBounds(dialog, font)
    local advance = font:getHeight() + font:getLeading()
    for _, page in ipairs(dialog.lines) do
        local y = 192
        for row in (page .. "\n"):gmatch("(.-)\n") do
            assert(SourceTextFont.width(row, font) <= 360, "horizontal clipping")
            assert(y + font:getHeight() <= 234, "vertical clipping")
            y = y + advance
        end
    end
end

function SourceTextContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}, glyphs = {}}
    local function test(name, fn)
        Contracts.progress("source-text",name,"running")
        gfx.pushContext()
        gfx.setFont(gfx.getSystemFont())
        local ok, problem = pcall(fn)
        gfx.popContext()
        Contracts.progress("source-text",name,"returned")
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end

    test("All English charmap tokens have explicit semantic expansion or required context", function()
        for _, token in ipairs(SourceTextFont.data().tokens) do
            local expanded = SourceText.expand(token, {target = "PIDGEY", user = "RED"})
            assert(not expanded:find("<", 1, true), token)
        end
        equal(SourceText.expand("#MON <PLAYER> <RIVAL>"), "POKEMON RED BLUE")
        equal(SourceText.expand("<PC> <TM> <……> <DOT>"), "PC TM …… .")
        equal(SourceText.expand("A<LINE>B<PARA>C@"), "A\nB\fC")
        rejects(function() SourceText.expand("<MISSING>") end)
        rejects(function() SourceText.expand("<TARGET>") end)
        rejects(function() SourceText.expand("first@discarded") end)
        rejects(function() SourceText.expand("bad" .. string.char(233)) end)
    end)

    test("Dynamic RAM and numeric recipes preserve words, receipts and metadata", function()
        local data = {source = "test.asm", recipe = {
            {op = "text", text = "<PLAYER> got ¥@"},
            {op = "control", source = "text_bcd wAmountMoneyWon, 3 | LEADING_ZEROES | LEFT_ALIGN"},
            {op = "line", text = "for winning!"},
            {op = "para", text = "Found @"}, {op = "text_ram", symbol = "wStringBuffer"},
            {op = "text", text = ".@"}, {op = "control", source = "done"},
        }}
        local function resolve() return data end
        local pages = EventText.pagesFrom({"money"}, resolve, {wAmountMoneyWon = 1386, wStringBuffer = "POKé BALL"})
        equal(#pages, 2); equal(pages[1].text, "RED got ¥1386 for winning!")
        equal(pages[1].receipt, true); equal(pages[1].source, "test.asm")
        equal(pages[2].text, "Found POKé BALL."); equal(pages[2].receipt, false)
        equal(SourceText.number("text_decimal hCount, 1, 3", {hCount = 7}), "  7")
        local padded = Dialog(); padded:show({"Count:   7 POKéMON."})
        equal(padded.lines[1], "Count:   7 POKéMON.")
        equal(SourceText.number("text_bcd hMoney, 3 | LEADING_ZEROES | LEFT_ALIGN", {hMoney = 0}), "0")
        rejects(function() EventText.pagesFrom({"money"}, resolve) end)
        rejects(function() SourceText.number("text_decimal hCount, 1, 3", {hCount = 256}) end)
        rejects(function() SourceText.number("text_decimal hCount, 1, 1", {hCount = 99}) end)
        rejects(function() SourceText.number("text_bcd hMoney, 3 | UNKNOWN", {hMoney = 7}) end)
    end)

    test("Current imported supported recipes all expand and paginate using actual SDK metrics", function()
        local count = 0
        for _, path in ipairs({"data/viridianSlice/dialogue.json", "data/pewterSlice/dialogue.json"}) do
            local data = assert(json.decodeFile(path))
            for label, record in pairs(data.texts) do
                local supported, values = true, {hOaksAideRequirement = 10, hOaksAideNumMonsOwned = 12,
                    hMoney = 200, wAmountMoneyWon = 1386}
                for _, row in ipairs(record.recipe) do
                    if row.op == "text_ram" then values[row.symbol] = "POKé BALL" end
                    if row.op == "control" and not (row.source == "done" or row.source == "prompt"
                        or row.source == "text_end" or row.source == "text_start"
                        or row.source:match("^text_decimal ") or row.source:match("^text_bcd ")) then supported = false end
                end
                local function make() return EventText.pagesFrom({label}, function() return record end, values) end
                if supported then
                    for _, page in ipairs(make()) do
                        local d = Dialog(); d:show({page.text .. " é"}) -- force measured path
                        pageBounds(d, gfx.getFont())
                        equal(compact(table.concat(d.lines, " ")), compact(page.text .. " é"))
                    end
                    count = count + 1
                else rejects(make) end -- source branches/ASM remain explicit failures
            end
        end
        assert(count > 150, "imported corpus not exercised")
    end)

    for char, entry in pairs(SourceTextFont.data().glyphs) do
        local name = string.format("Source glyph U+%04X matches pinned pixels", utf8.codepoint(char))
        test(name, function()
            local font = gfx.getFont()
            local image = render(function() SourceTextFont.draw(char, 0, 0, font) end)
            local top = math.floor((font:getHeight() - 16) / 2)
            local black = 0
            for y = 0, 15 do for x = 0, 15 do
                local expected = entry.rows[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1) == "#"
                equal(image:sample(x, y + top), expected and gfx.kColorBlack or gfx.kColorWhite)
                if expected then black = black + 1 end
            end end
            assert(black > 0, "empty fallback: " .. char)
            report.glyphs[#report.glyphs + 1] = {character = char, codepoint = utf8.codepoint(char),
                source_fallback = true, fallback_pixels = black}
        end)
    end
    test("Native contact sheets label every source fallback glyph", function()
        equal(#report.glyphs, 33)
        table.sort(report.glyphs, function(a, b) return a.codepoint < b.codepoint end)
        for first = 1, #report.glyphs, 10 do
            local image = render(function()
                for index = first, math.min(first + 9, #report.glyphs) do
                    local item = report.glyphs[index]
                    local y = (index - first) * 23
                    gfx.drawText(string.format("U+%04X", item.codepoint), 8, y)
                    SourceTextFont.draw(item.character, 150, y, gfx.getFont())
                    gfx.drawText("source 2x", 190, y)
                end
            end)
            native(image, "source-text-glyphs-" .. first)
        end
    end)

    test("Every English literal/contraction renders under system and existing battle fonts", function()
        for _, font in ipairs({gfx.getSystemFont(), assert(gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold"))}) do
            gfx.setFont(font)
            for _, literal in ipairs(SourceTextFont.data().literals) do
                local text = SourceText.expand(literal)
                assert(SourceTextFont.width(text, font) <= 360)
                render(function() SourceTextFont.draw(text, 0, 0, font) end)
            end
        end
    end)

    test("UTF-8 typewriter publishes only complete characters and A reveals then advances once", function()
        local d, completed = Dialog(), 0
        d:show({"é¥♂♀…"}, function() completed = completed + 1 end)
        for i = 1, 5 do
            d:update()
            equal(utf8.len(d.lines[1]:sub(1, d.charIndex)), i)
            native(drawDialog(d), "source-text-typing-" .. i)
        end
        equal(d.charIndex, #d.lines[1]); equal(completed, 0)
        d:advance(); equal(completed, 1); d:advance(); equal(completed, 1)
        d:show({"é¥♂♀…"}, function() completed = completed + 1 end)
        d:advance(); equal(d.isActive, true); equal(d.charIndex, #d.lines[1])
        d:advance(); equal(completed, 2)
    end)

    test("Long paragraphs, explicit breaks and oversized words retain all content with unclipped pages", function()
        local text = "POKéMON ¥1000 " .. string.rep("complete words stay together. ", 8)
            .. "\fFinal paragraph.\n" .. string.rep("é", 65)
        local d = Dialog(); d:show({text})
        pageBounds(d, gfx.getFont())
        equal(compact(table.concat(d.lines, " ")), compact(text))
        assert(#d.lines >= 4)
        for i, page in ipairs(d.lines) do
            d.currentLine = i; d.charIndex = #page; d.blinkTimer = 0
            native(drawDialog(d), "source-text-pages-" .. i)
        end
        local completed = 0
        d:show({text}, function() completed = completed + 1 end)
        local total = #d.lines
        for i = 1, total do
            equal(d.currentLine, i)
            d:advance() -- reveal this page, keep ownership
            equal(d.currentLine, i); equal(d.isActive, true); equal(completed, 0)
            d:advance() -- acknowledge exactly this page
        end
        equal(d.isActive, false); equal(completed, 1)
    end)

    test("Short ordinary dialog remains pixel identical to the original renderer", function()
        for _, text in ipairs({"Hello, RED!", "RED learned EMBER!", "Choose a POKEMON.",
            "OAK: Ah! CHARMANDER! This one is really energetic!"}) do
            local d = Dialog(); d:show({text})
            equal(#d.lines, 1); equal(d.legacy[1], true)
            for _, index in ipairs({1, #text}) do
                d.charIndex = index
                local actual = drawDialog(d)
                local expected = render(function()
                    gfx.setColor(gfx.kColorBlack); gfx.fillRect(0, 180, 400, 60)
                    gfx.setColor(gfx.kColorWhite); gfx.fillRect(4, 184, 392, 52)
                    gfx.setColor(gfx.kColorBlack); gfx.drawRect(4, 184, 392, 52)
                    gfx.drawTextInRect(text:sub(1, index), 14, 192, 372, 42)
                    if index == #text then gfx.drawText("v", 380, 220) end
                end)
                for y = 0, 239 do for x = 0, 399 do equal(actual:sample(x, y), expected:sample(x, y)) end end
            end
        end
    end)

    test("Extended pages reserve a readable advance gutter and drawing does not advance state", function()
        local d = Dialog(); d:show({"POKéMON ¥999999 ♂ ♀ …"})
        d:advance()
        local index = d.charIndex
        local image = drawDialog(d)
        equal(d.charIndex, index); equal(d.currentLine, 1)
        for y = 0, 239 do for x = 0, 399 do
            if y < 180 then equal(image:sample(x, y), gfx.kColorWhite) end
        end end
        equal(image:sample(383, 229), gfx.kColorBlack)
        equal(image:sample(387, 229), gfx.kColorWhite)
        native(image, "source-text-symbols-complete")
    end)
    return report
end
