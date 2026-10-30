# Timer removal-queue candidate

Prepared on `b7a04f08`, SDK 3.1.2. This is a compile/host-checked candidate,
not runtime acceptance or evidence of hardware benefit. Root owns the soft
memory guard, collection-mode experiments and all Simulator/device measurements.
No regions, audio, entry point, bootstrap or boot trace changed.

`tools/generate_timer_runtime.py` derives `Source/CoreLibs/timer.lua` and
`frameTimer.lua` from installed, checksum-pinned inputs. It never writes into
the SDK. The generated files have no added headers: every byte outside the
single replacement below is identical to the original, including comments and
whitespace. The original `SDK_LICENSE.md` is copied byte for byte beside them;
the SDK source retains its original ownership/license rather than receiving
the project's license.

The only replacement, once in each file, is:

```diff
-	timersToRemove = {}
+	for i = #timersToRemove, 1, -1 do
+		timersToRemove[i] = nil
+	end
```

Removal enqueueing, the existing `pairs` drain, timer-list removal and all
callback paths remain unchanged. The private queue is populated only by dense
append operations. Clearing from its last slot through its first drops every
reference after the same drain, without creating the next empty queue table.
It does not touch the active list or move callback execution. Pause, delay,
reverse/repeat, reset, callback arguments, completion and list ordering retain
their SDK implementations. Empty updates still execute normally. Automatic GC
and the game's manual step are untouched. Queue array capacity can retain its
high-water storage after a large batch; entries themselves are cleared. Other
SDK update allocations are outside this patch.

There is no exposed removal-queue flush API in these SDK modules. `allTimers()`
exposes the active list, not the private pending queue. Skipping updates based
on that list can leave duplicate or externally queued removals undrained;
manually clearing the active list would also change removal/callback behavior.
This candidate therefore retains both ordinary update calls.

Reproduce before compiling (the normal build copies these generated files):

```sh
python3 tools/generate_timer_runtime.py --write
python3 tools/generate_timer_runtime.py --check
python3 -m unittest tools.tests.test_timer_runtime -v
make compile
```

`--sdk` selects a local SDK and `--output-dir` allows isolated regeneration.
Version or input checksum mismatches fail before any output is written.
`--check` compares bytes and never repairs files. No build script was changed;
regeneration/checking is an explicit build prerequisite for this candidate.

| File | Original SHA256 | Candidate SHA256 |
| --- | --- | --- |
| timer.lua | `ffc8f98405fb3f8963ccad572fff66cd6de4b9d16efa08003304583297ac0c3d` | `3bec807aa27db0de68e200b2336fb229d4bfec3ee2c390600baed207e5a75768` |
| frameTimer.lua | `7c03955a9853f3fe9da00d3f016150771db3587f341c49a1e2062094110f07ea` | `b7fa5dcab4487a1a6777a1768055dea8255065c167dca2fa6064448db04b1fd1` |
| SDK_LICENSE.md | `b1e5c2c696faaae504e43b19a2f4e850f563f4a04317bd28fd354d2ec3c03905` | unchanged |

Four focused host checks pass: exact derivation/license equality, reproducible
output with non-repairing check mode, changed-input/version rejection and SDK
write protection, and real production PDZ import precedence. The latter decodes
the compiled `main.pdz` and compares each embedded CoreLibs timer payload with
an independently compiled local candidate and original control. Only the
known debug source-name field is normalized; every other byte, including code
and line tables, must match the candidate and differ from the SDK original.
The installed SDK checksums remain unchanged after compilation.

The existing production-build suite has four passes and one unrelated failure:
its frozen harness import list omits the existing transitive
`dev/sessionFixture`. The same failure reproduces with baseline Source and no
application CoreLibs overrides. No fixture was edited to hide it.

Retained production compile, staged Source, log and checksum report:
`~/Developer/Pokemon-PlayDate-env/evidence/p0-timer-runtime-compile-20261029-qhl1p53a`.
No Simulator, hardware, USB or runtime tests ran. Root still needs the existing
timer/presentation lifecycle cases, exact 16 MiB smoke and paired idle hardware
comparisons. Rendering source did not change. Collectible backlog is not an
established retained leak; this candidate makes no allocation-attribution or
measured memory/latency claim.
