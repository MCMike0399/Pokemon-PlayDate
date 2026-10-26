"""Protection flags come from the independent Gen5 projection, never targets."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools import move_producer_contract as c
from tools.tests.test_move_producer_contract import gen,ROOT

def fixture():
    vectors=[(182,'protect',1,0,0,10,7,4),(364,'feint',2,30,100,10,10,2)]
    moves=[dict(zip(('id','identifier','damage_class_id','power','accuracy','pp','target_id','priority'),map(str,row)),type_id='1',effect_chance='',generation_id='3')for row in vectors]
    return dict(moves=moves,move_changelog=[],move_meta=[],move_meta_stat_changes=[],types=[dict(id='1',identifier='normal')])

def prior():
    rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
    return '-- move-producer-contract: 8\n'+'\n'.join('    '+k+' = '+c.drop_fields(rows[k],c.PROTECTION_FIELDS).replace(', effects = { ProtectEffect() }','')for k in ('protect','feint'))+'\n'

def generate(text,folder):
    source=folder/'input.lua';target=folder/'output.lua';source.write_text(text)
    with patch.object(gen,'MOVES_INPUT',str(source)),patch.object(gen,'MOVES_LUA',str(target)),patch.object(gen,'EXTRA_MOVE_KEYS',[]):gen.generate_moves(fixture(),True)
    return target.read_text()

class ProtectionProducerTests(unittest.TestCase):
    def test_exact425_literal_flags_roster_and_noninferred_target_examples(self):
        metadata=c.protection_metadata();rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text())
        self.assertEqual(len(metadata),425);self.assertEqual(set(metadata),set(rows))
        self.assertEqual(sum(v['protectable']for v in metadata.values()),332)
        self.assertEqual([k for k,v in metadata.items()if v['breaksProtect']],['feint'])
        for k,row in rows.items():
            value=c.fields(row)
            for field,flag in metadata[k].items():self.assertIs(value[field],flag,k+' '+field)
        for key in ('tackle','growl','bide','worrySeed'):self.assertIs(metadata[key]['protectable'],True)
        for key in ('recover','focusEnergy','protect','feint'):self.assertIs(metadata[key]['protectable'],False)
        self.assertIs(metadata['feint']['breaksProtect'],True)

    def test_exact_epoch8_rows_acquire_flags_and_protect_payload_then_repeat(self):
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);old=c.read_rows(prior());text=generate(prior(),p);rows=c.read_rows(text)
            for key in old:
                lowered=c.drop_fields(rows[key],c.PROTECTION_FIELDS)
                self.assertEqual(c.split_payload(lowered)[0],c.split_payload(old[key])[0])
            self.assertEqual(c.payload(rows['protect']),{'effects':['ProtectEffect ( )'],'secondaries':[]})
            self.assertEqual(c.payload(rows['feint']),c.payload(old['feint']))
            self.assertEqual(generate(text,p),text)

    def test_current_missing_flipped_and_string_flags_and_payload_scalars_fail(self):
        rows=c.read_rows((ROOT/'Source/battle/moves.lua').read_text());semantics=c.producer_metadata();contract=c.load_contract()
        for key in ('protect','feint','tackle','growl','bide','focusEnergy','thunder'):
            for field in c.PROTECTION_FIELDS:
                flag=c.fields(rows[key])[field];token=field+' = '+str(flag).lower()
                variants=[c.drop_fields(rows[key],(field,)),rows[key].replace(token,field+' = '+str(not flag).lower()),rows[key].replace(token,field+' = "'+str(flag).lower()+'"')]
                for mutant in variants:
                    with self.subTest(key=key,field=field,mutant=mutant):self.assertFalse(c.compatible(key,mutant,rows[key],semantics[key],contract,epoch=9))
        with tempfile.TemporaryDirectory()as folder:
            p=Path(folder);text=generate(prior(),p)
            for a,b in [('ProtectEffect()','NoEffect()'),('priority = 4','priority = 3'),('power = 30','power = 50'),('pp = 10','pp = 11')]:
                with self.subTest(change=(a,b)),self.assertRaisesRegex(ValueError,'unexpected changes'):generate(text.replace(a,b,1),p)

    def test_current_exact_inverse_keeps_original424_oracle_and_validates_bide_flags_first(self):
        text=(ROOT/'Source/battle/moves.lua').read_text();rows=c.read_rows(text);self.assertEqual(c.producer_epoch(text),13)
        self.assertEqual(c.digest(json.dumps(c.legacy_rows(rows,c.producer_epoch(text)),sort_keys=True,separators=(',',':')).encode()),'ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea')
        for field in c.PROTECTION_FIELDS:
            changed=dict(rows);changed['bide']=c.drop_fields(rows['bide'],(field,))
            with self.subTest(field=field),self.assertRaisesRegex(ValueError,'added move protection metadata'):c.legacy_rows(changed,c.producer_epoch(text))
