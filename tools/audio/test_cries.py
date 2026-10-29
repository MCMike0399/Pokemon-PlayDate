"""Host checks for shared cry data; native playback remains root-owned."""
import hashlib
import json
import os
from pathlib import Path
import re
import unittest

from tools.audio.catalog import Catalog
from tools.audio.cries import ROOT, expand, generate
from tools.audio.scores import ScoreTrace
from tools.audio.source import Source


class CryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog = Catalog(Source(os.environ['POKERED_REFERENCE_DIR']))
        cls.manifest = json.loads((ROOT/'tools/audio/cry-manifest.json').read_text())

    def test_all_species_and_bank_parameters_match_source_trace(self):
        manifest = self.manifest
        self.assertEqual(len(manifest['species']), 151)
        self.assertEqual(len(manifest['headers']), 114)
        self.assertEqual(len(manifest['programs']), 38)
        for row in self.catalog.cries:
            self.assertEqual(manifest['species'][row['species']], [row['base'], row['pitch'], row['length']])
            for family, asset in row['assets'].items():
                with self.subTest(species=row['species'], asset=asset):
                    trace = ScoreTrace(self.catalog, int(family))
                    trace.load(asset, row['pitch'], row['length'])
                    result = trace.run()
                    index = manifest['headers'][asset]
                    program = {int(k): v for k, v in manifest['programs'][index-1].items()}
                    score = expand(program, row['pitch'], row['length'])
                    self.assertEqual(result['status'], 'ended')
                    self.assertEqual(score['ticks'], result['ticks'])
                    self.assertEqual(score['notes'], trace.notes)
                    releases = {e['voice']: e['tick'] for e in trace.events
                                if e['kind'] == 'ownership' and e.get('asset') is None}
                    self.assertEqual(score['holds'], [releases[i] for i in (1, 2, 3, 4)])

    def test_species_keys_cover_the_game_without_domain_dependencies(self):
        text = (ROOT/'Source/data/pokemon.lua').read_text()
        keys = re.findall(r'^    (\w+) = \{\n        name = .*?dex = (\d+),', text, re.M)
        self.assertEqual(len(keys), 151)
        by_dex = {r['dex_id']: r['species'] for r in self.catalog.cries}
        aliases = {'nidoranF': 'nidoran_f', 'nidoranM': 'nidoran_m', 'mr': 'mr_mime'}
        for key, dex in keys:
            self.assertEqual(aliases.get(key, key), by_dex[int(dex)])

    def test_generated_assets_and_source_checksums_reproduce(self):
        for name, data in generate(os.environ['POKERED_REFERENCE_DIR']).items():
            self.assertEqual((ROOT/name).read_bytes(), data, name)
        self.assertEqual(self.manifest['unavailable'], [])
        self.assertEqual(self.manifest['checked_combinations'], 453)
        for name, digest in self.manifest['inputs_sha256'].items():
            self.assertEqual(hashlib.sha256(self.catalog.source.read(name).encode()).hexdigest(), digest)


if __name__ == '__main__':
    unittest.main()
