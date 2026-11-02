"""Host-only byte/path proof against the exact worker base; no game Lua execution."""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from collections import Counter

BASE = '00ce443a32f183599ab073d5944905fdd8c19c0e'
ROOT = Path(__file__).resolve().parents[3]
PREFIX = 'Source/data/contentCache/'
archive = subprocess.check_output(['git', '-C', str(ROOT), 'archive', BASE, PREFIX])
with tarfile.open(fileobj=io.BytesIO(archive)) as snapshot:
    before = {member.name.removeprefix(PREFIX): snapshot.extractfile(member).read()
              for member in snapshot.getmembers() if member.isfile()}
after = {p.relative_to(ROOT / PREFIX).as_posix(): p.read_bytes()
         for p in (ROOT / PREFIX).rglob('*') if p.is_file()}
old_records = {Path(name).stem: raw for name, raw in before.items() if name.startswith('chunks/')}
new_paths = {name: raw for name, raw in after.items() if name.startswith('chunks-v2/')}
new_records = {Path(name).stem: raw for name, raw in new_paths.items()}
assert len(old_records) == len(new_records) == len(new_paths) == 2546
assert old_records == new_records
assert {k: v for k, v in before.items() if not k.startswith('chunks/')} == {
    k: v for k, v in after.items() if not k.startswith('chunks-v2/')}
for digest, raw in new_records.items():
    assert hashlib.sha256(raw).hexdigest() == digest
    assert new_paths[f'chunks-v2/{digest[:2]}/{digest}.json'] == raw
assert len(after) == len(before) == 2578
hashes = {digest: hashlib.sha256(raw).hexdigest() for digest, raw in sorted(new_records.items())}
manifest = (json.dumps(hashes, sort_keys=True, separators=(',', ':')) + '\n').encode()
fanout = Counter(Path(name).parent.name for name in new_paths)
print(json.dumps(dict(base=BASE, records=len(new_records), record_bytes=sum(map(len, new_records.values())),
    indexes_unchanged=32, shard_directories=len(fanout), maximum_files_per_shard=max(fanout.values()),
    flat_records_remaining=sum(len(Path(name).parts) == 2 for name in new_paths),
    exactly_one_file_per_digest=True, all_record_bytes_identical=True,
    old_and_new_per_digest_sha256_manifest=hashlib.sha256(manifest).hexdigest()), indent=2))
