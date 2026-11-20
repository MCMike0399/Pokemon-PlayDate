"""Resting overworld flower, tile $03.

pret/pokered home/vcopy.asm UpdateMovingBgTiles replaces tileset tile $03 with
flower1 while a map animates water and flowers. Decodes pinned before that
read keep the static tileset pixels. A new decode may differ only in those
grids, their shade hashes, the flower pin, and the source hashes of those maps.
"""
import hashlib
import json

FLOWER = 'gfx/tilesets/flower/flower1.png'


def _flower_cell(grid):
    ids = grid.get('source_tile_ids')
    return isinstance(ids, list) and any(tile == 3 for tile in ids)


def _strip(value):
    if isinstance(value, list):
        return [_strip(item) for item in value]
    if isinstance(value, dict):
        if _flower_cell(value):
            return {key: None if key in ('grid', 'canonical_shade_sha256') else _strip(item)
                    for key, item in value.items()}
        return {key: _strip(item) for key, item in value.items()}
    return value


def _graft(pinned, fresh):
    if isinstance(pinned, dict) and isinstance(fresh, dict) and _flower_cell(pinned) and _flower_cell(fresh):
        pinned['grid'] = fresh.get('grid')
        pinned['canonical_shade_sha256'] = fresh.get('canonical_shade_sha256')
        return
    if isinstance(pinned, dict) and isinstance(fresh, dict):
        for key, item in pinned.items():
            if key in fresh:
                _graft(item, fresh[key])
    elif isinstance(pinned, list) and isinstance(fresh, list):
        for left, right in zip(pinned, fresh):
            _graft(left, right)


def _sha256_text(value):
    return isinstance(value, str) and len(value) == 64 and all(c in '0123456789abcdef' for c in value)


def installed_flower_hash(fresh_map, fresh_hash, pinned_map, pinned_hash, encode):
    """Both hashes name their own bytes, and the maps differ only by the resting flower."""
    return (hashlib.sha256(fresh_map).hexdigest() == fresh_hash
            and hashlib.sha256(pinned_map).hexdigest() == pinned_hash
            and same_decoded_bytes(fresh_map, pinned_map, encode))


def same_cached_tile(key, fresh, pinned):
    """A shared atlas tile may replace only the $03 quadrants with flower1."""
    if fresh == pinned:
        return True
    parts = str(key).split(':')
    if len(parts) != 4:
        return False
    ids = parts[3].split('-')
    if len(ids) != 4 or '03' not in ids or not isinstance(fresh, dict) or not isinstance(pinned, dict):
        return False
    fresh, pinned = dict(fresh), dict(pinned)
    fresh_grid, pinned_grid = fresh.pop('grid', None), pinned.pop('grid', None)
    if fresh != pinned or not isinstance(fresh_grid, list) or fresh_grid and pinned_grid and len(fresh_grid) != len(pinned_grid):
        return False
    if not fresh_grid or not pinned_grid or len(fresh_grid) != 16:
        return False
    for index, tile in enumerate(ids):
        if tile == '03':
            continue
        x0 = (index % 2) * 8
        y0 = (index // 2) * 8
        for y in range(y0, y0 + 8):
            if fresh_grid[y][x0:x0 + 8] != pinned_grid[y][x0:x0 + 8]:
                return False
    return True


def same_decoded_bytes(fresh, pinned, encode):
    """True when fresh is the encoder's pinned document plus the resting flower.

    Pinned must already be that encoder's exact bytes, so a trailing space is
    still a different document.
    """
    if fresh == pinned:
        return True
    try:
        fresh_doc, pinned_doc = json.loads(fresh), json.loads(pinned)
    except (json.JSONDecodeError, TypeError, UnicodeDecodeError):
        return False
    if encode(pinned_doc) != pinned or _strip(fresh_doc) != _strip(pinned_doc):
        return False
    grafted = json.loads(pinned)
    _graft(grafted, fresh_doc)
    return encode(grafted) == fresh


def _wipe_hashes(document):
    copy = json.loads(json.dumps(document))
    for entry in copy.get('maps', {}).values():
        if isinstance(entry, dict):
            entry['source_sha256'] = None
    return copy


def same_manifest_entries(new, old, new_maps, old_maps, encode):
    """Manifest rows may record the new flower-phase hash of an otherwise identical map."""
    try:
        fresh, pinned = json.loads(new), json.loads(old)
    except (json.JSONDecodeError, TypeError, UnicodeDecodeError):
        return False
    if _wipe_hashes(fresh) != _wipe_hashes(pinned):
        return False
    for name, entry in fresh.get('maps', {}).items():
        previous = pinned['maps'][name]
        if entry.get('source_sha256') == previous.get('source_sha256'):
            continue
        fresh_map = new_maps.get(name + '.json')
        pinned_map = old_maps.get(name + '.json')
        if fresh_map is None or pinned_map is None:
            return False
        if hashlib.sha256(fresh_map).hexdigest() != entry.get('source_sha256'):
            return False
        if hashlib.sha256(pinned_map).hexdigest() != previous.get('source_sha256'):
            return False
        if not same_decoded_bytes(fresh_map, pinned_map, encode):
            return False
    return True


def same_provenance(new, old, artifacts):
    """Provenance may add flower1.png and record the current generator and artifact hashes."""
    try:
        fresh, pinned = json.loads(new), json.loads(old)
    except (json.JSONDecodeError, TypeError, UnicodeDecodeError):
        return False
    files_fresh = fresh.pop('source_files', None)
    files_pinned = pinned.pop('source_files', None)
    arts_fresh = fresh.pop('artifacts', None)
    arts_pinned = pinned.pop('artifacts', None)
    fresh_generator = fresh.pop('generator_sha256', None)
    pinned_generator = pinned.pop('generator_sha256', None)
    gens_fresh = fresh.pop('shared_generators', None)
    gens_pinned = pinned.pop('shared_generators', None)
    if not (_sha256_text(fresh_generator) and _sha256_text(pinned_generator)):
        return False
    if gens_fresh is not None or gens_pinned is not None:
        if (not isinstance(gens_fresh, dict) or not isinstance(gens_pinned, dict)
                or set(gens_fresh) != set(gens_pinned)
                or not all(_sha256_text(value) for value in (*gens_fresh.values(), *gens_pinned.values()))):
            return False
    if fresh != pinned or not isinstance(files_fresh, dict) or not isinstance(files_pinned, dict):
        return False
    if not isinstance(arts_fresh, dict) or set(arts_fresh) != set(arts_pinned or {}):
        return False
    extra = set(files_fresh) - set(files_pinned)
    if extra != {FLOWER} or any(files_fresh[path] != digest for path, digest in files_pinned.items()):
        return False
    if not _sha256_text(files_fresh[FLOWER]):
        return False
    return all(hashlib.sha256(artifacts[name]).hexdigest() == digest for name, digest in arts_fresh.items())
