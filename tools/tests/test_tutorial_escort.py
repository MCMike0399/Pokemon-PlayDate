"""Host checks pin source inputs and generated records; no Lua emulation."""
from pathlib import Path
import tempfile
import unittest
from tools import generate_tutorial_escort as generator


class TutorialEscortGeneratorTests(unittest.TestCase):
    def test_generated_output_is_reproducible(self):
        self.assertEqual(generator.OUTPUT.read_bytes(), generator.encoded())

    def test_all_inputs_pinned_and_nonempty(self):
        sources = generator.inputs()
        self.assertEqual(len(sources), 17)
        self.assertTrue(all(sources.values()))

    def test_changed_source_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for path, raw in generator.inputs().items():
                target = root / path
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(raw)
            (root / 'scripts/ViridianCity.asm').write_bytes(b'changed')
            with self.assertRaises(AssertionError):
                generator.build(root)

    def test_independent_routes_and_all_endpoints(self):
        data = generator.build()['escort']
        # Independent transcription of source RLE and LIFO joypad/prefix data.
        main = ['left']*15 + ['up']*5 + ['left']*11 + ['down']*5 + ['right']*2 + ['wait']
        prefixes = {'34,16': ['right','down','down','left'],
                    '35,17': ['left','right','down','left'],
                    '37,18': ['wait']*8 + ['left']*3,
                    '37,19': ['left','up','left','left'],
                    '36,17': ['wait']*8 + ['left','down','left']}
        delta = {'up':(0,-1), 'down':(0,1), 'left':(-1,0), 'right':(1,0), 'wait':(0,0)}
        for key, prefix in prefixes.items():
            route = data['player_routes'][key]
            self.assertEqual(route, prefix + main)
            x,y = map(int,key.split(','))
            for direction in route:
                dx,dy = delta[direction]; x += dx; y += dy
            self.assertEqual([x,y], [10,18])
        self.assertEqual(data['npc_route'], ['down']*2 + ['left']*15 + ['up']*5 + ['left']*11 + ['down']*5 + ['right']*3)
        self.assertEqual(data['departure'], ['right']*5)
        self.assertEqual(data['triggers'], [[35,17],[36,17],[37,18],[37,19]])

    def test_source_script_demo_exception_is_explicit(self):
        raw = generator.inputs()
        script = raw['scripts/ViridianCity.asm'].decode()
        self.assertIn('ld a, 5\n\tld [wCurEnemyLevel]',script)
        self.assertIn('ld a, WEEDLE',script)
        awake = script.split('ViridianCityOldManText:',1)[1].split('.HadMyCoffeeNowText:',1)[0]
        self.assertIn('and a\n\tjr z, .refused',awake)
        self.assertIn('SCRIPT_VIRIDIANCITY_OLD_MAN_START_CATCH_TRAINING',awake)
        item = raw['engine/items/item_effects.asm'].decode()
        self.assertIn('jp .captured\n\n.notOldManBattle',item)
        self.assertIn("if so, don't give the player the caught Pokémon",item)
        self.assertIn("if so, don't remove a ball from the bag",item)
        data = generator.build()['tutorial']
        self.assertEqual((data['species'],data['level'],data['display_quantity']),('weedle',5,50))
        self.assertTrue(data['scripted_catch'])

    def test_art_is_direct_four_shade_transcription(self):
        from PIL import Image
        import io
        raw = generator.inputs()
        palette = {'.':255, '1':170, '2':85, '#':0}
        for art in generator.build()['art'].values():
            image = Image.open(io.BytesIO(raw[art['source']]))
            self.assertEqual((art['width'],art['height']), image.size)
            decoded = [palette[c] for row in art['rows'] for c in row]
            self.assertEqual(decoded,list(image.getdata()))

    def test_ids_and_source_conditions(self):
        data = generator.build()
        self.assertEqual(data['actors']['oldman']['id'],'pokered:VIRIDIAN_CITY:objects:7')
        self.assertEqual(data['actors']['escort']['id'],'pokered:PEWTER_CITY:objects:5')
        self.assertEqual(data['tutorial']['gate'],'EVENT_GOT_POKEDEX')
        self.assertEqual(data['tutorial']['yes_means'],'in-a-hurry')
        self.assertEqual(data['tutorial']['sleepy_trigger'],[19,9])
        recipe = data['texts']['_ViridianCityOldManHadMyCoffeeNowText']['recipe']
        self.assertTrue(any(r.get('text') == 'hurry?' for r in recipe))

    def test_source_simulated_player_input_skips_sprite_collision(self):
        # These are the pinned original instructions, not a Lua implementation
        # assertion. The branch bypasses both sprite probes before tile checks.
        source = generator.inputs()['home/overworld.asm'].decode()
        land = source.split('CollisionCheckOnLand::', 1)[1].split('\n.noCollision', 1)[0]
        branch = ('ld a, [wSimulatedJoypadStatesIndex]\n\tand a\n'
                  '\tjr nz, .noCollision')
        self.assertIn(branch, land)
        self.assertLess(land.index(branch), land.index('wSpritePlayerStateData1CollisionData'))
        self.assertLess(land.index(branch), land.index('call IsSpriteInFrontOfPlayer'))

    def test_every_source_escort_route_crosses_unchanged_source_stay_actor(self):
        source = generator.inputs()['data/maps/objects/PewterCity.asm'].decode()
        self.assertIn('object_event  8, 15, SPRITE_COOLTRAINER_F, STAY, NONE', source)
        delta = {'up': (0,-1), 'down': (0,1), 'left': (-1,0),
                 'right': (1,0), 'wait': (0,0)}
        for entry, route in generator.build()['escort']['player_routes'].items():
            x, y = map(int, entry.split(','))
            cells = []
            for direction in route:
                dx, dy = delta[direction]
                x, y = x+dx, y+dy
                cells.append((x,y))
            self.assertIn((8,15), cells, entry)
            self.assertEqual(cells[-1], (10,18))

if __name__ == '__main__':
    unittest.main()
