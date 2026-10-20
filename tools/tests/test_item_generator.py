"""Offline deterministic fixtures for Blue item generation; no cache/network needed."""
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

PATH=Path(__file__).resolve().parents[1]/'generate_items.py'
spec=importlib.util.spec_from_file_location('item_generator',PATH)
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
SYMBOLS='''NO_ITEM MASTER_BALL ULTRA_BALL GREAT_BALL POKE_BALL TOWN_MAP BICYCLE SURFBOARD SAFARI_BALL POKEDEX MOON_STONE ANTIDOTE BURN_HEAL ICE_HEAL AWAKENING PARLYZ_HEAL FULL_RESTORE MAX_POTION HYPER_POTION SUPER_POTION POTION BOULDERBADGE CASCADEBADGE THUNDERBADGE RAINBOWBADGE SOULBADGE MARSHBADGE VOLCANOBADGE EARTHBADGE ESCAPE_ROPE REPEL OLD_AMBER FIRE_STONE THUNDER_STONE WATER_STONE HP_UP PROTEIN IRON CARBOS CALCIUM RARE_CANDY DOME_FOSSIL HELIX_FOSSIL SECRET_KEY ITEM_2C BIKE_VOUCHER X_ACCURACY LEAF_STONE CARD_KEY NUGGET ITEM_32 POKE_DOLL FULL_HEAL REVIVE MAX_REVIVE GUARD_SPEC SUPER_REPEL MAX_REPEL DIRE_HIT COIN FRESH_WATER SODA_POP LEMONADE S_S_TICKET GOLD_TEETH X_ATTACK X_DEFEND X_SPEED X_SPECIAL COIN_CASE OAKS_PARCEL ITEMFINDER SILPH_SCOPE POKE_FLUTE LIFT_KEY EXP_ALL OLD_ROD GOOD_ROD SUPER_ROD PP_UP ETHER MAX_ETHER ELIXER MAX_ELIXER'''.split()
def fixture():
    const=''.join(f' const {symbol}\n' for symbol in SYMBOLS)+'DEF NUM_ITEMS EQU const_value - 1\n'
    const+=''.join(f' add_hm MOVE_{n}\n' for n in range(1,6))
    const+=''.join(f' add_tm MOVE_{n}\n' for n in range(1,51))
    key={'TOWN_MAP','OAKS_PARCEL'}
    effects=''
    for symbol,amount in g.HEAL.items():
        effects+='ItemHandlers::UseOnPokemon.add(:'+symbol.replace('_','')+', proc { |item, qty, pkmn, scene|\n'
        effects+=f' next pbHPItem(pkmn, (Settings::REBALANCED_HEALING_ITEM_AMOUNTS) ? 999 : {amount}, scene)\n}})\n'
    return {'constants/item_constants.asm':const,
      'data/items/prices.asm':''.join(f' bcd3 {300 if symbol=="POTION" else 200} ; {symbol}\n' for symbol in SYMBOLS[1:]),
      'data/items/key_items.asm':''.join(f' dbit {"TRUE" if symbol in key else "FALSE"} ; {symbol}\n' for symbol in SYMBOLS[1:]),
      'data/items/names.asm':''.join(f' li "{symbol}"\n' for symbol in SYMBOLS[1:]),
      'data/items/tm_prices.asm':''.join(f' nybble {3 if n==1 else 1} ; TM{n:02}\n' for n in range(1,51)),
      'data/items/marts.asm':''.join(f'Mart{n}::\n script_mart POKE_BALL, POTION\n' for n in range(14))+'UnusedMartClerkText::\n script_mart BICYCLE\n',
      '001_Settings.rb':'REBALANCED_HEALING_ITEM_AMOUNTS = (MECHANICS_GENERATION >= 7)\n',
      '002_Item_Effects.rb':effects}
class ItemGeneratorTests(unittest.TestCase):
    def test_catalog_mapping_categories_and_exclusions(self):
        items,symbols,marts=g.collect(fixture())
        self.assertEqual(len(items),124);self.assertEqual(len(marts),14)
        self.assertEqual(symbols['POKE_BALL'],'pokeBall');self.assertEqual(symbols['OAKS_PARCEL'],'oaksParcel')
        self.assertEqual(symbols['ELIXER'],'elixir');self.assertEqual(symbols['MAX_ELIXER'],'maxElixir')
        self.assertEqual(items['potion']['numericId'],20);self.assertEqual(items['potion']['price'],300)
        self.assertEqual(items['potion']['sellPrice'],150);self.assertEqual(items['potion']['amount'],20)
        self.assertEqual(items['hyperPotion']['amount'],200);self.assertEqual(items['superPotion']['amount'],50)
        self.assertEqual(items['tm01']['category'],'tm');self.assertFalse(items['tm01']['keyItem'])
        self.assertEqual(items['hm01']['category'],'hm');self.assertTrue(items['hm01']['keyItem'])
        for symbol in g.EXCLUDED:self.assertNotIn(symbol,symbols)
    def test_render_stable_and_does_not_omit_unsupported(self):
        text=g.render(fixture());self.assertEqual(text,g.render(fixture()))
        self.assertIn('ppUp = ',text);self.assertIn('["effect"] = "unsupported"',text)
    def test_modern_medicine_values_rejected(self):
        raw=fixture();raw['002_Item_Effects.rb']=raw['002_Item_Effects.rb'].replace(': 200,',': 120,')
        with self.assertRaisesRegex(g.GenerationError,'medicine value disagreement'):g.collect(raw)
    def test_generation_boundary_must_be_explicit(self):
        raw=fixture();raw['001_Settings.rb']='REBALANCED_HEALING_ITEM_AMOUNTS = true'
        with self.assertRaisesRegex(g.GenerationError,'generation boundary'):g.collect(raw)
    def test_missing_price_rejected(self):
        raw=fixture();raw['data/items/prices.asm']=raw['data/items/prices.asm'].replace(' bcd3 300 ; POTION\n','')
        with self.assertRaisesRegex(g.GenerationError,'missing price'):g.collect(raw)
    def test_missing_key_flags_rejected(self):
        raw=fixture();raw['data/items/key_items.asm']=raw['data/items/key_items.asm'].replace(' dbit FALSE ; POTION\n','')
        with self.assertRaisesRegex(g.GenerationError,'incomplete'):g.collect(raw)
    def test_unknown_mart_symbol_rejected(self):
        raw=fixture();raw['data/items/marts.asm']=raw['data/items/marts.asm'].replace('POKE_BALL','GLITCH_ITEM',1)
        with self.assertRaisesRegex(g.GenerationError,'unknown mart item'):g.collect(raw)
    def test_missing_machine_rejected(self):
        raw=fixture();raw['constants/item_constants.asm']=raw['constants/item_constants.asm'].replace(' add_tm MOVE_50\n','')
        with self.assertRaisesRegex(g.GenerationError,'incomplete TM/HM'):g.collect(raw)
    def test_changed_numeric_layout_rejected(self):
        raw=fixture();raw['constants/item_constants.asm']=raw['constants/item_constants.asm'].replace(' const MAX_ELIXER\n','')
        with self.assertRaisesRegex(g.GenerationError,'ID layout'):g.collect(raw)
    def test_missing_cache_no_network(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaisesRegex(g.GenerationError,'missing pinned'):g.load(tmp,manifest={'files':{'x':{}}})
    def test_corrupt_cache_preserved(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'x';p.write_bytes(b'bad')
            m={'files':{'x':{'sha256':hashlib.sha256(b'good').hexdigest()}}}
            with self.assertRaisesRegex(g.GenerationError,'checksum'):g.load(tmp,manifest=m)
            self.assertEqual(p.read_bytes(),b'bad')
    def test_fetch_failure(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g.urllib.request,'urlopen',side_effect=OSError('offline')):
            with self.assertRaisesRegex(g.GenerationError,'fetch failed'):g.load(tmp,True,{'files':{'x':{'url':'https://example.invalid'}}})
    def test_check_drift_nonzero_no_write(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(g,'load',return_value=fixture()):
            p=Path(tmp)/'items.lua';p.write_text('old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p),'--check']),1);self.assertEqual(p.read_text(),'old')
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p)]),0)
            self.assertEqual(g.main(['--cache',tmp,'--output',str(p),'--check']),0)
if __name__=='__main__':unittest.main()
