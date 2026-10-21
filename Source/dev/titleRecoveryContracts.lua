-- Production SaveStore, real SDK filesystem, deterministic path-specific fault
-- adapters. Never touches the production bundle or an existing Data prefix.
TitleRecoveryContracts={}
local invocation=0
local function eq(actual,expected,label)
    assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function validate(data) return type(data)=="table" and type(data.revision)=="number" and data.revision%1==0 and data.revision>=1 end
function TitleRecoveryContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    local private=HarnessBuild and HarnessBuild.enabled and type(HarnessBuild.bundle_id)=="string"
        and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
    if not private then test("private SDK Data required",function()error("no files touched")end);return report end
    invocation=invocation+1
    local fs=SaveStore.sdkFilesystem();local serial=0
    local function setup(label,overrides)
        serial=serial+1
        local prefix="title-recovery-"..HarnessBuild.session_id.."-"..invocation.."-"..serial.."-"..label
        local adapter={read=fs.read,write=fs.write,rename=fs.rename}
        for k,v in pairs(overrides or {}) do adapter[k]=v end
        return SaveStore(prefix,validate,adapter),prefix
    end
    local function wrap(prefix,overrides)
        local adapter={read=fs.read,write=fs.write,rename=fs.rename}
        for k,v in pairs(overrides or {}) do adapter[k]=v end
        return SaveStore(prefix,validate,adapter)
    end
    local function seed(store)
        local raw={a="broken A\0\255",b="broken B",candidate="broken candidate"}
        for k,v in pairs(raw)do assert(fs.write(store._paths[k],v))end
        return raw
    end
    local function unchanged(store,raw)
        for k,v in pairs(raw)do eq(fs.read(store._paths[k]),v,"untouched "..k)end
    end
    local function archived(store,index,raw)
        local paths=store:_archivePaths(index)
        for k,v in pairs(raw)do eq(fs.read(paths[k]),v,"archived "..k)end
        assert(store:_verifiedArchive(index,true),"complete archive must verify")
    end
    local function replace(store,revision)
        return store:replace({revision=revision},assert(store:prepareReplacement()))
    end
    test("confirmed replacement archives every exact raw byte including NUL/non-UTF8",function()
        local store=setup("bytes");local raw=seed(store)
        local before=RulesRNG.toData();local ok,metadata=replace(store,2);assert(ok,metadata.reason)
        eq(metadata.archived,true);eq(metadata.archive,1);archived(store,1,raw)
        local data,info=store:load();eq(data.revision,2);eq(info.artifacts.b.archived,true)
        eq(json.encode(RulesRNG.toData()),json.encode(before),"no rules RNG")
        assert(store:save({revision=3}));assert(store:save({revision=4}));assert(store:save({revision=5}))
        eq(assert(store:load()).revision,5);archived(store,1,raw)
    end)
    test("opaque tickets are store-bound one-shot and observe exact missing/path/bytes",function()
        local store,prefix=setup("ticket");local raw=seed(store);local ticket=assert(store:prepareReplacement())
        local foreign=SaveStore(prefix,validate,fs)
        local ok,why=foreign:replace({revision=2},ticket);eq(ok,false);eq(why.reason,"replacement-not-authorized");unchanged(store,raw)
        assert(fs.write(store._paths.b,raw.b.."changed"))
        ok,why=store:replace({revision=2},ticket);eq(ok,false);eq(why.reason,"stale-replacement")
        eq(fs.read(store:_archivePaths(1).manifest),nil)
        local fresh=assert(store:prepareReplacement());assert(store:replace({revision=2},fresh))
        ok,why=store:replace({revision=3},fresh);eq(ok,false);eq(why.reason,"replacement-not-authorized")
        ok,why=store:replace({revision=3},{});eq(ok,false);eq(why.reason,"replacement-not-authorized")
        local missing=setup("missing");ticket=assert(missing:prepareReplacement());assert(fs.write(missing._paths.candidate,"new"))
        ok,why=missing:replace({revision=1},ticket);eq(ok,false);eq(why.reason,"stale-replacement")
    end)
    test("unsupported schema and conflicting valid slots are all retained by explicit replacement",function()
        for _,kind in ipairs({"future","conflict"}) do
            local store=setup(kind)
            local a=assert(store:_envelope({revision=1},7));local b=assert(store:_envelope({revision=2},7))
            if kind=="future" then local envelope=json.decode(b);envelope.schema=2;b=json.encode(envelope)end
            local raw={a=a,b=b,candidate=assert(store:_envelope({revision=3},8))}
            for k,v in pairs(raw)do assert(fs.write(store._paths[k],v))end
            local ok=store:save({revision=4});eq(ok,false);unchanged(store,raw)
            assert(replace(store,4));archived(store,1,raw);eq(assert(store:load()).revision,4)
        end
    end)
    test("confirmed replacement starts a new lineage at native MAX without lowering ordinary cap",function()
        local store=setup("max");local raw={a=assert(store:_envelope({revision=1},SaveStore.MAX_SEQUENCE)),b="old corrupt B",candidate="old candidate"}
        for k,v in pairs(raw)do assert(fs.write(store._paths[k],v))end
        assert(replace(store,2));local data,info=store:load();eq(data.revision,2);eq(info.sequence,1);archived(store,1,raw)
        assert(store:save({revision=3}));eq(assert(store:load()).revision,3)
    end)
    test("unreadable observation fails before ticket/archive/publication",function()
        local store,prefix=setup("io");local raw=seed(store)
        local broken=wrap(prefix,{read=function(path)if path==store._paths.b then return nil,"injected IO"end;return fs.read(path)end})
        local ticket,why=broken:prepareReplacement();eq(ticket,nil);eq(why.reason,"archive-read-failed");unchanged(store,raw)
        eq(fs.read(store:_archivePaths(1).manifest),nil)
    end)
    test("archive short/corrupt writes and readback failures never touch primary bytes",function()
        for _,kind in ipairs({"short","corrupt","read"})do
            local store,prefix=setup("archive-"..kind);local raw=seed(store);local path=store:_archivePaths(1).b
            local broken=wrap(prefix,{write=function(target,bytes)
                if target==path and kind=="short"then fs.write(target,bytes:sub(1,1));return false,"short"end
                if target==path and kind=="corrupt"then return fs.write(target,bytes.."!")end
                return fs.write(target,bytes)
            end,read=function(target)
                if target==path and kind=="read" and fs.read(target)~=nil then return nil,"readback IO"end
                return fs.read(target)
            end})
            local ok,why=replace(broken,2);eq(ok,false);eq(why.reason,"archive-write-failed");unchanged(store,raw)
            eq(fs.read(store:_archivePaths(1).receipt),nil)
        end
    end)
    test("crash before receipt keeps all old primary bytes and complete proposal explicitly recoverable",function()
        for _,kind in ipairs({"before-write","before-rename"})do
            local store,prefix=setup(kind);local raw=seed(store);local paths=store:_archivePaths(1)
            local broken=wrap(prefix,{write=function(path,bytes)
                if kind=="before-write" and path==paths.pending then return false,"crash before receipt"end
                return fs.write(path,bytes)
            end,rename=function(from,to)
                if kind=="before-rename" and to==paths.receipt then return false,"crash before receipt publish"end
                return fs.rename(from,to)
            end})
            local ok=replace(broken,2);eq(ok,false);unchanged(store,raw)
            local data,info=store:load();eq(data,nil);eq(info.proposalAvailable,true)
            ok=store:save({revision=3});eq(ok,false);unchanged(store,raw)
            assert(store:recover("proposal"));eq(assert(store:load()).revision,2);archived(store,2,raw)
        end
    end)
    test("crash after receipt but before primary candidate gives no boot overwrite authority",function()
        local store,prefix=setup("before-publish");local raw=seed(store)
        local broken=wrap(prefix,{write=function(path,bytes)if path==store._paths.candidate then return false,"crash before publication"end;return fs.write(path,bytes)end})
        local ok=replace(broken,2);eq(ok,false);unchanged(store,raw);archived(store,1,raw)
        local restarted=SaveStore(prefix,validate,fs);local data,info=restarted:load();eq(data,nil);eq(info.proposalAvailable,true)
        ok=restarted:save({revision=3});eq(ok,false);unchanged(store,raw)
        assert(restarted:recover("proposal"));eq(assert(restarted:load()).revision,2)
    end)
    test("partial primary candidate leaves durable exact archive and explicit proposal recovery",function()
        local store,prefix=setup("partial-candidate");local raw=seed(store)
        local broken=wrap(prefix,{write=function(path,bytes)if path==store._paths.candidate then fs.write(path,bytes:sub(1,9));return false,"torn"end;return fs.write(path,bytes)end})
        local ok=replace(broken,2);eq(ok,false);eq(fs.read(store._paths.a),raw.a);eq(fs.read(store._paths.b),raw.b);archived(store,1,raw)
        assert(store:recover("proposal"));eq(assert(store:load()).revision,2)
        eq(#assert(fs.read(store:_archivePaths(2).candidate)),9)
    end)
    test("false acknowledgment after atomic publication restarts into verified new proposal",function()
        local store,prefix=setup("after-publish");local raw=seed(store)
        local broken=wrap(prefix,{rename=function(from,to)
            local ok,err=fs.rename(from,to)
            if to==store._paths.a and ok then return false,"crash after publish"end
            return ok,err
        end})
        local ok=replace(broken,2);eq(ok,false)
        local restarted=SaveStore(prefix,validate,fs);eq(assert(restarted:load()).revision,2);archived(store,1,raw)
        assert(restarted:save({revision=3}));eq(assert(restarted:load()).revision,3)
    end)
    test("missing/corrupt archive or receipt never hides old corruption",function()
        for _,kind in ipairs({"receipt-missing","receipt-corrupt","archive-missing","archive-corrupt","manifest-corrupt","proposal-corrupt"})do
            local store=setup(kind);seed(store);assert(replace(store,2));local paths=store:_archivePaths(1)
            local path=kind:find("receipt") and paths.receipt or kind:find("archive") and paths.b or kind=="manifest-corrupt" and paths.manifest or paths.proposal
            if kind:find("missing")then assert(fs.rename(path,path..".quarantined"))else assert(fs.write(path,"corrupted"))end
            local ok=store:save({revision=3});eq(ok,false,"reject "..kind)
            eq(store:_read(store._paths.a).data.revision,2,"new published bytes retained")
        end
    end)
    test("receipt only recognizes exact archived leftovers not new corruption or unsupported bytes",function()
        for _,kind in ipairs({"corrupt","future","valid-candidate"})do
            local store=setup("unknown-"..kind);seed(store);assert(replace(store,2))
            local bytes="unknown new corruption"
            if kind=="future"then local env=json.decode(assert(store:_envelope({revision=3},3)));env.schema=2;bytes=json.encode(env)
            elseif kind=="valid-candidate"then bytes=assert(store:_envelope({revision=3},3))end
            assert(fs.write(store._paths.candidate,bytes))
            local ok=store:save({revision=4});eq(ok,false);eq(fs.read(store._paths.candidate),bytes)
            eq(store:_read(store._paths.a).data.revision,2)
        end
    end)
    test("checksummed sidecars reject unknown fields noncanonical indices and path injection",function()
        for _,kind in ipairs({"field","index","target","role","length"})do
            local store=setup("sidecar-"..kind);seed(store);assert(replace(store,2));local paths=store:_archivePaths(1)
            local envelope=json.decode(assert(fs.read(paths.manifest)));local data=json.decode(envelope.payload)
            if kind=="field"then data.path="foreign.json"
            elseif kind=="index"then data.index="01"
            elseif kind=="target"then data.target="../foreign"
            elseif kind=="role"then data.roles.other=data.roles.a
            else data.roles.b.length=SaveStore.MAX_FILE+1 end
            envelope.payload=json.encode(data);envelope.checksum=SaveStore._checksum(envelope.payload)
            assert(fs.write(paths.manifest,json.encode(envelope)))
            local ok=store:save({revision=3});eq(ok,false)
        end
    end)
    test("published repair preserves distinct valid pending candidate before overwriting it",function()
        local store=setup("repair");assert(store:save({revision=1}));assert(store:save({revision=2}))
        assert(fs.write(store._paths.candidate,assert(store:_envelope({revision=3},3))))
        local old={a=assert(fs.read(store._paths.a)),b=assert(fs.read(store._paths.b)),candidate=assert(fs.read(store._paths.candidate))}
        assert(store:recover("published"));eq(assert(store:load()).revision,2);archived(store,1,old)
        assert(store:recover("backup-candidate"));eq(assert(store:load()).revision,3)
        local preserved=store:_verifiedArchive(2,true);assert(preserved,"restore archives current generation first")
    end)
    test("candidate recovery keeps original newer-only rule and preserves counterparts",function()
        local store=setup("candidate");assert(store:save({revision=1}));assert(store:save({revision=2}))
        assert(fs.write(store._paths.candidate,assert(store:_envelope({revision=3},1))))
        local ok,why=store:recover("candidate");eq(ok,false);eq(why.reason,"candidate-not-newer")
        eq(fs.read(store:_archivePaths(1).manifest),nil)
        assert(fs.write(store._paths.candidate,assert(store:_envelope({revision=3},3))))
        local raw={a=assert(fs.read(store._paths.a)),b=assert(fs.read(store._paths.b)),candidate=assert(fs.read(store._paths.candidate))}
        assert(store:recover("candidate"));eq(assert(store:load()).revision,3);archived(store,1,raw)
    end)
    test("explicit backup restore first archives current valid adventure and does not discard any generation",function()
        local store=setup("restore");assert(store:save({revision=1}));assert(store:save({revision=2}))
        local old={a=assert(fs.read(store._paths.a)),b=assert(fs.read(store._paths.b))}
        assert(replace(store,3));local current=assert(fs.read(store._paths.a));assert(store:recover("backup-published"))
        eq(assert(store:load()).revision,2);eq(fs.read(store:_archivePaths(1).a),old.a);eq(fs.read(store:_archivePaths(1).b),old.b)
        eq(fs.read(store:_archivePaths(2).a),current)
        assert(store:save({revision=4}));eq(assert(store:load()).revision,4)
    end)
    test("latest corrupt receipt cannot fall back to older valid replacement authority",function()
        local store=setup("latest");seed(store);assert(replace(store,2));assert(replace(store,3))
        assert(fs.write(store:_archivePaths(2).receipt,"broken receipt"))
        local data,why=store:load();eq(data,nil);eq(why.reason,"archive-verification-failed")
        local ok=store:save({revision=4});eq(ok,false)
    end)
    test("newer malformed manifest cannot fall back to older receipt",function()
        local store=setup("newer-manifest");seed(store);assert(replace(store,2))
        assert(fs.write(store:_archivePaths(2).manifest,"torn newer manifest"))
        local data,info=store:load();eq(data,nil);eq(info.reason,"archive-verification-failed")
        local ok=store:save({revision=3});eq(ok,false)
    end)
    test("archive indices increase past occupied partial holes and cap fails unchanged",function()
        local store=setup("sparse");local raw=seed(store)
        assert(fs.write(store:_archivePaths(2).a,"partial older attempt"))
        local ok,info=replace(store,2);assert(ok,info.reason);eq(info.archive,3);archived(store,3,raw)
        eq(fs.read(store:_archivePaths(1).manifest),nil)
        local capped=setup("cap");raw=seed(capped);assert(fs.write(capped:_archivePaths(SaveStore.MAX_ARCHIVES).a,"occupied"))
        ok,info=replace(capped,2);eq(ok,false);eq(info.reason,"archive-limit");unchanged(capped,raw)
    end)
    test("pending proposal is hidden after exact publication and later ordinary saves, not old MAX slots",function()
        local store=setup("proposal-hidden");seed(store);assert(replace(store,2))
        local data,info=store:load();eq(data.revision,2);eq(info.proposalAvailable,false)
        assert(store:save({revision=3}));assert(store:save({revision=4}));data,info=store:load();eq(info.proposalAvailable,false)
        local old,prefix=setup("max-pending")
        assert(fs.write(old._paths.a,assert(old:_envelope({revision=1},SaveStore.MAX_SEQUENCE))))
        assert(fs.write(old._paths.b,assert(old:_envelope({revision=2},4))))
        local broken=wrap(prefix,{write=function(path,bytes)if path==old._paths.candidate then return false,"before publish"end;return fs.write(path,bytes)end})
        local ok=replace(broken,3);eq(ok,false);data,info=old:load();eq(info.proposalAvailable,true)
    end)
    return report
end
