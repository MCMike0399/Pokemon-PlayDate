"""Earned 5.4 -> 5.5 input journeys. Root alone owns Simulator and save import.

Reuse existing route, battle, menu, capture and restart owners. No planner,
fixture, state setter, artificial reward or free preparation battle is provided.
"""
import copy
import hashlib
import json
from pathlib import Path

from tools.harness import cerulean_journey as cj
from tools.harness import vermilion_journey as vj
from tools.harness.brock_journey import BrockJourney, NaturalBlackout
from tools.harness.journeys import DIRECTIONS, lookup
from tools.harness.parcel_journey import sequence
from tools.harness.protocol import ProtocolError, atomic_json

NAMES = {'midgame-natural', 'midgame-continue'}
SCENARIOS = Path(__file__).with_name('scenarios') / 'midgame'
BOUNDS = {'max_actions': (1, 120000), 'max_steps': (1, 20000),
          'max_encounters': (1, 256), 'max_blackouts': (0, 2), 'max_transitions': (1, 512)}
HMS = {'cut': 'hm01', 'fly': 'hm02', 'surf': 'hm03', 'strength': 'hm04', 'flash': 'hm05'}


def validate_config(config):
    allowed = set(BOUNDS) | {'name', 'starter', 'packet', 'content_scope', 'evolution_policy'}
    if not isinstance(config, dict) or set(config) - allowed or config.get('name') not in NAMES:
        raise ProtocolError('unknown or malformed midgame journey')
    for key, (low, high) in BOUNDS.items():
        if key in config and (type(config[key]) is not int or not low <= config[key] <= high):
            raise ProtocolError('invalid bounded midgame option: ' + key)
    if config.get('starter') not in cj.FAMILIES or config.get('packet') not in {'lavender', 'full'}:
        raise ProtocolError('midgame requires an original starter and explicit route packet')
    expected = 'optional' if config['starter'] == 'charmander' else 'critical'
    if config.get('content_scope') != expected or config.get('evolution_policy', 'accept') != 'accept':
        raise ProtocolError('midgame scope is Charmander optional, Bulbasaur/Squirtle critical; accept natural evolution')


def validate_scenario(scenario):
    if not isinstance(scenario, dict) or set(scenario) != {'initial_save', 'processes'}:
        raise ProtocolError('midgame requires exactly an earned save and two processes')
    groups = scenario['processes']
    if not isinstance(groups, list) or len(groups) != 2:
        raise ProtocolError('midgame requires natural Save followed by actual process Continue')
    for index, group in enumerate(groups):
        if not isinstance(group, dict) or set(group) != ({'journey'} if index == 0 else {'restart', 'journey'}):
            raise ProtocolError('midgame cannot mix input journey with fixture/command process')
        validate_config(group['journey'])
        if group['journey']['name'] != ('midgame-natural' if index == 0 else 'midgame-continue'):
            raise ProtocolError('midgame process order differs')
        if index and (group['restart'] is not True or any(group['journey'].get(k) != groups[0]['journey'].get(k)
                for k in ('starter', 'packet', 'content_scope'))):
            raise ProtocolError('midgame Continue changed earned route identity')
    if scenario['initial_save'] != {'milestone': '5.4', 'starter': groups[0]['journey']['starter']}:
        raise ProtocolError('midgame must start from accepted chain/5.4/<starter>')


def validate_chain_record(record, spec, project):
    proof = json.loads((Path(project) / 'docs/validation/vermilion-acceptance-20261028.json').read_bytes())
    if (spec['milestone'] != '5.4' or record.get('from_milestone') != '5.4'
            or record.get('starter') != spec['starter'] or proof.get('milestone_accepted') is not True
            or record.get('accepted_commit') != proof.get('accepted_main_code')
            or record.get('accepted_source_sha256') != proof.get('accepted_source_sha256')
            or not any(v.get('starter') == spec['starter'] for v in proof.get('final_build_verification', {}).get('starters', []))):
        raise ProtocolError('starting slots lack accepted final-build Vermilion ancestry')


def validate_receipt_state(state):
    if not isinstance(state, dict) or set(state) != {'starter', 'packet', 'content_scope', 'codec', 'completed_steps'}:
        raise ProtocolError('malformed midgame saved receipt')
    validate_config(dict(name='midgame-continue', **{k: state[k] for k in ('starter', 'packet', 'content_scope')}))
    cj.validate_boundary_payload(state['codec'])
    steps = state['completed_steps']
    if not isinstance(steps, list) or any(not isinstance(s, str) for s in steps) or steps != sorted(set(steps)):
        raise ProtocolError('invalid completed input-step observations')


class MidgameJourney(vj.VermilionJourney):
    def __init__(self, client, evidence, config, build_evidence=None, capture_dir=None):
        validate_config(config)
        adapted = dict(name='vermilion-natural', starter=config['starter'], content_scope='critical',
                       evolution_policy='accept', max_actions=min(config.get('max_actions', 20000), 20000),
                       max_steps=min(config.get('max_steps', 5000), 5000),
                       max_encounters=min(config.get('max_encounters', 64), 64),
                       max_blackouts=config.get('max_blackouts', 1))
        super().__init__(client, evidence, adapted, build_evidence, capture_dir)
        self.config = copy.deepcopy(config)
        self.summary.update(journey=copy.deepcopy(config), milestone='5.5', acceptance='unrun candidate',
                            driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                            preparation_policy={'new_training_fights': 0, 'use_centers_and_shops': True})
        self.stage = 'cerulean'  # Existing shared source-trainer validation path.
        self.completed_steps = set()
        self.vermilion_active = True
        self.midgame_ready = False

    def frame_label(self, label):
        if label.startswith('m55-'):
            return label
        if getattr(self, 'saving', False):
            label = 'save-' + str(self.save_number) + '-' + label
        return 'm55-' + self.state.get('zone_id', 'title').replace('pokered:', '').lower() + '-' + label

    def reset(self, **options):
        raise ProtocolError('midgame forbids New Game, resets and fixtures')

    def training_battle(self):
        raise ProtocolError('midgame forbids XP preparation fights')

    def dependencies(self):
        BrockJourney.dependencies(self)
        source = cj.StagedSource(self.build_evidence)
        self.models, self.map_manifest, self.doors = cj.source_models(source)
        self.vermilion = source.read('dev/vermilionJourney.json')
        self.field_definitions = source.read('data/fieldMoves.json')
        self.ordinary_events = {}
        for package in ('sourceSlice', 'vermilionPreparation', 'midgameEast', 'midgameSouth', 'midgameSaffron'):
            self.source_trainers.update(source.read('data/' + package + '/trainers.json')['trainers'])
            self.ordinary_events.update(source.read('data/' + package + '/events.json')['events'])
        owners = self.observe('midgame-owners')
        if owners.get('valid') is not True or type(owners.get('version')) is not int:
            raise ProtocolError('root midgame owner observation unavailable')
        self.export = {'session_codec': owners['version']}
        self.registered_events = owners['registered_events']
        self.vermilion['shops'].update(owners['shops'])
        for stable, definition in owners['trainers'].items():
            self.source_trainers[stable] = definition
        self.midgame_ready = True
        self.summary['midgame_dependencies'] = {'build_id': self.client.identity['build_id'],
            'active_maps': len(self.map_manifest['maps']), 'session_codec': owners['version']}

    def title_continue(self):
        self.require(root='title', **{'title.phase': 'menu'})
        options = sequence(lookup(self.state, 'title.menu.options'), 'title options')
        if options.count('CONTINUE') != 1:
            raise ProtocolError('earned save did not expose exactly one CONTINUE')
        self.select('title.selected', options.index('CONTINUE') + 1)
        self.send('press a')
        self.drain()
        if not any(mon['species'] in cj.FAMILIES[self.starter] for mon in self.party()):
            raise ProtocolError('loaded earned save has the wrong starter')

    def start_earned(self):
        provenance = json.loads((self.build_evidence / 'starting-save.json').read_bytes())
        if provenance.get('from_milestone') != '5.4' or provenance.get('starter') != self.starter:
            raise ProtocolError('midgame requires imported accepted 5.4 save provenance')
        self.dependencies()
        self.title_continue()
        for flag in ('EVENT_GOT_HM01', 'EVENT_GOT_HM05', 'BADGE_THUNDER'):
            if not self.flag(flag):
                raise ProtocolError('earned 5.4 progression missing: ' + flag)
        if not self.defeated(vj.SURGE) or self.quantity('hm01') < 1 or self.quantity('hm05') < 1:
            raise ProtocolError('earned Surge/Cut/Flash state missing')
        self.summary['starting_save'] = provenance
        self.checkpoint('earned-flash-continue')

    def require_event(self, stable):
        if self.registered_events.get(stable) is not True:
            raise ProtocolError('unavailable gameplay event; root must integrate owner: ' + stable)

    def visit_event(self, event, stop_phase=None):
        self.require_event(event)
        return super().visit_event(event, stop_phase)

    def use_field(self, index, move):
        self.send('press b')
        self.pause_option('POKEMON')
        self.send('press a')
        self.require(root='party')
        self.select('party_ui.selected', index)
        self.send('press a')
        options = sequence(lookup(self.state, 'party_ui.menu.options'), 'field options')
        if options.count(move.upper()) != 1:
            raise ProtocolError('unavailable actual party field action: ' + move)
        self.select('party_ui.menu.selected', options.index(move.upper()) + 1)
        self.send('press a')
        self.require(root='fieldMove', **{'field_move.phase': 'confirm'})
        choices = sequence(lookup(self.state, 'field_move.menu.options'), 'field confirmation')
        if choices.count('YES') != 1:
            raise ProtocolError('field confirmation lacks actual YES')
        self.select('field_move.menu.selected', choices.index('YES') + 1)
        self.send('press a')
        self.require(**{'field_move.phase': 'announce'})
        self.send('press a')
        self.drain()
        self.require(root='overworld', **{'field_move.lastResult.ok': True})

    def teach(self, move):
        known = next((i for i, mon in enumerate(self.party(), 1) if move in mon['moves']), None)
        if known:
            return known
        owners = self.observe('midgame-owners')
        compatible = owners.get('hm_compatibility', {}).get(HMS[move])
        if not isinstance(compatible, list):
            raise ProtocolError('actual HM compatibility observation unavailable: ' + move)
        index = next((i for i, mon in enumerate(self.party(), 1) if mon['species'] in compatible), None)
        if index is None:
            raise ProtocolError('no earned compatible HM user: ' + move)
        item = HMS[move]
        quantity = self.quantity(item)
        self.send('press b')
        self.pause_option('ITEM')
        self.send('press a')
        self.require(root='bag', **{'bag.phase': 'list'})
        slot = next((i for i, s in enumerate(self.inventory()['slots'], 1) if s['id'] == item), None)
        if slot is None:
            raise ProtocolError('earned HM missing: ' + item)
        self.select('bag.selected', slot)
        self.send('press a')
        self.select('bag.menu.selected', 1)
        self.send('press a')
        self.require(root='party')
        self.select('party_ui.selected', index)
        self.send('press a')
        for _ in range(160):
            if self.state.get('root') != 'learning':
                break
            phase = lookup(self.state, 'learning.phase')
            if lookup(self.state, 'learning.input_blocked'):
                self.send('wait 2')
            elif phase == 'message':
                self.send('press a' if lookup(self.state, 'learning.dialog_ready') else 'wait 3')
            elif phase == 'replace':
                known = sequence(lookup(self.state, 'learning.known_moves'), 'known moves')
                replacement = next((i for i, m in enumerate(known, 1) if m['key'] not in HMS), None)
                if replacement is None:
                    raise ProtocolError('all earned move slots are protected HMs')
                self.select('learning.selected', replacement)
                self.send('press a')
            elif phase in {'ask', 'confirm'}:
                self.select('learning.selected', 1)
                self.send('press a')
            elif phase == 'idle':
                self.send('wait 2')
            else:
                raise ProtocolError('unavailable HM teaching phase: ' + str(phase))
        else:
            raise ProtocolError('HM teaching action bound exhausted')
        if move not in self.party()[index - 1]['moves'] or self.quantity(item) != quantity:
            raise ProtocolError('actual reusable HM teaching did not complete: ' + move)
        self.send('press b')
        self.require(root='overworld')
        return index

    def route_lavender(self):
        if self.state['zone_id'] != self.zone('Route2Gate'):
            raise ProtocolError('first route packet requires the accepted Flash-aide checkpoint')
        self.leave_flash_gate()
        self.cross_digletts_cave(reverse=True)
        self.heal_here('VermilionPokecenter')
        self.travel(self.zone('Route6'))
        self.travel(self.zone('UndergroundPathRoute6'))
        self.travel(self.zone('UndergroundPathNorthSouth'))
        self.travel(self.zone('UndergroundPathRoute5'))
        self.travel(self.zone('Route5'))
        self.heal_here('CeruleanPokecenter')
        flash = self.teach('flash')
        self.travel(self.zone('CeruleanCity'))
        cut = self.teach('cut')
        self.field_cut(cut, 'CeruleanCity', (19, 28))
        self.travel(self.zone('Route9'))
        self.heal_here('RockTunnelPokecenter')
        self.travel(self.zone('Route10'))
        self.warp(self.zone('RockTunnel1F'), cj.sid('ROUTE_10', 2).replace(':objects:', ':warps:'))
        if self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != 6:
            raise ProtocolError('actual outside Rock Tunnel entry did not set darkness')
        self.checkpoint('rock-tunnel-dark-before-flash')
        self.use_field(flash, 'flash')
        if self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != 0:
            raise ProtocolError('actual Flash did not clear darkness')
        ladders = [('RockTunnel1F', 5, 'RockTunnelB1F'), ('RockTunnelB1F', 2, 'RockTunnel1F'),
                   ('RockTunnel1F', 7, 'RockTunnelB1F'), ('RockTunnelB1F', 4, 'RockTunnel1F'),
                   ('RockTunnel1F', 3, 'Route10')]
        for name, warp, target in ladders:
            self.require(zone_id=self.zone(name))
            stable = self.zone(name) + ':warps:' + str(warp)
            self.warp(self.zone(target), stable)
            if target.startswith('RockTunnel') and self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != 0:
                raise ProtocolError('Flash state was lost between connected tunnel floors')
        self.heal_here('LavenderPokecenter')
        if self.config['content_scope'] == 'optional':
            self.visit_event(cj.sid('LAVENDER_CUBONE_HOUSE', 2))
        self.travel(self.zone('LavenderTown'))
        self.completed_steps.add('rock-tunnel-flash-lavender')
        self.checkpoint('lavender-earned')

    def receipt_state(self):
        if not isinstance(getattr(self, 'boundary_payload', None), dict):
            raise ProtocolError('midgame receipt requires an actual Save/Continue boundary')
        return dict(starter=self.starter, packet=self.config['packet'], content_scope=self.config['content_scope'],
                    codec=copy.deepcopy(self.boundary_payload), completed_steps=sorted(self.completed_steps))

    def write_receipt(self):
        state = self.receipt_state()
        validate_receipt_state(state)
        packet = dict(schema=1, kind='midgame-saved', state=state,
                      **{k: self.client.identity[k] for k in ('build_id', 'session_id')})
        path = self.evidence / 'journey-receipt.json'
        atomic_json(path, packet)
        self.summary['receipt'] = dict(path=path.name, sha256=hashlib.sha256(path.read_bytes()).hexdigest())

    def continue_saved(self, prior):
        if (not isinstance(prior, dict) or prior.get('kind') != 'midgame-saved'
                or any(prior.get(k) != self.client.identity[k] for k in ('build_id', 'session_id'))):
            raise ProtocolError('missing immutable same-build midgame saved receipt')
        saved = prior['state']
        validate_receipt_state(saved)
        if any(saved[k] != self.config[k] for k in ('starter', 'packet', 'content_scope')):
            raise ProtocolError('Continue changed starter or route scope')
        self.completed_steps = set(saved['completed_steps'])
        self.dependencies()
        self.title_continue()
        self.boundary_payload = self.codec_guard('loaded')
        if self.receipt_state() != saved:
            raise ProtocolError('actual process Continue differs from complete saved codec payload')
        self.checkpoint('midgame-continued')
        self.write_receipt()

    def natural(self):
        self.start_earned()
        self.route_lavender()
        if self.config['packet'] == 'full':
            self.route_full()
        self.save()
        self.write_receipt()
        self.summary['acceptance'] = 'earned candidate saved; actual process restart pending'

    def route_full(self):
        raise ProtocolError('full 5.5 story/service route packet not yet composed')


def run(client, scenario, evidence, build_evidence=None, prior_receipt=None, capture_dir=None):
    journey = None
    try:
        journey = MidgameJourney(client, evidence, scenario['journey'], build_evidence, capture_dir)
        if scenario['journey']['name'] == 'midgame-continue':
            journey.continue_saved(prior_receipt)
        else:
            journey.natural()
    except BaseException as error:
        summary = journey.summary if journey else {'schema': 1, 'acceptance': 'unrun candidate'}
        summary.update(ok=False, error=str(error), last_snapshot=journey.state if journey else {})
        atomic_json(Path(evidence) / 'journey-summary.json', summary)
        raise
    journey.summary.update(ok=True, journey_outcome='complete', last_snapshot=journey.state)
    atomic_json(Path(evidence) / 'journey-summary.json', journey.summary)
    return journey.summary
