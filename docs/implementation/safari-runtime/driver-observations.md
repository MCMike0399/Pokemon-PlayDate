# Safari observations and real input for the 5.5b driver

This replaces the two Safari API unknowns in driver packet `76c372ad`; it does
not remove that packet's integration/runtime blockers. Root/driver must wire the
existing `midgame-state` projection to `SafariRuntime.observe(game)` after the
unapplied root hooks and map worker package are installed. No new harness
command, fixture, driver contract or durable field is supplied.

## Detached observation contract

Every table below is a defensive copy from the actual Safari owner. Observation
never starts a controller, draws RNG, advances a cell, or infers a receipt.
Missing `lastStep`, `lastPassage`, `lastBattle` and `lastTurn` are absent/nil.
They are ephemeral and are not promised across process restart. Durable
`active/steps/balls/ending` come directly from `session:safariData()` and do
survive schema-4 Save/Continue. Read those counters again after actual Continue;
compare the complete accepted codec through the driver's existing path.

- Top level: `sessionInstalled`, `battleRegistered`, `active`, `steps`, `balls`,
  `ending` (`none`, `steps`, `balls`), `surfReceived`, `teethFound`,
  `teethReturned`, `strengthReceived`. Reward facts are the existing source
  session flags, not new completion flags or inventory guesses.
- `battle`: `active`, `phase` (`message`, `command`, `action`, `closed`, or
  `unregistered`), `enemy` (species), `command` (`none`, `ball`, `bait`, `rock`,
  `run`), `outcome`, `balls`, `selected` (1-based), `lastFailure`, `encounter`
  (controller entry serial), `turns` (successful commits in that encounter),
  `catchRate`, `bait`, `anger`. `menu` has `active`, `columns=2`, and the actual
  `options={"BALL","BAIT","ROCK","RUN"}`. Only use menu selection when both
  `battle.active` and `battle.phase=="command"` and `menu.active` are true.
- `battle.lastTurn`: `sequence`, lowercase `command`, `before` and `after`
  Safari tuples, `outcome`, `receipt` and optional `destination`. This is set
  only after `session:commitSafariBattle` succeeds. `receipt.capture` is the
  actual Capture result: `ballId="safariBall"`, `caught`, `critical`,
  `displayShakes`, source-adjusted `catchRate` and Gen V thresholds/rolls.
  `destination` is the existing recruitment owner's party/storage receipt.
  BAIT/ROCK/RUN have no capture receipt and consume no Safari balls.
- `lastBattle`: `kind` (terminal outcome), `species`, `encounter`, `turns`,
  `lastTurn`, `resources`. Published only after the exit-time Safari ball check
  commits. Outcomes are `caught`, `fled`, `run`, `out-of-balls`; `command` is
  never a completed battle. No XP, payout, Pickup, attack or ordinary bag owner
  is invoked. Capture can fail honestly and the Pokémon can flee.
- `passage`: `active`, `phase` (`announcement`, `before`, `fade`, `after`,
  `failed`, `closed`, `unregistered`), `kind` (`admission`, `early-exit`,
  `continue`, `forced-return`, `none`), `stepIndex`, `lastFailure`. `stepIndex`
  indexes the current script segment; it is not a resource counter.
- `lastPassage`: `kind`, `ok=true`, `countedSteps`, `before`, `after`,
  `moneyBefore`, `moneyAfter`, `location` (committed stable `zone_id`, runtime
  padded `x`, `y`, `facing`). Published only after the atomic session passage
  commit succeeds. Cancelled/failed passages never manufacture this receipt.
- `lastStep`: `sequence` (per-session ordinary completed-cell serial), stable
  `zone`, runtime `x`, `y`, `before`, `after` Safari tuples. Published only when
  the settled ordinary Player cell commits its Safari step. Passage cells use
  `lastPassage.countedSteps` instead. No idle frame, overlay, partial cell,
  failed move or duration estimate increments either counter. Read the actual
  live Player/map observation for ordinary location; session location is
  captured by the existing traversal/save owners.

## Real input sequence and assertions

1. Walk through the installed Fuchsia gate to source `(4,2)` (runtime x adds
   gate padding). Source `(3,2)` also triggers and uses the existing event
   movement owner to align right. Ordinary A interaction with worker 1 only
   greets; the exact entrance cells trigger admission. Dismiss source pages
   with A, then select YES with A (NO uses down then A; B also cancels).
   `midgameYesNo(callback)` owns this menu. It leaves the inherited two-argument
   `serviceChoice(options,callback)` API unchanged.
2. Dismiss payment/PA pages. While `safariPassage` owns input, release controls
   and wait for its real Player cells: up twice in Gate, Center source warp 2,
   then up once. Assert completed `lastPassage.kind=="admission"`, fee exactly
   500, active true, 30 balls, steps 499, ending none, source Center `(15,24)`.
   The raw grant is 502; three actual scripted cells account for the difference.
   A decline or insufficient balance walks down one and publishes no admission.
3. Walk grass with ordinary inputs until the real encounter/iris transition
   opens `safariBattle`. Dismiss the intro with A until phase command. Menu is
   row-major: BALL=1, BAIT=2, ROCK=3, RUN=4. Starting from BALL, right selects
   BAIT, down selects ROCK, down+right selects RUN. Send discrete presses and
   observe `selected`; A commits. B on this menu leaves it open. During action
   release controls; during message use A until command or battle exit.
4. Observe each successful turn before sending another input. BALL must advance
   `turns` and report `lastTurn.before.balls-after.balls==1`, unchanged steps,
   capture ballId safariBall and actual caught result. Compare the existing
   inventory/party observations to show no ordinary bag ball was spent and no
   XP/money was awarded. BAIT/ROCK change the actual battle catch byte/counters;
   they and RUN retain balls/steps. If an enemy flees before the next command,
   obtain another natural encounter; do not seed or demand a guaranteed catch.
   `lastBattle` retains the last committed turn after the overlay closes.
5. For step exhaustion, use real completed walking cells and record `lastStep`.
   With settled admission at 499, 499 further counted cells reach zero with
   ending none; the next cell sets ending steps (Blue checks zero before
   decrement). Battle/dialog idle time spends none. Observe the final step's
   before.steps=0, after.steps=0, after.ending=steps. Forced return then opens
   announcement; dismiss with A, release controls for fade and three down cells.
   Assert `lastPassage.kind=="forced-return"`, before.ending=steps, inactive,
   ending none, balls=0, Gate source `(3,3)` and unchanged money. Those exit
   cells do not spend the now-ended budget. No fixed elapsed wait proves this.
6. A last BALL recruits first if caught. After its outcome pages close,
   `lastBattle.resources.ending=="balls"`; forced return uses the same path,
   with before.ending=balls. Do not require a catch to prove ball depletion.
7. Walking back from Center uses the source Gate return warp at y=0 and triggers
   “Leaving early?”. YES stages three down cells, clears active/ending, retains
   the source tuple's unused ball/step counters, and charges no fee. NO uses the
   matching Center warp (1 from gate source x=3, 2 from x=4), charges no fee and
   retains counters. `lastPassage.kind` is early-exit or continue respectively.
   These counters cannot be used for a battle while inactive. A new admission
   replaces them with a fresh 502/30 grant. Existing Escape Rope publication
   clears active and balls through SafariGame.escape; no separate callback or
   refund is added here.

The approved capture hybrid is explicit: Gen V Q12 HP/status/critical/shake
calculation with Blue's bait/rock-adjusted catch byte and Safari Ball multiplier
1.5. Ordinary Capture rejects Safari Ball. The same three existing SDK behavior
case names remain in `Source/dev/safariServicesContracts.lua`; they compile here
and must run under root after integration. Natural input evidence remains the
driver's responsibility. No Simulator, device or USB was used in this port.
