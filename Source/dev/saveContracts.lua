-- Actual Pokemon + actual SDK filesystem. Fault adapters wrap real file calls;
-- no fake SDK or memory-only filesystem. Root runs only private UUID bundles.
SaveContracts={}
local invocation=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function copy(data) return json.decode(json.encode(data)) end
local function mon() return Pokemon("charmander",5) end
local function payload(revision)
    return {revision=revision,pokemon=assert(PokemonCodec.encode(mon()))}
end
local function validate(data)
    return type(data)=="table" and type(data.revision)=="number" and data.revision%1==0 and data.revision>=1
        and PokemonCodec.validate(data.pokemon)
end
function SaveContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,err=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1; report.ok=false end
    end
    test("codec all 151 species roundtrip without rules RNG",function()
        local before=RulesRNG.snapshot()
        local count=0
        for species in pairs(pokemonData) do
            local original=Pokemon(species,5)
            original.hp=math.max(0,original.maxHP-3)
            local record=assert(PokemonCodec.encode(original))
            local restored=assert(PokemonCodec.decode(copy(record)))
            assert(same(record,assert(PokemonCodec.encode(restored))))
            eq(restored.maxHP,original.maxHP); eq(restored.atk,original.atk); eq(restored.spa,original.spa)
            count=count+1
        end
        eq(count,151); assert(same(before,RulesRNG.snapshot()))
    end)
    test("codec preserves chosen moves zero PP status HP XP nickname pending choices",function()
        local original=mon()
        original:gainXP(original:xpForLevel(20)-original.xp)
        local choices=original:getPendingMoveChoices(); assert(#choices>=3)
        original:resolveMoveChoice(choices[1].id,"learn")
        original:resolveMoveChoice(choices[2].id,"learn")
        original.name,original.hp,original.status,original.statusTurns="EMBER",7,"sleep",2
        original.sleepDuration=3
        original.pp[original.moves[1]]=0
        original.statStages.atk,original.confusion,original.flinched=-2,3,true
        local record=assert(PokemonCodec.encode(original))
        local restored=assert(PokemonCodec.decode(copy(record)))
        assert(same(assert(PokemonCodec.encode(restored)),record))
        eq(restored.pp[restored.moves[1]],0); eq(restored.hp,7); eq(restored.status,"sleep"); eq(restored.statusTurns,2)
        eq(restored.name,"EMBER"); assert(#restored.pendingMoveChoices>=1)
        eq(restored.statStages.atk,0); eq(restored.confusion,nil); eq(restored.flinched,false)
        eq(original.statStages.atk,-2); eq(original.confusion,3); eq(original.flinched,true)
        record.moves[1]="tackle"; eq(original.moves[1],"scratch"); eq(restored.moves[1],"scratch")
        for _,status in ipairs({"none","burn","poison","paralyze","freeze"}) do
            local variant=copy(assert(PokemonCodec.encode(original)))
            variant.status,variant.statusTurns,variant.hp,variant.sleepDuration=status,0,0,0
            assert(same(variant,assert(PokemonCodec.encode(assert(PokemonCodec.decode(variant))))))
        end
        local exhausted=copy(assert(PokemonCodec.encode(original)))
        exhausted.status,exhausted.statusTurns="sleep",0
        local sleeping=assert(PokemonCodec.decode(exhausted))
        eq(sleeping.status,"sleep"); eq(sleeping.statusTurns,0)
        assert(same(exhausted,assert(PokemonCodec.encode(sleeping))))
        local capped=Pokemon("mew",100); capped:gainXP(500)
        local loaded=assert(PokemonCodec.decode(assert(PokemonCodec.encode(capped))))
        eq(loaded.level,100); eq(loaded.xp,capped.xp)
    end)
    test("codec rejects malformed records and choices without mutating source",function()
        local original=mon(); original:gainXP(original:xpForLevel(20)-original.xp)
        local source=assert(PokemonCodec.encode(original))
        local changes={
            function(r) r.species="missingno" end,
            function(r) r.moves[1]="unknown" end,
            function(r) r.moves[2]=r.moves[1] end,
            function(r) r.pp[r.moves[1]]=moveData[r.moves[1]].maxPP+1 end,
            function(r) r.pp.unselected=1 end,
            function(r) r.hp=-1 end,
            function(r) r.hp=100000 end,
            function(r) r.level=0 end,
            function(r) r.level=101 end,
            function(r) r.xp=0 end,
            function(r) r.xp=xpForLevel(r.level+1, r.species) end,
            function(r) r.status="toxic" end,
            function(r) r.status="sleep"; r.statusTurns=-1 end,
            function(r) r.status="sleep"; r.statusTurns=4 end,
            function(r) r.status="poison"; r.statusTurns=1 end,
            function(r) r.name="TOO-LONG-NAME" end,
            function(r) r.pendingMoveChoices[1].sourceMoveId=99999 end,
            function(r) r.pendingMoveChoices[1].id=r.nextMoveChoiceId end,
            function(r) r.pendingMoveChoices[1].reason="unknown" end,
            function(r) r.pendingMoveChoices[1].sourceOrder=99 end,
            function(r) r.pendingMoveChoices[2].id=r.pendingMoveChoices[1].id end,
            function(r) r.nextMoveChoiceId=0 end,
            function(r) r.futureField="reject instead of dropping" end,
        }
        for _,change in ipairs(changes) do
            local bad=copy(source); change(bad)
            local restored=PokemonCodec.decode(bad); eq(restored,nil)
            assert(same(source,assert(PokemonCodec.encode(original))))
        end
        if moveData.struggle then
            local fallback=copy(source); fallback.moves={"struggle"}; fallback.pp={struggle=0}
            eq(PokemonCodec.decode(fallback),nil)
        end
        local bad=copy(source); bad.moves={[1]=bad.moves[1],[3]=bad.moves[2]}; eq(PokemonCodec.decode(bad),nil)
        bad=copy(source); bad.pendingMoveChoices={[2]=bad.pendingMoveChoices[1]}; eq(PokemonCodec.decode(bad),nil)
    end)
    -- Every remaining test is intentionally filesystem-backed and must not run
    -- against production Data, even when someone imports this module manually.
    local private=HarnessBuild and HarnessBuild.enabled and type(HarnessBuild.bundle_id)=="string"
        and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
    if not private then
        test("save filesystem contracts require isolated harness bundle",function() error("private harness bundle required; no files touched") end)
        return report
    end
    invocation=invocation+1
    local runId=HarnessBuild.session_id.."-"..invocation
    local fs=SaveStore.sdkFilesystem()
    local function fixture(name,adapter)
        local prefix="save-contract-"..runId.."-"..name
        local paths={a=prefix..".a.json",b=prefix..".b.json",candidate=prefix..".candidate.json"}
        return SaveStore(prefix,validate,adapter or fs),paths,prefix
    end
    local function wrapped(overrides)
        return {read=overrides.read or fs.read,write=overrides.write or fs.write,rename=overrides.rename or fs.rename}
    end
    local function unchanged(paths,before)
        for key,bytes in pairs(before) do eq(fs.read(paths[key]),bytes) end
    end
    test("checksum known vectors exact bytes and published two-slot ordering",function()
        eq(SaveStore._checksum(""),"811c9dc5"); eq(SaveStore._checksum("a"),"e40c292c")
        eq(SaveStore._checksum("foobar"),"bf9cf968"); eq(SaveStore._checksum("hello"),"4f9f2cab")
        local store,paths=fixture("ordering")
        local data,metadata=store:load(); eq(data,nil); eq(metadata.reason,"empty")
        assert(store:save(payload(1))); assert(store:save(payload(2)))
        data,metadata=store:load(); eq(data.revision,2); eq(metadata.sequence,2); eq(metadata.slot,"b")
        local envelope=json.decode(assert(fs.read(paths.b)))
        envelope.payload=envelope.payload.." " -- valid equivalent JSON, different exact bytes.
        assert(fs.write(paths.b,json.encode(envelope)))
        data,metadata=store:load(); eq(data.revision,1); eq(metadata.reason,"recovered-published")
        local before={a=assert(fs.read(paths.a)),b=assert(fs.read(paths.b))}
        local ok=store:save(payload(3)); eq(ok,false); unchanged(paths,before)
        assert(store:recover("published")); data=assert(store:load()); eq(data.revision,1)
    end)
    test("short write and candidate verification failures retain committed bytes",function()
        for _,kind in ipairs({"short","corrupt","throw"}) do
            local base,paths,prefix=fixture("write-"..kind)
            assert(base:save(payload(1))); assert(base:save(payload(2)))
            local before={a=assert(fs.read(paths.a)),b=assert(fs.read(paths.b))}
            local faulty=SaveStore(prefix,validate,wrapped({write=function(path,bytes)
                if kind=="throw" then error("injected prewrite failure") end
                if kind=="short" then fs.write(path,bytes:sub(1,math.floor(#bytes/2))); return false,"injected short write" end
                return fs.write(path,bytes:sub(1,-2).."]")
            end}))
            local ok=faulty:save(payload(3)); eq(ok,false); unchanged(paths,before)
            local recovered=assert(base:load()); eq(recovered.revision,2)
        end
    end)
    test("rename failure keeps pending candidate subordinate until deliberate recovery",function()
        local base,paths,prefix=fixture("rename-fail")
        assert(base:save(payload(1))); local old=assert(fs.read(paths.a))
        local faulty=SaveStore(prefix,validate,wrapped({rename=function() return false,"injected rename" end}))
        local ok=faulty:save(payload(2)); eq(ok,false); eq(fs.read(paths.a),old)
        local data,metadata=base:load(); eq(data.revision,1); eq(metadata.pendingCandidate,true)
        ok,metadata=base:save(payload(3)); eq(ok,false); eq(metadata.reason,"pending-candidate-recovery-required")
        assert(base:recover("candidate")); data=assert(base:load()); eq(data.revision,2); eq(fs.read(paths.a),old)
    end)
    test("crash after atomic rename loads newly published state",function()
        local base,paths,prefix=fixture("after-rename")
        assert(base:save(payload(1))); local old=assert(fs.read(paths.a))
        local faulty=SaveStore(prefix,validate,wrapped({rename=function(from,to)
            assert(fs.rename(from,to)); return false,"injected crash after rename"
        end}))
        local ok=faulty:save(payload(2)); eq(ok,false); eq(fs.read(paths.a),old)
        local data,metadata=base:load(); eq(data.revision,2); eq(metadata.reason,"published")
    end)
    test("candidate-only recovery publishes before a subsequent failed save",function()
        local base,paths,prefix=fixture("candidate-only")
        local unpublished=SaveStore(prefix,validate,wrapped({rename=function() return false,"not committed" end}))
        local ok=unpublished:save(payload(1)); eq(ok,false)
        local data,metadata=base:load(); eq(data,nil); eq(metadata.reason,"recoverable-candidate"); eq(metadata.candidate.data.revision,1)
        local candidate=assert(fs.read(paths.candidate))
        ok=base:save(payload(2)); eq(ok,false); eq(fs.read(paths.candidate),candidate)
        assert(base:recover("candidate")); data=assert(base:load()); eq(data.revision,1)
        local committed=assert(fs.read(paths.a))
        local broken=SaveStore(prefix,validate,wrapped({write=function(path,bytes)
            fs.write(path,bytes:sub(1,8)); return false,"subsequent torn write"
        end}))
        ok=broken:save(payload(2)); eq(ok,false); eq(fs.read(paths.a),committed)
        data=assert(base:load()); eq(data.revision,1)
    end)
    test("unsupported newer schema and both corrupt artifacts are never silently replaced",function()
        local base,paths=fixture("newer")
        assert(base:save(payload(1)))
        local envelope=json.decode(assert(fs.read(paths.a))); envelope.schema=2
        assert(fs.write(paths.b,json.encode(envelope)))
        local before={a=assert(fs.read(paths.a)),b=assert(fs.read(paths.b))}
        local data,metadata=base:load(); eq(data,nil); eq(metadata.reason,"unsupported-schema")
        local ok; ok,metadata=base:save(payload(2)); eq(ok,false); eq(metadata.reason,"unsupported-schema")
        ok,metadata=base:recover("published"); eq(ok,false); eq(metadata.reason,"unsupported-schema"); unchanged(paths,before)
        local corrupt,bad=fixture("both-corrupt")
        assert(fs.write(bad.a,"{")); assert(fs.write(bad.b,"["))
        data,metadata=corrupt:load(); eq(data,nil); eq(metadata.reason,"corrupt")
        ok=corrupt:save(payload(1)); eq(ok,false); eq(fs.read(bad.a),"{"); eq(fs.read(bad.b),"[")
    end)
    test("newer candidate blocks recovery and preserves every artifact",function()
        local base,paths=fixture("newer-candidate")
        assert(base:save(payload(1)))
        local envelope=json.decode(assert(fs.read(paths.a))); envelope.schema=2
        assert(fs.write(paths.candidate,json.encode(envelope)))
        local before={a=assert(fs.read(paths.a)),candidate=assert(fs.read(paths.candidate))}
        local data,metadata=base:load(); eq(data,nil); eq(metadata.reason,"unsupported-schema")
        local ok; ok,metadata=base:recover("candidate"); eq(ok,false); eq(metadata.reason,"unsupported-schema")
        ok,metadata=base:save(payload(2)); eq(ok,false); eq(metadata.reason,"unsupported-schema"); unchanged(paths,before)
    end)
    test("read faults sequence conflicts and bounded payloads never replace committed bytes",function()
        local base,paths,prefix=fixture("read-conflict")
        assert(base:save(payload(1))); assert(base:save(payload(2)))
        local before={a=assert(fs.read(paths.a)),b=assert(fs.read(paths.b))}
        local faulty=SaveStore(prefix,validate,wrapped({read=function(path)
            if path==paths.b then return nil,"injected IO fault" end
            return fs.read(path)
        end}))
        local data,metadata=faulty:load(); eq(data,nil); eq(metadata.reason,"io-error")
        local ok; ok,metadata=faulty:save(payload(3)); eq(ok,false); eq(metadata.reason,"io-error"); unchanged(paths,before)
        local folder = prefix .. "-archive-1.manifest.json"
        assert(playdate.file.mkdir(folder))
        local directoryFault = SaveStore(prefix, validate, {
            list = fs.list,
            read = function(path)
                if path == folder then
                    return nil, "injected directory read error"
                end
                return fs.read(path)
            end,
            write = fs.write,
            rename = fs.rename,
        })
        data, metadata = directoryFault:load()
        eq(data, nil)
        eq(metadata.reason, "archive-verification-failed")
        ok, metadata = directoryFault:save(payload(3))
        eq(ok, false)
        unchanged(paths, before)
        assert(playdate.file.delete(folder))
        local huge=payload(3); huge.padding=string.rep("x",SaveStore.MAX_PAYLOAD)
        ok,metadata=base:save(huge); eq(ok,false); eq(metadata.reason,"invalid-payload"); unchanged(paths,before)
        local envelope=json.decode(before.b); envelope.sequence=1
        envelope.checksum=SaveStore._boundChecksum(envelope.schema,envelope.sequence,envelope.payload)
        assert(fs.write(paths.b,json.encode(envelope)))
        before.b=assert(fs.read(paths.b))
        data,metadata=base:load(); eq(data,nil); eq(metadata.reason,"sequence-conflict")
        ok,metadata=base:save(payload(3)); eq(ok,false); eq(metadata.reason,"sequence-conflict"); unchanged(paths,before)
    end)
    test("canonical decimal counters retain native int32 across SDK JSON",function()
        for _,value in ipairs({16777215,16777216,16777217,2147483646,2147483647}) do
            local text=assert(DecimalInteger.encode(value,1,SaveStore.MAX_SEQUENCE))
            local wire=json.encode({sequence=text})
            local parsed=assert(DecimalInteger.decode(json.decode(wire).sequence,1,SaveStore.MAX_SEQUENCE))
            eq(parsed,value); eq(math.type(parsed),"integer")
            local store,paths=fixture("boundary-"..text)
            assert(fs.write(paths.a,assert(store:_envelope(payload(1),value))))
            local data,metadata=store:load(); assert(data,json.encode(metadata)); eq(data.revision,1); eq(metadata.sequence,value)
            eq(math.type(metadata.sequence),"integer")
            local numeric=json.decode(json.encode({n=value})).n
            if numeric~=value then
                local unsafe=payload(2); unsafe.counter=value
                local ok,reason=store:save(unsafe)
                -- A capped store stops before encoding; lower counters prove
                -- the generic payload guard rather than relying on that cap.
                eq(ok,false)
                if value<SaveStore.MAX_SEQUENCE then
                    eq(reason.reason,"invalid-payload"); assert(reason.error:find("json%-roundtrip%-loss"))
                else eq(reason.reason,"sequence-limit") end
            end
            if value<SaveStore.MAX_SEQUENCE then
                assert(store:save(payload(2)))
                local data,metadata=store:load(); eq(data.revision,2); eq(metadata.sequence,value+1)
            end
        end
        for _,text in ipairs({"00","01","+1","-0","1.0","1e3"," 1","2147483648","-2147483649"}) do
            eq(DecimalInteger.decode(text),nil)
        end
        eq(DecimalInteger.decode("-2147483648"),DecimalInteger.MIN)
        eq(assert(DecimalInteger.encode(DecimalInteger.MIN)),"-2147483648")
        eq(DecimalInteger.encode(1.5),nil)
    end)
    test("legacy numeric header compatibility is exact and high ambiguous values fail closed",function()
        local low,paths=fixture("legacy-low")
        local envelope=json.decode(assert(low:_envelope(payload(1),7)))
        envelope.sequence=7
        assert(fs.write(paths.a,json.encode(envelope)))
        local data,metadata=low:load(); eq(data.revision,1); eq(metadata.sequence,7)
        assert(low:save(payload(2))); data,metadata=low:load(); eq(data.revision,2); eq(metadata.sequence,8)
        local high,bad=fixture("legacy-high")
        envelope=json.decode(assert(high:_envelope(payload(1),SaveStore.MAX_SEQUENCE)))
        envelope.sequence=SaveStore.MAX_SEQUENCE
        local raw=json.encode(envelope); assert(fs.write(bad.a,raw))
        data,metadata=high:load(); eq(data,nil); eq(metadata.reason,"corrupt")
        eq(metadata.artifacts.a.error,"canonical-decimal-sequence-required")
        local ok=high:save(payload(2)); eq(ok,false); eq(fs.read(bad.a),raw)
    end)
    test("RNG integer JSON loss is diagnosed and generic payloads remain fail closed",function()
        local stream=RulesRNG.new(2147483646)
        local snapshot=stream:snapshot()
        local raw=json.encode(snapshot); local parsed=json.decode(raw)
        local encoded=assert(DecimalInteger.encode(snapshot.state))
        local restored=assert(DecimalInteger.decode(json.decode(json.encode({state=encoded})).state))
        eq(restored,snapshot.state); eq(math.type(restored),"integer")
        local store,paths,prefix=fixture("rng-numeric")
        assert(store:save(payload(1)))
        local unsafe=payload(2); unsafe.rng=snapshot
        local facts={sdk=HarnessBuild.sdk_version,rawJSON=raw,originalState=string.format("%d",snapshot.state),
            decodedState=tostring(parsed.state),decodedKind=math.type(parsed.state),rawEqual=same(snapshot,parsed),
            exactDecimal=encoded,restoredState=string.format("%d",restored)}
        assert(fs.write(prefix..".facts.json",json.encode(facts)))
        local ok,metadata=store:save(unsafe)
        if not same(snapshot,parsed) then
            eq(ok,false); eq(metadata.reason,"invalid-payload"); assert(metadata.error:find("json%-roundtrip%-loss"))
            eq(assert(store:load()).revision,1)
        else assert(ok) end
        -- The current Pokemon primitive codec retains native counters, but
        -- generic JSON cannot safely persist every large counter yet.
        local pokemon=mon(); pokemon.nextMoveChoiceId=16777217
        local record=assert(PokemonCodec.encode(pokemon))
        local decoded=json.decode(json.encode(record))
        if decoded.nextMoveChoiceId~=record.nextMoveChoiceId then
            local data=payload(3); data.pokemon=record
            ok,metadata=store:save(data); eq(ok,false); eq(metadata.reason,"invalid-payload")
        end
    end)
    test("third and fourth saves replace older slots while retaining newest backup",function()
        local store,paths=fixture("overwrite")
        for revision=1,4 do
            assert(store:save(payload(revision)))
            local data,metadata=store:load(); eq(data.revision,revision); eq(metadata.sequence,revision)
        end
        local a=json.decode(assert(fs.read(paths.a))); local b=json.decode(assert(fs.read(paths.b)))
        eq(a.sequence,"3"); eq(b.sequence,"4")
        eq(json.decode(a.payload).revision,3); eq(json.decode(b.payload).revision,4)
    end)
    test("sequence cap payload validation callbacks and input isolation",function()
        local base,paths=fixture("sequence")
        local live=payload(1); assert(base:save(live))
        local before=copy(live)
        local invalid=copy(live); invalid.pokemon.pp[invalid.pokemon.moves[1]]=-1
        local ok,metadata=base:save(invalid); eq(ok,false); eq(metadata.reason,"invalid-payload"); assert(same(live,before))
        local bytes=assert(fs.read(paths.a)); local envelope=json.decode(bytes)
        envelope.sequence=assert(DecimalInteger.encode(SaveStore.MAX_SEQUENCE,1,SaveStore.MAX_SEQUENCE))
        envelope.checksum=SaveStore._boundChecksum(envelope.schema,envelope.sequence,envelope.payload)
        assert(fs.write(paths.a,json.encode(envelope)))
        local data; data,metadata=base:load()
        assert(data,json.encode(metadata))
        eq(data.revision,1); eq(metadata.sequence,SaveStore.MAX_SEQUENCE)
        local capped=assert(fs.read(paths.a))
        ok,metadata=base:save(payload(2)); eq(ok,false); eq(metadata.reason,"sequence-limit"); eq(fs.read(paths.a),capped)
        local rejected=SaveStore("save-contract-"..runId.."-callback",function() error("validator failed") end,fs)
        ok=rejected:save(live); eq(ok,false); assert(same(live,before))
        local mutating=SaveStore("save-contract-"..runId.."-detached",function(data)
            data.revision=999; error("must not mutate caller")
        end,fs)
        ok=mutating:save(live); eq(ok,false); assert(same(live,before))
        local good=SaveStore("save-contract-"..runId.."-primitive",validate,fs)
        local cycle={}; cycle.self=cycle
        ok=good:save(cycle); eq(ok,false)
    end)
    return report
end
