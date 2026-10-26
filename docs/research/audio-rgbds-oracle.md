# Bounded RGBDS byte qualification attempt

Branch `wip/audio-rgbds-oracle` merged exact parser candidate `9c5ec44`
(including research `9a1cf87`) before changes. Production Source, parser,
catalog, trace, rendering and existing research results are untouched.

The pinned pokered checkout's `.rgbds-version` and `INSTALL.md` require
**1.0.4**. The [official release](https://github.com/gbdev/rgbds/releases/tag/v1.0.4)
resolves to `f7b8207322aa9e3714ef0d98d01989f320103026`. Its source archive SHA-256
matches the release asset digest; exact source/build/host details are in
[`rgbds-pin.json`](../../tools/references/audio/rgbds-pin.json).

**Build blocked:** the official source release does not contain generated
assembler/linker parsers. Its `src/bison.sh` rejects the available Apple
Bison 2.3 with `Bison 2.3 is not supported`; Bison >=3 is required. No newer
Bison was found in PATH, `/opt/homebrew/Cellar`, `/usr/local` or the project
environment. The build exited 2. No packages, system/profile changes,
prebuilt substitute, game ROM, Simulator or playback were used. Neither
consumed RGBDS binary exists, so binary hashes are explicitly null.

The standalone qualifier now defaults to requiring independent execution:

```sh
source ~/Developer/Pokemon-PlayDate-env/env.sh
export PATH="$POKEMON_ENV/toolchains/rgbds/v1.0.4/rgbds:$PATH"
python -m tools.audio.oracle --output "$POKEMON_ENV/evidence/audio-rgbds-oracle/retry.json"
```

With missing tools this writes `status: blocked`, `independent_execution: false`
and exits **2**. `--audit-only` explicitly permits an `audit-only` result and
exit 0; the existing converter's optional behavior remains visibly audit-only.
The callable API also accepts `require_independent=True`. An available wrong
version fails before assembly; actual successful execution would record consumed
binary SHA-256, versions, paths, emitted image hashes and compared-prefix hashes.
No mocked execution counts as qualification evidence.

Both with the isolated toolchain directory first in PATH and with only system
search directories, strict qualification exited 2. All 31 host tests passed with
zero skips under each PATH configuration (27 existing plus 4 qualification gates). All **22 audited macro cases,
4 header cases and 3 bank-relative wave5 prefixes** still match the existing
manual fixtures. **None has been compared to actual RGBDS-emitted bytes in this
attempt.** The RGBDS API path remains unqualified; no speculative compatibility
fix was made. Engine/register execution, APU timing and audio fidelity remain
unestablished.

Full source-consumption reports, CLI logs and test logs stay outside Git at
`~/Developer/Pokemon-PlayDate-env/evidence/audio-rgbds-oracle/`; archive, partial
build and build log stay under the isolated toolchain path. The small
[`rgbds-results.json`](../../tools/references/audio/rgbds-results.json) records
outcomes and evidence hashes. Retry requires an authorized Bison >=3 prerequisite;
then rebuild the pinned source and run the strict qualifier and host tests.
