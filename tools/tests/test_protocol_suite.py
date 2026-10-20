import argparse
import importlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.harness.protocol import ProtocolError, atomic_json

suite = importlib.import_module('tools.harness.suite')


class SuiteTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def args(self, **options):
        values = dict(output=str(self.root / 'suite'), only=['smoke', 'qualification'],
                      mutations=False, plan_only=False, continue_on_failure=False,
                      job_timeout=1, sdk=None)
        return argparse.Namespace(**(values | options))

    def test_selection_preserves_requested_order_and_rejects_unknown(self):
        self.assertEqual([job['name'] for job in suite.select_jobs(['qualification,smoke'])], ['qualification', 'smoke'])
        with self.assertRaisesRegex(ProtocolError, 'unknown case'):
            suite.select_jobs(['missing'])
        with self.assertRaisesRegex(ProtocolError, 'duplicate'):
            suite.select_jobs(['smoke', 'smoke'])
        with self.assertRaisesRegex(ProtocolError, 'requires --mutations'):
            suite.select_jobs(['mutations'])
        self.assertTrue(suite.select_jobs(['mutations'], mutations=True)[0]['mutations'])

    def test_plan_only_never_launches_or_claims_success(self):
        def forbidden(*args):
            self.fail('plan launched a process')
        self.assertEqual(suite.execute_suite(self.args(plan_only=True), launch=forbidden), 0)
        report = json.loads((self.root / 'suite/suite.json').read_text())
        self.assertFalse(report['ok'])
        self.assertFalse(report['complete'])
        self.assertTrue((self.root / 'suite/inputs/smoke.json').is_file())

    def test_abort_marks_remaining_not_run(self):
        calls = []
        def failed(command, wrapper, timeout):
            calls.append(command)
            return {'returncode': 1, 'timed_out': False, 'elapsed_seconds': .1}
        with patch.object(suite, 'suite_lock_path', return_value=self.root / 'suite.lock'):
            self.assertEqual(suite.execute_suite(self.args(), launch=failed), 1)
        report = json.loads((self.root / 'suite/suite.json').read_text())
        self.assertEqual(len(calls), 1)
        self.assertEqual(report['not_run'], ['qualification'])
        self.assertFalse(report['ok'])
        self.assertFalse(report['complete'])

    def test_continue_explicitly_runs_remaining_and_still_fails(self):
        calls = []
        def failed(command, wrapper, timeout):
            calls.append(command)
            return {'returncode': 1, 'timed_out': False, 'elapsed_seconds': .1}
        with patch.object(suite, 'suite_lock_path', return_value=self.root / 'suite.lock'):
            self.assertEqual(suite.execute_suite(self.args(continue_on_failure=True), launch=failed), 1)
        report = json.loads((self.root / 'suite/suite.json').read_text())
        self.assertEqual(len(calls), 2)
        self.assertTrue(report['complete'])
        self.assertFalse(report['ok'])
        self.assertEqual(report['not_run'], [])

    def test_contract_report_ignores_stale_archive_and_final_quiesce(self):
        destination = self.root / 'contracts'
        (destination / 'Source').mkdir(parents=True)
        (destination / 'Source/main.lua').write_text('compiled source')
        atomic_json(destination / 'outcome.json', {'ok': True})
        atomic_json(destination / 'catalog.json', {'images':[{'path':'asset.png'}], 'missing':[]})
        atomic_json(destination / 'build.json', {'build_id':'revision:hash','session_id':'session',
                    'compiled_source_sha256':suite.fingerprint(destination, exclude_generated=False)})
        report = {'ok':True,'passed':20,'failed':0}
        contracts = {'results':[{'contracts':report}]}
        atomic_json(destination / '00001-result.json', contracts)
        atomic_json(destination / 'stale-result.json', contracts)
        atomic_json(destination / '00002-result.json', {'results':[{'op':'quiesce'}], 'quiescent':True})
        item = suite.inspect_job({'name':'contracts-catalog'},destination,{'returncode':0,'timed_out':False})
        self.assertTrue(item['ok'],item.get('error'))
        self.assertEqual(item['contracts']['passed'],20)

    def test_compiled_staging_mismatch_fails_inspection(self):
        destination = self.root / 'job'
        (destination / 'Source').mkdir(parents=True)
        (destination / 'Source/main.lua').write_text('compiled source')
        atomic_json(destination / 'outcome.json', {'ok': True})
        atomic_json(destination / 'build.json', {'build_id': 'rev:hash', 'session_id': 'session',
                    'compiled_source_sha256': 'stale'})
        report = suite.inspect_job({'name': 'smoke'}, destination, {'returncode': 0, 'timed_out': False})
        self.assertFalse(report['ok'])
        self.assertIn('fingerprint mismatch', report['error'])


if __name__ == '__main__':
    unittest.main()
