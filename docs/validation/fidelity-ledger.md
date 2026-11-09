# Fidelity and intentional changes

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Version | Red and Blue differ in encounters/content | Blue default | README identity and explicit goal | Pinned pokered `af519899719f0754965776faac0e836a3b906e6d`; map/item/encounter manifests |
| World/story | Original Kanto campaign | Preserve geography, progression, characters, identity | User requirement | Pallet/intro accepted; four-map Viridian source adapter reviewed; complete campaign pending |
| Combat | Gen I rules | Gen V/B2W2 rules, physical/special split, broader learnsets, 17 types | Explicit gameplay enhancement | Native domain and gameplay contracts pass; remaining special mechanics still tracked, no blanket certification |
| Roster | Original 151 | Keep151; no later species or Fairy | Preserve identity | All151 learnsets and302 battle assets verified; natural availability remains separate |
| RED | Original source character with project tuning | Preserve custom pure B/W grids exactly | Refined accepted appearance | 2494 reviewed catalog images/masks/hiddenRGB exactly preserved on current Source49832d; Route22 additive inventory is separate and unaccepted |
| NPCs | Transcribed original sprites | Oak `outline`; BLUE/Mom/Daisy `greyhair` | Preserve readable hair/face silhouettes | Pinned converter/mask proof;46 new original frames independently compared |
| Display | GB four shades | 400×240 1-bit, fixed-phase Bayer LIGHT 31.25% / DARK 68.75% everywhere, 2× logical grids | Miguel's 2026-11-09 choice from the style-option screens (1b). Replaces the earlier Pallet/interior 12.5%/50% mapping | Shared `Shade` bytes and explicit phase `(0,0)`; map-preview contract compares 320/704 black pixels |
| Imported dithers | SDK omitted phase differs from explicit0 | Every Shade caller, including Pallet and interiors, uses explicit phase `(0,0)` and the Bayer bytes | The omitted-phase difference remains real; one phase keeps authored and imported pixels comparable | Native shade probe; the 2026-10-28 imported-only catalog is the previous decision, not the current mapping |
| Battle ground platforms | pokered battle scenes have no separate mound under the Pokémon | Keep the Playdate-authored ground platforms | Miguel's 2026-11-09 choice (3a), a deliberate Playdate presentation choice | `BattleScene` platform drawing unchanged |
| Battle sprite shading | pokered battle pictures are four-shade | Threshold 128 on the pinned pictures: 0/85 black, 170/255 white, no dither | Miguel's approved 400×240 frame matches that capture and does not match the `b3ce7a01` Bayer PNGs. Shade Bayer stays for Shade callers | Approved frame SHA-256 `d02e55fa…8315a` is identical to style options 2a and 3a. Slot ink against `b3ce7a01` misses 777 blacks and adds 772 |
| Exit doors | Original step semantics vary | Keep edge exits and exit arrow; new bottom-row interior exits press outward | Existing usability enhancement | Existing round trips pass; imported traversal acceptance pending |
| Effectiveness | Original UI lacks preview | Keep existing preview | Intentional usability enhancement | Native battle captures reviewed |
| XP arithmetic | Gen V scaled award and species growth | Correct growth/20 yields; bounded exact arithmetic without unsigned-overflow glitch | Preserve intended reward mechanics rather than a cartridge arithmetic bug | Growth/participant contracts and all3 native starter wins; source formula notes |
| Sleep | Gen V withdrawal resets original sleep duration | Store original duration separately from remaining turns | Correct switches and save/reload | Codec3; native voluntary sleep-switch case passes |
| Blackout | Defeated party returns healing checkpoint | New sessions use original Pallet5,6, then actual Center checkpoint; existing saved checkpoints retained; lab rival exception | Replace old current-zone spawn placeholder | Native checkpoint blackout and all3 intro regressions pass; corrected default/Mom rest pass integrated873 SDK; existing native checkpoint blackout passes |
| Parcel/sample capacity | Original scripts can set eligibility before failed GiveItem | Commit item and completion flags together; full bag can retry | Prevent lost rewards/quest softlock | Session transaction contracts pass; natural event UI pending |
| Authored Pallet connection | Original Route1 corridor differs by one cell | North+1/south−1 seam; preserve both layouts | Preserve refined Pallet composition | Source-coordinate proof; native connected traversal pending |
| Oak parcel scene | Original lab coordinates and receipt order | Adapt actor paths/transient Dex art to authored lab; defer receipt text until atomic commit | Preserve layout and prevent false reward claims on cancellation | Staged event UI; native acceptance pending |
| Save records | No preexisting aggregate save format in this project | Explicit codec version boundaries, no guessed XP/sleep migration | Reject unreleased incompatible records safely | Real two-process Save/Continue preserves file hash and exact scene |
| Species availability | Exclusives/trading/event Mew | Technical support differs from natural Blue availability | Avoid falsely claiming link/event availability | Policy to resolve before corresponding content |
| Abilities, held items, natures | Absent from original Red/Blue | Add Gen V/B2W2 behavior for the original151 | Explicit user choice on 2026-10-20: “Add abilities, held items, and natures” | Codec6 sex/nature/slot/held, LightBall/CompoundEyes acquisition and bounded battle hooks integrated; current950 SDK/462 host0skip,11 new native component cases and16 fault witnesses qualify,2494 images exact; full111 ability-union/held/IV-EV scope remains open |
| TM/HM policy | Original Blue identities, compatibility and consumable TMs/reusable HMs | Keep original55 machine mapping and compatibility; execute moves under GenV rules | Preserve original campaign rewards including TM34Bide | Isolated typed teaching/Bide implemented;3037 legal pairs/8305bits match independent pinned PKHeX; integrated873 SDK +actual TM34Bag/Bide input pass; broader machine-use acceptance follows content |
| Compound base power | GenV shared Q12 modifiers | One raw power followed by combined Rivalry/MudSport/Solar chain | Fix old40Electric×Rivalry×Mud16→17 | Actual pinned PS Gen5 replay reproduced by root; two-owner MudSport stacking is PS policy, not independently proven cartridge behavior; 873 SDK includes unified pipeline; actual original2494 preservation passes |
| Weather and dependent effects | Gen V moves introduce dependencies beyond the original engine | Implement the dependencies of enabled moves, abilities and held items | Prevent successful no-op effects | Sand/Rain/charge/Thunder/Hurricane/Synthesis and Worry/Insomnia integrated; Protect/Feint, LightScreen/Safeguard/Tailwind and Static/KeenEye/Intimidate field effects qualify in integrated950; no blanket GenV certification |


| Protect rare streak | GenV nominal1/2^32 branch at saturated256 | Two bounded16bit PM samples, both maxima, with real reproducible success; counter not lowered | Retain rare outcome under project RNG | Actual SDK/public ninth attempt and cap-failure mutant qualify; finite ParkMiller outputs are correlated, not native independent32bit entropy/exact frequency |
| Bide against Protect | Native C normal dispatcher +declared move flag block release; actual PS direct-helper path bypasses TryHit | Prefer native dispatch and independent PokeAPI protection flag | Resolve conflicting primary implementations explicitly | Actual PS220→200 bypass retained; native input Bide20 release blocked, target51 unchanged; no retail/emulator claim |
| Successful zero-HP hit | GenV LightScreen final rounding may yield0; successful contact/Rage/rampage still occur | Separate hit receipts from actualHP-removed ledgers | Avoid losing real contact/self effects or fabricating Bide/Assurance/drain damage | Actual PS and native handler audit; current950 SDK, native screen0HP and targeted mutants qualify |
| Individual stats | Blue scripted trainers fixedDV$98/$88; B2W2 uses IV/EV and trainer difficulty | Approved staged normal six boundedIV draws; Blue fixed individual contribution maps16/18/16/16/16/16, EV0; Codec7 legacy0/0 | GenV stats with original campaign trainer identity, no invented difficulty or past training | Proposal source/C vectors verified; implementation/rewards/native acceptance pending; not exact GenI finalstats or nativeDS RNG |
| Resource observations | Native Playdate capacity/frame target | Measure production and harness separately before optimizing | Harness instrumentation is not device evidence | Four600-frame opening probes pass; production postGC~10.35MiB Lua, sampledstartup~22.2MiB; native allocation/device/long-run unverified |
| Field Pickup | Original Blue has no ability-generated loot | User approved the unchanged native B2W2 table and eligibility on 2026-10-26, including all 25 items and six new definitions; retain existing Blue prices | Deliberate acquisition extension for the approved Gen V ability system | Exact table in `docs/research/pickup-policy.md`; private implementation and native acceptance remain pending |
| NPC trade held items | Original Blue had no held-item choice | Require Take before offering a holding Pokémon; do not include, delete or automatically refund its item | Explicit user choice on 2026-10-26 | Nine source trades verified in `docs/research/npc-trade-policy.md`; implementation and native acceptance remain pending |

Prepared during the Cerulean milestone, with native acceptance still pending:

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Catching demonstration | The original OLD_MAN branch guarantees capture and awards no Pokémon or Pokédex entry | Isolated native presentation uses the existing successful capture animation and a 30-tick bag pause | Preserve the lesson without changing player inventory, specimens or either RNG stream | Pinned source and prepared SDK cases; listening and native scene review pending |
| Pewter escort | Source movement ignores occupancy and has a documented screen-X alignment bug | Eight-frame leased movement yields in the final aisle and supports guarded retry/cancellation | Preserve the source route without overlapping actors or reproducing the alignment bug | Pinned route transcription; native motion and cancellation acceptance pending |
| Script placement | Bill enters machine cells; the guide crosses the Gym arrival mat | Only declared actor script positions may use those collision/transit exceptions | Keep player collision, ordinary wandering and actual warp tiles protected | Prepared scoped SDK witnesses; no general collision exemption |
| Museum opening | The original museum doors are passable; the earlier bounded slice blocked them | Open only the declared source ingresses in the private campaign candidate | Extend source geography while retaining every tile and character grid | User approved the reviewed collision diagnostic: exactly 2048 pixels in one image. Private approved comparison preserves all 2494 protected images. |
| Day Care | Blue has one slot, completed-step XP, fees, automatic crossed-level FIFO learning and no evolution | Preserve that service with B2W2 growth, stats, learnsets and PP; reject the last usable member and unresolved battle progression | Use the selected Gen V data while preventing lost choices and party softlocks | Source pins and prepared SDK cases; native service and process-restart acceptance pending |
| Field save migration | Original saves preserve wMapPalOffset; older project saves lack palette and Day Care provenance | Schema 1 migrates to light and an empty Day Care slot; schema 2 retains its palette and gains an empty slot; schema 3 requires both records | Preserve existing owned state without guessing historical field effects or deposited Pokémon | Strict codec and prepared native migration cases; runtime acceptance pending |

The abilities/held-items/natures decision extends the gameplay enhancement policy.
It does not authorize later species, Fairy, Mega Evolution, a changed Kanto story,
or replacement of the protected visual style. Existing saves need explicit
migration rules; new specimen generation, evolution, menus, storage, capture and
battle ordering must agree on the new attributes. Availability of later held
items and hidden abilities needs a documented acquisition policy rather than
invented original-world rewards.

Source references for future content must be pinned and independently checked.
The prior research audit is a starting investigation, not an acceptance oracle.


Play quality changes requested on 2026-10-28 are prepared on a separate branch.
They are not release-accepted until native checks and motion review pass.

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| HP and experience | Blue has HP animation but no visible experience gauge | Animate display HP and add an experience gauge that fills across level changes | Make battle progress readable on Playdate | Prepared; native review pending |
| Running | Blue walks at one normal speed | Hold B to run; a short stationary B release opens the field menu | Faster travel without changing maps or RED art | Requested by user; native checks pending |
| Text and Options | Original text speed and battle settings | Default fast text, hold A to advance; persistent text speed, animation and SHIFT/SET preferences | Comfortable handheld play | Requested by user; native checks pending |
| Battle effects | Original move animation scripts | Ten reusable 1-bit effects, with an OFF option | Native presentation within the project scope | Prepared; motion review pending |
| Trainer choices | Original trainer-class move priorities | Use those class layers with Gen V types and avoid clearly wasted effects | Keep trainer battles purposeful | Prepared; native checks pending |
| Title | Original logo and version identity | Use the source logo and Blue wordmark. The species slot follows the Blue title idle below | A complete native opening screen | Logo and wordmark kept; species slot cycles |
| Title idle | pokered `af519899` `engine/movie/title.asm` `DisplayTitleScreen` and `data/pokemon/title_mons.asm` | Blue starts on Squirtle (`STARTER2`). The menu stays on this screen and its cursor does not blink. After 200 frames `TitleScroll` runs the d=0 path, `TitleScroll_Out`, so that species leaves the right-hand slot. Charmander, Squirtle, or Bulbasaur then play the first five `TitleBallYTable` rows (`0x71` through `0x6c`) from rest `0x74`. There is no Red figure on this screen, so the source `poke_ball` sprite bounces in the vacated slot. `TitleScreenPickNewMon` passes d=1, which takes `TitleScroll_In`: a different Blue TitleMon (Squirtle, Charmander, Bulbasaur, Mankey, Hitmonlee, Vulpix, Chansey, Aerodactyl, Jolteon, Snorlax, Gloom, Poliwag, Doduo, Porygon, Gengar, Raichu) enters from the right. The inline scroll comments disagree with that branch | Was one static Blastoise | Host check covers the wait, both scroll tables, the starter ball, and a different next species. `20261109T214800Z-blue-title-idle.mp4` is 24 s of that cycle, and Continue then opened Silph Co. 3F |


The user approved all four additional quality-of-life proposals on 2026-10-28.
Implementation and native acceptance are tracked separately from this approval.

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Crank | Blue has directional menu input | Optional crank scrolling in menus and PC boxes, with D-pad retained | Native Playdate controls | User approved; implementation in progress |
| Registered key item | Blue requires opening the Bag | Register one key item in the Bag and use A+B in the field | Convenient access to existing item actions | User approved; implementation in progress |
| Bag sorting | Blue preserves manual item order | Explicit manual Sort command with key-item grouping and stable ties | Easier inventory navigation | User approved; implementation in progress |
| TMs | Blue consumes TMs | Reusable Gen V TMs, with compatibility and move-learning confirmation retained | Selected modern quality-of-life policy | User approved; implementation in progress |
| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Display | GB four-shade tonal values | Match GB tonal values with 1-bit dithering (user decision 2026-10-28): fixed-phase Bayer on imported terrain; protected authored art and characters retain their pixels | Reproduce the original tones on Playdate | Native motion passed; 186 approved protected terrain images updated, 2308 remain exact. See gb-tone-approved-images-20261028.json. |
