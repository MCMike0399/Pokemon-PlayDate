# Copycat service preparation

This separate packet starts at C activation packet
`e7249cf459a19296e6573040c23c8272a04934ff`. It prepares only Copycat's Blue
Poké Doll → TM31 service and facing-dependent PC text. It does not activate C,
change its cache/manifest, install link play or claim acceptance.

`tools/references/copycat.json` pins nine immutable inputs at pokered
`af519899719f0754965776faac0e836a3b906e6d`: the script, text, object map, header,
map include table, shared RedsHouse2F block layout, item/event constants and
GiveItem implementation. Raw inputs stay outside Git. The generator compares
both their exact Git objects and SHA256 values, verifies source control order
and projects eight text recipes. Those recipes equal the preexisting pinned
Saffron content exactly; no original content or shared cache was rewritten.

`Source/game/copycatService.lua` registers two reserved stable source IDs:

- `pokered:COPYCATS_HOUSE_2F:objects:1` for Copycat.
- `pokered:COPYCATS_HOUSE_2F:background_events:2` for the PC at source (0,1).

SourceEvents remains the only dispatcher. Copycat returns an ordinary EventState
plan, with the original opening, optional Doll acknowledgement, commit-gated
receipt plus first explanation, full-bag text, or later explanation. There is no
Yes/No offer in Blue, and no new choice is introduced. The small PC delegate
selects My Secrets only when facing up, otherwise Can't See, then uses the same
guarded source dialog/finish methods. It owns no persistent state or actor.

## Transaction semantics

The existing `GameSession:transact` guards false `EVENT_GOT_TM31` and exact Doll
and TM quantities. On its detached bag it adds one TM31 first, then takes one
Doll, then publishes the flag and inventory together. This preserves Blue's
GiveItem-before-RemoveItemByID capacity rule: a full bag cannot exchange its last
Doll to free a slot. A preexisting nonfull TM stack may accept the grant. On any
capacity or stale-observation failure, neither Doll nor flag is consumed.
A successful claim consumes exactly one Doll; subsequent talks never grant
again, regardless of whether the reusable TM was later stored elsewhere.

EventState's existing valid/top/epoch/serial guards protect dialog callbacks and
its transaction handles concurrent inventory/flag changes. Cancelling before
commit grants nothing. Cancelling receipt presentation after commit cannot undo
the completed exchange. Success text is not shown before the atomic grant.
This deliberately uses the existing receipt convention rather than exposing the
source script's intermediate state between success prose, removal and flag write.
TM teaching, compatibility, move effects and the approved reusable TM policy are
unchanged. There is no new item effect, naming or trade owner.

## Root integration

Cherry-pick this separate service commit after the C data packet. First compose
C's existing root-hooks.patch. Then review and apply:

```sh
git apply --check tools/integration/copycat/root-hooks.patch
git apply tools/integration/copycat/root-hooks.patch
```

The small unapplied patch imports the service, installs it after ordinary content
and delegates the PC scene from the existing HideoutTowerController. No new
executor or top-level state is registered. Install before entering the room;
Saffron's registered source maps/content supply all other room objects and signs.
The two service IDs remain absent from ordinary Saffron content, so registration
does not overwrite an existing owner. The patch also apply-checks without C's
hooks, but a functioning room requires C's activation and registration.

Optionally apply `sdk-registration.patch` to the harness overlay. It imports
`dev/copycatServiceContracts` and registers exactly one supplementary behavior
case, reusing KantoServicesContracts.withScene, the production composed event
state, real Dialog, Inventory and GameSession. It covers no Doll, capacity failure,
precommit cancellation/stale callback, retry, one claim and PC facing branches.
It has been **compiled, not executed**. Root owns actual SDK execution, screenshots,
real interaction approaches, full-bag retry, stale transaction failure and
separate-process Save/Continue. The existing generic owner contracts remain the
source of broader transaction, callback and reusable teaching coverage.

## Checks and limits

With `~/Developer/Pokemon-PlayDate-env/env.sh` loaded:

```sh
python3 tools/generate_copycat_service.py --reference "$POKERED_REFERENCE_DIR" --check
python3 -m unittest tools.tests.test_source_events tools.tests.test_source_text tools.tests.test_kanto_services tools.tests.test_celadon_services_sources tools.tests.test_teaching_data tools.tests.test_midgame_gym_story -q
```

All **38 existing focused host checks pass, with no skips**. The projection
reproduces exactly, and all eight recipes match pinned Saffron content.
SDK 3.1.2 compiles production and full harness. C and Copycat hooks also compile
when composed only in private production/harness staging; the latter includes
the single SDK case. The compiled main records contain the new module and test.
Both hook patches remain unapplied in this checkout.

Evidence: `~/Developer/Pokemon-PlayDate-env/evidence/copycat-service-prep-20261030-01/`.
The original `sound_get_item_1` remains an explicit audio gap; native sound,
text/button timing and gameplay were not measured. No Simulator, device, USB,
runtime locks, subagents, push, main activation, acceptance or 5.6 work occurred.
The activation packet's historical A/B fixture failures remain separate and
were not relabeled or rewritten by this service packet.
