# Device startup scaling

Same earned Route 2 Gate save and 254 serial commands; separate checkpoint snapshots.

| Phase | 108 maps (ms) | 149 maps (ms) |
| --- | ---: | ---: |
| Title accepts A | 12340 | 13687 |
| Continue | 3224 | 3295 |
| Save | 1526 | 1600 |
| Sampled longest door | 2957 | 2960 |
| CeruleanContent.registerPackage | 109 | 171 |
| KantoWorld.install | 1142 | 1555 |
| PewterWorld.install | 5 | 4 |
| KantoScenes.install | 1119 | 1172 |
| Daycare.install | 738 | 1293 |
| title.prepare | 4232 | 4201 |

Both boot totals fail 10 seconds. The historical Daycare span combines several installers;
it cannot establish isolated Day Care scaling. Instrumented title GC is included in boot.
The 108-map run includes 781 ms of diagnostic title GC; the 149-map run includes 898 ms.
Screen was not directly observed. Serial replay completes through battle.live.after_gc,
with no new error or crash logs. Keeper restored; no production activation or push.
