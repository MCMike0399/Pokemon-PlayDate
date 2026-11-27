# Hall of Fame dex rating

`origin/main` (`ea32b553`) was already an ancestor of this branch. `git merge origin/main` was already up to date. No `Source/` edit is committed here.

The player card already prints `POKéDEX Rating:` and then waits. `wDexRatingText` is the next page, but `drawPhoto` sends the whole paragraph to one `gfx.drawText` at y=160. Four lines at the system font's 20px pitch end at y=240, which is the hall clip, so the paragraph does not appear. About four seconds later the credits start. The RED name stays on row 3 of the name box. The credits draw is untouched.

`tools/notes/lane-e-hof-dex-rating.patch` is superseded. Lane E draws the hall page with `EndgameStory.drawPokeredText`, so the old `gfx.drawText` hunk does not apply. K's `tools/notes/lane-k-premerge-hof-dex-rating.patch` on `cursor/lane-k-qa` at `8600ea0b` keeps the line layout and draws each line with `drawPokeredText`. A 20px pitch is kept when the last glyph still fits. The five-line "at least 50" paragraph uses a shorter pitch. `#` stays `POKé`, and the lines have no raw `_` or `*` for the drawText wrapper.

`tools/tests/test_lane_e_hof_dex_rating.py`
`test_rating_table_order_delays_and_visible_lines`

The three pages stay DexSeenOwnedText, DexRatingText, then the owned-count paragraph, each with delay 120. The table is every DexRatingsTable band, including 0–9 and 150–151.

On this tree, the same `endgameStory.lua` as `origin/main`:

```
AssertionError: 1 != 0 : wDexRatingText for 2 owned is one 4-line drawText ending at y=240; the hall clip is 240, so the paragraph does not print
Ran 1 test in 0.003s
FAILED (failures=1)
```

After K's `lane-k-premerge-hof-dex-rating.patch` (the old patch no longer applies):

```
Ran 1 test in 0.003s
OK
```
