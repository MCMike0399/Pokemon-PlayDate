"""The move-proof re-run refuses a partial SDK result and leaves gap rows stale."""
import json
import unittest
from pathlib import Path

from tools.refresh_move_proofs import apply_refresh, bind_outputs, cited_suites
from tools.verify_moves.runtime_coverage import definition_hash, region
from tools.verify_moves.parse_lua import ROOT, read_moves


class RefreshMoveProofTests(unittest.TestCase):
    def test_cited_suites_follow_acceptance_prefixes(self):
        registry = json.loads((ROOT / 'tools/references/runtime-move-coverage.json').read_text())
        suites = cited_suites(registry)
        self.assertIn('bide', suites)
        self.assertIn('whirlwind', suites)
        self.assertEqual(len(suites), len(set(suites)))

    def test_partial_sdk_result_is_refused(self):
        registry = json.loads((ROOT / 'tools/references/runtime-move-coverage.json').read_text())
        with self.assertRaises(SystemExit):
            apply_refresh(registry, ROOT, {}, 'session:' + 'a' * 64, 'a' * 64)

    def test_verified_rows_take_current_hashes_and_gaps_stay(self):
        registry = json.loads((ROOT / 'tools/references/runtime-move-coverage.json').read_text())
        names = []
        for entry in registry['moves'].values():
            for proof in entry['tests']:
                names.append(proof['accepted_name'])
        passed = {name: True for name in names}
        moves = read_moves()
        source = 'b' * 64
        updated, evidence, summary = apply_refresh(
            registry, ROOT, passed, 'session:' + source, source)
        self.assertEqual(evidence['passed'], len(set(names)))
        self.assertIn('dig', summary['held_without_executed_proof'])
        self.assertIn('helpingHand', summary['held_without_executed_proof'])
        self.assertEqual(updated['moves']['dig']['owners'][0]['sha256'],
                         registry['moves']['dig']['owners'][0]['sha256'])
        solar = updated['moves']['solarBeam']
        self.assertEqual(solar['definition_sha256'], definition_hash(moves['solarBeam']))
        body = region(ROOT, solar['owners'][0])
        self.assertEqual(solar['owners'][0]['sha256'], __import__('hashlib').sha256(body.encode()).hexdigest())
        bound = bind_outputs(updated, json.dumps(evidence).encode(), json.dumps(summary).encode())
        self.assertEqual(bound['sdk_result']['suite_passed'], evidence['passed'])


if __name__ == '__main__':
    unittest.main()
