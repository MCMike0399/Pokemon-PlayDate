#!/usr/bin/env python3
"""Emit the small API delta after the story candidate's common API patch.

Does not edit Source. Pass an explicit staged root containing the story patch.
"""
import argparse
import difflib
from pathlib import Path


def changes(root):
    result = {}
    path = 'Source/world/npcMotion.lua'
    old = (root / path).read_text()
    assert 'function NPCMotion:placeScript(token, x, y)' in old, 'apply story placement/rollback API first'
    new = old.replace('function NPCMotion:placeScript(token, x, y)',
                      'function NPCMotion:placeScript(token, x, y, facing)')
    needle = '    local v = actor.value\n    v.x,v.y = x,y\n'
    assert old.count(needle) == 1
    new = new.replace(needle, '''    if facing ~= nil and not actor.spec.faces[facing] then return false, "missing-source-actor-facing" end
    local v = actor.value
    v.x,v.y = x,y
    if facing then v.facing = facing end
''')
    result[path] = new
    path = 'Source/game/sourceEvents.lua'
    old = (root / path).read_text()
    needle = '        assert(Party._array(d.party, 6) and #d.party > 0, "bounded source trainer party required")\n'
    assert old.count(needle) == 1
    result[path] = old.replace(needle, '''        if d.rival_parties then
            local count = 0
            for starter, variant in pairs(d.rival_parties) do
                assert(starter == "charmander" or starter == "squirtle" or starter == "bulbasaur",
                    "unsupported session starter")
                assert(boundedInteger(variant.payout, 0, Inventory.MONEY_LIMIT)
                    and Party._array(variant.party, 6) and #variant.party > 0, "bounded rival variant required")
                for _, mon in ipairs(variant.party) do
                    assert(pokemonData[mon.species] and boundedInteger(mon.level, 1, 100), "unresolved rival party")
                end
                count = count + 1
            end
            assert(count == 3, "all three starter variants required")
        end
''' + needle)
    path = 'Source/game/battleState.lua'
    old = (root / path).read_text()
    needle = '        if not receipt or not receipt.won then return end\n'
    assert old.count(needle) == 1
    result[path] = old.replace(needle, '''        if not receipt then return end
        if not receipt.won then
            local descriptor = SourceEvents.descriptor(receipt.id)
            if descriptor and descriptor.lost then
                local lines = {}
                for _, page in ipairs(SourceEvents.pages(receipt.id,descriptor.lost)) do lines[#lines+1] = page.text end
                game.machine:push("dialog",lines)
            end
            return
        end
''')
    return result


def patch(root):
    result = ''.join(''.join(difflib.unified_diff((root / path).read_text().splitlines(True),
        content.splitlines(True), fromfile='a/' + path, tofile='b/' + path))
        for path, content in changes(root).items())
    return result.replace('\n \n', '\n\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.write_text(patch(args.root))


if __name__ == '__main__':
    main()
