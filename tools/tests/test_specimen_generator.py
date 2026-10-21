"""Offline format/failure tests; full primary qualification is a separate command."""
import io
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from urllib.error import URLError

TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS))
import generate_specimen_data as gen

ITEMS = {
    'potion': {'symbol': 'POTION', 'keyItem': False, 'category': 'medicine'},
    'pokeBall': {'symbol': 'POKE_BALL', 'keyItem': False, 'category': 'ball'},
    'moonStone': {'symbol': 'MOON_STONE', 'keyItem': False, 'category': 'evolution'},
    'townMap': {'symbol': 'TOWN_MAP', 'keyItem': True, 'category': 'key'},
    'tm01': {'symbol': 'TM_MEGA_PUNCH', 'keyItem': False, 'category': 'tm'},
    'hm01': {'symbol': 'HM_CUT', 'keyItem': True, 'category': 'hm'},
    'expAll': {'symbol': 'EXP_ALL', 'keyItem': False, 'category': 'item'},
}
NAMES = ['Hardy','Lonely','Brave','Adamant','Naughty','Bold','Docile','Relaxed','Impish','Lax',
         'Timid','Hasty','Serious','Jolly','Naive','Modest','Mild','Quiet','Bashful','Rash',
         'Calm','Gentle','Sassy','Careful','Quirky']
# GenV ID ordering uses attack/defense/speed/special attack/special defense.
STAT_ORDER = [0, 1, 4, 2, 3]
LITERAL_SLOTS = {1:[65,65,34],4:[66,66,94],7:[67,67,44],11:[61,61,61],
                 12:[14,14,110],74:[69,5,8],94:[26,26,26],133:[50,91,107]}


def synthetic_sources():
    """Deliberately synthetic schema inputs; never presented as primary data."""
    personal = bytearray(152 * 76)
    for dex in range(1, 152):
        personal[dex*76+24:dex*76+27] = bytes(LITERAL_SLOTS.get(dex, [1,1,1]))
    nature_rows = []
    for index, name in enumerate(NAMES):
        signs = [0] * 5
        if index // 5 != index % 5:
            signs[STAT_ORDER[index // 5]] = 1
            signs[STAT_ORDER[index % 5]] = -1
        nature_rows.append('    {' + ','.join(map(str, signs)) + '}, // NATURE_' + name.upper())
    return {
        'personal_b2w2': bytes(personal),
        'PersonalInfo5B2W2.cs': b'SIZE = 0x4C; Data[0x18]',
        'abilities.csv': ('id,identifier\n' + ''.join(f'{n},ability{n}\n' for n in range(1,165))).encode(),
        'ability_names.csv': ('ability_id,local_language_id,name\n' + ''.join(f'{n},9,Ability {n}\n' for n in range(1,165))).encode(),
        'bw_src_system_poke_tool.c': ('static const s8 natureStat[NATURE_COUNT][NATURE_STAT_COUNT] = {\n' + '\n'.join(nature_rows) + '\n};').encode(),
        'items.csv': b'id,identifier\n4,poke-ball\n17,potion\n81,moon-stone\n',
        'ItemStorage5.cs': b'General => [1,4,55,81,236]; Medicine => [17]; Berry => [149];',
    }


class GeneratorTests(unittest.TestCase):
    def setUp(self):
        self.raw = synthetic_sources()

    def test_personal_row_offsets_preserve_all_three_preferences(self):
        species, _, _, _ = gen.collect(self.raw, ITEMS)
        self.assertEqual(len(species), 151)
        for dex, expected in LITERAL_SLOTS.items():
            self.assertEqual(species[dex-1], expected)
        self.assertEqual(species[10], [61,61,61], 'equal effects retain hidden provenance')

    def test_nature_schema_order_and_signs(self):
        natures = gen.collect(self.raw, ITEMS)[1]
        self.assertEqual(len(natures), 25)
        self.assertEqual(natures[3], ('Adamant', [1,0,-1,0,0]))
        self.assertEqual(natures[10], ('Timid', [-1,0,0,0,1]))
        self.assertEqual(sum(not any(row[1]) for row in natures), 5)

    def test_holdability_intersection_excludes_keys_tm_hm_and_exp_all(self):
        self.assertEqual(gen.collect(self.raw, ITEMS)[3],
            {'expAll':False,'hm01':False,'moonStone':81,'pokeBall':4,'potion':17,'tm01':False,'townMap':False})

    def test_missing_corrupt_fetch_failure_preserve_cache(self):
        manifest = {'files': {'source': {'url':'https://example.invalid/source','sha256':'0'*64}}}
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'source'
            with self.assertRaisesRegex(gen.GenerationError, 'missing'):
                gen.load(directory, manifest=manifest)
            with patch.object(gen.urllib.request, 'urlopen', side_effect=URLError('offline')):
                with self.assertRaises(URLError):
                    gen.load(directory, fetch=True, manifest=manifest)
            self.assertFalse(target.exists())
            with patch.object(gen.urllib.request, 'urlopen', return_value=io.BytesIO(b'wrong')):
                with self.assertRaisesRegex(gen.GenerationError, 'checksum mismatch'):
                    gen.load(directory, fetch=True, manifest=manifest)
            self.assertFalse(target.exists())
            target.write_bytes(b'corrupt')
            with self.assertRaisesRegex(gen.GenerationError, 'checksum mismatch'):
                gen.load(directory, manifest=manifest)
            self.assertEqual(target.read_bytes(), b'corrupt')

    def test_unknown_ability_nature_schema_unmapped_item_fail(self):
        bad = dict(self.raw); binary = bytearray(bad['personal_b2w2']); binary[76+24] = 0; bad['personal_b2w2'] = bytes(binary)
        with self.assertRaisesRegex(gen.GenerationError, 'unknown GenV'):
            gen.collect(bad, ITEMS)
        bad = dict(self.raw); bad['bw_src_system_poke_tool.c'] = b'bad schema'
        with self.assertRaisesRegex(gen.GenerationError, 'nature schema'):
            gen.collect(bad, ITEMS)
        bad_items = dict(ITEMS); bad_items['missing'] = {'symbol':'UNKNOWN_ITEM','keyItem':False,'category':'item'}
        with self.assertRaisesRegex(gen.GenerationError, 'missing GenV item'):
            gen.collect(self.raw, bad_items)

    def test_deterministic_cli_check_nonzero_on_drift(self):
        generated = gen.render(self.raw, ITEMS)
        self.assertEqual(generated, gen.render(self.raw, dict(reversed(list(ITEMS.items())))))
        with tempfile.TemporaryDirectory() as directory, patch.object(gen, 'load', return_value=self.raw), \
                patch.object(gen, 'load_items', return_value={}), patch.object(gen, 'collect_items', return_value=(ITEMS,{},{})):
            output = Path(directory) / 'specimen.lua'
            args = ['--cache',directory,'--items-cache',directory,'--output',str(output)]
            self.assertEqual(gen.main(args), 0)
            self.assertEqual(gen.main(args+['--check']), 0)
            output.write_text(generated + '-- drift\n')
            self.assertEqual(gen.main(args+['--check']), 1)


if __name__ == '__main__':
    unittest.main()
