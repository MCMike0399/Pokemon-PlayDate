TitleArchiveSafetyContracts={}
local invocation=0
function TitleArchiveSafetyContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}}
 local private=HarnessBuild and HarnessBuild.enabled and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
 if not private then return {ok=false,passed=0,failed=1,tests={{name="private SDK Data required",ok=false,error="no files touched"}}}end
 invocation=invocation+1;local fs=SaveStore.sdkFilesystem()
 for _,kind in ipairs({"manifest","receipt"})do
  local ok,problem=pcall(function()
   local prefix="title-ascii-"..HarnessBuild.session_id.."-"..invocation.."-"..kind
   local store=SaveStore(prefix,function(data)return type(data)=="table" and data.revision==1 end,fs)
   assert(fs.write(store._paths.a,"old A"));assert(fs.write(store._paths.b,"old B"));assert(fs.write(store._paths.candidate,"old candidate"))
   assert(store:replace({revision=1},assert(store:prepareReplacement())))
   local paths=store:_archivePaths(1);assert(fs.write(paths[kind],"\255\254\0malformed sidecar"))
   local before={};for key,path in pairs(store._paths)do local bytes=fs.read(path);before[key]=bytes or false end
   local data,metadata=store:load();assert(data==nil and metadata.reason=="archive-verification-failed")
   assert(metadata.error=="archive-content-invalid","raw parser error escaped ASCII boundary")
   local encoded=json.encode(metadata);assert(not encoded:find("[\128-\255]"),"non-ASCII metadata")
   assert(json.decode(encoded).error=="archive-content-invalid")
   local saved,why=store:save({revision=1});assert(saved==false and why.reason=="archive-verification-failed")
   for key,path in pairs(store._paths)do local bytes=fs.read(path);assert((bytes or false)==before[key],"primary bytes changed")end
  end)
  report.tests[#report.tests+1]={name="Binary-corrupt "..kind.." fails closed with ASCII diagnostics and unchanged primary bytes",ok=ok,error=not ok and tostring(problem)or nil}
  if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 return report
end
