"""Compare moved startup bodies as text; never execute or transpile Lua.

Only the reviewed one-shot wrappers are normalized. The old source remains the
oracle for every render helper, grid, map body and ordered image expression.
"""
import hashlib

_LAYOUTS = {
    'Source/data/maps.lua': (
        '-- Zone registry tables',
        '-- ============================================================\n-- PALLET TOWN',
        '2d758127b3f138071945ed5b7bc3a7826f9879e619c197e3cc44cd9023df59f5', 6,
    ),
    'Source/world/spritefactory.lua': (
        '-- Player imports capture', '-- PLAYER (RED)\n',
        '9af9bc74df1caddbee42eabc85c8c0313cdf048a6b244fe238ed302b14262987', 7,
    ),
}


def canonical_startup_source(path, current):
    marker, old_marker, wrapper_hash, yields = _LAYOUTS[path]
    new = current.decode()
    if marker not in new:
        return current
    assert new.count(marker) == 1, path
    header, _ = new.split(marker, 1)
    guard = '        return\n    end\n\n'
    start = new.index(guard) + len(guard)
    assert hashlib.sha256(new[len(header):start].encode()).hexdigest() == wrapper_hash, path
    ending = '\n    initialized = true\nend\n'
    assert new.endswith(ending), path
    body = new[start:-len(ending)]
    assert body.count('GameBootstrap.yieldIfDue()') == yields, path
    body = ''.join(line[4:] if line.startswith('    ') else line
                   for line in body.splitlines(keepends=True)
                   if line.strip() != 'GameBootstrap.yieldIfDue()')
    if path == 'Source/world/spritefactory.lua':
        for name, local in [('playerStand', 'stand'), ('playerWalk1', 'walk1'), ('playerWalk2', 'walk2')]:
            body = body.replace(f'copyFrames(SpriteFactory.{name}, {local})', f'SpriteFactory.{name} = {local}')
        body = body.replace('for _, key in ipairs', 'SpriteFactory.npc = {}\nfor _, key in ipairs', 1)
    return (header + body.rstrip('\n') + '\n').encode()


def assert_startup_preserved(path, original, current):
    assert canonical_startup_source(path, current) == original, path
