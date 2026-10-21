import importlib.util,json,os,re,shutil,hashlib,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('generate_teaching_data',ROOT/'tools/generate_machine_data.py');m=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(m)

class TeachingDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.reference=Path(os.environ['KANTO_REFERENCE']);cls.data=m.generate(cls.reference)
        cls.rows={row['species']:row for row in cls.data['species']}
    def test_all55_literal_numeric_machine_identities(self):
        ids=[5,13,14,18,25,92,32,34,36,38,61,55,58,59,63,6,66,68,69,99,72,76,82,85,87,89,90,91,94,100,102,104,115,117,118,120,121,126,129,130,135,138,143,156,86,149,153,157,161,164,15,19,57,70,148]
        self.assertEqual([row['move_id']for row in self.data['machines']],ids)
        self.assertEqual(self.data['machines'][33]['move_key'],'bide')
        self.assertEqual([row['item_id']for row in self.data['machines'][:50]],list(range(201,251)))
        self.assertEqual([row['item_id']for row in self.data['machines'][50:]],list(range(196,201)))
    def test_all151_raw_bitmaps_and8305_bits_match_independent_personal_rb(self):
        pin=json.loads((ROOT/'tools/references/teaching-independent/pkhex-source-pin.json').read_text())
        name='PKHeX.Core/Resources/byte/personal/personal_rb';path=ROOT/'tools/references/teaching-independent/pkhex'/name;raw=path.read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(),pin[name]['sha256']);self.assertEqual(len(raw),152*28)
        name='PKHeX.Core/PersonalInfo/Info/PersonalInfo1.cs';path=ROOT/'tools/references/teaching-independent/pkhex'/name
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(),pin[name]['sha256'])
        code=path.read_text();self.assertIn('SIZE = 0x1C',code);self.assertIn('TMHM = 0x14',code)
        block=code.split('MachineMoves =>',1)[1].split('];',1)[0];ids=[int(value)for value in re.findall(r'\b\d{3}\b',block)]
        self.assertEqual(ids,[row['move_id']for row in self.data['machines']])
        checked=0
        for row in self.data['species']:
            original=raw[row['dex']*28+20:row['dex']*28+27]
            self.assertEqual(bytes.fromhex(row['bitmap_hex']),original,row['species'])
            for index,machine in enumerate(self.data['machines']):
                self.assertEqual(machine['id']in row['machines'],bool(original[index//8]&(1<<(index%8))),row['species']+' '+machine['id']);checked+=1
        self.assertEqual(checked,8305)
    def test_literal_source_vectors_and_blue_charizard_not_yellow(self):
        self.assertEqual(set(self.rows['bulbasaur']['machines']),{'tm03','tm06','tm08','tm09','tm10','tm20','tm21','tm22','tm31','tm32','tm33','tm34','tm44','tm50','hm01'})
        self.assertEqual({key for key in self.rows['squirtle']['machines']if key.startswith('hm')},{'hm03','hm04'})
        self.assertNotIn('hm02',self.rows['charizard']['machines']);self.assertNotIn('hm03',self.rows['pikachu']['machines'])
        self.assertEqual({row['species']for row in self.data['species']if not row['machines']},{'caterpie','metapod','weedle','kakuna','magikarp','ditto'})
    def test_mew_unused_bit_is_separate_not_machine56(self):
        self.assertEqual(self.rows['mew']['bitmap_hex'],'ffffffffffffff');self.assertTrue(self.rows['mew']['unused_bit_55'])
        self.assertEqual(len(self.rows['mew']['machines']),55);self.assertEqual(sum(row['unused_bit_55']for row in self.data['species']),1)
        self.assertEqual(sum(len(row['machines'])for row in self.data['species']),3037)
    def test_deterministic_checked_output(self):
        self.assertEqual((ROOT/'Source/data/machineData.lua').read_text(),m.render(self.data))
        self.assertEqual((json.dumps(self.data,indent=2,sort_keys=True)+'\n').encode(),(ROOT/'tools/references/blue-machines.json').read_bytes())
    def test_tampered_source_and_unknown_compatibility_symbol_reject(self):
        with tempfile.TemporaryDirectory()as directory:
            root=Path(directory);pin=json.loads(m.PIN.read_text())
            for name in pin['files']:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(self.reference/name,target)
            name='data/pokemon/base_stats/bulbasaur.asm';path=root/name;path.write_text(path.read_text().replace('BIDE','NOT_A_TM'))
            with self.assertRaisesRegex(ValueError,'checksum drift'):m.generate(root)
            pin['files'][name]=hashlib.sha256(path.read_bytes()).hexdigest();p=root/'pin.json';p.write_text(json.dumps(pin))
            with self.assertRaisesRegex(ValueError,'invalid compatibility symbol'):m.generate(root,p)
    def test_approved_economy_exact50_consumed_tm_and5_reusable_hm(self):
        self.assertEqual(sum(row['consume_on_success']for row in self.data['machines']),50)
        self.assertTrue(all(not row['consume_on_success']for row in self.data['machines'][50:]))

if __name__=='__main__':unittest.main()
