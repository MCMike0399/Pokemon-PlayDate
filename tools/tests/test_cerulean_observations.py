"""Host generator/transport checks. No SDK substitutes or Lua evaluation."""
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock

from tools.generate_cerulean_journey import project
from tools.harness import cerulean_journey as journey
from tools.harness.protocol import ProtocolError

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source'


def check_native_witness(output):
    """Consume root-owned real SDK evidence; never launch a runtime here."""
    output = Path(output)
    run = json.loads((output / 'run.json').read_text())
    outcome = json.loads((output / 'outcome.json').read_text())
    processes = run['processes']
    if outcome.get('ok') is not True or len(processes) != 2 or processes[0]['pid'] == processes[1]['pid']:
        raise ProtocolError('native witness requires two successful actual processes')
    boundaries = []
    for process, kind in zip(processes, ('saved', 'loaded')):
        if process['status'] != 'exited' or not process['fresh_ready'] or not process['previous_exit_confirmed']:
            raise ProtocolError('native witness lacks confirmed restart lifecycle')
        found, purities = [], 0
        for path in sorted((output / process['evidence']).glob('[0-9][0-9][0-9][0-9][0-9]-result.json')):
            packet = json.loads(path.read_text())
            if packet.get('build_id') != run['build_id'] or packet.get('session_id') != run['session_id'] or packet.get('status') != 'ok':
                raise ProtocolError('native witness result identity/status mismatch')
            for row in packet['results']:
                if 'session_codec' in row.get('snapshot', {}):
                    raise ProtocolError('codec payload leaked into ordinary snapshots')
                observation = row.get('observation', {})
                if observation.get('kind') in {'validate', 'purity', 'owners'} and 'payload' in observation:
                    raise ProtocolError('nonboundary query published a complete payload')
                if observation.get('kind') == 'purity' and observation.get('valid') is True:
                    purities += 1
                if observation.get('kind') == kind:
                    if observation.get('valid') is not True or observation.get('roundtrip_equal') is not True:
                        raise ProtocolError('native boundary failed canonical validation')
                    journey.validate_boundary_payload(observation['payload'])
                    found.append(observation['payload'])
        if len(found) != 1 or purities < 1:
            raise ProtocolError('native witness missing unique boundary or SDK purity assertion')
        boundaries.append(found[0])
    if boundaries[0] != boundaries[1]:
        raise ProtocolError('complete actual Save/Continue payload differs across processes')
    return True


class ProjectionTests(unittest.TestCase):
    def test_deterministic_projection_matches_consumed_source_bytes(self):
        actual = project(SOURCE)
        self.assertEqual(actual, project(SOURCE))
        self.assertEqual(actual, json.loads((SOURCE / 'data/ceruleanJourney.json').read_text()))
        self.assertEqual(actual['bill_pc_player']['y'], 5)
        self.assertEqual(actual['session_codec'], 1)
        for path, digest in actual['sources'].items():
            self.assertEqual(hashlib.sha256((SOURCE / path).read_bytes()).hexdigest(), digest)
        self.assertEqual(len(actual['rivals']), 2)
        inputs = json.loads((SOURCE / 'data/sourceSlice/trainers.json').read_text())
        scenes = json.loads((SOURCE / 'data/ceruleanRoutes/scenes.json').read_text())
        for scene in scenes['rivals'].values():
            for starter, rival in {'charmander': 'squirtle', 'squirtle': 'bulbasaur', 'bulbasaur': 'charmander'}.items():
                team = actual['rivals'][scene['id']][starter]
                roster = inputs['rival_classes'][scene['class']]
                expected = roster['parties'][scene['roster_by_rival_starter'][rival] - 1]['party']
                self.assertEqual(team['party'], expected)  # includes source metadata
                self.assertEqual(team['payout'], roster['base_money'] * expected[-1]['level'])

    def test_final_manifest_regeneration_and_check_fail_on_drift(self):
        original = project(SOURCE)
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'Source'
            for relative in original['sources']:
                target = source / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(SOURCE / relative, target)
            manifest_path = source / 'data/sourceMaps.json'
            manifest = json.loads(manifest_path.read_text())
            # The maps are installed in the common manifest. A real metadata
            # change must invalidate the observed owner projection as well.
            self.assertNotEqual(manifest['maps']['BillsHouse']['spawn']['facing'], 'left')
            manifest['maps']['BillsHouse']['spawn']['facing'] = 'left'
            manifest_path.write_text(json.dumps(manifest))
            updated = project(source)
            self.assertEqual(updated['trainers'], original['trainers'])
            self.assertNotEqual(updated['sources']['data/sourceMaps.json'], original['sources']['data/sourceMaps.json'])
            command = [sys.executable, str(ROOT / 'tools/generate_cerulean_journey.py'), '--source', str(source)]
            subprocess.run(command, check=True, capture_output=True)
            subprocess.run(command + ['--check'], check=True, capture_output=True)
            with (source / 'game/sourceEvents.lua').open('a') as handle:
                handle.write('\n-- changed registration input\n')
            result = subprocess.run(command + ['--check'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn(b'stale', result.stderr)


class ObservationTransportTests(unittest.TestCase):
    def test_explicit_response_is_not_retained_in_frame_state(self):
        client = Mock()
        response = {'kind': 'saved', 'payload': {'large': 'only in command response'}}
        client.send.return_value = {'snapshot': {'root': 'overworld'}, 'results': [
            {'op': 'observe', 'status': 'ok', 'observation': response}]}
        driver = journey.CeruleanJourney(client, '/unused', {'name': 'cerulean-natural'})
        self.assertEqual(driver.observe('saved'), response)
        self.assertEqual(driver.state, {'root': 'overworld'})
        client.send.assert_called_once_with([{'op': 'observe', 'args': ['saved']}], timeout=60, max_frames=1800)
        for malformed in ({}, {'results': []}, {'results': [{'op': 'observe', 'status': 'ok', 'observation': {'kind': 'loaded'}}]}):
            client.send.return_value = dict(snapshot={}, **malformed)
            with self.assertRaises(ProtocolError):
                driver.observe('saved')

    def test_no_receipt_from_idle_snapshot_or_partial_dto(self):
        driver = journey.CeruleanJourney(Mock(), '/unused', {'name': 'cerulean-natural'})
        driver.state = {'session_codec': {'payload': {'questFlags': {}}}}
        with self.assertRaises(ProtocolError):
            driver.receipt_state()
        for value in ({'questFlags': {}}, {'version': 1}, {'worldMotion': {}}):
            with self.assertRaises(ProtocolError):
                journey.validate_boundary_payload(value)

    def test_observations_share_semantic_budget(self):
        client = Mock()
        driver = journey.CeruleanJourney(client, '/unused', {'name': 'cerulean-natural', 'max_actions': 1})
        driver.actions = 1
        with self.assertRaises(ProtocolError):
            driver.observe('validate')
        client.send.assert_not_called()


if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--native-results':
        check_native_witness(sys.argv[2])
        print('Actual Save/Continue payload and SDK purity witness passed')
    else:
        unittest.main()
