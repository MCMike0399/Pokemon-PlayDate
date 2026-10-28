# Battle presentation and QoL handoff

Prepared on `t3/battle-presentation-qol`, after merging exact `3cc674d`.
Root owns runtime acceptance. No Simulator, audio changes, push or delegation.

## Commits and integration

1. `636a852`: first independent packet: display HP drain, EXP gauge fill across
   level edges, opaque learning canvas, Gen 1 evolution result wording.
2. `e27bd09`: application options, default fast text/held A, B running, title art.
3. `1d0bb6d`: trainer entry/sendout/recall/faint presentation, ten type motifs,
   class move scoring, SHIFT/SET behavior, nine game behavior contracts.

Apply [the tiny root patch](battle-presentation-qol-root.patch) after the code.
It registers `OptionsState(game)` and the new SDK contract suite. Class imports
are already owned by TitleState/Dialog/Battle; no extra production import is
needed. The patch does not add an audio call. Root/audio A owns that bridge.

`GameOptions.textSpeed()` returns `SLOW`, `MEDIUM` or `FAST` (default).
`GameOptions.battleAnimations()` returns a boolean (default true).
`GameOptions.battleStyle()` returns `SHIFT` (default) or `SET`.
`get`, `set`, `cycle`, `save` expose the preferences editor. Values are validated,
loaded lazily from app datastore `game-options`, and saved on leaving Options.
Neither New Game nor an adventure codec owns these settings. Options is offered
from Title and Pause. Short stationary B taps open Pause on release; directional
B gestures run. Normal steps stay eight frames; running uses four. Ledges and
scripted escort movement retain their existing timing and RED frames.

Presentation requests suspend the existing battle coroutine. A rules-only
Battle without a scene has no cosmetic waits. HP/EXP display values live on the
scene, never flow back into Pokemon, and never draw RulesRNG. Animation OFF
skips move/entry/exit effects and flash/shake; HP and EXP remain legible gauges.
SHIFT is a free change before a trainer replacement; ordinary voluntary switches
still spend the turn. Class scoring uses the pinned Gen 1 layer table with the
Gen V type chart and basic wasted-status/immunity safeguards for every class.
This packet implements move selection, not new trainer item or switching policy.

## Focused integration follow-up

New packed guards and callbacks are expanded without reformatting ancestor code.
Trainer identity now comes from `class_source` or explicit stable encounter IDs;
both move AI and portraits read that canonical class rather than the displayed
name. The source-data audit resolves all 50 registered source trainer identities
to an AI policy and portrait, including the two early RIVAL1 encounters and
S.S. Anne's RIVAL2. No shared registration hook is required for these encounters.

SHIFT selection now requires a live script invitation. Cancelling Party restores
CHANGE/KEEP immediately, and a rejected Party open leaves that choice visible.
The existing AI and SHIFT cases cover these paths; the suite remains nine cases.
Production and contract-module SDK compilation pass. Runtime input verification
still belongs to root; no Simulator was launched.

## Validation performed

- Production `make compile`: passed on Playdate SDK 3.1.2.
- New contract module compiled with the SDK: passed. Its nine tests have **not
  been executed**; root must run them with the integrated SDK suite.
- Title/trainer generator `--check`: all 49 new images match pinned input pixels.
- `git diff --check`: passed. No protected Pokemon/tile/NPC/RED art was rewritten.

Title art and all 47 class portraits use the existing battle-art reader and
threshold converter, plus integer scaling. Inputs, class/picture tables and AI
sources are pinned in `tools/references/title-art.json`. Chief follows its
actual shared Scientist source label. Title uses the existing Blastoise front
art. Root still needs native image review; compilation is not visual acceptance.

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python3 tools/generate_title_art.py --reference-root "$POKERED_REFERENCE_DIR" \
  --output-dir Source/images/title --check
make compile
```

## Root's playable screenshots and motion witnesses

Use one identified private root-owned SDK session from an earned accepted save.
Keep the accepted save chain intact. Run the integrated contracts, then inspect:

- A real damaging hit: capture four-frame intervals through HP drain; numerical
  HP and bar must converge together. Holding A must not skip the drain. Capture
  a natural EXP award crossing a level: old bar fills to its edge, next bar
  starts at zero, and final EXP settles before learning opens.
- Learning message, replace, confirm and stop pages: no enemy HUD or battlefield
  peeks through. A supplemental full-moveset fixture may witness this UI if the
  earned save has no pending choice; label it separately from natural play.
- Natural evolution: `What? ... is evolving!`, source/target alternation, then
  `... evolved into ...!`; a separate B cancellation shows the source and the
  stopped-evolving message. Preserve existing cancellation/domain contracts.
- A trainer battle: portrait and challenge, portrait exits, sends-out text,
  ball arc/burst, then player's Go/sendout. Voluntary switch shows the outgoing
  Pokemon recall before the incoming sendout. Faint drops below the platform.
- A trainer with reserves: SHIFT offers CHANGE/KEEP; cancelling Party returns
  to that choice; changing spends no extra opponent attack. SET skips it.
- In a supplemental native battle set, record the ten motifs using Normal,
  Fire, Water, Grass, Electric, Ice, Poison, Rock, Psychic and Flying moves.
  Dragon/Fighting/Ground/Steel/Ghost/Dark/Bug reuse their mapped motif. Repeat
  with animations OFF: no motif, portrait motion, ball wait, flash or shake.
- Title: source logo/Blue wordmark and Blastoise, both normal and save-recovery
  menus. Open Options from Title and Pause; change all three values, leave with
  B, restart with the same private app data and verify persistence. New Game
  preserves preferences. Check slow/medium/fast and held-A dialogue in battle
  and the field. Menus continue to require distinct button presses.
- Walk one tile without B and one with B: eight/four frames, unchanged RED art.
  Tap B while stationary, then hold B with direction and release: Pause opens
  only for the short stationary gesture, and walking resumes at normal speed.

Record the battle/EXP/learning and trainer/switch/faint sequences in real time;
include display-transform captures for shake and normal PNGs for HUD inspection.
Run the protected catalog comparison on the integrated source before acceptance.

## Deliberate fidelity rows for root to add

| Area | Deliberate policy |
| --- | --- |
| HP/EXP | Display-only HP interpolation and visible EXP gauge/level-edge fill on Playdate; rules commit at their existing checkpoints. Blue did not show an EXP gauge. |
| Input | Hold B runs at four frames per normal tile; short stationary B release opens Pause. Ordinary walking/RED art and ledges stay unchanged. |
| Text/options | FAST by default, held A advances text; app-global preferences persist outside adventure slots. SHIFT is the default, SET available. |
| Battle effects | Ten deterministic 1-bit motifs cover seventeen Gen V types, with an OFF preference; these are native adaptations rather than original bytecode animations. |
| Trainer AI | Gen 1 class layer membership, modern type chart, and wasted-status/immunity safeguards even for source random classes; seeded random selection among minimum-score ties. |
| Title | Pinned original logo/Blue wordmark and existing Blastoise art composed for 400x240. |

## Proposals only — awaiting approval

- Crank: recommend optional menu/list scrolling, with D-pad always available.
- Registered key item: recommend a field-only A+B chord and explicit Bag registration.
- Bag sorting: recommend a manual Sort command; preserve key-item grouping and stable ties.
- Reusable Gen V TMs: recommend reusable TMs with existing compatibility/move-learning confirmation.

None of these four proposals is implemented.
