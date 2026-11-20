# Type display names (WIP)

Stopped before the lane E handoff. No `Source/` edit. `MallocPoolSize` stayed `16645684`. No simulator run for this pass.

## Done

BlueBot's call on `hall-photo-232d4452` stands: the photo draws, the blank-photo report stays closed, Red's card matches the approved layout, and the credits match r4.

The Mewtwo Hall card draws the pokered constant `PSYCHIC_TYPE`. `EndgameStory.monTypes` returns the `visual.json` strings unchanged, and `EndgameStory.hallRows` puts `types[1]` on the TYPE1 row. `gfx.drawText` treats `_` as italic markup, so the card shows `PSYCHIC` plus an italic `TYPE`. pokered `data/types/names.asm` (`af519899`) uses plain `PSYCHIC`. Equal types already omit the TYPE2/ row (`EraseType2Text`); Mewtwo is `["PSYCHIC_TYPE","PSYCHIC_TYPE"]`, so a missing TYPE2/ line is correct.

`PSYCHIC_TYPE` is the only type string in `visual.json` that contains `_`. The battle TYPE box draws `string.upper(move.type)`, which is already `PSYCHIC` for a Psychic move. The party stats page and the dex do not draw a type name today. Dialog uses `GbFont.drawString` (tile font). `font:drawText` does not interpret markup. Production `gfx.drawText` call sites that can still carry a raw `_` or `*` include the Hall rows, party/bag/shop/PC text, and the debug menu's `*Lv*` / `(* = current)`.

## Left

- `tools/notes/lane-e-type-display-names.patch`: one display-name table (`PSYCHIC_TYPE` and `psychic` to `PSYCHIC`, other types unchanged) used by the Hall card, the battle TYPE box, and any status or dex type line that is drawn. Escape `_` and `*` before `drawText` / `drawTextInRect` / `drawTextAligned` so names, nicknames, items, moves, and dialog cannot pass a single markup character. Keep the single-type TYPE2/ erasure.
- Failing tests, no skip/xfail: Hall card text for a Psychic-type mon is `PSYCHIC`, and a scan of drawn strings rejects unescaped `_` and `*`. They must fail on the live tree and pass once the patch is applied.
- Verify on `232d4452` with a new Hall card still and the status screen. Report the sha, the tests, and the stills.
