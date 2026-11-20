# Cerulean inflate on d010ec62

Pool `MallocPoolSize=16645684`. SDK 3.1.2. No `Source` edit. `switchZone` was a real Simulator load.

`ea32b553`, `9abf8f7c`, `43ee0ceb`, `540d5adb`, `14ca320f`, and `d010ec62` all open `kanto_cerulean_city` from a disposed world. The harness fixture resets, drops the imported cache, and then calls `switchZone`. Cerulean comes up. On `d010ec62` that ready heap is 12573.6 KiB and the zone build peaks at 13599.8 KiB. `intro skip` into the starting house and then `switchZone("kanto_cerulean_city")` also loads.

The same `switchZone` fails when Viridian is still the live imported city. The error is `pd_readcompressed inflate failed, out of memory`. It fails on `ea32b553`, `9abf8f7c`, `43ee0ceb`, `540d5adb`, and `d010ec62`. Nothing in this range introduces it. A walk that releases the previous view before the destination tilemap, which is what `setupOverworld` does for a door, is the path that already fits. `switchZone` builds the next zone first, so both city definitions are live and the next compressed read does not fit. On `d010ec62` Cerulean's zone build ends near 13710 KiB in that state, against about 13519 KiB when the previous city was disposed.

`runtime-CeruleanCity.json` stays 54460 bytes and `sourceMapCache/compact.json` stays 897443. The asset did not grow. `9abf8f7c` is the only boot-heap step: it compiles `postgameStory` into `main.pdz` (2112599 to 2120603 bytes) and `initialize.ready` rises from 12573.9 KiB to 12647.4 KiB. `43ee0ceb` loads that module with `file.run` again. `d010ec62` keeps it out of the boot chunk. `main.pdz` is 2112425 bytes, 174 bytes under `ea32b553`, and the ready heap is 12573.6 KiB. Both are under the 14000 KiB boot budget. `tools.tests.test_lane_e_hall_continue_memory` on `d010ec62` is 2 tests, OK. The Hall photo and credits images are not loaded on this path. `postgameStory.pdz` is present and not run.

`tools/notes/lane-e-cerulean-city-inflate.patch` is a note, not a diff. Releasing `SourceMaps.releaseRetainedRuntime` and the tile-grid cache before `ensureZone` left Cerulean's definition start at 13353 KiB and the inflate still failed. Disposing the previous view as well succeeded twice and failed once, at the same 13709 KiB zone end. That is not a reliable fix. The boot budget is unchanged because the note does not add a boot import.

From live Viridian on `d010ec62`:

| Next zone | Result |
| --- | --- |
| `kanto_celadon_city` | inflate out of memory at zone end, 13786 KiB |
| `kanto_saffron_city` | zone end 13811 KiB, then the session did not return |
| `kanto_lavender_town` | view reached actors at 13704 KiB, then `not enough memory` |
| `kanto_fuchsia_city` | inflate out of memory at zone end, 13822 KiB |
