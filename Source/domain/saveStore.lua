-- Published-slot transactional save container. Import after lib/oop.
-- No implicit reset, migration, world snapshot or battle-resume behavior.
import "domain/decimalInteger"

Class("SaveStore")
SaveStore.SCHEMA,SaveStore.MAX_SEQUENCE=1,2147483647
SaveStore.MAX_PAYLOAD,SaveStore.MAX_FILE=262144,1048576
local type <const>, pairs <const>, getmetatable <const> = type, pairs, getmetatable
local FORMAT="pokemon-playdate-save"
local function integer(n,low,high) return type(n)=="number" and n%1==0 and n>=low and n<=high end
local function primitive(value,seen,depth)
    depth=depth or 0
    assert(depth<=64,"payload-too-deep")
    local kind=type(value)
    if kind=="string" or kind=="boolean" then return end
    if kind=="number" then assert(value==value and value>=-2147483647 and value<=2147483647,"invalid-number"); return end
    assert(kind=="table" and getmetatable(value)==nil,"nonprimitive-payload")
    seen=seen or {}; assert(not seen[value],"cyclic-payload"); seen[value]=true
    local numeric,stringKeys,count=false,false,0
    for key,item in pairs(value) do
        if type(key)=="string" then stringKeys=true else assert(integer(key,1,1000000),"invalid-key"); numeric=true end
        count=count+1; primitive(item,seen,depth+1)
    end
    assert(not(numeric and stringKeys),"mixed-table")
    assert(not numeric or count==#value,"sparse-array")
    seen[value]=nil
end
local function equal(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for key,value in pairs(a) do if not equal(value,b[key]) then return false end end
    for key in pairs(b) do if a[key]==nil then return false end end
    return true
end
local function checksum(bytes)
    local hash=-2128831035 -- FNV offset 0x811c9dc5 as a signed SDK int32
    for i=1,#bytes do
        local product=(hash ~ bytes:byte(i))*16777619
        -- Explicit signed low32 normalization also works in a 64-bit Lua;
        -- int32 SDK multiplication wraps by definition before this mask.
        hash=(product&0x7fffffff)+(((product>>31)&1)==1 and (-2147483647-1) or 0)
        if i % 512 == 0 and GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return string.format("%02x%02x%02x%02x",(hash>>24)&255,(hash>>16)&255,(hash>>8)&255,hash&255)
end
local function sequenceValue(value)
    if type(value)=="string" then return DecimalInteger.decode(value,1,SaveStore.MAX_SEQUENCE) end
    -- Compatibility with old low numeric headers only. Above this threshold
    -- JSON float32 can round a different raw integer into the same number.
    if integer(value,1,16777215) then return math.tointeger(value) end
    return nil,"canonical-decimal-sequence-required"
end
local function boundChecksum(schema,sequence,payload)
    local number=type(sequence)=="string" and assert(DecimalInteger.decode(sequence,1,SaveStore.MAX_SEQUENCE)) or sequence
    local decimal=assert(DecimalInteger.encode(number,1,SaveStore.MAX_SEQUENCE))
    return checksum(string.format("%d",schema).."\n"..decimal.."\n"..payload)
end
-- Small internal test seam for independent envelope fault cases/known vectors.
SaveStore._checksum,SaveStore._boundChecksum=checksum,boundChecksum
function SaveStore.sdkFilesystem()
    local sdkFile <const> = playdate.file
    return {
        read=function(path)
            if not sdkFile.exists(path) then return nil,"missing" end
            local size=sdkFile.getSize(path)
            if not integer(size,0,SaveStore.MAX_FILE) then return nil,"file-size-invalid" end
            if size==0 then return "" end
            local file,err=sdkFile.open(path,sdkFile.kFileRead)
            if not file then return nil,err or "open-failed" end
            local ok,bytes,count=pcall(function() return file:read(size) end)
            local closed=pcall(function() file:close() end)
            if not ok or not closed or type(bytes)~="string" or #bytes~=size or count~=size then return nil,"read-failed" end
            return bytes
        end,
        write=function(path,bytes)
            local file,err=sdkFile.open(path,sdkFile.kFileWrite)
            if not file then return false,err or "open-failed" end
            local ok,count=pcall(function()
                local written=file:write(bytes)
                file:flush()
                return written
            end)
            local closed=pcall(function() file:close() end)
            if not ok or not closed or count~=#bytes then return false,"write-failed" end
            return true
        end,
        list=type(sdkFile.listFiles)=="function" and function(path) return sdkFile.listFiles(path) end or nil,
        rename=function(from,to) return sdkFile.rename(from,to) end,
    }
end
local function call(fs,op,...)
    local ok,a,b=pcall(fs[op],...)
    if not ok then return nil,"adapter-"..op..": "..tostring(a) end
    return a,b
end
function SaveStore:init(prefix,validate,filesystem)
    assert(type(prefix)=="string" and #prefix>=1 and #prefix<=120 and not prefix:find("[^%w_/-]")
        and not prefix:find("//",1,true) and prefix:sub(1,1)~="/" and prefix:sub(-1)~="/","safe explicit Data-relative prefix required")
    assert(type(validate)=="function","payload validator required")
    self._prefix=prefix
    self._validate,self._fs=validate,filesystem or SaveStore.sdkFilesystem()
    assert(type(self._fs.read)=="function" and type(self._fs.write)=="function" and type(self._fs.rename)=="function","invalid filesystem adapter")
    self._paths={a=prefix..".a.json",b=prefix..".b.json",candidate=prefix..".candidate.json"}
end
function SaveStore:_decode(path,bytes,err)
    if bytes==nil then return {state=err=="missing" and "missing" or "io-error",error=err,path=path} end
    if type(bytes)~="string" or #bytes>SaveStore.MAX_FILE then return {state="corrupt",error="invalid-file-bytes",path=path} end
    local ok,envelope=pcall(json.decode,bytes)
    if not ok or type(envelope)~="table" or envelope.format~=FORMAT then return {state="corrupt",error="invalid-envelope",path=path} end
    if integer(envelope.schema,1,2147483647) and envelope.schema~=SaveStore.SCHEMA then
        return {state="unsupported-schema",schema=envelope.schema,path=path}
    end
    local sequence,sequenceError=sequenceValue(envelope.sequence)
    if envelope.schema~=SaveStore.SCHEMA or not sequence
        or type(envelope.payload)~="string" or #envelope.payload>SaveStore.MAX_PAYLOAD
        or envelope.checksum~=boundChecksum(envelope.schema,sequence,envelope.payload) then
        return {state="corrupt",error=sequenceError or "invalid-header-or-checksum",path=path}
    end
    local decoded,data=pcall(json.decode,envelope.payload)
    local valid,accepted,reason=pcall(function()
        assert(decoded and type(data)=="table","invalid-payload")
        primitive(data)
        local untouched=json.decode(envelope.payload)
        local accepted,reason=self._validate(data)
        assert(equal(data,untouched),"validator-mutated-payload")
        return accepted,reason
    end)
    if not valid or accepted~=true then return {state="corrupt",error=reason or tostring(accepted),path=path} end
    return {state="valid",sequence=sequence,payload=envelope.payload,data=data,path=path}
end
function SaveStore:_read(path)
    local bytes,err=call(self._fs,"read",path)
    local record=self:_decode(path,bytes,err)
    record.bytes=bytes
    return record
end
function SaveStore:_inspect()
    local artifacts={a=self:_read(self._paths.a),b=self:_read(self._paths.b),candidate=self:_read(self._paths.candidate)}
    local metadata={artifacts={}}
    local archive,archiveError=self:_archiveInfo()
    if archiveError then metadata.reason="archive-verification-failed"; metadata.error=archiveError; return artifacts,nil,metadata end
    if archive then
        metadata.backupAvailable=archive.backupPublished~=nil or archive.backupCandidate~=nil
        local proposalPublished=archive.committed and artifacts[archive.manifest.target].bytes==archive.proposal
        if archive.committed and not proposalPublished then
            for _,role in ipairs({"a","b"}) do
                local value=artifacts[role]
                if value.state=="valid" and value.bytes~=archive.raw[role] and value.sequence>archive.proposed.sequence then proposalPublished=true end
            end
        end
        metadata.proposalAvailable=not proposalPublished
        metadata.backupPublished=archive.backupPublished~=nil
        metadata.backupCandidate=archive.backupCandidate~=nil
        -- The receipt grants no write authority. It can only recognize exact
        -- old bytes after the exact proposed target has actually been published.
        if artifacts[archive.manifest.target].bytes==archive.proposal and archive.committed then
            for _,key in ipairs({"a","b","candidate"}) do
                if key~=archive.manifest.target and archive.raw[key]~=false and artifacts[key].bytes==archive.raw[key] then
                    artifacts[key].archived=true
                end
            end
        end
    end
    local corrupt,any=false,false
    for _,key in ipairs({"a","b","candidate"}) do
        local value=artifacts[key]
        metadata.artifacts[key]={state=value.state,sequence=value.sequence,schema=value.schema,error=value.error,path=value.path,archived=value.archived}
        if not value.archived and value.state=="unsupported-schema" then metadata.reason="unsupported-schema"; return artifacts,nil,metadata end
        if not value.archived and value.state=="io-error" then metadata.reason="io-error"; return artifacts,nil,metadata end
        corrupt=corrupt or not value.archived and value.state=="corrupt"
        any=any or value.state~="missing"
    end
    local a,b=artifacts.a,artifacts.b
    local latest
    if a.state=="valid" and not a.archived then latest=a; metadata.slot="a" end
    if b.state=="valid" and not b.archived and(not latest or b.sequence>latest.sequence) then latest=b; metadata.slot="b" end
    if a.state=="valid" and b.state=="valid" and not a.archived and not b.archived and a.sequence==b.sequence and a.payload~=b.payload then
        metadata.reason="sequence-conflict"; return artifacts,nil,metadata
    end
    metadata.hasCorruption=corrupt
    metadata.pendingCandidate=artifacts.candidate.state=="valid" and not artifacts.candidate.archived
    if latest then
        metadata.sequence=latest.sequence
        metadata.reason=corrupt and "recovered-published" or metadata.pendingCandidate and "published-with-pending-candidate" or "published"
    elseif artifacts.candidate.state=="valid" and not artifacts.candidate.archived then
        metadata.reason="recoverable-candidate"
        metadata.candidate={sequence=artifacts.candidate.sequence,data=artifacts.candidate.data}
    else metadata.reason=any and "corrupt" or archive and "archived-adventure" or "empty" end
    return artifacts,latest,metadata
end
function SaveStore:load()
    local _,latest,metadata=self:_inspect()
    if not latest then return nil,metadata end
    return latest.data,metadata
end
function SaveStore:_envelope(data,sequence)
    local ok,bytes=pcall(function()
        assert(type(data)=="table","table-payload-required"); primitive(data)
        local payload=json.encode(data)
        assert(type(payload)=="string" and #payload<=SaveStore.MAX_PAYLOAD,"payload-too-large")
        -- Validator receives a detached JSON decode, never caller live objects.
        local detached=json.decode(payload)
        assert(equal(data,detached),"json-roundtrip-loss")
        local untouched=json.decode(payload)
        local accepted,reason=self._validate(detached)
        assert(accepted==true,reason or "payload-rejected")
        assert(equal(detached,untouched),"validator-mutated-payload")
        return json.encode({format=FORMAT,schema=SaveStore.SCHEMA,sequence=assert(DecimalInteger.encode(sequence,1,SaveStore.MAX_SEQUENCE)),payload=payload,
            checksum=boundChecksum(SaveStore.SCHEMA,sequence,payload)})
    end)
    if not ok or type(bytes)~="string" or #bytes>SaveStore.MAX_FILE then return nil,tostring(bytes) end
    return bytes
end
function SaveStore:_publish(bytes,target,sequence)
    local ok,err=call(self._fs,"write",self._paths.candidate,bytes)
    if ok~=true then return false,{reason="candidate-write-failed",error=err} end
    local verified=self:_read(self._paths.candidate)
    if verified.state~="valid" or verified.sequence~=sequence then return false,{reason="candidate-verification-failed",error=verified.error} end
    local exact=call(self._fs,"read",self._paths.candidate)
    if exact~=bytes then return false,{reason="candidate-bytes-differ"} end
    ok,err=call(self._fs,"rename",self._paths.candidate,self._paths[target])
    if ok~=true then return false,{reason="publication-failed",error=err,recoverableCandidate=true} end
    local published=self:_read(self._paths[target])
    if published.state~="valid" or published.sequence~=sequence then return false,{reason="published-verification-failed",error=published.error} end
    exact=call(self._fs,"read",self._paths[target])
    if exact~=bytes then return false,{reason="published-bytes-differ"} end
    return true,{reason="published",slot=target,sequence=sequence}
end
local function targetFor(artifacts,latest)
    if latest==artifacts.a then return "b" end
    if latest==artifacts.b then return "a" end
    -- With no known-good published state, explicit recovery may replace one
    -- damaged artifact; the other is retained as evidence.
    return artifacts.a.state=="missing" and "a" or artifacts.b.state=="missing" and "b" or "a"
end
function SaveStore:save(data)
    local artifacts,latest,metadata=self:_inspect()
    if metadata.reason=="unsupported-schema" or metadata.reason=="io-error" or metadata.reason=="sequence-conflict" or metadata.reason=="archive-verification-failed" then return false,metadata end
    if metadata.hasCorruption or not latest and metadata.reason~="empty" then metadata.reason="recovery-required"; return false,metadata end
    if metadata.pendingCandidate then metadata.reason="pending-candidate-recovery-required"; return false,metadata end
    if latest and latest.sequence>=SaveStore.MAX_SEQUENCE then return false,{reason="sequence-limit"} end
    local sequence=latest and latest.sequence+1 or 1
    local bytes,err=self:_envelope(data,sequence)
    if not bytes then return false,{reason="invalid-payload",error=err} end
    return self:_publish(bytes,targetFor(artifacts,latest),sequence)
end
function SaveStore:recover(source)
    if source=="proposal" or source=="backup-published" or source=="backup-candidate" then return self:_restoreArchive(source) end
    if source~="candidate" and source~="published" then return false,{reason="invalid-recovery-source"} end
    local artifacts,latest,metadata=self:_inspect()
    if metadata.reason=="unsupported-schema" or metadata.reason=="io-error" or metadata.reason=="sequence-conflict" or metadata.reason=="archive-verification-failed" then return false,metadata end
    local selected=source=="candidate" and artifacts.candidate or latest
    if not selected or selected.state~="valid" then return false,{reason="no-valid-"..source} end
    if source=="candidate" then
        if latest and selected.sequence<=latest.sequence then return false,{reason="candidate-not-newer"} end
        -- Do not rewrite the only good candidate. Promotion moves it to a
        -- published slot first; subsequent writes cannot destroy recovery.
        local target=targetFor(artifacts,latest)
        local snapshot,problem=self:_rawSnapshot()
        if not snapshot then return false,{reason="archive-read-failed",error=problem} end
        local archived,archiveMetadata=self:_archive(snapshot,selected.bytes,target,"recovery")
        if not archived then return false,archiveMetadata end
        local ok,err=call(self._fs,"rename",self._paths.candidate,self._paths[target])
        if ok~=true then return false,{reason="recovery-publication-failed",error=err} end
        local verified=self:_read(self._paths[target])
        if verified.state~="valid" or verified.sequence~=selected.sequence or verified.payload~=selected.payload then
            return false,{reason="recovery-verification-failed"}
        end
        return true,{reason="recovered-candidate",slot=target,sequence=verified.sequence}
    end
    if latest.sequence>=SaveStore.MAX_SEQUENCE then return false,{reason="sequence-limit"} end
    local sequence=latest.sequence+1
    local bytes,err=self:_envelope(latest.data,sequence)
    if not bytes then return false,{reason="invalid-recovery-payload",error=err} end
    local target=targetFor(artifacts,latest)
    local snapshot,problem=self:_rawSnapshot()
    if not snapshot then return false,{reason="archive-read-failed",error=problem} end
    local archived,archiveMetadata=self:_archive(snapshot,bytes,target,"recovery")
    if not archived then return false,archiveMetadata end
    return self:_publish(bytes,target,sequence)
end

-- Append-only, bounded replacement evidence. These files never grant a new
-- process permission to overwrite an adventure. Only an explicit live ticket
-- can do that; receipts recognize exact already-archived leftovers on load.
SaveStore.MAX_ARCHIVES=64
local ROLES={"a","b","candidate"}
local tickets=setmetatable({},{__mode="k"})
local SIDECAR="pokemon-playdate-save-archive"
local function keys(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"invalid-sidecar-table")
    local count=0
    for key in pairs(value) do assert(allowed[key],"unknown-sidecar-field"); count=count+1 end
    local expected=0; for _ in pairs(allowed) do expected=expected+1 end
    assert(count==expected,"missing-sidecar-field")
end
local function hashText(value) return type(value)=="string" and #value==8 and not value:find("[^0-9a-f]") end
local function packSidecar(data)
    local payload=json.encode(data)
    assert(type(payload)=="string" and #payload<=4096,"sidecar-too-large")
    return json.encode({format=SIDECAR,version=1,payload=payload,checksum=checksum(payload)})
end
local function unpackSidecar(bytes)
    assert(type(bytes)=="string" and #bytes<=8192,"invalid-sidecar-size")
    local envelope=json.decode(bytes)
    keys(envelope,{format=true,version=true,payload=true,checksum=true})
    assert(envelope.format==SIDECAR and envelope.version==1 and type(envelope.payload)=="string" and #envelope.payload<=4096
        and hashText(envelope.checksum) and checksum(envelope.payload)==envelope.checksum,"invalid-sidecar-header")
    return json.decode(envelope.payload)
end
function SaveStore:_archivePaths(index)
    local text=assert(DecimalInteger.encode(index,1,SaveStore.MAX_ARCHIVES))
    local prefix=self._prefix.."-archive-"..text
    return {a=prefix..".a.json",b=prefix..".b.json",candidate=prefix..".candidate.json",
        proposal=prefix..".proposal.json",manifest=prefix..".manifest.json",
        pending=prefix..".receipt-pending.json",receipt=prefix..".receipt.json"}
end
-- A listing narrows discovery only. Every selected index still uses the
-- original read probes and content validation, with no cross-call cache.
function SaveStore:_listedArchiveIndexes()
    if type(self._fs.list) ~= "function" then
        return nil
    end
    local directory <const>, basename <const> = self._prefix:match("^(.*)/([^/]+)$")
    local entries <const>, problem <const> = call(self._fs, "list", directory or ".")
    if problem ~= nil then
        return nil
    end
    if type(entries) ~= "table" or getmetatable(entries) ~= nil then
        return nil
    end

    local indexes <const> = {}
    local stem <const> = (basename or self._prefix) .. "-archive-"
    local suffixes <const> = {
        ["a.json"]=true, ["b.json"]=true, ["candidate.json"]=true,
        ["proposal.json"]=true, ["manifest.json"]=true,
        ["receipt-pending.json"]=true, ["receipt.json"]=true,
    }
    local count = 0
    for key, name in pairs(entries) do
        -- An unusable listing cannot establish that any path is absent.
        if not integer(key, 1, #entries) or type(name) ~= "string" then
            return nil
        end
        count = count + 1
        -- SDK listings suffix directories with '/'. A directory occupying an
        -- archive path still needs the normal read/error checks, not omission.
        local basename <const> = name:gsub("/$", "")
        if basename:sub(1, #stem) == stem then
            local text <const>, suffix <const> = basename:sub(#stem + 1):match("^([1-9][0-9]*)%.(.+)$")
            local index <const> = text and DecimalInteger.decode(text, 1, SaveStore.MAX_ARCHIVES)
            if index and suffixes[suffix] then
                indexes[index] = true
            end
        end
    end
    if count ~= #entries then
        return nil
    end
    return indexes
end
function SaveStore:_rawSnapshot()
    local snapshot={}
    for _,role in ipairs(ROLES) do
        local bytes,err=call(self._fs,"read",self._paths[role])
        if bytes==nil then
            if err~="missing" then return nil,"unreadable-"..role end
            snapshot[role]=false
        elseif type(bytes)~="string" or #bytes>SaveStore.MAX_FILE then return nil,"invalid-raw-"..role
        else snapshot[role]=bytes end
    end
    return snapshot
end
function SaveStore:_matches(snapshot)
    local now,problem=self:_rawSnapshot()
    if not now then return false,problem end
    for _,role in ipairs(ROLES) do if now[role]~=snapshot[role] then return false,"stale-observation" end end
    return true
end
local function descriptor(bytes)
    return {present=bytes~=false,length=bytes==false and 0 or #bytes,checksum=bytes==false and "00000000" or checksum(bytes)}
end
local function validateDescriptor(value)
    keys(value,{present=true,length=true,checksum=true})
    assert(type(value.present)=="boolean" and integer(value.length,0,SaveStore.MAX_FILE) and hashText(value.checksum),"invalid-byte-descriptor")
    assert(value.present or value.length==0 and value.checksum=="00000000","invalid-missing-descriptor")
end
function SaveStore:_verifiedArchive(index,committed)
    local paths=self:_archivePaths(index)
    local ok,record=pcall(function()
        local manifestBytes=assert(call(self._fs,"read",paths.manifest),"missing-manifest")
        local manifest=unpackSidecar(manifestBytes)
        keys(manifest,{index=true,mode=true,target=true,roles=true,proposal=true})
        assert(DecimalInteger.decode(manifest.index,1,SaveStore.MAX_ARCHIVES)==index,"invalid-archive-index")
        assert(manifest.mode=="replacement" or manifest.mode=="recovery" or manifest.mode=="restore","invalid-archive-mode")
        assert(manifest.target=="a" or manifest.target=="b","invalid-archive-target")
        keys(manifest.roles,{a=true,b=true,candidate=true})
        local raw={}
        for _,role in ipairs(ROLES) do
            local item=manifest.roles[role]; validateDescriptor(item)
            local bytes,err=call(self._fs,"read",paths[role])
            if item.present then
                assert(type(bytes)=="string" and #bytes==item.length and checksum(bytes)==item.checksum,"archive-bytes-differ")
                raw[role]=bytes
            else assert(bytes==nil and err=="missing","unexpected-archive-file"); raw[role]=false end
        end
        validateDescriptor(manifest.proposal); assert(manifest.proposal.present,"missing-proposal")
        local proposal=assert(call(self._fs,"read",paths.proposal),"unreadable-proposal")
        assert(#proposal==manifest.proposal.length and checksum(proposal)==manifest.proposal.checksum,"proposal-bytes-differ")
        local proposed=self:_decode(paths.proposal,proposal)
        assert(proposed.state=="valid","invalid-proposal")
        if committed then
            local receipt=unpackSidecar(assert(call(self._fs,"read",paths.receipt),"missing-receipt"))
            keys(receipt,{index=true,manifestChecksum=true,proposalChecksum=true})
            assert(receipt.index==manifest.index and receipt.manifestChecksum==checksum(manifestBytes)
                and receipt.proposalChecksum==checksum(proposal),"receipt-binding-differs")
        end
        local best,candidate,conflicting
        for _,role in ipairs(ROLES) do
            if raw[role]~=false then
                local previous=self:_decode(paths[role],raw[role])
                if previous.state=="valid" then
                    if role=="candidate" then candidate=previous
                    elseif not best or previous.sequence>best.sequence then best=previous
                    elseif previous.sequence==best.sequence and previous.payload~=best.payload then conflicting=true end
                end
            end
        end
        return {index=index,manifest=manifest,raw=raw,proposal=proposal,proposed=proposed,
            backupPublished=not conflicting and best or nil,backupCandidate=candidate,committed=committed}
    end)
    if not ok then return nil,"archive-content-invalid" end
    return record
end
function SaveStore:_archiveInfo()
    local latestReceipt,latestManifest
    local indexes <const> = self:_listedArchiveIndexes()
    for index=1,SaveStore.MAX_ARCHIVES do
        if not indexes or indexes[index] then
            local paths <const> = self:_archivePaths(index)
            local receipt <const>, err <const> = call(self._fs, "read", paths.receipt)
            if receipt ~= nil then
                latestReceipt = index
            elseif err ~= "missing" then
                return nil, "unreadable-receipt"
            end
            local manifest <const>, problem <const> = call(self._fs, "read", paths.manifest)
            if manifest ~= nil then
                latestManifest = index
            elseif problem ~= "missing" then
                return nil, "unreadable-manifest"
            end
        end
    end
    -- Never fall back to an older receipt when the latest is corrupt.
    local record,problem
    if latestReceipt then record,problem=self:_verifiedArchive(latestReceipt,true); if not record then return nil,problem end end
    if latestManifest and (not latestReceipt or latestManifest>latestReceipt) then
        local pending,pendingError=self:_verifiedArchive(latestManifest,false)
        if not pending then return nil,pendingError end
        return pending -- Complete archive, interrupted before receipt.
    end
    return record
end
function SaveStore:prepareReplacement()
    local snapshot,problem=self:_rawSnapshot()
    if not snapshot then return nil,{reason="archive-read-failed",error=problem} end
    local ticket={}
    tickets[ticket]={owner=self,snapshot=snapshot}
    return ticket
end
function SaveStore:cancelReplacement(ticket) tickets[ticket]=nil end
function SaveStore:_archive(snapshot,proposal,target,mode)
    local matches,problem=self:_matches(snapshot)
    if not matches then return false,{reason="stale-replacement",error=problem} end
    local highest=0
    local indexes <const> = self:_listedArchiveIndexes()
    for n=1,SaveStore.MAX_ARCHIVES do
        if not indexes or indexes[n] then
            for _, path in pairs(self:_archivePaths(n)) do
                local bytes <const>, err <const> = call(self._fs, "read", path)
                if bytes ~= nil then
                    highest = n
                elseif err ~= "missing" then
                    return false, {reason="archive-read-failed"}
                end
            end
        end
    end
    if highest>=SaveStore.MAX_ARCHIVES then return false,{reason="archive-limit"} end
    local index=highest+1
    local paths=self:_archivePaths(index)
    local function writeExact(path,bytes)
        local ok=call(self._fs,"write",path,bytes)
        if ok~=true then return false end
        return call(self._fs,"read",path)==bytes
    end
    local manifest={index=assert(DecimalInteger.encode(index,1,SaveStore.MAX_ARCHIVES)),mode=mode,target=target,roles={},proposal=descriptor(proposal)}
    for _,role in ipairs(ROLES) do
        manifest.roles[role]=descriptor(snapshot[role])
        if snapshot[role]~=false and not writeExact(paths[role],snapshot[role]) then return false,{reason="archive-write-failed",archive=index} end
    end
    if not writeExact(paths.proposal,proposal) then return false,{reason="archive-proposal-failed",archive=index} end
    local manifestBytes=packSidecar(manifest)
    if not writeExact(paths.manifest,manifestBytes) then return false,{reason="archive-manifest-failed",archive=index} end
    local verified,verifyError=self:_verifiedArchive(index,false)
    if not verified then return false,{reason="archive-verification-failed",error=verifyError} end
    matches,problem=self:_matches(snapshot)
    if not matches then return false,{reason="stale-replacement",error=problem} end
    local receipt=packSidecar({index=manifest.index,manifestChecksum=checksum(manifestBytes),proposalChecksum=checksum(proposal)})
    if not writeExact(paths.pending,receipt) then return false,{reason="archive-receipt-write-failed",archive=index} end
    local published=call(self._fs,"rename",paths.pending,paths.receipt)
    if published~=true then return false,{reason="archive-receipt-publication-failed",archive=index} end
    verified,verifyError=self:_verifiedArchive(index,true)
    if not verified then return false,{reason="archive-verification-failed",error=verifyError} end
    matches,problem=self:_matches(snapshot)
    if not matches then return false,{reason="stale-replacement",error=problem} end
    return true,{archived=true,archive=index}
end
function SaveStore:_replaceSnapshot(data,snapshot,mode)
    local highest=0
    for _,role in ipairs(ROLES) do
        if snapshot[role]~=false then
            local record=self:_decode(self._paths[role],snapshot[role])
            if record.state=="valid" then highest=math.max(highest,record.sequence) end
        end
    end
    -- A newly confirmed adventure is a new sequence lineage; MAX does not
    -- prevent it. Old envelopes are retained and recognized only by exact bytes.
    local sequence=highest==SaveStore.MAX_SEQUENCE and 1 or highest+1
    local bytes,problem=self:_envelope(data,sequence)
    if not bytes then return false,{reason="invalid-payload",error=problem} end
    local archived,metadata=self:_archive(snapshot,bytes,"a",mode)
    if not archived then return false,metadata end
    local ok,result=self:_publish(bytes,"a",sequence)
    result.archived,result.archive=true,metadata.archive
    return ok,result
end
function SaveStore:replace(data,ticket)
    local request=tickets[ticket]
    if not request or request.owner~=self then return false,{reason="replacement-not-authorized"} end
    local matches,problem=self:_matches(request.snapshot)
    if not matches then return false,{reason="stale-replacement",error=problem} end
    -- One attempt per explicit confirmation. A partial publication requires
    -- explicit Title recovery, never a silently refreshed observation.
    tickets[ticket]=nil
    return self:_replaceSnapshot(data,request.snapshot,"replacement")
end
function SaveStore:_restoreArchive(source)
    local archive,problem=self:_archiveInfo()
    if not archive then return false,{reason="archive-verification-failed",error=problem} end
    local record
    if source=="proposal" then record=archive.proposed
    elseif source=="backup-published" then record=archive.backupPublished
    else record=archive.backupCandidate end
    if not record then return false,{reason="no-valid-"..source} end
    local snapshot,readError=self:_rawSnapshot()
    if not snapshot then return false,{reason="archive-read-failed",error=readError} end
    return self:_replaceSnapshot(record.data,snapshot,"restore")
end
