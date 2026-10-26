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
from tools.harness.brock_journey import BrockJourney, NaturalBlackout
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
BOUNDS = dict(cj.BOUNDS, max_puzzle_attempts=(1, 512))
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
    adapted = {k: v for k, v in config.items() if k not in {'case', 'max_puzzle_attempts'}}
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


def validate_boundary_payload(payload):
    if not isinstance(payload, dict) or payload.get('version') != 3:
        return cj.validate_boundary_payload(payload)
    if set(payload) != cj.CODEC_FIELDS | {'fieldWorld', 'daycare'}:
        raise ProtocolError('incomplete schema 3 Save/Continue payload')
    legacy = copy.deepcopy(payload)
    daycare = legacy.pop('daycare')
    legacy['version'] = 2
    cj.validate_boundary_payload(legacy)
    if (not isinstance(daycare, dict) or set(daycare) - {'version', 'earned', 'pokemon'}
            or type(daycare.get('version')) is not int or daycare['version'] != 1
            or not isinstance(daycare.get('earned'), str) or not daycare['earned'].isascii()
            or not daycare['earned'].isdigit() or str(int(daycare['earned'])) != daycare['earned']
            or not 0 <= int(daycare['earned']) <= 1250000
            or 'pokemon' in daycare and not isinstance(daycare['pokemon'], dict)
            or 'pokemon' not in daycare and daycare['earned'] != '0'):
        raise ProtocolError('invalid canonical Day Care wire record')


def validate_campaign_receipt(state):
    if not isinstance(state, dict) or not isinstance(state.get('codec'), dict):
        raise ProtocolError('missing full campaign codec receipt')
    validate_boundary_payload(state['codec'])
    # Reuse the earlier receipt envelope checks without discarding any bytes in
    # the actual receipt. SDK validation owns all nested Pokemon semantics.
    legacy = copy.deepcopy(state)
    if legacy['codec']['version'] == 3:
        legacy['codec'].pop('daycare')
        legacy['codec']['version'] = 2
    cj.validate_receipt_state(legacy)


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
              'cut_sites', 'cut_species', 'session_codec', 'daycare_inputs', 'registration'}
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


class VermilionJourney(cj.CeruleanJourney):
    def __init__(self, client, evidence, config, build_evidence=None, capture_dir=None):
        validate_config(config)
        adapted = {k: v for k, v in config.items() if k not in {'case', 'supplementary', 'max_puzzle_attempts'}}
        adapted['name'] = 'cerulean-natural'
        super().__init__(client, evidence, adapted, build_evidence, capture_dir)
        self.config = copy.deepcopy(config)
        self.summary['journey'] = copy.deepcopy(config)
        self.vermilion_active = False
        self.cut_cells = []
        self.cut_witnesses = 0
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

    def codec_guard(self, boundary=None):
        observed = self.observe(boundary or 'validate')
        if (observed.get('version') != self.export['session_codec'] or observed.get('valid') is not True
                or observed.get('roundtrip_equal') is not True):
            raise ProtocolError('actual canonical codec validation failed')
        if boundary:
            payload = observed.get('payload')
            validate_boundary_payload(payload)
            if payload['version'] != self.export['session_codec']:
                raise ProtocolError('boundary codec version differs')
            return copy.deepcopy(payload)
        if 'payload' in observed:
            raise ProtocolError('validation cannot masquerade as a Save/Continue receipt')
        return None

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
        result = super().cross(direction, zone, destination)
        self.refresh_world()
        return result

    def travel(self, target_id, goal=None):
        # Map reload restores temporary Cut; use actual settled terrain at each
        # transition rather than retaining the earlier host collision override.
        self.refresh_world()
        return super().travel(target_id, goal)

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
        self.vermilion_active = True
        self.summary['acceptance'] = '5.3 path saved; private 5.4 candidate in progress'
        self.travel(self.zone('CeruleanCity'))
        # The robbed-house Rocket is a real required battle, not a seeded flag.
        self.fight(cj.sid('CERULEAN_CITY', 2))
        self.travel(self.zone('Route5'))
        self.daycare_service()
        self.travel(self.zone('UndergroundPathRoute5'))
        self.travel(self.zone('UndergroundPathNorthSouth'))
        self.travel(self.zone('UndergroundPathRoute6'))
        self.travel(self.zone('Route6'))
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
        if case in {'hm05-full-retry', 'itemfinder-full-retry'}:
            raise ProtocolError('supplementary fixture input missing: existing fixture API cannot supply 10/30 unique owned species; seen/duplicates do not qualify')
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
        self.setup_fixture(name, player_pokemon={'species': 'squirtle', 'level': 40},
                           inventory={'money': 3000, 'slots': [{'id': i, 'quantity': 1} for i in cj.FULL_BAG]})
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

    def setup_fixture(self, name, **options):
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
