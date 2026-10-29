# P0 import trace grouping candidate

Base: `6428bf33957fcca2acb20a156b0989958865e144`. Only `Source/main.lua`
and this handoff change. Ten contiguous import groups retain begin/end records;
the bootstrap pair remains unchanged. Import records fall from 228 to 22,
a reduction of 206 (90.35%). This is a static count, not a measured speedup.

All 115 ordered imports match the base. Removing only import trace-marker
lines leaves byte-identical files (13,017 bytes; SHA-256
`328ddc28b4ee010491f5f879d62f283b35f6d652b5ac844bb9ec9a7b7e57c889`).
This proves every other runtime token, comment and harness anchor is unchanged.
The first six bootstrap lines and complete post-import tail also match exactly.
Each traced import has one enclosing begin/end pair. Reproduce the core proof:

```sh
python3 - <<'PY'
from pathlib import Path
import re
import subprocess
base = '6428bf33957fcca2acb20a156b0989958865e144'
old = subprocess.check_output(['git', 'show', base + ':Source/main.lua'])
new = Path('Source/main.lua').read_bytes()
imports = rb'^ *import "([^"\n]+)"$'
marks = rb'^ *BootTrace\.mark\("import\.[^"\n]+\.(?:begin|end)"\)\n'
assert re.findall(imports, old, re.M) == re.findall(imports, new, re.M)
assert re.sub(marks, b'', old, flags=re.M) == re.sub(marks, b'', new, flags=re.M)
print('Ordered imports and every byte outside import trace markers match.')
PY
```

Validation passed with SDK 3.1.2: all five existing production artifact/build
host checks, all 54 protocol host checks, private production compilation,
private harness `--build-only` compilation, and `git diff --check`. No skips.
Evidence is under
`~/Developer/Pokemon-PlayDate-env/evidence/p0-import-trace-groups-worker-20261029-01/`:
`preservation.json`, `production-host.log`, `protocol-host.log`,
`production-stage/`, `Production.pdx`, and `compile-only/`.

No Simulator or USB execution, deployment, push, baseline edit or new test was
performed. BootTrace flush behavior and all later tracing are unchanged.
Sprite/map initialization calls remain unapplied for root to integrate with the
other worker's candidate. Root must run the integrated trace under the 16 MB
Simulator before merging. Timing, heap and hardware acceptance remain unproved;
the game is not yet playable on Playdate hardware.
