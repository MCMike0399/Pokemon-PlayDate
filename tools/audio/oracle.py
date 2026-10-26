"""Independent RGBDS macro execution when present; explicit audited fallback otherwise."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from .codec import PITCHES, encode
from .source import AudioError

FIXTURE = Path(__file__).resolve().parents[1]/'references/audio/bytes.json'


def qualify_bytes(catalog, *, require_independent=False):
    raw = FIXTURE.read_bytes()
    fixture = json.loads(raw)
    if fixture['revision'] != catalog.source.revision:
        raise AudioError('byte fixture revision mismatch')
    expected = bytearray()
    source_lines = []
    for op, args, reference in fixture['commands']:
        actual = encode(op, args, lambda _: 0x4567)
        if actual.hex() != reference:
            raise AudioError(f'byte fixture mismatch: {op}')
        expected.extend(actual)
        source_lines.append(f'\t{op} '+', '.join(args))
    for key, reference in fixture['headers'].items():
        actual = [entry['header_byte'] for entry in catalog.headers[key]['channels']]
        if actual != reference:
            raise AudioError(f'header byte fixture mismatch: {key}')
        source_lines.append(f'channel_count {len(reference)}')
        for byte in reference:
            source_lines.append(f'channel {(byte & 15)+1}, Target')
            expected.extend((byte, 0x67, 0x45))
    wave_report = {}
    for family in (1, 2, 3):
        section, offset = catalog.target(family, f'Audio{family}_WavePointers.wave5')
        actual = catalog.sections[section][offset:offset+16].hex()
        if actual != fixture['wave5'][str(family)]:
            raise AudioError(f'audio{family} wave5 fixture mismatch')
        wave_report[str(family)] = actual
    assembler = shutil.which('rgbasm')
    linker = shutil.which('rgblink')
    result = {'method': 'audited exact-byte fixtures', 'independent_execution': False,
              'limitation': 'RGBDS rgbasm and rgblink required for independent byte execution; no packages installed.',
              'fixture_sha256': hashlib.sha256(raw).hexdigest(),
              'macro_cases': len(fixture['commands']), 'header_cases': len(fixture['headers']), 'wave5': wave_report}
    result['status'] = 'audit-only'
    result['missing_tools'] = [name for name, path in (('rgbasm', assembler), ('rgblink', linker)) if not path]
    if not assembler or not linker:
        if require_independent:
            raise AudioError('independent byte qualification unavailable: missing '+', '.join(result['missing_tools']))
        return result
    tool_report = {}
    for name, path in (('rgbasm', assembler), ('rgblink', linker)):
        try:
            version = subprocess.check_output([path, '--version'], stderr=subprocess.STDOUT).decode().strip()
        except (OSError, subprocess.CalledProcessError) as exc:
            raise AudioError(f'{name} version probe failed: {exc}') from exc
        if version != f'{name} v1.0.4':
            raise AudioError(f'{name}: required v1.0.4, found {version!r}')
        tool_report[name] = {'path': str(Path(path).resolve()), 'version': version,
                             'sha256': hashlib.sha256(Path(path).read_bytes()).hexdigest()}

    # Execute the original macros in an isolated 32KiB ROM, never the game ROM.
    preamble = ['DEF _BLUE EQU 1', 'DEF NUM_MUSIC_CHANS EQU 4', 'DEF NUM_CHANNELS EQU 8',
                'INCLUDE "macros/const.asm"', 'INCLUDE "macros/data.asm"',
                'INCLUDE "macros/scripts/audio.asm"']
    for name, value in PITCHES.items():
        preamble.append(f'DEF {name} EQU {value}')
    catalog.source.read('macros/const.asm')
    catalog.source.read('macros/data.asm')
    emitted_report = {}
    for family in (1, 2, 3):
        # Original first files after wave5, not a handwritten prefix translation.
        paths = {1: ['start_menu_1', 'pokeflute'], 2: ['press_ab_2'], 3: ['start_menu_3', 'cut_3']}[family]
        lines = preamble + ['DEF Target EQU $4567', 'SECTION "fixture", ROM0[$0000]'] + source_lines
        lines += [f'INCLUDE "audio/sfx/{path}.asm"' for path in paths]
        for path in paths: catalog.source.read(f'audio/sfx/{path}.asm')
        with tempfile.TemporaryDirectory(prefix='audio-rgbds-') as tmp:
            tmp = Path(tmp)
            (tmp/'fixture.asm').write_text('\n'.join(lines)+'\n')
            try:
                subprocess.run([assembler, '-I', str(catalog.source.root)+'/', '-o', str(tmp/'fixture.o'), str(tmp/'fixture.asm')], check=True, capture_output=True)
                subprocess.run([linker, '-o', str(tmp/'fixture.gb'), str(tmp/'fixture.o')], check=True, capture_output=True)
            except subprocess.CalledProcessError as exc:
                raise AudioError('RGBDS byte oracle failed: '+exc.stderr.decode()) from exc
            emitted = (tmp/'fixture.gb').read_bytes()
            if emitted[:len(expected)] != expected or emitted[len(expected):len(expected)+16].hex() != wave_report[str(family)]:
                raise AudioError(f'independent RGBDS byte mismatch, audio{family}')
            emitted_report[str(family)] = {
                'fixture_asm_sha256': hashlib.sha256((tmp/'fixture.asm').read_bytes()).hexdigest(),
                'compared_bytes': len(expected)+16,
                'compared_sha256': hashlib.sha256(emitted[:len(expected)+16]).hexdigest(),
                'emitted_sha256': hashlib.sha256(emitted).hexdigest()}
    result.update(status='pass', tools=tool_report, emitted=emitted_report, method='isolated original RGBDS macros and wave5 source prefixes', independent_execution=True,
                  limitation='Macro/prefix byte comparison only; not independent engine/register execution.',
                  rgbasm_version=subprocess.check_output([assembler, '--version']).decode().strip(),
                  rgblink_version=subprocess.check_output([linker, '--version']).decode().strip())
    return result


def main(argv=None):
    """Strict standalone byte qualification; audit-only is an explicit opt-in."""
    import os
    from .catalog import Catalog
    from .source import Source

    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument('--source', default=os.environ.get('POKERED_REFERENCE_DIR'))
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--audit-only', action='store_true')
    args = parser.parse_args(argv)
    if not args.source:
        parser.error('--source or POKERED_REFERENCE_DIR is required')
    try:
        catalog = Catalog(Source(args.source))
        result = qualify_bytes(catalog)
        result['revision'] = catalog.source.revision
        result['consumed_sha256'] = dict(sorted(catalog.source.hashes.items()))
        result['oracle_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        if not args.audit_only and not result['independent_execution']:
            result['status'] = 'blocked'
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
        if result['status'] == 'blocked':
            print('independent byte qualification unavailable: missing '+', '.join(result['missing_tools']))
            return 2
        return 0
    except (AudioError, OSError, ValueError) as exc:
        print(f'audio byte qualification: {exc}')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
