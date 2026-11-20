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
local function pageBounds(dialog)
    for _, page in ipairs(dialog.lines) do
        local rows = 0
        for row in (page .. "\n"):gmatch("(.-)\n") do
            rows = rows + 1
            local count = utf8.len(row)
            assert(count and count <= 18, "horizontal clipping")
        end
        assert(rows <= 2, "vertical clipping")
    end
end

function SourceTextContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}, glyphs = {}}
    local function test(name, fn)
        Contracts.progress("source-text",name,"running")
        gfx.pushContext()
        gfx.setFont(gfx.getSystemFont())
        local textSpeed = GameOptions.textSpeed()
        local ok, problem = pcall(fn)
        GameOptions.set("textSpeed", textSpeed)
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
        equal(#pages, 2); equal(pages[1].text, "RED got ¥1386\nfor winning!")
        equal(pages[1].ending, "para"); equal(pages[2].ending, "done")
        equal(pages[1].receipt, true); equal(pages[1].source, "test.asm")
        equal(pages[2].text, "Found POKé BALL."); equal(pages[2].receipt, false)
        equal(SourceText.number("text_decimal hCount, 1, 3", {hCount = 7}), "  7")
        -- MESSAGE_BOX is two rows of 18. The padded count stays; the name wraps.
        local padded = Dialog(); padded:show({"Count:   7 POKéMON."})
        equal(#padded.lines, 1)
        equal(padded.lines[1], "Count:   7\nPOKéMON.")
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
                        local d = Dialog(); d:show({page.text})
                        pageBounds(d)
                        equal(compact(table.concat(d.lines, " ")), compact(page.text))
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
        -- MEDIUM reveals one character every two ticks. FAST deliberately
        -- reveals three, while this case witnesses every UTF-8 boundary.
        assert(GameOptions.set("textSpeed", "MEDIUM"))
        d:show({"é¥♂♀…"}, function() completed = completed + 1 end)
        for i = 1, 5 do
            d:update()
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
        local paragraph = "POKéMON ¥1000 " .. string.rep("complete words stay together. ", 8)
        local longWord = string.rep("é", 65)
        local text = paragraph .. "\fFinal paragraph.\n" .. longWord
        local d = Dialog(); d:show({text})
        pageBounds(d)
        local finalPage
        for i, page in ipairs(d.lines) do
            if page:find("Final", 1, true) then
                assert(not finalPage, "final paragraph duplicated")
                finalPage = i
            end
        end
        assert(finalPage and finalPage > 1, "paragraph must start a fresh page")
        -- Joining ordinary wrapped rows with spaces must preserve every word
        -- intact, including their order and punctuation.
        equal(compact(table.concat(d.lines, " ", 1, finalPage - 1)), compact(paragraph))
        local rows = {}
        for i = finalPage, #d.lines do
            for row in (d.lines[i] .. "\n"):gmatch("(.-)\n") do rows[#rows + 1] = row end
        end
        equal(rows[1], "Final paragraph.") -- explicit newline survives
        assert(utf8.len(longWord) > 18)
        assert(#rows > 2, "oversized word must wrap")
        -- Only the oversized word may split. Recover it without introducing
        -- spaces, and require every nonfinal fragment to fill the 18-tile row.
        for i = 2, #rows do
            assert(utf8.len(rows[i]) and utf8.len(rows[i]) > 0, "empty or partial UTF-8 fragment")
            equal((rows[i]:gsub("é", "")), "")
            if i < #rows then equal(utf8.len(rows[i]), 18) end
        end
        equal(table.concat(rows, "", 2), longWord)
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

    test("The message box is the two-line tile box with the prompt arrow", function()
        local text = "Hello, hello!\nI am the official"
        local d = Dialog(); d:show({{text = text, ending = "cont"}})
        equal(#d.lines, 1); equal(d.lines[1], text)
        d.charIndex = #text; d.blinkTimer = 0
        local actual = drawDialog(d)
        local expected = render(function()
            GbFont.drawBox(TitleIdle.textBox(0, 12, 18, 4))
            GbFont.drawString("Hello, hello!", 1, 14)
            GbFont.drawString("I am the official", 1, 16)
            GbFont.drawChar("▼", 18, 16)
        end)
        for y = 0, 239 do for x = 0, 399 do equal(actual:sample(x, y), expected:sample(x, y)) end end
        d.charIndex = 5
        local partial = drawDialog(d)
        local partialExpected = render(function()
            GbFont.drawBox(TitleIdle.textBox(0, 12, 18, 4))
            GbFont.drawString(text:sub(1, 5), 1, 14)
        end)
        for y = 0, 239 do for x = 0, 399 do equal(partial:sample(x, y), partialExpected:sample(x, y)) end end
        local function arrowInk(dialog)
            dialog:advance()
            local image = drawDialog(dialog)
            local blacks = 0
            for y = 16 * 13, 17 * 13 - 1 do for x = 18 * 20, 19 * 20 - 1 do
                if image:sample(x, y) == gfx.kColorBlack then blacks = blacks + 1 end
            end end
            return blacks
        end
        local prompt = Dialog(); prompt:show({{text = "Which POKEMON\nshould I look at?", ending = "prompt"}})
        assert(arrowInk(prompt) > 20, "prompt places the arrow")
        local paragraph = Dialog(); paragraph:show({{text = "That is a decent\nnickname!", ending = "para"}})
        assert(arrowInk(paragraph) > 20, "para places the arrow")
        local finished = Dialog(); finished:show({{text = "give a nickname\nto SQUIRTLE?", ending = "done"}})
        equal(arrowInk(finished), 0)
    end)

    test("The prompt arrow sits in the second line and drawing does not advance state", function()
        local d = Dialog(); d:show({"POKéMON"})
        d:advance()
        local index = d.charIndex
        local image = drawDialog(d)
        equal(d.charIndex, index); equal(d.currentLine, 1)
        for y = 0, 155 do for x = 0, 399 do
            equal(image:sample(x, y), gfx.kColorWhite)
        end end
        native(image, "source-text-symbols-complete")
    end)
    return report
end
