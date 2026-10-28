-- Optional facade and read-only game observer. Import once; update after input.
import "audio/scores"
import "audio/engine"
KantoAudio = {}
local mapScore=nil
local inBattle=false
local observer={}
local aliases <const> = {
    pallet_town="pokered:PALLET_TOWN", reds_house="pokered:REDS_HOUSE_1F",
    reds_house_2f="pokered:REDS_HOUSE_2F", blues_house="pokered:BLUES_HOUSE",
    route_1="pokered:ROUTE_1", route1="pokered:ROUTE_1",
}
function KantoAudio.enterMap(zone)
    local id=type(zone)=="table" and zone.stableID or zone
    mapScore=KantoMusicMaps[aliases[id] or id]
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
    inBattle=false;mapScore=nil;observer={}
    KantoSynth.stop()
end

-- Read only the active stack and presentation fields. Never calls gameplay
-- getters, callbacks, RNG, or installs listeners. Keeps its own small snapshot.
local function visibleMenu(top)
    if not top then return end
    local menu=top.menu
    if menu and menu.isActive then return menu,menu.selectedIndex end
    local scene=top.name=="battle" and top.scene
    if scene then
        for _,key in ipairs({"moveMenu","mainMenu"}) do
            menu=scene[key]
            if menu and menu.isActive then return menu,menu.selectedIndex end
        end
    end
    if top.phase=="list" or top.phase=="swap" or top.phase=="browse" then
        if type(top.selected)=="number" then return top,top.selected end
    end
end

function KantoAudio.updateGame(game)
    local stack=game and game.machine and game.machine.stack
    local root=stack and stack[1]
    local top=stack and stack[#stack]
    if not root then
        if observer.root then KantoAudio.stop() end
        return
    end
    if observer.game~=game or observer.session~=game.session then
        KantoAudio.stop()
        observer.game,observer.session=game,game.session
    end
    if root.name=="title" then
        if observer.root~="title" then
            KantoAudio.stop()
            observer.game,observer.session=game,game.session
        end
    else
        -- World identity can change while the battle state is exiting. Remember
        -- the new destination before restoring field music.
        local zone=currentZone and currentZone.stableID
        if observer.root=="title" or observer.zone~=zone then
            KantoAudio.enterMap(zone)
            observer.zone=zone
        end
        local battleState
        for _,state in ipairs(stack) do
            if state.name=="battle" then battleState=state;break end
        end
        local battle=battleState and battleState.battle
        if battle~=observer.battle then
            observer.hp={}
            if battle then KantoAudio.battleStart(battle.trainerName and "trainer" or "wild")
            elseif observer.battle then KantoAudio.battleEnd() end
            observer.battle=battle
            observer.lowHP=nil
        end
        if battle then
            local hp=observer.hp
            local hit,faint=false,false
            for _,mon in ipairs({battle.player,battle.enemy}) do
                if type(mon.hp)=="number" then
                    local before=hp[mon]
                    if before and mon.hp<before then
                        hit=true
                        if mon.hp<=0 then faint=true end
                    end
                    hp[mon]=mon.hp
                end
            end
            local mon=battle.player
            local low=mon and type(mon.hp)=="number" and type(mon.maxHP)=="number"
                and mon.hp>0 and mon.hp*5<=mon.maxHP or false
            if low~=observer.lowHP then KantoAudio.setLowHP(low);observer.lowHP=low end
            if faint then KantoAudio.playSFX("faint")
            elseif hit then KantoAudio.playSFX("hit") end
        end
        local healing
        for _,state in ipairs(stack) do
            if state.phase=="heal-animation" then healing=state;break end
        end
        if healing and observer.healing~=healing then KantoAudio.playSFX("heal") end
        observer.healing=healing
    end
    local menu,cursor=visibleMenu(top)
    if menu and observer.root and (menu~=observer.menu or cursor~=observer.cursor) then
        KantoAudio.playSFX("menu")
    end
    observer.root=root.name
    observer.menu,observer.cursor=menu,cursor
    KantoAudio.update()
end
