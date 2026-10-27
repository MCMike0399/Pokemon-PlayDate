"""Primary ASM/data oracles for ordinary dialogue; never executes Lua."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import unittest
from tools import generate_vermilion_preparation as g


class VermilionAmbientTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ref = Path(os.environ['POKERED_REFERENCE_DIR'])
        cls.artifacts = g.build(cls.ref)
        cls.events = json.loads(cls.artifacts['events.json'])['events']

    def primary(self, path):
        data = subprocess.check_output(['git', '-C', str(self.ref), 'show', g.REVISION + ':' + path])
        pins = json.loads(g.PIN.read_bytes())['files']
        self.assertEqual(hashlib.sha256(data).hexdigest(), pins[path])
        self.assertEqual(data, (self.ref / path).read_bytes())
        return data.decode()

    def test_exact_installed_outputs_and_protected_maps_art(self):
        g.verify(self.artifacts, g.OUTPUT)
        for name, data in self.artifacts.items():
            if name.endswith('.json') and name not in {
                'events.json', 'scripts.json', 'reservations.json', 'provenance.json'}:
                old = subprocess.check_output(['git', 'show', 'e4dd170:Source/data/vermilionPreparation/' + name])
                self.assertEqual(data, old, name)

    def test_fan_cross_flags_and_clear_branch_from_primary(self):
        source = self.primary('scripts/PokemonFanClub.asm')
        for fan, other, index in [('Pikachu', 'Seel', 1), ('Seel', 'Pikachu', 2)]:
            body = g.sections(source)['PokemonFanClub' + fan + 'FanText']
            own = 'EVENT_' + fan.upper() + '_FAN_BOAST'
            opposite = 'EVENT_' + other.upper() + '_FAN_BOAST'
            self.assertIn('CheckEvent ' + own, body)
            self.assertIn('SetEvent ' + opposite, body)
            self.assertIn('ResetEvent ' + own, body)
            d = self.events[f'pokered:POKEMON_FAN_CLUB:objects:{index}']
            branch = d['cases'][0]
            self.assertEqual(branch['when'], {'flags': {own: True}})
            for program, suffix, flag, value in [
                (branch['then'], 'Better', own, False),
                (d['otherwise'], 'Normal', opposite, True),
            ]:
                self.assertEqual(program['transaction'], 'source-effects')
                self.assertEqual(set(program['guard_flags']), {own, opposite})
                self.assertEqual(program['steps'], [
                    {'op': 'dialog', 'labels': [f'_PokemonFanClub{fan}Fan{suffix}Text']},
                    {'op': 'set-flag', 'id': flag, 'value': value}])

    def test_departure_gambler_primary_branch(self):
        source = self.primary('scripts/VermilionCity.asm')
        body = g.sections(source)['VermilionCityGambler1Text']
        self.assertIn('CheckEvent EVENT_SS_ANNE_LEFT', body)
        d = self.events['pokered:VERMILION_CITY:objects:2']
        self.assertEqual(d['cases'][0]['when'], {'flags': {'EVENT_SS_ANNE_LEFT': True}})
        self.assertEqual(d['cases'][0]['then']['steps'][0]['labels'], ['_VermilionCityGambler1SSAnneDepartedText'])
        self.assertEqual(d['otherwise']['steps'][0]['labels'], ['_VermilionCityGambler1DidYouSeeText'])

    def test_all_cries_preserve_source_order_wait_and_machop_tail(self):
        cases = [('PokemonFanClub', 'Pikachu', 3, 'pikachu', True),
                 ('PokemonFanClub', 'Seel', 4, 'seel', True),
                 ('VermilionCity', 'Machop', 5, 'machop', True),
                 ('VermilionPidgeyHouse', 'Pidgey', 2, 'pidgey', True),
                 ('SSAnne1FRooms', 'Wigglytuff', 8, 'wigglytuff', False),
                 ('SSAnneB1FRooms', 'Machoke', 8, 'machoke', False)]
        names = {'PokemonFanClub': 'POKEMON_FAN_CLUB', 'VermilionCity': 'VERMILION_CITY',
                 'VermilionPidgeyHouse': 'VERMILION_PIDGEY_HOUSE', 'SSAnne1FRooms': 'SS_ANNE_1F_ROOMS',
                 'SSAnneB1FRooms': 'SS_ANNE_B1F_ROOMS'}
        for name, actor, index, species, wait in cases:
            body = g.sections(self.primary('scripts/' + name + '.asm'))[name + actor + 'Text']
            self.assertIn('ld a, ' + species.upper() + '\n\tcall PlayCry', body)
            self.assertEqual('call WaitForSoundToFinish' in body, wait)
            steps = self.events[f'pokered:{names[name]}:objects:{index}']['steps']
            self.assertEqual(steps[0], {'op': 'dialog', 'labels': ['_' + name + actor + 'Text']})
            self.assertEqual(steps[1], dict(op='source-audio', cue='cry', species=species,
                                          wait_for_completion=wait, owner='SourceAudio'))
            self.assertEqual(len(steps), 3 if species == 'machop' else 2)
            if species == 'machop':
                self.assertEqual(steps[2]['labels'], ['_VermilionCityMachopStompingTheLandFlatText'])

    def test_snorlax_display_and_primary_seen_side_effect(self):
        body = g.sections(self.primary('scripts/SSAnne2FRooms.asm'))['SSAnne2FRoomsGentleman3Text']
        self.assertIn('ld a, SNORLAX\n\tcall DisplayPokedex', body)
        display = self.primary('engine/events/display_pokedex.asm')
        self.assertLess(display.index('predef ShowPokedexData'), display.index('ld hl, wPokedexSeen'))
        self.assertIn('ld b, FLAG_SET', display)
        steps = self.events['pokered:SS_ANNE_2F_ROOMS:objects:5']['steps']
        self.assertEqual(steps[0], {'op': 'dialog', 'labels': ['_SSAnne2FRoomsGentleman3Text']})
        self.assertEqual((steps[1]['op'], steps[1]['species']), ('show-pokemon', 'snorlax'))
        dex = self.primary('engine/menus/pokedex.asm')
        self.assertIn('if the pokemon has not been owned', dex)
        self.assertIn('call PlayCry', dex)
        self.assertEqual(steps[1]['audio']['volume_before'], 0x33)
        self.assertEqual(steps[1]['audio']['volume_after'], 0x77)
        self.assertEqual(steps[1]['audio']['status_bit'], 'wStatusFlags2.BIT_NO_AUDIO_FADE_OUT')

    def test_chef_exact_256_byte_primary_partition(self):
        body = g.sections(self.primary('scripts/SSAnneKitchen.asm'))['SSAnneKitchenCook7Text']
        self.assertLess(body.index('bit 7, a'), body.index('bit 4, a'))
        steps = self.events['pokered:SS_ANNE_KITCHEN:objects:7']['steps']
        self.assertEqual(steps[0]['labels'], ['_SSAnneKitchenCook7MainCourseIsText'])
        for byte in range(256):
            rows = [c for c in steps[1]['choices'] if c['min'] <= byte <= c['max']]
            suffix = 'SalmonDuSaladText' if byte & 128 else 'EelsAuBarbecueText' if byte & 16 else 'PrimeBeefSteakText'
            self.assertEqual([r['labels'] for r in rows], [['SSAnneKitchenCook7' + suffix]])

    def test_prior_registrations_unchanged_and_separate_services_reserved(self):
        old = json.loads(subprocess.check_output(['git', 'show', 'e4dd170:Source/data/vermilionPreparation/events.json']))
        for id, descriptor in old['events'].items():
            self.assertEqual(self.events[id], descriptor, id)
        reservations = json.loads(self.artifacts['reservations.json'])['reservations']
        self.assertEqual(set(self.events) & {r['id'] for r in reservations}, set())
        for id in ['pokered:ROUTE_11_GATE_2F:objects:1', 'pokered:VERMILION_TRADE_HOUSE:objects:1',
                   'pokered:ROUTE_2_TRADE_HOUSE:objects:2', 'pokered:VERMILION_POKECENTER:objects:4',
                   'pokered:ROUTE_11_GATE_2F:background_events:1', 'pokered:ROUTE_11_GATE_2F:background_events:2']:
            self.assertIn(id, {r['id'] for r in reservations})

    def test_recipes_end_at_every_global_label(self):
        recipe = g.text_recipes('_First:: ; exported\n text "é"\n done\nPrivate:\n text "second"\n done\nOther::\n text "third"\n done\n')
        self.assertEqual([r.get('text') for r in recipe['_First'] if r['op'] == 'text'], ['é'])
        self.assertEqual([r.get('text') for r in recipe['Private'] if r['op'] == 'text'], ['second'])
