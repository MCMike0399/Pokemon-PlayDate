"""Offline fixtures test generation checks independently of network/cache state."""
import copy
from decimal import Decimal, localcontext, ROUND_HALF_UP
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH = Path(__file__).resolve().parents[1] / 'generate_growth_data.py'
spec = importlib.util.spec_from_file_location('growth_generator', PATH)
g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)

# Independent textbook threshold formula, evaluated using unbounded integers.
def threshold(group, n):
    if n == 1: return 0
    if group == 0: return n**3
    if group == 1:
        if n <= 50: return n**3*(100-n)//50
        if n <= 68: return n**3*(150-n)//100
        if n <= 98: return n**3*((1911-10*n)//3)//500
        return n**3*(160-n)//100
    if group == 2:
        if n <= 15: return n**3*((n+1)//3+24)//50
        if n <= 35: return n**3*(n+14)//50
        return n**3*(n//2+32)//50
    if group == 3: return 6*n**3//5-15*n*n+100*n-140
    if group == 4: return 4*n**3//5
    return 5*n**3//4

def fixture():
    experience = 'growth_rate_id,level,experience\n'
    independent = ''
    for api, group in g.GROWTH_IDS.items():
        values = [threshold(group,n) for n in range(1,101)]
        experience += ''.join(f'{api},{n},{v}\n' for n,v in enumerate(values,1))
        independent += f'Growth{group} => [' + ','.join(map(str,values)) + '];\n'
    personal = bytearray(53884)
    species = 'id,growth_rate_id\n'
    for dex in range(1,152):
        api = 1+(dex%6);group=g.GROWTH_IDS[api]
        species += f'{dex},{api}\n'; personal[dex*76+0x15]=group
        personal[dex*76+0x22:dex*76+0x24]=(64).to_bytes(2,'little')
    rates = 'id,identifier\n1,slow\n2,medium\n3,fast\n4,medium-slow\n5,slow-then-very-fast\n6,fast-then-very-slow\n'
    return {'experience.csv':experience.encode(),'Experience.cs':independent.encode(),
            'pokemon_species.csv':species.encode(),'personal_b2w2':bytes(personal),'growth_rates.csv':rates.encode()}

class GrowthTests(unittest.TestCase):
    def test_all_six_curves_independent_fixture(self):
        tables,species=g.collect(fixture()); self.assertEqual(len(species),151)
        self.assertEqual([tables[n][100] for n in range(6)],[1000000,600000,1640000,1059860,800000,1250000])
        self.assertEqual([tables[3][n] for n in [1,5,6,7]],[0,135,179,236])
    def test_q12_roots_against_decimal_oracle(self):
        with localcontext() as ctx:
            ctx.prec=60
            for n in range(1,211):
                root=int((Decimal(n).sqrt()*4096).to_integral_value(rounding=ROUND_HALF_UP))
                self.assertEqual(g.scaled_power(n),root*n*n//4096,n)
    def test_render_deterministic(self): self.assertEqual(g.render(fixture()),g.render(fixture()))
    def test_missing_level_rejected(self):
        f=fixture();f['experience.csv']=f['experience.csv'].replace(b'1,100,1250000\n',b'')
        with self.assertRaisesRegex(g.GenerationError,'incomplete'):g.collect(f)
    def test_duplicate_level_rejected(self):
        f=fixture();f['experience.csv']+=b'1,100,1250000\n'
        with self.assertRaisesRegex(g.GenerationError,'duplicate'):g.collect(f)
    def test_threshold_disagreement_rejected(self):
        f=fixture();f['experience.csv']=f['experience.csv'].replace(b'1,100,1250000',b'1,100,1250001')
        with self.assertRaisesRegex(g.GenerationError,'disagreement'):g.collect(f)
    def test_species_disagreement_rejected(self):
        f=fixture();b=bytearray(f['personal_b2w2']);b[76+0x15]=5;f['personal_b2w2']=bytes(b)
        with self.assertRaisesRegex(g.GenerationError,'species growth disagreement'):g.collect(f)
    def test_missing_species_rejected(self):
        f=fixture();f['pokemon_species.csv']=f['pokemon_species.csv'].replace(b'151,2\n',b'')
        with self.assertRaisesRegex(g.GenerationError,'incomplete original151'):g.collect(f)
    def test_bad_schema_rejected(self):
        with self.assertRaisesRegex(g.GenerationError,'schema'):g.rows(b'wrong\n1\n',['id'])
    def test_corrupt_cache_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'x';p.write_bytes(b'corrupt')
            manifest={'files':{'x':{'sha256':hashlib.sha256(b'good').hexdigest(),'url':'https://example.invalid'}}}
            with self.assertRaisesRegex(g.GenerationError,'checksum'):g.load_sources(tmp,manifest=manifest)
            self.assertEqual(p.read_bytes(),b'corrupt')
    def test_missing_cache_no_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(g.GenerationError,'missing pinned'):g.load_sources(tmp,manifest={'files':{'x':{}}})
    def test_fetch_failure_rejected(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g.urllib.request,'urlopen',side_effect=OSError('offline')):
            with self.assertRaisesRegex(g.GenerationError,'fetch failed'):g.load_sources(tmp,True,{'files':{'x':{'url':'https://example.invalid'}}})
    def test_check_drift_nonzero_no_write(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g,'load_sources',return_value=fixture()):
            p=Path(tmp)/'out.lua';p.write_text('old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p),'--check']),1)
            self.assertEqual(p.read_text(),'old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p)]),0)
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p),'--check']),0)
if __name__=='__main__':unittest.main()
