"""Harness-only imports, inserted into the private staged entry point.

Keep slots in execution order: some production imports occur between suites.
No runtime conditional can exclude Lua from pdc's compile input.
"""
import re
from pathlib import Path

IMPORTS = Path(__file__).with_name('dev_imports.lua')


def overlay_imports(source):
    main = source / 'main.lua'
    text = main.read_text()
    sections = re.split(r'^-- @harness ([\w-]+)\n', IMPORTS.read_text(), flags=re.MULTILINE)
    names = sections[1::2]
    if not names or len(names) != len(set(names)):
        raise ValueError('missing or duplicate harness overlay section')
    for name, lua in zip(names, sections[2::2]):
        marker = '-- @harness ' + name + '\n'
        if text.count(marker) != 1:
            raise ValueError('missing or duplicate harness import slot: ' + name)
        text = text.replace(marker, lua)
    if '-- @harness ' in text:
        raise ValueError('unknown harness import slot')
    main.write_text('import "dev/harness_build"\n' + text)
