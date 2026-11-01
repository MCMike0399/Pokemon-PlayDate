"""Compile the real helper's read policy with host transport-error inputs.

No AX request, Simulator, game SDK execution, owner lock or GUI action occurs.
This checks bounded error recovery, not native application responsiveness.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

TESTS = r'''
do {
    var calls = 0
    let recovered = try copiedAttribute("AXTitle", "host-test") { value in
        calls += 1
        if calls == 1 { return .cannotComplete }
        value = "ready" as CFString
        return .success
    }
    try require(calls == 2 && recovered as? String == "ready", "transient recovery differs")
    calls = 0
    let immediate = try copiedAttribute("AXTitle", "host-test") { value in
        calls += 1
        value = "first" as CFString
        return .success
    }
    try require(calls == 1 && immediate as? String == "first", "successful read repeated")
    for (status, expectedCalls) in [(AXError.cannotComplete, 2), (.invalidUIElement, 1)] {
        calls = 0
        var refused = false
        do {
            _ = try copiedAttribute("AXTitle", "host-test") { _ in
                calls += 1
                return status
            }
        } catch { refused = true }
        try require(refused && calls == expectedCalls, "persistent/invalid failure did not refuse")
    }
    for status in [AXError.noValue, .attributeUnsupported] {
        calls = 0
        let absent = try copiedAttribute("AXTitle", "host-test") { _ in
            calls += 1
            return status
        }
        try require(absent == nil && calls == 1, "absent attribute behavior changed")
    }
    calls = 0
    let absent = try copiedAttribute("AXTitle", "host-test") { value in
        calls += 1
        value = "discard this failed result" as CFString
        return calls == 1 ? .cannotComplete : .noValue
    }
    try require(absent == nil && calls == 2, "failed read leaked a stale value")
    print("7 host AX-read policy checks passed; no native AX or SDK requests")
} catch {
    fputs("host policy check failed: \(error)\n", stderr)
    exit(1)
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    helper = Path(__file__).with_name('malloc_history_clear.swift')
    source = helper.read_text()
    marker = 'let started = DispatchTime.now().uptimeNanoseconds'
    if source.count(marker) != 1:
        raise ValueError('helper entry-point boundary changed')
    test_source = output / 'read-policy.swift'
    test_source.write_text(source.split(marker)[0] + TESTS)
    binary = output / 'read-policy'
    subprocess.run(['swiftc', '-O', '-warnings-as-errors', str(test_source), '-o', str(binary)], check=True)
    result = subprocess.run([str(binary)], text=True, capture_output=True, timeout=5)
    (output / 'stdout.txt').write_text(result.stdout)
    (output / 'stderr.txt').write_text(result.stderr)
    (output / 'result.json').write_text(json.dumps({
        'returncode': result.returncode, 'checks': 7,
        'helper_source_sha256': hashlib.sha256(helper.read_bytes()).hexdigest(),
        'scope': 'Host attribute-read error policy only; native recovery remains unmeasured.'
    }, indent=2) + '\n')
    print(result.stdout, end='')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
