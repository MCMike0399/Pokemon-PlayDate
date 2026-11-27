# Lane J — Squirtle

Branch `cursor/lane-j-squirtle`. Merged E tip `51764017` (Oak at lab cell 6, 2 in `837a61e6`), then main through `fe6376b9` (pokered trainer movesets and learnsets). The remote branch only moved forward. Real Simulator presses only. Earned saves stay outside git.

## Position

- Badges: Boulder Badge (`BADGE_BOULDER`) and Cascade Badge (`BADGE_CASCADE`). Misty's payout was 2079. TM34 was sold. The Dome Fossil is still in the bag.
- BLUE, rival RED. Squirtle, level 15, 39 HP, no status, Tackle, Water Gun, Bubble, and Withdraw. Tail Whip was replaced when Water Gun was learned.
- Intro done. Lab rival won (his Bulbasaur)
- Oak's Parcel has been delivered. `EVENT_GOT_POKEDEX` and `EVENT_OAK_GOT_PARCEL` are set.
- Route 3 is crossed. Mt. Moon is crossed. The Route 4 open line entered Cerulean. Nugget Bridge, including the rival on the north corridor and the off-line Jr.Trainer, left Wartortle at level 22 with the Nugget. The gym fight on `fe6376b9` used Bite only. Staryu L18 had Tackle and Water Gun. Starmie L21 had Tackle, Water Gun, and Bubblebeam. Neither used Recover or Swift.
- S.S. Ticket is in the bag (`ssTicket` 1, `EVENT_GOT_SS_TICKET`). Bill's YES started the separator. The ticket pause is `/opt/cursor/artifacts/lane-j/saves/191a86b9e4ed/adventure.b.json` sha256 `1363fe0f4563c44e931da1db5199022186790131dd7cd45f5cf87830838ae4ad` (sequence 18, Bill's house (5, 4)).
- Vermilion is reached. The burgled house back door, the thief at (30, 9) (TM28), Route 5's underground door (17, 27), and Route 6's south edge (9, 35) landed Vermilion (19, 0). The Center healed Wartortle. The north arrival has no walk to the gym door (12, 19). Thunder Badge is not set. Wartortle is level 25, 67 HP, Tackle, Water Gun, Bubble, and Bite, outside the Vermilion Center at (11, 4). The pause is `/opt/cursor/artifacts/lane-j/saves/de26045b6d06/adventure.a.json` sha256 `51ade10899094ca5582d70e13e6664bb0fe9adff6b95c19036ed86770c32a4e3` (sequence 19).
- The S.S. Anne rival blacked out once, then won. The winning send was Wartortle Bite on Pidgeotto, Raticate, and Kadabra, then Pidgeotto Gust on Ivysaur. Kadabra's Disable and Ivysaur's Vine Whip and Leech Seed match pokered. HM01 is in the bag (`hm01` 1, `EVENT_GOT_HM01`, `EVENT_RUBBED_CAPTAINS_BACK`, `EVENT_SS_ANNE_LEFT`). Bellsprout knows Cut. The ship departure warped to Vermilion (18, 29) before the 1F exit step. The pause is `/opt/cursor/artifacts/lane-j/saves/hm01/adventure.a.json` sha256 `d13db4c790f30de1b9f82f6b4e59bbe0463c7bf0ea4f252f7e38483023444589` (sequence 29, Vermilion checkpoint (11, 4)). Wartortle is 26 with 68 HP, Bellsprout 15, Pidgeotto 20 with 37 HP. Money is 6445, with 1 Super Potion, 6 Poké Balls, and TM28. Thunder Badge is not set.
- Earned pause save: `/opt/cursor/artifacts/lane-j/saves/5a428a2c98f5/adventure.a.json` sha256 `9f3237a35d79f667b80884f3b0711356450817f5f068e67611f02ffdd29e2a14` (sequence 11, the cliff). The east-side exit pause is `adventure.b.json` sha256 `35c11c6985486b732e734bf14c15832c1367b4c638b16d9c27a68438b590fb8d` (sequence 10, Route 4 (24, 6)). The Dome Fossil pause is `/opt/cursor/artifacts/lane-j/saves/c964b798257f/adventure.a.json` sha256 `d7c9172de14d727711569feeb8d1b5eac274d43f03223898d55afbcbdd47d2f4` (sequence 9). Earlier: Route 4 entrance sequence 8 `362f03f4ab81c87ca6421b4d419090fb17e557a79e3d27146398fc9f872772d9`, Boulder Badge `fca4f05f2567bd621c35b195f24c0f7db80655b09b67409d282e3e4550a1b05b`. None of these are in git.

## Clips

Decoded frames are only 0 and 255.

| Clip | Duration | sha256 | What it shows |
| --- | --- | --- | --- |
| `artifacts/lane-j/20261120T001412Z-rival-lab.mp4` | 37.03s | `d9b57b21ed0ceca5c0bf01bbf83d25ede123fe13fd2bddf5e396265ee42563bc` | Lab rival win |
| `artifacts/lane-j/20261120T002027Z-rival-lab.mp4` | 36.83s | `9edcfcad7374969896bf63b6d3146e80db78043ee6397aafc5440f24ad05fe58` | Lab rival win only. The recorder stopped when the battle ended, so this is not a Route 1 walk. |
| `artifacts/lane-j/20261120T005708Z-pokedex-lab.mp4` | 31.97s | `71f1cded1ecffbdd3646087cb355c73fa8e74021b5cca23ad01b6dc636a592dd` | Oak takes the parcel and gives the Pokédex. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T010900Z-route1.mp4` | 24.03s | `f46446c1aed298405a06c00b055444af84f15359ac4a04d2f12cdf44a0d33023` | The walk north on Route 1 into Viridian. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T011836Z-gym-pewter.mp4` | 45.37s | `341d2404b7f16eabd0f526dccc5dc5cb660a774360d9540157079efd6d0c6e58` | The Pewter Gym trainer battle that blacked out. This is not the Boulder Badge. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T012706Z-gym-pewter.mp4` | 70.93s | `1d3c2df84e1aeb53e5da03654da14a58756c6e2346c549ab10dd8bec87b9c6f7` | Brock, Geodude then Onix, and the Boulder Badge. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T020656Z-route3.mp4` | 80.73s | `8c25bf7a0134b25b5d0e77ca881ed771f53037c9d96e109ee747826fe4d5516a` | Leaving Pewter onto Route 3. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T023747Z-mt-moon.mp4` | 60.57s | `805cc8f940fa66a4139c6312c6eb80033ff72e0b6001edb1f41c62a5dc2894f9` | The Mt. Moon 1F stair walk. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T024836Z-mt-moon.mp4` | 60.13s | `2a634e95b62d40d1b93ab96129b1a5aeadcfad7bab452f3a587a133e0d95067d` | The next 1F stair walk, before the fossil nerd blackout. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T025319Z-route3.mp4` | 41.33s | `35ffa5094d9b1e68b6fc2b7dbfcc1cb264ef8bc055353d22f84371cda4dd47e4` | The Route 3 recross after that blackout. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T025414Z-mt-moon.mp4` | 47.53s | `79723686ea1ea0cb8af33a75c2967d71483723e70ab11cfa2803902addac4671` | The retry's 1F stair walk. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T055730Z-gym-cerulean.mp4` | 85.0s, trimmed from 102.1s | `e041115526f22ae6ec005672fc0fe35fe41c220ab834424ae0fd5ec089222ccf` | Misty, Staryu then Starmie, and the Cascade Badge. Decoded frames are only 0 and 255. |
| `artifacts/lane-j/20261120T061534Z-bill-ticket.mp4` | 38.77s | `a4dd9a22fd14d6ae0f13e249ad76c749e73ee518a7c3b3c90048b837d2ec66fa` | Bill's separator and the S.S. Ticket. 400x240, decoded luma only 0 and 255. |
| `artifacts/lane-j/20261120T062608Z-vermilion.mp4` | 84.97s, trimmed from 149.37s | `257a78bc7a6813e55a6a051ebeaed8cc9ecee041838c7fc11db003c6c790b89d` | Route 6 into Vermilion. 400x240, decoded luma only 0 and 255. |
| `artifacts/lane-j/20261120T065442Z-ss-anne.mp4` | 85.0s, trimmed from 323.63s | `757d2eaaa7a6ef51be9b8f521d30a2760b3b4d25324472d8dc00a03c79a6a9d1` | The S.S. Anne rival, ending in the blackout. 400x240, gbrp, 2550 frames, decoded luma only 0 and 255. |
| `artifacts/lane-j/20261120T085952Z-ss-anne.mp4` | 85.0s | `17ce2cf09faa8b9aeeef2de6cf1541208d2b3de17e08145bf7bc56b373c879f4` | The S.S. Anne rival win. 400x240, gbrp, 2550 frames, decoded luma only 0 and 255. |
| `artifacts/lane-j/20261120T122228Z-gym-vermilion.mp4` | 85.0s | `499f042e3fc20a3b794b9c58ac9390db852392e89bccc092b45d9891fc534108` | Lt. Surge. 400x240, gbrp, 2550 frames, decoded luma only 0 and 255. |
| `artifacts/lane-j/20261120T125308Z-route2.mp4` | 9.67s | `5e24de6ba48d559cf19742e1a91cb0bb21981657192323e917842812a19bf626` | The Route 2 step left from (11, 2). 400x240, gbrp, 290 frames. Eight sampled frames are luma 0 and 255 only. |
| `artifacts/lane-j/20261120T131809Z-route2.mp4` | 33.0s | `7b3b3c81b27204e4b9aab5ba88430e8b4ed83be093bbac724f8d5c2c96ab5bff` | Cut at Route 2 (5, 10) and the north edge into Pewter. 400x240, gbrp, 990 frames. Sampled frames are luma 0 and 255 only. |
| `artifacts/lane-j/20261120T131907Z-route3.mp4` | 47.5s | `7b4d7400739e477ccd9804ffe08323d4f6221855c0c9d04bd570bf41bf6693e1` | Pewter's east edge across Route 3. 400x240, gbrp, 1425 frames. Sampled frames are luma 0 and 255 only. |
| `artifacts/lane-j/20261120T132807Z-mt-moon.mp4` | 61.1s | `0be8ce453bd227b5c7099f9b62754cc030f5cb1f9b593f702c7db700470db775` | Mt. Moon 1F on the crossing that reached Cerulean. 400x240, gbrp, 1833 frames. Sampled frames are luma 0 and 255 only. |
| `artifacts/lane-j/20261126T190623Z-erika.mp4` | 85.0s | `6bef85855b6e72490368a04122a8bb1fe42a8ac5fee0e670c81d9cb5f48a980f` | Erika, then the Rainbow Badge. 400x240, gbrp, 2549 frames. |
| `artifacts/lane-j/20261127T020500Z-koga.mp4` | 84.97s, trimmed from 370.47s | `886774e6c4e843f686df6607ebb63ed7a5e768a85e88b1435df98f6ce55d353f` | Koga's Weezing, Pidgeot surviving Selfdestruct at 23 HP, and the Soul Badge. 400x240. |

## Title intro

The hang was in this driver. One `wait 250` held the copyright screen. Copyright (180 frames) and the black bars (64) ignore A; the shooting star and the fight accept it (`Source/game/introMovie.lua`, pret/pokered `engine/movie/intro.asm` `PlayIntroScene`). The skip is now a 12-frame wait plus A, repeated until the title leaves the intro, which still covers the whole movie if every A is ignored. A later session cleared that intro, chose CONTINUE on the earned Viridian save, and reached the Mart. No Source change.

## How we got here

New Game from the title. Bedroom stairs, Red's house, Pallet grass, Oak's lab, Squirtle ball at the padded (8, 3) object. Tackle won the lab fight. Out of the lab, north through Route 1, into Viridian City. CONTINUE from that pause save, in the Mart door. The entry program gave Oak's Parcel. Pause save inside the Mart.

## Parcel handoff

An earlier walk reached the same lab before Oak was placed. A at (6, 3) did nothing and the parcel stayed in the bag. After `837a61e6`, CONTINUE from the Mart save again. The title intro cleared, then Mart door to Viridian (29, 20), south edge (21, 35), Route 1 (11, 0) to (10, 35), Pallet (9, 0). The seam at (9, 0) is solid in `PalletTown.json` and open at runtime. The lab door entered `oaks_lab` at (6, 10). Faced Oak at (6, 2) from (6, 3) and pressed A. The handoff ran: dialogue, the rival's walk in, the Pokédex pages, and the rival leaving. The parcel count went to 0. Pause save in the lab. The clip is `20261120T005708Z-pokedex-lab.mp4` (31.97s).

The lab save walked out, filmed Route 1 (24.03s), and talked to the old man at (17, 6). The next walk crossed Route 2, Viridian Forest, and the north gate into Pewter at level 8 with 10 HP. Bubble was learned. A forest battle left Squirtle poisoned. The first Center visit looked for a tile beside the nurse and left without healing. The gym path then crossed the junior trainer's sight at (5, 7). Squirtle fainted. That blackout was not saved. The Pewter pause at (18, 35) resumed. The nurse is at (3, 1) behind the solid counter at (3, 2). Standing at (3, 3) and facing up opened the heal, and YES restored Squirtle to 25 HP. The walk to Brock avoided (4, 7) and (5, 7). Brock's Geodude and Onix fainted. `last_battle_outcome.won` is true, `BADGE_BOULDER` is set, and the bag holds one TM34. Squirtle reached level 12 with 20 HP and learned Withdraw. The clip is `20261120T012706Z-gym-pewter.mp4` (70.93s).

The gym pause walked east. Pewter's Center healed Squirtle before Route 3. The northern road is blocked by trainer sight, so the walk crossed four of them and returned to Pewter whenever HP fell under 22 or a status landed: the bug catcher at (10, 6), the youngster at (14, 4), the youngster at (19, 5), and the youngster at (24, 6). Their flags are `pokered:ROUTE_3:objects:2`, `:3`, `:5`, and `:8`. Water Gun replaced Tail Whip at level 13. Route 3's north edge at (59, 0) opened Route 4 at (9, 17). The pause there is sequence 8. A later step entered Mt. Moon and reached level 16; the evolution announcement was on screen and this driver never pressed A, so that cave progress was not saved. The Route 4 pause is the resume. The clip is `20261120T020656Z-route3.mp4` (80.73s).

A second cave attempt used the pair-legal path. Foot tiles 32 and 5 cannot be stepped between, so the collision-only route west from (10, 22) is refused and the other stairs drop into a dead pocket. The legal path reached B2F. Squirtle evolved to Wartortle at level 16. The super nerd's battle then left Water Gun disabled, and the menu kept confirming that move, so the fight never advanced. That cave was not saved. The Route 4 pause above is still the resume. The clip is `20261120T023747Z-mt-moon.mp4` (60.57s).

A third crossing evolved to Wartortle again, lost to the fossil super nerd, and blacked out to Pewter. The retry beat him at B2F (12, 7) and learned Bite, but Grimer's Disable page stayed up while the cursor moved, so every move was marked rejected and the rest of the fight used Tackle. Wartortle finished paralyzed at 14 HP. The Dome Fossil sprite at (12, 6) is the only step into the exit pocket, and treating that blocked step as a wall left no route. The win was not written. The sequence 8 Route 4 pause is still the resume. The clips are `20261120T024836Z-mt-moon.mp4` (60.13s), `20261120T025319Z-route3.mp4` (41.33s), and `20261120T025414Z-mt-moon.mp4` (47.53s).

The retry beat the fossil super nerd. Wartortle is level 17, 22 HP, with Tackle, Water Gun, Bubble, and Bite, and `EVENT_GOT_DOME_FOSSIL` is set. The first exit walk stepped on warp (5, 7) early. The next walk kept that stair for the last step, returned through B1F, and landed on Route 4 (24, 6). The Center is west of the wall at x=20, so the east side cannot heal there. The walk reached (59, 4) and a right step was blocked. Cerulean did not open.

## S.S. Anne blackout

From sequence 19 the walk bought 8 Poké Balls and 6 Super Potions at the Vermilion Mart (money left 3745), showed the ticket at (18, 30), and boarded. The rival trigger is 2F (36, 8). Kadabra L18 disabled Water Gun, then used Confusion. The first session kept confirming Water Gun because the page says "is disabled" rather than "was disabled", so that fight never advanced and was stopped. The parser now accepts both, and the second session switched moves.

Kadabra fainted. Wartortle grew to level 26. Ivysaur came out with Vine Whip, Leech Seed, and enough HP that Bite could not finish it. Vine Whip was super effective. Leech Seed restored Ivysaur between Bites, and Bite missed. All 6 Super Potions were used. Wartortle fainted with Ivysaur at 6 HP. The session woke at the Vermilion Center (11, 4), level 26, 69 HP, with no Super Potions and no HM01. No pause was written. The disk resume is still sequence 19. The same fight was not started again.

## Next

The committed pause is sequence 659, Silph Co. 9F (18, 9), facing down. Highest slot: `artifacts/lane-j/saves/route6-bird/adventure.a.json`. `origin/main` `247d60a9` is merged. The Fighting Dojo is cleared and neither Poké Ball was taken. Blastoise is 42 (83 HP, Strength, Ice Beam, Surf, Bite), Pidgeot is 41 (119 HP), and Dugtrio is 33 (72 HP). Silph trainers beaten: 2F objects 2–5, 3F objects 2 and 3, 4F objects 2–4, 5F objects 2–5, 6F objects 6–8, 8F objects 2–4, and 9F objects 3 and 4. 9F doors 2 and 3 are open. Door 4 at source (5, 6) is still locked and sits on the walk to door 1 and the last 9F Rocket. Money is 9134. Two Hyper Potions and four Revives. The Card Key is held. The rival wiped the party three times before this grind. Each blackout returned to the Saffron Center.

The Silph party matches pokered `data/trainers/parties.asm` Rival2 for a Squirtle start: Pidgeot 37, Gyarados 38, Growlithe 35, Alakazam 35, Venusaur 40. Wild and trainer EXP use `Growth.battleAward`, the Gen V scaled award. No lane-e patch. Route 7 wilds are about level 20, so the walker no longer paces that grass. It heals at the Saffron Center, clears the Fighting Dojo without taking a Pokémon, then the remaining Silph Rockets and Scientists. Dugtrio leads Rock and Electric parties. Blastoise and Pidgeot share the rest, and the rematch starts once both are 44. The 7F tiles (3, 2) and (3, 3) stay avoided until then. Water-line healing starts at 72 HP against Gyarados and Venusaur, and at 48 otherwise. Lapras, Giovanni, Sabrina, and Blaine are still ahead. Koga's clip is `artifacts/lane-j/20261127T020500Z-koga.mp4`. The Silph rival, Sabrina, and Blaine are not yet filmed. Pidgeot stays for Fly. One party slot stays open for Lapras.

Badges: Boulder, Cascade, Thunder, Rainbow, and Soul.

Team: Dugtrio 33 (72 HP), Bellsprout 15 (40 HP, Cut), Pidgeot 41 (119 HP), Blastoise 42 (83 HP, Strength, Ice Beam, Surf, Bite), Venonat 22 (64 HP). One party slot stays open for Lapras. Pidgeot stays for Fly. Route 16 stays the other Snorlax.

The B2F lift reached Giovanni. The two east Rockets opened his door. The Scope was the ball at (25, 2). The way out stays off the B2F Rocket's sight and uses the B2F cabin back to the Game Corner, then the Celadon Center. B1F's door at (24, 16) and (25, 16) is still the closed block. The closed-stairs note was the wrong press; see `tools/notes/lane-e-game-corner-stairs.md`.

## Blockers

No product red on Misty after `fe6376b9`, and none on Bill, the burgled house, the Underground, the Vermilion arrival, or the S.S. Anne rival. The first Anne loss was the fight: Ivysaur's Vine Whip and Leech Seed outlasted 6 Super Potions. The later fight won with the bird and saved HM01. The disconnected gym door matches the documented north-arrival component until Cut. Recover and Swift did not appear in the gym fight. The swimmer on the gym's y=7 line stayed avoided.

Route 2's blocked left step from (11, 2) and the Vermilion tree returning after a map change are pokered behavior. The cave side joins Pewter after Cut at (5, 10).

## Tests

`python3 -m unittest tools.tests.test_lane_j_squirtle tools.tests.test_lane_e_oaks_lab_oak` — 12 tests, all passed before the Route 3 walk. The Route 3 host checks passed again after that walk (`SquirtleRouteTests`, 11 tests). The Simulator run is `/tmp/lane-j-squirtle-17`. It saved Route 4 and then stopped on the evolution announcement inside Mt. Moon. The same 11 host tests passed after the Anne driver. The blackout session is `/tmp/lane-j-squirtle-43`.
