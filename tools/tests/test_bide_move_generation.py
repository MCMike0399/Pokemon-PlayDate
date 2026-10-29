"""425th row is an explicit source-qualified addition, never a historical waiver."""
import json,tempfile,unittest
from pathlib import Path
from tools import move_producer_contract as c
from tools import verify_early_combat as verify
ROOT=Path(__file__).resolve().parents[2]
class BideProducerTests(unittest.TestCase):
    def test_original424_row_inverse_hash_unchanged_with_exact_added_bide(self):
        rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text());self.assertEqual(len(rows),425)
        self.assertEqual(c.drop_fields(rows['bide'],c.PROTECTION_FIELDS),c.load_contract()['added_moves']['bide']['row'])
        self.assertIs(c.fields(rows['bide'])['protectable'],True);self.assertIs(c.fields(rows['bide'])['breaksProtect'],False)
        old=c.legacy_rows(rows,c.producer_epoch((ROOT/'Source/battle/moves.lua').read_text()));self.assertEqual(len(old),424)
        self.assertEqual(c.digest(json.dumps(old,sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
    def test_added_row_scalar_target_contact_rule_or_payload_changes_are_rejected(self):
        rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text());row=rows['bide']
        for before,after in [('pp = 10','pp = 9'),('power = 0','power = 1'),('accuracy = 0','accuracy = 100'),('targetId = 7','targetId = 10'),('contact = true','contact = false'),('damageRule = "bide"','damageRule = "endeavor"'),('priority = 1','priority = 0'),('priority = 1','priority = 1, effects = { NoEffect() }')]:
            with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'added move scalar or effect'):
                c.legacy_rows(dict(rows,bide=row.replace(before,after,1)),c.producer_epoch((ROOT/'Source/battle/moves.lua').read_text()))
    def test_full_roster_verifier_rejects_missing_bide_or_unknown_extra_without_hash_waiver(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();manifest=json.loads((ROOT/'tools/references/early-combat.json').read_text())
        import re
        missing=re.sub(r'^    bide = function\(\)\n.*?^    end,\n','',text,flags=re.M | re.S)
        self.assertNotEqual(missing, text)
        with tempfile.TemporaryDirectory()as folder:
            path=Path(folder)/'moves.lua'
            for mutant in [missing,text+'\n    invented = Move{ name = "INVENTED", power = 1 },\n']:
                path.write_text(mutant)
                with self.assertRaisesRegex(ValueError,'roster drift'):verify.check_moves(path,manifest)
    def test_immutable_metadata_projection_retains424_and_explicit_bide_extension(self):
        historical=c.metadata();current=c.producer_metadata();self.assertEqual(len(historical),424);self.assertEqual(set(current)-set(historical),{'bide'})
        self.assertEqual(current['bide'],dict(contact=True,secondary=False,ohko=False,typeImmunity=False))
        self.assertEqual({key:current[key]for key in historical},historical)
