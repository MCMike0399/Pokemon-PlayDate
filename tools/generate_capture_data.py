#!/usr/bin/env python3
"""Generate original151 B2W2 catch rates from two checked immutable sources."""
import argparse
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import urllib.request
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'tools/references/capture-sources.json'
class GenerationError(ValueError):pass

def load(cache,fetch=False,manifest=None):
    manifest=manifest or json.loads(MANIFEST.read_text());out={}
    for name,spec in manifest['files'].items():
        path=Path(cache)/name
        if path.exists():raw=path.read_bytes()
        elif fetch:
            try:
                with urllib.request.urlopen(spec['url'],timeout=45) as response:raw=response.read()
            except OSError as error:raise GenerationError(f'fetch failed {name}: {error}') from error
        else:raise GenerationError(f'missing pinned input {path}; use --fetch')
        if hashlib.sha256(raw).hexdigest()!=spec['sha256']:raise GenerationError(f'checksum mismatch {name}; cache preserved')
        out[name]=raw
        if not path.exists():path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)
    return out

def collect(raw):
    binary=raw['personal_b2w2']
    if len(binary)!=53884:raise GenerationError('unexpected B2W2 personal length')
    layout=raw['PersonalInfo5B2W2.cs'].decode('utf-8')
    if 'SIZE = 0x4C' not in layout or 'CatchRate { get => Data[0x08]' not in layout:raise GenerationError('unsupported personal layout')
    reader=csv.DictReader(io.StringIO(raw['pokemon_species.csv'].decode('utf-8')))
    if not {'id','capture_rate'} <= set(reader.fieldnames or []):raise GenerationError('missing species capture schema')
    rates={}
    for row in reader:
        dex=int(row['id'])
        if not 1<=dex<=151:continue
        if dex in rates:raise GenerationError('duplicate species catch rate')
        rate=int(row['capture_rate'])
        if not 1<=rate<=255:raise GenerationError('invalid species catch rate')
        if binary[dex*76+8]!=rate:raise GenerationError(f'independent catch rate disagreement: {dex}')
        rates[dex]=rate
    if set(rates)!=set(range(1,152)):raise GenerationError('incomplete original151 catch rates')
    return rates

def render(raw):
    rates=collect(raw)
    return '\n'.join(['-- Generated from pinned B2W2 personal data; independent PokeAPI cross-check.',
      '-- See tools/references/capture-sources.json. Indexed by National Dex.', 'CaptureData = {']+
      [f'    [{dex}] = {rate},' for dex,rate in sorted(rates.items())]+['}',''])

def main(argv=None):
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cache',type=Path,required=True);p.add_argument('--fetch',action='store_true');p.add_argument('--output',type=Path,required=True);p.add_argument('--check',action='store_true');args=p.parse_args(argv)
    try:
        text=render(load(args.cache,args.fetch))
        if args.check:
            if not args.output.exists() or args.output.read_text()!=text:raise GenerationError('generated catch-rate drift')
        else:args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(text)
        print('151 B2W2 catch rates cross-checked');return 0
    except (OSError,ValueError,KeyError,TypeError) as error:print(f'capture generation failed: {error}',file=sys.stderr);return 1
if __name__=='__main__':raise SystemExit(main())
