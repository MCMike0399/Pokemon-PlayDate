import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from PIL import Image

from tools.visual.compare import compare_catalog
from tools.visual.inventory import expected_slice, inspect_catalog, stable_name

ROOT=Path(__file__).resolve().parents[2]


class ProtectedPreservationTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root=Path(self.temp.name);self.before=self.root/'before';self.after=self.root/'after'
        self.before.mkdir();self.after.mkdir();(self.after/'frames').mkdir()
        self.protected=[{'path':'tile.png','width':2,'height':2,'mask':False},
                        {'path':'tile__mask.png','width':2,'height':2,'mask':True}]
        self.added=[{'path':'new.png','width':2,'height':2,'mask':False}]
        for path in ('tile.png','tile__mask.png'):
            Image.new('RGBA',(2,2),'white').save(self.before/path)
            Image.new('RGBA',(2,2),'white').save(self.after/'frames'/path)
        Image.new('RGBA',(2,2),'black').save(self.after/'frames/new.png')
        self.write()
    def write(self,actual=None):
        (self.before/'catalog.json').write_text(json.dumps({'images':self.protected,'missing':[]}))
        (self.after/'catalog.json').write_text(json.dumps({'image_root':'frames','images':actual or self.protected+self.added,'missing':[]}))
    def test_default_strict_still_rejects_every_addition(self):
        self.assertFalse(compare_catalog(self.before,self.after)['equal'])
        proc=subprocess.run([sys.executable,str(ROOT/'tools/visual/compare.py'),str(self.before),str(self.after)],capture_output=True,text=True)
        self.assertEqual(proc.returncode,1);self.assertFalse(json.loads(proc.stdout)['equal'])
    def test_explicit_mode_preserves_subset_without_reviewing_additions(self):
        result=compare_catalog(self.before,self.after,protected_preservation=True)
        self.assertTrue(result['protected_equal']);self.assertTrue(result['comparison_ok'])
        self.assertFalse(result['equal']);self.assertFalse(result['review_complete'])
        self.assertEqual(result['added_unreviewed'],['new.png'])
        proc=subprocess.run([sys.executable,str(ROOT/'tools/visual/compare.py'),str(self.before),str(self.after),'--protected-preservation'],capture_output=True,text=True)
        self.assertEqual(proc.returncode,0,proc.stderr);self.assertFalse(json.loads(proc.stdout)['equal'])
    def test_changed_protected_mask_fails(self):
        image=Image.open(self.after/'frames/tile__mask.png').convert('RGBA');image.putpixel((1,0),(255,255,255,0));image.save(self.after/'frames/tile__mask.png')
        result=compare_catalog(self.before,self.after,protected_preservation=True)
        self.assertFalse(result['protected_equal']);self.assertFalse(result['comparison_ok'])
        self.assertEqual(result['failures'][0]['alpha_pixels'],1)
    def test_missing_protected_inventory_or_file_fails(self):
        self.write(self.protected[:1]+self.added)
        self.assertFalse(compare_catalog(self.before,self.after,protected_preservation=True)['protected_equal'])
        self.write();(self.after/'frames/tile__mask.png').unlink()
        self.assertFalse(compare_catalog(self.before,self.after,protected_preservation=True)['protected_equal'])
    def test_missing_or_corrupt_added_file_never_passes(self):
        for value in (None,b'not a PNG'):
            path=self.after/'frames/new.png'
            if value is None:path.unlink(missing_ok=True)
            else:path.write_bytes(value)
            result=compare_catalog(self.before,self.after,protected_preservation=True)
            self.assertTrue(result['protected_equal']);self.assertFalse(result['comparison_ok'])
            self.assertFalse(result['equal']);self.assertEqual(result['added_unreviewed'],['new.png'])
    def test_protected_mask_metadata_cannot_be_relabelled(self):
        self.write([self.protected[0],dict(self.protected[1],mask=False)]+self.added)
        self.assertFalse(compare_catalog(self.before,self.after,protected_preservation=True)['protected_equal'])
    def test_addition_paths_and_symlink_escape_rejected(self):
        for path in ('../new.png','/tmp/new.png','bad\\new.png'):
            self.write(self.protected+[{'path':path}])
            with self.assertRaises(ValueError):compare_catalog(self.before,self.after,protected_preservation=True)
        (self.after/'frames/escape').symlink_to(self.root,target_is_directory=True)
        self.write(self.protected+[{'path':'escape/new.png'}])
        with self.assertRaises(ValueError):compare_catalog(self.before,self.after,protected_preservation=True)
    def test_added_dimensions_must_match_manifest(self):
        self.write(self.protected+[dict(self.added[0],width=3)])
        self.assertFalse(compare_catalog(self.before,self.after,protected_preservation=True)['comparison_ok'])


class IndependentInventoryTests(unittest.TestCase):
    def test_pinned_four_map_inventory_complete_and_stable(self):
        report=expected_slice(ROOT/'Source')
        self.assertEqual(report['counts'],{'images':635,'imported_tiles':102,'source_npc_frames':46,'runtime_npc_facings':37,'maps':4})
        self.assertEqual(len(report['expected']),len(set(report['expected'])))
        self.assertTrue(all('/' not in path and len(path.encode())<255 for path in report['expected']))
        asleep=[p for p in report['expected'] if p.startswith('npc_kantoGamblerAsleep_')]
        self.assertEqual(len(asleep),5);self.assertTrue(all('_down' in p for p in asleep))
    def test_stable_names_reversible_safe_and_bounded(self):
        for key in ('pokered:OVERWORLD:cell:01-01-11-11','adapter:viridian-slice:void','a/b','a_b','é'):
            encoded=stable_name(key);self.assertEqual(bytes.fromhex(encoded).decode(),key)
        self.assertNotEqual(stable_name('a/b'),stable_name('a_b'))
        for invalid in ('','x'*101,'é'*51):
            with self.assertRaises(ValueError):stable_name(invalid)
    def test_expected_inventory_missing_file_is_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'catalog.json').write_text(json.dumps({'images':[{'path':'x.png'}]}))
            report=inspect_catalog(root,{'expected':['x.png','x__mask.png']})
            self.assertFalse(report['ok']);self.assertEqual(report['missing_expected'],['x__mask.png']);self.assertEqual(len(report['invalid']),1)


if __name__=='__main__':unittest.main()
