"""Qualification gates only: mocks here are never independent byte evidence."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tools.audio.catalog import Catalog
from tools.audio.oracle import main, qualify_bytes
from tools.audio.source import AudioError, Source


class OracleQualificationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        root = os.environ.get('POKERED_REFERENCE_DIR')
        if not root:
            raise RuntimeError('POKERED_REFERENCE_DIR required for oracle qualification tests')
        cls.catalog = Catalog(Source(root))

    def test_missing_tools_are_only_audit_evidence(self):
        with patch('tools.audio.oracle.shutil.which', return_value=None):
            report = qualify_bytes(self.catalog)
            self.assertFalse(report['independent_execution'])
            self.assertEqual(report['status'], 'audit-only')
            self.assertEqual(report['missing_tools'], ['rgbasm', 'rgblink'])
            self.assertEqual((report['macro_cases'], report['header_cases']), (22, 4))
            self.assertEqual(set(report['wave5']), {'1', '2', '3'})
            with self.assertRaisesRegex(AudioError, 'missing rgbasm, rgblink'):
                qualify_bytes(self.catalog, require_independent=True)

    def test_partial_install_cannot_claim_execution(self):
        with patch('tools.audio.oracle.shutil.which', side_effect=['/unused/rgbasm', None]):
            with self.assertRaisesRegex(AudioError, 'missing rgblink'):
                qualify_bytes(self.catalog, require_independent=True)

    def test_unpinned_version_fails_before_assembly(self):
        with patch('tools.audio.oracle.shutil.which', return_value='/unused/tool'), \
             patch('tools.audio.oracle.subprocess.check_output', return_value=b'rgbasm v0.9.4\n'):
            with self.assertRaisesRegex(AudioError, 'required v1.0.4'):
                qualify_bytes(self.catalog)

    def test_strict_cli_retains_blocked_report_and_audit_is_explicit(self):
        with tempfile.TemporaryDirectory() as tmp, \
             patch('tools.audio.oracle.shutil.which', return_value=None):
            output = Path(tmp)/'result.json'
            args = ['--source', str(self.catalog.source.root), '--output', str(output)]
            self.assertEqual(main(args), 2)
            report = json.loads(output.read_text())
            self.assertEqual(report['status'], 'blocked')
            self.assertFalse(report['independent_execution'])
            self.assertEqual(main(args+['--audit-only']), 0)
            self.assertEqual(json.loads(output.read_text())['status'], 'audit-only')
