"""Private milestone 5.4 real-input candidate; never owns a runtime process.

Natural mode extends CeruleanJourney in the same process from New Game. Every
state change goes through production input. Missing activation, observations or
service contracts fail closed. Supplementary fixtures never become natural.
"""
import copy
import hashlib
import json
from pathlib import Path

from tools.harness import cerulean_journey as cj
from tools.harness.brock_journey import BrockJourney, NaturalBlackout, training_lane, choose_battle_medicine
from tools.harness.journeys import DIRECTIONS, lookup
from tools.harness.parcel_journey import sequence
from tools.harness.protocol import ProtocolError, atomic_json

RIVAL = cj.sid('SS_ANNE_2F', 2)
SURGE = cj.sid('VERMILION_GYM', 1)
CAPTAIN = cj.sid('SS_ANNE_CAPTAINS_ROOM', 1)
DAYCARE = cj.sid('DAYCARE', 1)
GIFTS = {
    'voucher': (cj.sid('POKEMON_FAN_CLUB', 5), 'bikeVoucher', 'EVENT_GOT_BIKE_VOUCHER'),
    'rod': (cj.sid('VERMILION_OLD_ROD_HOUSE', 1), 'oldRod', 'pokered:wStatusFlags1:BIT_GOT_OLD_ROD'),
    'hm05': (cj.sid('ROUTE_2_GATE', 1), 'hm05', 'EVENT_GOT_HM05'),
    'itemfinder': (cj.sid('ROUTE_11_GATE_2F', 2), 'itemfinder', 'EVENT_GOT_ITEMFINDER'),
    'hm01': (CAPTAIN, 'hm01', 'EVENT_GOT_HM01'),
    'tm24': (SURGE, 'tm24', 'EVENT_GOT_TM24'),
}
NAMES = {'vermilion-natural', 'vermilion-continue', 'vermilion-supplementary', 'vermilion-supplementary-continue'}
CASES = {key + '-full-retry' for key in GIFTS} | {'blackout', 'field-cut-reload'}
COLLECTION_BOUNDS = {
    'vermilion_actions': (1, 60000), 'collection_steps': (1, 20000),
    'collection_battles': (1, 400), 'collection_phase_battles': (1, 120),
    'collection_balls': (1, 160), 'collection_ball_stock': (1, 40),
    'collection_balls_per_battle': (1, 16), 'collection_money_reserve': (0, 3000),
}
BOUNDS = dict(cj.BOUNDS, max_puzzle_attempts=(1, 512), **COLLECTION_BOUNDS)
PROJECTION = 'data/vermilionJourney.json'


def validate_config(config):
    allowed = set(BOUNDS) | {'name', 'starter', 'fossil', 'evolution_policy', 'case', 'supplementary'}
    if not isinstance(config, dict) or set(config) - allowed or config.get('name') not in NAMES:
        raise ProtocolError('unknown or malformed Vermilion journey')
    for key, (low, high) in BOUNDS.items():
        if key in config and (type(config[key]) is not int or not low <= config[key] <= high):
            raise ProtocolError('invalid bounded Vermilion option: ' + key)
    supplementary = config['name'].startswith('vermilion-supplementary')
    if supplementary != (config.get('supplementary') is True):
        raise ProtocolError('Vermilion fixtures require explicit supplementary classification')
    if supplementary and config.get('case') not in CASES or not supplementary and 'case' in config:
        raise ProtocolError('invalid Vermilion supplementary case')
    adapted = {k: v for k, v in config.items() if k not in {'case', 'max_puzzle_attempts'} | set(COLLECTION_BOUNDS)}
    adapted['name'] = 'cerulean-continue' if config['name'].endswith('continue') else 'cerulean-natural'
    adapted.pop('supplementary', None)
    cj.validate_config(adapted)


def validate_process_journey(config, index, previous):
    validate_config(config)
    name = config['name']
    if name.endswith('continue'):
        expected = 'vermilion-supplementary' if config.get('supplementary') else 'vermilion-natural'
        if index == 0 or previous.get('name') != expected:
            raise ProtocolError('Vermilion Continue requires its immediately preceding Save')
        for key, default in [('starter', 'squirtle'), ('fossil', 'dome'), ('case', None)]:
            if config.get(key, default) != previous.get(key, default):
                raise ProtocolError('Continue changes saved configuration: ' + key)
    elif index != 0:
        raise ProtocolError('Vermilion initial journey must be first process')


# Root's canonical envelope validators include schemas 1, 2 and 3. Preserve
# every owner field; do not maintain a second schema or a reduced receipt DTO.
validate_boundary_payload = cj.validate_boundary_payload
validate_campaign_receipt = cj.validate_receipt_state


def validate_receipt_state(state):
    if not isinstance(state, dict) or set(state) != {'campaign', 'classification', 'case', 'cut_cells'}:
        raise ProtocolError('malformed Vermilion saved state')
    validate_campaign_receipt(state['campaign'])
    if state['classification'] not in {'natural', 'supplementary'}:
        raise ProtocolError('missing saved journey classification')
    if (state['classification'] == 'natural' and state['case'] is not None
            or state['classification'] == 'supplementary' and state['case'] not in CASES):
        raise ProtocolError('saved fixture classification differs')
    if not isinstance(state['cut_cells'], list) or any(
            not isinstance(c, dict) or set(c) != {'x', 'y', 'key'} or type(c['x']) is not int
            or type(c['y']) is not int or not isinstance(c['key'], str) for c in state['cut_cells']):
        raise ProtocolError('invalid Cut boundary observation')


def validate_projection(source):
    export = source.read(PROJECTION)
    fields = {'schema', 'source_revision', 'sources', 'maps', 'events', 'trainers', 'scenes',
              'cut_sites', 'cut_species', 'session_codec', 'daycare_inputs', 'registration', 'collection', 'shops'}
    if set(export) != fields or len(export['maps']) != 35 or not export['cut_species']:
        raise ProtocolError('incomplete Vermilion owner projection')
    required = {'main.lua', 'domain/sessionCodec.lua', 'data/sourceMaps.json',
                'data/machineData.lua', 'data/fieldMoves.json', 'game/vermilionStoryIntent.lua',
                'data/vermilionPreparation/trainers.json', 'data/vermilionGifts/events.json'}
    if required - set(export['sources']):
        raise ProtocolError('projection omits owner pins')
    for relative, digest in export['sources'].items():
        path = Path(relative)
        if path.is_absolute() or '..' in path.parts or relative == PROJECTION:
            raise ProtocolError('unsafe or recursive Vermilion projection pin')
        target = source.build / 'original-main.lua' if relative == 'main.lua' else source.build / 'Source' / relative
        if source.manifest.get(relative) != digest or not target.is_file() or hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ProtocolError('stale Vermilion owner pin: ' + relative)
    manifest = source.read('data/sourceMaps.json')
    missing = set(export['maps']) - set(manifest['maps'])
    if missing:
        raise ProtocolError('inactive milestone 5.4 maps: ' + ', '.join(sorted(missing)))
    for name, entry in export['maps'].items():
        active = manifest['maps'][name]
        for field in ('id', 'path', 'padding', 'width', 'height', 'source_sha256'):
            if active[field] != entry[field]:
                raise ProtocolError('activated map differs from prepared pin: ' + name)
    for key, (event, item, flag) in GIFTS.items():
        if event not in export['events']:
            raise ProtocolError('missing declared reward: ' + key)
    variants = export['trainers'][RIVAL].get('rival_parties', {})
    if set(variants) != set(cj.FAMILIES):
        raise ProtocolError('missing all-starter Anne teams')
    return export


def validate_collection_owner(value):
    if not isinstance(value, dict) or set(value) != {'kind', 'party', 'storage', 'owned'} or value['kind'] != 'vermilion-collection':
        raise ProtocolError('missing canonical collection owners observation')
    owned = cj.boolean_map(value['owned'], 'collection owned species')
    party, storage = value['party'], value['storage']
    if (not isinstance(party, dict) or not isinstance(party.get('members'), list)
            or not 1 <= len(party['members']) <= 6 or party.get('version') != 1
            or type(party.get('active')) is not int or not 1 <= party['active'] <= len(party['members'])
            or not isinstance(storage, dict) or storage.get('version') != 1
            or type(storage.get('active')) is not int or not 1 <= storage['active'] <= 12):
        raise ProtocolError('malformed collection party/storage owners')
    boxes = sequence(storage.get('boxes'), 'collection boxes')
    if len(boxes) != 12:
        raise ProtocolError('collection observation omits storage boxes')
    for box in boxes:
        if len(sequence(box, 'collection box members')) > 20:
            raise ProtocolError('collection selected box exceeds capacity')
    for mon in party['members'] + [m for box in boxes for m in sequence(box, 'box')]:
        if not isinstance(mon, dict) or not isinstance(mon.get('species'), str) or not owned.get(mon['species']):
            raise ProtocolError('collection specimen lacks canonical owned provenance')
    return copy.deepcopy(value)


def verify_capture_commit(before, after, species, result):
    before, after = validate_collection_owner(before), validate_collection_owner(after)
    if not isinstance(result, dict) or result.get('caught') is not True:
        raise ProtocolError('capture commit requires an actual caught result')
    if before['owned'].get(species):
        raise ProtocolError('collection target was already owned')
    expected_owned = dict(before['owned'], **{species: True})
    if after['owned'] != expected_owned:
        raise ProtocolError('capture did not commit exactly the new owned species')
    destination = result.get('destination')
    if (not isinstance(destination, dict) or type(destination.get('index')) is not int
            or 'box' in destination and type(destination['box']) is not int):
        raise ProtocolError('actual capture recruitment destination missing')
    party_before, party_after = before['party']['members'], after['party']['members']
    active = before['storage']['active']
    if len(party_before) < 6:
        if (destination != {'destination': 'party', 'index': len(party_before) + 1}
                or len(party_after) != len(party_before) + 1 or party_after[:-1] != party_before
                or party_after[-1]['species'] != species or before['storage'] != after['storage']
                or before['party']['active'] != after['party']['active']):
            raise ProtocolError('capture party commit differs from actual recruitment receipt')
    else:
        index = len(sequence(before['storage']['boxes'][active - 1], 'selected box')) + 1
        if (index > 20 or destination != {'destination': 'storage', 'box': active, 'index': index}
                or before['party'] != after['party'] or after['storage']['active'] != active):
            raise ProtocolError('full-party capture lacks selected-box recruitment receipt')
        for number, (prior, current) in enumerate(zip(before['storage']['boxes'], after['storage']['boxes']), 1):
            prior, current = sequence(prior, 'prior box'), sequence(current, 'current box')
            if number == active:
                if len(current) != len(prior) + 1 or current[:-1] != prior or current[-1]['species'] != species:
                    raise ProtocolError('capture did not append the actual selected-box specimen')
            elif current != prior:
                raise ProtocolError('capture changed another PC box')
    return copy.deepcopy(destination)


class VermilionJourney(cj.CeruleanJourney):
    def __init__(self, client, evidence, config, build_evidence=None, capture_dir=None):
        validate_config(config)
        adapted = {k: v for k, v in config.items() if k not in {'case', 'supplementary', 'max_puzzle_attempts'} | set(COLLECTION_BOUNDS)}
        adapted['name'] = 'cerulean-natural'
        super().__init__(client, evidence, adapted, build_evidence, capture_dir)
        self.config = copy.deepcopy(config)
        self.summary['journey'] = copy.deepcopy(config)
        self.vermilion_active = False
        self.cut_cells = []
        self.cut_witnesses = 0
        self.acquisition_active = False
        self.acquisition_targets = set()
        self.collection = {'steps': 0, 'battles': 0, 'balls': 0, 'purchased': 0,
                           'captures': [], 'phases': [], 'purchases': []}
        self.summary['collection'] = self.collection
        self.summary.update(milestone='5.4', natural=not config.get('supplementary', False),
                            supplementary=config.get('supplementary', False), acceptance='unrun candidate',
                            driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())

    def dependencies(self):
        # Preflight immutable bytes before parent dependencies send any input.
        source = cj.StagedSource(self.build_evidence)
        self.vermilion = validate_projection(source)
        if not self.vermilion['daycare_inputs']:
            raise ProtocolError('missing root Day Care owner/service inputs; no service acceptance')
        super().dependencies()
        registered = self.observe('vermilion-owners')
        if registered != {'kind': 'vermilion-owners', 'valid': True,
                          'version': self.vermilion['session_codec']}:
            raise ProtocolError('missing root registered Vermilion owners observation')
        self.source_trainers.update(copy.deepcopy(self.vermilion['trainers']))
        definition = self.source_trainers[RIVAL]
        selected = definition['rival_parties'][self.starter]
        self.source_trainers[RIVAL] = dict(definition, party=selected['party'], payout=selected['payout'])
        self.summary['vermilion_dependencies'] = {
            'owner_export_sha256': source.manifest[PROJECTION], 'build_id': self.client.identity['build_id'],
            'status': 'declared inputs and actual registration qualified; runtime journey still pending'}

    def capture_presentation(self, label, kind):
        if self.vermilion_active:
            label = 'vermilion-' + label
        return super().capture_presentation(label, kind)

    def advance_event(self, stop_phase=None):
        if (self.vermilion_active and self.state.get('root') == 'party'
                and lookup(self.state, 'event.id') == DAYCARE
                and lookup(self.state, 'event.phase') == 'daycare-party'):
            index = getattr(self, 'daycare_index', None)
            if index is None:
                raise ProtocolError('unplanned actual Day Care party selection')
            self.select('party_ui.selected', index)
            self.send('press a')
            return True
        if (self.vermilion_active and self.state.get('root') == 'event'
                and lookup(self.state, 'event.phase') == 'vermilion-departure'):
            key = ('vermilion-departure', lookup(self.state, 'event.id'))
            if key not in self.event_recordings:
                self.event_recordings.add(key)
                self.send('record vermilion-ship-departure 90')
                return True
        if (self.vermilion_active and self.state.get('root') == 'event'
                and lookup(self.state, 'event.phase') == 'story-choice'):
            event = lookup(self.state, 'event.id')
            if event not in {v[0] for v in GIFTS.values()} | {DAYCARE}:
                raise ProtocolError('unplanned Vermilion service choice: ' + str(event))
            options = sequence(lookup(self.state, 'event.menu.options'), 'gift options')
            if options != ['YES', 'NO']:
                raise ProtocolError('changed actual gift menu')
            self.select('event.menu.selected', 1)
            self.send('press a')
            return True
        return super().advance_event(stop_phase)

    def refresh_world(self):
        if self.vermilion_active:
            self.apply_world_observation(self.observe('vermilion-world'))

    def warp(self, target_id, event_id=None):
        result = super().warp(target_id, event_id)
        self.refresh_world()
        return result

    def cross(self, direction, zone, destination):
        self.count_collection_step()
        result = super().cross(direction, zone, destination)
        self.refresh_world()
        return result

    def travel(self, target_id, goal=None):
        # Map reload restores temporary Cut; use actual settled terrain at each
        # transition rather than retaining the earlier host collision override.
        self.refresh_world()
        return super().travel(target_id, goal)

    def begin_continuation(self):
        if self.vermilion_active:
            raise ProtocolError('Vermilion continuation initialized twice')
        self.vermilion_active = True
        # Only the 5.4 continuation receives this additional finite budget.
        # Earlier New Game -> Bill uses the original, unchanged Brock bounds.
        self.config = dict(self.config,
            max_actions=self.config.get('max_actions', 6000) + self.config.get('vermilion_actions', 30000),
            max_encounters=self.config.get('max_encounters', 64) + self.config.get('collection_battles', 180))

    def count_collection_step(self):
        if self.acquisition_active:
            if self.collection['steps'] >= self.config.get('collection_steps', 12000):
                raise ProtocolError('Vermilion collection physical step budget exhausted')
            if self.collection['battles'] >= self.config.get('collection_battles', 180):
                raise ProtocolError('Vermilion collection real battle budget exhausted before movement')
            self.collection['steps'] += 1

    def step(self, step):
        self.count_collection_step()
        return super().step(step)

    def collection_owner(self):
        return validate_collection_owner(self.observe('vermilion-collection'))

    def battle(self, name, strategy='attack', expected=None):
        if self.acquisition_active and not lookup(self.state, 'battle.trainerName'):
            # EventState can still display the previous trainer ID after a wild
            # encounter. Wild outcomes have no trainer receipt/payout; use the
            # shared production input loop without Cerulean's trainer-ID guard.
            return BrockJourney.battle(self, name, strategy, expected)
        return super().battle(name, strategy, expected)

    def training_battle(self):
        if not self.acquisition_active:
            return super().training_battle()
        if self.collection['battles'] >= self.config.get('collection_battles', 180):
            raise ProtocolError('Vermilion collection real battle budget exhausted')
        self.collection['battles'] += 1
        self.collection_battle_balls = 0
        # Trainers retain the ordinary stable-team, PP, payout and outcome checks.
        return self.battle('vermilion-collection-' + str(self.collection['battles']))

    def battle_preparation_action(self, battle, options):
        if not self.acquisition_active or battle.get('trainerName'):
            return super().battle_preparation_action(battle, options)
        species = battle['enemy']['species']
        owned = cj.boolean_map(lookup(self.state, 'session.pokedex.owned'), 'owned')
        if species not in self.acquisition_targets or owned.get(species):
            # Incidental non-target battles use actual attacks and PP. This also
            # avoids pretending RUN can bypass a wild trapping ability.
            return super().battle_preparation_action(battle, options)
        if choose_battle_medicine(battle['player'], self.inventory()):
            return False  # Existing battle loop selects and commits real medicine.
        if self.collection['balls'] >= self.config.get('collection_balls', 80):
            raise ProtocolError('Vermilion collection total ball budget exhausted')
        if self.collection_battle_balls >= self.config.get('collection_balls_per_battle', 12):
            raise ProtocolError('Vermilion collection per-encounter ball bound exhausted')
        if self.quantity('pokeBall') < 1:
            raise ProtocolError('collection ran out of actual purchased balls during an encounter')
        if self.state['zone_id'] not in {v['id'] for v in self.vermilion['collection'].values()}:
            raise ProtocolError('capture target encountered outside pinned collection maps')
        before = self.collection_owner()
        if len(before['party']['members']) == 6:
            active = before['storage']['active']
            if len(sequence(before['storage']['boxes'][active - 1], 'active box')) >= 20:
                raise ProtocolError('selected PC box is full; no automatic overflow assumed')
        positions = [i for i, v in enumerate(options, 1)
                     if v == 'BAG' or isinstance(v, dict) and v.get('action') == 'bag']
        if len(positions) != 1:
            raise ProtocolError('collection requires exactly one actual battle BAG')
        quantity = self.quantity('pokeBall')
        self.select('battle.menu.selected', positions[0])
        self.send('press a')
        self.require(root='bag')
        index = next((i for i, row in enumerate(self.inventory()['slots'], 1) if row['id'] == 'pokeBall'), None)
        if index is None:
            raise ProtocolError('actual collection ball slot disappeared')
        self.select('bag.selected', index)
        self.send('press a')
        self.require(root='battle')
        if self.quantity('pokeBall') != quantity - 1:
            raise ProtocolError('actual collection ball consumption differs')
        result = copy.deepcopy(lookup(self.state, 'battle.capture_result'))
        if not isinstance(result, dict) or type(result.get('caught')) is not bool:
            raise ProtocolError('actual collection capture result missing')
        self.collection['balls'] += 1
        self.collection_battle_balls += 1
        record = {'species': species, 'zone_id': self.state['zone_id'], 'result': result,
                  'before_quantity': quantity, 'after_quantity': self.quantity('pokeBall')}
        after = self.collection_owner()
        if result['caught']:
            record['commit'] = verify_capture_commit(before, after, species, result)
            self.collection['captures'].append(record)
        elif (before['owned'] != after['owned'] or before['storage'] != after['storage']
              or [m['species'] for m in before['party']['members']] != [m['species'] for m in after['party']['members']]):
            raise ProtocolError('failed actual capture changed recruitment or owned species')
        self.summary.setdefault('collection_throws', []).append(record)
        self.send('record vermilion-collection-catch-' + str(self.collection['balls']) + ' 48')
        return True

    def require_shop_stock(self, clerk, item):
        if self.vermilion_active and clerk in self.vermilion['shops']:
            shop = self.vermilion['shops'][clerk]
            if item not in shop['stock'] or type(shop['prices'].get(item)) is not int or shop['prices'][item] <= 0:
                raise ProtocolError('collection purchase absent from actual shop owner')
            return
        return super().require_shop_stock(clerk, item)

    def sell_collection_nugget(self, clerk):
        price = self.vermilion['shops'][clerk]['sell_prices']['nugget']
        quantity, money = self.quantity('nugget'), self.inventory()['money']
        if quantity < 1 or type(price) is not int or price <= 0:
            raise ProtocolError('collection funding requires an actual sellable Bridge Nugget')
        self.interact(source_id=clerk)
        self.require(root='shop', **{'shop.phase': 'mode'})
        self.select('shop.menu.selected', 2)
        self.send('press a')
        index = next(i for i, slot in enumerate(self.inventory()['slots'], 1) if slot['id'] == 'nugget')
        self.select('shop.selected', index)
        self.require(**{'shop.item': 'nugget'})
        self.send('press a')
        self.require(**{'shop.phase': 'quantity', 'shop.quantity': 1})
        self.send('press a')
        self.require(**{'shop.phase': 'confirm'})
        self.select('shop.menu.selected', 1)
        self.send('press a')
        self.require(**{'shop.phase': 'result', 'shop.result.ok': True, 'shop.result.total': price})
        if self.quantity('nugget') != quantity - 1 or self.inventory()['money'] != money + price:
            raise ProtocolError('actual Nugget sale did not commit exact item/money changes')
        self.collection.setdefault('sales', []).append({'item': 'nugget', 'quantity': 1, 'price': price,
                                                       'money_before': money, 'money_after': self.inventory()['money']})
        self.send('press a', 'press b', 'press b')
        self.drain()

    def collection_supplies(self, mart):
        clerk = self.zone(mart) + ':objects:1'
        self.require_shop_stock(clerk, 'pokeBall')
        price = self.vermilion['shops'][clerk]['prices']['pokeBall']
        stock = self.quantity('pokeBall')
        wanted = max(0, self.config.get('collection_ball_stock', 20) - stock)
        remaining = max(0, self.config.get('collection_balls', 80) - self.collection['purchased'])
        reserve = self.config.get('collection_money_reserve', 600)
        affordable = max(0, self.inventory()['money'] - reserve) // price
        if affordable < min(wanted, remaining) and self.quantity('nugget'):
            self.travel(self.zone(mart))
            self.sell_collection_nugget(clerk)
            affordable = max(0, self.inventory()['money'] - reserve) // price
        count = min(wanted, remaining, affordable)
        if count:
            self.travel(self.zone(mart))
            # Path trainers can change money. Recheck the actual balance at clerk.
            count = min(count, max(0, self.inventory()['money'] - reserve) // price)
            if count:
                money = self.inventory()['money']
                self.buy_item(clerk, 'pokeBall', count, price)
                self.collection['purchased'] += count
                self.collection['purchases'].append({'clerk': clerk, 'count': count, 'price': price,
                                                       'money_before': money, 'money_after': self.inventory()['money']})
        if self.quantity('pokeBall') < self.config.get('collection_balls_per_battle', 12):
            raise ProtocolError('insufficient real ball stock/funds; reserve and finite purchase budget preserved')

    def collection_needs_healing(self):
        active = self.party()[lookup(self.state, 'session.party.active') - 1]
        damaging = [key for key in active['moves']
                    if self.observed_moves.get(key, {}).get('category') in {'physical', 'special'}]
        low_attack_pp = bool(damaging) and sum(active['pp'].get(key, 0) for key in damaging) < 3
        return (active['hp'] * 4 < active['maxHP'] * 3 or active['status'] not in {None, 'none'}
                or low_attack_pp or sum(active['pp'].values()) < 3)

    def collection_lane(self, name):
        model = self.model()
        if name != 'DiglettsCave' or any(any(row) for row in model.grass):
            return training_lane(model, self.position(), self.occupied())
        # The source cache currently marks no cave floor as grass. Ask the
        # actual Zone policy rather than inventing eligible terrain in the host.
        value = self.observe('vermilion-encounter-terrain')
        if value.get('zone_id') != self.state['zone_id']:
            raise ProtocolError('collection encounter terrain belongs to another map')
        cells = sequence(value.get('cells'), 'actual encounter cells')
        if not cells:
            raise ProtocolError('Diglett fallback requires root-owned eligible cave encounter terrain; actual Zone policy has no eligible cells')
        if len(cells) > model.width * model.height:
            raise ProtocolError('unbounded encounter terrain observation')
        shadow = copy.deepcopy(model)
        shadow.grass = [[False] * model.width for _ in range(model.height)]
        seen = set()
        for cell in cells:
            if (not isinstance(cell, dict) or set(cell) != {'x', 'y'}
                    or type(cell['x']) is not int or type(cell['y']) is not int):
                raise ProtocolError('invalid actual encounter terrain cell')
            point = (cell['x'], cell['y'])
            if point in seen or not model.inside(point) or model.collision[point[1]][point[0]]:
                raise ProtocolError('invalid or duplicate actual encounter terrain cell')
            seen.add(point)
            shadow.grass[point[1]][point[0]] = True
        return training_lane(shadow, self.position(), self.occupied())

    def collect(self, name, targets, center, mart, *, minimum_owned=None, required=True):
        policy = self.vermilion['collection'][name]
        if not set(targets) <= set(policy['targets']):
            raise ProtocolError('collection target is not a pinned common Blue slot')
        if 'bellsprout' in targets and not any(m['species'] == 'bellsprout' for m in self.party()) and len(self.party()) >= 6:
            raise ProtocolError('Bellsprout must be secured before filling the party')
        phase = {'map': name, 'targets': list(targets), 'owned_before': self.owned_count(), 'completed': False}
        self.collection['phases'].append(phase)
        initially_owned = cj.boolean_map(lookup(self.state, 'session.pokedex.owned'), 'owned')
        start_battles, start_steps = self.collection['battles'], self.collection['steps']
        self.acquisition_active = True
        self.acquisition_targets = set(targets)
        previous_mode = self.training_mode
        self.training_mode = 'vermilion-collection'
        try:
            self.heal_here(center)
            self.collection_supplies(mart)
            lane = None
            for _ in range(min(3000, self.config.get('collection_steps', 12000))):
                owned = cj.boolean_map(lookup(self.state, 'session.pokedex.owned'), 'owned')
                if all(owned.get(s) for s in targets) or minimum_owned is not None and self.owned_count() >= minimum_owned:
                    phase['completed'] = True
                    break
                if (self.collection['battles'] - start_battles >= self.config.get('collection_phase_battles', 60)
                        or self.collection['steps'] - start_steps >= 3000):
                    break
                try:
                    if self.collection_needs_healing():
                        self.heal_here(center)
                        lane = None
                    if self.quantity('pokeBall') < self.config.get('collection_balls_per_battle', 12):
                        self.collection_supplies(mart)
                        lane = None
                    if self.state['zone_id'] != self.zone(name):
                        self.travel(self.zone(name))
                        lane = None
                    # A real capture can also occur while walking from the
                    # Center or Mart into this map; do not take another step.
                    now_owned = cj.boolean_map(lookup(self.state, 'session.pokedex.owned'), 'owned')
                    if all(now_owned.get(s) for s in targets) or minimum_owned is not None and self.owned_count() >= minimum_owned:
                        break
                    if lane is None:
                        lane = self.collection_lane(name)
                    goal = lane[1] if self.position() == lane[0] else lane[0]
                    self.navigate(goal)
                except NaturalBlackout:
                    self.recover_blackout()
                    self.heal_here(center)
                    lane = None
            owned = cj.boolean_map(lookup(self.state, 'session.pokedex.owned'), 'owned')
            phase['completed'] = (all(owned.get(s) for s in targets)
                                  or minimum_owned is not None and self.owned_count() >= minimum_owned)
            receipts = {c['species'] for c in self.collection['captures'] if c.get('commit')}
            if any(owned.get(s) and not initially_owned.get(s) and s not in receipts for s in targets):
                raise ProtocolError('new collection owned flag lacks an actual capture commit receipt')
            phase.update(owned_after=self.owned_count(), battles=self.collection['battles'] - start_battles,
                         steps=self.collection['steps'] - start_steps)
            if required and not phase['completed']:
                raise ProtocolError('bounded natural acquisition did not obtain required common species: ' + name)
        finally:
            self.acquisition_active = False
            self.acquisition_targets = set()
            self.training_mode = previous_mode
        self.checkpoint('vermilion-collection-' + name.lower() + '-' + str(len(self.collection['phases'])))

    def event_map(self, event):
        return event.rsplit(':', 2)[0]

    def visit_event(self, event, stop_phase=None):
        self.travel(self.event_map(event))
        self.interact(source_id=event, stop_phase=stop_phase)

    def owned_count(self):
        owned = lookup(self.state, 'session.pokedex.owned')
        return sum(cj.boolean_map(owned, 'unique owned species').values())

    def gift(self, key):
        event, item, flag = GIFTS[key]
        threshold = self.vermilion['events'][event].get('threshold', 0)
        if self.owned_count() < threshold:
            raise ProtocolError(f'{key} needs {threshold} actual unique owned species; natural capture plan not yet feasible')
        self.travel(self.event_map(event))
        self.reward(event, item, flag)
        self.interact(source_id=event)
        if self.quantity(item) != 1:
            raise ProtocolError('repeated source gift duplicated item: ' + key)
        self.checkpoint('vermilion-' + key)

    def daycare_service(self):
        self.travel(self.zone('Daycare'))
        self.checkpoint('vermilion-daycare-visit')
        before = self.observe('vermilion-daycare')['owner']
        if before.get('pokemon') is not None or before.get('earned') != 0:
            raise ProtocolError('natural Day Care slot must initially be empty')
        members = sequence(before.get('party', {}).get('members'), 'Day Care actual party')
        starter = self.starter_index()
        index = next((i for i, mon in enumerate(members, 1)
                      if i != starter and not set(mon['moves']) & {'cut', 'fly', 'surf', 'strength', 'flash'}
                      and not mon.get('pendingMoveChoices') and not mon.get('pendingEvolution')
                      and any(other['hp'] > 0 for j, other in enumerate(members, 1) if j != i)), None)
        if index is None or len(members) < 2:
            raise ProtocolError('no actual eligible second Day Care member; natural capture required')
        selected = copy.deepcopy(members[index - 1])
        self.daycare_index = index
        try:
            self.interact(source_id=DAYCARE)
        finally:
            self.daycare_index = None
        deposited = self.observe('vermilion-daycare')['owner']
        if (deposited.get('pokemon') != selected or deposited['party']['members'] != members[:index - 1] + members[index:]
                or deposited['money'] != before['money'] or deposited['earned'] != 0):
            raise ProtocolError('actual Day Care deposit transferred the wrong specimen or charged money')
        self.checkpoint('vermilion-daycare-deposited')
        self.travel(self.zone('UndergroundPathRoute5'))
        self.travel(self.zone('Daycare'))
        # Quote after the last ordinary approach step; those steps also earn
        # XP, so an arrival-door quote would already be stale at interaction.
        self.approach_daycare()
        observation = self.observe('vermilion-daycare')
        grown, quote = observation['owner'], observation.get('withdrawal')
        if (grown.get('pokemon') != selected or type(grown.get('earned')) is not int or grown['earned'] <= 0
                or not isinstance(quote, dict) or quote.get('status') != 'ready'
                or type(quote.get('fee')) is not int or quote['fee'] < 100):
            raise ProtocolError('actual completed steps/withdrawal quote missing')
        self.interact(source_id=DAYCARE)
        after = self.observe('vermilion-daycare')['owner']
        returned = after['party']['members'][-1]
        mutable = {'xp', 'level', 'hp', 'maxHP', 'attack', 'defense', 'spAttack', 'spDefense', 'speed', 'moves', 'pp'}
        if (after.get('pokemon') is not None or after['earned'] != 0
                or len(after['party']['members']) != len(members)
                or after['money'] != grown['money'] - quote['fee']
                or returned['xp'] != selected['xp'] + grown['earned']
                or returned['species'] != selected['species']
                or {k: v for k, v in returned.items() if k not in mutable}
                   != {k: v for k, v in selected.items() if k not in mutable}):
            raise ProtocolError('actual paid Day Care withdrawal lost specimen traits, XP or money')
        self.summary['daycare_service'] = {'deposited': selected, 'earned': grown['earned'],
                                           'quote': quote, 'returned': returned}
        self.checkpoint('vermilion-daycare-paid-withdrawal')

    def approach_daycare(self):
        target = self.interaction_target(source_id=DAYCARE)
        self.navigate(set(self.model().approaches(target)))

    def teach_cut(self):
        index = next((i for i, mon in enumerate(self.party(), 1) if mon['species'] == 'bellsprout'), None)
        if index is None:
            index = next((i for i, mon in enumerate(self.party(), 1)
                          if mon['species'] in self.vermilion['cut_species']), None)
        if index is None:
            raise ProtocolError('no actually owned compatible Cut user; requires natural capture, never an artificial species')
        if 'cut' in self.party()[index - 1]['moves']:
            raise ProtocolError('natural Teaching witness requires an unlearned Cut')
        before = copy.deepcopy(self.party()[index - 1])
        quantity = self.quantity('hm01')
        self.send('press b')
        self.pause_option('ITEM')
        self.send('press a')
        self.require(root='bag', **{'bag.phase': 'list'})
        slots = self.inventory()['slots']
        selected = next((i for i, s in enumerate(slots, 1) if s['id'] == 'hm01'), None)
        if selected is None:
            raise ProtocolError('actual Captain HM01 missing from Bag')
        self.select('bag.selected', selected)
        self.send('press a')
        self.require(**{'bag.phase': 'actions'})
        self.select('bag.menu.selected', 1)
        self.send('press a')
        self.require(root='party')
        self.select('party_ui.selected', index)
        self.send('press a')
        self.require(root='learning')
        # Deliberate Teaching decision: preserve existing HMs; choose one actual
        # non-HM slot if all four slots are occupied. Do not score Cut away.
        for _ in range(160):
            if self.state.get('root') != 'learning':
                break
            if lookup(self.state, 'learning.input_blocked'):
                self.send('wait 2')
                continue
            phase = lookup(self.state, 'learning.phase')
            if phase == 'message':
                if lookup(self.state, 'learning.dialog_ready'):
                    self.send('press a')
                else:
                    self.send('wait 3')
            elif phase == 'ask':
                self.select('learning.selected', 1)
                self.send('press a')
            elif phase == 'replace':
                known = sequence(lookup(self.state, 'learning.known_moves'), 'known moves')
                replace = next((i for i, m in enumerate(known, 1)
                                if m['key'] not in {'cut', 'fly', 'surf', 'strength', 'flash'}), None)
                if replace is None:
                    raise ProtocolError('no replaceable Cut slot')
                self.select('learning.selected', replace)
                self.send('press a')
            elif phase == 'confirm':
                self.select('learning.selected', 1)
                self.send('press a')
            elif phase == 'idle':
                self.send('wait 2')
            else:
                raise ProtocolError('unexpected Teaching phase: ' + str(phase))
        else:
            raise ProtocolError('Teaching input bound exhausted')
        mon = self.party()[index - 1]
        if 'cut' not in mon['moves'] or self.quantity('hm01') != quantity or mon['species'] != before['species']:
            raise ProtocolError('actual Teaching did not learn reusable HM01')
        self.send('press b')
        self.require(root='overworld')
        self.checkpoint('vermilion-actual-teaching-cut')
        return index

    def field_cut(self, index):
        self.travel(self.zone('VermilionCity'))
        site = self.vermilion['cut_sites'][0]
        target = site['targets'][0]
        cell = (target['x'] + self.model().padding, target['y'])
        approaches = self.model().approaches(cell)
        self.navigate(set(approaches))
        direction = next((d for d, (dx, dy) in DIRECTIONS.items()
                          if (self.position()[0] + dx, self.position()[1] + dy) == cell), None)
        if direction is None:
            raise ProtocolError('no actual adjacent tree pose')
        self.face(direction)
        self.send('press b')
        self.pause_option('POKEMON')
        self.send('press a')
        self.require(root='party')
        self.select('party_ui.selected', index)
        self.send('press a')
        options = sequence(lookup(self.state, 'party_ui.menu.options'), 'actual field actions')
        if options.count('CUT') != 1:
            raise ProtocolError('actual party field menu lacks CUT')
        self.select('party_ui.menu.selected', options.index('CUT') + 1)
        self.send('press a')
        # field_move is a tiny read-only UI observation required from root.
        self.require(root='fieldMove', **{'field_move.phase': 'confirm'})
        self.select('field_move.menu.selected', 2)
        self.send('press a')
        self.require(**{'field_move.phase': 'announce'})
        self.checkpoint('vermilion-field-cut-announce-' + str(self.cut_witnesses + 1))
        self.cut_witnesses += 1
        self.send('press a', 'record vermilion-cut-effect-' + str(self.cut_witnesses) + ' 12')
        self.require(root='overworld', **{'field_move.lastResult.ok': True})
        observed = self.observe('vermilion-world')
        self.apply_world_observation(observed)
        self.cut_cells = [{'x': c['x'] + self.model().padding, 'y': c['y'], 'key': c['after']} for c in site['cells']]
        by_position = {(c['x'], c['y']): c['key'] for c in observed['cells']}
        if any(by_position.get((c['x'], c['y'])) != c['key'] for c in self.cut_cells):
            raise ProtocolError('actual Cut source block differs from declared replacement')
        self.checkpoint('vermilion-field-cut-tree-' + str(self.cut_witnesses))

    def apply_world_observation(self, value):
        if value.get('zone_id') != self.state.get('zone_id'):
            raise ProtocolError('world observation belongs to another map')
        model = self.model()
        collision = value.get('collision')
        if (not isinstance(collision, list) or len(collision) != model.height
                or any(not isinstance(row, list) or len(row) != model.width
                       or any(type(v) is not int or v not in (0, 1) for v in row) for row in collision)):
            raise ProtocolError('invalid actual world collision observation')
        # Detached host planning model only; production Zone remains sole owner.
        model.collision = copy.deepcopy(collision)

    def puzzle(self):
        cans = self.vermilion['scenes']['trash']['cans']
        table = self.vermilion['scenes']['trash']['table']
        attempts = 0
        while not self.flag('EVENT_2ND_LOCK_OPENED'):
            # Search real cans. Only visible lock progress guides decisions; do
            # not read persisted secret can indices or predict world RNG draws.
            for can in cans:
                if attempts >= self.config.get('max_puzzle_attempts', 240):
                    raise ProtocolError('actual Surge puzzle attempt bound exhausted')
                self.inspect_can(can)
                attempts += 1
                if self.flag('EVENT_1ST_LOCK_OPENED'):
                    candidates = list(dict.fromkeys([0] + table[can['index']][1:]))
                    for candidate in candidates:
                        if attempts >= self.config.get('max_puzzle_attempts', 240):
                            raise ProtocolError('actual Surge puzzle attempt bound exhausted')
                        self.inspect_can(cans[candidate])
                        attempts += 1
                        if self.flag('EVENT_2ND_LOCK_OPENED') or not self.flag('EVENT_1ST_LOCK_OPENED'):
                            break
                if self.flag('EVENT_2ND_LOCK_OPENED'):
                    break
        self.apply_world_observation(self.observe('vermilion-world'))
        self.checkpoint('vermilion-surge-switches-open')

    def inspect_can(self, can):
        point = (can['x'] + self.model().padding, can['y'])
        self.navigate(set(self.model().approaches(point)))
        direction = next((d for d, (dx, dy) in DIRECTIONS.items()
                          if (self.position()[0] + dx, self.position()[1] + dy) == point), None)
        if direction is None:
            raise ProtocolError('no adjacent source can pose')
        self.face(direction)
        self.send('press a')
        if lookup(self.state, 'event.id') != can['id']:
            raise ProtocolError('actual hidden can dispatch differs')
        self.drain()

    def natural(self):
        # No save import exists here. The exact accepted Cerulean real-input path
        # runs first, in this same identified process and with the same RNG.
        super().natural()
        self.begin_continuation()
        self.summary['acceptance'] = '5.3 path saved; private 5.4 candidate in progress'
        self.travel(self.zone('CeruleanCity'))
        # The robbed-house Rocket is a real required battle, not a seeded flag.
        self.fight(cj.sid('CERULEAN_CITY', 2))
        self.collect('Route24', ['bellsprout'], 'CeruleanPokecenter', 'CeruleanMart')
        self.collect('Route24', ['caterpie', 'metapod', 'pidgey'], 'CeruleanPokecenter', 'CeruleanMart')
        if not any(m['species'] == 'bellsprout' for m in self.party()):
            raise ProtocolError('actual Cut-compatible Bellsprout did not remain in the party')
        self.travel(self.zone('Route5'))
        self.daycare_service()
        self.travel(self.zone('UndergroundPathRoute5'))
        self.travel(self.zone('UndergroundPathNorthSouth'))
        self.travel(self.zone('UndergroundPathRoute6'))
        self.travel(self.zone('Route6'))
        self.collect('Route6', ['meowth'], 'VermilionPokecenter', 'VermilionMart')
        self.heal_here('VermilionPokecenter')
        self.gift('voucher')
        self.gift('rod')
        self.travel(self.zone('VermilionDock'))
        self.travel(self.zone('SSAnne1F'))
        for name in ('SSAnne1FRooms', 'SSAnneB1FRooms', 'SSAnne2FRooms',
                     'SSAnneKitchen', 'SSAnne3F', 'SSAnneBow'):
            self.visit_all_cabins(name)
        trigger = self.vermilion['scenes']['rival']['variants'][0]['trigger']
        self.travel(self.zone('SSAnne2F'), (trigger['x'] + self.models[self.zone('SSAnne2F')].padding, trigger['y']))
        if not self.defeated(RIVAL) or not any(r.get('trainer_id') == RIVAL and r.get('won') for r in self.summary['source_receipts']):
            raise ProtocolError('actual positional Anne rival battle receipt missing')
        self.gift('hm01')
        index = self.teach_cut()
        self.travel(self.zone('VermilionCity'))
        if not self.flag('EVENT_SS_ANNE_LEFT'):
            raise ProtocolError('actual post-HM01 ship exit/departure did not commit')
        self.checkpoint('vermilion-ship-departed')
        self.field_cut(index)
        self.travel(self.zone('VermilionGym'))
        self.apply_world_observation(self.observe('vermilion-world'))
        self.puzzle()
        self.fight(SURGE)
        if not all(self.flag(f) for f in ('BADGE_THUNDER', 'EVENT_BEAT_LT_SURGE', 'EVENT_GOT_TM24')) or self.quantity('tm24') != 1:
            raise ProtocolError('actual Surge win/badge/TM24 transaction missing')
        self.repeat_trainer(SURGE)
        self.checkpoint('vermilion-surge-badge-tm24')
        self.heal_here('VermilionPokecenter')
        self.collect('Route11', ['sandshrew', 'spearow', 'drowzee'],
                     'VermilionPokecenter', 'VermilionMart', minimum_owned=10, required=False)
        if self.owned_count() < 10:
            self.collect('DiglettsCave', ['diglett'], 'VermilionPokecenter', 'VermilionMart')
        if self.owned_count() < 10:
            raise ProtocolError('actual common captures did not reach the ten-species HM05 threshold')
        for name in ('DiglettsCaveRoute11', 'DiglettsCave', 'DiglettsCaveRoute2', 'Route2Gate'):
            self.travel(self.zone(name))
            self.checkpoint('vermilion-visit-' + name.lower())
        self.gift('hm05')
        self.travel(self.zone('Route11'))
        self.checkpoint('vermilion-route11')
        self.save()
        self.write_receipt()
        self.summary.update(acceptance='candidate saved; actual process restart pending', forbidden_shortcuts=False)

    def visit_all_cabins(self, name):
        model = self.models[self.zone(name)]
        # Each disconnected room component is entered at its exact source warp;
        # travelling to the map name alone would cover only the first cabin.
        for event in model.events['warps']:
            point = (event['x'], event['y'])
            goals = set(model.approaches(point))
            if not goals:
                raise ProtocolError('source cabin has no passable approach')
            self.travel(model.name, goals)
            for actor in model.events['objects']:
                if actor['id'] not in self.source_trainers or self.defeated(actor['id']):
                    continue
                try:
                    model.path(self.position(), set(model.approaches((actor['x'], actor['y']))), self.occupied())
                except ProtocolError:
                    continue
                self.fight(actor['id'])
            self.checkpoint('vermilion-cabin-' + name.lower() + '-' + str(event['source_index']))

    def receipt_state(self):
        campaign = cj.CeruleanJourney.receipt_state(self)
        return {'campaign': campaign, 'classification': 'supplementary' if self.config.get('supplementary') else 'natural',
                'case': self.config.get('case'), 'cut_cells': copy.deepcopy(self.cut_cells)}

    def write_receipt(self):
        if not self.vermilion_active:
            return
        state = self.receipt_state()
        validate_receipt_state(state)
        packet = dict(schema=1, kind='vermilion-saved', state=state,
                      **{key: self.client.identity[key] for key in ('build_id', 'session_id')})
        path = self.evidence / 'journey-receipt.json'
        atomic_json(path, packet)
        self.summary['receipt'] = {'path': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

    def continue_saved(self, prior):
        if (not isinstance(prior, dict) or prior.get('schema') != 1 or prior.get('kind') != 'vermilion-saved'
                or any(prior.get(k) != self.client.identity[k] for k in ('build_id', 'session_id'))):
            raise ProtocolError('missing/wrong-build Vermilion continuation receipt')
        validate_receipt_state(prior.get('state'))
        saved = prior['state']
        if saved['classification'] != ('supplementary' if self.config.get('supplementary') else 'natural') or saved['case'] != self.config.get('case'):
            raise ProtocolError('Continue cannot relabel supplementary evidence')
        campaign = saved['campaign']
        self.starter = campaign['starter']
        self.config.update(starter=self.starter, fossil=campaign['fossil'])
        self.dependencies()
        self.stage = 'cerulean'
        self.vermilion_active = True
        self.cut_cells = copy.deepcopy(saved['cut_cells'])
        self.require(root='title', **{'title.phase': 'menu'})
        options = sequence(lookup(self.state, 'title.menu.options'), 'title menu')
        if options.count('CONTINUE') != 1:
            raise ProtocolError('title lacks exactly one actual CONTINUE')
        self.select('title.selected', options.index('CONTINUE') + 1)
        self.checkpoint('vermilion-title-continue')
        self.send('press a')
        self.drain()
        self.boundary_payload = self.codec_guard('loaded')
        if self.receipt_state() != saved:
            raise ProtocolError('actual Continue differs from immutable full codec receipt')
        if saved['case'] == 'field-cut-reload':
            self.assert_cut_restored()
        elif saved['classification'] == 'natural':
            if not self.defeated(SURGE) or not self.flag('EVENT_GOT_HM05') or self.quantity('hm05') != 1:
                raise ProtocolError('Continue lost milestone 5.4 progress')
        self.checkpoint('vermilion-continued')
        self.write_receipt()
        self.summary['acceptance'] = 'candidate Continue completed; root visual acceptance remains separate'

    def assert_cut_restored(self):
        self.travel(self.zone('VermilionCity'))
        observed = self.observe('vermilion-world')
        self.apply_world_observation(observed)
        actual = {(c['x'], c['y']): c['key'] for c in observed['cells']}
        expected = self.vermilion['cut_sites'][0]['cells']
        if any(actual.get((c['x'] + self.model().padding, c['y'])) != c['before'] for c in expected):
            raise ProtocolError('temporary Cut did not reset at map/process reload')

    def supplementary(self):
        self.dependencies()
        self.stage = 'cerulean'
        self.vermilion_active = True
        case = self.config['case']
        self.summary.update(natural=False, supplementary=True)
        if case == 'field-cut-reload':
            self.setup_fixture('VermilionCity', inventory={'money': 3000, 'slots': [{'id': 'hm01', 'quantity': 1}]},
                               quest_flags={'BADGE_CASCADE': True}, player_pokemon={'species': 'bulbasaur', 'level': 20})
            index = self.teach_cut()
            self.field_cut(index)
            self.travel(self.zone('VermilionPokecenter'))
            self.assert_cut_restored()
            self.field_cut(index)
            self.save()
            self.write_receipt()
            return
        if case == 'blackout':
            self.setup_fixture('VermilionPokecenter', player_pokemon={'species': 'squirtle', 'level': 1})
            self.allow_blackout = True
            self.heal_here('VermilionPokecenter')
            checkpoint = copy.deepcopy(lookup(self.state, 'session.checkpoint'))
            self.blackout_probe = True
            try:
                self.travel(self.zone('Route6'))
                trainer = next(d for d in self.source_trainers.values() if d['map_id'] == self.zone('Route6'))
                self.interact(source_id=trainer['id'])
            except NaturalBlackout:
                pass
            else:
                raise ProtocolError('supplementary blackout did not reach actual loss')
            finally:
                self.blackout_probe = False
            self.recover_blackout()
            if lookup(self.state, 'session.checkpoint') != checkpoint:
                raise ProtocolError('actual blackout changed Center checkpoint')
            if any(self.flag(f) for f in ('BADGE_THUNDER', 'EVENT_BEAT_LT_SURGE', 'EVENT_GOT_TM24')):
                raise ProtocolError('actual loss granted Surge rewards')
            self.checkpoint('vermilion-supplementary-blackout')
            return
        key = case.removesuffix('-full-retry')
        event, item, flag = GIFTS[key]
        name = next(n for n, e in self.map_manifest['maps'].items() if e['id'] == self.event_map(event))
        setup = {'inventory': {'money': 3000, 'slots': [{'id': i, 'quantity': 1} for i in cj.FULL_BAG]}}
        if key in {'hm05', 'itemfinder'}:
            setup['vermilion_aide_capacity'] = key
        else:
            setup['player_pokemon'] = {'species': 'squirtle', 'level': 40}
        self.setup_fixture(name, **setup)
        if key in {'hm05', 'itemfinder'}:
            self.qualify_aide_fixture(key)
        if key == 'tm24':
            self.apply_world_observation(self.observe('vermilion-world'))
            self.puzzle()
        self.visit_event(event)
        if self.flag(flag) or self.quantity(item):
            raise ProtocolError('full bag lost source reward eligibility')
        if key == 'tm24' and (not self.defeated(SURGE) or not self.flag('BADGE_THUNDER')):
            raise ProtocolError('full bag lost actual Surge victory/badge')
        before = (self.inventory()['money'], len(self.summary['battles']))
        self.toss_single()
        self.reward(event, item, flag)
        self.interact(source_id=event)
        if self.quantity(item) != 1 or before != (self.inventory()['money'], len(self.summary['battles'])):
            raise ProtocolError('reward retry duplicated item/battle/payout')
        self.codec_guard()
        self.checkpoint('vermilion-supplementary-' + case)
        self.summary['acceptance'] = 'supplementary candidate only; no natural campaign credit'

    def qualify_aide_fixture(self, key):
        if not self.config.get('supplementary') or self.config.get('case') != key + '-full-retry':
            raise ProtocolError('aide capacity setup cannot enter the natural journey')
        threshold = self.vermilion['events'][GIFTS[key][0]]['threshold']
        receipt = self.observe('vermilion-aide-fixture')
        if (receipt.get('classification') != 'supplementary' or receipt.get('case') != key
                or receipt.get('threshold') != threshold or receipt.get('owned') != threshold):
            raise ProtocolError('missing actual supplementary aide recruitment receipt')
        owner = self.collection_owner()
        all_mons = owner['party']['members'] + [m for b in owner['storage']['boxes'] for m in sequence(b, 'fixture box')]
        species = {m['species'] for m in all_mons}
        owned = {s for s, flag in owner['owned'].items() if flag}
        recruits = sequence(receipt.get('recruits'), 'aide recruitment receipts')
        if (len(species) != threshold or len(all_mons) != threshold or species != owned
                or len(owner['party']['members']) != 6 or len(recruits) != threshold - 1
                or {r.get('species') for r in recruits} != species - {'squirtle'}):
            raise ProtocolError('aide fixture threshold lacks distinct actually recruited specimens')
        for record in recruits:
            destination = record.get('destination')
            if not isinstance(destination, dict):
                raise ProtocolError('aide fixture recruitment destination missing')
            if destination.get('destination') == 'party':
                members = owner['party']['members']
            elif destination.get('destination') == 'storage' and type(destination.get('box')) is int and 1 <= destination['box'] <= 12:
                members = sequence(owner['storage']['boxes'][destination['box'] - 1], 'fixture recruited box')
            else:
                raise ProtocolError('invalid actual aide recruitment destination')
            index = destination.get('index')
            if type(index) is not int or not 1 <= index <= len(members) or members[index - 1]['species'] != record['species']:
                raise ProtocolError('aide fixture receipt does not point to the actual specimen')
        self.summary['aide_fixture'] = copy.deepcopy(receipt)

    def setup_fixture(self, name, **options):
        if not self.config.get('supplementary'):
            raise ProtocolError('Vermilion setup fixture requires explicit supplementary mode')
        entry = self.map_manifest['maps'][name]
        fixture = dict(intro='skip', opening=False, zone=entry['key'], entry=copy.deepcopy(entry['spawn']), **options)
        self.initializing = True
        try:
            self.reset(**fixture)
        finally:
            self.initializing = False


def run(client, scenario, evidence, build_evidence=None, prior_receipt=None, capture_dir=None):
    journey = None
    try:
        journey = VermilionJourney(client, evidence, scenario['journey'], build_evidence, capture_dir)
        name = scenario['journey']['name']
        if name.endswith('continue'):
            journey.continue_saved(prior_receipt)
        elif name == 'vermilion-natural':
            journey.natural()
        else:
            journey.supplementary()
    except BaseException as error:
        summary = journey.summary if journey else {'schema': 1, 'acceptance': 'unrun candidate'}
        summary.update(ok=False, error=str(error), journey_outcome='failed', last_snapshot=journey.state if journey else {})
        atomic_json(Path(evidence) / 'journey-summary.json', summary)
        raise
    journey.summary.update(ok=True, journey_outcome='complete', last_snapshot=journey.state)
    atomic_json(Path(evidence) / 'journey-summary.json', journey.summary)
    return journey.summary
