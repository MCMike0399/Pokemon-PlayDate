# Fidelity and intentional changes

| Area | Original reference behavior | Project decision | Reason | Evidence/status |
|---|---|---|---|---|
| Version | Red and Blue differ in encounters/content | Blue default | README identity and explicit goal | Accepted product direction; content source pin pending |
| World/story | Original Kanto campaign | Preserve geography, progression, characters, identity | User requirement | Existing Pallet baseline in progress; rest unimplemented |
| Combat | Gen I rules | Gen V/B2W2 rules, physical/special split, broader learnsets, 17 types | Explicit gameplay enhancement | Existing engine incomplete; independent rule cases pending |
| Roster | Original 151 | Keep 151; no later species or Fairy | Preserve identity | Data/art coverage audit pending |
| RED | Original source character with project tuning | Preserve custom pure B/W grids exactly | Refined accepted appearance | `starting-source.json`; runtime baseline pending review |
| NPCs | Transcribed original sprites | Oak `outline`; BLUE/Mom/Daisy `greyhair` | Preserve readable hair/face silhouettes | Generator exists; pin/checksum work pending |
| Display | GB four shades | 400×240 1-bit, fine 12.5%/50% dithers, 2× logical grids | Native Playdate adaptation | Initial renderer unchanged |
| Exit doors | Original step semantics vary | Keep current edge exits and exit arrow | Existing usability enhancement | Door round-trip capture in progress |
| Effectiveness | Original UI lacks preview | Keep existing preview | Intentional usability enhancement | Battle scene baseline pending review |
| Species availability | Exclusives/trading/event Mew | Technical support differs from natural Blue availability | Avoid falsely claiming link/event availability | Policy to resolve before corresponding content |
| Abilities/items/weather | Gen V dependencies exceed current engine | Explicit feature policy required before exposing dependent content | Prevent successful no-op moves | Unresolved implementation work; no blanket Gen V certification |

Source references for future content must be pinned and independently checked.
The prior research audit is a starting investigation, not an acceptance oracle.
