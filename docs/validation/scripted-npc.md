# Source NPC script ownership candidate

Prepared on `wip/scripted-npc` after merging exact foundation candidate `e9cba41`.
This is implementation preparation, not native acceptance. No Simulator was run.
The root integration worktree and its campaign Source freeze remain separate.

NPCMotion owns tracked source actor poses during both autonomous and scripted
movement. EventState claims an opaque lease per actor, starts bounded cells,
advances each cell through eight native source-art frames, and releases every
lease on exit or failure. Leases survive intervening dialogue and bind the
attachment epoch, actor identity, event owner/epoch, player, session and zone.
Reattachment, removal, event exit and session/zone replacement reject stale
advancement. The existing bespoke Oak scene remains separate. Reusable move-npc
rejects untracked temporary actors; its former temporary BLUE test now verifies
that rejection, and the new suite moves the real tracked Mart WALK actor.

Each script cell reserves its origin and destination. NPCMotion checks source
collision, directional tile rules, player reservations, other actors and protected
warp/connection cells before starting. Interpolation never changes the completed
actor value. Cancellation restores that value; completed cells and their facing
survive. Script updates draw neither world nor rules RNG. On release, autonomous
control resumes from the completed position with its prior phase/delay timers.
Already moving autonomous actors must settle before a claim; scripts do not steal
an incomplete autonomous cell. Overlays already prevent saving; no script phase,
save-schema change or new RNG owner was introduced.

Optional `script_positions` on an actor's own stable-ID SourceEvents object
descriptor is a list of `{x=..., y=...}` positions in runtime padded coordinates.
It is bounded to 64 unique integer positions (0–1023), detached on read, and checked
against the map's dimensions. Only those explicit positions extend normal
standing policy, and neither collision nor protected cells can be exempted.
Autonomous steps still use the original home bound and direction selector through
`canWanderStep`. An actor left outside its normal range stays there until another
script moves it back; autonomy cannot wander through the declared script route.
No shipped descriptor gains positions or new story content in this candidate.
The native STAY witness uses a scoped test metadata adapter for the real Mart
Super Nerd at (7,5), declaring (7,6); the adapter is restored after each case.

The new SDK suite covers source-art timing/reservations, unchanged RNG, completed
pose codec persistence, partial cancellation, resumed autonomy, stale attachment,
event/session/zone tokens, collision/occupancy/protected exits, and explicit STAY
placement. The fixture replaces only the executor queue after entering a real
source dialogue; it is supplementary contract evidence, not a natural journey.
It does not claim disk-restart, screenshot or hardware acceptance. Root should
inspect the animated source art and final pose in its native integration run.

Exact registration is in `docs/plans/scripted-npc-registration.lua`; add those two
Lua lines to `tools/harness/dev_imports.lua` near the existing event suites. Main
and the root's overlay registration are intentionally unchanged here.

Worker checks: 43 scoped host tests passed, plus all 49 `make test-harness` tests.
The harness and a separate staged build with the new suite explicitly registered
both compiled using the installed SDK. Evidence is under
`~/Developer/Pokemon-PlayDate-env/evidence/scripted-npc-build-20261026-final2` and
`scripted-npc-contract-compile-20261026-final2`. SDK contracts have not executed.

Root acceptance commands, after registering and merging in the integration tree:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
python -m unittest tools.tests.test_source_events tools.tests.test_source_map_pipeline tools.tests.test_motion_profile tools.tests.test_motion_render tools.tests.test_motion_journey -v
make test-harness
python tools/harness/run.py --build-only --output "$POKEMON_ENV/evidence/scripted-npc-root-build-UNIQUE" snapshot
python tools/harness/run.py contracts catalog --output "$POKEMON_ENV/evidence/scripted-npc-root-sdk-UNIQUE"
python tools/visual/compare.py docs/validation/catalog-pewter "$POKEMON_ENV/evidence/scripted-npc-root-sdk-UNIQUE/frames" --protected-preservation --report "$POKEMON_ENV/evidence/scripted-npc-root-sdk-UNIQUE/comparison.json"
```

Run the root's usual full host gate and real event/trainer/healing journeys on the
integrated commit. The existing frozen coverage fingerprint requires root review;
this worker did not change the ledger, coverage matrix or native acceptance state.
