#!/usr/bin/env python3
"""Produce the small root-owned session append; never edit the shared owner."""
import difflib
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
OWNER = Path('Source/domain/gameSession.lua')
before = (ROOT/OWNER).read_text()
assert 'function GameSession:commitCeladonService' not in before
methods = '\n'.join((Path(__file__).parent/name).read_text() for name in ['root-session-methods.lua','root-slot-methods.lua'])
after = before + '\n' + methods
patch = ''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile='a/'+str(OWNER),tofile='b/'+str(OWNER)))
(Path(__file__).parent/'root-api.patch').write_text(patch)
print('Root GameSession patch generated; no shared owner edited.')
