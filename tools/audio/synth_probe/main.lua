import "CoreLibs/graphics"
import "game/kantoAudio"
local sound <const> = playdate.sound
playdate.display.setRefreshRate(30)
local start=sound.getCurrentTime()
local cursor=1
local finished=false
local events={
    {3,"Bulbasaur cry",function() assert(KantoAudio.playCry("bulbasaur")) end},
    {12,"Pikachu cry",function() assert(KantoAudio.playCry("pikachu")) end},
    {20,"Jynx cry",function() assert(KantoAudio.playCry("jynx")) end},
    {34,"Mr Mime cry",function() assert(KantoAudio.playCry("mr")) end},
    {46,"Zapdos cry",function() assert(KantoAudio.playCry("zapdos")) end},
    {0,"Pallet",function() KantoAudio.enterMap("pallet_town") end},
    {6,"Menu over Pallet",function() KantoAudio.playSFX("menu") end},
    {9,"Route 1",function() KantoAudio.enterMap("pokered:ROUTE_1") end},
    {18,"Wild battle",function() KantoAudio.battleStart("wild") end},
    {23,"Damage",function() KantoAudio.playSFX("hit") end},
    {25,"Faint",function() KantoAudio.playSFX("faint") end},
    {27,"Low HP on",function() KantoAudio.setLowHP(true) end},
    {30,"Low HP off",function() KantoAudio.setLowHP(false) end},
    {32,"Trainer battle",function() KantoAudio.battleStart("trainer") end},
    {41,"Vermilion return",function() KantoAudio.enterMap("pokered:VERMILION_CITY"); KantoAudio.battleEnd() end},
    {43,"Center heal",function() KantoAudio.playSFX("heal") end},
    {48,"S.S. Anne",function() KantoAudio.enterMap("pokered:SS_ANNE_1F") end},
}
table.sort(events, function(a, b) return a[1] < b[1] end)
local observations={}
local function publish(status,message)
    if finished then return end
    finished=true
    KantoAudio.stop()
    local result={identity=ProbeIdentity,status=status,message=message,
        publication="producer-stopped-v1",quiescent=true,observations=observations,
        system_volume=playdate.getSystemVolume(),
        acceptance="native API exercise only; listening acceptance pending"}
    local f=assert(playdate.file.open("RuntimeSnapshot.json",playdate.file.kFileWrite))
    f:write(json.encode(result));f:close()
    local done=assert(playdate.file.open("done.json",playdate.file.kFileWrite))
    done:write(json.encode(result));done:close()
end
function playdate.update()
    if finished then return end
    local ok,message=pcall(function()
        if playdate.file.exists("cancel.json") then publish("cancelled");return end
        local now=sound.getCurrentTime()-start
        while events[cursor] and now>=events[cursor][1] do
            local event=events[cursor]
            event[3]()
            observations[#observations+1]={scheduled=event[1],actual=now,label=event[2]}
            print(string.format("audio %.3f %s",now,event[2]))
            cursor=cursor+1
        end
        KantoAudio.update()
        playdate.graphics.clear()
        playdate.graphics.drawText("Kanto native synth listening packet",12,15)
        playdate.graphics.drawText(events[math.max(1,cursor-1)][2],12,45)
        playdate.graphics.drawText(string.format("%.1f / 54 seconds",now),12,75)
        if now>=54 then publish("complete") end
    end)
    if not ok then publish("error",tostring(message)) end
end
