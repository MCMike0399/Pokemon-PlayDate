# Native audio SDK probe: compile-only packet

Branch `wip/audio-sdk-probe` starts at exact main
`27443afcc63c9a103a6663876a36e9c67bd80673` (fast-forward merge reported already
up to date). No game Source, existing audio tools, manifest, ledger, coverage or
baseline is changed. Research was read with `git show`: `9a1cf87`'s
`docs/research/audio-pipeline.md`, `9c5ec44`'s `docs/research/audio-parser.md`, and
`8def326`'s renderer packet. Their files need not be merged to use this probe.
The offline report at
`~/Developer/Pokemon-PlayDate-env/evidence/audio-offline-renderer-v1/final/summary.json`
is host-math evidence with fidelity and SDK acceptance still pending.

## Verification completed

Twelve focused host tests pass without skips. Both arms compile with installed
SDK **3.1.2** using its real `bin/pdc`. Retained evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/audio-sdk-probe-compile-v3/`.
`summary.json` explicitly says both runtime arms were not executed. Its staged
source and compiled manifests were independently rechecked against the files;
asset identities agree between arms, session IDs differ, and neither private
SDK Data directory exists. Host tests exercise argument bounds, immutable
manifests, exact result identity, the final publication barrier, global lock
contention, foreign Data preservation, launch failure, bounded cancellation and
exact child cleanup. Process doubles test host lifecycle only, not SDK behavior.
No fake SDK or Lua substitute is used to establish API behavior.

**No Simulator, device, audio playback or listening was performed.** Compilation
checks Lua syntax and asset packaging; it cannot establish constructor support,
callback semantics, loop counts, timing, underruns, gating or audible output.
There is no backend recommendation yet.

## Commands

Compile again from the repository root; output directories must be new:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m unittest tools.tests.test_audio_sdk_probe -v
python tools/audio/sdk_probe.py --output "$POKEMON_ENV/evidence/audio-sdk-probe-compile-next"
```

Only the root orchestrator, when it owns the runtime lane, may run this next
command. `--runtime-owner root` is an explicit role assertion, not `sudo` or an
OS authentication mechanism. This worker did not run it:

```sh
python tools/audio/sdk_probe.py --execute --runtime-owner root --output "$POKEMON_ENV/evidence/audio-sdk-probe-runtime-next"
```

The default `--mode both` compiles and runs streams, stops/reaps that exact child,
then prepares a fresh sequence arm and child. Each arm has a unique session,
bundle ID and private Data directory. `--mode streams` or `--mode sequence`
selects one fresh arm. Runtime waits are bounded to 35 seconds per arm by default
(`--timeout` range 20–90), plus a three-second cancellation barrier and bounded
terminate/kill waits. The CLI is Simulator-only; it has no device path.

Muted is the default: every source gets zero app gain before playing. System
volume is read and recorded, never changed; there are no OS-volume commands,
microphone calls, recordings or permission requests. If the root later explicitly
needs audible playback, add `--audible` to the execution command; app source gain
is capped at 0.03. This is not a calibrated acoustic level. Audible mode never
raises system volume.

## Installed primary API contract

The primary reference is the selected SDK's `Inside Playdate.html`; `build.json`
records its SHA-256, version, compiler hash and path. These are the actual installed
3.1.2 anchors used by the implementation:

- `f-sound.synth.new`: `synth.new(sample, sustainStart, sustainEnd)` accepts PCM,
  not ADPCM. `f-sound.sample.new-path` can fail with nil/error. Such failure is
  reported; there is no oscillator/sampleplayer fallback.
- `m-sound.sequence.addTrack`, `m-sound.track.setInstrument`,
  `m-sound.track.addNote`, `m-sound.sequence.setTempo`,
  `m-sound.sequence.setLoops`, `m-sound.sequence.getCurrentStep` and
  `m-sound.sequence.play` describe the one-clock, four-track arm.
- `m-sound.fileplayer.play` starts immediately and returns success/error.
  Fileplayers have **no documented `playAt` API**. Four calls are serial; their
  audio-device clock brackets measure call skew, not waveform onset.
- `m-sound.fileplayer.setLoopRange`, `m-sound.fileplayer.setLoopCallback`,
  `m-sound.fileplayer.setFinishCallback`, `m-sound.fileplayer.getOffset`,
  `m-sound.fileplayer.didUnderrun`, `m-sound.fileplayer.setStopOnUnderrun`
  provide stream observations. `stop()` also invokes the finish callback.
- `m-sound.instrument.addVoice` documents stealing when its single voice is
  occupied. `m-sound.instrument.playMIDINote`, `m-sound.synth.noteOff`,
  `m-sound.synth.isPlaying` and `m-sound.synth.setADSR` support the control phase.
  No future-time instrument calls are needed; their relative-time convention is
  not confused with synth `playNote`'s absolute-time convention.
- `f-sound.getCurrentTime` uses audio-device seconds.
  `f-getSystemVolume` is a read-only system-volume observation.

## Fixture and observations prepared for root

Both arms use the same four generated mono PCM16, 44,100 Hz markers, each exactly
5,292 frames / 120 ms. Frequencies and phases differ per voice, with a peak of
1,500 / 32,767. These are **synthetic phase markers**, not renderer music or an
APU fidelity experiment. WAV/PDX and complete staging stay in environment evidence.

Streams use four fileplayers with explicit 0.25-second buffers, loop range
0–0.12 seconds and finite repeat count 101 to request 100 loop boundaries. Each
voice retains callback clock/offset/frame records, finish state, underrun flags,
first-to-last drift and first-loop callback skew. Fewer than 100 callbacks or an
underrun finish fails the arm. A callback timestamp may reflect delivery latency.

The second arm loads those PCM samples into four sample-backed synths, each in
its own one-voice instrument on one SDK sequence. Tempo is 100 steps/second,
loop range 0–12 and finite loop count 100. The note lasts eight steps with a
zero-velocity extent event ending at step 12; an unexpected SDK sequence length
fails explicitly. Step position, active state and completion time are recorded.
The SDK supplies no sequence loop callback or documented synth sample cursor:
finite configuration plus completion is the prepared loop witness. Sampled step
wraps cannot count every loop during a stalled frame. The 12-second comparison
is a model expectation; root must inspect the SDK's endpoint/count behavior.

Both arms record 30 FPS update timing, Lua heap KB and sound-device time, plus a
single intentional nominal 200 ms frame stall with before/after native state.
The busy wait is bounded by time and an iteration cap; record the actual duration.
No notes are scheduled from frames during the loop phase. This prepares a check
of audio progression across a stalled game update, not proof of independence
before the root runs it.

After loops end, four serial control exercises record per-voice mute/readback,
replacement/steal requests, release state, per-side gain and errors. The sequence
arm requests another note on each occupied one-voice instrument. The stream arm
uses explicitly labeled stop/restart replacement and stop release; it makes no
claim of native synth-style stream stealing or envelopes. Unexpected mute or
release state fails. Zero-gain runs cannot qualify acoustic panning. Synth
underruns have no documented metric and remain unavailable, not inferred zero.

`getOffset()` is an SDK seconds cursor. Offset spread near wrap boundaries is
discontinuous, clock-phase differences have unknown cursor granularity, and
neither is waveform sample proof. Heap includes instrumentation and excludes
native allocations; Simulator timing is not device capacity, CPU or memory proof.

## Ownership, identity and publication

Execution holds the existing `OwnerLock(run.runtime_lock_path(sdk))` across both
serial arms, before preparing any runtime job. `execute` requires that live lock.
Each new Data directory has another owner lock; collisions fail without adopting
or deleting foreign data. Launch uses only the exact Simulator binary and private
PDX via `Popen`. Cleanup terminates/reaps that child only and removes only the
fresh directory created by this invocation. Root evidence is retained.

`build.json` retains revision/dirty state, input and compiled manifests, SDK/doc/
compiler fingerprints, and hashes of the probe plus imported harness host tools.
Their source copies are retained under `tool-sources/`. Source, tool, asset,
mode, audible setting, loop count, session and bundle identity are bound by the
probe ID. Source and PDX manifests are checked immediately before launch.

The runtime accumulates bounded observations. Completion/error/cancel invalidates
callback generation tokens, replaces `playdate.update` with a no-op, stops sound
sources, then publishes `RuntimeSnapshot.json` via temporary file/rename. Only
afterwards does it publish `done.json`. The host waits for this final barrier,
checks both exact identities and stopped status, and archives the stable snapshot.
A timeout requests an identity-bound cancellation and waits at most three seconds.
Missing barrier, early exit, stale identity, runtime error or incomplete arm fails;
raw diagnostics can be retained without being called finalized results. Root must
review the snapshots before choosing a backend. No production integration follows
automatically from this packet.
