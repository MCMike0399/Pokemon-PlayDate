"""Native APFS compression of terminal traces; caller holds all four global locks."""
from contextlib import contextmanager
import fcntl
import io
import json
import math
import os
import plistlib
import stat
import subprocess
import sys
import time
import uuid

from tools.harness.share_archives import closed_trace_groups, digest, metadata, regular, within_root

COMPRESSED = 32
EXCLUDED = {'chain', 'player-packages', 'Source', 'references', 'Data', 'runtime-data'}


class StopCompression(Exception):
    """Target or time budget reached without publishing another file."""


class AuditError(OSError):
    """Do not publish more files when the audit stream cannot be written."""


def audit_event(event):
    """Append to the CLI's existing stderr; fsync the wrapper's regular log file."""
    try:
        print(json.dumps(event), file=sys.stderr, flush=True)
        try:
            fd = sys.stderr.fileno()
        except (AttributeError, io.UnsupportedOperation):
            return  # In-memory host-test adapter; real wrappers use regular files.
        if stat.S_ISREG(os.fstat(fd).st_mode):
            os.fsync(fd)
    except (OSError, ValueError) as error:
        raise AuditError('compression audit unavailable: ' + str(error)) from error


def unavailable_reason(root):
    if sys.platform != 'darwin':
        return 'native compression unavailable: requires Darwin/APFS'
    try:
        # diskutil accepts devices/mount points, not arbitrary archive folders.
        rows = subprocess.check_output(['/bin/df', '-P', str(root)],
                                       text=True, timeout=10).splitlines()
        if len(rows) != 2 or not rows[1].split():
            raise ValueError('cannot identify the evidence filesystem')
        device = rows[1].split()[0]
        info = plistlib.loads(subprocess.check_output(
            ['/usr/sbin/diskutil', 'info', '-plist', device], timeout=10))
        if not isinstance(info, dict):
            raise ValueError('invalid filesystem probe')
        if str(info.get('FilesystemType', '')).lower() != 'apfs':
            return 'native compression unavailable: evidence is not APFS'
    except (OSError, ValueError, plistlib.InvalidFileException, subprocess.SubprocessError) as error:
        return 'native compression unavailable: ' + str(error)
    return None


def lower_priority():
    priority = os.getpriority(os.PRIO_PROCESS, 0)
    if priority < 10:
        os.nice(10 - priority)


def copy_compressed(source, destination, timeout):
    subprocess.run(['/usr/bin/ditto', '--rsrc', '--extattr', '--acl', '--hfsCompression',
                    str(source), str(destination)], check=True, capture_output=True, timeout=timeout)


def source_identity(path, info=None):
    info = path.stat() if info is None else info
    return (info.st_dev, info.st_ino, info.st_nlink, info.st_size, info.st_mtime_ns,
            info.st_ctime_ns, getattr(info, 'st_flags', 0))


def terminal_proofs(folder, archive, root):
    runfile = folder / 'run.json'
    terminal = archive / 'suite.json'
    if not terminal.exists():
        terminal = archive / 'outcome.json'
    proofs = {}
    for file in (runfile, terminal):
        if not within_root(file, root) or not regular(file):
            raise ValueError('unsafe or missing terminal proof: ' + str(file))
        before = source_identity(file)
        checksum = digest(file)
        value = json.loads(file.read_text())
        if not isinstance(value, dict):
            raise ValueError('terminal proof must be an object')
        if file == runfile:
            processes = value.get('processes')
            if not isinstance(processes, list) or not processes or any(
                    not isinstance(row, dict) or row.get('status') not in ('exited', 'failed-exited')
                    or type(row.get('returncode')) is not int for row in processes):
                raise ValueError('run has no confirmed terminal processes')
        elif file.name == 'suite.json':
            if value.get('complete') is not True:
                raise ValueError('suite is not complete')
        elif type(value.get('ok')) is not bool:
            raise ValueError('outcome is not terminal')
        if source_identity(file) != before or digest(file) != checksum:
            raise ValueError('terminal proof changed during inspection')
        proofs[file] = (before, checksum)
    return proofs


def verify_proofs(proofs, root):
    for file, (identity, checksum) in proofs.items():
        if not within_root(file, root) or not regular(file) or source_identity(file) != identity \
                or digest(file) != checksum:
            raise ValueError('terminal proof changed before publication')


@contextmanager
def archive_lock(folder, root):
    path = folder / 'runtime-data/owner.lock'
    if not within_root(path.parent, root) or not path.parent.is_dir():
        raise ValueError('unsafe archived runtime directory')
    if path.exists() and (not regular(path) or not within_root(path, root)):
        raise ValueError('unsafe archived owner lock')
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'a+') as stream:
        if not regular(path) or not within_root(path, root):
            raise ValueError('archived owner lock boundary changed')
        fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield path


def reject_open(archive, live_paths, own_lock=None):
    # Only our exact lsof owner-lock line is exempt. Never erase a command or
    # some other open file merely because its line also contains the lock path.
    pid = None
    for line in live_paths().splitlines():
        if line.startswith('p') and line[1:].isdigit():
            pid = int(line[1:])
        if own_lock is not None and pid == os.getpid() and line == 'n' + str(own_lock):
            continue
        if str(archive) in line:
            raise ValueError('archive is live/open: ' + str(archive))


def compress_file(path, root, proofs, archive, own_lock, live_paths, check_budget, timeout):
    if path.name != 'trace.jsonl' or not within_root(path, root) or not regular(path):
        raise ValueError('not an independent closed trace inside evidence')
    before = path.stat()
    identity = source_identity(path, before)
    if getattr(before, 'st_flags', 0) != 0:
        return None  # Includes already-compressed files and every unsupported flag.
    original_metadata = metadata(path)
    checksum = digest(path)
    temporary = path.with_name(path.name + '.compressed-' + uuid.uuid4().hex)
    try:
        check_budget()
        copy_compressed(path, temporary, timeout())
        check_budget()
        if not within_root(temporary, root) or not regular(temporary):
            raise ValueError('temporary crossed filesystem/link boundary')
        result = temporary.stat()
        if getattr(result, 'st_flags', 0) != COMPRESSED or result.st_blocks >= before.st_blocks:
            return None  # An ordinary copy is never reported as compression.
        if (result.st_uid, result.st_gid, result.st_size) != (before.st_uid, before.st_gid, before.st_size):
            raise ValueError('identity or length changed')
        if result.st_ino == before.st_ino or digest(temporary) != checksum:
            raise ValueError('compressed bytes or independent inode differ')
        compressed_metadata = metadata(temporary)
        if original_metadata[:3] != compressed_metadata[:3] or original_metadata[4:] != compressed_metadata[4:]:
            raise ValueError('permissions, ACLs or public extended attributes differ')
        if not within_root(path, root) or not regular(path) or source_identity(path) != identity \
                or metadata(path) != original_metadata or digest(path) != checksum:
            raise ValueError('source changed while compressing')
        verify_proofs(proofs, root)
        if not within_root(temporary, root) or not within_root(path, root):
            raise ValueError('publication boundary changed')
        os.utime(temporary, ns=(before.st_atime_ns, before.st_mtime_ns))
        with temporary.open('rb') as stream:
            os.fsync(stream.fileno())
        row = {'path': str(path), 'sha256': checksum, 'logical_bytes': before.st_size,
               'allocated_before': before.st_blocks * 512, 'allocated_after': result.st_blocks * 512,
               'mode_mtime_public_xattrs_acl_preserved': True}
        # Prepared events make a crash between replace and completed audit
        # recoverable by hashing this exact path. Never overwrite an old audit.
        audit_event({'compression_prepared': row})
        check_budget()
        reject_open(archive, live_paths, own_lock)  # Fresh open-path check before publication.
        check_budget()  # A slow process inventory must not publish past the deadline.
        os.replace(temporary, path)
        return row
    finally:
        if temporary.exists() or temporary.is_symlink():
            temporary.unlink()


def compress_closed_traces(root, execute, enough_space, live_paths, allowed_roots=None,
                           minimum_size=10 * 1024 ** 2, max_seconds=1800):
    """Called only under storage/suite/Simulator/device locks; never acquires or expires them."""
    if not math.isfinite(max_seconds) or not 0 < max_seconds <= 1800:
        raise ValueError('compression budget must be finite and at most 1800 seconds')
    started = time.monotonic()
    report = {'mode': 'execute' if execute else 'dry-run', 'files': [], 'refusals': [],
              'status': 'exhausted', 'candidate_files': 0}
    reason = unavailable_reason(root)
    if reason:
        report.update(status='unavailable', reason=reason)
        return report
    if root.resolve() != root.absolute() or root.is_mount():
        raise ValueError('compression root must be a real unmounted directory')

    def check_budget():
        if enough_space():
            raise StopCompression('target met')
        if time.monotonic() - started >= max_seconds:
            raise StopCompression('time budget exhausted')

    def timeout():
        check_budget()
        remaining = max_seconds - (time.monotonic() - started)
        if remaining <= 0:
            raise StopCompression('time budget exhausted')
        return min(180, remaining)

    try:
        check_budget()
        if execute:
            lower_priority()
        for paths in closed_trace_groups(root, allowed_roots):
            check_budget()
            if not paths:
                continue
            # These are exactly the supported run layouts from closed_trace_groups.
            archive = root / paths[0].relative_to(root).parts[0]
            if archive.name in EXCLUDED:
                continue
            try:
                folder = next((parent for parent in paths[0].parents
                               if (parent / 'run.json').is_file()), None)
                if folder is None:
                    raise ValueError('run metadata disappeared')
                reject_open(archive, live_paths)
                terminal_proofs(folder, archive, root)
                if not execute:
                    report['candidate_files'] += sum(p.stat().st_size >= minimum_size for p in paths)
                    continue
                with archive_lock(folder, root) as own_lock:
                    for path in paths:
                        check_budget()
                        if path.stat().st_size < minimum_size:
                            continue
                        # Fresh proof bytes and identities for every file, never
                        # a cached group's historical terminal/PID declarations.
                        proofs = terminal_proofs(folder, archive, root)
                        reject_open(archive, live_paths, own_lock)
                        report['candidate_files'] += 1
                        row = compress_file(path, root, proofs, archive, own_lock,
                                            live_paths, check_budget, timeout)
                        if row:
                            report['files'].append(row)
                            audit_event({'compressed_archive': row})
            except AuditError as error:
                report['refusals'].append({'archive': str(archive), 'reason': str(error)})
                report['status'] = 'audit unavailable'
                return report
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                refusal = {'archive': str(archive), 'reason': str(error)}
                report['refusals'].append(refusal)
                try:
                    audit_event({'compression_refused': refusal})
                except AuditError:
                    report['status'] = 'audit unavailable'
                    return report
    except StopCompression as stopped:
        report['status'] = str(stopped)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        refusal = {'archive': str(root), 'reason': str(error)}
        report['refusals'].append(refusal)
        report['status'] = 'refused'
        try:
            audit_event({'compression_refused': refusal})
        except AuditError:
            report['status'] = 'audit unavailable'
    return report
