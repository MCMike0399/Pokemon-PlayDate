# Kanto first-use device comparison

Exact reports and hashes: [comparison](kanto-first-entry-scaling-20261030.json).
Diagnostic full collections are included; shipped-equivalent timings remain unmeasured.

| Phase / target | 108 maps | 149 maps |
| --- | ---: | ---: |
| Input-ready title / 10 s | 11.263 s | 12.580 s |
| Longest boot slice / 1 s | 1.267 s | 1.446 s |
| Continue / 4 s | 3.197 s | 3.384 s |
| Save / 2 s | 1.613 s | 1.648 s |
| Longest sampled door / 1.5 s | 3.014 s | 2.974 s |
| Cave walking p95 / 50 ms | 96.969 ms | 101.508 ms |
| Battle start / 1 s | 19.000 ms | 20.000 ms |

| Installer (wall ms, includes yields) | 108 maps | 149 maps |
| --- | ---: | ---: |
| CeruleanContent.registerPackage | 112.0 | 193.0 |
| CeruleanContent.install | 90.0 | 94.0 |
| KantoScenes.install | 58.0 | 34.0 |
| KantoServices.install | 20.0 | 20.0 |
| VermilionGifts.install | 35.0 | 43.0 |
| VermilionStory.install | 143.0 | 157.0 |
| Daycare.install | 740.0 | 21.0 |
| HideoutTowerContent.install | Not separately traced | 768.0 |
| MidgameServices.install | Not separately traced | 67.0 |
| CeladonServices.install | Not separately traced | 283.0 |
| MidgameStoryWarps.install | Not separately traced | 113.0 |
| KantoWorld.install | 1141.0 | 1559.0 |
| PewterWorld.install | 4.0 | 4.0 |
| title.prepare | 4184.0 | 4296.0 |

108-map Daycare includes later installers; its aggregate cannot be compared with the split 149-map Daycare span. Other counts cover different content, not a controlled per-map scaling experiment.

149-map Kanto installer: 1172 → 34 ms (97.1% reduction). Boot: 13.711 → 12.580 s.
No new error/crash logs in either run; keeper restored. Last phase in both is `battle.live.after_gc`.
Hardware live/peak Lua heap: 4.02/5.26 MiB / 4.53/5.82 MiB.
Screen not directly observed. This does not accept B, full first-entry activation, native memory, or long traversal.
