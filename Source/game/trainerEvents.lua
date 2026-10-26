-- Cohesive trainer progression/temporary encounter owner. Session owns all
-- durable flags/money; native EventState owns the bounded approach lifecycle.
Class("TrainerEvents")
local owners=setmetatable({},{__mode="k"})
local tokens=setmetatable({},{__mode="k"})
local BROCK <const> = "pokered:PEWTER_GYM:objects:1"
local JR <const> = "pokered:PEWTER_GYM:objects:2"
local LAB <const> = "authored:oaks_lab:npc:2"
local vectors={up={0,-1},down={0,1},left={-1,0},right={1,0}}
local function copy(v) return GameSession._copy(v) end
local function info(self,token)
    local owner=assert(owners[self]);local value=tokens[token]
    if not value or value.owner~=self or owner.active~=token or value.session~=owner.game.session then return nil,"stale-trainer-encounter" end
    return value
end
local function idOf(npc) return npc and (npc.trainerID or npc.def and npc.def.source_event_id) end
local function definition(self,id)
    local owner=owners[self]
    if id==LAB then
        if owner.game.session:getIntro().stage~="rival_fight" or currentZone.stableID~="oaks_lab" then return nil end
        return {id=LAB,payout=175,initial_lab=true,talk_only=true,party={{species=assert(owner.game.session:getIntro().rivalStarter),level=5}},name="BLUE"}
    end
    local d=owners[self].definitions[id]
    if d then
        d = copy(d)
        -- Resolve from the actual session starter into this encounter's private
        -- definition. prepare() freezes it in its opaque token before any RNG.
        if d.rival_parties then
            local variant = assert(d.rival_parties[owner.game.session:getIntro().starter],
                "rival encounter requires the session starter")
            assert(Party._array(variant.party, 6) and #variant.party > 0,
                "bounded rival team required")
            for _, mon in ipairs(variant.party) do
                assert(pokemonData[mon.species] and Party._integer(mon.level, 1, 100),
                    "invalid rival team")
            end
            assert(Party._integer(variant.payout, 0, Inventory.MONEY_LIMIT), "invalid rival payout")
            d.party, d.payout = copy(variant.party), variant.payout
            d.rival_parties = nil
        end
    end
    return d
end
function TrainerEvents:init(game)
    assert(game and game.session and game.npcManager,"authoritative trainer context required")
    owners[self]={game=game,definitions=SourceEvents.trainerDefinitions()}
end
function TrainerEvents:sourceFlag(id)
    local game=owners[self].game
    if owners[self].definitions[id] then return game.session:trainerDefeated(id) end
    for stable,d in pairs(owners[self].definitions) do if d.source_flag==id then return game.session:trainerDefeated(stable) end end
    return game.session:questFlag(id)
end
function TrainerEvents:definition(id) return definition(self,id) end
function TrainerEvents:approach(npc,mode)
    local game=owners[self].game;local player=game.player;local d=definition(self,idOf(npc))
    if not d then return nil,"unsupported-trainer" end
    if game.session:trainerDefeated(d.id) then return nil,"already-defeated" end
    if not d.initial_lab and currentZone.stableID~=d.map_id then return nil,"wrong-source-trainer-zone" end
    if not player or player.isMoving or player.pendingEdgeDoor or player.pendingConnection or npc.isMoving then return nil,"movement-active" end
    if game.npcManager:getNPCAt(npc.gridX,npc.gridY)~=npc then return nil,"absent-trainer" end
    local dx,dy=player.gridX-npc.gridX,player.gridY-npc.gridY
    local distance=math.abs(dx)+math.abs(dy)
    if mode=="talk" then
        if distance~=1 then return nil,"trainer-not-adjacent" end
        return {}
    end
    if mode~="sight" or d.talk_only then return nil,"trainer-has-no-sight" end
    local direction=vectors[npc.facing]
    if not direction or distance<1 or distance>d.sight_range_cells or dx~=direction[1]*distance or dy~=direction[2]*distance then return nil,"outside-source-sight" end
    if npc.x-game.camera.x>=400 or npc.x-game.camera.x+32<=0 or npc.y-game.camera.y>=240 or npc.y-game.camera.y+32<=0 then return nil,"trainer-offscreen" end
    local steps={}
    local descriptor
    local name = SourceMaps.nameForID(currentZone.stableID)
    if name and SourceMaps.entry(name).profile == "source" then
        descriptor = SourceActors.describe(currentZone.stableID, WorldDeltas.export())
    end
    for i=1,distance-1 do
        local x,y=npc.gridX+direction[1]*i,npc.gridY+direction[2]*i
        if y<0 or x<0 or y>=currentZone.height or x>=currentZone.width or currentZone.collision[y+1][x+1]~=0 then return nil,"blocked-trainer-approach" end
        if descriptor and descriptor.protected[y * currentZone.width + x + 1] then
            return nil, "protected-trainer-approach"
        end
        local occupant=game.npcManager:getNPCAt(x,y)
        if occupant and occupant~=npc then return nil,"occupied-trainer-approach" end
        if currentZone:isSliceReady() and currentZone:movementRule(x-direction[1],y-direction[2],npc.facing).kind~="walk" then return nil,"blocked-trainer-pair" end
        steps[#steps+1]={x=x,y=y}
    end
    return steps
end
function TrainerEvents:prepare(npc,mode,scriptOwner)
    local owner=owners[self];local game=owner.game
    if owner.active then
        if info(self,owner.active) then return nil,"trainer-already-active" end
        owner.active=nil
    end
    local steps,reason=self:approach(npc,mode);if not steps then return nil,reason end
    local d=assert(definition(self,idOf(npc)))
    local token={};tokens[token]={owner=self,session=game.session,definition=d,npc=npc,zone=currentZone,player=game.player,
        phase="approach",steps=steps,index=1,tick=0,origin={x=npc.gridX,y=npc.gridY,facing=npc.facing,image=npc:getImage()},mode=mode}
    local name = SourceMaps.nameForID(d.map_id)
    if name and SourceMaps.entry(name).profile == "source" then
        local motion = game.npcManager.motion
        local lease, problem = motion:claimScript(npc, scriptOwner)
        if not lease then tokens[token] = nil; return nil, problem end
        tokens[token].motion, tokens[token].lease = motion, lease
    else
        npc:faceTowards(game.player.gridX,game.player.gridY)
    end
    owner.active=token
    return token
end
function TrainerEvents:updateApproach(token)
    local value,reason=info(self,token);if not value then return false,reason end
    local game=owners[self].game
    if value.phase~="approach" or currentZone~=value.zone or game.player~=value.player then return false,"invalid-approach-owner" end
    local step=value.steps[value.index]
    if not step then value.phase="ready";return true end
    local npc=value.npc
    if value.lease then
        if value.tick == 0 then
            local dx, dy = step.x - npc.gridX, step.y - npc.gridY
            local direction = dx > 0 and "right" or dx < 0 and "left" or dy > 0 and "down" or "up"
            local accepted, problem = value.motion:startScriptStep(value.lease, direction)
            if not accepted then return false, problem end
        end
        local done, problem = value.motion:updateScript(value.lease)
        if not done and problem ~= "moving" then return false, problem end
        value.tick = value.tick + 1
        if done then value.index, value.tick = value.index + 1, 0 end
        if value.index > #value.steps then value.phase="ready"; return true end
        return false, "moving"
    end
    if value.tick==0 then
        if currentZone.collision[step.y+1][step.x+1]~=0 or game.npcManager:getNPCAt(step.x,step.y) then return false,"approach-changed" end
        value.fromX,value.fromY=npc.gridX,npc.gridY
    end
    value.tick=value.tick+1
    npc:setImage(PewterSprites.stepImage(value.definition.sprite_source,npc.facing,value.tick))
    npc:moveTo((value.fromX+(step.x-value.fromX)*value.tick/8)*TILE_SIZE,(value.fromY+(step.y-value.fromY)*value.tick/8)*TILE_SIZE-8)
    if value.tick==8 then npc.gridX,npc.gridY=step.x,step.y;value.index,value.tick=value.index+1,0 end
    if value.index>#value.steps then value.phase="ready";return true end
    return false,"moving"
end
function TrainerEvents:launch(token)
    local value,reason=info(self,token);if not value then return nil,reason end
    if value.phase~="ready" then return nil,"trainer-approach-incomplete" end
    local game=owners[self].game
    if game.player~=value.player or currentZone~=value.zone or game.session:trainerDefeated(value.definition.id) then return nil,"stale-trainer-launch" end
    if math.abs(value.npc.gridX-game.player.gridX)+math.abs(value.npc.gridY-game.player.gridY)~=1 then return nil,"trainer-not-adjacent" end
    if game.session:party():allFainted() or game.session:party():count()==0 then return nil,"no-usable-party" end
    if not Specimen.isActiveSession(game.session) then return nil,"inactive-trainer-session" end
    local party=Party()
    local planned=RulesRNG.new(1);planned:restore(RulesRNG.snapshot())
    for _,mon in ipairs(value.definition.party) do
        assert(party:add(assert(Specimen.create(mon.species,mon.level,"trainer",planned,nil,Specimen.blueTrainerPolicy(value.definition.id)))))
    end
    RulesRNG.restore(planned:snapshot()) -- Entire detached team succeeded.
    if value.lease then value.motion:releaseScript(value.lease); value.lease = nil end
    value.party,value.phase=party,"battle"
    return party
end
function TrainerEvents:attachBattle(token,battle)
    local value,reason=info(self,token);if not value then return false,reason end
    if value.phase~="battle" or not battle:is("Battle") or battle.enemyParty~=value.party or battle.party~=value.session:party() or battle.trainerName~=value.definition.name then return false,"wrong-trainer-battle" end
    value.battle=battle;return true
end
function TrainerEvents:currentBattleToken(npc)
    local token=owners[self].active;local value=token and info(self,token)
    if value and value.phase=="battle" and value.npc==npc then return token end
end
-- Existing authored intro battle keeps its proven scene/geometry. Adopt only
-- its exact live level5 counter starter; no party replacement or guessed money.
function TrainerEvents:adoptIntroBattle(npc,battle)
    local owner=owners[self];local d=definition(self,idOf(npc))
    if not d or not d.initial_lab then return nil end
    if owner.active and info(self,owner.active) then return nil,"trainer-already-active" end
    if owner.game.session:trainerDefeated(LAB) or battle.party~=owner.game.session:party() or battle.enemyParty
        or battle.enemy.species~=d.party[1].species or battle.enemy.level~=5 or battle.trainerName~="BLUE" then return nil,"invalid-intro-trainer-battle" end
    local party=Party();assert(party:add(battle.enemy))
    local token={};tokens[token]={owner=self,session=owner.game.session,definition=d,npc=npc,zone=currentZone,player=owner.game.player,
        phase="battle",party=party,battle=battle,mode="intro"};owner.active=token;return token
end
function TrainerEvents:resolve(token,won,kind)
    local value,reason=info(self,token);if not value then return false,reason end
    local battle=value.battle
    if value.phase~="battle" or not battle or not battle.emittingEnd or not battle.machine:is("ended") or battle.outcome~=kind
        or type(won)~="boolean" or won~=(kind=="victory") or (kind~="victory" and kind~="defeat") then return false,"unconfirmed-trainer-outcome" end
    if won and not value.party:allFainted() or not won and not value.session:party():allFainted() then return false,"unconfirmed-trainer-faint" end
    local d,session=value.definition,value.session
    local receipt={id=d.id,won=won,payout=0,initial_lab=d.initial_lab or false,position={x=value.npc.gridX,y=value.npc.gridY,facing=value.npc.facing},zone_id=value.zone.stableID}
    if won then
        local money=session:inventory():money();local final=math.min(Inventory.MONEY_LIMIT,money+d.payout)
        if session:party():allFainted() and not d.initial_lab then final=final//2;receipt.blackout_money_applied=true end
        local expected={flags={},items={},trainers={[d.id]=false},money=money}
        local changes={flags={},items={},trainers={[d.id]=true},money={op=final>=money and "credit" or "debit",amount=math.abs(final-money)}}
        SourceEvents.victoryChanges(d.id,session,expected,changes)
        local accepted,problem=session:transact(expected,changes)
        if not accepted then return false,problem end
        receipt.payout,receipt.money_delta=d.payout,final-money
    end
    value.phase="resolved";owners[self].active=nil
    if won then owners[self].receipt,owners[self].receiptSession=copy(receipt),session end
    return true,receipt
end
function TrainerEvents:cancel(token)
    local value,reason=info(self,token);if not value then return false,reason end
    if value.phase=="battle" then return false,"battle-owns-encounter" end
    if value.lease then
        value.motion:releaseScript(value.lease)
        value.lease = nil
    elseif currentZone==value.zone and owners[self].game.player==value.player then
        local npc=value.npc;npc.gridX,npc.gridY=value.origin.x,value.origin.y
        npc:moveTo(npc.gridX*TILE_SIZE,npc.gridY*TILE_SIZE-8);npc:setFacing(value.origin.facing);npc:setImage(value.origin.image)
    end
    value.phase="cancelled";owners[self].active=nil;return true
end
function TrainerEvents:abortBattle(token)
    local value,reason=info(self,token);if not value then return false,reason end
    value.phase="cancelled";owners[self].active=nil;return true
end
function TrainerEvents:rewardPlan(id)
    local session=owners[self].game.session
    local items={}
    local descriptor=SourceEvents.descriptor(id)
    if descriptor and descriptor.reward then
        items[descriptor.reward.item]=session:inventory():quantity(descriptor.reward.item)
    end
    return SourceEvents.rewardPlan(id,{flags=session:flags().quest,trainers=session:flags().trainers,items=items})
end
function TrainerEvents:snapshot()
    local owner = owners[self]
    local value = owner.active and tokens[owner.active]
    if not value or value.session ~= owner.game.session then return {phase="idle"} end
    local definition = {
        id=value.definition.id,
        party=copy(value.definition.party),
        payout=value.definition.payout,
    }
    return {
        id=definition.id, party=definition.party, payout=definition.payout,
        definition=definition, phase=value.phase,
        pixelX=value.npc.x, pixelY=value.npc.y,
        gridX=value.npc.gridX, gridY=value.npc.gridY,
        step=value.index or 0, tick=value.tick or 0,
        total_steps=value.steps and #value.steps or 0, mode=value.mode,
    }
end
TrainerEvents.BROCK,TrainerEvents.JR,TrainerEvents.LAB=BROCK,JR,LAB

-- Defensive read only: a stale session never exposes its old presentation,
-- and even that rejection leaves ownership untouched until an explicit claim.
function TrainerEvents:peekReceipt(id)
    local owner=owners[self]
    if owner.receiptSession==owner.game.session and owner.receipt and owner.receipt.id==id then return copy(owner.receipt) end
end
function TrainerEvents:takeReceipt(id)
    local owner=owners[self]
    if owner.receiptSession~=owner.game.session then owner.receipt=nil end
    if owner.receipt and owner.receipt.id==id then local value=copy(owner.receipt);owner.receipt=nil;return value end
end
function TrainerEvents:restoreReturnedTrainer()
    local owner=owners[self];local receipt=owner.receipt
    if not receipt or owner.receiptSession~=owner.game.session or receipt.initial_lab or currentZone.stableID~=receipt.zone_id then return false end
    local x,y=receipt.position.x,receipt.position.y
    if not Party._integer(x,0,currentZone.width-1) or not Party._integer(y,0,currentZone.height-1) or currentZone.collision[y+1][x+1]~=0 then return false end
    local actor
    for _,npc in ipairs(owner.game.npcManager.npcs) do if idOf(npc)==receipt.id then actor=npc;break end end
    if not actor then return false end
    local occupied=owner.game.npcManager:getNPCAt(x,y)
    if occupied and occupied~=actor then return false end
    local name = SourceMaps.nameForID(receipt.zone_id)
    if name and SourceMaps.entry(name).profile == "source" then
        return owner.game.npcManager.motion:restoreTrainerPose(actor,x,y,receipt.position.facing)
    end
    actor.gridX,actor.gridY=x,y;actor:moveTo(x*TILE_SIZE,y*TILE_SIZE-8);actor:setFacing(receipt.position.facing)
    return true
end
