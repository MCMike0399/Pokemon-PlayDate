"""Read reviewed source/test evidence; metadata alone never proves a rule.

A changed handler, definition or assertion makes a claim stale, not missing or
complete. The immutable accepted result is distinct from current source bytes.
"""
import hashlib,json
from pathlib import Path
from .parse_lua import Expression
from .fetch_pokeapi import SourceError

def primitive(value):
    if isinstance(value,Expression):return value.text
    if isinstance(value,dict):return{k:primitive(v)for k,v in value.items()}
    if isinstance(value,list):return[primitive(v)for v in value]
    return value

def definition_hash(row):
    return hashlib.sha256(json.dumps(primitive(row),sort_keys=True,separators=(',',':')).encode()).hexdigest()

def region(project,proof):
    path=Path(proof['path'])
    if path.is_absolute()or'..'in path.parts:raise SourceError('unsafe runtime evidence path')
    raw=(project/path).read_text()
    if proof.get('function_body') is True:
        lines=raw.splitlines(keepends=True);indices=[i for i,line in enumerate(lines)if line.startswith(proof['start'])]
        if len(indices)!=1:return None
        i=indices[0]
        if proof.get('one_line') is True:return lines[i]
        ends=[j for j in range(i+1,len(lines))if lines[j].strip()=='end'and lines[j].startswith('end')]
        return ''.join(lines[i:ends[0]+1])if ends else None
    if proof.get('exact_line') is True:
        found=[line for line in raw.splitlines(keepends=True)if line.lstrip().startswith(proof['start'])]
        return found[0]if len(found)==1 else None
    if proof.get('whole_file') is True:return raw
    start=raw.find(proof['start']);end=raw.find(proof['end'],start+len(proof['start']))
    if start<0 or end<0:return None
    return raw[start:end]

def evidence_path(project, name):
    path=Path(name)
    if path.is_absolute() or '..' in path.parts:
        raise SourceError('unsafe SDK result path')
    resolved=(project/path).resolve()
    if not resolved.is_relative_to(project.resolve()):
        raise SourceError('SDK result escapes project')
    return resolved

def executed_tests(project, record, summary, accepted):
    """Bind curated claims to one complete native contract result or explicit projection.

    Raw contract replies precede the harness terminal barrier; quiescence is
    deliberately not inferred here. This is scoped SDK evidence, not a journey.
    """
    try:
        pin=record['sdk_result']
        raw=evidence_path(project,pin['path']).read_bytes()
        digest=hashlib.sha256(raw).hexdigest()
        if digest!=pin['sha256'] or digest!=record['sdk_result_sha256']:
            raise SourceError('actual SDK result hash differs')
        result=json.loads(raw)
        if 'raw_provenance' in pin or 'evidence_format' in result:
            provenance=result.get('raw_provenance',{})
            if (result.get('evidence_format')!='contracts-projection-v1'
                    or provenance!=pin.get('raw_provenance')
                    or set(provenance)!={'path','sha256','size_bytes'}
                    or not isinstance(provenance['path'],str) or not Path(provenance['path']).is_absolute()
                    or not isinstance(provenance['sha256'],str) or len(provenance['sha256'])!=64
                    or any(c not in '0123456789abcdef' for c in provenance['sha256'])
                    or type(provenance['size_bytes'])is not int or provenance['size_bytes']<=0):
                raise SourceError('invalid contracts projection raw provenance')
        source=summary['source_sha256']
        if (pin['source_sha256']!=source or result.get('build_id')!=pin['build_id']
                or pin['build_id'].rsplit(':',1)[-1]!=source):
            raise SourceError('actual SDK build/source differs')
        if result.get('protocol')!=1 or result.get('status')!='ok':
            raise SourceError('actual SDK result did not succeed')
        reports=[r for r in result['results'] if r.get('op')=='contracts' or 'contracts' in r]
        if len(reports)!=1:
            raise SourceError('expected exactly one actual SDK contract report')
        reply=reports[0]
        if reply.get('op')!='contracts' or reply.get('status')!='ok' or reply.get('outcome')!='ok':
            raise SourceError('incomplete actual SDK contract reply')
        report=reply['contracts']
        passed,failed=report['passed'],report['failed']
        if (type(passed)is not int or type(failed)is not int or passed<0 or failed!=0
                or report.get('ok')is not True or passed!=pin['passed'] or failed!=pin['failed']
                or passed!=summary['sdk_passed'] or passed!=accepted['sdk']['passed']
                or failed!=accepted['sdk']['failed']):
            raise SourceError('actual SDK report totals differ or failed')
        tests=report['tests'];suites=report['suites']
        if not isinstance(tests,list) or len(tests)!=passed+failed or not isinstance(suites,list) or not suites:
            raise SourceError('incomplete actual SDK contract inventory')
        canonical={}
        for test in tests:
            name=test['name']
            if not isinstance(name,str) or not name or name in canonical or test.get('ok')is not True:
                raise SourceError('duplicate, invalid or failed actual SDK test')
            canonical[name]=test
        suite_ids=set();suite_passed=0
        for suite in suites:
            ident=suite['id']
            if (not isinstance(ident,str) or not ident or ident in suite_ids
                    or suite.get('ok')is not True or type(suite['passed'])is not int
                    or suite['passed']<0 or type(suite['failed'])is not int or suite['failed']!=0):
                raise SourceError('incomplete actual SDK suite')
            suite_ids.add(ident);suite_passed+=suite['passed']
        # Twenty original core assertions are intentionally outside named suites.
        if len(suites)!=pin['suite_count'] or suite_passed!=pin['suite_passed'] or suite_passed>passed:
            raise SourceError('actual SDK suite totals differ')
        return canonical
    except SourceError:raise
    except (KeyError,TypeError,ValueError,OSError,AttributeError) as error:
        raise SourceError('invalid actual SDK evidence: '+str(error)) from error

def load_runtime_coverage(project,moves,evidence_file=None):
    project=Path(project);path=Path(evidence_file)if evidence_file else project/'tools/references/runtime-move-coverage.json'
    record=json.loads(path.read_text())
    if record.get('schema')!=1 or record.get('scope')!='reviewed-source-and-executed-SDK-subsets':raise SourceError('invalid runtime coverage schema')
    summary=record['accepted_summary'];p=Path(summary['path'])
    if p.is_absolute()or'..'in p.parts:raise SourceError('unsafe accepted summary path')
    raw=(project/p).read_bytes()
    if hashlib.sha256(raw).hexdigest()!=summary['sha256']:raise SourceError('accepted runtime summary drift')
    data=json.loads(raw)
    if data.get('source_sha256')!=summary['source_sha256']or data.get('sdk',{}).get('passed')!=summary['sdk_passed']:raise SourceError('accepted runtime identity differs')
    canonical=executed_tests(project,record,summary,data)
    out={}
    for key,entry in record['moves'].items():
        if key not in moves:continue
        problems=[];owner_checks=[];test_checks=[]
        if definition_hash(moves[key])!=entry['definition_sha256']:problems.append('move definition differs from reviewed row')
        for proof in entry['owners']:
            body=region(project,proof)
            current_hash=hashlib.sha256(body.encode()).hexdigest()if body is not None else None
            owner_checks.append({'path':proof['path'],'selector':proof.get('start','whole-file'),'declared_sha256':proof['sha256'],'current_sha256':current_hash,'equal':current_hash==proof['sha256']})
            if current_hash!=proof['sha256']:problems.append('handler body changed: '+proof['path']+' '+proof.get('start','whole-file'))
        for proof in entry['tests']:
            if proof.get('executed',{}).get('ok')is not True or proof['executed'].get('name')!=proof['accepted_name']:raise SourceError('invalid executed SDK claim')
            if not(proof['accepted_name']==proof['name']or proof['accepted_name'].endswith(': '+proof['name'])):raise SourceError('exact SDK test name differs')
            actual=canonical.get(proof['accepted_name'])
            if actual is None or actual.get('ok')is not True or proof['executed']!=actual:
                raise SourceError('executed claim differs from actual canonical SDK test')
            body=region(project,proof)
            current_hash=hashlib.sha256(body.encode()).hexdigest()if body is not None else None
            test_checks.append({'name':proof['name'],'declared_sha256':proof['sha256'],'current_sha256':current_hash,'equal':current_hash==proof['sha256']})
            if current_hash!=proof['sha256']:problems.append('SDK assertion body changed: '+proof['name'])
        state=entry['state']
        if state not in('verified_subset','source_only','source_gap'):raise SourceError('unknown runtime coverage state')
        if state=='verified_subset'and not entry['tests']:raise SourceError('verified runtime subset lacks meaningful executed test')
        if not entry['owners']:raise SourceError('runtime claim lacks reviewed source owner')
        out[key]={'state':'stale'if problems else state,'capabilities':entry['capabilities']if not problems else[],
                  'scope':entry['scope'],'reasons':problems,'owner_checks':owner_checks,'assertion_checks':test_checks,'evidence':{'registry':str(path),'registry_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'accepted_source_sha256':summary['source_sha256'],
                  'acceptance_context':record.get('acceptance_context','accepted-main950'),'sdk_result_sha256':record['sdk_result_sha256'],'sdk_result_path':record['sdk_result']['path'],'sdk_build_id':record['sdk_result']['build_id'],'tests':[p['accepted_name']for p in entry['tests']]}}
    return out
