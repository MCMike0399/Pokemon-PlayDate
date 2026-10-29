"""Harness-only imports, inserted into the private staged entry point.

Keep slots in execution order: some production imports occur between suites.
No runtime conditional can exclude Lua from pdc's compile input.
"""
import re
from pathlib import Path

IMPORTS = Path(__file__).with_name('dev_imports.lua')


def overlay_imports(source, journey=False):
    main = source / 'main.lua'
    text = main.read_text()
    imports = IMPORTS.read_text()
    if journey:
        imports = '''-- @harness imports-1
-- @harness imports-2
import "dev/harness_capture"
import "dev/diagnostics"
import "dev/fixtures"
import "dev/autopilot"
import "dev/harness"
-- @harness imports-3
-- @harness imports-4
-- @harness imports-5
-- @harness imports-6
-- @harness imports-7
-- @harness content-ready
-- @harness runtime
harness = Harness
'''
    sections = re.split(r'^-- @harness ([\w-]+)\n', imports, flags=re.MULTILINE)
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
