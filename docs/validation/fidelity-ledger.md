# Fidelity and intentional changes

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Version | Red and Blue differ in encounters/content | Blue default | README identity and explicit goal | Pinned pokered `af519899719f0754965776faac0e836a3b906e6d`; map/item/encounter manifests |
| World/story | Original Kanto campaign | Preserve geography, progression, characters, identity | User requirement | Pallet/intro accepted; four-map Viridian source adapter reviewed; complete campaign pending |
| Combat | Gen I rules | Gen V/B2W2 rules, physical/special split, broader learnsets, 17 types | Explicit gameplay enhancement | Native domain and gameplay contracts pass; remaining special mechanics still tracked, no blanket certification |
| Roster | Original 151 | Keep151; no later species or Fairy | Preserve identity | All151 learnsets and302 battle assets verified; natural availability remains separate |
| RED | Original source character with project tuning | Preserve custom pure B/W grids exactly | Refined accepted appearance | Original915 protected image/mask comparisons remain exact |
| NPCs | Transcribed original sprites | Oak `outline`; BLUE/Mom/Daisy `greyhair` | Preserve readable hair/face silhouettes | Pinned converter/mask proof;46 new original frames independently compared |
| Display | GB four shades | 400×240 1-bit, fine 12.5%/50% dithers, 2× logical grids | Native Playdate adaptation | Initial renderer unchanged |
| Imported dithers | SDK omitted phase differs from explicit0 | Existing paths unchanged; new imported tiles/NPCs use explicit0 | Deterministic source-to-pixel comparison | Native shade probe;96 exact new-source comparisons; old915 unchanged |
| Exit doors | Original step semantics vary | Keep edge exits and exit arrow; new bottom-row interior exits press outward | Existing usability enhancement | Existing round trips pass; imported traversal acceptance pending |
| Effectiveness | Original UI lacks preview | Keep existing preview | Intentional usability enhancement | Native battle captures reviewed |
| XP arithmetic | Gen V scaled award and species growth | Correct growth/20 yields; bounded exact arithmetic without unsigned-overflow glitch | Preserve intended reward mechanics rather than a cartridge arithmetic bug | Growth/participant contracts and all3 native starter wins; source formula notes |
| Sleep | Gen V withdrawal resets original sleep duration | Store original duration separately from remaining turns | Correct switches and save/reload | Codec3; native voluntary sleep-switch case passes |
| Blackout | Defeated party returns healing checkpoint | Initial bedroom, then actual Center checkpoint; lab rival exception | Replace old current-zone spawn placeholder | Native checkpoint blackout and all3 intro regressions pass |
| Parcel/sample capacity | Original scripts can set eligibility before failed GiveItem | Commit item and completion flags together; full bag can retry | Prevent lost rewards/quest softlock | Session transaction contracts pass; natural event UI pending |
| Authored Pallet connection | Original Route1 corridor differs by one cell | North+1/south−1 seam; preserve both layouts | Preserve refined Pallet composition | Source-coordinate proof; native connected traversal pending |
| Oak parcel scene | Original lab coordinates and receipt order | Adapt actor paths/transient Dex art to authored lab; defer receipt text until atomic commit | Preserve layout and prevent false reward claims on cancellation | Staged event UI; native acceptance pending |
| Save records | No preexisting aggregate save format in this project | Explicit codec version boundaries, no guessed XP/sleep migration | Reject unreleased incompatible records safely | Real two-process Save/Continue preserves file hash and exact scene |
| Species availability | Exclusives/trading/event Mew | Technical support differs from natural Blue availability | Avoid falsely claiming link/event availability | Policy to resolve before corresponding content |
| Abilities/items/weather | Gen V dependencies exceed current engine | Explicit feature policy required before exposing dependent content | Prevent successful no-op moves | Unresolved implementation work; no blanket Gen V certification |

Source references for future content must be pinned and independently checked.
The prior research audit is a starting investigation, not an acceptance oracle.
