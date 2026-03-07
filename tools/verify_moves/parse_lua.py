"""Parse pokemon.lua to extract pokemon names and their move lists."""
import re
import os


def to_camel_case(hyphenated):
    """Convert PokeAPI hyphenated name to our camelCase key (e.g. 'vine-whip' -> 'vineWhip')."""
    parts = hyphenated.split("-")
    return parts[0] + "".join(p.capitalize() for p in parts[1:])


class LuaParser:
    """Parses pokemon.lua to extract pokemon data and movesets."""

    DEFAULT_PATH = os.path.join(os.path.dirname(__file__), "../../Source/data/pokemon.lua")

    def __init__(self, lua_path=None):
        self.lua_path = lua_path or self.DEFAULT_PATH
        self._pokemon = None

    def parse(self):
        """Parse the lua file and return pokemon dict. Caches result."""
        if self._pokemon is not None:
            return self._pokemon

        with open(self.lua_path) as f:
            content = f.read()

        self._pokemon = {}
        block_pattern = re.compile(
            r'^\s{4}(\w+)\s*=\s*\{(.*?)\n\s{4}\}', re.MULTILINE | re.DOTALL
        )
        for match in block_pattern.finditer(content):
            name = match.group(1)
            block = match.group(2)

            dex_match = re.search(r'dex\s*=\s*(\d+)', block)
            moves_match = re.search(r'moves\s*=\s*\{([^}]*)\}', block)

            if dex_match and moves_match:
                dex = int(dex_match.group(1))
                moves_raw = moves_match.group(1)
                moves = [m.strip().strip('"') for m in moves_raw.split(',') if m.strip().strip('"')]
                self._pokemon[name] = {"dex": dex, "moves": moves}

        return self._pokemon

    def sorted_by_dex(self):
        """Return pokemon as list of (name, info) sorted by dex number."""
        data = self.parse()
        return sorted(data.items(), key=lambda x: x[1]["dex"])


if __name__ == "__main__":
    parser = LuaParser()
    data = parser.parse()
    print(f"Parsed {len(data)} pokemon from lua file")
    for name, info in parser.sorted_by_dex()[:5]:
        print(f"  {name} (#{info['dex']}): {len(info['moves'])} moves")
