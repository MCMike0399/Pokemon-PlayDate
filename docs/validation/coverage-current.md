# Current whole-game coverage

Main has **108/222 maps in the accepted Simulator checkpoint inventory**, through
5.5a: Rock Tunnel, Lavender, Celadon, Erika, Rocket Hideout and Silph Scope.
[Checkpoint A acceptance](midgame-a-acceptance-20261029.json) includes three
chained starter journeys and actual process Continue. **0/222 maps have hardware
playability acceptance.** Hardware boots, loads Continue, saves, traverses doors,
uses Cut and starts a wild battle; device latency targets remain unmet.

The matrix's current Source fingerprint matches main. Its snapshot names
`f86d62577f2288f5ae14f3102158da0f7fd90f82`, whose Source is unchanged on current
main. Its per-row verification remains conservative and retains the original
proof scopes. Inventory membership does not establish complete behavior, regional
fidelity or full mechanics. No historical or private result is promoted.

Checkpoint B remains private at **149 maps**. Its three earned-save journeys are
running; there is no B acceptance. The full B host run found stale development
fixtures plus omitted outdoor Cut records, a generated trade-event inventory
mismatch and this main-only coverage snapshot. Prepared repairs do not renew
runtime evidence. [Current B status](midgame-b-candidate-20261030.json).

All **1,512 rows** remain: the original 1,501 plus 11 explicit partial/source rows.
Campaign path, regional fidelity and full mechanics remain separate. The matrix
indexes 248 map slots (222 ordinary named slots plus aliases and unused entries),
430 moves including five runtime field moves, 131 items including six Pickup
additions, and 375 audio source files. These are inventory counts, not acceptance
counts. Every row's evidence and historical declaration retains its own scope.

Actual saves stay outside Git. [Chain hashes](chain-saves.json) retain accepted
starter provenance. The [ledger](progress.md) records current results and
blockers. [The earlier Cerulean report](coverage-history-cerulean1659.md) remains
historical. Audio, the rest of Kanto and the complete campaign remain unfinished.
