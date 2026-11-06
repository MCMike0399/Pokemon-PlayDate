"""Read-only relocation of the frozen earned-evidence namespace.

Frozen saves keep their original absolute paths and hashes. When
``POKEMON_EVIDENCE_MIRROR`` names a real directory, reads under
``/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence`` resolve there.
Nothing is rewritten, and paths outside that namespace are untouched.
"""
from contextlib import contextmanager
import os
from pathlib import Path

from tools.harness.protocol import ProtocolError

ORIGINAL_EVIDENCE = Path('/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence')
_PATCHED = ('read_bytes', 'read_text', 'is_file', 'is_symlink', 'exists')


def mirror_root():
    raw = os.environ.get('POKEMON_EVIDENCE_MIRROR')
    if not raw:
        return None
    root = Path(raw)
    if root.is_symlink() or not root.is_dir():
        raise ProtocolError('POKEMON_EVIDENCE_MIRROR must be a real directory')
    return root.resolve()


@contextmanager
def mirrored_evidence_reads():
    root = mirror_root()
    if root is None:
        yield
        return
    originals = {name: getattr(Path, name) for name in _PATCHED}

    def mapped(path):
        try:
            relative = Path(path).relative_to(ORIGINAL_EVIDENCE)
        except ValueError:
            return path
        if relative.is_absolute() or '..' in relative.parts:
            raise ProtocolError('unsafe evidence mirror path')
        target = root / relative
        if os.path.islink(target):
            raise ProtocolError('evidence mirror path is a link: ' + str(path))
        return target

    def wrapper(name):
        def call(path, *args, **kwargs):
            return originals[name](mapped(path), *args, **kwargs)
        return call

    try:
        for name in originals:
            setattr(Path, name, wrapper(name))
        yield
    finally:
        for name, function in originals.items():
            setattr(Path, name, function)
