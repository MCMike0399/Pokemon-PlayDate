-- Field-only item owner: typed ephemeral requests, retained session identities.
FieldItems={}
local requests=setmetatable({},{__mode="k"})
local sourceData
local function data()
    if not sourceData then
        sourceData=assert(json.decodeFile("data/fieldItems.json"))
        assert(sourceData.schema==1 and sourceData.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified field item definitions")
    end
    return sourceData
end
local function copy(v)return Party._primitive(v)end
local function equal(a,b)
    if type(a)~=type(b)then return false end
    if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not equal(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end
    return true
end
local function position(game)return {zone_id=currentZone.stableID,x=game.player.gridX,y=game.player.gridY,facing=game.player.facing}end
local function bagBoundary(game,bag)
    local world=game.machine:get("overworld");local player=game.player
    return game.machine:current()==bag and game.machine:depth()==2 and game.machine.stack[1]==world
        and bag.active and bag.session==game.session and not bag.battle and not bag.options.mode and not bag.options.trySelect
        and world.sub:getCurrent()=="explore"and player and not player.isMoving and not player.isJumping
        and not player.pendingEdgeDoor and not player.pendingConnection and not player.stepJustFinished
end
local function zoneKey(id)
    for key,zone in pairs(zoneRegistry)do if zone.stableID==id then return key end end
    return WorldDeltas.zoneKey(id)
end
function FieldItems.canEscape(id)
    if type(id)~="string"then return false end
    local d=data();local symbol=d.aliases[id]or id:match("^pokered:(.+)$")
    if symbol=="AGATHAS_ROOM"then return false end
    local tileset=symbol and d.tilesets[symbol]
    return tileset=="FOREST"or tileset=="CEMETERY"or tileset=="CAVERN"or tileset=="FACILITY"or tileset=="INTERIOR"
end
function FieldItems.prepareEscape(game,bag)
    if not bagBoundary(game,bag)then return nil,"field-only"end
    if not FieldItems.canEscape(currentZone.stableID)then return nil,"not-usable-here"end
    local session=game.session;local inventory=session:inventory()
    if inventory:quantity("escapeRope")<1 then return nil,"insufficient-items"end
    local world;local target=session:checkpoint()
    local ok,result=pcall(function()
        local deps=game:getSessionDependencies();world=deps.validateWorld(WorldDeltas.export())
        local checkpoint=copy(target)
        target=deps.resolveLocation(copy(target),copy(world))
        assert(equal(target,checkpoint),"checkpoint resolver relocated destination")
        local descriptor=SourceActors.describe(target.zone_id,world)
        local actors=descriptor and WorldMotionData.reconcile(nil,descriptor,session:flags())or WorldMotionData.empty()
        actors=GameSession._validateActors(deps,actors,world,target,session:flags())
        local key=assert(zoneKey(target.zone_id),"checkpoint not installed/supported")
        local detached=assert(Inventory.fromData(GameSession._state(session).deps.itemDefinitions,inventory:toData()))
        assert(detached:consume("escapeRope",1))
        return {key=key,world=copy(world),target=copy(target),actors=actors,bagAfter=detached:toData()}
    end)
    if not ok then return nil,"invalid-checkpoint:"..tostring(result)end
    local request={};result.game,result.session,result.inventory=game,session,inventory
    result.bag,result.visit,result.player,result.zone=bag,bag.visit,game.player,currentZone
    result.origin,result.before,result.checkpoint=position(game),inventory:toData(),session:checkpoint()
    result.flags,result.rules,result.worldRng=session:flags(),RulesRNG.toData(),session:worldRngData()
    result.status="pending";requests[request]=result
    return request
end
function FieldItems.cancel(request)
    local p=requests[request]
    if not p or p.status~="pending"then return false,"stale-selection"end
    p.status="cancelled";return true
end
local function valid(p)
    return p and p.status=="pending"and p.game.session==p.session and p.session:inventory()==p.inventory
        and p.game.player==p.player and currentZone==p.zone and p.bag.visit==p.visit and not p.game.machine._transitioning and bagBoundary(p.game,p.bag)
        and equal(position(p.game),p.origin)and equal(p.inventory:toData(),p.before)and equal(p.session:checkpoint(),p.checkpoint)and equal(p.session:flags(),p.flags)
        and equal(WorldDeltas.export(),p.world)and equal(RulesRNG.toData(),p.rules)and equal(p.session:worldRngData(),p.worldRng)
end
function FieldItems._commit(session,request)
    local p=requests[request]
    if not p or p.status~="transporting"or not p.readyToCommit or p.game.machine._transitioning or p.game.machine:getCurrent()~="overworld"or p.game.machine:depth()~=1 or p.session~=session or p.game.session~=session
        or p.inventory~=session:inventory()or not equal(p.inventory:toData(),p.before)
        or not equal(session:checkpoint(),p.checkpoint)or not equal(session:flags(),p.flags)
        or not equal(RulesRNG.toData(),p.rules)or not equal(session:worldRngData(),p.worldRng)then return false,"stale-selection"end
    if not equal(position(p.game),p.target)then return false,"wrong-arrival"end
    local current=GameSession._state(session)
    local ok,prepared=pcall(function()
        local world=current.deps.validateWorld(WorldDeltas.export())
        local location=current.deps.resolveLocation(copy(p.target),copy(world))
        assert(equal(location,p.target),"checkpoint resolver relocated destination")
        local actors=GameSession._validateActors(current.deps,p.game.npcManager.motion:snapshot(),world,location,session:flags())
        -- Detached validation is complete before the retained Inventory commit.
        local bag=assert(Inventory.fromData(current.deps.itemDefinitions,p.bagAfter))
        return {bag=bag:toData(),world=copy(world),location=copy(location),actors=actors,result={kind="escape-rope",destination=copy(location),consumed=1}}
    end)
    if not ok then return false,tostring(prepared)end
    local accepted,reason=p.inventory:_replaceData(prepared.bag)
    if not accepted then return false,reason end
    current.world,current.location,current.currentActors=prepared.world,prepared.location,prepared.actors
    p.status="complete"
    return true,prepared.result
end
function FieldItems.useEscape(game,request)
    local p=requests[request]
    if type(request)~="table"or getmetatable(request)~=nil or next(request)~=nil then return false,"stale-selection"end
    local checked,current=pcall(valid,p)
    if not checked or not current or p.game~=game then return false,"stale-selection"end
    local checkpointed,undo=pcall(WorldDeltas.checkpointRuntime)
    if not checkpointed then return false,"runtime-preflight-failed"end
    local previous={zone=currentZone,position=position(game),actors=game.npcManager.motion:snapshot(),rules=RulesRNG.toData(),worldRng=game.session:worldRngData()}
    p.status="transporting"
    local ok,result=pcall(function()
        switchZone(p.key)
        game.machine:change("overworld",{entry={x=p.target.x,y=p.target.y,facing=p.target.facing},actors=p.actors})
        p.readyToCommit=true
        local accepted,receipt=game.session:useEscapeRope(request)
        assert(accepted,receipt)
        return receipt
    end)
    if ok then game.lastFieldItem=result;return true,result end
    p.status="failed"
    local restored,problem=pcall(function()
        undo();currentZone=previous.zone
        RulesRNG.restoreData(previous.rules);GameSession._state(p.session).worldRng:restoreData(previous.worldRng)
        game.machine:change("overworld",{entry={x=previous.position.x,y=previous.position.y,facing=previous.position.facing},actors=previous.actors})
    end)
    game.lastFieldItem={kind="escape-rope",ok=false,reason=tostring(result),restored=restored,rollback_error=not restored and tostring(problem)or nil}
    return false,"transition-failed"
end
function FieldItems.confirmEscape(bag)
    local request,reason=FieldItems.prepareEscape(bag.game,bag)
    if not request then bag:showMessage("That item can't be used here.");return false,reason end
    local visit,session=bag.visit,bag.session
    bag.fieldRequest=request;bag.phase="field-confirm"
    local function current()return bag.active and bag:isTop()and bag.visit==visit and bag.game.session==session end
    bag.menu:show({"NO","YES"},function(choice)
        if not current()then return false,"stale-selection"end
        bag.fieldRequest=nil
        if choice~=2 then FieldItems.cancel(request);bag.phase="list";bag.menu:hide();return end
        local ok,why=FieldItems.useEscape(bag.game,request)
        if not ok then
            if current()then bag:showMessage("That item could not be used.")
            elseif bag.game.machine:getCurrent()=="overworld"then bag.game.machine:push("dialog",{"That item could not be used."})end
        end
        return ok,why
    end,function()
        if not current()then return end
        FieldItems.cancel(request);bag.fieldRequest=nil;bag.phase="list";bag.menu:hide()
    end)
    return true
end
function FieldItems.tryDaisy(game)
    if currentZone.stableID~="blues_house"then return false end
    local x,y=game.player:getFacingTile();local npc=game.npcManager:getNPCAt(x,y)
    if not npc or npc.name~="Daisy"then return false end
    if game.machine:getCurrent()~="overworld"or game.machine:depth()~=1 or game.player.isMoving then return true end
    npc:faceTowards(game.player.gridX,game.player.gridY)
    local session=game.session
    if session:questFlag("EVENT_GOT_TOWN_MAP")then game.machine:push("dialog",{"Use the TOWN MAP to find out where you are."});return true end
    if not session:questFlag("EVENT_GOT_POKEDEX")then game.machine:push("dialog",{"Hi RED! BLUE is out at Grandpa's lab."});return true end
    game.machine:push("dialog",{"Grandpa asked you to run an errand? Here, this will help you!"},function()
        if game.session~=session or currentZone.stableID~="blues_house"or game.machine:getCurrent()~="overworld"or game.machine:depth()~=1
            or game.npcManager:getNPCAt(x,y)~=npc then return false,"stale-selection"end
        local ok,reason=session:transact({flags={EVENT_GOT_POKEDEX=true,EVENT_GOT_TOWN_MAP=false},items={townMap=0}},
            {flags={EVENT_GOT_TOWN_MAP=true},items={{op="add",id="townMap",quantity=1}}})
        if ok then game.machine:push("dialog",{"RED got a TOWN MAP!"})
        elseif reason=="bag-full"then game.machine:push("dialog",{"You have too much stuff with you."})end
        return ok,reason
    end)
    return true
end
