#!/usr/bin/env python3
"""ROOT ONLY: record ordinary DS1 buttons via existing exact-bundle Simulator.

Recording is NOT admission. Replay the frozen result with simulator_smoke.py.
"""
import argparse
import json
from pathlib import Path
import re
import sys
import time
from prepare import B, check_inputs


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--execute-root', action='store_true', required=True)
    p.add_argument('--stage', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--operator-dir', type=Path, required=True)
    p.add_argument('--sdk', type=Path, default=Path.home() / 'Developer/PlaydateSDK')
    a = p.parse_args()
    check_inputs()
    if not a.operator_dir.is_dir() or any(a.operator_dir.iterdir()):
        raise ValueError('fresh empty operator directory required')
    sys.path.insert(0, str(B))
    from tools.device import simulator_smoke as smoke
    from tools.harness.protocol import atomic_json
    original = smoke.Mailbox.command
    captured, armed = [], False
    deadline = time.monotonic() + 1200

    def command(self, body):
        nonlocal armed
        if armed:
            number = 1
            while time.monotonic() < deadline:
                batch = a.operator_dir / f'{number:06d}.json'
                if batch.exists():
                    if batch.is_symlink() or batch.stat().st_size > 8192:
                        raise ValueError('unsafe batch')
                    bodies = json.loads(batch.read_text())
                    if not isinstance(bodies, list) or not 1 <= len(bodies) <= 64:
                        raise ValueError('bounded input batch required')
                    for value in bodies:
                        if not isinstance(value, str) or not re.fullmatch(
                                r'(?:state|release all|press (?:a|b|up|down|left|right) [1-8]|wait ([1-9]|[1-5][0-9]|60))', value):
                            raise ValueError('ordinary bounded DS1 input required')
                        if len(captured) >= 1500:
                            raise ValueError('1500 command safety capture bound')
                        captured.append(value)
                        atomic_json(a.output / 'captured-buttons.json', captured)
                        atomic_json(a.operator_dir / 'state.json', original(self, value))
                    atomic_json(a.operator_dir / 'completed.json', {'batch': number})
                    number += 1
                elif (a.operator_dir / 'finish').exists():
                    break
                elif (a.operator_dir / 'abort').exists():
                    raise ValueError('root aborted capture')
                else:
                    # Root has 20 minutes overall; each command has 30 seconds.
                    captured.append('wait 30')
                    if len(captured) >= 1500:
                        raise ValueError('capture command bound')
                    atomic_json(a.operator_dir / 'state.json', original(self, 'wait 30'))
                    atomic_json(a.output / 'captured-buttons.json', captured)
            else:
                raise TimeoutError('20 minute safety recording bound')
            armed = False
        state = original(self, body)
        atomic_json(a.operator_dir / 'state.json', state)
        if state.get('ready') and not captured:
            armed = True  # next call is the existing runner's final state read
        return state

    smoke.Mailbox.command = command
    try:
        # Empty frozen route here deliberately cannot supply hardware admission.
        # Existing runner owns locks, exact launch, seeded Data and child cleanup.
        smoke.execute(a.stage.resolve(), a.sdk.resolve(), a.output.resolve(),
                      a.stage.resolve() / 'earned-save.json', [], 30, 1)
    finally:
        atomic_json(a.output / 'captured-buttons.json', captured)


if __name__ == '__main__':
    main()
