-- Red-capable production Title -> confirmed New Game -> GameSaves regression.
-- Uses real SDK files only in a private harness bundle. Root executes it.
TitleRecoveryProbe={}
local invocation=0
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
function TitleRecoveryProbe.run()
 invocation=invocation+1
 local report={ok=true,passed=0,failed=0,tests={}}
 local private=HarnessBuild and HarnessBuild.enabled and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
 if not private then return {ok=false,passed=0,failed=1,tests={{name="private SDK Data required",ok=false,error="no files touched"}}}end
 local fs=SaveStore.sdkFilesystem();local serial=0
 local function test(name,fn)
  local oldZone,oldRng,oldOwner,oldStory=currentZone,RulesRNG.toData(),GameSession.activeRNGSession(),Story.currentContext()
  local oldWorld=WorldDeltas.export();local undoRuntime=WorldDeltas.checkpointRuntime();local x,y=playdate.graphics.getDrawOffset()
  local sprites={};for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites())do sprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()}end
  local games={};local ok,problem=pcall(fn,games)
  for _,g in ipairs(games)do if GameSession.activeRNGSession()==g.session then g.session:deactivateRNG()end end
  pcall(WorldDeltas.apply,oldWorld);pcall(undoRuntime);currentZone=oldZone;Story.bind(oldStory)
  local active=GameSession.activeRNGSession();if active and active~=oldOwner then active:deactivateRNG()end
  if oldOwner and GameSession.activeRNGSession()~=oldOwner then assert(oldOwner:activateRNG())end;RulesRNG.restoreData(oldRng)
  for _,sprite in ipairs(playdate.graphics.sprite.getAllSprites())do if not sprites[sprite]then sprite:remove()end end
  for sprite,state in pairs(sprites)do sprite:add();sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled)end
  playdate.graphics.setDrawOffset(x,y);playdate.graphics.sprite.addDirtyRect(0,0,400,240);Autopilot.resetControls()
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 local function setup(games)
  serial=serial+1;local g=GameContext();games[#games+1]=g
  -- A real settled Player/State boundary; full native Overworld journey is a
  -- separate recipe. Avoid disposing the host game's global WorldView here.
  local world=State("overworld");world.sub=StateMachine();world.sub:register("explore",State("explore"));world.sub:change("explore")
  g.machine:register("overworld",world);g.machine:register("title",TitleState(g));g.machine:register("dialog",DialogState(g))
  switchZone("reds_house_2f");g.player=Player(5,3,currentZone.collision,g.npcManager);g.player:remove();g.player.facing="up"
  local prefix="title-red-"..HarnessBuild.session_id.."-"..invocation.."-"..serial
  g.saves=GameSaves(g,prefix)
  local bytes={a="broken published A",b="broken published B",candidate="broken unpublished candidate"}
  for key,value in pairs(bytes)do assert(fs.write(prefix.."."..key..".json",value))end
  g.machine:change("title");return g,g.machine:get("title"),prefix,bytes
 end
 test("NO at actual Title confirmation preserves session and all corrupt bytes",function(games)
  local g,title,prefix,bytes=setup(games);local old=g.session;eq(title.metadata.reason,"corrupt");eq(title.candidate,nil)
  title:choose("new");eq(title.phase,"confirm-new");title.menu.onSelect(1);eq(g.session,old);eq(g.machine:getCurrent(),"title")
  for key,value in pairs(bytes)do eq(fs.read(prefix.."."..key..".json"),value)end
 end)
 test("Confirmed New Game can Save after all old artifacts are corrupt",function(games)
  local g,title,prefix,bytes=setup(games);title:choose("new");title.menu.onSelect(2)
  eq(g.machine:getCurrent(),"dialog","new adventure reached opening")
  g.machine:pop();eq(g.machine:getCurrent(),"overworld")
  local payload,why=g:captureSession();assert(payload,"test did not reach valid settled save boundary: "..tostring(why))
  local ok,metadata=g.saves:save()
  assert(ok,"confirmed new adventure cannot save: "..tostring(metadata and metadata.reason))
  local restored=assert(g.saves:inspect());eq(restored:getIntro().stage,"pre_oak")
  for key,value in pairs(bytes)do eq(fs.read(g.saves.store:_archivePaths(1)[key]),value,"exact old "..key)end
  eq(g.saves._replacement,nil,"successful save consumes session request")
 end)
 test("only explicit Title YES binds replacement to the installed session",function(games)
  local g,title,prefix,bytes=setup(games)
  assert(g:beginNewSession(RulesRNG.snapshot().seed))
  local ok,why=g.saves:save();eq(ok,false);eq(why.reason,"recovery-required")
  for key,value in pairs(bytes)do eq(fs.read(prefix.."."..key..".json"),value)end
 end)
 test("session replacement invalidates an earlier explicit Title request",function(games)
  local g,title,prefix,bytes=setup(games);title:choose("new");title.menu.onSelect(2);g.machine:pop()
  assert(g:beginNewSession(RulesRNG.snapshot().seed))
  local ok,why=g.saves:save();eq(ok,false);eq(why.reason,"replacement-session-changed")
  for key,value in pairs(bytes)do eq(fs.read(prefix.."."..key..".json"),value)end
  eq(fs.read(g.saves.store:_archivePaths(1).manifest),nil)
 end)
 test("Title request stale after confirmation cannot refresh its observed bytes",function(games)
  local g,title,prefix,bytes=setup(games);title:choose("new");title.menu.onSelect(2);g.machine:pop()
  assert(fs.write(prefix..".b.json","newly discovered bytes"))
  local ok,why=g.saves:save();eq(ok,false);eq(why.reason,"stale-replacement")
  ok,why=g.saves:save();eq(ok,false);eq(why.reason,"stale-replacement")
  eq(fs.read(prefix..".a.json"),bytes.a);eq(fs.read(prefix..".b.json"),"newly discovered bytes")
  eq(fs.read(g.saves.store:_archivePaths(1).manifest),nil)
 end)
 test("failed archival attempt cannot fall through to ordinary save on retry",function(games)
  local g,title,prefix,bytes=setup(games);title:choose("new");title.menu.onSelect(2);g.machine:pop()
  local actual=g.saves.store._fs
  g.saves.store._fs={read=actual.read,rename=actual.rename,write=function(path,data)
   if path==g.saves.store:_archivePaths(1).a then return false,"injected archive failure"end
   return actual.write(path,data)
  end}
  local ok,why=g.saves:save();eq(ok,false);eq(why.reason,"archive-write-failed")
  g.saves.store._fs=actual
  ok,why=g.saves:save();eq(ok,false);eq(why.reason,"replacement-not-authorized")
  for key,value in pairs(bytes)do eq(fs.read(prefix.."."..key..".json"),value)end
 end)
 test("trusted PC first save uses the same confirmed archive authority",function(games)
  local g,title,prefix=setup(games)
  local old=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
  local bytes={}
  for index,key in ipairs({"a","b","candidate"})do bytes[key]=assert(g.saves.store:_envelope(old,index));assert(fs.write(prefix.."."..key..".json",bytes[key]))end
  title:refresh();title:choose("new");title.menu.onSelect(2);g.machine:pop()
  g.machine:register("pc",PCState(g));g.machine:push("pc");local pc=g.machine:get("pc")
  local ok,metadata=g.saves:changeBoxFromPC(pc,2,pc.epoch);assert(ok,metadata.reason);eq(metadata.archived,true)
  eq(g.session:storage():activeBox(),2);eq(g.saves._replacement,nil)
  for key,value in pairs(bytes)do eq(fs.read(g.saves.store:_archivePaths(1)[key]),value,"PC preserved "..key)end
  local restored=assert(g.saves:inspect());eq(restored:storage():activeBox(),2)
 end)
 test("failed confirmed PC save rolls box back without bypassing archive on retry",function(games)
  local g,title,prefix,bytes=setup(games);title:choose("new");title.menu.onSelect(2);g.machine:pop()
  g.machine:register("pc",PCState(g));g.machine:push("pc");local pc=g.machine:get("pc");local previous=g.session:storage():activeBox()
  local actual=g.saves.store._fs
  g.saves.store._fs={read=actual.read,rename=actual.rename,write=function(path,data)
   if path==g.saves.store:_archivePaths(1).a then return false,"injected PC archive failure"end
   return actual.write(path,data)
  end}
  local ok,why=g.saves:changeBoxFromPC(pc,2,pc.epoch);eq(ok,false);eq(why.reason,"archive-write-failed");eq(g.session:storage():activeBox(),previous)
  g.saves.store._fs=actual
  ok,why=g.saves:changeBoxFromPC(pc,2,pc.epoch);eq(ok,false);eq(why.reason,"replacement-not-authorized");eq(g.session:storage():activeBox(),previous)
  for key,value in pairs(bytes)do eq(fs.read(prefix.."."..key..".json"),value)end
 end)
 return report
end
