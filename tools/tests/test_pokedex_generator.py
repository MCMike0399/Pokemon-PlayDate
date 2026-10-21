"""Deterministic synthetic source fixtures; no network or SDK substitute."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
p=Path(__file__).resolve().parents[1]/'generate_pokedex.py'
spec=importlib.util.spec_from_file_location('dexgen',p);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
def fixture():
    keys=[f'DEX_S{i}' for i in range(1,152)]+['0']*39
    names=[f'S{i}' for i in range(1,152)]+['MISSINGNO.']*39
    labels=[f'S{i}DexEntry' for i in range(1,152)]+['MissingNoDexEntry']*39
    raw={'constants/pokedex_constants.asm':''.join(f' const DEX_S{i} ; {i}\n' for i in range(1,152)),
    'data/pokemon/dex_order.asm':''.join(' db '+k+'\n' for k in keys),
    'data/pokemon/names.asm':''.join(' dname "'+n+'"\n' for n in names),
    'data/pokemon/dex_entries.asm':''.join(' dw '+n+'\n' for n in labels)+''.join(f'S{i}DexEntry:\n db "TEST@"\n db 1,2\n dw 30\n text_far _S{i}DexEntry\n' for i in range(1,152)),
    'data/pokemon/dex_text.asm':''.join(f'_S{i}DexEntry::\n text "A #MON"\n next "second line"\n page "next page"\n dex\n' for i in range(1,152))}
    return raw,{i:'s'+str(i) for i in range(1,152)}
class PokedexGeneratorTests(unittest.TestCase):
    def test_all151_and_internal_order_mapping(self):
        raw,species=fixture();entries=g.parse(raw,species)
        self.assertEqual(len(entries),151);self.assertEqual(entries[150]['species'],'s151')
        self.assertEqual(entries[0]['lines'],['A POKEMON','second line','','next page'])
        self.assertEqual(entries[0]['heightFeet'],1);self.assertEqual(entries[0]['heightInches'],2);self.assertEqual(entries[0]['weightTenthsLb'],30)
        # Internal order is independent of National Dex order.
        for path,token in [('dex_order','DEX_S'),('names','S')]:
            source='data/pokemon/'+path+'.asm';lines=raw[source].splitlines();lines[0],lines[1]=lines[1],lines[0];raw[source]='\n'.join(lines)+'\n'
        source='data/pokemon/dex_entries.asm';raw[source]=raw[source].replace(' dw S1DexEntry\n dw S2DexEntry',' dw S2DexEntry\n dw S1DexEntry')
        e=g.parse(raw,species);self.assertEqual(e[0]['sourceInternalId'],2);self.assertEqual(e[0]['name'],'S1')
    def test_ascii_aliases_and_limits(self):
        for source,expected in [('NIDORAN♀','NIDORAN F'),('NIDORAN♂','NIDORAN M'),('MR.MIME','MR. MIME'),("FARFETCH'D","FARFETCH'D")]:self.assertEqual(g.ascii_name(source),expected)
        for name in ['','ABCDEFGHIJK','NIDORANé']:
            with self.assertRaises(g.DataError):g.ascii_name(name)
    def test_corrupt_schema_and_missing_roster_reject(self):
        raw,species=fixture()
        variants=[('data/pokemon/dex_order.asm',' db DEX_S2\n',' db DEX_S1\n'),('data/pokemon/dex_entries.asm',' dw S1DexEntry\n',' dw UnknownDexEntry\n'),('data/pokemon/dex_entries.asm',' db 1,2\n',' db 1,12\n'),('data/pokemon/dex_text.asm',' dex\n',' broken\n'),('data/pokemon/names.asm',' dname "S1"\n','')]
        for path,before,after in variants:
            bad=copy.deepcopy(raw);bad[path]=bad[path].replace(before,after,1)
            with self.subTest(path=path),self.assertRaises(g.DataError):g.parse(bad,species)
    def test_checksum_pin_and_path_escape(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);(root/'source').write_text('original');m={'inputs':[{'path':'source','sha256':g.sha(b'original')}]}
            self.assertEqual(g.read_pins(root,m)['source'],'original');(root/'source').write_text('changed')
            with self.assertRaisesRegex(g.DataError,'checksum'):g.read_pins(root,m)
            m['inputs'][0]['path']='../outside'
            with self.assertRaisesRegex(g.DataError,'escape'):g.read_pins(root,m)
    def test_check_drift_nonzero_and_no_write(self):
        raw,species=fixture();entries=g.parse(raw,species)
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);manifest=root/'manifest.json';manifest.write_text(json.dumps({'schema':1,'species':[species[i] for i in range(1,152)]}))
            pokemon=root/'pokemon.lua';pokemon.write_text('fixture')
            with patch.object(g,'MANIFEST',manifest),patch.object(g,'projection',return_value=species),patch.object(g,'read_pins',return_value=raw):
                args=['--reference-root',td,'--pokemon-source',str(pokemon),'--output-root',td]
                self.assertEqual(g.main(args),0);self.assertEqual(g.main(args+['--check']),0)
                data=root/'Source/data/pokedexData.lua';data.write_text('corrupt');self.assertEqual(g.main(args+['--check']),1);self.assertEqual(data.read_text(),'corrupt')
    def test_no_live_generation(self):
        self.assertEqual(g.main(['--reference-root','/absent','--output-root',str(g.ROOT)]),1)
if __name__=='__main__':unittest.main()
