"""Pure host rejection checks. Requires a private helper and retained real census run."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

helper, retained = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def reject(args, expected):
    result = subprocess.run([str(helper), *map(str, args)], capture_output=True, text=True, timeout=9)
    assert result.returncode == 1 and expected in result.stderr, result
    assert not result.stdout, result.stdout

reject([], 'usage:')
reject(['press', retained, '0'*64, '0'*64], 'usage:')
reject(['inspect', retained, 'wrong', 'wrong'], 'expected SHA256')
reject(['inspect', retained, '0'*64, '0'*64], 'metadata pin mismatch')
with tempfile.TemporaryDirectory(prefix='malloc-helper-host-') as temp:
    root = Path(temp)
    build = json.loads((retained / 'build.json').read_text())
    run = json.loads((retained / 'run.json').read_text())
    shutil.copytree(Path(build['bundle']), root / 'DoorCensus.pdx')
    build['bundle'] = str(root / 'DoorCensus.pdx')
    run['pid'] = os.getpid()  # This Python host test is never a Simulator child.
    (root / 'build.json').write_text(json.dumps(build))
    (root / 'run.json').write_text(json.dumps(run))
    def args():
        return ['inspect', root, sha(root / 'build.json'), sha(root / 'run.json')]
    reject(args(), 'helper must be direct child of runtime owner')
    (root / 'DoorCensus.pdx' / 'host-test-extra.txt').write_text('changed payload')
    reject(args(), 'PDX payload changed')
    run['simulator_sha256'] = '0'*64
    (root / 'run.json').write_text(json.dumps(run))
    reject(args(), 'not the pinned SDK census build/run')
print('7 host rejection checks passed; no AX, SDK execution or locks used')
