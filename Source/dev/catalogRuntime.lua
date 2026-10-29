-- Trusted development exporter boundary, not an arbitrary-Lua sandbox.
CatalogRuntime={}
local gfx <const> = playdate.graphics
local function copy(source) local out={};for k,v in pairs(source) do out[k]=v end;return out end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" or getmetatable(a) or getmetatable(b) then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end;return true
end
CatalogRuntime.same=same
-- Defensive value snapshots plus original table nodes for narrowly supported
-- in-place restoration. Domain owners remain the original objects.
local function capture(value,seen,root)
    if type(value)~="table" then
        assert(value==nil or type(value)=="number" or type(value)=="string" or type(value)=="boolean","unsupported primitive observation")
        return value,{kind="scalar",value=value}
    end
    assert(root or getmetatable(value)==nil,"unsupported nested model object")
    seen=seen or {};assert(not seen[value],"cyclic model observation");seen[value]=true
    local values,node={},{kind="table",reference=value,entries={}}
    for key,item in pairs(value) do
        assert(type(key)=="string" or type(key)=="number","unsupported model key")
        local copied,child=capture(item,seen);values[key]=copied;node.entries[key]=child
    end
    seen[value]=nil;return values,node
end
local function restoreNode(node)
    if node.kind=="scalar" then return node.value end
    local target=node.reference
    for key in pairs(target) do target[key]=nil end
    for key,child in pairs(node.entries) do target[key]=restoreNode(child) end
    return target
end
local function models(session)
    if not session then return nil end
    local out={owner=session,party=session:party(),storage=session:storage(),bag=session:inventory(),
        active=session:party():activeIndex(),members=session:party():members(),boxes={},mons={},
        inventory=session:inventory():toData(),intro=session:getIntro(),flags=session:flags(),dex=session:pokedex(),
        location=session:location(),checkpoint=session:checkpoint(),world=session:worldData(),rng=session:rngData(),
        worldRng=session:worldRngData(),capturedActors=session:actorData()}
    local function mon(value)
        if not out.mons[value] then local values,node=capture(value,nil,true);out.mons[value]={values=values,node=node,metatable=getmetatable(value)} end
    end
    for _,value in ipairs(out.members) do mon(value) end
    for box=1,Storage.BOX_COUNT do
        out.boxes[box]={};for index=1,session:storage():count(box) do local value=session:storage():get(index,box);out.boxes[box][index]=value;mon(value) end
    end
    local state=game and game.machine:get("battle");local battle=state and state.battle
    if battle then
        out.battle=battle;out.battlePhase=battle:phase();out.battleSelection=battle.selectionKind
        out.battleConditions=battle:getConditionsSnapshot();out.battleEffects=battle.effects and battle.effects:snapshot()
        mon(battle.player);mon(battle.enemy)
        if battle.enemyParty then out.enemyMembers=battle.enemyParty:members();for _,value in ipairs(out.enemyMembers) do mon(value) end end
    end
    out.box=session:storage():activeBox();return out
end
local function restoreModels(before)
    if not before then return end
    for mon,record in pairs(before.mons) do setmetatable(mon,record.metatable);restoreNode(record.node) end
    if not same(before.inventory,before.bag:toData()) then assert(before.bag:_replaceData(before.inventory)) end
    if not same(before.intro,before.owner:getIntro()) then assert(before.owner:setIntro(before.intro)) end
    local current=before.owner:flags()
    -- Existing flags can be restored through public typed setters. New keys,
    -- dex changes and transfers have no public undo: observation reports them
    -- honestly as unsupported/unrestored instead of replacing live owners.
    for key,value in pairs(before.flags.quest) do if current.quest[key]~=value then assert(before.owner:setQuestFlag(key,value)) end end
    for key,value in pairs(before.flags.trainers) do if current.trainers[key]~=value then assert(before.owner:setTrainerDefeated(key,value)) end end
    if not same(before.location,before.owner:location()) or not same(before.world,before.owner:worldData()) or not same(before.checkpoint,before.owner:checkpoint()) then
        assert(before.owner:captureTraversal({location=before.location,world=before.world,checkpoint=before.checkpoint,actors=before.capturedActors}))
    end
    -- The session owns the separate world stream and captured DTO. This typed
    -- install validates before replacing either; it does not rewind the live
    -- NPCMotion private phase/interaction queues. Those changes remain an
    -- explicitly unsupported side effect, detected by motion:snapshot below.
    if not same(before.worldRng,before.owner:worldRngData()) or not same(before.capturedActors,before.owner:actorData()) then
        before.owner:_installWorldMotion({version=1,rng=before.worldRng,actors=before.capturedActors})
    end
end
local fields={"gridX","gridY","facing","isMoving","moveFrames","startPixelX","startPixelY","targetPixelX","targetPixelY","walkToggle","rustleFrames","pendingEdgeDoor","pendingConnection","isJumping","jumpOffset","groundPixelX","groundPixelY","arrowTimer","lastTraversalBlock"}
function CatalogRuntime.snapshot()
    local provider=WorldDeltas.definitionProvider and WorldDeltas.definitionProvider()
    local out={registry=zoneRegistry,zones=copy(zoneRegistry),list=zoneList,order=copy(zoneList),zone=currentZone,
        world=WorldDeltas.export(),provider=provider,cache=provider and provider:snapshot(),rng=RulesRNG.toData(),
        owner=GameSession.activeRNGSession(),story=Story.currentContext(),sprites={},actors={},palettes={},factory=SpriteFactory.npc,npcs={},game=game,
        session=game and game.session,models=models(game and game.session),controller=game and game.machine:stackNames(),generation=game and game.machine._generation}
    if game and game.npcManager and game.npcManager.motion then
        local motion=game.npcManager.motion;out.motion={owner=motion,pose=motion:snapshot()}
    end
    if game and game.camera then local values,node=capture(game.camera,nil,true);out.camera={owner=game.camera,values=values,node=node} end
    out.view=getOverworldView and getOverworldView()
    if out.view then local view=out.view;out.viewState={zone=view.zone,disposed=view.disposed,animTick=view.animTick,animStep=view.animStep,sprite=view.sprite,tilemap=view.tilemap,images=view.images,imageCount=view.imageCount} end
    out.offsetX,out.offsetY=gfx.getDrawOffset()
    out.displayX,out.displayY=playdate.display.getOffset()
    local palettes={[WorldTiles]=true};for _,zone in pairs(zoneRegistry) do palettes[zone.registry]=true end
    for registry in pairs(palettes) do out.palettes[registry]=registry:maxID() end
    for _,s in ipairs(gfx.sprite.getAllSprites()) do
        local cx,cy=s:getCenter();out.sprites[s]={x=s.x,y=s.y,image=s:getImage(),visible=s:isVisible(),enabled=s:updatesEnabled(),z=s:getZIndex(),cx=cx,cy=cy}
    end
    local function actor(a) if a then local values,nodes={},{};for _,key in ipairs(fields) do local value,node=capture(a[key]);values[key]=value;nodes[key]=node end;out.actors[a]={values=values,nodes=nodes} end end
    if game then actor(game.player);for _,npc in ipairs(game.npcManager.npcs) do actor(npc) end end
    for key,set in pairs(SpriteFactory.npc) do out.npcs[key]={set=set,images=copy(set)} end
    return out
end
local function diff(before)
    local after=CatalogRuntime.snapshot()
    for _,key in ipairs({"registry","zones","list","order","zone","world","provider","cache","rng","owner","story","sprites","actors","palettes","factory","npcs","game","session","models","motion","camera","view","viewState","controller","generation","offsetX","offsetY","displayX","displayY"}) do
        if not same(before[key],after[key]) then return key end
    end
end
function CatalogRuntime.guard(callback)
    local before=CatalogRuntime.snapshot()
    local rollback=WorldDeltas.checkpointRuntime and WorldDeltas.checkpointRuntime()
    local palettes={};for registry in pairs(before.palettes) do
        if registry~=WorldTiles and registry.checkpointRuntime then palettes[#palettes+1]=registry:checkpointRuntime() end
    end
    gfx.pushContext(gfx.image.new(400,240,gfx.kColorClear)) -- accidental unscoped drawing never reaches the live framebuffer
    gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local values=table.pack(pcall(callback))
    gfx.popContext()
    local observed,changed=pcall(diff,before);if not observed then changed="observation-error: "..tostring(changed) end
    if values[1] and not changed then return table.unpack(values,2,values.n) end
    local restored,problem=pcall(function()
        currentZone=before.zone;zoneRegistry=before.registry;zoneList=before.list
        if rollback then rollback() end
        for _,undo in ipairs(palettes) do undo() end
        if not same(zoneRegistry,before.zones) then
            for key in pairs(zoneRegistry) do zoneRegistry[key]=nil end;for key,value in pairs(before.zones) do zoneRegistry[key]=value end
        end
        if not same(zoneList,before.order) then
            for key in pairs(zoneList) do zoneList[key]=nil end;for key,value in pairs(before.order) do zoneList[key]=value end
        end
        if not same(WorldDeltas.export(),before.world) then WorldDeltas.apply(before.world) end
        game=before.game;if game then game.session=before.session end;Story.bind(before.story)
        if before.camera then game.camera=before.camera.owner;restoreNode(before.camera.node) end
        restoreModels(before.models)
        for actor,record in pairs(before.actors) do for _,key in ipairs(fields) do actor[key]=restoreNode(record.nodes[key]) end end
        local present={}
        for _,sprite in ipairs(gfx.sprite.getAllSprites()) do present[sprite]=true;if not before.sprites[sprite] then sprite:remove() end end
        for sprite,state in pairs(before.sprites) do
            if not present[sprite] then sprite:add() end;if sprite:getImage()~=state.image then sprite:setImage(state.image) end
            sprite:setCenter(state.cx,state.cy);sprite:moveTo(state.x,state.y);sprite:setZIndex(state.z)
            sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled)
        end
        SpriteFactory.npc=before.factory;for key in pairs(SpriteFactory.npc) do SpriteFactory.npc[key]=nil end
        for key,value in pairs(before.npcs) do
            SpriteFactory.npc[key]=value.set
            for direction in pairs(value.set) do value.set[direction]=nil end
            for direction,image in pairs(value.images) do value.set[direction]=image end
        end
        local active=GameSession.activeRNGSession()
        if active~=before.owner then if active then active:deactivateRNG() end;if before.owner then before.owner:activateRNG() end end
        assert(RulesRNG.restoreData(before.rng));gfx.setDrawOffset(before.offsetX,before.offsetY);playdate.display.setOffset(before.displayX,before.displayY)
    end)
    local checked,remaining=pcall(diff,before)
    if not restored then remaining=tostring(problem) elseif not checked then remaining="observation-error: "..tostring(remaining) end
    error((values[1] and "catalog exporter side effect: "..tostring(changed) or tostring(values[2]))
        ..(remaining and "; unrestored/unsupported state: "..tostring(remaining) or "; supported live state restored"),0)
end

-- Accepted base art plus every currently registered extension. Later regions
-- extend the inventory without changing the earlier regions' own assertions.
function CatalogRuntime.declaredImageCount(inventory)
    local count = 1635
    for _, exporter in pairs(inventory.exporters) do
        count = count + #exporter.images
    end
    return count
end
