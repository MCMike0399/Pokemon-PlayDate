"""Contract sessions must not keep the shared compact catalogue resident.

pret/pokered af519899 is the map source. The harness registers the Pewter,
Cerulean, Vermilion and midgame catalog exporters at boot. Each membership
walk calls SourceMaps._sharedCompact(), which retains compact.json. A
contracts source-maps session never draws the catalog, so that catalogue
stays beside every Zone and the first Route 2 decode raises "not enough
memory". Fixture scopes replace a map key (fixture_Route22) while the lazy
provider still reads the shipped entry file, so the entry no longer matches
the manifest.

These checks fail until the registration releases the compact and a lazy
load prefers the active compact.
"""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class SourceMapContractMemoryTests(unittest.TestCase):
    def test_catalog_registration_releases_the_shared_compact(self):
        text = (ROOT / "tools/harness/dev_imports.lua").read_text(encoding="utf-8")
        pewter = text.index("PewterCatalogExporter.register()")
        cerulean = text.index("CeruleanCatalogExporter.register()")
        first = text.index("SourceMaps._releaseSharedCompact()", cerulean)
        self.assertLess(pewter, cerulean)
        self.assertLess(cerulean, first)
        self.assertIn('collectgarbage("collect")', text[first:first + 180])
        vermilion = text.index("VermilionCatalogExporter.register()")
        midgame = text.index("MidgameCatalogExporter.register()")
        second = text.index("SourceMaps._releaseSharedCompact()", midgame)
        self.assertLess(vermilion, midgame)
        self.assertLess(midgame, second)
        self.assertIn('collectgarbage("collect")', text[second:second + 180])

    def test_lazy_load_prefers_the_active_compact_over_the_shipped_entry(self):
        imported = (ROOT / "Source/world/importedMaps.lua").read_text(encoding="utf-8")
        load = imported[imported.index("local function loadHeavy"):imported.index("local function dropHeavy")]
        active = load.index("_activeCompactMap")
        shipped = load.index('entry-"')
        self.assertLess(active, shipped)
        maps = (ROOT / "Source/world/sourceMaps.lua").read_text(encoding="utf-8")
        body = maps[maps.index("function SourceMaps._activeCompactMap"):maps.index("function SourceMaps._releaseSharedCompact")]
        self.assertIn("if not compact then return nil end", body)
        self.assertIn("compact.maps[name]", body)
        self.assertNotIn("compactData", body)

    def test_selected_suite_drops_the_other_contract_closures(self):
        text = (ROOT / "Source/dev/contracts.lua").read_text(encoding="utf-8")
        run = text[text.index("function Contracts.run"):text.index("function Contracts.", text.index("function Contracts.run") + 1)]
        call = run.index("Contracts.releaseUnselected(only)")
        invoke = run.index("suite.run")
        self.assertLess(call, invoke)
        body = text[text.index("function Contracts.releaseUnselected"):text.index("function Contracts.run")]
        self.assertIn("string.dump", body)
        self.assertIn("suite.run = nil", body)
        self.assertIn("_G[key] = nil", body)


if __name__ == "__main__":
    unittest.main()
