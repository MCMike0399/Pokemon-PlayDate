"""Explicit declarative move migrations; no generator, Lua or TS execution.

Original scalars and arbitrary effects are never normalized away. Only missing
producer-owned fields and exact declared payload pairs may migrate.
"""
import hashlib,json,re
from pathlib import Path
from tools.verify_moves.parse_lua import Reader,TOKEN
ROOT=Path(__file__).resolve().parents[1]
CONTRACT_SHA256='886897fb9411a8cb1d0c65b25c95acf398be3f06acbd3939da833513a31d3d71'
META_SHA256='c277e8d18b6c8523281b84dbc43db136e576c03395d9b5ef3e6763d62cb424dd'
PROTECTION_SHA256='66c23d6bd5e78ecfae62a656e0c0612c793dc902be41d48fc351cf1bd900d462'
PAYLOAD=('effects','secondaries')
ABILITY_FIELDS=('contact','hasSecondary','ohko','typeImmunity','sandWeakened')
RULE_FIELDS=('powerRule','damageRule','attemptRule','chargeRule','lockRule','weatherAccuracy')
RULES={'electroBall':{'powerRule':'electroBall'},'assurance':{'powerRule':'assurance'},'endeavor':{'damageRule':'endeavor'},'suckerPunch':{'attemptRule':'suckerPunch'},'ragePowder':{'attemptRule':'singlesRedirect'},'bide':{'damageRule':'bide'},'captivate':{'attemptRule':'oppositeSex'},'solarBeam':{'chargeRule':'solarBeam'},'skullBash':{'chargeRule':'skullBash'},'petalDance':{'lockRule':'rampage'},'thunder':{'weatherAccuracy':True},'hurricane':{'weatherAccuracy':True},'worrySeed':{'attemptRule':'worrySeed'}}
RULE_EPOCHS={**dict.fromkeys(('electroBall','assurance','endeavor','suckerPunch','ragePowder'),3),'bide':4,'captivate':5,'solarBeam':6,'skullBash':6,'petalDance':6,'thunder':7,'hurricane':7,'worrySeed':8}
PROTECTION_FIELDS=('protectable','breaksProtect')
PRODUCER_FIELDS=ABILITY_FIELDS+('critStage',)+RULE_FIELDS+PROTECTION_FIELDS
def digest(raw):return hashlib.sha256(raw).hexdigest()
def read_rows(text):
    pairs=re.findall(r'^    (\w+) = (Move[^\n]+)$',text,re.M)
    if len({key for key,row in pairs})!=len(pairs):raise ValueError('duplicate declarative move row')
    return dict(pairs)
def fields(row):
    match=re.fullmatch(r'Move\s*(?:\(\s*)?(\{.*\})\s*\)?\s*,?',row)
    if not match:raise ValueError('malformed declarative move row')
    values=[m.group()for m in TOKEN.finditer(match[1])if not m.group().isspace()and not m.group().startswith('--')]
    parser=Reader(values);result=parser.table()
    if parser.peek()is not None or not isinstance(result,dict):raise ValueError('malformed move fields')
    return result

def payload(value):
    if isinstance(value,str):value=fields(value)
    out={}
    for key in PAYLOAD:
        entries=value.get(key,[])
        if not isinstance(entries,list)or any(not hasattr(v,'text')for v in entries):raise ValueError('non-declarative move payload')
        out[key]=[v.text for v in entries]
    return out

def field_spans(row):
    tokens=[m for m in TOKEN.finditer(row)if not m.group().isspace()and not m.group().startswith('--')]
    depth=0;parens=0;root_parens=None;comma=None;active=None;spans={};previous=None
    for i,m in enumerate(tokens):
        token=m.group()
        if token=='{'and depth==0:root_parens=parens
        if depth==1 and parens==root_parens:
            if token==','or token=='}':
                if active is not None:spans[active][1]=previous.end();active=None
                if token==',':comma=m.start()
            elif re.fullmatch(r'[A-Za-z_]\w*',token)and i+1<len(tokens)and tokens[i+1].group()=='=':
                active=token;spans[token]=[comma,None,m.start()]
        if token=='{':depth+=1
        elif token=='}':depth-=1
        elif token=='(':parens+=1
        elif token==')':parens-=1
        previous=m
    return spans

def drop_fields(row,names):
    spans=field_spans(row);remove=[]
    for key in names:
        if key in spans:
            start,end,_=spans[key]
            if start is None or end is None:raise ValueError('producer field must follow original scalar fields')
            remove.append((start,end))
    for start,end in sorted(remove,reverse=True):row=row[:start]+row[end:]
    return row

def split_payload(row):
    spans=field_spans(row);starts=[spans[k][0]for k in PAYLOAD if k in spans]
    if starts:
        start=min(starts)
        # Payloads must be the tail: unknown scalars after a payload cannot hide.
        first=min(spans[k][2]for k in PAYLOAD if k in spans)
        if any(span[2]>first for key,span in spans.items()if key not in PAYLOAD):raise ValueError('scalar after move payload')
        return row[:start],row[start:]
    match=re.search(r'\s*\}\s*\)?\s*,?$',row)
    if not match:raise ValueError('missing move row terminator')
    return row[:match.start()],row[match.start():]

def load_contract():
    path=ROOT/'tools/references/move-producer-migrations.json';raw=path.read_bytes()
    if digest(raw)!=CONTRACT_SHA256:raise ValueError('move migration contract checksum mismatch')
    result=json.loads(raw)
    if result['schema']!=1:raise ValueError('unsupported move migration contract')
    return result

def metadata():
    path=ROOT/'tools/references/ability-move-metadata.json';raw=path.read_bytes()
    if digest(raw)!=META_SHA256:raise ValueError('ability move metadata checksum mismatch')
    result=json.loads(raw)
    if result.get('schema')!=1 or result.get('revision')!='9b136a8c8cdb860a8ab96fa063f906604e352547':raise ValueError('unverified move metadata source')
    for key,row in result['moves'].items():
        if set(row)!={'contact','secondary','ohko','typeImmunity'}or any(type(v)is not bool for v in row.values()):raise ValueError('invalid literal move metadata '+key)
    return result['moves']

def producer_metadata():
    result=dict(metadata())
    for key,row in load_contract().get('added_moves',{}).items():
        if key in result:raise ValueError('added move collides with historical metadata: '+key)
        result[key]=row['metadata']
    return result

def protection_metadata():
    raw=(ROOT/'tools/references/protection-move-metadata.json').read_bytes()
    if digest(raw)!=PROTECTION_SHA256:raise ValueError('protection metadata checksum mismatch')
    result=json.loads(raw)
    if result.get('schema')!=1 or result.get('generation')!=5 or result.get('revision')!='9b136a8c8cdb860a8ab96fa063f906604e352547':raise ValueError('unverified protection metadata source')
    rows=result['moves']
    if set(rows)!=set(producer_metadata()):raise ValueError('protection metadata roster mismatch')
    for key,row in rows.items():
        if set(row)!=set(PROTECTION_FIELDS) or any(type(v)is not bool for v in row.values()):raise ValueError('invalid protection metadata '+key)
    return rows

def historical_rows(rows,epoch=None):
    result=dict(rows)
    for key,entry in load_contract().get('added_moves',{}).items():
        if key in result:
            row=result[key];value=fields(row)
            if (epoch or 0)>=9 or (epoch is None and any(k in value for k in PROTECTION_FIELDS)):
                expected=protection_metadata()[key]
                if any(type(value.get(k))is not bool or value[k]!=v for k,v in expected.items()):raise ValueError('an added move protection metadata changed: '+key)
                row=drop_fields(row,PROTECTION_FIELDS)
            if row!=entry['row']:raise ValueError('an added move scalar or effect changed: '+key)
            del result[key]
    return result

def additions(key,semantics,epoch=9):
    expected={'contact':semantics['contact'],'hasSecondary':semantics['secondary'],'ohko':semantics['ohko']}
    if semantics['typeImmunity']:expected['typeImmunity']=True
    if key=='solarBeam':expected['sandWeakened']=True
    if epoch>=9:expected.update(protection_metadata()[key])
    return expected

def producer_epoch(text):
    marker=re.search(r'^-- move-producer-contract: (\d+)$',text,re.M)
    if marker:
        version=int(marker[1])
        if version not in (1,2,3,4,5,6,7,8,9,10,11,12):raise ValueError('unsupported move producer epoch')
        return version
    if re.search(r'self\.protectable\s*=',text) or any(any(field in fields(row)for field in PROTECTION_FIELDS)for row in read_rows(text).values()):return 9
    if re.search(r'self\.(?:powerRule|damageRule|attemptRule)\s*=',text):return 3
    if re.search(r'self\.critStage\s*=',text):return 2
    return 1 if any(any(field in fields(row)for field in ABILITY_FIELDS)for row in read_rows(text).values())else 0

def same(a,b):
    if type(a)is not type(b):return False
    if isinstance(a,dict):return set(a)==set(b)and all(same(v,b[k])for k,v in a.items())
    if isinstance(a,list):return len(a)==len(b)and all(same(x,y)for x,y in zip(a,b))
    return a==b

def compatible(key,old,new,semantics,contract=None,epoch=0):
    if new is None:return False
    before,after=fields(old),fields(new);left=dict(before);expected=additions(key,semantics)
    expected.update(RULES.get(key,{}))
    if 'critStage'in after:expected['critStage']=after['critStage']
    # Only genuinely pre-ability inputs may acquire missing v1 fields.
    # Epoch2 critical metadata may be introduced from complete epoch1 inputs.
    if 'targetId'not in left:
        if epoch>=1:return False
        left['targetId']=after['targetId']
    for field in PRODUCER_FIELDS:
        if field in left:
            if field not in expected or type(left[field])is not type(expected[field])or left[field]!=expected[field]:return False
        elif field in expected:
            introduced=9 if field in PROTECTION_FIELDS else RULE_EPOCHS[key] if field in RULE_FIELDS else 2 if field=='critStage' else 1
            if epoch>=introduced:return False
            left[field]=expected[field]
    if not same({k:v for k,v in left.items()if k not in PAYLOAD},{k:v for k,v in after.items()if k not in PAYLOAD}):return False
    if payload(left)==payload(after):return True
    transitions=(contract or load_contract())['transitions'].get(key,[])
    # Exact forward-only declared edges; never normalize arbitrary payloads.
    # PoisonFang needs v0 legacy -> v1 typed -> v12 Gen5 correction in one run.
    reachable=[(epoch,payload(left))]
    for entry in sorted(transitions,key=lambda entry:entry['version']):
        if any(version<entry['version'] and value==entry['before']for version,value in reachable):
            if entry['after']==payload(after):return True
            reachable.append((entry['version'],entry['after']))
    return False

def legacy_rows(rows,epoch=None):
    """Reverse exact declared v1 payloads, then retain ORIGINAL legacy hashes."""
    contract=load_contract();semantics=metadata();result={}
    inferred=max([1]+[RULE_EPOCHS[key]for key,row in rows.items()if key in RULES and any(field in fields(row)for field in RULE_FIELDS)]+[9 for row in rows.values()if any(field in fields(row)for field in PROTECTION_FIELDS)])
    rows=historical_rows(rows,epoch or inferred)
    migrated=any(any(k in fields(row)for k in ABILITY_FIELDS)for row in rows.values())
    if not migrated:return dict(rows)
    critical=(epoch is not None and epoch>=2) or any('critStage'in fields(row)or 'FocusEnergyEffect'in row for row in rows.values())
    rules=(epoch is not None and epoch>=3) or any(any(field in fields(row)for field in RULE_FIELDS)for row in rows.values())
    version=max(epoch or 0,inferred,3 if rules else 2 if critical else 1)
    for key,row in rows.items():
        value=fields(row);expected=additions(key,semantics[key],epoch=version)
        if rules and RULE_EPOCHS.get(key,3)<=version:expected.update(RULES.get(key,{}))
        if critical and key in contract['critical']['nonzero']:expected['critStage']=contract['critical']['nonzero'][key]
        if any(field not in value or type(value[field])is not type(flag)or value[field]!=flag for field,flag in expected.items()):raise ValueError('an existing move scalar changed: producer metadata '+key)
        if any(field in value and field not in expected for field in PRODUCER_FIELDS):raise ValueError('an existing move scalar changed: unexpected producer metadata '+key)
        lowered=drop_fields(row,PRODUCER_FIELDS)
        entries=[entry for entry in contract['transitions'].get(key,[])if entry['version']<=version]
        if entries:
            # A current file must retain this key's latest declared semantics.
            # Accepting any historical 'after' would hide a v12->v1 rollback.
            latest=max(entry['version']for entry in entries)
            entries=[entry for entry in entries if entry['version']==latest]
            matches=[entry for entry in entries if payload(value)==entry['after']]
            if len(matches)!=1:raise ValueError('an unowned move effect changed: declared migration '+key)
            prefix,_=split_payload(lowered);lowered=prefix+matches[0]['legacy_suffix']
        result[key]=lowered
    return result
