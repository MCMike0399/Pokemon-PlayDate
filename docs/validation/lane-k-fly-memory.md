# Lane K Fly memory (WIP)

Stopped before the city matrix finished. Nothing here is a pass. Pool size is unchanged. No Source commit. No pin edits.

## Done

Scratch tree `/tmp/pd-switch` is detached at `232d4452` with both of these applied and uncommitted: `tools/notes/lane-e-switchzone-release-before-build.patch`, and H's `tools/notes/lane-e-hof-continue-release.patch` from `cursor/lane-h-postgame` `0eed8277`. H's continue heap is still H's. That patch was only applied so this measurement matched the requested tree.

Real party-menu Fly was used, not `switchZone`. Level 65 Blastoise, only move `fly`, quest flag `BADGE_THUNDER`. Cities were marked visited with the dev `switchzone` command, then the player stood outside (`warp 23 26` in Viridian) and the start menu path was B, POKEMON, the mon, FLY, the city, YES, A on the announce. The 12-frame shade fade was not changed.

Unpatched `FieldTravelRuntime.fly` from live Viridian to Fuchsia fails inside the fade completion. The caught reason is `not enough memory`. Boot trace for that attempt: Fuchsia `definition.begin` heap 13684.7, `definition.end` 13809.4, observed peak 13836.2, no `zone.end`. The same Fuchsia load after a released `switchZone` ends at heap 13523.7. Fly was still building the destination while the origin city was live.

`tools/notes/lane-e-fly-release-before-build.patch` is the unfinished attempt. It drops the origin inside `FieldTravelRuntime.fly` before `ensureZone`, nils `request.zone` on the prepared Fly request, keeps the same player, npc manager, and view object for a failed capture, and guards `WorldView:dispose` when Fly has already cleared `view.zone`. The fade frame count is untouched.

A probe of that release, before `request.zone` was cleared, still had Fuchsia `definition.begin` at 13564 and `zone.end` at 13905, then the frame hung. After dispose the imported cache was empty and `kanto_viridian_city` was gone from `zoneRegistry`, and the lua heap stayed about 13560 even after the view, player, and sprites were dropped. The prepared request's `zone` field was still holding the origin. Clearing it is in the patch and was not measured. The run that would have measured it was killed for this wrap-up.

## Left

- Re-run Viridian to Fuchsia with the patch as it sits, and read `zone.end` heap and observed peak.
- If that flight still fails, the origin is still reachable from something this patch does not drop. Extend the patch. Do not wipe `TileRegistry`.
- Then each of Viridian, Cerulean, Celadon, Saffron, Lavender, and Fuchsia to Fuchsia and Saffron, same-city excluded, real party-menu Fly, and record every peak.
- The field-travel contract still has to pass: a rejected capture keeps the same player, npc manager, and view, and the location and world export stay put.
- Add the simulator test with no skip or xfail only after a flight actually lands. Source-byte pin reds from the edited files stay unedited.
