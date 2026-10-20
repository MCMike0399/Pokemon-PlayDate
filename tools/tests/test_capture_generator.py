import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.tests.capture_oracle import parameters, attempt
PATH=Path(__file__).resolve().parents[1]/'generate_capture_data.py'
spec=importlib.util.spec_from_file_location('capture_generator',PATH);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
def fixture():
    binary=bytearray(53884);rows=['id,capture_rate']
    for dex in range(1,152):binary[dex*76+8]=3 if dex in [144,145,146,150] else 45;rows.append(f'{dex},{binary[dex*76+8]}')
    return {'personal_b2w2':bytes(binary),'pokemon_species.csv':('\n'.join(rows)+'\n').encode(),'PersonalInfo5B2W2.cs':b'SIZE = 0x4C; CatchRate { get => Data[0x08]; }'}
class CaptureGeneratorTests(unittest.TestCase):
    def test_all151_independent_rows(self):
        rates=g.collect(fixture());self.assertEqual(len(rates),151);self.assertEqual(rates[150],3);self.assertEqual(rates[1],45)
    def test_rate_disagreement(self):
        f=fixture();f['pokemon_species.csv']=f['pokemon_species.csv'].replace(b'150,3',b'150,4')
        with self.assertRaisesRegex(g.GenerationError,'disagreement: 150'):g.collect(f)
    def test_missing_species(self):
        f=fixture();f['pokemon_species.csv']=f['pokemon_species.csv'].replace(b'151,45\n',b'')
        with self.assertRaisesRegex(g.GenerationError,'incomplete'):g.collect(f)
    def test_duplicate_species(self):
        f=fixture();f['pokemon_species.csv']+=b'151,45\n'
        with self.assertRaisesRegex(g.GenerationError,'duplicate'):g.collect(f)
    def test_bad_rate(self):
        f=fixture();f['pokemon_species.csv']=f['pokemon_species.csv'].replace(b'151,45',b'151,0')
        with self.assertRaisesRegex(g.GenerationError,'invalid species'):g.collect(f)
    def test_bad_schema(self):
        f=fixture();f['pokemon_species.csv']=b'wrong\n1\n'
        with self.assertRaisesRegex(g.GenerationError,'schema'):g.collect(f)
    def test_bad_layout(self):
        f=fixture();f['PersonalInfo5B2W2.cs']=b'SIZE=12'
        with self.assertRaisesRegex(g.GenerationError,'layout'):g.collect(f)
    def test_bad_binary_length(self):
        f=fixture();f['personal_b2w2']=b'bad'
        with self.assertRaisesRegex(g.GenerationError,'length'):g.collect(f)
    def test_cache_failures_preserve_bytes(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'x';p.write_bytes(b'bad')
            with self.assertRaisesRegex(g.GenerationError,'checksum'):g.load(tmp,manifest={'files':{'x':{'sha256':hashlib.sha256(b'good').hexdigest()}}})
            self.assertEqual(p.read_bytes(),b'bad')
    def test_missing_cache_offline(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(g.GenerationError,'missing pinned'):g.load(tmp,manifest={'files':{'x':{}}})
    def test_fetch_failure(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g.urllib.request,'urlopen',side_effect=OSError('offline')):
            with self.assertRaisesRegex(g.GenerationError,'fetch failed'):g.load(tmp,True,{'files':{'x':{'url':'https://example.invalid'}}})
    def test_check_drift_no_write(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g,'load',return_value=fixture()):
            out=Path(tmp)/'data.lua';out.write_text('old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(out),'--check']),1);self.assertEqual(out.read_text(),'old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(out)]),0);self.assertEqual(g.main(['--cache',tmp,'--output',str(out),'--check']),0)
    def test_literal_parameter_vectors_match_independent_oracle(self):
        data=json.loads((PATH.parent/'references/capture-vectors.json').read_text())
        self.assertEqual(len(data['parameters']),64)
        for v in data['parameters']:
            self.assertEqual(parameters(v['rate'],v['hp'],v['maxHP'],v['ball'],v['status'],v['caughtCount']),v['expected'])
    def test_literal_replays_and_strict_boundary_vectors(self):
        data=json.loads((PATH.parent/'references/capture-vectors.json').read_text())
        self.assertEqual(len(data['attempts']),25)
        for v in data['attempts']:self.assertEqual(attempt(v['expected'],v['seed']),v['attempt'])
        boundaries={v['boundary']:v for v in data['attempts'] if 'boundary' in v}
        self.assertEqual(boundaries['first shake threshold']['attempt']['caught'],False)
        self.assertEqual(boundaries['first shake threshold-minus-one']['attempt']['caught'],True)
        self.assertEqual(boundaries['critical threshold']['attempt']['critical'],False)
        self.assertEqual(boundaries['critical threshold-minus-one']['attempt']['critical'],True)
    def test_simple_known_threshold_and_status_vectors(self):
        self.assertEqual(parameters(255,20,20,'pokeBall',None,30),{'modifiedRate4096':348160,'shakeThreshold':49802,'criticalThreshold':0})
        self.assertEqual(parameters(3,20,20,'pokeBall',None,151),{'modifiedRate4096':4096,'shakeThreshold':16400,'criticalThreshold':0})
        self.assertEqual(parameters(255,1,20,'ultraBall','sleep',151)['modifiedRate4096'],1044480)
if __name__=='__main__':unittest.main()
