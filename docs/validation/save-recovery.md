# Confirmed New Game and damaged-save recovery

A confirmed New Game must be able to save after damaged, unsupported or conflicting prior save files. The existing SaveStore owner archives and verifies every observed old published/candidate byte before replacement. Title YES binds a one-shot exact-observation ticket to the installed session. Ordinary boot, Continue and persisted receipts grant no new replacement authority. Field and trusted PC saves share publication authority; failures preserve the in-memory adventure and expose explicit recovery. Archive capacity64 is a safe-fail bound, with no automatic deletion or management feature.

Run the dedicated actual two-process qualification from a clean checkout:

```
python3 tools/harness/save_recovery.py --output /private/tmp/pokemon-save-recovery-UNIQUE
```

Use `--sdk /path/to/PlaydateSDK` if needed. Compile only, without launching Simulator or touching SDK Data:

```
python3 tools/harness/save_recovery.py --build-only --output /private/tmp/pokemon-save-recovery-build-UNIQUE
```

This uses the normal harness Source snapshot/compiler with **no Source overlays**. The dedicated wrapper seeds only a fresh owner-locked private UUID Data directory, refusing all preexisting files except that lock. It seeds exactly three known damaged save files, including binary bytes, records their immutable hashes, and delegates the normal process lifecycle. The case lives under `tools/harness/cases/`, intentionally outside the automatic scenario suite because it requires this seeder.

Actual input drives Title -> NEW GAME -> explicit YES -> the ten original opening lines -> Pause Save -> saved/backup explanation -> confirmed process exit -> fresh process Title CONTINUE -> original bedroom. No gameplay fixture or forged session/envelope is used. The harness records different PIDs, stops each owned process and preserves stopped-generation evidence. `native-recovery-proof.json` is required: the independent verifier checks every original byte, strict sidecar/envelope fields and bounds, checksum/receipt binding, exact planned target, unknown leftovers and unchanged durable files across Continue. Failed proof changes the outcome to failure rather than leaving a successful result.

Inspect the captured Title confirmation, saved text, backup explanation, restarted Continue and continued world. No compile/test count substitutes for native inspection.

Offline independent verifier tests (no network, Simulator or fake SDK):

```
python3 -m unittest tools.tests.test_save_recovery_evidence -v
```

Seventeen tests preserve the original corruption/receipt/path checks and reject boolean/float/string schemas, unknown/missing headers, malformed payload types, file/payload byte-limit violations and checksum mutation. Python schema validation uses `type(schema) is int`, avoiding `True == 1`. This host verifier checks generic saved-envelope integrity, not every SessionCodec domain invariant; actual SDK load supplies domain validation.

Read-only requalification of an already stopped native output, without rerunning Simulator:

```
python3 -c 'from pathlib import Path; import json; from tools.harness.save_recovery_evidence import verify_run; print(json.dumps(verify_run(Path("/path/to/completed/output")), indent=2))'
```

The production implementation was accepted by root with 1089 SDK passes and an inspected actual two-process journey; the portable runner itself must be run on the integrated checkout before claiming its own native proof. This qualification closes a save correctness defect, not the Pallet-to-Brock or full-game goal.
