"""Preserved 1274 foundation evidence remains separate from live Cerulean."""
import hashlib
import json
import unittest
from tools.verify_moves.parse_lua import ROOT, read_moves
from tools.verify_moves.runtime_coverage import load_runtime_coverage


class CurrentFoundationCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.current = json.loads((ROOT / 'tools/references/runtime-move-coverage-candidate1274.json').read_text())
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
        self.assertEqual(pin['raw_provenance']['sha256'], '249649b31f8d41ed4d67a9acba1d608ca6d52bf5136e8b6491cfa0592d16a966')
        self.assertEqual(pin['source_sha256'], '2673b352e62b8e145b8a7e19b055db47479bc4f4100caf6f2835137ee85fe079')
        self.assertTrue(pin['build_id'].startswith('58495ebbf67c2a49bb53293fc98d99b00bf136e8:'))
        report = projection['results'][0]['contracts']
        self.assertEqual((report['passed'], report['failed'], len(report['tests'])), (1274, 0, 1274))
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
        self.assertEqual(matrix['snapshot']['acceptance_context'], 'private-cerulean-candidate-not-main-or-milestone')
        for key in ('whirlwind', 'roar'):
            row = next(r for r in matrix['rows'] if r['id'] == 'move:' + key)
            self.assertEqual(row['full_mechanics']['verification'], 'sdk_scoped')
            self.assertEqual(row['campaign_path']['verification'], 'source_only')
            self.assertEqual(row['regional_fidelity']['verification'], 'unreviewed')

    def test_all50_move_records_are_unchanged_from1250(self):
        # Pin the complete prior reviewed set: no owner/assertion hashes or states rebound.
        self.assertEqual(hashlib.sha256(json.dumps(self.current['moves'], sort_keys=True,
                         separators=(',', ':')).encode()).hexdigest(), '5a90fa249dd9099a9f98963417a999ae3d3e0b60f1f2ae8df129541652edb6b6')

    def test_historical_packets_remain_byte_exact(self):
        expected = {'docs/validation/coverage-evidence/candidate1250-contracts-projection.json': '958e28ac9f34f8406fc1c100f58c5188c26d1ba5310f5f4a4b0cba68f62066b3', 'docs/validation/coverage-evidence/candidate1250-summary.json': '09215ebe8d621a600ee8462aff73fa3f78e3852a2095385ad1f2c06c38a772fb', 'docs/validation/coverage-evidence/current1091-result.json': '7be14560c490601b0057a5cbf98b415ad5a3e0cde33f9628d5735382f51a57a3', 'docs/validation/coverage-evidence/current1091-summary.json': '32f34c1e483168b8c5ef76f8a86d0fd32001d43657b140a327bceda738decf78'}
        for path, digest in expected.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)

    def test_final_qualifications_bind_same_native_packet_and_source(self):
        summary = json.loads((ROOT / self.current['accepted_summary']['path']).read_text())
        self.assertEqual(summary['maintenance_base_commit'], '9ed4d36f0ba0b13734f109435070eaa0486ed506')
        self.assertEqual(summary['candidate_commit'], '58495ebbf67c2a49bb53293fc98d99b00bf136e8')
        proof = summary['identity_proof']
        self.assertEqual(proof['source_git_tree'], proof['native_source_git_tree'])
        self.assertEqual(proof['original_manifest_files'], 569)
        self.assertEqual(proof['reviewed_move_records_unchanged_from1250'], 50)
        self.assertEqual(proof['owner_or_assertion_hashes_rebound'], 0)
        self.assertTrue(summary['outcome']['ok'])
        comparison = summary['catalog_comparison']['summary']
        self.assertTrue(comparison['comparison_ok'])
        self.assertEqual(comparison['protected_checked'], 2494)
        self.assertEqual(comparison['added_unreviewed'], [])
        for item in summary['artifact_qualifications'].values():
            qualified = item['qualification']
            self.assertTrue(qualified['ok'])
            self.assertTrue(qualified['quiescent'])
            for field in ('build_id', 'session_id', 'source_sha256', 'compiled_source_sha256'):
                self.assertEqual(qualified[field], summary[field])
            for executed in qualified['executions']:
                self.assertEqual(executed['result_sha256'], summary['raw_provenance']['sha256'])
        matrix = json.loads((ROOT / 'docs/validation/coverage-current.json').read_text())
        self.assertNotEqual(matrix['snapshot']['source_sha256'], summary['source_sha256'])
        self.assertEqual(matrix['evidence']['candidate1274']['sha256'], self.current['accepted_summary']['sha256'])
        self.assertEqual(matrix['evidence']['candidate1274']['kind'], 'historical')
