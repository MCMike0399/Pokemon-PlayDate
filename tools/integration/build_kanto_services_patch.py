"""Write only the small root bootstrap/hooks patch; never mutate shared Source."""
import argparse
import difflib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def build(root=ROOT):
    changes = {}
    path = 'Source/main.lua'
    source = (root / path).read_text()
    updated = source.replace('import "game/ceruleanRoutesState"',
                             'import "game/ceruleanRoutesState"\nimport "game/kantoServices"')
    updated = updated.replace('game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})',
                              'KantoServices.install()\n\ngame = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})')
    updated = updated.replace('machine:register("event", CeruleanRoutesState(game))',
                              'machine:register("event", KantoServicesState(game))')
    assert updated != source
    changes[path] = updated
    path = 'Source/game/overworldState.lua'
    source = (root / path).read_text()
    updated = source.replace('if Story.check(game, self.owner) then return end',
                             'if Story.check(game, self.owner) then return end\n    if KantoServices.check(game) then return end')
    updated = updated.replace('    setupOverworld()\n    self.builtZone = currentZone',
                              '    setupOverworld()\n    assert(KantoServices.onMapEnter(game.session, currentZone.stableID))\n    self.builtZone = currentZone')
    assert updated != source
    changes[path] = updated
    path = 'tools/harness/dev_imports.lua'
    source = (root / path).read_text()
    updated = source.replace('-- @harness runtime',
                             'import "dev/kantoServicesContracts"\nContracts.register("kanto-services", KantoServicesContracts.run)\n\n-- @harness runtime')
    assert updated != source
    changes[path] = updated
    patch = ''.join(''.join(difflib.unified_diff((root / path).read_text().splitlines(True),
                                              updated.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
                   for path, updated in changes.items())
    # Git accepts empty context lines; avoid trailing spaces in this saved patch.
    return patch.replace('\n \n', '\n\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path, default=ROOT / 'tools/integration/kanto-services.patch')
    args = parser.parse_args()
    args.output.write_text(build(args.root))


if __name__ == '__main__':
    main()
