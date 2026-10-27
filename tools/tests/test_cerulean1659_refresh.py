"""Live coverage requires scoped actual successes and reviewed Source drift."""
import hashlib
import json
import unittest

from tools.harness.run import fingerprint
from tools.verify_moves.parse_lua import ROOT, read_moves
from tools.verify_moves.runtime_coverage import load_runtime_coverage, region


def read(path):
    return json.loads((ROOT / path).read_text())


class CeruleanCoverageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registry = read('tools/references/runtime-move-coverage.json')
        cls.prior = read('tools/references/runtime-move-coverage-candidate1274.json')
        cls.summary = read(cls.registry['accepted_summary']['path'])
        cls.projection = read(cls.registry['sdk_result']['path'])

    def test_current_source_and_actual_complete_inventory_are_bound(self):
        summary, projection = self.summary, self.projection
        self.assertEqual(fingerprint(ROOT), summary['source_sha256'])
        self.assertEqual(summary['candidate_commit'], 'b1f0bd8d19c857dc78c10648acd495a3cfdcd3be')
        self.assertEqual(summary['source_sha256'], '3fab65f913a2963e136e6f9c51123da9dd9a78822d859a376eca9a67a0cd9320')
        self.assertEqual(summary['raw_provenance'], projection['raw_provenance'])
        self.assertEqual(summary['raw_provenance']['sha256'], '814d4737855b85625a9055be7e06709e5e3e9dff2cd6fc385bdcd16d79f6234a')
        self.assertEqual(summary['raw_provenance']['size_bytes'], 2597103)
        self.assertEqual(projection['evidence_format'], 'contracts-projection-v1')
        self.assertFalse(projection['quiescent'])
        report = projection['results'][0]['contracts']
        self.assertEqual((report['passed'], report['failed'], len(report['tests'])), (1659, 0, 1659))
        self.assertEqual(len({test['name'] for test in report['tests']}), 1659)
        self.assertTrue(all(test['ok'] is True for test in report['tests']))
        self.assertEqual(len(report['suites']), 103)
        self.assertEqual(sum(suite['passed'] for suite in report['suites']), 1639)
        self.assertTrue(all(suite['ok'] is True and suite['failed'] == 0 for suite in report['suites']))
        for key in ('build_id', 'session_id'):
            self.assertEqual(projection[key], summary[key])
        proof = summary['identity_proof']
        self.assertEqual(proof['source_git_tree'], proof['native_source_git_tree'])
        self.assertEqual(proof['original_manifest_files'], 634)
        self.assertEqual(proof['reconstructed_original_source_sha256'], summary['source_sha256'])
        self.assertTrue(proof['all_original_file_hashes_match'])
        self.assertTrue(proof['compiled_staged_tree_matches'])

    def test_original50_scopes_and_all_ten_unverified_records_are_preserved(self):
        current, prior = self.registry['moves'], self.prior['moves']
        self.assertEqual(set(current), set(prior))
        self.assertEqual(len(current), 50)
        for key, old in prior.items():
            for field in ('scope', 'state', 'capabilities', 'definition_sha256', 'tests'):
                self.assertEqual(current[key][field], old[field], (key, field))
        stale = set(self.summary['unverified_left_stale'])
        self.assertEqual(len(stale), 10)
        for key in stale:
            self.assertEqual(current[key], prior[key], key)
        context = load_runtime_coverage(ROOT, read_moves())
        self.assertEqual({key for key, entry in context.items() if entry['state'] == 'stale'}, stale)

    def test_only_nine_explicitly_reviewed_owner_selections_changed(self):
        reviews = {(r['path'], r['selector']): r for r in self.summary['reviewed_owner_refresh']}
        self.assertEqual(len(reviews), 9)
        changed = set()
        for key, old in self.prior['moves'].items():
            current = self.registry['moves'][key]
            self.assertEqual(len(old['owners']), len(current['owners']))
            for before, after in zip(old['owners'], current['owners']):
                if before == after:
                    continue
                self.assertEqual({k: v for k, v in before.items() if k != 'sha256'},
                                 {k: v for k, v in after.items() if k != 'sha256'})
                selection = (after['path'], after.get('start'))
                review = reviews[selection]
                changed.add(selection)
                self.assertIn(key, review['moves'])
                self.assertEqual(before['sha256'], review['before_sha256'])
                self.assertEqual(after['sha256'], review['after_sha256'])
                self.assertEqual(hashlib.sha256(region(ROOT, after).encode()).hexdigest(), after['sha256'])
                self.assertTrue(review['review'])
        self.assertEqual(changed, set(reviews))

    def test_supplemental_ability_field_assertions_have_exact_bodies_and_actual_success(self):
        canonical = {t['name']: t for t in self.projection['results'][0]['contracts']['tests']}
        summary = self.summary
        for path, digest in summary['source_guards'].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
        assertions = summary['supplemental_assertions'] + summary['field_assertions']
        for ability in summary['ability_scopes']:
            assertions += ability['tests']
            self.assertIn('unverified', ability['scope'])
        self.assertEqual(len(summary['ability_scopes']), 25)
        for proof in assertions:
            self.assertEqual(proof['executed'], canonical[proof['name']])
            self.assertTrue(proof['executed']['ok'])
            self.assertEqual(hashlib.sha256(region(ROOT, proof).encode()).hexdigest(), proof['sha256'], proof['name'])
        for review in summary['reviewed_owner_refresh']:
            self.assertTrue(review['tests'])
            self.assertTrue(review['supplemental_tests'])
            self.assertTrue(all(canonical[name]['ok'] is True
                                for name in review['tests'] + review['supplemental_tests']))

    def test_matrix_keeps_all_rows_layers_and_main_candidate_boundary(self):
        matrix = read('docs/validation/coverage-current.json')
        self.assertEqual(len(matrix['rows']), 1501)
        self.assertEqual(matrix['accepted_milestone_rows'], [])
        self.assertEqual(matrix['snapshot']['acceptance_context'], 'private-cerulean-candidate-not-main-or-milestone')
        self.assertEqual(matrix['snapshot']['source_sha256'], self.summary['source_sha256'])
        self.assertEqual(self.summary['accepted_main']['commit'], '27443af')
        self.assertNotEqual(self.summary['accepted_main']['source_sha256'], matrix['snapshot']['source_sha256'])
        for row in matrix['rows']:
            for facet in ('campaign_path', 'regional_fidelity', 'full_mechanics'):
                self.assertNotEqual(row[facet]['verification'], 'accepted_milestone')
            if row['kind'] == 'ability' and row['source']['native_id'] in {a['id'] for a in self.summary['ability_scopes']}:
                self.assertEqual(row['full_mechanics']['implementation'], 'partial')
                self.assertEqual(row['full_mechanics']['verification'], 'sdk_scoped')
                self.assertNotEqual(row['campaign_path']['verification'], 'sdk_scoped')

    def test_foundation_history_remains_byte_exact(self):
        expected = {
            'tools/references/runtime-move-coverage-candidate1274.json': '6ade4dc051440d3363f7cfe8bf5e0b5cb17dbbcec8a67d9c38ea099050d8e8e9',
            'docs/validation/coverage-evidence/candidate1274-contracts-projection.json': '9fb1ec609e2f740df6dc1c7877093dce6c16284c49182f145ea40f019aa09d23',
            'docs/validation/coverage-evidence/candidate1274-summary.json': '770bd3a97495225fce365c048d38162f69865f4001de93a68c7c822ba97dbb2c',
        }
        for path, digest in expected.items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest, path)
