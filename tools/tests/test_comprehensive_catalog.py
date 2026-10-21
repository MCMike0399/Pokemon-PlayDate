import importlib.util,json,os,tempfile,unittest,hashlib,shutil
from pathlib import Path

PROJECT=Path(os.environ.get('POKEMON_PROJECT',Path.cwd())).resolve()
FEATURE_SOURCE=Path(os.environ.get('CATALOG_FEATURE_SOURCE',PROJECT/'Source')).resolve()
from tools.harness import catalog_qualification as qualifier
from tools.harness.protocol import ProtocolError
SPEC=importlib.util.spec_from_file_location('comprehensive_catalog',Path(__file__).resolve().parents[1]/'visual/comprehensive.py')
m=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(m)

class ComprehensiveCatalogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pins=json.loads(m.PIN.read_text())
        cls.protected={row['path'] for row in json.loads((PROJECT/'docs/validation/catalog-viridian/catalog.json').read_text())['images']}
        cls.added=m.inventory(PROJECT,cls.pins)
    def test_exact_explicit_inventory(self):
        self.assertEqual(len(self.protected),1635);self.assertEqual(len(self.added),859)
        m.verify_inventory(self.protected|self.added,self.protected,self.added)
        self.assertEqual(sum('-viewport.png' in p for p in self.added),8)
        self.assertEqual(sum(p.startswith('pewter-pose-')for p in self.added),600)
        self.assertEqual(sum(p.startswith('tile_imported_')for p in self.added),86)
    def test_every_source_direction_and_real_walk_alternate_has_all_variants(self):
        source=m.data(PROJECT,'Source/data/pewterSlice/sprites.json',self.pins)
        poses=m.pose_specs(source);self.assertEqual(len(poses),120)
        for row in poses:
            for suffix in ('','__mask','__white','__black','__texture'):self.assertIn(row['name']+suffix+'.png',self.added)
        fixed=[x for x in poses if x['source']=='SPRITE_POKE_BALL']
        self.assertEqual({x['direction']for x in fixed},{'up','down','left','right'})
        self.assertTrue(all(x['pose']=='stand' and not x['flip_x']for x in fixed))
    def test_missing_undeclared_duplicate_and_traversal_paths_fail(self):
        valid=list(self.protected|self.added)
        cases=[valid[:-1],valid+['undeclared.png'],valid+[valid[0]],['../escape.png']+valid[1:],['/absolute.png']+valid[1:]]
        for paths in cases:
            with self.assertRaises(ValueError):m.verify_inventory(paths,self.protected,self.added)
    def test_all_before_after_native_files_are_required_not_just_counts(self):
        # Normal checkout declarations and normal qualifier replace the retired
        # private validator's scenario outputs/post-success-only comparison.
        contract=(FEATURE_SOURCE/'dev/comprehensiveCatalogContracts.lua').read_text()
        self.assertIn('HarnessBuild.output_dir.."catalog-invariance-"..phase.."/"..path',contract)
        self.assertIn('"catalog-invariance-"..phase..".json"',contract)
        self.assertIn('emit("before")',contract);self.assertIn('emit("after")',contract)
        self.assertNotIn('HarnessBuild.output_dir.."/frames/"',contract)
        self.assertEqual(qualifier.PHASES,('before','after'));self.assertEqual(qualifier.COUNT,859)
        with tempfile.TemporaryDirectory()as directory:
            source=Path(directory);(source/'dev').mkdir();(source/'data').mkdir()
            shutil.copyfile(FEATURE_SOURCE/'dev/catalogProtected.json',source/'dev/catalogProtected.json')
            shutil.copytree(PROJECT/'Source/data/pewterSlice',source/'data/pewterSlice')
            inventory=qualifier.expected_inventory(source)
        self.assertEqual(set(inventory),self.added)
        expected={'catalog-invariance-'+phase+'/'+name for phase in qualifier.PHASES for name in inventory}
        self.assertEqual(len(expected),1718)
        for phase in qualifier.PHASES:
            packet={'schema':1,'image_root':'.','images':list(inventory.values()),'missing':[]}
            self.assertEqual(set(qualifier.check_manifest(packet,inventory)),self.added)
            packet['images']=packet['images'][:-1]
            with self.assertRaises(ProtocolError):qualifier.check_manifest(packet,inventory)
            packet['images']=list(inventory.values());packet['images'][1]=packet['images'][0]
            with self.assertRaises(ProtocolError):qualifier.check_manifest(packet,inventory)

    def test_capture_materialization_helper_is_byte_preserved(self):
        # Independent pin of the accepted helper body; comparing two copies from
        # the same checkout would conceal simultaneous accidental changes.
        text=(PROJECT/'Source/dev/catalog.lua').read_text()
        helper=text[text.index('function VisualCatalog.materializeCaptureImage'):text.index('-- Reversible UTF-8')]
        self.assertEqual(hashlib.sha256(helper.encode()).hexdigest(),'835529cc84f2881ebf6bd0f21f2a2e2e9bd8b6cd174bfda81747c6d20df4cac6')
    def test_source_input_drift_is_not_silently_rebased(self):
        path='Source/data/pewterSlice/sprites.json'
        with tempfile.TemporaryDirectory()as directory:
            project=Path(directory);target=project/path;target.parent.mkdir(parents=True)
            data=json.loads((PROJECT/path).read_text());data['sprites']['super_nerd']['frames']['0'][0]='#'*16
            target.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'source input drift'):m.data(project,path,self.pins)
    def test_exact_rgba_oracle_catches_invisible_rgb_and_mask_single_pixels(self):
        from tools.visual.event_art import difference,raster
        source=m.data(PROJECT,'Source/data/pewterSlice/sprites.json',self.pins)
        expected=raster(source['sprites']['super_nerd']['frames']['0'])
        point=next((x,y)for y in range(32)for x in range(32)if expected.getpixel((x,y))[3]==0)
        changed=expected.copy();pixel=expected.getpixel(point);changed.putpixel(point,(255-pixel[0],255-pixel[1],255-pixel[2],pixel[3]))
        row=difference(expected,changed);self.assertFalse(row['equal']);self.assertEqual(row['changed_pixels'],1);self.assertEqual(row['alpha_pixels'],0)
        with tempfile.TemporaryDirectory()as directory:
            before=Path(directory)/'before.png';after=Path(directory)/'after.png'
            expected.save(before);changed.save(after)
            strict=qualifier.image_dependencies()[1](before,after)
            self.assertFalse(strict['equal']);self.assertEqual(strict['rgb_pixels'],1);self.assertEqual(strict['alpha_pixels'],0)
        changed=expected.copy();changed.putpixel(point,(*pixel[:3],255));row=difference(expected,changed)
        self.assertFalse(row['equal']);self.assertEqual(row['changed_pixels'],1);self.assertEqual(row['alpha_pixels'],1)

if __name__=='__main__':unittest.main()
