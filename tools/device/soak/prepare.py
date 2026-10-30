#!/usr/bin/env python3
"""Compile-only private soak packet. Has no runtime, USB, or deployment action."""
import argparse
import difflib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT))
from tools.build import stage_production
from tools.device.build_smoke import manifest, replace_once
from tools.device_cycle import inventory, tree_hash, sha
from tools.device.soak.evidence import TOOL_PATHS

SNAPSHOT = '''local function snapshot()
    local result = {ready=runtimeGame ~= nil, error=failure, loaded=loaded,
        saved=saved, input_active=active ~= nil}
    if not runtimeGame then return result end
    local machine = runtimeGame.machine
    result.state = machine:getCurrent()
    local title = machine:get("title")
    result.continue_available = title.candidate ~= nil
    local world = machine:get("overworld")
    result.overworld = world.sub and world.sub:getCurrent()
    result.zone = currentZone and currentZone.stableID
    local player = runtimeGame.player
    if player then result.player = {x=player.gridX, y=player.gridY,
        facing=player.facing, moving=player.isMoving} end
    return result
end

'''


def prepare(project, sdk, output, earned_path, phase_minutes=60, gc_mode='generational'):
    if phase_minutes not in (30, 60) or gc_mode not in ('generational', 'incremental'):
        raise ValueError('soak requires 30/60 minute phases and a known collection mode')
    dependencies = {name: sha(PROJECT/name) for name in TOOL_PATHS}
    earned = json.loads(earned_path.read_text())
    slots = earned['files']
    if (len(slots) != 2 or len({r['file'] for r in slots}) != len(slots)
            or any(r['file'] not in {'adventure.a.json', 'adventure.b.json'} for r in slots)):
        raise ValueError('two uniquely named earned slots required')
    earned_dir = Path(earned['directory']).expanduser().resolve()
    for row in slots:
        if sha(earned_dir / row['file']) != row['sha256']:
            raise ValueError('earned slot hash mismatch')
    if not earned.get('provenance'):
        raise ValueError('root must supply earned provenance; no eligibility inferred from hashes')
    output.mkdir(parents=True, exist_ok=False)
    source = stage_production(project, output)
    base = manifest(source)
    original = (source / 'main.lua').read_text()
    if 'GameBootstrap.runFrame(updateGame, game)' not in original:
        raise ValueError('root guarded bootstrap anchor required')
    if 'DEVICE_TEST_BUILD = ' in original or 'dev/deviceSmoke' in original:
        raise ValueError('production entry must not contain private test imports')
    # Compile the current DS1 parser/input seam, replacing only its heavy read
    # snapshot and removing the entire observer/recorder implementation.
    module = (project / 'Source/dev/deviceSmoke.lua').read_text()
    observer = '-- Installed by private staging after main.'
    if module.count(observer) != 1:
        raise ValueError('unknown DS1 observer boundary')
    module = module.split(observer)[0]
    begin, end = module.index('local function menuState('), module.index('function DeviceSmoke.drawError()')
    module = module[:begin] + SNAPSHOT + module[end:]
    module = replace_once(module, '    if playdate.isSimulator then\n', '    if true then -- bounded ready/accepted/done audit on both platforms\n')
    module += '\nDeviceSmoke.soakState = snapshot\nfunction DeviceSmoke.soakStatus() return failure, loaded, saved, active ~= nil end\n'
    if any(s in module for s in ('device-smoke-frames.tsv', 'function record(', 'installSimulatorObserver')):
        raise ValueError('recorder survived overlay')
    identity = uuid.uuid4().hex
    private = replace_once(original, '    import "CoreLibs/graphics"\n',
        '    import "CoreLibs/graphics"\n    import "dev/deviceSmoke"\n    import "dev/soakSampler"\n')
    private = f'DEVICE_TEST_BUILD = true\nDEVICE_TEST_ID = "{identity}"\n' + private
    private += '\nDeviceSmoke.installSoak()\n'
    if gc_mode == 'incremental':
        private += '\nGameBootstrap.afterReady(function() collectgarbage("incremental", 110, 200, 13) end)\n'
    (source / 'main.lua').write_text(private)
    (source / 'dev').mkdir()
    (source / 'dev/deviceSmoke.lua').write_text(module)
    sampler = Path(__file__).with_name('sampler.lua').read_text()
    sampler = replace_once(sampler, 'local phaseSamples = 60', f'local phaseSamples = {phase_minutes}')
    sampler = replace_once(sampler, 'local profile = "hardware-60+60"',
                           f'local profile = "hardware-{phase_minutes}+{phase_minutes}"')
    (source / 'dev/soakSampler.lua').write_text(sampler)
    bundle_id = f'com.poc.pokemon.soak.{identity}'
    info = source / 'pdxinfo'
    info.write_text(replace_once(info.read_text(), 'bundleID=com.poc.pokemon\n', f'bundleID={bundle_id}\n'))
    compiled = manifest(source)
    if ({n for n in base if compiled.get(n) != base[n]} != {'main.lua', 'pdxinfo'}
            or set(compiled)-set(base) != {'dev/deviceSmoke.lua', 'dev/soakSampler.lua'}):
        raise ValueError('overlay exceeded private entry/identity/two-module boundary')
    for row in slots:
        (output / 'earned-slots').mkdir(exist_ok=True)
        shutil.copyfile(earned_dir / row['file'], output / 'earned-slots' / row['file'])
        if sha(output / 'earned-slots' / row['file']) != row['sha256']:
            raise ValueError('retained earned slot hash mismatch')
    earned['directory'] = str(output / 'earned-slots')
    (output / 'earned-save.json').write_text(json.dumps(earned, indent=2)+'\n')
    for name, before, after in [('main', original, private),
            ('deviceSmoke', (project/'Source/dev/deviceSmoke.lua').read_text(), module)]:
        (output/f'private-{name}.patch').write_text(''.join(difflib.unified_diff(
            before.splitlines(True), after.splitlines(True), fromfile=f'base/{name}.lua', tofile=f'private/{name}.lua')))
    bundle = output / 'Soak.pdx'
    with (output / 'build.log').open('w') as log:
        subprocess.run([str(sdk/'bin/pdc'), str(source), str(bundle)],
                       stdout=log, stderr=subprocess.STDOUT, check=True)
    # Snapshot the helpers actually imported by this Python process, not merely
    # the selected game's Source checkout. Root's owner patch must precede this.
    tool_files = dependencies
    if {name: sha(PROJECT/name) for name in TOOL_PATHS} != tool_files:
        raise ValueError('executing dependency changed during preparation; rebuild')
    for name in TOOL_PATHS:
        target = output/'soak-tools'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PROJECT/name, target)
    if inventory(output/'soak-tools') != tool_files:
        raise ValueError('dependency changed while retaining packet')
    result = dict(tool_files=tool_files, mode='private-soak-compile-only-NOT-ADMITTED', build_id=identity,
        bundle_id=bundle_id, bundle=str(bundle),
        revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=project, text=True).strip(),
        git_status=subprocess.check_output(['git', 'status', '--porcelain'], cwd=project, text=True),
        source_maps=len(json.loads((source/'data/sourceMaps.json').read_text())['maps']),
        source_label='exact selected project revision/status; production staging without content overlays',
        main_revision=subprocess.check_output(['git', 'rev-parse', 'main'], cwd=project, text=True).strip(),
        production_source_manifest=base, production_source_sha256=tree_hash(base),
        compiled_source_manifest=compiled, compiled_source_sha256=tree_hash(compiled),
        pdx_files=inventory(bundle), pdx_sha256=tree_hash(inventory(bundle)),
        compiler_sha256=sha(sdk/'bin/pdc'), sdk_version=(sdk/'VERSION.txt').read_text().strip(),
        earned_manifest_sha256=sha(output/'earned-save.json'), earned_slots=slots,
        device_smoke_seam_sha256=sha(project/'Source/dev/deviceSmoke.lua'),
        sampler_sha256=sha(source/'dev/soakSampler.lua'),
        hardware_admission=False, runtime_executed=False,
        phase_minutes=phase_minutes, gc_mode=gc_mode,
        schedule=f'{phase_minutes} complete active minutes at title; DS1 press a 1; settled earned overworld; {phase_minutes} complete active minutes',
        heap_sampling='recorded once/minute; original per-frame guard retained; no periodic full GC',
        overhead='unmeasured until runtime; minute rows report prior cost; terminal row reports total/max/last',
        blockers=['existing exact DeviceSmoke gate rejects two-module overlay and absent frame metrics',
                  'root must admit exact-build short Simulator aggregate proof, unchanged 150 ms/9 MiB limits',
                  'existing device cycle holds both locks until collection; launch/release/collect split required'])
    (output/'build.json').write_text(json.dumps(result, indent=2)+'\n')
    return {k: result[k] for k in ('mode', 'build_id', 'bundle', 'source_maps', 'pdx_sha256')}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', type=Path, default=PROJECT)
    parser.add_argument('--sdk', type=Path, default=Path('~/Developer/PlaydateSDK'))
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--earned-save', type=Path, required=True)
    parser.add_argument('--phase-minutes', type=int, choices=(30, 60), default=60)
    parser.add_argument('--gc-mode', choices=('generational', 'incremental'), default='generational')
    args = parser.parse_args()
    print(json.dumps(prepare(args.project.expanduser().resolve(), args.sdk.expanduser().resolve(),
        args.output.expanduser().resolve(), args.earned_save.expanduser().resolve(),
        args.phase_minutes, args.gc_mode), indent=2))
