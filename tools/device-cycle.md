# Root-only device cycle

This worker packet performs no runtime or hardware acceptance. Root owns the
PDX, BootTrace, test-only auto-lock/error hooks, Simulator and all device runs.
No production source is modified. No USB reader is started at import or startup.

Build a retained **production** stage with the existing builder, then root runs:

```sh
python3 tools/device_cycle.py --execute-root \
  --pdx /absolute/candidate.pdx --build-stage /absolute/retained-build \
  --simulator-gate /absolute/root-measured-gate.json \
  --output /absolute/evidence/fresh-cycle --run-seconds 30
```

Use `tools/build.py --output /absolute/candidate.pdx --stage /absolute/retained-build`
for the existing compile-only build. The cycle checks its retained `Production.pdx`
against the candidate, hashes every source/payload file and records both manifests.
`pdx_sha256` is SHA256 of the payload hash dictionary encoded with Python
`json.dumps(files, sort_keys=True, separators=(',', ':')).encode()`;
`source_sha256` uses the existing builder's fingerprint. Root's gate must identify
both exact hashes, `malloc_pool_mb: 16`, and numeric `measurements` and `limits`
objects containing `heap_live_bytes`, `heap_peak_bytes`, `map_load_ms`,
`battle_start_ms`, `frame_ms`, and `slice_ms`. All measurements must pass the
supplied limits. Root supplies the actual measurements and approved budgets;
the CLI does not change Simulator settings or measure runtime itself.
The locally installed SDK documents the pool menu in *Inside Playdate*,
“Profiling malloc calls in the Simulator”. Do not fabricate a gate from compile
success or reuse one for another payload.

Each invocation runs exactly one bounded cycle. It takes the existing global
runtime lock and the device lock, requests `datadisk`, waits up to 300 seconds,
archives the currently installed PDX's complete hash inventory plus available
logs/identity, copies changed payloads, removes only obsolete PDX payload files,
verifies **every** installed hash, ejects, and sends `run /Games/<name>.pdx`
immediately after serial returns. It waits the requested interval while checking
serial presence, enters data disk and archives logs again. It leaves that disk
mounted. The only pdutil actions used are `datadisk` and `run`; no recovery,
firmware, erase, reset or process-kill commands exist here.

Logs checked are root and `System/Logs` `errorlog.txt`/`crashlog.txt`, and
`Data/<bundleID>/boot-trace.tsv`. Missing logs are explicitly recorded. Before and
after logs retain their hashes, so old files cannot be mistaken for fresh output.
`device-cycle-identity.json` in application Data identifies the candidate; the
actual installed PDX inventory is always authoritative. All phases, command
outputs and failures go to `phases.jsonl`; `outcome.json` never asserts boot
acceptance. A missing serial port after run, or a subsequent command timeout or
failure, stops the invocation with **device needs one A press**. The CLI does
not retry another candidate. Root must stop its outer device loop on this failure
and may continue Simulator-only work. No routine unlock/replug prompt is issued.

Application Data stays untouched except the explicitly named identity file.
`--clear-boot-trace` explicitly archives then removes only `boot-trace.tsv`.
Default behavior preserves saves and prior trace. For an explicitly requested
earned/seed save, pass `--earned-save /absolute/save-manifest.json`:

```json
{
  "directory": "/absolute/earned-slots",
  "files": [
    {"file": "adventure.a.json", "sha256": "<actual SHA256>"},
    {"file": "adventure.b.json", "sha256": "<actual SHA256>"}
  ]
}
```

Both imported hashes are checked before deployment and after each copy. Existing
slots are copied and hash-verified into the fresh evidence directory before either
is overwritten. Missing prior slots are recorded. No other Data is deleted or
replaced. Root must supply earned provenance; this tool checks transfer integrity,
not gameplay eligibility or Lua save-codec acceptance.

Simulator initial launches and restarts now check `lsof` for both `cu` and `tty`
Playdate aliases. A free attached device is permitted. Occupied ports fail within
a three-second ownership check and report exact lsof PID/command/path output;
inability to inspect ownership fails with its concrete error. No reader is killed.
Simulator runs and device cycles share
`/private/tmp/pokemon-playdate-device-<uid>.lock`, in addition to the unchanged
runtime/private locks. A root-owned serial reader must use that same device lock
and **close its file descriptor and release the lock before** pdutil, data disk
or Simulator work. This packet starts no reader, so there is none to close.

Local SDK documentation confirms the `msg <text>` callback and print forwarding
through Simulator, but does not specify raw serial framing/baud or a raw print
capture protocol. Raw capture and message sending are therefore omitted rather
than guessed. No serial controls are added to production. Root can add a bounded
reader later after verifying that transport, with the same device lock.

Host-only validation:

```sh
python3 -m unittest tools.tests.test_device_cycle -v
python3 -m py_compile tools/device_cycle.py tools/harness/run.py tools/harness/restarting.py
```
