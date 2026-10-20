"""Immutable PokeAPI raw CSV inputs, separate from legacy API/generator caches."""
import csv
import hashlib
import io
import json
from pathlib import Path
import urllib.request

HERE = Path(__file__).resolve().parent


class SourceError(ValueError):
    pass


class PinnedSources:
    def __init__(self, cache=None, fetch=False, manifest=None, opener=None):
        self.manifest = manifest or json.loads((HERE / 'sources.json').read_text())
        self.cache = Path(cache) if cache else HERE / 'cache' / 'b2w2' / self.manifest['revision']
        self.fetch = fetch
        self.opener = opener or urllib.request.urlopen

    def load(self, name):
        spec = self.manifest['files'][name]
        path = self.cache / name
        try:
            if path.exists():
                raw = path.read_bytes()
            else:
                if not self.fetch:
                    raise SourceError(f'missing pinned cache: {path}; rerun with --fetch')
                url = f"https://raw.githubusercontent.com/PokeAPI/pokeapi/{spec.get('revision', self.manifest['revision'])}/data/v2/csv/{spec.get('remote_file', name)}"
                request = urllib.request.Request(url, headers={'User-Agent': 'PokemonPlaydate-B2W2Verifier/2'})
                with self.opener(request, timeout=60) as response:
                    raw = response.read()
            if hashlib.sha256(raw).hexdigest() != spec['sha256']:
                raise SourceError(f'checksum mismatch: {path}; cache preserved for diagnosis')
            reader = csv.DictReader(io.StringIO(raw.decode('utf-8')))
            if reader.fieldnames != spec['columns']:
                raise SourceError(f'CSV schema mismatch: {name}: {reader.fieldnames}')
            rows = list(reader)
            if not rows or any(None in row or any(value is None for value in row.values()) for row in rows):
                raise SourceError(f'empty or malformed rows: {name}')
            if not path.exists():
                self.cache.mkdir(parents=True, exist_ok=True)
                temporary = path.with_suffix('.csv.tmp')
                temporary.write_bytes(raw)
                temporary.replace(path)
            return rows
        except SourceError:
            raise
        except (OSError, UnicodeError, csv.Error, ValueError) as error:
            raise SourceError(f'cannot load {name}: {error}') from error

    def all(self):
        return {name.removesuffix('.csv'): self.load(name) for name in self.manifest['files']}
