# Earned B Gen V move packet — compile-only handoff

Exact prerequisite: `00ce443a32f183599ab073d5944905fdd8c19c0e`.
The preceding B in the brief was a prose label; Root confirmed this exact hash.
Assigned branch: `t3/gen5-b2w2-moves`.
Synchronization merge: `1969bf31`, whose tree is exactly prerequisite tree
`f6320a71f435a075373af33992a4677fe0f0e4a5`.
Logical implementation: `8e08f1f740c684a83b4aad893d72d843bb8b2c19`.
Root should select the logical implementation and subsequent handoff documentation
commit, rather than merge the worker's divergent main ancestry or synchronization.
No other checkout was created or edited.

This packet implements Rest, Snore, Yawn, Foresight and Revenge through existing
production battle owners. It does not establish native, campaign, performance,
device or acceptance results. Root must rebuild its own identified harness,
apply the supplied registration, execute the cases and retain the original
failed earned-log diagnostics alongside the new results.

## Behavior and ownership

- Rest uses the existing `ApplyStatus` type/ability/origin/sleep transaction and
  Pokémon HP owner. At an actual attempt it fails at full HP even with another
  status, or when unable to sleep. Successful Rest replaces the old major
  status, clears its toxic counter, heals fully and leaves other stages and
  conditions alone. It consumes the ordinary sleep-Start RNG draw, then installs
  the fixed duration. The existing persisted counters store blocked actions:
  source time/startTime3 maps to statusTurns/sleepDuration2, with two blocked
  actions then acting on waking. Withdrawal resets that same duration through
  the existing `onSwitchOut`; no codec interpretation/schema change was made.
  Sleep/flinch/confusion/paralysis and PP still use the existing action gates.
- Snore's generated attempt rule allows its queued action through the sleep
  gate, while continuing to decrement sleep. Waking still occurs first; an
  awake Snore fails after spending PP, before target/type/hit RNG. While asleep,
  ordinary accuracy, Ghost immunity, Protect, Soundproof, damage, the existing
  30% secondary draw, Shield Dust and Inner Focus owners apply. Gen5 power40 and
  the absence of Gen6+ Substitute bypass remain source-pinned.
- Yawn is a target identity condition with duration2 at residual order23. The
  placement turn consumes the first tick; the following residual attempts sleep
  through `ApplyStatus`, rechecking current status and sleep immunity. Placement
  fails against an existing status, existing Yawn, sleep immunity or Safeguard.
  The oracle explicitly exempts an already placed Yawn from later Safeguard.
  A narrow validated `yawn` sleep origin retains that distinction. Real target
  withdrawal/faint/terminal cleanup clears it; source withdrawal leaves the
  captured source identity available for expiry. No independent status owner.
- Foresight's concrete effect calls the same existing `odorSleuth` condition.
  Repeated Foresight/Odor Sleuth fails across both move names. It negates Ghost's
  Normal/Fighting immunity while retaining the other type's multiplier, ignores
  positive evasion without deleting stages, and preserves negative evasion.
  Target withdrawal removes identification. No type/stat mutation was added.
- Revenge extends the existing `BattleEffects.round` ledger with source-keyed
  positive opposing move-hit receipts, including fixed hits such as Sonic Boom.
  The raw power doubles only when its current target dealt real move HP loss
  earlier in that same logical round. Residuals, confusion, recoil, costs,
  misses, immunity and protection cannot create that receipt. The raw power
  passes through the existing base-power, damage and ability pipelines. Priority
  remains -4. The ledger survives script yields and clears on actual round exit,
  identity withdrawal/faint and battle close; replacements cannot inherit it.

Legitimate failures now remain failures: full-HP Rest, awake Snore, ineligible
Yawn, duplicate Foresight and unboosted Revenge do not become success claims.
The existing unsupported diagnostics for other moves remain intact. No trainer,
roster, level, AI, move-learning or journey substitutions were made.

## Data and historical guarantees

[provenance.json](provenance.json) records checksum-verified local Showdown
`9b136a8c8cdb860a8ab96fa063f906604e352547` base/Gen8→Gen5 move inputs,
condition/sleep/switch/action/attack-history inputs and the immutable PokeAPI
chain. The qualifier checks actual callback clauses and all inherited overrides.
There was no network fetch or oracle repinning.

Producer epoch 17 introduces only the five requested rows: three concrete
payloads and Snore/Revenge rule fields. There are exactly 425 core rows;
420 unrelated rows remain byte identical to exact B. Original scalar values,
Haze/Clear Smog 16, Reflect 15, Chip Away 14 and every earlier transition remain
exact. The original 424 inverse SHA256 stays
`ad40fd9b5592a4ffeb88dcfc9243cc56034b2f4ea5b2da6bb3f2a8c129da45ea`.
All five HM battle declarations and the schema 4 codec owner remain byte
identical. The field generators still reproduce all 35 artifacts/88 pinned files.

Stale current-epoch assertions now expect 17. Genuine historical 11/13/14/15/16
fixtures explicitly remove later payloads/metadata before exercising the old
inverse; they are not current rows with an old label. Existing rejection tests
remain, plus new deletion, rollback, wrong-rule/type, scalar and extra-effect
mutants. No current coverage or historical acceptance record was rewritten.

## Validation and Root selections

[validation.json](validation.json) lists the exact 24 implementation files,
SHA256 values, all 33 native case names, Root regression selections and retained
build/log paths. The 74 focused host checks pass with no skips. Production and
privately registered harness compile with real SDK 3.1.2, and their owned staged
Source hashes match the logical packet. Compilation is the only SDK activity;
no Lua/stock-Lua substitute, runtime, Simulator, global lock, device/USB/AX,
OpenClaw, Pi/service/network configuration, push or delegation was used.

[root-registration.patch](root-registration.patch) applies to exact B's existing
`tools/harness/dev_imports.lua`. It remains unapplied in this checkout. It imports
`dev/earnedBMoveContracts` and registers `earned-b-moves`; production imports need
no change. Root should run that 33-case group first, then the selected existing
combat, switch, condition, ability, secondary, power, protection, HM and stage
regressions recorded in validation.json. Root's runtime helper owns selection;
this packet adds no selection infrastructure.

Reproduce host and static checks after sourcing the usual project environment:

```sh
python3 -m unittest tools.tests.test_earned_b_move_generation tools.tests.test_move_producer_contract tools.tests.test_charge_move_generation tools.tests.test_protection_move_generation tools.tests.test_rain_move_generation tools.tests.test_move_failure_phazing tools.tests.test_side_move_generation tools.tests.test_roost_move_generation tools.tests.test_poison_fang_generation tools.tests.test_worry_seed_generation tools.tests.test_prebrock_move_generation tools.tests.test_move_critical_generation tools.tests.test_move_target_generation tools.tests.test_field_move_data tools.tests.test_captivate_move_generation tools.tests.test_bide_move_generation -q
python3 -m tools.generate_move_support --check
python3 tools/generate_field_moves.py --check
python3 tools/materialize_field_moves.py --check
python3 tools/qualify_earned_b_moves.py --showdown-cache "$POKEMON_ENV/preparation/move-failure-phazing/showdown" --condition-cache "$POKEMON_ENV/preparation/common-abilities-oracle" --report /absolute/fresh-report.json
git apply --check tools/integration/earned-b-moves/root-registration.patch
```

The older `qualify_stage_reset.py` remains a frozen two-row epoch16 comparison.
Use the new qualifier for the composed epoch 17 tree; it independently preserves
all of that earlier transition history and the original inverse.

## Explicit limits

Ordinary singles with existing producers only. Substitute remains an unsupported
move: Gen5 Snore and Yawn do not bypass it, while Foresight does. Uproar,
Miracle Eye, Baton Pass, Early Bird, Sleep Talk, Magic Bounce/Coat,
Infiltrator, Heal Block, relevant missing items and terrain producers were not
implemented or certified. Their gaps remain explicit; no fake volatile/item/
ability state was introduced to simulate them. Doubles, allied hits and spread
routing are outside this packet. Existing ability and held-item owners retain
only their existing supported interactions.

All 33 new SDK cases are compiled and unexecuted. Root must inspect any native
failures, including fixture expectations, before treating this packet as ready
for campaign or acceptance work. The full Blue game remains unfinished.
