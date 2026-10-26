"""Independent pinned Blue geography/art/roster checks; never executes Lua."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from PIL import Image
from tools import generate_vermilion_preparation as g
from tools.generate_kanto_maps import MapError, Reference, decode_map

BASE = 'c6882b696fa9e0b8b4f43e7bb46fffacceeb11f6'


class VermilionPreparationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get('POKERED_REFERENCE_DIR'):
            raise RuntimeError('explicit pinned POKERED_REFERENCE_DIR required; no skipped checks')
        cls.ref = Path(os.environ['POKERED_REFERENCE_DIR'])
        cls.artifacts = g.build(cls.ref)
        cls.maps = {name: json.loads(cls.artifacts[name + '.json']) for name in g.MAPS}
        cls.events = json.loads(cls.artifacts['events.json'])
        cls.trainers = json.loads(cls.artifacts['trainers.json'])
        cls.texts = json.loads(cls.artifacts['dialogue.json'])['texts']
        cls.pin = json.loads(g.PIN.read_bytes())

    def test_deterministic_complete_output_and_pinned_reference(self):
        self.assertEqual(subprocess.check_output(['git', '-C', str(self.ref), 'rev-parse', 'HEAD'], text=True).strip(), g.REVISION)
        self.assertEqual(self.artifacts, g.build(self.ref))
        g.verify(self.artifacts, g.OUTPUT)
        consumed = json.loads(self.artifacts['provenance.json'])['source_files']
        self.assertEqual(consumed, self.pin['files'])
        for path, expected in consumed.items():
            original = subprocess.check_output(['git', '-C', str(self.ref), 'show', g.REVISION + ':' + path])
            self.assertEqual((self.ref / path).read_bytes(), original, path)
            self.assertEqual(hashlib.sha256(original).hexdigest(), expected, path)

    def test_active_manifest_cache_and_preexisting_input_art_are_unchanged(self):
        tracked = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', BASE, 'Source'], text=True).splitlines()
        roots = ('Source/images/', 'Source/world/sprites/', 'Source/data/sourceMapCache/',
                 'Source/data/viridianSlice/', 'Source/data/pewterSlice/', 'Source/data/sourceSlice/')
        exact = {'Source/data/sourceMaps.json', 'Source/world/tilefactory.lua',
                 'Source/world/spritefactory.lua', 'Source/lib/shade.lua'}
        for path in tracked:
            if path in exact or path.startswith(roots):
                self.assertEqual((g.ROOT / path).read_bytes(), subprocess.check_output(['git', 'show', BASE + ':' + path]), path)
        self.assertEqual(len(json.loads((g.ROOT / 'Source/data/sourceMaps.json').read_bytes())['maps']), 30)

    def test_one_existing_pipeline_and_exact_additive_promotion(self):
        active = json.loads((g.ROOT / 'Source/data/sourceMaps.json').read_bytes())
        proposed = json.loads(self.artifacts['proposed-source-maps.json'])
        additions = json.loads(self.artifacts['manifest-entries.json'])['maps']
        self.assertEqual(len(additions), 35)
        self.assertEqual(len(proposed['maps']), 65)
        for name, value in active['maps'].items():
            self.assertEqual(proposed['maps'][name], value)
        for key in active.keys() - {'maps'}:
            self.assertEqual(active[key], proposed[key])
        self.assertEqual(set(proposed['maps']) - set(active['maps']), set(g.MAPS))
        cache = json.loads(self.artifacts['proposed-compact.json'])
        self.assertEqual(cache['manifest_sha256'], g.digest(self.artifacts['proposed-source-maps.json']))
        old_tiles = json.loads((g.ROOT / 'Source/data/sourceMapCache/tile-grids.json').read_bytes())['tiles']
        tiles = json.loads(self.artifacts['proposed-tile-grids.json'])['tiles']
        for key, value in old_tiles.items():
            self.assertEqual(tiles[key], value)
        for name, entry in additions.items():
            self.assertEqual(entry['profile'], 'source')
            self.assertEqual(entry['source_sha256'], g.digest(self.artifacts[name + '.json']))
        source = (g.ROOT / 'tools/generate_vermilion_preparation.py').read_text()
        self.assertIn('decode_map(ref, name', source)
        self.assertIn('cache_build(manifest_path, source)', source)

    def test_all_cells_blocks_collision_and_png_pixels_independently(self):
        assembly = (self.ref / 'maps.asm').read_text()
        collision = (self.ref / 'data/tilesets/collision_tile_ids.asm').read_text()
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        for name, d in self.maps.items():
            path = re.search(rf'^{name}_Blocks:(?:[^\n]*\n)*?[^\n]*INCBIN "([^"]+)"', assembly, re.M)[1]
            layout = (self.ref / path).read_bytes()
            if name == 'UndergroundPathNorthSouth':
                self.assertRegex(assembly, r'UndergroundPathNorthSouth_Blocks: INCBIN "maps/UndergroundPathNorthSouth.blk"\nUndergroundPathWestEast_Blocks: INCBIN "maps/UndergroundPathWestEast.blk"')
                self.assertEqual(len(layout), 92)
                layout += (self.ref / 'maps/UndergroundPathWestEast.blk').read_bytes()[:4]
                self.assertEqual(d['layout_extent']['size'], 4)
            blockset = (self.ref / d['tileset']['blockset']).read_bytes()
            image = Image.open(self.ref / d['tileset']['graphics']).convert('L')
            width, height = d['dimensions']['cells']
            self.assertEqual(len(layout), width * height // 4)
            # Collision lists end at the sentinel, independently of generator.
            body = re.search(r'^' + d['tileset']['name'] + r'_Coll::?\n(?:\w+_Coll::?\n)*(.*?)(?=^\w|\Z)', collision, re.M | re.S)[1]
            allowed = {int(token, 16) for token in re.findall(r'\$([0-9a-fA-F]{2})', body)} - {255}
            for y in range(height):
                for x in range(width):
                    offset = y // 2 * (width // 2) + x // 2
                    block, quadrant = layout[offset], 2 * (y % 2) + x % 2
                    self.assertEqual(d['source_refs'][y][x], [offset, block, quadrant])
                    start = block * 16 + (y % 2) * 8 + (x % 2) * 2
                    ids = [blockset[start + i] for i in (0, 1, 4, 5)]
                    grid = d['grids'][d['tile_ids'][y][x] - 1]
                    self.assertEqual(grid['source_tile_ids'], ids)
                    self.assertEqual(d['collision'][y][x], int(ids[2] not in allowed))
            for grid in d['grids']:
                expected = [''.join(shades[image.getpixel((tile % (image.width // 8) * 8 + x % 8,
                    tile // (image.width // 8) * 8 + y % 8))]
                    for x in range(16) for tile in [grid['source_tile_ids'][y // 8 * 2 + x // 8]]) for y in range(16)]
                self.assertEqual(grid['grid'], expected, name)

    def test_layout_continuation_is_explicit_bounded_and_default_still_rejects(self):
        ref = Reference(self.ref, self.pin['files'])
        with self.assertRaisesRegex(MapError, 'layout dimensions mismatch'):
            decode_map(ref, 'UndergroundPathNorthSouth')
        for tail in [('maps/UndergroundPathWestEast.blk', 3), ('maps/Route5.blk', 4), ('maps/UndergroundPathWestEast.blk', -4)]:
            with self.assertRaisesRegex(MapError, 'unverified adjacent'):
                decode_map(ref, 'UndergroundPathNorthSouth', linked_layout_tail=tail)

    def test_all_sprite_frames_match_pinned_png_and_protected_blue_policy_is_preserved(self):
        sprites = json.loads(self.artifacts['sprites.json'])['sprites']
        shades = {255: '.', 170: '1', 85: '2', 0: '#'}
        for sprite in sprites.values():
            image = Image.open(self.ref / sprite['source']).convert('L')
            for frame, grid in sprite['frames'].items():
                self.assertEqual(grid, [''.join(shades[image.getpixel((x, int(frame) * 16 + y))] for x in range(16)) for y in range(16)])
        old = json.loads((g.ROOT / 'Source/data/sourceSlice/sprites.json').read_bytes())['sprites']
        for source in sprites.keys() & old.keys():
            self.assertEqual(sprites[source], old[source])
        patch = (g.ROOT / 'tools/integration/vermilion-content-root.patch').read_text()
        self.assertNotIn('+    SourceActors.registerContent', patch)
        self.assertNotIn('-    if source == "SPRITE_BLUE"', patch)

    def test_exact_asm_global_boundaries_and_literal_utf8_in_every_json(self):
        text = '_First::\n text "one"\nPrivate: ; boundary\n text "private"\n_Second: ; boundary\n text "two"\n'
        recipes = g.text_recipes(text)
        self.assertEqual([r.get('text') for r in recipes['_First']], ['one'])
        self.assertEqual([r.get('text') for r in recipes['_Second']], ['two'])
        self.assertEqual(set(g.sections(text)), {'_First', 'Private', '_Second'})
        self.assertIn('SSAnneKitchenCook7SalmonDuSaladText', self.texts)
        for name, raw in self.artifacts.items():
            self.assertNotRegex(raw.decode(), r'\\u[0-9a-fA-F]{4}', name)
            self.assertEqual(g.canonical(json.loads(raw)), raw, name)
        self.assertIn('¥', self.artifacts['dialogue.json'].decode())

    def test_text_lines_events_and_reservations_are_complete_disjoint(self):
        for record in self.texts.values():
            lines = (self.ref / record['source']).read_text().splitlines()
            for row in record['recipe']:
                line = lines[row['source_line'] - 1].split(';', 1)[0].strip()
                expected = f'{row["op"]} "{row["text"]}"' if 'text' in row else 'text_ram ' + row['symbol'] if row['op'] == 'text_ram' else row['source']
                self.assertEqual(line, expected)
        old_texts = json.loads((g.ROOT / 'Source/data/sourceSlice/dialogue.json').read_bytes())['texts']
        for label in self.texts.keys() & old_texts.keys():
            self.assertEqual(self.texts[label], old_texts[label], label)
        bound = set(self.events['events']) | set(self.events['signs'])
        reservations = json.loads(self.artifacts['reservations.json'])['reservations']
        reserved = {row['id'] for row in reservations}
        expected = {e['id'] for d in self.maps.values() for group in ('objects', 'background_events') for e in d['events'][group]}
        self.assertFalse(bound & reserved)
        self.assertEqual(bound | reserved, expected)
        for map_name, indexes in g.BESPOKE.items():
            for index in indexes:
                self.assertIn(f"{self.maps[map_name]['id']}:objects:{index}", reserved)
        def labels(value):
            if isinstance(value, dict):
                for k, child in value.items():
                    if k in ('labels', 'before', 'won', 'after', 'success', 'full') and isinstance(child, list):
                        for label in child:self.assertTrue(label in self.texts, label)
                    else: labels(child)
            elif isinstance(value, list):
                for child in value: labels(child)
        labels(self.events)
        for row in reservations:
            for label in row['text_labels']:self.assertTrue(label in self.texts, label)

    def test_every_trainer_roster_matches_independent_blue_party_parser(self):
        # Line references preserve exact source db records. Independently select
        # Blue branches and decode uniform/$FF parties without generator helpers.
        text = (self.ref / 'data/trainers/parties.asm').read_text()
        selected, stack, active = [], [], True
        for line in text.splitlines():
            clean=line.split(';',1)[0].strip()
            if clean.startswith('IF '):
                self.assertIn(clean, ('IF DEF(_RED)', 'IF DEF(_BLUE)'))
                stack.append((active, clean == 'IF DEF(_BLUE)'));active=active and stack[-1][1]
            elif clean == 'ELSE':
                parent, branch=stack[-1];stack[-1]=(parent,not branch);active=parent and not branch
            elif clean == 'ENDC':active,_=stack.pop()
            elif active:selected.append(line)
        bodies = dict(re.findall(r'^(\w+Data):\n(.*?)(?=^\w+Data:|\Z)', '\n'.join(selected), re.M | re.S))
        classes = re.findall(r'^\s*trainer_const[ \t]+(\w+)', (self.ref/'constants/trainer_constants.asm').read_text(), re.M)[1:]
        pointers = re.findall(r'^\s*dw (\w+Data)\s*$', '\n'.join(selected), re.M)
        source_rows = {}
        for cls, pointer in zip(classes,pointers):
            rows=[]
            for raw in re.findall(r'^\s*db ([^;\n]+)', bodies[pointer], re.M):
                tokens=[t.strip() for t in raw.strip().split(',')]
                self.assertEqual(tokens[-1],'0')
                if tokens[0]=='$FF':party=list(zip(map(int,tokens[1:-1:2]),tokens[2:-1:2]))
                else:party=[(int(tokens[0]),mon) for mon in tokens[1:-1]]
                rows.append(party)
            source_rows['OPP_'+cls]=rows
        for trainer in self.trainers['trainers'].values():
            expected=source_rows[trainer['class_source']][trainer['roster_id']-1]
            self.assertEqual([(m['level'],m['species_source']) for m in trainer['party']],expected)
            self.assertEqual(trainer['payout'],trainer['base_money']*expected[-1][0])
        for cls, data in self.trainers['rival_classes'].items():
            for index,row in enumerate(data['parties']):
                self.assertEqual([(m['level'],m['species_source']) for m in row['party']],source_rows[cls][index])
        self.assertEqual([(m['level'],m['species']) for m in self.trainers['trainers']['pokered:VERMILION_GYM:objects:1']['party']], [(21,'voltorb'),(18,'pikachu'),(24,'raichu')])

    def test_original_events_header_connections_music_and_blue_wild_tables(self):
        songs = re.findall(r'^\s*db (MUSIC_\w+), (BANK\(Music_\w+\))', (self.ref/'data/maps/songs.asm').read_text(), re.M)
        wild_pointers = re.findall(r'^\s*dw (\w+)', (self.ref/'data/wild/grass_water.asm').read_text(), re.M)
        for name,d in self.maps.items():
            source=(self.ref/f'data/maps/objects/{name}.asm').read_text()
            for macro,group in [('warp_event','warps'),('bg_event','background_events'),('object_event','objects')]:
                rows = re.findall(r'^\s*' + macro + r' ([^;\n]+)',source,re.M)
                self.assertEqual(len(rows),len(d['events'][group]),name)
                for raw,event in zip(rows,d['events'][group]):
                    args=[v.strip() for v in raw.split(',')]
                    self.assertEqual([event['x'],event['y']],list(map(int,args[:2])))
                    if group=='objects':self.assertEqual(event['sprite'],args[2])
                    if group=='warps':
                        self.assertEqual(event['destination']['warp_index'],int(args[3]))
                        if args[2]!='LAST_MAP':self.assertEqual(event['destination']['map'],args[2])
            header=(self.ref/f'data/maps/headers/{name}.asm').read_text()
            connections=re.findall(r'^\s*connection (\w+), (\w+), (\w+), (-?\d+)',header,re.M)
            self.assertEqual([(c['direction'],c['target_header'],c['target_map'],str(c['offset_blocks'])) for c in d['connections']],connections)
            self.assertEqual((d['music']['symbol'],d['music']['audio_bank']),songs[d['source_map_id']])
            pointer=wild_pointers[d['source_map_id']]
            self.assertEqual(d['encounters']['source_pointer'],pointer)
            path='nothing' if pointer=='NothingWildMons' else pointer.removesuffix('WildMons')
            raw=(self.ref/f'data/wild/maps/{path}.asm').read_text()
            # Independently remove RED branch and unwrap BLUE declarations.
            raw=re.sub(r'IF DEF\(_RED\)\n.*?ENDC', '', raw, flags=re.S)
            raw=raw.replace('IF DEF(_BLUE)','').replace('ENDC','')
            for kind in ('grass','water'):
                match=re.search(r'def_'+kind+r'_wildmons (\d+)(.*?)end_'+kind+r'_wildmons',raw,re.S)
                table=d['encounters'][kind]
                self.assertEqual(table['rate_byte'],int(match[1]))
                slots=[(int(level),mon) for level,mon in re.findall(r'^\s*db[ \t]+(\d+),[ \t]+(\w+)',match[2],re.M)]
                self.assertEqual([(slot['level'],slot['species_source']) for slot in table['slots']],slots)
                if slots:self.assertEqual([slot['weight_256'] for slot in table['slots']],[51,51,39,25,25,25,13,13,11,3])
        center=self.maps['VermilionPokecenter']
        self.assertEqual(center['dimensions']['cells'],[14,8])
        step=self.events['events']['pokered:VERMILION_POKECENTER:objects:1']['steps'][0]
        self.assertEqual(step['op'],'heal')
        self.assertEqual(step['checkpoint'],dict(zone_id='pokered:VERMILION_CITY',x=11,y=4,facing='down'))

    def test_changed_pinned_input_is_rejected(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'maps/UndergroundPathWestEast.blk'
            path.parent.mkdir()
            path.write_bytes((self.ref/'maps/UndergroundPathWestEast.blk').read_bytes()+b'\0')
            with self.assertRaisesRegex(MapError,'checksum'):
                Reference(temp,self.pin['files']).bytes('maps/UndergroundPathWestEast.blk')

    def test_missing_mutated_and_extra_output_rejected_without_repairs(self):
        for mutation in ('missing','mutated','extra'):
            with tempfile.TemporaryDirectory() as temp:
                path=Path(temp)
                for name,data in self.artifacts.items():(path/name).write_bytes(data)
                if mutation=='missing':(path/'Route5.json').unlink()
                elif mutation=='mutated':(path/'Route5.json').write_bytes(b'{}')
                else:(path/'extra').write_bytes(b'{}')
                before={p.name:p.read_bytes() for p in path.iterdir()}
                with self.assertRaises(ValueError):g.verify(self.artifacts,path)
                self.assertEqual(before,{p.name:p.read_bytes() for p in path.iterdir()})


if __name__ == '__main__':
    unittest.main()
