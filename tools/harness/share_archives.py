"""Share identical immutable bytes with independent APFS clones, never hard links."""
from collections import defaultdict
import hashlib
import json
import os
import stat
import subprocess
import sys
import uuid


def digest(path):
    checksum = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 ** 2), b''):
            checksum.update(block)
    return checksum.hexdigest()


def within_root(path, root):
    if path.resolve() != path.absolute() or not path.is_relative_to(root):
        return False
    device = root.stat().st_dev
    current = path
    while current != root:
        if current.is_mount() or current.stat().st_dev != device:
            return False
        current = current.parent
    return True


def metadata(path):
    info = path.stat()
    acl = ()
    if sys.platform == 'darwin':
        names = subprocess.check_output(['/usr/bin/xattr', str(path)], text=True).splitlines()
        attributes = []
        for name in names:
            value = subprocess.check_output(['/usr/bin/xattr', '-px', name, str(path)], text=True)
            attributes.append((name, hashlib.sha256(bytes.fromhex(value)).hexdigest()))
        permissions = subprocess.check_output(['/bin/ls', '-lde', str(path)], text=True)
        acl = tuple(permissions.splitlines()[1:])
    else:
        attributes = [(name, hashlib.sha256(os.getxattr(path, name)).hexdigest())
                      for name in os.listxattr(path)]
    return (info.st_uid, info.st_gid, info.st_mode, getattr(info, 'st_flags', 0),
            tuple(sorted(attributes)), acl)


def compatible_metadata(source, target):
    left, right = metadata(source), metadata(target)
    # Decline different ACLs/attributes instead of transferring another file's
    # metadata. Mode and timestamps are explicitly restored below.
    return left[:2] == right[:2] and left[3:] == right[3:]


def regular(path):
    if path.is_symlink() or path.resolve() != path.absolute():
        return False
    info = path.stat()
    return stat.S_ISREG(info.st_mode) and info.st_nlink == 1


def clone_file(source, target):
    subprocess.run(['/bin/cp', '-c', '-p', str(source), str(target)],
                   check=True, capture_output=True, text=True)


def share_pair(source, target, checksum, clone=clone_file, boundary=None):
    """Replace only a still-identical destination, preserving its mode and times."""
    if not regular(source) or not regular(target):
        raise ValueError('sharing requires real independent regular files')
    if boundary is not None and not all(within_root(p, boundary) for p in (source, target)):
        raise ValueError('sharing path crosses evidence mount/device boundary')
    if not compatible_metadata(source, target):
        raise ValueError('sharing metadata is unsupported or differs')
    original_source_metadata, original_target_metadata = metadata(source), metadata(target)
    before = target.stat()
    if source.stat().st_dev != before.st_dev:
        raise ValueError('sharing requires the same filesystem')
    if source.stat().st_ino == before.st_ino:
        raise ValueError('sharing requires different files')
    if digest(source) != checksum or digest(target) != checksum:
        raise ValueError('sharing bytes changed before cloning')
    temporary = target.with_name(target.name + '.cow-' + uuid.uuid4().hex)
    try:
        clone(source, temporary)
        if not regular(temporary) or temporary.stat().st_ino == source.stat().st_ino:
            raise ValueError('sharing must create an independent clone')
        if not compatible_metadata(source, temporary):
            raise ValueError('cloned metadata differs')
        if digest(temporary) != checksum or digest(source) != checksum:
            raise ValueError('cloned bytes differ')
        current = target.stat()
        if (current.st_ino, current.st_size, current.st_mtime_ns) != (
                before.st_ino, before.st_size, before.st_mtime_ns) or digest(target) != checksum \
                or metadata(target) != original_target_metadata \
                or metadata(source) != original_source_metadata:
            raise ValueError('sharing destination changed during cloning')
        if boundary is not None and not all(within_root(p, boundary) for p in (source, target, temporary)):
            raise ValueError('sharing path crosses evidence mount/device boundary')
        os.chmod(temporary, stat.S_IMODE(before.st_mode))
        os.utime(temporary, ns=(before.st_atime_ns, before.st_mtime_ns))
        if metadata(temporary) != original_target_metadata:
            raise ValueError('destination metadata could not be preserved')
        os.replace(temporary, target)
    finally:
        if temporary.exists():
            temporary.unlink()


def closed_trace_groups(root, allowed_roots=None):
    """Only archived harness processes with confirmed exits qualify."""
    runs = sorted(set(root.glob('*/run.json')) | set(root.glob('*/*/run.json')))
    for path in runs:
        archive = root / path.relative_to(root).parts[0]
        if allowed_roots is not None and archive not in allowed_roots:
            continue
        if not within_root(path, root) or not regular(path):
            continue
        try:
            run = json.loads(path.read_text())
        except (OSError, ValueError):
            continue
        if not isinstance(run, dict):
            continue
        processes = run.get('processes', [])
        if not isinstance(processes, list) or not processes or any(
                not isinstance(row, dict) or row.get('status') not in {'exited', 'failed-exited'}
                                or 'returncode' not in row for row in processes):
            continue
        folder = path.parent
        paths = [folder / 'runtime-data/trace.jsonl']
        for generation in sorted((folder / 'processes').glob('*')):
            paths.extend((generation / 'trace.jsonl', generation / 'runtime-data/trace.jsonl'))
        yield [p for p in paths if p.is_file() and within_root(p, root) and regular(p)]


def share_closed_traces(root, execute, enough_space, minimum_size=1024 ** 2, allowed_roots=None):
    """Caller holds the storage, suite, Simulator and device ownership locks."""
    report = {'mode': 'execute' if execute else 'dry-run', 'files': [], 'skipped_metadata': []}
    for paths in closed_trace_groups(root, allowed_roots):
        by_size = defaultdict(list)
        for path in paths:
            if path.stat().st_size >= minimum_size:
                by_size[path.stat().st_size].append(path)
        for size, same_size in by_size.items():
            if len(same_size) < 2:
                continue
            by_digest = {}
            for path in same_size:
                if execute and enough_space():
                    return report
                checksum = digest(path)
                if checksum not in by_digest:
                    by_digest[checksum] = path
                    continue
                source = by_digest[checksum]
                if not compatible_metadata(source, path):
                    report['skipped_metadata'].append(str(path))
                    continue
                if execute:
                    share_pair(source, path, checksum, boundary=root)
                row = {'source': str(source), 'destination': str(path),
                       'sha256': checksum, 'logical_bytes': size}
                report['files'].append(row)
                if execute:
                    print(json.dumps({'shared_archive': row}), file=sys.stderr)
    return report
