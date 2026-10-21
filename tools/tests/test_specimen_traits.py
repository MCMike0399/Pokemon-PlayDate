import re,subprocess,sys,hashlib,importlib.util,json,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('traits_generator',ROOT/'tools/generate_specimen_traits.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
class TraitSources(unittest.TestCase):
 def test_full151_ratios_and_native_light_ball_crosswalk(self):
  data=g.collect(g.load(ROOT/'tools/references/traits'),ROOT)
  self.assertEqual(len(data),151);counts={}
  for row in data.values():counts[row['ratio']]=counts.get(row['ratio'],0)+1
  self.assertEqual(counts,{0:6,31:19,63:10,127:91,191:6,254:6,255:13})
  self.assertEqual(data['pikachu']['held'],[0,236,0]);self.assertEqual(data['nidoranF']['ratio'],254);self.assertEqual(data['nidoranM']['ratio'],0)
 def test_all72_original151_evolution_edges_preserve_ratio(self):
  data=g.collect(g.load(ROOT/'tools/references/traits'),ROOT);n=0
  for species,body in re.findall(r'^    (\w+) = (.*)$',(ROOT/'Source/data/evolutionData.lua').read_text(),re.M):
   for target in re.findall(r'to = "(\w+)"',body):self.assertEqual(data[species]['ratio'],data[target]['ratio']);n+=1
  self.assertEqual(n,72)
 def test_primary_light_ball_both_stats_and_post_stage_hook_order(self):
  raw=g.load(ROOT/'tools/references/traits');base=raw['ps_data_items.ts'].decode();body=base.split('\tlightball: {',1)[1].split('\n\t},',1)[0]
  for token in ('onModifyAtkPriority: 1','onModifySpAPriority: 1','onModifyAtk(','onModifySpA(','chainModify(2)'):self.assertIn(token,body)
  self.assertEqual(body.count("pokemon.baseSpecies.baseSpecies === 'Pikachu'"),2)
  for version in (8,7,6,5):self.assertNotRegex(raw[f'ps_data_mods_gen{version}_items.ts'].decode(),r'(?m)^\tlightball:')
  actions=raw['ps_sim_battle-actions.ts'].decode();self.assertLess(actions.index('let attack = attacker.calculateStat('),actions.index("attack = this.battle.runEvent('Modify'"))
  self.assertNotIn('getDamage(',raw['ps_data_mods_gen5_scripts.ts'].decode())
 def test_generated_files_exact(self):
  data=g.collect(g.load(ROOT/'tools/references/traits'),ROOT)
  self.assertEqual((ROOT/'Source/data/specimenTraits.lua').read_text(),g.render(data))
  self.assertEqual((ROOT/'Source/data/lightBall.lua').read_text(),g.item())
 def test_cli_check_fails_on_changed_generated_ratio_without_rewriting(self):
  with tempfile.TemporaryDirectory()as tmp:
   root=Path(tmp);command=[sys.executable,str(ROOT/'tools/generate_specimen_traits.py'),'--project',str(ROOT),'--output',str(root)]
   self.assertEqual(subprocess.run(command,capture_output=True).returncode,0)
   self.assertEqual(subprocess.run(command+['--check'],capture_output=True).returncode,0)
   path=root/'Source/data/specimenTraits.lua';changed=path.read_text().replace('pikachu=127','pikachu=255');path.write_text(changed)
   result=subprocess.run(command+['--check'],capture_output=True);self.assertNotEqual(result.returncode,0);self.assertIn(b'trait drift',result.stderr);self.assertEqual(path.read_text(),changed)
 def test_missing_or_changed_input_rejects(self):
  with tempfile.TemporaryDirectory()as tmp:
   root=Path(tmp)
   with self.assertRaises(FileNotFoundError):g.load(root)
   first=next(iter(json.loads(g.MANIFEST.read_text())['files']));(root/first).write_bytes(b'changed')
   with self.assertRaisesRegex(ValueError,'checksum'):g.load(root)
 def test_wrong_native_crosswalk_and_binary_ratio_rejects(self):
  raw=g.load(ROOT/'tools/references/traits');bad=dict(raw);binary=bytearray(bad['personal_b2w2']);binary[25*76+18]=255;bad['personal_b2w2']=bytes(binary)
  with self.assertRaisesRegex(ValueError,'ratio'):g.collect(bad,ROOT)
  bad=dict(raw);bad['item_game_indices.csv']=bad['item_game_indices.csv'].replace(b'213,5,236',b'236,5,236')
  self.assertNotEqual(bad['item_game_indices.csv'],raw['item_game_indices.csv'])
  with self.assertRaisesRegex(ValueError,'crosswalk'):g.collect(bad,ROOT)
if __name__=='__main__':unittest.main()
