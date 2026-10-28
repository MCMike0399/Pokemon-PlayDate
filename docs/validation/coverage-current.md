# Current whole-game coverage

Main reaches Cerulean and Bill with all three starters: **30/222 source maps**.
Milestone 5.3 is accepted in [the summary](cerulean-acceptance-20261028.json).
Current game Source: `44280b886e08a3549f502b4383e9e191f7264b85a9f3bc7a6881f2268c989529`.

The final build passed 1666 SDK checks and 723 host tests with no skips.
All 2494 protected images match the reviewed baseline; 2448 additions were
reviewed. Physical-device, full-campaign and audio acceptance remain unfinished.

The JSON matrix retains all 1501 rows and keeps campaign path, regional fidelity
and full mechanics separate. Installed maps and a passed journey do not prove
every optional event or every possible interaction. Existing narrow move proofs
keep their original source hashes and may be stale after shared code changes.
They are not silently relabeled as current proofs.

The matrix still indexes 248 map slots (222 ordinary named slots plus unused
and alias entries), 425 moves, 111 ability IDs, 151 species, 125 original item
entries, 38 held-item entries, 375 audio sources and 28 systems. These counts
are an inventory, not a completion count. The source manifest has 30 maps.

Actual saves are outside Git. [Hashes and provenance](chain-saves.json) identify
both Brock and Cerulean saves. The acceptance summary links the native reports,
actual process restarts, source versions, screenshots and recovered tooling
failures. Only small summaries are committed; raw reports stay in environment
evidence. The older [1659-check report](coverage-history-cerulean1659.md) remains
historical and does not describe the current build.
