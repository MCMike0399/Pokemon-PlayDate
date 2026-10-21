-- Bounded source-text adapter, not a replacement for the game dialogue system.
EventText={}
local cached
local function source()
    if not cached then
        cached=assert(json.decodeFile("data/viridianSlice/dialogue.json"))
        assert(cached.schema==1 and cached.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified event dialogue")
    end
    return cached.texts
end
local function words(text)
    text=text:gsub("<PLAYER>","RED"):gsub("<RIVAL>","BLUE"):gsub("#","POKE"):gsub("@","")
    assert(not text:find("<[^>]+>"),"unresolved source text token")
    return text
end
function EventText.pagesFrom(labels,resolver,ram)
    assert(type(resolver)=="function","explicit immutable text resolver required")
    assert(type(labels)=="table" and #labels>0 and #labels<=12,"bounded dialogue labels required")
    local pages={}
    for _,label in ipairs(labels) do
        local record=assert(resolver(label),"missing source dialogue: "..tostring(label))
        local raw,space="",false
        local function flush()
            if #raw>0 then
                local receipt=raw:find("<PLAYER> got",1,true) or raw:find("<PLAYER> received",1,true) or raw:find("<PLAYER> delivered",1,true)
                pages[#pages+1]={label=label,text=words(raw),receipt=receipt~=nil,source=record.source}
            end
            raw,space="",false
        end
        for _,row in ipairs(record.recipe) do
            if row.op=="para" then flush();raw=row.text
            elseif row.op=="line" or row.op=="cont" or row.op=="next" then
                if row.text~="@" then raw=raw..(#raw>0 and " " or "")..row.text else space=true end
            elseif row.op=="text" then raw=raw..row.text
            elseif row.op=="text_ram" then
                local supplied=ram and ram[row.symbol]
                if supplied==nil then
                    assert(row.symbol=="wStringBuffer" and label=="_Route1Youngster1GotPotionText","unresolved source RAM token")
                    supplied=ItemData.definitions.potion.name
                end
                assert(type(supplied)=="string" and #supplied<=128,"bounded source text RAM value required")
                raw=raw..(space and " " or "")..supplied;space=false
            elseif row.op=="control" then
                if label=="_MoneyForWinningText" and row.source=="text_bcd wAmountMoneyWon, 3 | LEADING_ZEROES | LEFT_ALIGN" then
                    assert(ram and Party._integer(ram.wAmountMoneyWon,0,Inventory.MONEY_LIMIT),"confirmed trainer money text required")
                    raw=raw..tostring(ram.wAmountMoneyWon)
                else assert(row.source=="done" or row.source=="prompt" or row.source=="text_end" or row.source=="text_start","unsupported event text control") end
            else error("unsupported source text operation: "..tostring(row.op)) end
        end
        flush()
    end
    assert(#pages<=64,"event dialogue page limit")
    return pages
end

function EventText.pages(labels)
    return EventText.pagesFrom(labels,function(label)return source()[label]end)
end
