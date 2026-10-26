-- Source recipes produce semantic paragraphs; Dialog owns measured pagination.
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
        local raw, space = "", false
        local function flush()
            if #raw > 0 then
                local player = ram and ram.player or "RED"
                local receipt = raw:find(player .. " got", 1, true)
                    or raw:find(player .. " received", 1, true)
                    or raw:find(player .. " delivered", 1, true)
                pages[#pages + 1] = {label = label, text = raw, receipt = receipt ~= nil, source = record.source}
            end
            raw, space = "", false
        end
        for _, row in ipairs(record.recipe) do
            if row.op == "para" then
                flush()
                raw = SourceText.expand(row.text, ram)
            elseif row.op == "line" or row.op == "cont" or row.op == "next" then
                -- Original 18-column line breaks reflow to Playdate words.
                -- A terminator-only line reserves separation for dynamic RAM.
                if row.text == "@" then
                    space = true
                else
                    raw = raw .. (#raw > 0 and " " or "") .. SourceText.expand(row.text, ram)
                end
            elseif row.op == "text" then
                raw = raw .. SourceText.expand(row.text, ram)
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
                raw = raw .. (space and " " or "") .. supplied
                space = false
            elseif row.op == "control" then
                if row.source:match("^text_decimal%s") or row.source:match("^text_bcd%s") then
                    raw = raw .. (space and " " or "") .. SourceText.number(row.source, ram)
                    space = false
                else
                    assert(row.source == "done" or row.source == "prompt"
                        or row.source == "text_end" or row.source == "text_start",
                        "unsupported event text control: " .. tostring(row.source))
                end
            else
                error("unsupported source text operation: " .. tostring(row.op))
            end
        end
        flush()
    end
    assert(#pages <= 64, "event dialogue page limit")
    return pages
end

function EventText.pages(labels)
    return EventText.pagesFrom(labels, function(label) return source()[label] end)
end
