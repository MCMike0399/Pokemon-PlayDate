# P0 binary cell cache handoff

Base: exact main `3c4fc9bddc7f51bdda5fca49005ef10829412d0a`.
This packet only prepares faster current-map cell decoding. No maps are activated.

`Source/data/sourceMapCells/<name>.bin` contains SMC1, three little-endian
uint16 values (source width, height, palette count), 64 ASCII bytes each for
manifest and source SHA256, then row-major tile bytes and collision bytes.
The header is 138 bytes. Version 1 limits width to 128, height to 65535 and
palette count to 255; larger data retains the runtime JSON decoder. The width
bound keeps each native string.byte multi-return small. In-range files must
exist and pass header, dimensions, pins, exact length, tile and collision checks.
Missing/corrupt supported artifacts fail closed. Padding remains in Lua.
Record overrides continue through the original full-definition path.

The generator's existing build() result remains JSON-only for fixture callers.
Regenerate/check both directories with the required environment loaded:

```sh
python3 tools/generate_source_map_cache.py --output <fresh-json-dir> --cells-output <fresh-cell-dir>
python3 tools/generate_source_map_cache.py --output Source/data/sourceMapCache --cells-output Source/data/sourceMapCells --check
```

All 65 files (68,290 bytes) reproduce. Every one of 29,660 decoded tile IDs and
collision values equals both the pinned source arrays and the existing runtime
hex/terrain reconstruction. All original map inputs and existing generated JSON,
including compact.json and tile-grids.json, remain byte-identical to the base.
The actual SDK 3.1.2 production bundle includes all 65 binaries byte-identically.
Generation fallback was checked at width 129, palette 256 and height 65536.

Validation: 15 existing source-map host checks and five production artifact
checks pass. SDK production compilation passes. Evidence and independent cell
proof: `~/Developer/Pokemon-PlayDate-env/evidence/p0-binary-cells-compile-20261029-02/`
(`cell-proof.json`, `stage/build.json`, `stage/build.log`, `Production.pdx`).

No Simulator, USB, deployment or gameplay execution occurred. Root must run the
existing source-map/world SDK cases, exact smoke and hardware gate. There is no
runtime speed/heap measurement or hardware acceptance. Full definitions are
still scoped to a load or weakly retained as before; binaries are not retained.

The first independently usable commit is
`52c93b9f9a5bbe5e4dc596ba7d9ac7793c226415`.

The separate constructor follow-up records binary-loaded padded definitions in
a private weak-key identity table. It compares the tile/collision arrays with
rawequal and matches dimensions. It grants no caller flag and retains no full
definition permanently. Public copies, replacement arrays, overflow fallback
and record overrides retain the original initial validation. For recognized
runtime rows, the final construction pass checks array shape, every current ID
and collision/terrain equality; registry preparation/metadata, publication
conflicts, owned Zone palette checks and rollback remain in place.

The follow-up also passes the same 20 host checks and SDK 3.1.2 production
compilation. Compile-only evidence:
`~/Developer/Pokemon-PlayDate-env/evidence/p0-binary-cells-owned-compile-20261029-01/`.
Neither commit has runtime timing, heap or behavior acceptance. Root can test
the first commit alone before deciding whether to include the follow-up.
