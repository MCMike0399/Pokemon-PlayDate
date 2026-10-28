#!/usr/bin/env python3
"""Silent, deliberately narrow proof of pokered wave5 bank-relative bytes.

Not an audio converter. Fails on unsupported macros; never assembles a ROM,
launches the SDK, renders PCM, or plays sound. JSON goes to stdout.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

PIN = "af519899719f0754965776faac0e836a3b906e6d"
PITCHES = "C_ C# D_ D# E_ F_ F# G_ G# A_ A# B_".split()


def number(token):
    return int(token[1:], 16) if token.startswith("$") else int(token)


def encode(line):
    op, _, arguments = line.partition(" ")
    args = [part.strip() for part in arguments.split(",")]
    if op == "sound_ret":
        return [0xFF]
    if op == "note":
        return [PITCHES.index(args[0]) * 16 + number(args[1]) - 1]
    values = [number(arg) for arg in args]
    if op == "octave":
        return [0xE0 | (8 - values[0])]
    if op == "duty_cycle":
        return [0xEC, values[0]]
    if op == "vibrato":
        delay, depth, rate = values
        return [0xEA, delay, depth * 16 + rate]
    if op in ("noise_note", "square_note", "note_type"):
        length, volume, fade, *freq = values
        envelope = volume * 16 + abs(fade) + (8 if fade < 0 else 0)
        if op == "note_type":
            return [0xD0 | length, envelope]
        result = [0x20 | length, envelope, freq[0] & 255]
        if op == "square_note":
            result.append(freq[0] >> 8)
        return result
    raise ValueError(f"unsupported prefix macro: {line}")


def probe(root):
    revision = subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "HEAD"], text=True
    ).strip()
    if revision != PIN:
        raise ValueError(f"expected {PIN}, found {revision}")
    used = {}

    def read(relative):
        data = (root / relative).read_bytes()
        used[relative] = hashlib.sha256(data).hexdigest()
        return data.decode()

    read("macros/scripts/audio.asm")
    read("audio/engine_2.asm")
    layout = read("layout.link")
    banks = {}
    current_bank = None
    for line in layout.splitlines():
        match = re.fullmatch(r"ROMX \$([0-9A-Fa-f]+)", line)
        if match:
            current_bank = int(match.group(1), 16)
        match = re.fullmatch(r'\s*"Sound Effects ([123])"', line)
        if match:
            banks[int(match.group(1))] = current_bank
    assert banks == {1: 2, 2: 8, 3: 31}
    assembly = read("audio.asm")
    waves = read("audio/wave_samples.asm")
    # These expected points are the pinned source's own explanatory comments,
    # compared with emitted bytes from following INCLUDEs; comments may be stale.
    expected = re.findall(r";\s*dn\s+([\d, ]+)", waves)
    assert len(expected) == 3
    result = []
    for engine, bank in sorted(banks.items()):
        marker = f"Audio{engine}_WavePointers:"
        section = assembly.split(marker, 1)[1].split("SECTION", 1)[0]
        includes = re.findall(r'INCLUDE "([^"]+)"', section)
        assert includes.pop(0) == "audio/wave_samples.asm"
        emitted = []
        origins = []
        for relative in includes:
            for line_no, raw in enumerate(read(relative).splitlines(), 1):
                line = raw.split(";", 1)[0].strip()
                if not line or line.endswith(":"):
                    continue
                for byte in encode(line):
                    emitted.append(byte)
                    origins.append(f"{relative}:{line_no}")
                if len(emitted) >= 16:
                    break
            if len(emitted) >= 16:
                break
        emitted = emitted[:16]
        nibbles = [n for byte in emitted for n in (byte >> 4, byte & 15)]
        oracle = [int(n) for n in expected[engine - 1].split(",")]
        result.append({"engine": engine, "rom_bank": bank,
                       "wave5_bytes_hex": bytes(emitted).hex(),
                       "nibbles_match_source_comment": nibbles == oracle,
                       "source_comment_nibbles": oracle,
                       "emitted_nibbles": nibbles,
                       "byte_origins": origins[:16]})
    # Formula independently transcribed from Audio2_SetSfxTempo and note_length.
    # This demonstrates why changing sample playback rate cannot model cries:
    # noise retains $100 tempo while pulse timing uses length modifier + $80.
    cry_text = read("data/pokemon/cries.asm")
    modifiers = {}
    for base, pitch, length, species in re.findall(
        r"mon_cry SFX_CRY_([0-9A-F]+), \$([0-9A-F]+), \$([0-9A-F]+) ; ([^\n]+)",
        cry_text,
    ):
        if species in ("Rhydon", "Clefairy", "Mew", "Onix", "Pidgey"):
            modifiers[species] = {"base": int(base, 16),
                                  "frequency_register_add": int(pitch, 16),
                                  "pulse_tempo_q8": int(length, 16) + 128,
                                  "noise_tempo_q8": 256}
    return {"scope": "silent source-prefix proof; no playback acceptance",
            "revision": revision, "wave5": result,
            "cry_examples": modifiers, "input_sha256": dict(sorted(used.items()))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(probe(args.source), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
