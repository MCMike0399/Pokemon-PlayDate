#!/usr/bin/env python3
"""ROOT ONLY private wait_smoke hook. Reuse Cycle admission/locks/USB/collection.

No planner. Root supplies small ordinary-button batches in numbered JSON files.
Nothing runs when imported. Shared owner and DS1 sources remain unchanged.
"""
import json
import os
from pathlib import Path
import re
import sys
import time

from prepare import B, PACKET, check_inputs, digest


def main():
    check_inputs()
    sys.path.insert(0, str(B))
    from tools import device_cycle as owner
    from tools.harness.protocol import atomic_json
    from tools.harness.run import simulator_usb_preflight
    if '--safety-only' not in sys.argv or '--simulator-smoke' not in sys.argv:
        raise ValueError('existing exact-build Simulator safety admission required')
    if '--execute-root' not in sys.argv:
        raise ValueError('explicit --execute-root required, including validation')
    position = sys.argv.index('--operator-dir')
    inbox = Path(sys.argv[position + 1]).expanduser().resolve()
    del sys.argv[position:position + 2]
    if not inbox.is_dir() or any(inbox.iterdir()):
        raise ValueError('fresh empty operator directory required')

    original_validate = owner.Cycle.validate_inputs
    original_read = owner.SmokeSerial.read

    def read(self):
        rows = original_read(self)
        raw_path = self.cycle.output / 'serial.raw'
        if raw_path.exists():
            with raw_path.open('rb') as raw:
                raw.seek(getattr(self, '_long_raw_offset', 0))
                tail = getattr(self, '_long_raw_tail', b'') + raw.read()
                self._long_raw_offset = raw.tell()
            self._long_raw_tail = tail[-512:]
            if re.search(rb'out of memory|allocation fail|malloc[^\r\n]*fail|BOOTERROR|panic|fatal', tail, re.I):
                self.cycle.event('native-runtime-diagnostic', text=tail.decode('utf-8', errors='replace'))
                raise ValueError('native/runtime allocation diagnostic; stop, retain serial.raw and logs')
        return rows

    def validate(self):
        if not 1 <= self.args.run_seconds <= 7200:
            raise ValueError('maximum 7200 seconds')
        result = original_validate(self)
        stage = Path(self.args.build_stage).resolve()
        build = json.loads((stage / 'build.json').read_text())
        extension = build.get('long_traversal', {})
        if extension.get('inputs_sha256') != digest(PACKET / 'inputs.json'):
            raise ValueError('not this long traversal build')
        for name, expected in extension.get('packet_files', {}).items():
            if digest(PACKET / name) != expected:
                raise ValueError('private packet changed since compilation: ' + name)
        if not extension.get('packet_files'):
            raise ValueError('missing private hook identity')
        return result

    def wait_smoke(self, deadline):
        simulator_usb_preflight()
        descriptor = os.open(self.serial, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        transport = owner.SmokeSerial(self, descriptor, self.smoke_build['build_id'], deadline)
        self.smoke_transport = transport
        number, commands, frames = 1, 0, 0
        battle_started = None
        battle_number = 0

        def send(body):
            nonlocal commands, frames, battle_started, battle_number
            commands += 1
            parts = body.split()
            frames += int(parts[-1]) + 1 if parts[0] in {'press', 'wait'} else 1
            if commands > 20000 or frames > 180000:
                raise ValueError('input/frame bound exhausted')
            # Preserve the overall deadline AND bound a stalled single command.
            transport.deadline = min(deadline, time.monotonic() + 30)
            value = transport.command(body)
            if value.get('saved', 0) != 0 or value.get('physical_controls'):
                raise ValueError('unexpected Save or physical handoff')
            stats = value.get('long_traversal', {})
            if stats.get('battles', 0) > battle_number:
                battle_number = stats['battles']
                battle_started = time.monotonic()
            if value.get('state') == 'overworld' and value.get('overworld') == 'explore':
                battle_started = None
            if battle_started and time.monotonic() - battle_started > 180:
                raise ValueError('180 second battle/UI bound exhausted')
            atomic_json(inbox / 'state.json', value)
            return value

        try:
            # Same module-installation and ordinary-readiness handshake as owner.
            transport.deadline = min(deadline, time.monotonic() + 60)
            installed = False
            while not installed:
                rows = transport.read()
                installed = transport.trace_identity or any(
                    row.get('seq') == 0 and row.get('status') == 'ready' for row in rows)
            state = send('state')
            while state.get('ready') is not True:
                state = send('state')
            if state.get('state') != 'title' or not state.get('continue_available'):
                raise ValueError('actual earned Title Continue required')
            # Deliberately do not replay the Simulator's Save safety route.
            state = send('press a 1')
            for _ in range(30):
                state = send('wait 30')
                if state.get('loaded', 0) > 0 and state.get('state') == 'overworld':
                    break
            if state.get('loaded', 0) != 1 or state.get('zone') != 'pokered:FUCHSIA_POKECENTER':
                raise ValueError('Continue did not reach exact earned B origin')
            while time.monotonic() < deadline:
                request = inbox / f'{number:06d}.json'
                if request.exists():
                    if request.is_symlink() or request.stat().st_size > 8192:
                        raise ValueError('unsafe/oversized operator batch')
                    bodies = json.loads(request.read_text())
                    if not isinstance(bodies, list) or not 1 <= len(bodies) <= 64:
                        raise ValueError('one to 64 ordinary inputs required')
                    for body in bodies:
                        match = re.fullmatch(r'(?:state|release all|press (?:a|b|up|down|left|right) ([1-8])|wait ([1-9]|[1-5][0-9]|60))', body)
                        if not match:
                            raise ValueError('bounded DS1 input required')
                    atomic_json(self.output / f'operator-{number:06d}.json', bodies)
                    for body in bodies:
                        state = send(body)
                    atomic_json(inbox / 'completed.json', {'batch': number})
                    number += 1
                elif (inbox / 'finish').exists():
                    state = send('release all')
                    stats = state.get('long_traversal', {})
                    if (stats.get('doors', 0) < 110 or stats.get('maps', 0) < 30
                            or stats.get('battles', 0) < 20 or stats.get('pending')
                            or state.get('state') != 'overworld' or state.get('overworld') != 'explore'
                            or state.get('player', {}).get('moving')):
                        raise ValueError('coverage/settled finish not achieved')
                    atomic_json(self.output / 'long-traversal-finish.json', state)
                    return
                elif (inbox / 'abort').exists():
                    send('release all')
                    raise ValueError('root stopped traversal; partial evidence retained')
                else:
                    # Ordinary no-input frames keep the app awake and observable.
                    state = send('wait 30')
            raise TimeoutError('two hour deadline; no restart/retry')
        finally:
            os.close(descriptor)
            atomic_json(self.output / 'device-responses.json', transport.responses)
            (self.output / 'serial-boot-trace.tsv').write_text('\n'.join(transport.trace) + '\n')
            self.event('reader-closed')

    # Invocation-local, deliberately unapplied hook. Admission/deployment/owner
    # lifecycle/log comparisons/collection/finally remain the existing Cycle.
    owner.Cycle.validate_inputs = validate
    owner.Cycle.wait_smoke = wait_smoke
    owner.SmokeSerial.read = read
    return owner.main()


if __name__ == '__main__':
    raise SystemExit(main())
