# Hall of Fame and credits capture

Source is pret/pokered `af519899719f0754965776faac0e836a3b906e6d`, `engine/movie/hall_of_fame.asm` and `engine/movie/credits.asm`, plus `data/credits/credits_order.asm`, `data/credits/credits_text.asm`, and `data/credits/credits_mons.asm`. This port is Blue, so the staff line is `BLUE VERSION STAFF`. `RED VERSION STAFF` is the `_RED` string.

Lane B's Charmander run is at Lance. Do not capture this movie until that run, or Lane J, enters `HallOfFamePC`. Frames are 400×240. One pokered `DelayFrames` count is 1/60s. A Playdate frame at 30fps is two of those counts. `GBFadeOutToWhite` is 3 steps of 8 frames (24). `FadeInCredits` is 4 palettes of 5 frames (20).

The machine-readable copy of the credits roll is `tools/tests/fixtures/lane_g_hall_of_fame_credits.json`. `tools/tests/lane_g_hall_of_fame.py` checks a frame log against it. `tools/tests/test_lane_g_hall_of_fame.py` checks the log rules and, when a pokered checkout is available, checks the fixture against the asm.

```bash
python3 tools/tests/lane_g_hall_of_fame.py --log artifacts/lane-g/hof/log.json --credits tools/tests/fixtures/lane_g_hall_of_fame_credits.json
python3 -m unittest tools.tests.test_lane_g_hall_of_fame
```

`#` is the `POKé` tile. `#MON` prints `Pokémon` and `#DEX` prints `PokéDEX`. The log may use either spelling.

## Shot list

Save under `artifacts/lane-g/hof/`. A `log.json` next to the frames names each beat, the text read from the frame, and the PNG. Optional frames set `"skip": true`. Timing fields are checked only when the log includes them.

| Field | Meaning |
| --- | --- |
| `beat` | Beat id from this list |
| `text` | String or list of strings read from the frame |
| `species` | Credits species, or the party species on a Hall of Fame beat |
| `gb_frames` | Pokered hold. Must match the count in this doc |
| `playdate_frames` | `gb_frames / 2` at 30fps |
| `seconds` | `gb_frames / 60`, within 0.05s |
| `fade_gb_frames` | 20 when the beat fades in |
| `png` | 400×240 capture. Paths are relative to the log |

## Hall of Fame mons

`AnimateHallOfFame` walks `wPartySpecies` until `$ff`. That is party order, slot 0 first. Fainted members still show. The nickname is `wPartyMonNicks`. The level is the party level printed by `PrintLevelCommon` (the digits only; the `<LV>` tile is not drawn). The info box is `HoFMonInfoText`:

```
LEVEL/
TYPE1/
TYPE2/
```

`PrintMonType` prints the first type from `data/types/names.asm` (`NORMAL`, `FIGHTING`, `FLYING`, `POISON`, `GROUND`, `ROCK`, `BIRD`, `BUG`, `GHOST`, `FIRE`, `WATER`, `GRASS`, `ELECTRIC`, `PSYCHIC`, `ICE`, `DRAGON`). A second type that differs is printed two rows down. A single-type species blanks the six characters of `TYPE2/`.

After the pictures settle, the info holds 80 frames. Then a box at tile `(2, 13)` gets `HALL OF FAME` at `(4, 15)` and holds 180 frames. Then a 24-frame fade to white. The cry plays when the info is first drawn.

Pictures: `hSCX` starts at `$C0`. The back pic steps `+4` until `$A0` (56 frames). The front pic steps `-4` until `0` (40 frames). SGB doubles the step. The Playdate capture uses the DMG step.

Opening: fade to white (24), clear, hold 100 frames, then `MUSIC_HALL_OF_FAME` and the first party member.

| Beat | Hold | What the frame shows |
| --- | --- | --- |
| `hof-blank` | 100 | White screen after the fade, before the first mon |
| `hof-mon-N` | 80 | Nickname, `LEVEL/`, the level, `TYPE1/`, the first type. `TYPE2/` only for a second type. Front pic settled |
| `hof-banner-N` | 180 | The same info plus `HALL OF FAME` |

## Player card

After the party, `wHoFMonOrPlayer` selects Red. The same back-then-front scroll plays `RedPicBack` and `RedPicFront`. `HoFDisplayPlayerStats` then draws the card. There is no hold of its own before the dex text.

| Text | Where | Rule |
| --- | --- | --- |
| Player name | tile `(7, 2)` | `wPlayerName` |
| `PLAY TIME` | `(1, 6)` | Hours at `(5, 7)` are a 1-byte count with leading zeroes skipped. Tile `$6d` is the colon. Minutes are two digits with leading zeroes |
| `MONEY` | `(1, 9)` | Three BCD bytes at `(4, 10)`, yen tile, leading zeroes skipped. `¥0` when the balance is zero. `¥1234` when it is 1234 |

Beat `hof-player` carries the name, `PLAY TIME`, the `hours:minutes` text, `MONEY`, and the yen amount.

`DisplayDexRating` copies the seen and owned counts, then the rating paragraph, because `EVENT_HALL_OF_FAME_DEX_RATING` is set. It does not print Oak's dex-completion box. Three prints follow, and each falls through `HoFPrintTextAndDelay` (120 frames, no button wait):

| Beat | Hold | Text |
| --- | --- | --- |
| `hof-dex-seen` | 120 | `PokéDEX   Seen:` and the seen count, then `Owned:` and the owned count. `text_decimal` is 3 digits, left aligned, leading zeroes skipped |
| `hof-dex-rating-label` | 120 | `PokéDEX Rating` |
| `hof-dex-rating` | 120 | The paragraph for the owned count |

The owned count picks the first threshold it is strictly under. 151 is the last band (`NUM_POKEMON`).

| Owned | Paragraph |
| --- | --- |
| 0–9 | You still have / lots to do. / Look for Pokémon / in grassy areas! |
| 10–19 | You're on the / right track! / Get a FLASH HM / from my AIDE! |
| 20–29 | You still need / more Pokémon! / Try to catch / other species! |
| 30–39 | Good, you're / trying hard! / Get an ITEMFINDER / from my AIDE! |
| 40–49 | Looking good! / Go find my AIDE / when you get 50! |
| 50–59 | You finally got at / least 50 species! / Be sure to get / EXP.ALL from my / AIDE! |
| 60–69 | Ho! This is geting / even better! |
| 70–79 | Very good! / Go fish for some / marine Pokémon! |
| 80–89 | Wonderful! / Do you like to / collect things? |
| 90–99 | I'm impressed! / It must have been / difficult to do! |
| 100–109 | You finally got at / least 100 species! / I can't believe / how good you are! |
| 110–119 | You even have the / evolved forms of / Pokémon! Super! |
| 120–129 | Excellent! Trade / with friends to / get some more! |
| 130–139 | Outstanding! / You've become a / real pro at this! |
| 140–149 | I have nothing / left to say! / You're the / authority now! |
| 150–151 | Your PokéDEX is / entirely complete! / Congratulations! |

`geting` is the pokered spelling. The card then fades out (24) and returns to `HallOfFamePC`.

## Credits

`HallOfFamePC` clears, holds 100 (`credits-clear`), shifts the font so the text can fade, and fills rows 0–3 and 14–17 with tile `$7e` (solid black). `BGP` is `%11000000`. Music stops, `MUSIC_CREDITS` starts, then 128 frames (`credits-music`). The roll starts at tile column 9, row 6. Each string's first byte is a leftward indent. The next string is two rows down.

A fade command runs `FadeInCredits` (20) and then the hold below. A text command uses the hold only. `CRED_TEXT_MON` and `CRED_TEXT_FADE_MON` then scroll the next `CreditsMons` entry from tile `(8, 6)`: 7 one-tile steps, then 20 more while `rWX` starts at `$A7` and drops by 8. `BGP` `%11111100` makes that pic a solid black silhouette on the white middle. The window's visible edge is `rWX - 7`, so it starts just off the right and then covers the wrapping text. The species is a field on the text beat, never a line of text. Charmap `#` is `POKé`, so `#MON` is drawn `POKéMON`. `é` is font.png char `$BA`: a lowercase e with an acute accent, on the same baseline and x-height as the other lowercase letters, and the letters after it still draw. Rows 0–3 and 14–17 are black. The middle is white and the text is black. The `#MON` line sits at column 2 so the word stays left of the silhouette.

| Beat | Kind | Hold | Mon | Lines |
| --- | --- | --- | --- | --- |
| `credits-00` | fade + mon | 90 | VENUSAUR | Pokémon / BLUE VERSION STAFF |
| `credits-01` | fade + mon | 90 | ARBOK | DIRECTOR / SATOSHI TAJIRI |
| `credits-02` | fade | 120 | | PROGRAMMERS / TAKENORI OOTA / SHIGEKI MORIMOTO |
| `credits-03` | mon | 110 | RHYHORN | PROGRAMMERS / TETSUYA WATANABE / JUNICHI MASUDA / SOUSUKE TAMADA |
| `credits-04` | fade + mon | 90 | FEAROW | CHARACTER DESIGN / KEN SUGIMORI / ATSUKO NISHIDA |
| `credits-05` | fade | 120 | | MUSIC / JUNICHI MASUDA |
| `credits-06` | mon | 110 | ABRA | SOUND EFFECTS / JUNICHI MASUDA |
| `credits-07` | fade + mon | 90 | GRAVELER | GAME DESIGN / SATOSHI TAJIRI |
| `credits-08` | fade | 120 | | MONSTER DESIGN / KEN SUGIMORI / ATSUKO NISHIDA / MOTOFUMI FUZIWARA |
| `credits-09` | mon | 110 | HITMONLEE | MONSTER DESIGN / SHIGEKI MORIMOTO / SATOSHI OOTA / RENA YOSHIKAWA |
| `credits-10` | fade | 120 | | GAME SCENARIO / SATOSHI TAJIRI |
| `credits-11` | mon | 110 | TANGELA | GAME SCENARIO / RYOHSUKE TANIGUCHI / FUMIHIRO NONOMURA / HIROYUKI ZINNAI |
| `credits-12` | fade + mon | 90 | STARMIE | PARAMETRIC DESIGN / KOHJI NISINO / TAKEO NAKAMURA |
| `credits-13` | fade | 120 | | MAP DESIGN / SATOSHI TAJIRI / KOHJI NISINO |
| `credits-14` | mon | 110 | GYARADOS | MAP DESIGN / KENJI MATSUSIMA / FUMIHIRO NONOMURA / RYOHSUKE TANIGUCHI |
| `credits-15` | fade | 120 | | PRODUCT TESTING / AKIYOSHI KAKEI / KAZUKI TSUCHIYA |
| `credits-16` | mon | 110 | DITTO | PRODUCT TESTING / TAKEO NAKAMURA / MASAMITSU YUDA |
| `credits-17` | fade | 120 | | SPECIAL THANKS / TATSUYA HISHIDA / YASUHIRO SAKAI |
| `credits-18` | text | 140 | | SPECIAL THANKS / WATARU YAMAGUCHI / KAZUYUKI YAMAMOTO |
| `credits-19` | mon | 110 | OMASTAR | SPECIAL THANKS / AKIHITO TOMISAWA / HIROSHI KAWAMOTO / TOMOMICHI OOTA |
| `credits-20` | fade | 120 | | PRODUCERS / SHIGERU MIYAMOTO |
| `credits-21` | text | 140 | | PRODUCERS / TAKASHI KAWAGUCHI |
| `credits-22` | mon | 110 | VILEPLUME | PRODUCERS / TSUNEKAZU ISHIHARA |
| `credits-23` | fade | 120 | | US VERSION STAFF |
| `credits-24` | fade | 120 | | US COORDINATION / GAIL TILDEN |
| `credits-25` | text | 140 | | US COORDINATION / NAOKO KAWAKAMI / HIRO NAKAMURA |
| `credits-26` | text | 140 | | US COORDINATION / WILLIAM GIESE / SARA OSBORNE |
| `credits-27` | fade | 120 | | TEXT TRANSLATION / NOB OGASAWARA |
| `credits-28` | fade | 120 | | PROGRAMMERS / TERUKI MURAKAWA / KOHTA FUKUI |
| `credits-29` | fade | 120 | | SPECIAL THANKS / SATORU IWATA |
| `credits-30` | text | 140 | | SPECIAL THANKS / TAKAHIRO HARADA |
| `credits-31` | fade | 120 | | PRODUCT TESTING / PAAD TESTING / NCL SUPER MARIO CLUB |
| `credits-32` | fade | 120 | | PRODUCER / TAKEHIRO IZUSHI |
| `credits-33` | fade + mon | 90 | NIDOKING | EXECUTIVE PRODUCER / HIROSHI YAMAUCHI |
| `credits-34` | fade + mon | 90 | PARASECT | ©'95.'96.'98 Nintendo / ©'95.'96.'98 Creatures inc. / ©'95.'96.'98 GAME FREAK inc. |
| `the-end` | fade | 16, then fade 20 | | THE END |

`credits-34` is `LoadCopyrightTiles` at tile `(2, 7)`, then the fade and Parasect. The three lines are the copyright tiles, not a font string.

## THE END

`CRED_THE_END` waits 16 frames, clears the middle rows, and copies `gfx/credits/the_end.2bpp` onto tile `$60`. Two rows at `(4, 8)` and `(4, 9)` spell `THE END` from tiles `$60`–`$69`. `FadeInCredits` then runs (20) and the movie stays on that graphic. Beat `the-end` is that graphic after the fade. The log text may be `THE END` or `T H E E N D`.
