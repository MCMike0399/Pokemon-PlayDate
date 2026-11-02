"""Four exact side-condition migrations; no GenV scalar changes."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT
KEYS=('reflect','lightScreen','safeguard','tailwind')

def fixture():
    vectors=[(115,'reflect',14,20),(113,'light-screen',14,30),(219,'safeguard',1,25),(366,'tailwind',3,30)]
    moves=[dict(id=str(i),identifier=k,type_id=str(t),pp=str(pp),damage_class_id='1',power='0',accuracy='0',target_id='4',priority='0',effect_chance='',generation_id='4')for i,k,t,pp in vectors]
    return dict(moves=moves,move_changelog=[],move_meta=[],move_meta_stat_changes=[],types=[dict(id=str(i),identifier=s)for i,s in ((1,'normal'),(3,'flying'),(14,'psychic'))])

def prior():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 9\n'+'\n'.join('    '+k+' = '+rows[k].replace(', effects = { SideConditionEffect("'+k+'") }','')for k in KEYS)+'\n'

def generate(text,folder):
    source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return target.read_text()

class SideProducerTests(unittest.TestCase):
    def test_exact_four_payloads_preserve_all_prior_fields_and_repeat(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior());text=generate(prior(),p);rows=c.read_rows(text)
            for key,pp in zip(KEYS,(20,30,25,30)):
                self.assertEqual(c.split_payload(rows[key])[0],c.split_payload(old[key])[0])
                self.assertEqual(c.payload(rows[key]),{'effects':['SideConditionEffect ( "'+key+'" )'],'secondaries':[]})
                self.assertEqual(c.fields(rows[key])['pp'],pp);self.assertEqual(c.fields(rows[key])['targetId'],4)
            self.assertEqual(generate(text,p),text)

    def test_current_missing_wrong_extra_effect_and_modern_pp_mutants_fail(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for key in KEYS:
                for replacement in ('NoEffect()','SideConditionEffect("mist")','SideConditionEffect("'+key+'"), NoEffect()'):
                    mutant=text.replace('SideConditionEffect("'+key+'")',replacement,1)
                    with self.subTest(key=key,replacement=replacement),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(mutant,p)
            for a,b in [('pp = 30','pp = 15'),('pp = 25','pp = 24'),('targetId = 4','targetId = 7')]:
                with self.subTest(change=(a,b)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(a,b,1),p)

    def test_composed_epochs_preserve_chip_away14_then_add_only_reflect15(self):
        text = (ROOT / 'Source/battle/moves.lua').read_text()
        rows = c.read_rows(text)
        semantics = c.producer_metadata()
        current = rows['chipAway']
        old = c.drop_fields(current, ('ignoreDefensive', 'ignoreEvasion'))
        self.assertEqual(c.RULE_EPOCHS['chipAway'], 14)
        self.assertTrue(c.compatible('chipAway', old, current, semantics['chipAway'], epoch=13))
        for epoch in (14, 15):
            for flag in ('ignoreDefensive', 'ignoreEvasion'):
                for mutant in (c.drop_fields(current, (flag,)), current.replace(flag + ' = true', flag + ' = false')):
                    with self.subTest(epoch=epoch, flag=flag, mutant=mutant):
                        self.assertFalse(c.compatible('chipAway', mutant, current, semantics['chipAway'], epoch=epoch))
        reflect = rows['reflect']
        before = c.split_payload(reflect)[0] + ' },'
        self.assertTrue(c.compatible('reflect', before, reflect, semantics['reflect'], epoch=14))
        self.assertFalse(c.compatible('reflect', before, reflect, semantics['reflect'], epoch=15))
        self.assertFalse(c.compatible('reflect', reflect, before, semantics['reflect'], epoch=15))
        for epoch in (13, 14, 15):
            mutant = reflect.replace('SideConditionEffect("reflect")', 'NoEffect()')
            self.assertFalse(c.compatible('reflect', mutant, reflect, semantics['reflect'], epoch=epoch))
        # Genuine epoch13 and14 projections: no silently relabelled Reflect14 export.
        # Construct the genuine old export: remove later payloads/rules first.
        historical = dict(rows, reflect=before)
        historical["substitute"] = c.split_payload(rows["substitute"])[0] + " },"
        for key in ('snore', 'revenge', 'selfDestruct', 'explosion'):
            historical[key] = c.drop_fields(historical[key], c.RULE_FIELDS)
        for key in ('haze', 'clearSmog', 'rest', 'yawn', 'foresight'):
            historical[key] = c.split_payload(historical[key])[0] + ' },'
        epoch15 = dict(historical, reflect=reflect)
        legacy14 = c.legacy_rows(historical, 14)
        historical['chipAway'] = old
        self.assertEqual(c.legacy_rows(historical, 13), legacy14)
        self.assertEqual(c.legacy_rows(epoch15, 15), legacy14)
        self.assertEqual(c.legacy_rows(rows, 19), legacy14)

    def test_explicit_current_epoch_keeps_original424_inverse_hash(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);epoch=c.producer_epoch(text);self.assertEqual(epoch,19)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,epoch),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        for key in KEYS:
            changed=dict(rows);changed[key]=rows[key].replace('SideConditionEffect("'+key+'")','NoEffect()')
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'unowned move effect'):c.legacy_rows(changed,epoch)
