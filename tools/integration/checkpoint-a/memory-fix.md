# Private 108-map content-index memory fix

Branch `candidate/108-map-memory` merges exact candidate
`fe8d49c73c9445fd001b526219bbbf133ea20795` into the isolated checkout's
`64f60b23` base. Main and original frozen A were not moved. Root's title preview,
main's flat atlases and the regenerated 108-map atlases remain present.

The confirmed retention path is `SourceEvents.contentIndexes[root]` to each
complete generated package index. Registration separately retains the necessary
event/trainer digest membership and trainer flags, but the strong index cache
also kept all 1,644 dialogue-label digests (767 East, 247 source, 630 Vermilion),
sprite indexes, rival-class indexes and redundant membership tables at title.
Root's `p0-checkpoint-a-title-preview-20261029-01/runtime-data/boot-trace.tsv`
shows package registration moving from 4217.604 to 4845.632 KiB before later GC;
this phase delta includes transient work and is not an isolated retained cost.
The final measured title heap remains Root's original 6182.137 KiB result.

`Source/game/sourceEvents.lua` now holds package registration indexes through
weak values, allowing unused portions to be collected after registration. It
loads generated field indexes on demand through `_contentField`, also weakly
cached. `Source/data/ceruleanContent.lua` uses that loader for its existing text,
sprite and complete defensive catalog reads. Active consumers keep normal strong
references; registered membership and the eight-record chunk cache retain their
previous ownership. Nested/error `_withSources` scopes restore both caches with
weak semantics. Public copying, duplicate/content checks, checksum pins and
registration activation are unchanged.

`tools/generate_content_cache.py` additionally emits field-index projections in
`Source/data/contentCache/{base,package-*}-*-*.json`. All 1,887 pre-existing cache
artifacts are byte-identical to fe8d49c. Existing generator checks reconstruct
every original field and compare the complete generated file set (1,907 files).
No source records, maps, controllers, trades, guards, audio, budgets, baselines,
accepted saves, goal or progress were edited for this fix. In particular,
`Source/game/npcTradeState.lua` and its Hideout/Celadon delegation remain intact,
as do the required v4 coins/session/schema dependencies.

Qualification: 45 existing content/source host checks, 5 existing real SDK
compiled-artifact checks (production and harness), and 54 protocol checks pass.
SDK 3.1.2 production compilation also has a retained private bundle. Logs and
bundle are under
`~/Developer/Pokemon-PlayDate-env/evidence/p0-checkpoint-a-memory-worker-20261029-01/`.
No new test or contract was added. No runtime, Simulator, USB, host Lua, push or
delegation was performed.

Root must rerun the exact paired 16 MB title/earned Continue probe from this
checkout with a fresh output directory, then the existing content/event SDK
cases and gameplay checks as appropriate. This preparation does not establish
the 6 MiB guard, the desired roughly 5.7 MiB headroom, timing or acceptance.
Weak field indexes may be decoded again after collection; Root should check
normal text/actor loading latency as well as heap. No forced GC or GC policy
change is included. This is the first scoped fix, ready for measurement before
further changes.
