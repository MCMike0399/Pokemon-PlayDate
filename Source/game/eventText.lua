-- text, line, and next fill the two rows of the message box. cont scrolls
-- the second row up and keeps writing. para clears the box. Dialog draws
-- those rows; it does not join them back into a paragraph.
EventText = {}
local cached
local function source()
    if not cached then
        cached = assert(json.decodeFile("data/viridianSlice/dialogue.json"))
        assert(cached.schema == 1 and cached.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified event dialogue")
    end
    return cached.texts
end

function EventText.pagesFrom(labels, resolver, ram)
    assert(type(resolver) == "function", "explicit immutable text resolver required")
    assert(type(labels) == "table" and #labels > 0 and #labels <= 12, "bounded dialogue labels required")
    local pages = {}
    for _, label in ipairs(labels) do
        local record = assert(resolver(label), "missing source dialogue: " .. tostring(label))
        local line1, line2, slot, ending = "", "", 1, nil
        local function pageText()
            if line1 == "" and line2 == "" then return nil end
            if line2 == "" then return line1 end
            return line1 .. "\n" .. line2
        end
        local function close(reason)
            local text = pageText()
            local use = reason or ending or "done"
            ending = nil
            if not text then return end
            local player = ram and ram.player or "RED"
            local flat = text:gsub("\n", " ")
            local receipt = flat:find(player .. " got", 1, true)
                or flat:find(player .. " received", 1, true)
                or flat:find(player .. " delivered", 1, true)
            pages[#pages + 1] = {label = label, text = text, ending = use,
                receipt = receipt ~= nil, source = record.source}
        end
        local function append(text)
            if text == "" then return end
            if slot == 1 then line1 = line1 .. text else line2 = line2 .. text end
        end
        local function breakLine()
            slot = 2
        end
        for _, row in ipairs(record.recipe) do
            if row.op == "para" then
                -- Paragraph places ▼, waits, then clears the box.
                close("para")
                line1, line2, slot = "", "", 1
                if row.text ~= "@" then append(SourceText.expand(row.text, ram)) end
            elseif row.op == "cont" then
                -- _ContText places ▼, waits, then scrolls the second row up.
                local kept = line2
                close("cont")
                line1, line2, slot = kept, "", 2
                if row.text ~= "@" then append(SourceText.expand(row.text, ram)) end
            elseif row.op == "line" or row.op == "next" then
                -- <LINE> and <NEXT> both land on the second row without waiting.
                breakLine()
                if row.text ~= "@" then append(SourceText.expand(row.text, ram)) end
            elseif row.op == "text" then
                append(SourceText.expand(row.text, ram))
            elseif row.op == "text_ram" then
                local supplied = ram and ram[row.symbol]
                if supplied == nil then
                    assert(row.symbol == "wStringBuffer" and label == "_Route1Youngster1GotPotionText",
                        "unresolved source RAM token: " .. tostring(row.symbol))
                    supplied = ItemData.definitions.potion.name
                end
                assert(type(supplied) == "string" and utf8.len(supplied) and #supplied <= 128,
                    "bounded source text RAM value required")
                -- Resolved RAM is literal display text, never another program.
                append(supplied)
            elseif row.op == "control" then
                if row.source:match("^text_decimal%s") or row.source:match("^text_bcd%s") then
                    append(SourceText.number(row.source, ram))
                elseif row.source == "prompt" then
                    ending = "prompt"
                elseif row.source == "done" or row.source == "text_end" then
                    ending = "done"
                else
                    assert(row.source == "text_start",
                        "unsupported event text control: " .. tostring(row.source))
                end
            else
                error("unsupported source text operation: " .. tostring(row.op))
            end
        end
        close()
    end
    assert(#pages <= 64, "event dialogue page limit")
    return pages
end

function EventText.pages(labels)
    return EventText.pagesFrom(labels, function(label) return source()[label] end)
end
