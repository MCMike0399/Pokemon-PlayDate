"""Live candidate evidence is separate from immutable 1091 history."""
import hashlib
import json
import unittest
from tools.harness.run import fingerprint
from tools.verify_moves.parse_lua import ROOT, read_moves
from tools.verify_moves.runtime_coverage import load_runtime_coverage


class Candidate1250RefreshTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.current = json.loads((ROOT / 'tools/references/runtime-move-coverage.json').read_text())
        cls.history = json.loads((ROOT / 'tools/references/runtime-move-coverage-current1091.json').read_text())

    def test_original48_scopes_preserved_and_only_reviewed_drift_rebound(self):
        current, history = self.current['moves'], self.history['moves']
        self.assertEqual(set(current) - set(history), {'whirlwind', 'roar'})
        for key, old in history.items():
            for field in ('scope', 'state', 'capabilities', 'definition_sha256'):
                self.assertEqual(current[key][field], old[field], (key, field))
        self.assertEqual({k for k in history if current[k]['owners'] != history[k]['owners']},
                         {'captivate', 'endeavor', 'ragePowder', 'suckerPunch'})
        self.assertEqual({k for k in history if current[k]['tests'] != history[k]['tests']}, {'assurance'})
        # The reviewed actor update changes only this assertion's body hash.
        for before, after in zip(history['assurance']['tests'], current['assurance']['tests']):
            self.assertEqual({k:v for k,v in before.items() if k != 'sha256'},
                             {k:v for k,v in after.items() if k != 'sha256'})

    def test_exact_unverified_stale_set_and_reviewed_scopes(self):
        context = load_runtime_coverage(ROOT, read_moves())
        self.assertEqual({k for k,v in context.items() if v['state'] == 'stale'},
                         {'dig', 'earthquake', 'explosion', 'furyCutter', 'gyroBall',
                          'heavySlam', 'magnitude', 'selfDestruct', 'smackDown', 'helpingHand'})
        for key in ('captivate', 'endeavor', 'ragePowder', 'suckerPunch', 'assurance', 'whirlwind', 'roar'):
            self.assertEqual(context[key]['state'], 'verified_subset', key)

    def test_candidate_identity_projection_and_complete_contract_inventory(self):
        pin = self.current['sdk_result']
        projection = json.loads((ROOT / pin['path']).read_text())
        self.assertEqual(projection['evidence_format'], 'contracts-projection-v1')
        self.assertEqual(projection['raw_provenance'], pin['raw_provenance'])
        self.assertEqual(pin['raw_provenance']['sha256'], '63890cf75a394d62342dd25a9fb7da39b62b45ce9c2b0bcd37b3aae1ab1e3231')
        self.assertEqual(pin['source_sha256'], fingerprint(ROOT))
        self.assertTrue(pin['build_id'].startswith('9cc65c4b1fed0d1e1bdace128ce2900bb571f4a5:'))
        report = projection['results'][0]['contracts']
        self.assertEqual((report['passed'], report['failed'], len(report['tests'])), (1250, 0, 1250))
        suites = {s['id']:s for s in report['suites']}
        self.assertEqual((suites['whirlwind']['passed'], suites['move-failure']['passed']), (27, 6))
        self.assertEqual(len(self.current['moves']['roar']['tests']), 3)
        self.assertEqual(len(self.current['moves']['whirlwind']['tests']), 27)
        # Whole-file guards bind shared test helpers as well as selected assertions.
        for key in ('whirlwind', 'roar'):
            proof = self.current['moves'][key]['owners'][-1]
            self.assertTrue(proof['whole_file'])
            self.assertEqual(proof['sha256'], hashlib.sha256((ROOT / proof['path']).read_bytes()).hexdigest())

    def test_matrix_retains_inventory_and_three_independent_layers(self):
        matrix = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertEqual(len(matrix['rows']), 1501)
        self.assertEqual(matrix['accepted_milestone_rows'], [])
        self.assertEqual(matrix['snapshot']['acceptance_context'], 'private-foundation-candidate-not-main-or-milestone')
        for key in ('whirlwind', 'roar'):
            row = next(r for r in matrix['rows'] if r['id'] == 'move:' + key)
            self.assertEqual(row['full_mechanics']['verification'], 'sdk_scoped')
            self.assertEqual(row['campaign_path']['verification'], 'source_only')
            self.assertEqual(row['regional_fidelity']['verification'], 'unreviewed')
