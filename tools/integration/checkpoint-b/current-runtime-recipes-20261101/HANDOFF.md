# B physical traversal and native showcase refresh

Host/compile preparation only. Final explicit pin is **4750bd71bc899f810513e71a4ce58fb85a821ccf**,
under the user's subsequent correction. Observed Root HEAD **9542d84d** is a
docs/coverage descendant with identical Source/harness bytes. Both recipes require
that ancestry, clean Source/tooling and exact inventories before/after preparation;
changed Source fails closed. No alternate Root ancestry was merged.

The original requested 635 preparation is retained under `historical/635-preparation`,
including the unsuccessful fingerprint draft and its explicit correction. Full
Source changed at 4750: only `sources` dependency hashes in the Cerulean/Vermilion
dev projections; JSON values outside `sources` compare equal. Production Source
remains identical to 70e015a6. Harness bytes are unchanged from 635, but differ from
the old showcase through contract imports. See `refresh-audit.json`, complete
`source-inventory.json`, `harness-inventory.json` and `validation.json`.

## Compatibility review

Git-object comparison against 565/old e71 inspected the actual battle, encounter,
loader and staging deltas. HM dispatch/Fly, Haze/Clear Smog, Rest/Snore/Yawn/
Foresight/Revenge reach epoch17. The secondary argument no longer aliases Rest:
ordinary ApplyStatus calls the shared implementation with false, Rest has its own
applyRest entry. None changes the DS1 parser, receipts, serial owner or the
Overworld/Battle entry signatures wrapped by the private diagnostic. Encounter
preparation now occurs in Overworld entry; the wrapper still samples only after
that owner succeeds, at settled exploration. No entry/sample allowance changed.

Content reads/generation use chunks-v2/<prefix>/<digest>.json; every 2546 chunk
and all32 indexes compare byte-for-byte against git objects. SourceBindings now
checks its cooperative budget after each object. The fresh qualified Kanto
export/provenance is pinned and production staging compiles successfully. This
is an inspected compatibility rationale, **not runtime compatibility proof**.

The supplied long checkout was already at 4ec64943, beyond named origin bbac7ddf.
Both are preserved separately. Active root_driver, diagnostic, safety recorder,
summarizer, route and source guide are byte-identical to that supplied packet.
Ordinary inputs only; no hardware Save, planner, observer history or new contracts.
All existing ownership, admission, error, cleanup and receipt semantics remain.
Required actual counts stay110 doors/30 maps/20 battles; hard bounds stay160 doors,
240 entries,48 battles,2 hours,20,000 commands/180,000 commanded frames,180 seconds
per battle and30 seconds per command. Hardware per-entry post-GC <=6 MiB; raw
pre-GC <9 MiB. Simulator raw safety and native16 MiB pool remain unchanged.

The only additional private staging change is the explicitly authorized
SaveBuildPolicy literal `production-profile`, recorded in build metadata and a
patch. `production` inside DEVICE_TEST alone still selects deep export. Shared
policy files, normal production and codecs stay unchanged. Hardware Save still
asserts before reaching the save owner. Simulator safety Save is disposable.

Canonical Charmander sequences61/62, Fuchsia Center(3,3,up), all byte/provenance
hashes and ancestry remain exact. Showcase retains genuine pre-Koga Bulbasaur
m55b-earned-fourth marker, actual saved-codec result/newest slot, stopped producer,
accepted A and all external reuse hashes. Strict complete loaded-codec equality
is unchanged. Host import checks prove archived equality only: Root's SDK Continue
must establish new loaded-codec equality; on mismatch retain/report it, do not
rewrite the frozen codec or relax the assertion. The old Source rejection is
retained in `old-showcase-rejection.txt`.

## Root preparation and short safety

Run from the checkout containing this packet. Every output must be fresh.
These are one-shot commands, not worker execution authorization.

```sh
PACKET="$PWD/tools/integration/checkpoint-b/current-runtime-recipes-20261101"
LONG="$PACKET/long_traversal"
SHOW="$PACKET/showcase"
B=/Users/burbujamc/.t3/worktrees/Pokemon-PlayDate/t3-2c976160
SDK=/Users/burbujamc/Developer/PlaydateSDK
E=/Users/burbujamc/Developer/Pokemon-PlayDate-env/evidence
STAGE="$E/b149-long-traversal-root-prepare-20261101-ROOT-01"
CAPTURE="$E/b149-long-traversal-root-capture-20261101-ROOT-01"
CAP_OP="$E/b149-long-traversal-capture-operator-20261101-ROOT-01"
SAFETY="$E/b149-long-traversal-root-safety-20261101-ROOT-01"
OP="$E/b149-long-traversal-hardware-operator-20261101-ROOT-01"
ATTEMPT="$E/b149-long-traversal-hardware-20261101-ROOT-01"
PYTHONDONTWRITEBYTECODE=1 python3 "$LONG/prepare.py" --sdk "$SDK" --output "$STAGE"
PYTHONDONTWRITEBYTECODE=1 python3 "$B/tools/device/simulator_smoke.py" --build-stage "$STAGE"
mkdir "$CAP_OP"
PYTHONDONTWRITEBYTECODE=1 python3 "$LONG/capture_safety.py" --execute-root \
  --stage "$STAGE" --sdk "$SDK" --output "$CAPTURE" --operator-dir "$CAP_OP"
```

Root supplies actual Continue, ordinary Save, Center exit, one genuine battle and
settled return via the existing numbered batches in [long_traversal/RECIPE.md](long_traversal/RECIPE.md).
Finish the recorder, rename/archive its UUID SDK Data using that recipe's exact
snippet, then replay the frozen short route once:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 "$B/tools/device/simulator_smoke.py" --execute \
  --build-stage "$STAGE" --sdk "$SDK" --output "$SAFETY" \
  --earned-save "$STAGE/earned-save.json" \
  --commands "$CAPTURE/captured-buttons.json" --timeout 120 --timing-factor 1
```

Do not record another long Simulator traversal. Raw safety must pass on this
exact build/seed; old compile, plateau, hardware Route17 or other timing reports
do not admit it. Preserve all failed or incomplete evidence.

## Root physical owner

After genuine exact-build short safety and current ownership checks:

```sh
mkdir "$OP"
PYTHONDONTWRITEBYTECODE=1 python3 "$LONG/root_driver.py" --operator-dir "$OP" \
  --execute-root --validate-only --safety-only --build-stage "$STAGE" \
  --pdx "$STAGE/DeviceSmoke.pdx" --simulator-smoke "$SAFETY/simulator-smoke.json" \
  --earned-save "$STAGE/earned-save.json" \
  --output "$E/b149-long-traversal-admission-20261101-ROOT-01" --run-seconds 7200
PYTHONDONTWRITEBYTECODE=1 python3 "$LONG/root_driver.py" --operator-dir "$OP" \
  --execute-root --safety-only --build-stage "$STAGE" --pdx "$STAGE/DeviceSmoke.pdx" \
  --simulator-smoke "$SAFETY/simulator-smoke.json" --earned-save "$STAGE/earned-save.json" \
  --inspect-previous-game PokemonPoC.pdx --output "$ATTEMPT" --run-seconds 7200 --leave-running
PYTHONDONTWRITEBYTECODE=1 python3 "$LONG/summarize.py" --stage "$STAGE" --attempt "$ATTEMPT"
```

Operate the existing fixed itinerary and bounded ordinary UI batches, finishing
only after observed counts and all samples settle. The recipe retains resource,
healing, error/log, import backup and stop policies. USB loss/uncertain completion/
native crash stops attempts: device needs one A; no retry/replug/reset. A long
summary never changes the owner's missing hardware Save or grants acceptance.

## Root showcase admission and capture

```sh
PYTHONDONTWRITEBYTECODE=1 python3 "$SHOW/record.py" --check
PLAYDATE_SDK_PATH="$SDK" PYTHONDONTWRITEBYTECODE=1 python3 "$SHOW/record.py" \
  --compile-only --output "$E/b149-showcase-root-compile-20261101-ROOT-01"
```

The existing recorder requires `--root-gates-verified` even for preflight. It
asserts actual AX/Clear/reclamation verification and full hold release. Neither
this packet nor the worker verified these. Root must inspect actual current
requirements; the referenced historical helper is absent in fixed B. Do not
resurrect census/AX epochs, raise1 GiB or pass a false assertion. A three-second
label caps captured frames, not startup/Continue/cleanup residence. A separately
admitted short preflight may be appropriate, but the unchanged CLI offers no
narrow preflight admission: Root must resolve/review that condition first.

Only when the existing assertion is truthful, use the exact preflight/export/
ffprobe/native comparison commands in [showcase/README.md](showcase/README.md),
then its full capture and companion export commands. Full capture retains the
1 GiB/30 minute guard,16 MiB pool, complete companions, native400x240 pixels and
actual wall time. No resampling, false speedup or audio activation. Root alone
selects a continuous complete trainer battle and the disclosed cutscene/gym
excerpts, checks every chapter and writes the measured60–90 second export plan.

No runtime, safety capture/replay, physical coverage, native preflight/export,
AX action or full capture was performed here. B149 remains unaccepted; main108,
C171 inactive and audio held. Normal hardware Route17 and its measured gain are
separate evidence; production Save2226ms and deep diagnostic8624ms are unmatched.
The packet makes no new playability, latency, map or acceptance claim.
