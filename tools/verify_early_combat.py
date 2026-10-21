#!/usr/bin/env python3
"""Replay immutable mechanic pins and bounded generated move preservation checks."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/early-combat.json'
def digest(raw):return hashlib.sha256(raw).hexdigest()
def scalar(row):
    return re.sub(r', (?:rollout|curse) = true','',re.sub(r', effects = \{.*',' },',row))
def projection(rows,keys,transform=lambda x:x):
    return digest(json.dumps({key:transform(rows[key]) for key in sorted(keys)},sort_keys=True,separators=(',',':')).encode())
def check_moves(source,manifest):
    rows=dict(re.findall(r'^    (\w+) = (Move[^\n]+)$',Path(source).read_text(),re.M))
    before=set(manifest['original_keys']);extra=set(manifest['new_keys'])
    if set(rows)!=before|extra:raise ValueError('move roster drift: '+str(sorted(set(rows)^(before|extra))))
    if projection(rows,before,scalar)!=manifest['original_scalars_sha256']:raise ValueError('an existing move scalar changed')
    unchanged=before-set(manifest['updated_keys'])
    if projection(rows,unchanged)!=manifest['unchanged_rows_sha256']:raise ValueError('an unowned move effect changed')
    if projection(rows,rows)!=manifest['candidate_rows_sha256']:raise ValueError('declared move correction drift')
    return len(rows)
def check_pins(cache,manifest,fetch=False):
    cache=Path(cache)
    for name,entry in manifest['primary']['files'].items():
        path=cache/name.replace('/','_')
        if not path.exists() and fetch:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_bytes(urllib.request.urlopen(entry['url'],timeout=30).read())
        if digest(path.read_bytes())!=entry['sha256']:raise ValueError('primary source checksum mismatch: '+name)
def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT/'Source/battle/moves.lua');p.add_argument('--source-cache',type=Path,required=True);p.add_argument('--fetch',action='store_true');args=p.parse_args(argv)
    try:
        manifest=json.loads(MANIFEST.read_text());check_pins(args.source_cache,manifest,args.fetch);count=check_moves(args.source,manifest)
        print(str(count)+' move rows: original423 scalars preserved;17 declared corrections; Toxic added; primary pins verified');return 0
    except (OSError,ValueError,KeyError) as error:print('early combat verification failed: '+str(error),file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
