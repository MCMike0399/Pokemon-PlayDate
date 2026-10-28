# Offline register renderer

Implemented on `wip/audio-offline-renderer`, starting at **exact parser candidate
`9c5ec44`**. This is host preparation. Hardware fidelity, listening acceptance,
SDK playback and phase/channel-steal feasibility are pending. No Simulator,
playback, ROM, package changes, production edits or push were used.

`tools/audio/render.py` consumes the existing schema-1 register trace, without
reading a ROM or source checkout. It writes a canonical 44,100 Hz signed PCM16
stereo mix and four stereo contribution stems: `pulse1`, `pulse2`, `wave`, and
`noise`. Stereo stems retain NR51 panning and NR50 master levels. All five files
share the same sample grid and duration. No network is used during rendering.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m tools.audio.render --ir /path/to/closed/trace.json \
  --preview-ticks 180 --output "$POKEMON_ENV/evidence/audio-preview-new"
python -m unittest discover -s tools/tests -p 'test_audio_*.py' -v
```

The output directory must be new. The API is
`render(ir, output, preview_ticks=None, max_samples=44100*180)`. A preview must
be inside an already ended or repeated trace. No preview override accepts a
`bound` trace. The default memory/output budget is 180 seconds; an API caller
can explicitly change it. Rendering does not repeat score loops or append a
release tail. A finite cue can leave a DAC bias at its endpoint; that is retained.
`render.json` is written only after successful WAV generation.

`convert.py` is untouched. An unapplied small integration patch is at
`~/Developer/Pokemon-PlayDate-env/evidence/audio-offline-renderer-v1/convert-cli.patch`.
The root can wire that separately after review. RGBDS/byte qualification remains
owned by the independent worker; this packet does not modify `oracle.py`.

## Primary timing inputs

Before implementation, GBdev's authored [Audio Registers] and [Audio Details]
were read. Their exact source files are vendored as `hardware-*.md`, with immutable
revision URLs and SHA-256 in [hardware-pins.json]. These are primary technical
documentation, including links to LIJI32's original SameSuite experiments;
those experiments were **not executed here**. Pin tests check the vendored bytes.
No arbitrary blog or recalled formula is treated as a hardware oracle.

[Audio Registers]: https://github.com/gbdev/pandocs/blob/abeda621759a8e2b322b368eacf4d31ec48eb4df/src/Audio_Registers.md
[Audio Details]: https://github.com/gbdev/pandocs/blob/abeda621759a8e2b322b368eacf4d31ec48eb4df/src/Audio_details.md
[hardware-pins.json]: ../../tools/references/audio/hardware-pins.json

The renderer implements the pulse eight-step duty counters, wave nibble buffer
and output shifts, 7/15-bit noise recurrence, envelope, pulse-1 sweep with shadow
frequency/overflow, length counters, DAC enable, panning and master gain. The
noise representation follows the pinned XNOR/zero-seed description directly.
Wave trigger retains the old buffer; its first new fetch is nibble 1. Pulse
retrigger retains duty position. Frequency writes take effect on timer reload.
Bank-specific wave5 bytes and cry modifiers are consumed from trace writes,
without inventing a common wave instrument or reinterpreting score commands.

Time uses integers throughout. Hardware dots run at 4,194,304 Hz, a score tick
is 70,224 dots, and sample boundaries are multiples of 4,194,304 in a superclock
of `4194304*44100` units per second. Exact rectangular areas are integrated at
every oscillator/frame/write edge; each PCM sample averages one complete sample
interval. This is deterministic box integration, not a bandlimited resampler.
Absolute endpoints use `floor(tick*70224*44100/4194304)`. The fractional tail is
reported, never accumulated as per-tick rounding drift. At 120,000 ticks the
endpoint is **88,602,401 samples**, remainder 3,076,096/4,194,304 sample; rounding
every tick to 738 samples would lose **42,401 samples**. Source time remains
independent of the game's 30 FPS.

The digital DAC model has negative slope, includes enabled-but-inactive DAC
bias, applies NR51 routing and `(NR50 field+1)/8`, and reserves four-voice
headroom. PCM conversion truncates toward zero, with no dither, peak
normalization or clipping. Per-stem rounding can differ from the directly
quantized mix by at most three PCM units when summed. Analog HPF, DAC fade,
speaker response and external VIN are not synthesized.

## Loop and ownership contract

Reports preserve source provenance, canonical IR hash, renderer/pin hashes,
file checksums, absolute sample counts/remainders, intro and candidate loop
boundaries, logical per-voice lease intervals and original ownership/rejection
events. Leases describe suppressed music writes; they are not a promise that
static stem gates recreate dynamic oscillator phase. A combined music/SFX trace
is rendered through the same four live digital voices.

A full-span render compares complete renderer states immediately before the
start/end source ticks, including timer remainders, frame phase and sample-grid
closure, and reports the mix endpoint delta. A short preview explicitly reports
that state comparison is incomplete. Even matching state does not grant
`seamless` acceptance: every result keeps it false pending independent phase and
listening qualification. The implementation does not search additional score
repetitions for a PCM period or export loop chunks as accepted assets.

Lavender and Dungeon1 remain the parser's **120,000-tick search limits** (last
processed tick 119,999). Both existing bound fixtures were submitted to the
renderer, including a one-tick preview request; both were rejected before
creating output. No truncation is presented as a closing loop.

## Qualification and remaining limits

**42 audio host tests pass, zero skips**: 27 unchanged parser tests and 15 new
renderer tests. New fixtures contain literal pulse patterns, periods, envelope
levels, sweep transitions/overflow and noise states. The noise literals were
cross-checked using an independent MSB-first string-shift calculation; sample
counts were checked with decimal rational arithmetic. These mathematical
fixtures are not captured hardware audio. Tests also check wave shifts/buffer,
register bit width, length phase, negative DAC slope, stereo/master gain,
exact integration, shared stem counts, repeat metadata, ownership timing,
no-network deterministic output and fail-closed invalid inputs.

Five controlled mutations were detected: corrupted oscillator period, silent
pulse duty, suppressed noise shift, per-tick rounded clock and inverted DAC.
The small fixture/reference data are checked in; mutation logs and large WAVs
stay outside Git.

Explicit exclusions are also embedded in every render report:

- IR lacks CPU instruction timestamps within a tick. Writes are instantaneous
  in recorded order. Initial DIV-APU phase is a fixed declared convention.
- Pulse trigger low-divider-bit preservation, wave access-window corruption,
  physical model differences and analog filtering/fades are unqualified.
- Active wave-RAM writes, active envelope writes without same-tick retrigger,
  external VIN, writes while APU is off, unknown registers/events/clocks/schemas,
  invalid boundaries and nonclosing traces fail loudly. Envelope zombie mode,
  DIV resets and CPU-speed switching have no supported IR semantics.
- Score recurrence, deterministic hashes and short math fixtures do not prove
  hardware fidelity. Independent APU execution, listening against a source-backed
  reference, SDK backend scheduling and dynamic steal/release phase remain open.

Final representative renders and the checksum/provenance summary are under
`~/Developer/Pokemon-PlayDate-env/evidence/audio-offline-renderer-v1/final/`:
Pallet and Route3 180-tick previews (about three seconds), a battle preview with a scheduled cry,
a complete modified cry, and complete field/battle flute cues. No full soundtrack
was dumped and no audio was auditioned. The checked-in small summary is
[hardware-render-summary.json](../../tools/references/audio/hardware-render-summary.json).
