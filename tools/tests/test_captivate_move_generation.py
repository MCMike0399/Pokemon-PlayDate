"""Captivate gains an explicit eligibility rule; historical payload remains exact."""
import tempfile,unittest,json
from pathlib import Path
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT

def fixture():
    move=dict(id='445',identifier='captivate',type_id='1',damage_class_id='1',power='0',accuracy='100',pp='20',target_id='11',priority='0',effect_chance='',generation_id='4')
    meta=dict(move_id='445',crit_rate='0',meta_ailment_id='0',ailment_chance='0',flinch_chance='0',stat_chance='0',healing='0',drain='0',min_hits='',max_hits='')
    return dict(moves=[move],move_changelog=[],move_meta=[meta],move_meta_stat_changes=[dict(move_id='445',stat_id='4',change='-2')],types=[dict(id='1',identifier='normal')])
def generate(text,folder):
    src=folder/'input.lua';out=folder/'output.lua';src.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(src)),patch.object(gen,'MOVES_LUA',str(out)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return out.read_text()
class CaptivateProducerTests(unittest.TestCase):
    def test_complete_epoch4_migrates_exact_one_field_and_repeats_identically(self):
        row=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())['captivate'];old=c.drop_fields(row,('attemptRule',))
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);new=generate('-- move-producer-contract: 4\n    captivate = '+old+'\n',p)
            actual=c.read_rows(new)['captivate'];self.assertEqual(c.drop_fields(actual,('attemptRule',)),old)
            self.assertEqual(c.fields(actual)['attemptRule'],'oppositeSex');self.assertEqual(generate(new,p),new)
    def test_current_epoch_rule_removal_wrong_type_wrong_rule_and_changed_effect_fail(self):
        row=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())['captivate']
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);new=generate('-- move-producer-contract: 5\n    captivate = '+row+'\n',p)
            for before,after in [(', attemptRule = "oppositeSex"',''),('attemptRule = "oppositeSex"','attemptRule = true'),('attemptRule = "oppositeSex"','attemptRule = "suckerPunch"'),('"spa", -2','"spa", -1'),('accuracy = 100','accuracy = 99'),('pp = 20','pp = 19')]:
                with self.subTest(change=(before,after)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(new.replace(before,after,1),p)
    def test_source_epoch_preservation_rejects_current_missing_rule(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,12)
        changed=dict(rows);changed['captivate']=c.drop_fields(changed['captivate'],('attemptRule',))
        with self.assertRaisesRegex(ValueError,'producer metadata'):c.legacy_rows(changed,epoch)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
