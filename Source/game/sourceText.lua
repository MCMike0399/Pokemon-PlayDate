-- Semantic projection of the pinned English source charset. No model writes.
SourceText = {}

-- Existing # -> POKE policy deliberately preserves reviewed short dialogue.
local expansions <const> = {
    ["<PKMN>"] = "PKMN", ["<……>"] = "……", ["<PC>"] = "PC",
    ["<TM>"] = "TM", ["<TRAINER>"] = "TRAINER", ["<ROCKET>"] = "ROCKET",
    ["<COLON>"] = ":", ["<LV>"] = "Lv", ["<to>"] = "to", ["<ID>"] = "ID",
    ["<ED>"] = "ED", ["<PK>"] = "PK", ["<MN>"] = "MN", ["<DOT>"] = ".",
    ["<PAGE>"] = "\f", ["<PARA>"] = "\f", ["<LINE>"] = "\n",
    ["<NEXT>"] = "\n", ["<CONT>"] = "\n", ["<_CONT>"] = "\n", ["<SCROLL>"] = "\n",
}
local endings <const> = { ["<NULL>"] = true, ["<DONE>"] = true,
    ["<PROMPT>"] = true, ["<DEXEND>"] = true }

function SourceText.expand(text, values)
    assert(type(text) == "string" and utf8.len(text), "valid UTF-8 source text required")
    values = values or {}
    local result, index = {}, 1
    while index <= #text do
        local char = text:sub(index, index)
        if char == "<" then
            local finish = assert(text:find(">", index, true), "unterminated source token")
            local token = text:sub(index, finish)
            local value = expansions[token]
            if token == "<PLAYER>" then value = values.player or "RED"
            elseif token == "<RIVAL>" then value = values.rival or "BLUE"
            elseif token == "<TARGET>" then value = assert(values.target, "source TARGET text required")
            elseif token == "<USER>" then value = assert(values.user, "source USER text required")
            elseif token:match("^<BOLD_[A-ILMPSV]>$") then value = token:sub(7, 7)
            elseif endings[token] then
                assert(text:sub(finish + 1):match("^@?$"), "text after source terminator")
                break
            end
            assert(type(value) == "string" and utf8.len(value), "unsupported source token: " .. token)
            result[#result + 1] = value
            index = finish + 1
        elseif char == "@" then
            assert(index == #text, "text after source terminator")
            break
        elseif char == "#" then
            result[#result + 1] = "POKE"
            index = index + 1
        else
            local nextIndex = utf8.offset(text, 2, index) or (#text + 1)
            result[#result + 1] = text:sub(index, nextIndex - 1)
            index = nextIndex
        end
    end
    return table.concat(result)
end

-- charIndex stays a byte offset for existing diagnostics/controllers; each
-- published offset is nevertheless the end of a complete UTF-8 codepoint.
function SourceText.nextBoundary(text, index)
    if index >= #text then return #text end
    return (utf8.offset(text, 2, index + 1) or (#text + 1)) - 1
end

function SourceText.number(command, values)
    local symbol, bytes, digits = command:match("^text_decimal%s+(%w+),%s*(%d+),%s*(%d+)$")
    local bcd = false
    if not symbol then
        symbol, bytes = command:match("^text_bcd%s+(%w+),%s*(%d+)%s*|%s*LEADING_ZEROES%s*|%s*LEFT_ALIGN$")
        bcd = true
        digits = bytes and tonumber(bytes) * 2
    end
    assert(symbol, "unsupported numeric source control: " .. command)
    bytes, digits = tonumber(bytes), tonumber(digits)
    assert(bytes >= 1 and bytes <= 3 and digits >= 1 and digits <= 7, "bounded source number required")
    local value = values and values[symbol]
    local limit = bcd and (10 ^ (bytes * 2) - 1) or (256 ^ bytes - 1)
    assert(type(value) == "number" and value == math.floor(value) and value >= 0 and value <= limit,
        "confirmed source number required: " .. symbol)
    local text = tostring(math.floor(value))
    assert(#text <= digits, "source number exceeds display digits: " .. symbol)
    -- Source decimal fields are right aligned, BCD LEADING_ZEROES|LEFT_ALIGN
    -- suppresses leading zeroes and their padding (home/print_bcd.asm).
    return bcd and text or string.rep(" ", digits - #text) .. text
end
