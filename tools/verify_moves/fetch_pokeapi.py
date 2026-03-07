"""Fetch Gen 5 (Black/White) level-up movesets from PokeAPI."""
import json
import os
import time
import urllib.request
import urllib.error


class PokeAPIFetcher:
    """Fetches and caches pokemon move data from PokeAPI."""

    BASE_URL = "https://pokeapi.co/api/v2/pokemon"
    VERSION_GROUP = "black-white"
    REQUEST_DELAY = 0.5  # seconds between API calls

    def __init__(self, cache_dir=None):
        self.cache_dir = cache_dir or os.path.join(os.path.dirname(__file__), "cache")

    def fetch(self, dex_number, pokemon_name):
        """Fetch level-up moves for a pokemon from PokeAPI (Gen 5 B/W).

        Returns list of {"name": str, "level": int} sorted by level,
        or None on error. Uses file cache to avoid re-fetching.
        """
        cached = self._load_cache(dex_number, pokemon_name)
        if cached is not None:
            return cached

        data = self._request(dex_number, pokemon_name)
        if data is None:
            return None

        moves = self._extract_level_up_moves(data)
        self._save_cache(dex_number, pokemon_name, moves)

        time.sleep(self.REQUEST_DELAY)
        return moves

    def _cache_path(self, dex_number, pokemon_name):
        return os.path.join(self.cache_dir, f"{dex_number}_{pokemon_name}.json")

    def _load_cache(self, dex_number, pokemon_name):
        path = self._cache_path(dex_number, pokemon_name)
        if os.path.exists(path):
            with open(path) as f:
                return json.load(f)
        return None

    def _save_cache(self, dex_number, pokemon_name, moves):
        os.makedirs(self.cache_dir, exist_ok=True)
        path = self._cache_path(dex_number, pokemon_name)
        with open(path, "w") as f:
            json.dump(moves, f, indent=2)

    def _request(self, dex_number, pokemon_name):
        url = f"{self.BASE_URL}/{dex_number}"
        try:
            req = urllib.request.Request(
                url, headers={"User-Agent": "PokemonPoC-MoveVerifier/1.0"}
            )
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode())
        except urllib.error.HTTPError as e:
            print(f"  HTTP error {e.code} for #{dex_number} {pokemon_name}")
            return None
        except Exception as e:
            print(f"  Error fetching #{dex_number} {pokemon_name}: {e}")
            return None

    def _extract_level_up_moves(self, data):
        moves = []
        for move_entry in data.get("moves", []):
            move_name = move_entry["move"]["name"]
            for vgd in move_entry["version_group_details"]:
                if (vgd["version_group"]["name"] == self.VERSION_GROUP
                        and vgd["move_learn_method"]["name"] == "level-up"):
                    moves.append({
                        "name": move_name,
                        "level": vgd["level_learned_at"]
                    })
        moves.sort(key=lambda m: (m["level"], m["name"]))
        return moves


if __name__ == "__main__":
    fetcher = PokeAPIFetcher()
    moves = fetcher.fetch(1, "bulbasaur")
    if moves:
        print(f"Bulbasaur has {len(moves)} level-up moves in B/W:")
        for m in moves:
            print(f"  Lv.{m['level']:>3}: {m['name']}")
