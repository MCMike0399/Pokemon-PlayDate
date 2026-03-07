#!/usr/bin/env python3
"""Verify Gen 5 (Black/White) level-up movesets for all 151 Gen I Pokemon.

Scrapes PokeAPI one by one and compares against our pokemon.lua data.
Results are written to tools/verify_moves/reports/ with one file per pokemon
plus a summary file.

Usage:
    python3 main.py              # Verify all 151
    python3 main.py bulbasaur    # Verify a single pokemon
    python3 main.py 1-10         # Verify dex range
"""
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))

from parse_lua import LuaParser
from fetch_pokeapi import PokeAPIFetcher
from compare import MoveComparer, ReportWriter


class MoveVerifier:
    """Orchestrates the full verification pipeline."""

    def __init__(self):
        self.parser = LuaParser()
        self.fetcher = PokeAPIFetcher()
        self.comparer = MoveComparer()
        self.reporter = ReportWriter()

    def run(self, filter_names=None, filter_range=None):
        """Run verification for all or filtered pokemon."""
        pokemon_list = self.parser.sorted_by_dex()
        print(f"Loaded {len(pokemon_list)} pokemon from lua")

        if filter_names:
            print(f"Filtering to: {filter_names}")
        if filter_range:
            print(f"Filtering to dex #{filter_range[0]}-{filter_range[1]}")

        results = []
        for name, info in pokemon_list:
            dex = info["dex"]

            if filter_names and name not in filter_names:
                continue
            if filter_range and not (filter_range[0] <= dex <= filter_range[1]):
                continue

            result = self._verify_one(name, info)
            results.append(result)

        if results:
            self._finalize(results)

        return results

    def _verify_one(self, name, info):
        """Verify a single pokemon and write its report."""
        dex = info["dex"]
        print(f"[{dex:03d}/151] {name}...", end=" ", flush=True)

        api_moves = self.fetcher.fetch(dex, name)
        result = self.comparer.compare(name, dex, info["moves"], api_moves)
        self.reporter.write_pokemon_report(result)

        if result.is_match:
            print("OK")
        elif result.is_error:
            print("ERROR")
        else:
            print(f"MISMATCH (missing={len(result.missing)}, extra={len(result.extra)})")

        return result

    def _finalize(self, results):
        """Write summary and print stats."""
        summary_path = self.reporter.write_summary(results)
        matches = sum(1 for r in results if r.is_match)
        mismatches = sum(1 for r in results if r.status == "mismatch")

        print(f"\nDone! Summary: {summary_path}")
        print(f"Reports: {os.path.dirname(summary_path)}/")
        print(f"\n  Match: {matches}/{len(results)}  |  Mismatch: {mismatches}/{len(results)}")


def parse_args():
    """Parse CLI arguments into filter_names and filter_range."""
    if len(sys.argv) <= 1:
        return None, None

    arg = sys.argv[1]
    if "-" in arg and arg.replace("-", "").isdigit():
        parts = arg.split("-")
        return None, (int(parts[0]), int(parts[1]))
    else:
        return set(sys.argv[1:]), None


if __name__ == "__main__":
    filter_names, filter_range = parse_args()
    verifier = MoveVerifier()
    verifier.run(filter_names=filter_names, filter_range=filter_range)
