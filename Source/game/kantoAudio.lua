-- Small optional facade. Import once; root supplies gameplay hooks.
import "audio/scores"
import "audio/engine"
KantoAudio = {}
local mapScore=nil
local inBattle=false
local maps <const> = {
    pallet_town="pallet", reds_house="pallet", reds_house_2f="pallet", blues_house="pallet",
    ["pokered:PALLET_TOWN"]="pallet", ["pokered:REDS_HOUSE_1F"]="pallet",
    ["pokered:REDS_HOUSE_2F"]="pallet", ["pokered:BLUES_HOUSE"]="pallet",
    route_1="route1", route1="route1", ["pokered:ROUTE_1"]="route1",
}
function KantoAudio.enterMap(zone)
    local id=type(zone)=="table" and zone.stableID or zone
    mapScore=maps[id]
    if not inBattle then KantoSynth.music(mapScore) end
end
function KantoAudio.battleStart(kind)
    inBattle=true
    KantoSynth.lowHP(false)
    KantoSynth.music(kind=="trainer" and "trainer" or "wild")
end
function KantoAudio.battleEnd()
    inBattle=false
    KantoSynth.lowHP(false)
    KantoSynth.music(mapScore)
end
function KantoAudio.playSFX(name) return KantoSynth.sfx(name) end
function KantoAudio.setLowHP(flag) KantoSynth.lowHP(inBattle and flag==true) end
function KantoAudio.update() KantoSynth.update() end
function KantoAudio.stop()
    inBattle=false;mapScore=nil
    KantoSynth.stop()
end
