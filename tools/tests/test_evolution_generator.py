"""Offline synthetic Gen5 containers; no ROM, network or replacement SDK."""
import importlib.util,json,struct,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('evogen',ROOT/'tools/generate_evolution_data.py');g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
def container(rows):
    chunks=[]
    for i in range(650):chunks.append(b''.join(struct.pack('<BBHHBB',*r) for r in rows.get(i,[])))
    offsets=[4+2*651]
    for chunk in chunks:offsets.append(offsets[-1]+len(chunk))
    return b'g5'+struct.pack('<H',650)+struct.pack('<'+'H'*651,*offsets)+b''.join(chunks)
def fixture():
    rows={i:[(4,0,10,i+1,255,10)] for i in range(1,53)}
    rows.update({i:[(5,0,0,i+1,255,0)] for i in range(53,57)})
    rows.update({i:[(8,0,81+(i%5),i+1,255,0)] for i in range(61,77)})
    rows[100]=[(6,0,233,208,255,0)] # Explicit later-roster relationship excluded.
    raw={'evos_g5.pkl':container(rows),'items.csv':b'id,identifier\n81,moon-stone\n82,fire-stone\n83,thunder-stone\n84,water-stone\n85,leaf-stone\n'}
    return raw,{'species':['s'+str(i) for i in range(1,152)]}
class EvolutionGeneratorTests(unittest.TestCase):
    def test_original_graph_counts_and_later_target_exclusion(self):
        raw,m=fixture();rules,excluded=g.collect(raw,m)
        self.assertEqual(len(rules),151);self.assertEqual(sum(map(len,rules.values())),72)
        self.assertEqual(rules['s1'],[{'to':'s2','targetDex':2,'method':4,'trigger':'level','minimum':10}])
        self.assertEqual(rules['s53'][0]['trigger'],'trade');self.assertEqual(rules['s61'][0]['item'],'fireStone')
        self.assertEqual(excluded,[{'from':100,'to':208,'method':6}]);self.assertEqual(rules['s100'],[])
    def test_exact_binary_record_unpack_and_corrupt_offsets(self):
        binary=container({1:[(4,0,16,2,255,16)],64:[(5,0,0,65,255,0)]})
        self.assertEqual(g.unpack(binary)[1],[(4,16,2,255,16)]);self.assertEqual(g.unpack(binary)[64],[(5,0,65,255,0)])
        variants=[b'xx'+binary[2:],binary[:2]+struct.pack('<H',649)+binary[4:],binary[:-1]]
        for bad in variants:
            with self.assertRaises(g.DataError):g.unpack(bad)
        bad=bytearray(binary);struct.pack_into('<H',bad,4,0)
        with self.assertRaises(g.DataError):g.unpack(bytes(bad))
    def test_unknown_original_method_and_bad_level_fail(self):
        raw,m=fixture();graph=g.unpack(raw['evos_g5.pkl'])
        for replacement in [(9,0,10,2,255,10),(4,0,16,2,255,17),(8,0,999,2,255,0)]:
            rows={i:[(method,0,arg,target,form,level) for method,arg,target,form,level in entries] for i,entries in graph.items()}
            rows[1]=[replacement];bad=dict(raw);bad['evos_g5.pkl']=container(rows)
            with self.assertRaises(g.DataError):g.collect(bad,m)
    def test_source_corruption_and_missing_pin_fail_without_replacing_cache(self):
        with tempfile.TemporaryDirectory() as td:
            root=Path(td);(root/'pin').write_bytes(b'original');m={'inputs':{'pin':{'url':'unused','sha256':g.digest(b'original')}}}
            self.assertEqual(g.sources(root,m)['pin'],b'original');(root/'pin').write_bytes(b'corrupt')
            with self.assertRaisesRegex(g.DataError,'checksum'):g.sources(root,m)
            self.assertEqual((root/'pin').read_bytes(),b'corrupt');(root/'pin').unlink()
            with self.assertRaises(OSError):g.sources(root,m)
    def test_render_deterministic_and_all_species_present(self):
        raw,m=fixture();rules,_=g.collect(raw,m);self.assertEqual(g.render(rules),g.render(rules));self.assertIn('s151 = {},',g.render(rules))
    def test_only_five_stone_semantic_tags_change_preserving_ascii_names_prices_and_medicine(self):
        import hashlib,re
        manifest=json.loads((ROOT/'tools/references/evolution.json').read_text())['item_projection']
        rows=dict(re.findall(r'^        (\w+) = (\{[^\n]+)$',(ROOT/'Source/data/items.lua').read_text(),re.M))
        stones=set(manifest['stones']);stable={k:v for k,v in rows.items() if k not in stones}
        digest=lambda value:hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()
        self.assertEqual(digest(stable),manifest['unchanged_sha256'])
        scalar={k:re.sub(r'\["(?:category|effect)"\] = "[^"]+",? ?', '',rows[k]) for k in sorted(stones)}
        self.assertEqual(digest(scalar),manifest['stone_scalar_sha256'])
        for key in stones:
            self.assertIn('["category"] = "evolution"',rows[key]);self.assertIn('["effect"] = "evolution"',rows[key])
if __name__=='__main__':unittest.main()
