"""Every source-profile actor uses an imported pokered strip, not a placeholder."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'Source'
PACKAGES = (
    'data/sourceSlice/',
    'data/vermilionPreparation/',
    'data/midgameEast/',
    'data/midgameSouth/',
    'data/midgameSaffron/',
)
EXTRA = (
    'data/zEndgame/sprites.json',
    'data/zRemainder/sprites.json',
)
# These eight are absent from the registered content packages. They already
# exist in the importer output for zEndgame and zRemainder.
REQUIRED = {
    'SPRITE_AGATHA', 'SPRITE_BRUNO', 'SPRITE_LANCE', 'SPRITE_LORELEI', 'SPRITE_OAK',
    'SPRITE_DAISY', 'SPRITE_MOM', 'SPRITE_RED',
}


def load(path):
    return json.loads((SOURCE / path).read_text())


class ImportedActorStripTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.registered = {}
        for root in PACKAGES:
            for name, strip in load(root + 'sprites.json')['sprites'].items():
                cls.registered.setdefault(name, strip)
        cls.extra = {}
        for path in EXTRA:
            data = load(path)
            if data['schema'] != 1 or data['source_revision'] != 'af519899719f0754965776faac0e836a3b906e6d':
                raise AssertionError('unverified imported sprite catalog: ' + path)
            for name, strip in data['sprites'].items():
                previous = cls.extra.get(name)
                if previous is not None and previous != strip:
                    raise AssertionError('conflicting imported sprite strip: ' + name)
                cls.extra[name] = strip
        cls.maps = load('data/sourceMaps.json')['maps']

    def test_required_strips_come_from_the_importer_catalogs(self):
        for name in REQUIRED:
            self.assertNotIn(name, self.registered, name)
            self.assertIn(name, self.extra, name)
            strip = self.extra[name]
            self.assertIn('standing', strip)
            self.assertIn('frames', strip)
            for direction, index in strip['standing'].items():
                self.assertIn(str(index), strip['frames'], name + ' ' + direction)

    def test_every_source_map_actor_has_an_imported_strip(self):
        missing = []
        for name, meta in sorted(self.maps.items()):
            if meta['profile'] != 'source':
                continue
            definition = load(meta['path'])
            for event in definition['events']['objects']:
                sprite = event['sprite']
                if sprite not in self.registered and sprite not in self.extra:
                    missing.append(f'{name} {sprite}')
        self.assertEqual(missing, [])

    def test_runtime_lookup_names_both_imported_catalogs(self):
        text = (SOURCE / 'data/ceruleanContent.lua').read_text()
        for path in EXTRA:
            self.assertIn(path, text)
