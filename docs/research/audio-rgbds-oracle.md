# Bounded RGBDS byte qualification

Branch `wip/audio-rgbds-oracle` merged exact parser candidate `9c5ec44`
(including research `9a1cf87`) before changes. Commit `b809130` preserves the
initial blocked attempt. Production Source, parser, catalog, trace, rendering
and existing research results remain untouched.

## Result and boundary

**Actual independent byte comparison passes:** all **22 audited macro cases,
4 header cases and 3 bank-relative wave5 prefixes** match bytes emitted by
RGBDS 1.0.4 from the original pinned pokered macros and source prefixes.
Each of three isolated images compares a 79-byte macro/header block and a
16-byte bank-specific wave5 prefix (95 bytes per image). This builds isolated
data images, never the game ROM. No RGBDS API compatibility fix was needed.

The source-prefix oracle assembles the original `start_menu_1` + `pokeflute`,
`press_ab_2`, and `start_menu_3` + `cut_3` includes. Headers invoke the original
`channel_count`/`channel` macros with the four audited channel lists and a fixed
synthetic pointer `$4567`; this does not qualify linked game-ROM addresses.
This is a bounded byte qualification, **not independent engine/register
execution, APU timing, PCM or audio fidelity acceptance**.

## Isolated toolchain

The pinned pokered checkout's `.rgbds-version` and `INSTALL.md` require
**1.0.4**. The [official RGBDS release](https://github.com/gbdev/rgbds/releases/tag/v1.0.4)
resolves to `f7b8207322aa9e3714ef0d98d01989f320103026`. Its source archive SHA-256
matches the release asset digest. Exact source/build/host details and consumed
`rgbasm`/`rgblink` SHA-256 values are in
[`rgbds-pin.json`](../../tools/references/audio/rgbds-pin.json).

Initially its `src/bison.sh` rejected Apple Bison 2.3; generated parsers are absent
from the source release. After explicit authorization for an isolated prerequisite,
GNU Bison **3.8.2** was fetched directly from the
[official GNU distribution](https://ftp.gnu.org/gnu/bison/).
Archive SHA-256: `9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2`.
This pins the HTTPS download; no detached-signature verification is claimed.
The release README requires M4 >=1.4.6; system GNU M4 1.4.6 sufficed.

Bison configure/build/install used system clang, make and M4 with explicit
`CC=/usr/bin/clang CFLAGS=-O2 M4=/usr/bin/m4` and only this install prefix:
`~/Developer/Pokemon-PlayDate-env/toolchains/bison/3.8.2/install`.
[`bison-pin.json`](../../tools/references/audio/bison-pin.json) records commands,
flags, tool versions, binary SHA-256 and build-log hashes. RGBDS used task-local
PATH with that Bison first; only `rgbasm` and `rgblink` were built, using
`CXX=/usr/bin/clang++ CXXFLAGS='-O3 -flto -DNDEBUG' VERSION_STRING=v1.0.4`
plus upstream required C++20 flags. A subsequent clean RGBDS rebuild reproduced
both consumed binary hashes and all emitted comparison hashes exactly.

No global installation, Homebrew invocation, root/system/profile changes,
prebuilt substitution, Simulator, playback, push or delegation occurred.
Archives, build trees and logs stay under the isolated toolchain directories.

## Reproduction and honest absence

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
export PATH="$POKEMON_ENV/toolchains/rgbds/v1.0.4/rgbds:$PATH"
python -m tools.audio.oracle \
  --output "$POKEMON_ENV/evidence/audio-rgbds-oracle/new-run.json" \
  --evidence-dir "$POKEMON_ENV/evidence/audio-rgbds-oracle/new-emitted"
AUDIO_EXPECT_INDEPENDENT=1 python -m unittest discover -s tools/tests -p 'test_audio_*.py' -v
```

`--evidence-dir` must be new; it retains actual assembly input, objects, linked
data images and assembler/linker logs. The report records consumed binary hashes,
versions, paths, image hashes and compared-prefix hashes. Mocks in gate tests
are never qualification evidence.

With only system search directories in PATH, strict qualification writes
`status: blocked`, `independent_execution: false` and exits **2**. With the
isolated RGBDS directory first, it records `status: pass` and exits **0**.
`--audit-only` explicitly permits a non-independent audit result and exit 0;
the existing converter's optional behavior remains visibly audit-only. An
available wrong version fails before assembly. The callable API also accepts
`require_independent=True`. All **33 host tests pass, zero skips**, under both
PATH configurations; the runs explicitly set `AUDIO_EXPECT_INDEPENDENT=0/1`.

Full source-consumption reports, CLI/test logs and actual emitted data stay outside
Git at `~/Developer/Pokemon-PlayDate-env/evidence/audio-rgbds-oracle/qualified-bison-3.8.2/`.
The small [`rgbds-results.json`](../../tools/references/audio/rgbds-results.json)
records outcomes and evidence hashes. The earlier blocked evidence remains in
its parent directory and in commit `b809130`; original research summaries were
not rewritten to claim this later qualification retroactively.
