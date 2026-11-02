# Runtime HM battle preparation

Prepared on exact private B `10cb9572f8db3979fd7d3b1ddf517277008b4eeb`.
The full Blue 222-map goal remains unfinished. This packet fixes the five runtime
HM dispatch gaps through actual battle owners; it changes no roster, learnset,
trainer AI, field/travel owner, durable state or save schema.

The initial worktree was a diverged census branch. Synchronization merge
`04f38874f27e1a7f4b0a49fd3459317366503526` deliberately has a tree identical to
exact B. It is separate from logical implementation commit
`36073a1bba0c5c9e6c3ec4b81cad130909018220`. Root should cherry-pick the logical
commit onto B, not merge this worker's census ancestry or synchronization commit.

Cut and Strength use ordinary physical damage/contact. Flash uses the existing
accuracy-lowering DSL and ability/stat gates. Surf uses ordinary special Water
damage, existing absorption/weather/protection hooks and one opposing target in
singles, with no doubles damage reduction. The generated extension uniquely
registers all five HMs and their dispatch declarations after core move loading.
It imports the existing support inventory before extending it; the SDK's later
battle import reuses that module. No additional production import is needed.

Fly extends the existing charge receipt. It spends PP on the first actual
attempt, automatically releases the stored identity without a second PP payment,
and targets the opposing slot after replacement. BeforeMove interruptions,
withdrawal, faint and battle cleanup discard both the lock and airborne state
through that same owner. Forgetting the learned slot cannot forge PP or change
the stored release. The semi-invulnerability gate is independent of accuracy:
Swift and Whirlwind miss; existing Gust, Twister, Thunder, Hurricane and Sky
Uppercut can hit, with ordinary accuracy. Existing living No Guard on either
actor bypasses that gate. Gust/Twister double final damage, before screen
rounding so Light Screen cancels the multiplier without losing odd damage.
Smack Down appears only in the oracle exception list; its unsupported dispatch
remains a gap and is not enabled here.

All 88 primary local cache files passed checksum verification before behavior
was derived. The Showdown base plus Gen8 → Gen5 chain is pinned at
`9b136a8c8cdb860a8ab96fa063f906604e352547`. The generator now checks the inherited
Fly charge and airborne damage clauses in addition to existing HM scalar checks.
The generated field artifacts reproduce. All 425 core move rows remain byte
identical to B. Producer epoch 15, Chip Away's introduction epoch 14, Reflect's
epoch 15, the original 424-row inverse hash and schema 4 remain unchanged.
No producer migration or change to the Haze/Clear Smog rows is needed.

## Root integration and native work

Apply `root-hooks.patch` to register `dev/hmBattleContracts` as suite `hm-battle`
in Root's harness overlay. It apply-checks exact B and was applied only in private
compile staging. It is not applied in this worktree. Root retains ownership of
all native execution, reviews, acceptance and coverage updates. The existing
field contract that expected loud HM failure now checks the supported
registration; actual action assertions live in the new battle suite.

The 25 exact native case names are in `verification.json`. They exercise real
Battle selection, coroutine action resolution, PP and RulesRNG, with bounded
fixtures; they do not substitute a rules implementation. Cases cover ordinary
HM damage/miss/Flash, Normal immunity, Keen Eye, Water Absorb, Protect, Effect
Spore contact, Fly charge/release and lock rejection, zero PP/forgotten slot,
slower release timing, airborne move exceptions, Gust/Twister doubling and Light
Screen, No Guard, status interruption, enemy continuation, opposing replacement,
actual Roar withdrawal and Gust KO, forced replacement and terminal cleanup.
They are compiled only and may require corrections after Root executes them.

Reproduce the host checks after sourcing the normal project environment:

```sh
python3 tools/materialize_field_moves.py --check
python3 tools/generate_field_moves.py --check
python3 -m tools.generate_move_support --check
python3 -m unittest tools.tests.test_field_move_data tools.tests.test_move_producer_contract tools.tests.test_charge_move_generation tools.tests.test_protection_move_generation tools.tests.test_rain_move_generation tools.tests.test_move_failure_phazing tools.tests.test_teaching_data -q
git apply --check tools/integration/hm-battle/root-hooks.patch
```

All 41 focused host checks passed without skips. Production and composed harness
compiled with SDK 3.1.2. Durable build logs, exact staged Source and bundles are at
`~/Developer/Pokemon-PlayDate-env/evidence/hm-battle-preparation-20261101-01/`.
`verification.json` records source fingerprints, owned-file hashes, oracle hashes,
commit identities and compiled native case names. No runtime was launched or
runtime/storage fence acquired. No device, USB, AX, Pi, push or delegation action
was performed.

## Explicit limits

This is singles support. Doubles spread, friendly fire and ally targeting are
unsupported. Dive still has no charge/underwater producer, so Surf's doubled
underwater hit cannot be reached or certified; adding synthetic underwater state
would conceal that dependency. Gravity, Smack Down, Lock-On, Mind Reader and
Substitute remain explicit existing move gaps. There is no new ability or item
producer: Storm Drain, Power Herb and other missing interactions are not
certified by enabling ordinary HM dispatch. Existing owner diagnostics and gaps
remain; no handler was added for these mechanics.

No SDK case was executed. There is no native, campaign, visual, performance,
acceptance or complete Gen V claim. Root's exhaustive census remains untouched.
