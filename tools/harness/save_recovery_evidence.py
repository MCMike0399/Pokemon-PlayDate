"""Independent byte-level verifier for the real two-process native evidence.

This checks stored evidence. It does not implement SaveStore or simulate SDK IO.
"""
import hashlib
import json
import math
from pathlib import Path

SEED = {'a': b'original damaged published A\x00\xff',
        'b': b'original damaged published B',
        'candidate': b'original damaged unpublished candidate'}
ROLES = frozenset(SEED)


def require(ok, why):
    if not ok:
        raise ValueError(why)


def fnv(data):
    value=2166136261
    for byte in data:
        value=((value ^ byte)*16777619)&0xffffffff
    return f'{value:08x}'


def decode(data):
    def pairs(items):
        value={}
        for key,item in items:
            require(key not in value,'duplicate JSON field')
            value[key]=item
        return value
    return json.loads(data.decode('utf-8'),object_pairs_hook=pairs)


def exact(value, fields):
    require(isinstance(value,dict) and set(value)==set(fields),'unexpected object fields')


def decimal(value, low, high):
    require(isinstance(value,str) and value.isascii() and value.isdecimal() and str(int(value))==value,'noncanonical decimal')
    require(low<=int(value)<=high,'decimal out of bounds')
    return int(value)


def sidecar(raw):
    value=decode(raw)
    exact(value,{'format','version','payload','checksum'})
    require(value['format']=='pokemon-playdate-save-archive' and type(value['version']) is int and value['version']==1,'sidecar header')
    require(isinstance(value['payload'],str) and len(value['payload'].encode())<=4096,'sidecar payload bound')
    require(fnv(value['payload'].encode())==value['checksum'],'sidecar checksum')
    return decode(value['payload'].encode())


def primitive(value, depth=0):
    require(depth<=64,'payload too deep')
    if type(value) in (str,bool):
        return
    if type(value) in (int,float):
        require(-2147483647<=value<=2147483647 and math.isfinite(value),'invalid payload number')
        return
    require(type(value) in (dict,list),'nonprimitive payload')
    if type(value) is dict:
        require(all(type(key) is str for key in value),'invalid payload key')
        items=value.values()
    else:
        require(len(value)<=1000000,'payload array bound')
        items=value
    for item in items:
        primitive(item,depth+1)


def envelope(raw):
    require(type(raw) is bytes and 1<=len(raw)<=1048576,'save file bound')
    value=decode(raw)
    exact(value,{'format','schema','sequence','payload','checksum'})
    require(value['format']=='pokemon-playdate-save' and type(value['schema']) is int and value['schema']==1,'save schema')
    decimal(value['sequence'],1,2147483647)
    require(type(value['payload']) is str,'save payload type')
    try:
        payload=value['payload'].encode('utf-8')
    except UnicodeEncodeError as error:
        raise ValueError('invalid payload encoding') from error
    require(len(payload)<=262144,'save payload bound')
    require(fnv(b'1\n'+value['sequence'].encode()+b'\n'+payload)==value['checksum'],'save checksum')
    data=decode(payload)
    require(type(data) in (dict,list),'table payload required')
    primitive(data)
    return data


def descriptor(value, raw):
    exact(value,{'present','length','checksum'})
    require(type(value['present']) is bool and type(value['length']) is int and 0<=value['length']<=1048576,'descriptor bounds')
    require(value['present']==(raw is not None),'descriptor presence')
    if raw is None:
        require(value['length']==0 and value['checksum']=='00000000','missing descriptor')
    else:
        require(len(raw)==value['length'] and fnv(raw)==value['checksum'],'archived bytes differ')


def verify_archive(data, index=1, expected=None):
    data=Path(data)
    prefix='adventure-archive-'+str(index)
    manifest_raw=(data/(prefix+'.manifest.json')).read_bytes()
    manifest=sidecar(manifest_raw)
    exact(manifest,{'index','mode','target','roles','proposal'})
    require(decimal(manifest['index'],1,64)==index,'archive index')
    require(manifest['mode'] in {'replacement','recovery','restore'} and manifest['target'] in {'a','b'},'archive mode/target')
    exact(manifest['roles'],ROLES)
    for role in ROLES:
        path=data/(prefix+'.'+role+'.json')
        raw=path.read_bytes() if path.exists() else None
        descriptor(manifest['roles'][role],raw)
        if expected is not None:require(raw==expected[role],'original bytes lost: '+role)
    proposal=(data/(prefix+'.proposal.json')).read_bytes()
    descriptor(manifest['proposal'],proposal)
    payload=envelope(proposal)
    receipt=sidecar((data/(prefix+'.receipt.json')).read_bytes())
    exact(receipt,{'index','manifestChecksum','proposalChecksum'})
    require(receipt['index']==manifest['index'] and receipt['manifestChecksum']==fnv(manifest_raw) and receipt['proposalChecksum']==fnv(proposal),'receipt binding')
    require((data/('adventure.'+manifest['target']+'.json')).read_bytes()==proposal,'planned target not exact proposal')
    for role in ROLES-{'a'}:
        path=data/('adventure.'+role+'.json')
        if path.exists():
            require(expected is not None and path.read_bytes()==expected[role],'unknown leftover is not archived evidence')
    return {'proposal_sha256':hashlib.sha256(proposal).hexdigest(),'archive_index':index,'session_payload':payload}


def verify_run(output):
    output=Path(output)
    run=decode((output/'run.json').read_bytes())
    processes=run['processes']
    require(len(processes)==2,'must be two actual processes')
    require(processes[0]['pid']!=processes[1]['pid'],'same process reused')
    for process in processes:
        require(process['status']=='exited' and process['previous_exit_confirmed'] and process['fresh_ready'],'unconfirmed process lifecycle')
    first=output/processes[0]['evidence']/'runtime-data'
    second=output/processes[1]['evidence']/'runtime-data'
    proof1=verify_archive(first,expected=SEED)
    proof2=verify_archive(second,expected=SEED)
    require(proof1==proof2,'continued process changed saved bytes')
    hashes=lambda root:{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in root.glob('adventure*')if p.is_file()}
    require(hashes(first)==hashes(second),'boot/Continue changed durable save files')
    return {'ok':True,'distinct_pids':[p['pid']for p in processes],
            'proposal_sha256':proof1['proposal_sha256'],'archive_index':proof1['archive_index'],
            'exact_original_files':{k:hashlib.sha256(v).hexdigest()for k,v in SEED.items()}}
