-- Published-slot transactional save container. Import after lib/oop.
-- No implicit reset, migration, world snapshot or battle-resume behavior.
import "domain/decimalInteger"

Class("SaveStore")
SaveStore.SCHEMA,SaveStore.MAX_SEQUENCE=1,2147483647
SaveStore.MAX_PAYLOAD,SaveStore.MAX_FILE=262144,1048576
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
    return {
        read=function(path)
            if not playdate.file.exists(path) then return nil,"missing" end
            local size=playdate.file.getSize(path)
            if not integer(size,0,SaveStore.MAX_FILE) then return nil,"file-size-invalid" end
            if size==0 then return "" end
            local file,err=playdate.file.open(path,playdate.file.kFileRead)
            if not file then return nil,err or "open-failed" end
            local ok,bytes,count=pcall(function() return file:read(size) end)
            local closed=pcall(function() file:close() end)
            if not ok or not closed or type(bytes)~="string" or #bytes~=size or count~=size then return nil,"read-failed" end
            return bytes
        end,
        write=function(path,bytes)
            local file,err=playdate.file.open(path,playdate.file.kFileWrite)
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
        rename=function(from,to) return playdate.file.rename(from,to) end,
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
    self._validate,self._fs=validate,filesystem or SaveStore.sdkFilesystem()
    assert(type(self._fs.read)=="function" and type(self._fs.write)=="function" and type(self._fs.rename)=="function","invalid filesystem adapter")
    self._paths={a=prefix..".a.json",b=prefix..".b.json",candidate=prefix..".candidate.json"}
end
function SaveStore:_read(path)
    local bytes,err=call(self._fs,"read",path)
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
function SaveStore:_inspect()
    local artifacts={a=self:_read(self._paths.a),b=self:_read(self._paths.b),candidate=self:_read(self._paths.candidate)}
    local metadata={artifacts={}}
    local corrupt,any=false,false
    for _,key in ipairs({"a","b","candidate"}) do
        local value=artifacts[key]
        metadata.artifacts[key]={state=value.state,sequence=value.sequence,schema=value.schema,error=value.error,path=value.path}
        if value.state=="unsupported-schema" then metadata.reason="unsupported-schema"; return artifacts,nil,metadata end
        if value.state=="io-error" then metadata.reason="io-error"; return artifacts,nil,metadata end
        corrupt=corrupt or value.state=="corrupt"
        any=any or value.state~="missing"
    end
    local a,b=artifacts.a,artifacts.b
    local latest
    if a.state=="valid" then latest=a; metadata.slot="a" end
    if b.state=="valid" and(not latest or b.sequence>latest.sequence) then latest=b; metadata.slot="b" end
    if a.state=="valid" and b.state=="valid" and a.sequence==b.sequence and a.payload~=b.payload then
        metadata.reason="sequence-conflict"; return artifacts,nil,metadata
    end
    metadata.hasCorruption=corrupt
    metadata.pendingCandidate=artifacts.candidate.state=="valid"
    if latest then
        metadata.sequence=latest.sequence
        metadata.reason=corrupt and "recovered-published" or metadata.pendingCandidate and "published-with-pending-candidate" or "published"
    elseif artifacts.candidate.state=="valid" then
        metadata.reason="recoverable-candidate"
        metadata.candidate={sequence=artifacts.candidate.sequence,data=artifacts.candidate.data}
    else metadata.reason=any and "corrupt" or "empty" end
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
    if metadata.reason=="unsupported-schema" or metadata.reason=="io-error" or metadata.reason=="sequence-conflict" then return false,metadata end
    if metadata.hasCorruption or not latest and metadata.reason~="empty" then metadata.reason="recovery-required"; return false,metadata end
    if metadata.pendingCandidate then metadata.reason="pending-candidate-recovery-required"; return false,metadata end
    if latest and latest.sequence>=SaveStore.MAX_SEQUENCE then return false,{reason="sequence-limit"} end
    local sequence=latest and latest.sequence+1 or 1
    local bytes,err=self:_envelope(data,sequence)
    if not bytes then return false,{reason="invalid-payload",error=err} end
    return self:_publish(bytes,targetFor(artifacts,latest),sequence)
end
function SaveStore:recover(source)
    if source~="candidate" and source~="published" then return false,{reason="invalid-recovery-source"} end
    local artifacts,latest,metadata=self:_inspect()
    if metadata.reason=="unsupported-schema" or metadata.reason=="io-error" or metadata.reason=="sequence-conflict" then return false,metadata end
    local selected=source=="candidate" and artifacts.candidate or latest
    if not selected or selected.state~="valid" then return false,{reason="no-valid-"..source} end
    if source=="candidate" then
        if latest and selected.sequence<=latest.sequence then return false,{reason="candidate-not-newer"} end
        -- Do not rewrite the only good candidate. Promotion moves it to a
        -- published slot first; subsequent writes cannot destroy recovery.
        local target=targetFor(artifacts,latest)
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
    return self:_publish(bytes,targetFor(artifacts,latest),sequence)
end
