"""Offline target metadata migration checks, using the staged generator before apply."""
import importlib.util
import os
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch
PATH=Path(os.environ.get('GEN5_GENERATOR',Path(__file__).resolve().parents[1]/'generate_gen5_data.py'))
spec=importlib.util.spec_from_file_location('target_generator',PATH);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)

def row(key,target):
    return dict(id={'recover':'105','growl':'45','struggle':'165'}[key],identifier=key,generation_id='1',
        type_id='1',power='50' if key=='struggle' else '',pp='1' if key=='struggle' else '10',accuracy='',
        priority='0',effect_chance='',target_id=str(target),damage_class_id='2' if key=='struggle' else '1')
class TargetGenerationTests(unittest.TestCase):
    def test_target_changelog_is_resolved_as_of_b2w2(self):
        change={'changed_in_version_group_id':'15','target_id':'10'}
        value=g.resolve_b2w2(row('struggle',8),[change])
        self.assertEqual(value['target_id'],10)
    def test_explicit_target_and_ability_metadata_additions_preserve_legacy_row(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'input.lua';output=Path(tmp)/'output.lua'
            old='    recover = Move{ name = "RECOVER", type = "normal", category = "status", power = 0, accuracy = 0, pp = 10 },\n'
            source.write_text('moveData = {\n'+old+'}\n')
            data={'moves':[row('recover',7)],'move_changelog':[],'move_meta':[], 'move_meta_stat_changes':[], 'types':[{'id':'1','identifier':'normal'}]}
            with patch.object(g,'MOVES_INPUT',str(source)),patch.object(g,'MOVES_LUA',str(output)):
                g.generate_moves(data,preserve_existing=True)
                generated=output.read_text()
                from tools.move_producer_contract import read_rows
                actual='    recover = '+read_rows(generated)['recover']+'\n'
                # These exact six producer-owned additions are now declared. No
                # other scalar or effect may disappear behind normalization.
                from tools.move_producer_contract import fields
                self.assertEqual(fields(actual[actual.index("Move"):].strip()),{'name':'RECOVER','type':'normal','category':'status','power':0,'accuracy':0,'pp':10,'targetId':7,'contact':False,'hasSecondary':False,'ohko':False,'breaksProtect':False,'protectable':False})
                self.assertEqual(actual.replace(', targetId = 7','').replace(', contact = false, hasSecondary = false, ohko = false','').replace(', breaksProtect = false, protectable = false',''),old)
                self.assertIn('self.targetId = m.targetId or 10',generated)
                source.write_text(generated)
                g.generate_moves(data,preserve_existing=True)
                self.assertEqual(output.read_text(),generated)
    def test_existing_target_drift_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'input.lua';output=Path(tmp)/'output.lua'
            source.write_text('    recover = Move{ name = "RECOVER", type = "normal", category = "status", power = 0, accuracy = 0, pp = 10, targetId = 10 },\n')
            data={'moves':[row('recover',7)],'move_changelog':[],'move_meta':[],'move_meta_stat_changes':[],'types':[{'id':'1','identifier':'normal'}]}
            with patch.object(g,'MOVES_INPUT',str(source)),patch.object(g,'MOVES_LUA',str(output)):
                with self.assertRaisesRegex(ValueError,'unexpected changes'):g.generate_moves(data,preserve_existing=True)
            self.assertFalse(output.exists())
    def test_missing_target_never_falls_back_to_selected_opponent(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'input.lua';output=Path(tmp)/'output.lua'
            source.write_text('    recover = Move{ name = "RECOVER", type = "normal", category = "status", power = 0, accuracy = 0, pp = 10 },\n')
            move=row('recover',7);move['target_id']=''
            data={'moves':[move],'move_changelog':[],'move_meta':[],'move_meta_stat_changes':[],'types':[{'id':'1','identifier':'normal'}]}
            with patch.object(g,'MOVES_INPUT',str(source)),patch.object(g,'MOVES_LUA',str(output)):
                with self.assertRaisesRegex(ValueError,'invalid Gen V target'):g.generate_moves(data,preserve_existing=True)
            self.assertFalse(output.exists())
    def test_other_scalar_drift_is_still_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'input.lua';output=Path(tmp)/'output.lua'
            source.write_text('    recover = Move{ name = "RECOVER", type = "normal", category = "status", power = 0, accuracy = 0, pp = 11 },\n')
            data={'moves':[row('recover',7)],'move_changelog':[],'move_meta':[],'move_meta_stat_changes':[],'types':[{'id':'1','identifier':'normal'}]}
            with patch.object(g,'MOVES_INPUT',str(source)),patch.object(g,'MOVES_LUA',str(output)):
                with self.assertRaisesRegex(ValueError,'unexpected changes'):g.generate_moves(data,preserve_existing=True)
            self.assertFalse(output.exists())
if __name__=='__main__':unittest.main()
