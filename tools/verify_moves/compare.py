"""Independent B2W2 oracle from pinned raw CSVs; no generator imports."""
from collections import defaultdict
try:
    from .parse_lua import to_camel_case
    from .fetch_pokeapi import SourceError
except ImportError:
    from parse_lua import to_camel_case
    from fetch_pokeapi import SourceError

VERSION_GROUP = 14
TIE_POLICY = 'level ascending; explicit source order ascending; missing order last; numeric move ID ascending'


def number(row, field, optional=False):
    value = row.get(field)
    if optional and value == '': return None
    try:
        return int(value)
    except (ValueError, TypeError) as error:
        raise SourceError(f'invalid integer {field}={value!r}') from error


class Oracle:
    def __init__(self, tables):
        self.tables = tables
        groups = {number(row, 'id'): row for row in tables['version_groups']}
        if groups.get(VERSION_GROUP, {}).get('identifier') != 'black-2-white-2':
            raise SourceError('version-group 14 must identify black-2-white-2')
        self.moves = {}
        self.ids = {}
        for row in tables['moves']:
            move_id = number(row, 'id')
            key = to_camel_case(row['identifier'])
            if move_id in self.ids or key in self.moves:
                raise SourceError(f'duplicate move identity: {move_id}/{key}')
            self.moves[key] = row
            self.ids[move_id] = key
        self.types = {number(row, 'id'): row['identifier'] for row in tables['types']}
        self.classes = {number(row, 'id'): row['identifier'] for row in tables['move_damage_classes']}
        # PokeAPI's latest history omits some Gen IX healing PP nerfs. Resolve
        # numeric fields from a separately pinned pre-SV snapshot, whose own
        # changelog still undoes Gen VI-VIII changes back to B2W2.
        self.field_rows = {to_camel_case(row['identifier']): row for row in tables.get('moves_pre_sv', tables['moves'])}
        self.changes = defaultdict(list)
        for row in tables.get('move_changelog_pre_sv', tables['move_changelog']):
            move_id = number(row, 'move_id')
            if move_id not in self.ids: raise SourceError(f'unknown changelog move ID {move_id}')
            self.changes[move_id].append(row)
        self.meta = {number(row, 'move_id'): row for row in tables['move_meta']}
        self.effect_prose = {number(row, 'move_effect_id'): row['short_effect']
                             for row in tables.get('move_effect_prose', []) if row['local_language_id'] == '9'}
        self.stat_changes = defaultdict(list)
        for row in tables.get('move_meta_stat_changes', []):
            self.stat_changes[number(row, 'move_id')].append({'stat_id': number(row, 'stat_id'), 'change': number(row, 'change')})
        self.learnsets = defaultdict(list)
        seen = set()
        for row in tables['pokemon_moves']:
            if number(row, 'version_group_id') != VERSION_GROUP or number(row, 'pokemon_move_method_id') != 1:
                continue
            dex, move_id = number(row, 'pokemon_id'), number(row, 'move_id')
            if not 1 <= dex <= 151: continue
            if move_id not in self.ids: raise SourceError(f'unknown learnset move ID {move_id}')
            level, order = number(row, 'level'), number(row, 'order', optional=True)
            if not 0 <= level <= 100 or (order is not None and order < 0): raise SourceError('invalid learnset level/order')
            identity = dex, move_id, level, order
            if identity in seen: raise SourceError(f'duplicate learnset row: {identity}')
            seen.add(identity)
            self.learnsets[dex].append({'move': self.ids[move_id], 'level': level, 'order': order, 'id': move_id})
        for entries in self.learnsets.values():
            entries.sort(key=lambda row: (row['level'], row['order'] is None, row['order'] or 0, row['id']))

    def fields(self, key):
        if key not in self.moves: raise SourceError(f'unknown canonical move: {key}')
        if key not in self.field_rows: raise SourceError(f'missing archived field row: {key}')
        current = self.field_rows[key]
        if number(current, 'generation_id') > 5: raise SourceError(f'move introduced after Gen V: {key}')
        # Walk backward from current values, undoing every post-B2W2 change.
        fields = {field: number(current, field, optional=True) for field in
                  ('power', 'pp', 'accuracy', 'priority', 'type_id', 'effect_id')}
        for change in sorted(self.changes[number(current, 'id')],
                             key=lambda row: number(row, 'changed_in_version_group_id'), reverse=True):
            if number(change, 'changed_in_version_group_id') > VERSION_GROUP:
                for field in fields:
                    value = number(change, field, optional=True)
                    if value is not None: fields[field] = value
        try:
            return {'type': self.types[fields['type_id']], 'category': self.classes[number(current, 'damage_class_id')],
                    'power': fields['power'] or 0, 'accuracy': fields['accuracy'] or 0,
                    'pp': fields['pp'], 'priority': fields['priority'] or 0}
        except KeyError as error:
            raise SourceError(f'unknown type/category for {key}') from error


def issue(code, **detail):
    return {'code': code, **detail}


def compare_learnset(name, species, oracle, local_moves):
    expected = oracle.learnsets.get(species['dex'])
    failures = []
    if not expected: failures.append(issue('missing-reference-learnset'))
    unknown = [key for key in species['moves'] if key not in local_moves or key not in oracle.moves]
    if unknown: failures.append(issue('unknown-move-key', moves=unknown))
    actual = species.get('learnset')
    if not isinstance(actual, list) or not actual:
        failures.append(issue('missing-level-metadata', message='flat move names cannot prove learned level or order'))
    else:
        for index, row in enumerate(actual):
            if (not isinstance(row, dict) or not isinstance(row.get('move'), str)
                    or type(row.get('level')) is not int or not 0 <= row['level'] <= 100
                    or (row.get('order') is not None and type(row['order']) is not int)):
                failures.append(issue('invalid-learnset-entry', index=index)); continue
            if row['move'] not in oracle.moves or row['move'] not in local_moves:
                failures.append(issue('unknown-move-key', index=index, move=row['move']))
        if not any(f['code'] == 'invalid-learnset-entry' for f in failures):
            projection = lambda rows: [(row['move'], row['level'], row.get('order')) for row in rows]
            if expected and projection(actual) != projection(expected):
                failures.append(issue('ordered-learnset-mismatch', expected=expected, actual=actual))
    # Even without levels, retain useful ordered name diagnostics (never success).
    expected_names = [row['move'] for row in expected or []]
    if species['moves'] != expected_names:
        failures.append(issue('ordered-move-names-mismatch', expected=expected_names, actual=species['moves']))
    return {'species': name, 'dex': species['dex'], 'ok': not failures, 'issues': failures,
            'expected_learnset': expected or []}


# Source-verified dispatcher gaps, not an exhaustive semantics allowlist.
SPECIAL_GAPS = {
    'hyperBeam': 'recharge', 'gigaImpact': 'recharge', 'solarBeam': 'charge/weather',
    'fly': 'charge/invulnerability', 'dig': 'charge/invulnerability', 'dive': 'charge/invulnerability',
    'bounce': 'charge/invulnerability', 'skullBash': 'charge', 'skyDrop': 'two-turn state',
    'razorWind': 'charge', 'protect': 'protection', 'detect': 'protection', 'endure': 'survive lethal damage',
    'transform': 'battler copy', 'metronome': 'move selection', 'rest': 'healing plus sleep',
    'healPulse': 'heal target (generated effect currently heals attacker)',
    'psystrike': 'special attack versus physical defense', 'psyshock': 'special attack versus physical defense',
    'falseSwipe': 'nonlethal damage', 'selfDestruct': 'user faint', 'explosion': 'user faint',
}


def semantics_inventory(moves, oracle):
    inventory = []
    for key, row in sorted(moves.items()):
        reasons = []
        status = 'requires-independent-runtime-contract'
        if key == 'splash': status = 'intentional-no-effect'
        elif key in SPECIAL_GAPS:
            status = 'known-runtime-gap'; reasons.append(SPECIAL_GAPS[key])
        elif row['category'] == 'status' and not row.get('effects'):
            status = 'status-dispatch-review-required'; reasons.append('no effects or dedicated dispatcher; verify intentional failure/no-op policy')
        elif row['category'] != 'status' and row['power'] == 0 and not row.get('effects'):
            status = 'missing-damage-dispatch'; reasons.append('zero-base-power attack has no damage effect')
        source = oracle.moves.get(key)
        meta = oracle.meta.get(number(source, 'id'), {}) if source else {}
        if meta.get('crit_rate') not in (None, '', '0'):
            status = 'known-runtime-gap'; reasons.append('source crit-rate modifier has no engine field')
        inventory.append({'move': key, 'status': status, 'reasons': reasons,
                          'reference_effect': oracle.effect_prose.get(number(source, 'effect_id')) if source else None,
                          'reference_meta': meta,
                          'reference_stat_changes': oracle.stat_changes.get(number(source, 'id'), []) if source else []})
    return inventory


def verify(species, moves, oracle):
    if not species or not moves: raise SourceError('cannot verify an empty roster or move library')
    learnsets = [compare_learnset(name, row, oracle, moves) for name, row in sorted(species.items(), key=lambda x: x[1]['dex'])]
    fields = []
    for key, row in sorted(moves.items()):
        failures = []
        try:
            expected = oracle.fields(key)
            for field, wanted in expected.items():
                actual = row.get(field, 0 if field == 'priority' else None)
                if actual != wanted: failures.append(issue('move-field-mismatch', field=field, expected=wanted, actual=actual))
        except SourceError as error:
            failures.append(issue('unknown-or-invalid-reference-move', message=str(error)))
        fields.append({'move': key, 'ok': not failures, 'issues': failures})
    inventory = semantics_inventory(moves, oracle)
    gaps = [row for row in inventory if row['status'] in ('known-runtime-gap', 'missing-damage-dispatch')]
    reviews = [row for row in inventory if row['status'] == 'status-dispatch-review-required']
    return {'ok': all(row['ok'] for row in learnsets + fields) and not gaps and not reviews,
            'version_group': VERSION_GROUP, 'tie_policy': TIE_POLICY, 'learnsets': learnsets,
            'runtime_semantics_complete': False,
            'move_fields': fields, 'runtime_semantics': inventory,
            'counts': {'species': len(species), 'moves': len(moves),
                       'learnset_failures': sum(not row['ok'] for row in learnsets),
                       'move_field_failures': sum(not row['ok'] for row in fields), 'known_runtime_gaps': len(gaps), 'status_dispatch_reviews': len(reviews),
                       'runtime_unreviewed': sum(row['status'] == 'requires-independent-runtime-contract' for row in inventory)}}
