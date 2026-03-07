"""Compare our lua movesets against PokeAPI Gen 5 data and generate reports."""
import os
from parse_lua import to_camel_case


class MoveComparer:
    """Compares local move lists against PokeAPI level-up moves."""

    def compare(self, pokemon_name, dex, our_moves, api_moves):
        """Compare move lists and return a ComparisonResult."""
        if api_moves is None:
            return ComparisonResult(
                pokemon=pokemon_name, dex=dex, status="error",
                message="Failed to fetch from API"
            )

        api_move_map = {}
        api_move_names = set()
        for m in api_moves:
            camel = to_camel_case(m["name"])
            api_move_names.add(camel)
            api_move_map[camel] = m

        our_set = set(our_moves)
        missing = api_move_names - our_set
        extra = our_set - api_move_names
        common = our_set & api_move_names
        status = "match" if not missing and not extra else "mismatch"

        return ComparisonResult(
            pokemon=pokemon_name, dex=dex, status=status,
            our_count=len(our_moves), api_count=len(api_moves),
            common=sorted(common), missing=sorted(missing),
            extra=sorted(extra), api_detail=api_move_map
        )


class ComparisonResult:
    """Holds the result of comparing moves for one pokemon."""

    def __init__(self, pokemon, dex, status, our_count=0, api_count=0,
                 common=None, missing=None, extra=None, api_detail=None,
                 message=None):
        self.pokemon = pokemon
        self.dex = dex
        self.status = status
        self.our_count = our_count
        self.api_count = api_count
        self.common = common or []
        self.missing = missing or []
        self.extra = extra or []
        self.api_detail = api_detail or {}
        self.message = message

    @property
    def is_match(self):
        return self.status == "match"

    @property
    def is_error(self):
        return self.status == "error"


class ReportWriter:
    """Writes per-pokemon and summary reports to disk."""

    def __init__(self, reports_dir=None):
        self.reports_dir = reports_dir or os.path.join(
            os.path.dirname(__file__), "reports"
        )

    def write_pokemon_report(self, result):
        """Write a single pokemon report file. Returns the file path."""
        os.makedirs(self.reports_dir, exist_ok=True)
        filepath = os.path.join(
            self.reports_dir, f"{result.dex:03d}_{result.pokemon}.txt"
        )

        lines = [
            f"#{result.dex:03d} {result.pokemon.upper()}",
            f"Status: {result.status.upper()}",
            f"Our moves: {result.our_count}  |  API moves: {result.api_count}",
            "",
        ]

        if result.is_error:
            lines.append(f"Error: {result.message or 'unknown'}")
        elif result.is_match:
            lines.append("All moves match!")
            lines.append(f"Moves: {', '.join(result.common)}")
        else:
            if result.missing:
                lines.append("MISSING (in API but not in ours):")
                for m in result.missing:
                    detail = result.api_detail.get(m, {})
                    level = detail.get("level", "?")
                    api_name = detail.get("name", m)
                    lines.append(f"  - {m} (API: {api_name}, Lv.{level})")

            if result.extra:
                lines.append("EXTRA (in ours but not in API level-up):")
                for m in result.extra:
                    lines.append(f"  - {m}")

            if result.common:
                lines.append(
                    f"\nMatching ({len(result.common)}): {', '.join(result.common)}"
                )

        lines.append("")

        with open(filepath, "w") as f:
            f.write("\n".join(lines))
        return filepath

    def write_summary(self, results):
        """Write the overall summary report. Returns the file path."""
        os.makedirs(self.reports_dir, exist_ok=True)
        filepath = os.path.join(self.reports_dir, "000_SUMMARY.txt")

        matches = [r for r in results if r.is_match]
        mismatches = [r for r in results if r.status == "mismatch"]
        errors = [r for r in results if r.is_error]

        lines = [
            "=" * 60,
            "MOVE VERIFICATION SUMMARY - Gen 5 (Black/White) Level-Up",
            "=" * 60,
            f"Total: {len(results)}  |  Match: {len(matches)}  |  "
            f"Mismatch: {len(mismatches)}  |  Errors: {len(errors)}",
            "",
        ]

        if mismatches:
            lines.append("MISMATCHES:")
            lines.append("-" * 40)
            for r in sorted(mismatches, key=lambda x: x.dex):
                missing_str = f" missing={len(r.missing)}" if r.missing else ""
                extra_str = f" extra={len(r.extra)}" if r.extra else ""
                lines.append(
                    f"  #{r.dex:03d} {r.pokemon:12s} |{missing_str}{extra_str}"
                )
                if r.missing:
                    lines.append(f"       Missing: {', '.join(r.missing)}")
                if r.extra:
                    lines.append(f"       Extra:   {', '.join(r.extra)}")
            lines.append("")

        if errors:
            lines.append("ERRORS:")
            lines.append("-" * 40)
            for r in sorted(errors, key=lambda x: x.dex):
                lines.append(f"  #{r.dex:03d} {r.pokemon}: {r.message or 'unknown'}")
            lines.append("")

        if matches:
            lines.append(f"MATCHES ({len(matches)}):")
            lines.append("-" * 40)
            lines.append(
                ", ".join(f"#{r.dex:03d}" for r in sorted(matches, key=lambda x: x.dex))
            )
            lines.append("")

        with open(filepath, "w") as f:
            f.write("\n".join(lines))
        return filepath
