"""Call the fossil revival service with the pinned generator table."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('late_kanto', ROOT / 'tools/generate_late_kanto_story.py')
GEN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GEN)
REFERENCE = Path(os.environ.get('POKERED_REFERENCE_DIR', Path.home() / 'Developer/Pokemon-PlayDate-env/pokered'))
HOST = ROOT / 'tools/tests/fossil_revival_host.lua'
SERVICE = ROOT / 'Source/game/fossilRevival.lua'


def lua_binary():
    override = os.environ.get('LUA')
    if override:
        return override
    for name in ('lua', 'lua5.4'):
        found = shutil.which(name)
        if found:
            return found
    built = Path('/tmp/lua-5.4.7/src/lua')
    if built.is_file() and os.access(built, os.X_OK):
        return str(built)
    raise AssertionError('Lua 5.4 is required to call FossilRevival')


def run_service(revival, scenarios):
    with tempfile.TemporaryDirectory() as tmp:
        directory = Path(tmp)
        canonical = directory / 'revival.json'
        ops = directory / 'ops.json'
        canonical.write_text(json.dumps(revival))
        ops.write_text(json.dumps({'scenarios': scenarios}))
        completed = subprocess.run(
            [lua_binary(), str(HOST), str(ROOT), str(ops), str(canonical)],
            check=False, capture_output=True, text=True)
    if completed.returncode != 0:
        raise AssertionError(completed.stderr or completed.stdout)
    return json.loads(completed.stdout)


def gave_flag(revival):
    still = revival['still_reviving_cleared_on_map_load']['event']
    found = [flag for flag in revival['give_sets'] if flag != still]
    if len(found) != 1 or still not in revival['give_sets']:
        raise AssertionError('generator give flags changed')
    return found[0], still


class FossilRevivalServiceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.generated = GEN.build(REFERENCE)
        cls.scenes = json.loads(cls.generated['scenes.json'])['scenes']
        cls.revival = cls.scenes['fossil_revival']
        cls.gave, cls.still = gave_flag(cls.revival)
        cls.handing = cls.revival['handover_sets'][0]
        cls.island = cls.revival['still_reviving_cleared_on_map_load']['map_constant']
        cls.lab = cls.revival['scientist']['map_constant']
        cls.dome, cls.helix, cls.amber = cls.revival['results']
        patched = copy.deepcopy(cls.revival)
        patched['level'] = cls.revival['level'] - 1 if cls.revival['level'] == 100 else cls.revival['level'] + 1
        # A real species outside the fossil rows, so a hardcoded pairing cannot pass.
        patched['results'][0]['species'] = 'BULBASAUR'
        cls.patched = patched
        cls.host = run_service(cls.revival, [
            {'name': 'decline', 'revival': cls.revival, 'steps': [
                {'op': 'add', 'symbol': cls.dome['item']},
                {'op': 'cancel'},
                {'op': 'confirm', 'item': cls.dome['item'], 'accepted': False},
                {'op': 'talk'},
                {'op': 'confirm', 'item': cls.helix['item'], 'accepted': True},
                {'op': 'take', 'symbol': cls.dome['item']},
                {'op': 'confirm', 'item': cls.dome['item'], 'accepted': True},
                {'op': 'confirm', 'item': 'MASTER_BALL', 'accepted': True},
            ]},
            {'name': 'one-fossil', 'revival': cls.revival, 'steps': [
                {'op': 'add', 'symbol': cls.dome['item']},
                {'op': 'add', 'symbol': cls.helix['item']},
                {'op': 'add', 'symbol': cls.amber['item']},
                {'op': 'confirm', 'item': cls.dome['item'], 'accepted': True},
                {'op': 'confirm', 'item': cls.helix['item'], 'accepted': True},
                {'op': 'talk'},
                {'op': 'map', 'map': cls.lab},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
                {'op': 'talk'},
                {'op': 'confirm', 'item': cls.helix['item'], 'accepted': True},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
            ]},
            {'name': 'box-full', 'revival': cls.revival, 'steps': [
                {'op': 'fill', 'partyOnly': False},
                {'op': 'add', 'symbol': cls.amber['item']},
                {'op': 'confirm', 'item': cls.amber['item'], 'accepted': True},
                {'op': 'talk'},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
                {'op': 'box', 'index': 2},
                {'op': 'talk'},
                {'op': 'talk'},
            ]},
            {'name': 'party-full', 'revival': cls.revival, 'steps': [
                {'op': 'add', 'symbol': cls.helix['item']},
                {'op': 'confirm', 'item': cls.helix['item'], 'accepted': True},
                {'op': 'fill', 'partyOnly': True},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
            ]},
            {'name': 'follows-table', 'revival': patched, 'steps': [
                {'op': 'add', 'symbol': patched['results'][0]['item']},
                {'op': 'confirm', 'item': patched['results'][0]['item'], 'accepted': True},
                {'op': 'map', 'map': patched['still_reviving_cleared_on_map_load']['map_constant']},
                {'op': 'talk'},
            ]},
            {'name': 'continue-declined', 'revival': cls.revival, 'steps': [
                {'op': 'add', 'symbol': cls.dome['item']},
                {'op': 'confirm', 'item': cls.dome['item'], 'accepted': False},
                {'op': 'continue'},
            ]},
            {'name': 'continue-choice', 'revival': cls.revival, 'steps': [
                {'op': 'add', 'symbol': cls.dome['item']},
                {'op': 'confirm', 'item': cls.dome['item'], 'accepted': True},
                {'op': 'continue'},
                {'op': 'map', 'map': cls.lab},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
                {'op': 'talk'},
            ]},
            {'name': 'continue-box-full', 'revival': cls.revival, 'steps': [
                {'op': 'fill', 'partyOnly': False},
                {'op': 'add', 'symbol': cls.amber['item']},
                {'op': 'confirm', 'item': cls.amber['item'], 'accepted': True},
                {'op': 'talk'},
                {'op': 'map', 'map': cls.island},
                {'op': 'talk'},
                {'op': 'continue'},
                {'op': 'talk'},
                {'op': 'box', 'index': 2},
                {'op': 'talk'},
                {'op': 'continue'},
                {'op': 'talk'},
            ]},
        ])

    def scenario(self, name):
        return self.host['scenarios'][name]

    def flags(self, step):
        return step['state']['flags'][self.gave], step['state']['flags'][self.still], step['state']['flags'][self.handing]

    def test_service_reads_the_generator_and_is_not_on_the_root(self):
        self.assertEqual(self.host['plan'], self.revival)
        self.assertEqual((GEN.OUTPUT / 'scenes.json').read_bytes(), self.generated['scenes.json'])
        text = SERVICE.read_text()
        hook = text.split('-- ROOT_HOOK: ', 1)[1].split('\n', 1)[0]
        anchor = text.split('-- ROOT_ANCHOR: ', 1)[1].split('\n', 1)[0]
        self.assertEqual(hook, 'import "game/fossilRevival"')
        self.assertEqual(anchor, 'import "domain/gameSession"')
        main = (ROOT / 'Source/main.lua').read_text()
        self.assertEqual(main.count(anchor), 1)
        self.assertNotIn(hook, main)
        self.assertNotIn('lateKantoStory', main)
        self.assertNotIn('function FossilRevival.install', text)
        self.assertNotIn('SourceEvents', text)
        self.assertNotIn('__mode', text)
        self.assertIn('wFossilItem:', text)
        self.assertIn('wFossilMon:', text)
        host_text = HOST.read_text()
        self.assertIn('SessionCodec.encode', host_text)
        self.assertIn('SessionCodec.decode', host_text)
        for relative in (
            'Source/main.lua',
            'Source/data/sourceMaps.json',
            'Source/domain/sessionCodec.lua',
            'Source/domain/gameSession.lua',
            'Source/domain/saveStore.lua',
        ):
            untouched = (ROOT / relative).read_text()
            self.assertNotIn('wFossil', untouched)
            self.assertNotIn('fossilRevival', untouched)
        installed = json.loads((ROOT / 'Source/data/sourceMaps.json').read_text())['maps']
        self.assertEqual(self.scenes['missing_maps'], [])
        for name in (self.revival['scientist']['map'], self.revival['still_reviving_cleared_on_map_load']['map']):
            self.assertIn(name, installed)

    def test_cancellation_and_a_missing_fossil_leave_the_source_flags_clear(self):
        steps = self.scenario('decline')
        self.assertEqual(steps[1]['result']['status'], 'cancelled')
        self.assertIsNone(steps[1]['state']['pending'])
        self.assertEqual(steps[1]['state']['items'][self.dome['item']], 1)
        self.assertEqual(self.flags(steps[1]), (False, False, False))
        declined = steps[2]
        self.assertEqual(declined['result']['status'], 'cancelled')
        self.assertEqual(declined['state']['pending'], {'item': self.dome['item'], 'species': self.dome['species']})
        self.assertEqual(self.flags(declined), (False, False, False))
        self.assertEqual(steps[3]['result'], {'ok': True, 'status': 'offer', 'fossils': [self.dome['item']]})
        self.assertEqual(steps[3]['state']['counts'][self.dome['species']], 0)
        self.assertEqual(steps[4]['result']['status'], 'no-fossil')
        self.assertEqual(steps[4]['state']['pending']['species'], self.dome['species'])
        self.assertEqual(steps[5]['result']['status'], 'taken')
        missing = steps[6]
        self.assertEqual(missing['result']['status'], 'no-fossil')
        self.assertEqual(missing['state']['items'][self.dome['item']], 0)
        self.assertEqual(self.flags(missing), (False, False, False))
        self.assertEqual(missing['state']['pending']['species'], self.dome['species'])
        self.assertEqual(steps[7]['result']['status'], 'not-a-fossil')
        self.assertEqual(self.flags(steps[7]), (False, False, False))

    def test_one_fossil_blocks_the_others_until_the_source_flags_reset(self):
        steps = self.scenario('one-fossil')
        offered = [self.dome['item'], self.helix['item'], self.amber['item']]
        given = steps[3]
        self.assertEqual(given['result']['status'], 'reviving')
        self.assertEqual(given['state']['items'], {self.dome['item']: 0, self.helix['item']: 1, self.amber['item']: 1})
        self.assertEqual(self.flags(given), (True, True, False))
        self.assertEqual(given['state']['pending'], {'item': self.dome['item'], 'species': self.dome['species']})
        blocked = steps[4]
        self.assertEqual(blocked['result']['status'], 'already-reviving')
        self.assertEqual(blocked['state']['items'][self.helix['item']], 1)
        self.assertEqual(blocked['state']['pending']['species'], self.dome['species'])
        self.assertEqual(steps[5]['result']['status'], 'still-reviving')
        self.assertEqual(self.flags(steps[5]), (True, True, False))
        self.assertEqual(steps[5]['state']['counts'][self.dome['species']], 0)
        self.assertEqual(steps[6]['result']['status'], 'ignored')
        self.assertEqual(self.flags(steps[6]), (True, True, False))
        self.assertEqual(steps[7]['result']['status'], 'cleared')
        self.assertEqual(self.flags(steps[7]), (True, False, False))
        revived = steps[8]
        self.assertEqual(revived['result']['status'], 'revived')
        self.assertEqual(revived['result']['destination'], 'party')
        self.assertEqual(revived['result']['species'], self.dome['species'])
        self.assertEqual(revived['result']['level'], self.revival['level'])
        self.assertEqual(self.flags(revived), (False, False, False))
        self.assertEqual(revived['state']['counts'][self.dome['species']], 1)
        self.assertTrue(revived['state']['owned'][self.dome['species']])
        self.assertNotEqual(revived['state']['rolls'], steps[7]['state']['rolls'])
        self.assertEqual(steps[9]['result']['status'], 'offer')
        self.assertEqual(steps[9]['result']['fossils'], [self.helix['item'], self.amber['item']])
        self.assertEqual(steps[9]['state']['counts'][self.dome['species']], 1)
        self.assertEqual(steps[10]['result']['status'], 'reviving')
        self.assertEqual(steps[12]['result']['species'], self.helix['species'])
        self.assertEqual(steps[12]['state']['counts'][self.helix['species']], 1)
        self.assertEqual(steps[12]['state']['counts'][self.dome['species']], 1)
        self.assertEqual(self.flags(steps[12]), (False, False, False))

    def test_full_current_box_fails_without_granting_and_retries(self):
        steps = self.scenario('box-full')
        given = steps[2]
        self.assertEqual(given['result']['status'], 'reviving')
        self.assertEqual(given['state']['party'], 6)
        self.assertEqual(given['state']['box'], 20)
        self.assertEqual(given['state']['items'][self.amber['item']], 0)
        self.assertEqual(given['state']['counts'][self.amber['species']], 0)
        self.assertFalse(given['state']['owned'][self.amber['species']])
        self.assertEqual(self.flags(given), (True, True, False))
        self.assertEqual(steps[3]['result']['status'], 'still-reviving')
        self.assertEqual(steps[3]['state']['rolls'], given['state']['rolls'])
        failed = steps[5]
        self.assertEqual(failed['result'], {'ok': False, 'status': 'box-full'})
        self.assertEqual(self.flags(failed), (True, False, True))
        self.assertEqual(failed['state']['counts'][self.amber['species']], 0)
        self.assertFalse(failed['state']['owned'][self.amber['species']])
        self.assertEqual(failed['state']['party'], 6)
        self.assertEqual(failed['state']['box'], 20)
        self.assertEqual(failed['state']['rolls'], steps[4]['state']['rolls'])
        self.assertEqual(failed['state']['pending'], {'item': self.amber['item'], 'species': self.amber['species']})
        retried = steps[7]
        self.assertEqual(retried['result']['status'], 'revived')
        self.assertEqual(retried['result']['destination'], 'storage')
        self.assertEqual(retried['result']['box'], 2)
        self.assertEqual(retried['result']['species'], self.amber['species'])
        self.assertEqual(retried['result']['level'], self.revival['level'])
        self.assertEqual(self.flags(retried), (False, False, False))
        self.assertEqual(retried['state']['counts'][self.amber['species']], 1)
        self.assertTrue(retried['state']['owned'][self.amber['species']])
        self.assertEqual(steps[8]['result']['status'], 'no-fossils')
        self.assertEqual(steps[8]['state']['counts'][self.amber['species']], 1)

    def test_a_full_party_with_box_room_uses_ordinary_acquisition(self):
        revived = self.scenario('party-full')[4]
        self.assertEqual(revived['result']['status'], 'revived')
        self.assertEqual(revived['result']['destination'], 'storage')
        self.assertEqual(revived['result']['box'], 1)
        self.assertEqual(revived['result']['species'], self.helix['species'])
        self.assertEqual(revived['result']['level'], self.revival['level'])
        self.assertEqual(self.flags(revived), (False, False, False))
        self.assertEqual(revived['state']['party'], 6)
        self.assertEqual(revived['state']['counts'][self.helix['species']], 1)

    def choice_ids(self, item, species):
        return [f'wFossilItem:{item}', f'wFossilMon:{species}']

    def test_a_declined_choice_survives_codec_bytes(self):
        steps = self.scenario('continue-declined')
        chosen = steps[1]
        self.assertEqual(chosen['state']['pending'], {'item': self.dome['item'], 'species': self.dome['species']})
        self.assertEqual(self.flags(chosen), (False, False, False))
        continued = steps[2]
        self.assertEqual(continued['result']['status'], 'continued')
        self.assertEqual(continued['result']['codec'], 5)
        self.assertNotEqual(continued['state']['process'], chosen['state']['process'])
        self.assertEqual(continued['state']['pending'], chosen['state']['pending'])
        self.assertEqual(continued['state']['choice'], self.choice_ids(self.dome['item'], self.dome['species']))
        self.assertEqual(self.flags(continued), (False, False, False))
        self.assertEqual(continued['state']['items'][self.dome['item']], 1)
        self.assertEqual(continued['state']['counts'][self.dome['species']], 0)
        for flag in self.choice_ids(self.dome['item'], self.dome['species']):
            self.assertIn(f'"{flag}":true', continued['result']['bytes'])

    def test_the_given_fossil_revives_from_a_second_session(self):
        steps = self.scenario('continue-choice')
        given = steps[1]
        self.assertEqual(given['result']['status'], 'reviving')
        self.assertEqual(given['state']['items'][self.dome['item']], 0)
        continued = steps[2]
        self.assertEqual(continued['result']['status'], 'continued')
        self.assertEqual(continued['result']['codec'], 5)
        self.assertNotEqual(continued['state']['process'], given['state']['process'])
        self.assertEqual(continued['state']['pending'], {'item': self.dome['item'], 'species': self.dome['species']})
        self.assertEqual(continued['state']['choice'], self.choice_ids(self.dome['item'], self.dome['species']))
        self.assertEqual(self.flags(continued), (True, True, False))
        self.assertEqual(continued['state']['counts'][self.dome['species']], 0)
        for flag in self.choice_ids(self.dome['item'], self.dome['species']):
            self.assertIn(f'"{flag}":true', continued['result']['bytes'])
        self.assertEqual(steps[3]['result']['status'], 'ignored')
        self.assertEqual(steps[4]['result']['status'], 'cleared')
        revived = steps[5]
        self.assertEqual(revived['result']['status'], 'revived')
        self.assertEqual(revived['result']['destination'], 'party')
        self.assertEqual(revived['result']['species'], self.dome['species'])
        self.assertEqual(revived['result']['level'], self.revival['level'])
        self.assertEqual(revived['state']['counts'][self.dome['species']], 1)
        self.assertTrue(revived['state']['owned'][self.dome['species']])
        self.assertEqual(revived['state']['choice'], [])
        self.assertIsNone(revived['state']['pending'])
        self.assertEqual(self.flags(revived), (False, False, False))
        self.assertEqual(steps[6]['result']['status'], 'no-fossils')
        self.assertEqual(steps[6]['state']['counts'][self.dome['species']], 1)

    def test_full_party_and_current_box_fail_atomically_across_continue(self):
        steps = self.scenario('continue-box-full')
        given = steps[2]
        self.assertEqual(given['result']['status'], 'reviving')
        self.assertEqual(given['state']['party'], 6)
        self.assertEqual(given['state']['box'], 20)
        self.assertEqual(steps[3]['result']['status'], 'still-reviving')
        failed = steps[5]
        self.assertEqual(failed['result'], {'ok': False, 'status': 'box-full'})
        self.assertEqual(self.flags(failed), (True, False, True))
        self.assertEqual(failed['state']['counts'][self.amber['species']], 0)
        self.assertFalse(failed['state']['owned'][self.amber['species']])
        self.assertEqual(failed['state']['party'], 6)
        self.assertEqual(failed['state']['box'], 20)
        self.assertEqual(failed['state']['rolls'], steps[4]['state']['rolls'])
        self.assertEqual(failed['state']['pending'], {'item': self.amber['item'], 'species': self.amber['species']})
        continued = steps[6]
        ids = self.choice_ids(self.amber['item'], self.amber['species'])
        self.assertEqual(continued['result']['status'], 'continued')
        self.assertEqual(continued['result']['codec'], 5)
        self.assertNotEqual(continued['state']['process'], failed['state']['process'])
        self.assertEqual(continued['state']['party'], 6)
        self.assertEqual(continued['state']['box'], 20)
        self.assertEqual(continued['state']['boxIndex'], 1)
        self.assertEqual(continued['state']['pending'], failed['state']['pending'])
        self.assertEqual(continued['state']['choice'], ids)
        self.assertEqual(self.flags(continued), (True, False, True))
        self.assertEqual(continued['state']['counts'][self.amber['species']], 0)
        self.assertIn(f'"{self.handing}":true', continued['result']['bytes'])
        for flag in ids:
            self.assertIn(f'"{flag}":true', continued['result']['bytes'])
        again = steps[7]
        self.assertEqual(again['result'], {'ok': False, 'status': 'box-full'})
        self.assertEqual(self.flags(again), (True, False, True))
        self.assertEqual(again['state']['counts'][self.amber['species']], 0)
        self.assertFalse(again['state']['owned'][self.amber['species']])
        self.assertEqual(again['state']['party'], 6)
        self.assertEqual(again['state']['box'], 20)
        self.assertEqual(again['state']['rolls'], failed['state']['rolls'])
        self.assertEqual(again['state']['pending'], failed['state']['pending'])
        revived = steps[9]
        self.assertEqual(revived['result']['status'], 'revived')
        self.assertEqual(revived['result']['destination'], 'storage')
        self.assertEqual(revived['result']['box'], 2)
        self.assertEqual(revived['result']['species'], self.amber['species'])
        self.assertEqual(revived['result']['level'], self.revival['level'])
        self.assertEqual(revived['state']['counts'][self.amber['species']], 1)
        self.assertTrue(revived['state']['owned'][self.amber['species']])
        self.assertEqual(self.flags(revived), (False, False, False))
        self.assertEqual(revived['state']['choice'], [])
        self.assertIsNone(revived['state']['pending'])
        saved = steps[10]
        self.assertEqual(saved['result']['status'], 'continued')
        self.assertNotEqual(saved['state']['process'], revived['state']['process'])
        self.assertEqual(saved['state']['counts'][self.amber['species']], 1)
        self.assertIsNone(saved['state']['pending'])
        self.assertEqual(saved['state']['choice'], [])
        for flag in ids:
            self.assertNotIn(f'"{flag}":true', saved['result']['bytes'])
        self.assertEqual(steps[11]['result']['status'], 'no-fossils')
        self.assertEqual(steps[11]['state']['counts'][self.amber['species']], 1)

    def test_species_and_level_come_from_the_generator_table(self):
        revived = self.scenario('follows-table')[3]
        chosen = self.patched['results'][0]
        self.assertNotEqual(chosen['species'], self.dome['species'])
        self.assertNotEqual(self.patched['level'], self.revival['level'])
        self.assertEqual(revived['result']['status'], 'revived')
        self.assertEqual(revived['result']['species'], chosen['species'])
        self.assertEqual(revived['result']['level'], self.patched['level'])
        self.assertEqual(revived['state']['counts'][chosen['species']], 1)
        self.assertNotIn(self.dome['species'], revived['state']['counts'])


if __name__ == '__main__':
    unittest.main()
