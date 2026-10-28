"""Earned 5.4 -> 5.5a input journeys. Root alone owns Simulator and save import.

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
    if config.get('starter') not in cj.FAMILIES or config.get('packet') not in {'lavender', '5.5a'}:
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
    starting = scenario['initial_save']
    if (not isinstance(starting, dict) or set(starting) not in (
            {'milestone', 'starter'}, {'milestone', 'starter', 'resume'})
            or starting.get('milestone') != '5.4'
            or starting.get('starter') != groups[0]['journey']['starter']):
        raise ProtocolError('midgame must descend from accepted chain/5.4/<starter>')
    if 'resume' in starting:
        reference = starting['resume']
        if (not isinstance(reference, dict) or set(reference) != {'path', 'sha256'}
                or not isinstance(reference['path'], str) or not Path(reference['path']).is_absolute()
                or not isinstance(reference['sha256'], str) or len(reference['sha256']) != 64):
            raise ProtocolError('resume requires an absolute checkpoint path and exact SHA256')


def validate_chain_record(record, spec, project):
    proof = json.loads((Path(project) / 'docs/validation/vermilion-acceptance-20261028.json').read_bytes())
    if (spec['milestone'] != '5.4' or record.get('from_milestone') != '5.4'
            or record.get('starter') != spec['starter'] or proof.get('milestone_accepted') is not True
            or record.get('accepted_commit') != proof.get('accepted_main_code')
            or record.get('accepted_source_sha256') != proof.get('accepted_source_sha256')
            or not any(v.get('starter') == spec['starter'] for v in proof.get('final_build_verification', {}).get('starters', []))):
        raise ProtocolError('starting slots lack accepted final-build Vermilion ancestry')


def validate_partial_state(state):
    if not isinstance(state, dict) or set(state) != {'starter', 'packet', 'content_scope', 'codec', 'completed_steps'}:
        raise ProtocolError('malformed partial midgame Save observation')
    validate_config(dict(name='midgame-continue', **{key: state[key]
                        for key in ('starter', 'packet', 'content_scope')}))
    cj.validate_boundary_payload(state['codec'])
    steps = state['completed_steps']
    allowed = {'vermilion-return', 'cerulean-arrival', 'rock-tunnel-center',
               'rock-tunnel-flash-lavender', 'celadon-arrival', 'celadon_gym', 'hideout-scope',
               'celadon-vending-drinks', 'celadon-eevee', 'celadon-coins-prize-slot'}
    if (not isinstance(steps, list) or any(not isinstance(step, str) for step in steps)
            or steps != sorted(set(steps)) or not set(steps) <= allowed):
        raise ProtocolError('invalid partial route steps')


def validate_receipt_state(state):
    if not isinstance(state, dict) or set(state) != {'starter', 'packet', 'content_scope', 'codec', 'completed_steps'}:
        raise ProtocolError('malformed midgame saved receipt')
    validate_config(dict(name='midgame-continue', **{k: state[k] for k in ('starter', 'packet', 'content_scope')}))
    cj.validate_boundary_payload(state['codec'])
    steps = state['completed_steps']
    if not isinstance(steps, list) or any(not isinstance(s, str) for s in steps) or steps != sorted(set(steps)):
        raise ProtocolError('invalid completed input-step observations')
    required = {'rock-tunnel-flash-lavender'}
    if state['packet'] == '5.5a':
        required |= {'celadon_gym', 'hideout-scope'}
        if state['content_scope'] == 'optional':
            required |= {'celadon-vending-drinks', 'celadon-eevee', 'celadon-coins-prize-slot'}
    if not required <= set(steps):
        raise ProtocolError('incomplete route cannot publish a final saved receipt')


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
        self.summary.update(journey=copy.deepcopy(config), milestone='5.5a', acceptance='unrun candidate',
                            driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                            preparation_policy={'new_training_fights': 0, 'use_centers_and_shops': True})
        self.stage = 'cerulean'  # Existing shared source-trainer validation path.
        self.completed_steps = set()
        self.vermilion_active = True
        self.midgame_ready = False

    def frame_label(self, label):
        if label.startswith('m55a-'):
            return label
        for prefix in ('brock-', 'parcel-', 'cerulean-', 'vermilion-'):
            label = label.replace(prefix, '')
        if getattr(self, 'saving', False):
            label = 'save-' + str(self.save_number) + '-' + label
        return 'm55a-' + self.state.get('zone_id', 'title').replace('pokered:', '').lower() + '-' + label

    def send(self, *commands):
        if commands and commands[0] == 'press b' and self.state.get('root') == 'overworld':
            # Let the existing A/B gesture finish before opening a field menu.
            commands = ('wait 3', *commands)
        return super().send(*commands)

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
        for package in ('sourceSlice', 'vermilionPreparation', 'midgameEast'):
            self.source_trainers.update(source.read('data/' + package + '/trainers.json')['trainers'])
            self.ordinary_events.update(source.read('data/' + package + '/events.json')['events'])
        owners = self.observe('midgame-owners')
        if owners.get('valid') is not True or type(owners.get('version')) is not int:
            raise ProtocolError('root midgame owner observation unavailable')
        self.export = {'session_codec': owners['version'], 'shops': owners['shops']}
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
        resume = provenance.get('resume')
        if resume:
            saved = resume['state']
            if any(saved[k] != self.config[k] for k in ('starter', 'packet', 'content_scope')):
                raise ProtocolError('partial checkpoint changed starter or route scope')
            self.boundary_payload = self.codec_guard('loaded')
            if self.boundary_payload != saved['codec']:
                raise ProtocolError('partial Continue differs from its actual saved codec payload')
            self.completed_steps = set(saved['completed_steps'])
            self.summary['resumed_steps'] = sorted(self.completed_steps)
        self.summary['starting_save'] = provenance
        self.checkpoint('earned-flash-continue')

    def require_event(self, stable):
        if self.registered_events.get(stable) is not True:
            raise ProtocolError('unavailable gameplay event; root must integrate owner: ' + stable)

    def visit_event(self, event, stop_phase=None):
        self.require_event(event)
        return super().visit_event(event, stop_phase)

    def use_field(self, index, move):
        if move in {'surf', 'strength', 'fly'} and not self.observe('midgame-state').get('fieldRuntime', {}).get('installed'):
            raise ProtocolError('field travel controller is not integrated: ' + move)
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
        if move in {'surf', 'strength', 'fly'}:
            self.require(root='fieldTravel')
            self.drain()
            result = self.observe('midgame-state')['fieldRuntime'].get('last')
            if not isinstance(result, dict) or result.get('key') != move or result.get('kind') != 'complete':
                raise ProtocolError('actual field travel did not complete: ' + move)
            return
        self.require(root='fieldMove', **{'field_move.phase': 'confirm'})
        choices = sequence(lookup(self.state, 'field_move.menu.options'), 'field confirmation')
        if choices.count('YES') != 1:
            raise ProtocolError('field confirmation lacks actual YES')
        self.select('field_move.menu.selected', choices.index('YES') + 1)
        self.send('press a')
        self.require(**{'field_move.phase': 'announce'})
        self.send('press a', 'wait 8')
        self.drain()
        self.require(root='overworld', **{'field_move.lastResult.ok': True})

    def retrieve_hm_user(self, move, compatible):
        owner = self.collection_owner()
        boxes = sequence(owner['storage']['boxes'], 'PC boxes')
        stored = next(((box, index, mon) for box, rows in enumerate(boxes, 1)
                       for index, mon in enumerate(sequence(rows, 'PC box'), 1)
                       if mon['species'] in compatible), None)
        if stored is None:
            return False
        box, index, expected = stored
        if not self.state['zone_id'].endswith('POKECENTER'):
            self.heal_here('CeruleanPokecenter' if move == 'flash' else 'FuchsiaPokecenter')
        self.navigate((13, 4))
        self.face('up')
        self.send('wait 1', 'press a', 'wait 2')
        self.require(root='pc', **{'pc.phase': 'top'})
        self.select('pc.menu.selected', 1)
        self.send('press a')
        if len(self.party()) == 6:
            deposit = next(i for i in range(len(self.party()), 0, -1)
                           if self.party()[i - 1]['species'] not in cj.FAMILIES[self.starter]
                           and not any(key in HMS for key in self.party()[i - 1]['moves']))
            self.select('pc.menu.selected', 2)
            self.send('press a')
            self.select('pc.selected', deposit)
            self.send('press a', 'press a')
            self.require(**{'pc.phase': 'result', 'pc.result.ok': True})
            self.send('press b', 'press b')
        if lookup(self.state, 'pc.box') != box:
            self.select('pc.menu.selected', 4)
            self.send('press a')
            self.select('pc.menu.selected', 1)
            self.send('press a')
            self.require(**{'pc.phase': 'boxes'})
            self.select('pc.box', box)
            self.send('press a')
            self.require(**{'pc.phase': 'result', 'pc.result.ok': True})
            self.send('press b')
        self.select('pc.menu.selected', 1)
        self.send('press a')
        self.require(**{'pc.phase': 'list', 'pc.operation': 'withdraw'})
        self.select('pc.selected', index)
        self.send('press a', 'press a')
        self.require(**{'pc.phase': 'result', 'pc.result.ok': True})
        actual = self.collection_owner()['party']['members'][-1]
        if actual != expected:
            raise ProtocolError('PC withdrawal changed the earned Pokemon')
        self.send('press b', 'press b', 'press b', 'press b')
        self.require(root='overworld')
        self.summary['party_changes'].append({'kind': 'withdraw-for-' + move, 'species': expected['species']})
        return True

    def teach(self, move):
        known = next((i for i, mon in enumerate(self.party(), 1) if move in mon['moves']), None)
        if known:
            return known
        owners = self.observe('midgame-owners')
        compatible = owners.get('hm_compatibility', {}).get(HMS[move])
        if not isinstance(compatible, list):
            raise ProtocolError('actual HM compatibility observation unavailable: ' + move)
        index = next((i for i, mon in enumerate(self.party(), 1) if mon['species'] in compatible), None)
        if index is None and self.retrieve_hm_user(move, set(compatible)):
            index = next(i for i, mon in enumerate(self.party(), 1) if mon['species'] in compatible)
        if index is None:
            if move == 'flash':
                self.summary['flash'] = {'used': False, 'reason': 'no compatible earned Pokemon; fixed route stays dark'}
                return None
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
        if 'rock-tunnel-flash-lavender' in self.completed_steps:
            return
        if 'vermilion-return' not in self.completed_steps:
            if self.state['zone_id'] != self.zone('Route2Gate'):
                raise ProtocolError('first route packet requires the accepted Flash-aide checkpoint')
            self.leave_flash_gate()
            self.cross_digletts_cave(reverse=True)
            self.heal_here('VermilionPokecenter')
            self.complete_at_center('vermilion-return')
        if 'cerulean-arrival' not in self.completed_steps:
            for name in ('Route6', 'UndergroundPathRoute6', 'UndergroundPathNorthSouth',
                         'UndergroundPathRoute5', 'Route5'):
                self.travel(self.zone(name))
            self.heal_here('CeruleanPokecenter')
            self.complete_at_center('cerulean-arrival')
        if 'rock-tunnel-center' not in self.completed_steps:
            self.travel(self.zone('CeruleanCity'))
            cut = self.teach('cut')
            self.field_cut(cut, 'CeruleanCity', (19, 28))
            self.travel(self.zone('Route9'))
            self.field_cut(cut, 'Route9', (5, 8))
            self.source_waypoint(59, 9)
            self.cross('right', self.zone('Route10'), (0, 9))
            self.heal_here('RockTunnelPokecenter')
            self.complete_at_center('rock-tunnel-center')
        flash = self.teach('flash')
        self.travel(self.zone('Route10'))
        self.warp(self.zone('RockTunnel1F'), cj.sid('ROUTE_10', 2).replace(':objects:', ':warps:'))
        if self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != 6:
            raise ProtocolError('actual outside Rock Tunnel entry did not set darkness')
        self.checkpoint('rock-tunnel-dark-before-flash')
        if flash is not None:
            self.use_field(flash, 'flash')
            self.summary['flash'] = {'used': True}
        expected_darkness = 0 if flash is not None else 6
        if self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != expected_darkness:
            raise ProtocolError('Rock Tunnel darkness differs from actual Flash use')
        ladders = [('RockTunnel1F', 5, 'RockTunnelB1F'), ('RockTunnelB1F', 2, 'RockTunnel1F'),
                   ('RockTunnel1F', 7, 'RockTunnelB1F'), ('RockTunnelB1F', 4, 'RockTunnel1F'),
                   ('RockTunnel1F', 3, 'Route10')]
        for name, warp, target in ladders:
            self.require(zone_id=self.zone(name))
            stable = self.zone(name) + ':warps:' + str(warp)
            self.warp(self.zone(target), stable)
            if target.startswith('RockTunnel') and self.observe('midgame-state')['fieldWorld']['mapPalOffset'] != expected_darkness:
                raise ProtocolError('Flash state was lost between connected tunnel floors')
        self.heal_here('LavenderPokecenter')
        if self.config['content_scope'] == 'optional':
            self.visit_event(cj.sid('LAVENDER_CUBONE_HOUSE', 2))
        self.heal_here('LavenderPokecenter')
        self.complete_at_center('rock-tunnel-flash-lavender')
        self.checkpoint('lavender-earned')

    def complete_at_center(self, step):
        self.completed_steps.add(step)
        self.save()

    def save(self):
        # A final dialogue press can expose the overworld with its field
        # gesture still consumed. Release it before the inherited Save B tap.
        self.send('wait 1')
        super().save()
        files = []
        for name in ('adventure.a.json', 'adventure.b.json'):
            path = self.client.data / name
            if path.is_symlink() or not path.is_file():
                raise ProtocolError('partial checkpoint requires two real save slots')
            files.append(dict(file=name, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        starting = json.loads((self.build_evidence / 'starting-save.json').read_bytes())
        # This is a partial progress marker, never a completed route receipt.
        atomic_json(self.evidence / 'partial-save.json', dict(schema=1, kind='midgame-partial',
            state=self.receipt_state(), files=files, starting_save=starting,
            **{k: self.client.identity[k] for k in ('build_id', 'session_id')}))

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
        if self.config['packet'] == '5.5a':
            self.route_a()
        self.save()
        self.write_receipt()
        self.summary['acceptance'] = 'earned candidate saved; actual process restart pending'

    def advance_event(self, stop_phase=None):
        if self.state.get('root') == 'fieldGear':
            self.send('wait 3', 'press a')
            return True
        if self.state.get('root') == 'fieldTravel':
            return self.advance_travel()
        if self.state.get('root') == 'event' and lookup(self.state, 'event.phase') == 'celadon-slots':
            if not getattr(self, 'slot_attempt', None):
                raise ProtocolError('unplanned slot spin')
            self.slot_attempt['spinning_observed'] = True
            # Fixed human input cadence, independent of symbols or possible payout.
            self.send('wait 8', 'press a', 'wait 4')
            self.capture_slot_result()
            return True
        phase = lookup(self.state, 'event.phase')
        if self.state.get('root') == 'event' and lookup(self.state, 'event.menu.active') is True:
            options = sequence(lookup(self.state, 'event.menu.options'), 'midgame event options')
            if phase == 'celadon-menu':
                choices = getattr(self, 'celadon_choices', None)
                if not choices:
                    raise ProtocolError('unplanned Celadon menu: ' + str(options))
                choice = choices.pop(0)
                if options.count(choice) != 1:
                    raise ProtocolError('fixed Celadon choice absent: ' + choice + ': ' + str(options))
                self.select('event.menu.selected', options.index(choice) + 1)
                self.send('press a')
                self.capture_slot_result()
                return True
            if phase in {'hideout-floor', 'silph-floor'}:
                choice = getattr(self, 'floor_choice', None)
                if choice is None or options.count(choice) != 1:
                    raise ProtocolError('unplanned actual elevator menu: ' + str(options))
                self.select('event.menu.selected', options.index(choice) + 1)
                self.send('press a')
                return True
            event = lookup(self.state, 'event.id')
            choice = getattr(self, 'event_choices', {}).get(event)
            if choice is not None:
                if options.count(choice) != 1:
                    raise ProtocolError('source service menu differs: ' + str(event) + ':' + str(options))
                self.select('event.menu.selected', options.index(choice) + 1)
                self.send('press a')
                return True
        return super().advance_event(stop_phase)

    def background(self, stable):
        self.require_event(stable)
        event = next((e for e in self.model().events['background_events'] if e['id'] == stable), None)
        if event is None:
            raise ProtocolError('source background interaction missing: ' + stable)
        approaches = self.model().approaches((event['x'], event['y']))
        self.navigate(set(approaches))
        self.face(approaches[self.position()])
        self.send('press a', 'wait 2')
        self.drain()
        self.refresh_world()

    def source_waypoint(self, x, y):
        self.navigate((x + self.model().padding, y))

    def scene_data(self, relative):
        try:
            return cj.StagedSource(self.build_evidence).read(relative)['scenes']
        except (ProtocolError, KeyError) as error:
            raise ProtocolError('unavailable integrated source story package: ' + relative) from error

    def fixed_hideout(self, index, destination):
        path = SCENARIOS / 'hideout-fixed-routes.json'
        data = json.loads(path.read_bytes())
        route = data['routes'][index]
        self.require(zone_id=self.zone(route['map']))
        if self.position() != tuple(route['start']):
            raise ProtocolError('fixed Hideout entry differs: ' + str(self.position()))
        self.summary.setdefault('fixed_scripts', []).append(dict(script=path.name,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(), route=index))
        for number, step in enumerate(route['steps']):
            if self.position() != tuple(step['from_cell']):
                raise ProtocolError('fixed Hideout script lost source approach: ' + str(step))
            self.send('press ' + step['direction'], 'wait 10')
            self.drain()
            if number == len(route['steps']) - 1 and self.state['zone_id'] == self.zone(destination):
                break
            expected = tuple(step.get('stop_cell', step['to_cell']))
            if self.position() != expected:
                raise ProtocolError('actual source walk/spinner did not reach fixed stop: ' + str(expected))
        self.require(zone_id=self.zone(destination))
        self.refresh_world()

    def pickup(self, stable, item, flag=None):
        completed = flag or 'PICKUP:' + stable
        if self.flag(completed):
            if flag and self.quantity(item) < 1:
                raise ProtocolError('completed earned reward is absent: ' + item)
            return
        before = self.quantity(item)
        self.visit_event(stable)
        if self.quantity(item) != before + 1 or flag and not self.flag(flag):
            raise ProtocolError('actual item transaction unavailable/incomplete: ' + stable)
        self.summary['rewards'].append(dict(id=stable, item=item, observed_quantity=self.quantity(item), flag=flag))

    def event_offer(self, stable, choice='YES'):
        self.event_choices = {stable: choice}
        try:
            self.visit_event(stable)
        finally:
            self.event_choices = {}

    def leave_party_slot(self):
        if len(self.party()) < 6:
            return
        self.heal_here('PewterPokecenter')
        self.navigate((13, 4))
        self.face('up')
        before = self.collection_owner()
        members = before['party']['members']
        fly_species = set(self.observe('midgame-owners')['hm_compatibility']['hm02'])
        index = next((i for i in range(len(members), 0, -1)
                      if members[i - 1]['species'] not in cj.FAMILIES[self.starter]
                      and members[i - 1]['species'] not in fly_species
                      and not any(move in HMS for move in members[i - 1]['moves'])), None)
        if index is None:
            raise ProtocolError('no non-starter without learned HMs can be stored for Lapras')
        self.send('wait 1', 'press a', 'wait 2')
        self.require(root='pc', **{'pc.phase': 'top'})
        self.select('pc.menu.selected', 1)
        self.send('press a')
        self.require(**{'pc.phase': 'storage'})
        self.select('pc.menu.selected', 2)
        self.send('press a')
        self.require(**{'pc.phase': 'list', 'pc.operation': 'deposit'})
        self.select('pc.selected', index)
        self.send('press a')
        self.require(**{'pc.phase': 'actions'})
        self.select('pc.menu.selected', 1)
        self.send('press a')
        self.require(**{'pc.phase': 'result', 'pc.result.ok': True})
        after = self.collection_owner()
        if after['party']['members'] != members[:index - 1] + members[index:]:
            raise ProtocolError('real PC deposit changed the wrong party member')
        self.send('press b', 'press b', 'press b', 'press b')
        self.require(root='overworld')
        self.summary['party_changes'].append(dict(kind='deposit-for-earned-lapras', species=members[index - 1]['species']))

    def restock(self, mart):
        clerk = self.zone(mart) + ':objects:1'
        shop = self.vermilion['shops'].get(clerk)
        if not shop:
            raise ProtocolError('actual shop owner unavailable: ' + mart)
        for item, target in [('antidote', 2), ('superPotion', 4)]:
            if item not in shop['stock']:
                continue
            price = shop['prices'][item]
            count = min(max(0, target - self.quantity(item)), max(0, self.inventory()['money'] - 1200) // price)
            if count:
                self.travel(self.zone(mart))
                self.buy_item(clerk, item, count, price)

    def leader(self, constant, badge, tm, center, mart):
        stable = cj.sid(constant, 1)
        self.require_event(stable)
        self.heal_here(center)
        self.restock(mart)
        self.fight(stable)
        if not self.flag(badge) or not self.flag('EVENT_GOT_' + tm.upper()) or self.quantity(tm) < 1:
            raise ProtocolError('actual leader/badge/TM reward missing: ' + stable)
        self.completed_steps.add(constant.lower())
        self.checkpoint(constant.lower() + '-badge-and-' + tm)
        self.travel(self.zone(center))
        self.heal_here(center)
        self.save()

    def route_celadon(self):
        if 'celadon-arrival' not in self.completed_steps:
            for name in ('Route8', 'UndergroundPathRoute8', 'UndergroundPathWestEast',
                         'UndergroundPathRoute7', 'Route7'):
                self.travel(self.zone(name))
            self.heal_here('CeladonPokecenter')
            self.complete_at_center('celadon-arrival')
        if 'celadon_gym' not in self.completed_steps:
            self.ensure_room('CeladonMart2F')
            self.leader('CELADON_GYM', 'BADGE_RAINBOW', 'tm21', 'CeladonPokecenter', 'CeladonMart2F')

    def route_a(self):
        self.route_celadon()
        if 'hideout-scope' not in self.completed_steps:
            self.route_hideout()
        if self.config['content_scope'] == 'optional':
            self.celadon_services_a()
        if (not self.flag('BADGE_RAINBOW') or not self.flag('EVENT_GOT_TM21')
                or self.quantity('silphScope') != 1):
            raise ProtocolError('5.5a requires actual Erika rewards and Silph Scope')
        self.heal_here('CeladonPokecenter')
        self.require(zone_id=self.zone('CeladonPokecenter'))

    def route_hideout(self):
        self.scene_data('data/rocketHideoutStory/scenes.json')
        guard = cj.sid('GAME_CORNER', 11)
        self.require_event(guard)
        self.travel(self.zone('GameCorner'))
        self.source_waypoint(9, 6)
        self.fight(guard)
        if not self.flag('ROCKET_HIDEOUT_SCENE_V1_GUARD_LEFT'):
            self.visit_event(guard)
        self.background('pokered:GAME_CORNER:background_events:1')
        self.warp(self.zone('RocketHideoutB1F'), 'pokered:GAME_CORNER:warps:3')
        self.warp(self.zone('RocketHideoutB2F'), 'pokered:ROCKET_HIDEOUT_B1F:warps:1')
        self.fixed_hideout(0, 'RocketHideoutB3F')
        self.fixed_hideout(1, 'RocketHideoutB4F')
        key_rocket = cj.sid('ROCKET_HIDEOUT_B4F', 4)
        self.fight(key_rocket)
        self.visit_event(key_rocket)  # Source requires the later talk, not just victory.
        if not self.flag('EVENT_ROCKET_DROPPED_LIFT_KEY'):
            raise ProtocolError('actual defeated Rocket did not drop Lift Key')
        self.pickup(cj.sid('ROCKET_HIDEOUT_B4F', 9), 'liftKey')
        self.warp(self.zone('RocketHideoutB3F'), 'pokered:ROCKET_HIDEOUT_B4F:warps:1')
        self.fixed_hideout(2, 'RocketHideoutB2F')
        self.fixed_hideout(3, 'RocketHideoutElevator')
        self.floor_choice = 'B4F'
        self.background('pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1')
        self.floor_choice = None
        self.navigate((2 + self.model().padding, 1), transition=self.zone('RocketHideoutB4F'))
        self.require(zone_id=self.zone('RocketHideoutB4F'))
        self.refresh_world()
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 2))
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 3))
        # Source applies the guard door on map load. Re-enter the selected cabin.
        self.warp(self.zone('RocketHideoutElevator'))
        self.navigate((2 + self.model().padding, 1), transition=self.zone('RocketHideoutB4F'))
        self.refresh_world()
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 1))
        self.pickup(cj.sid('ROCKET_HIDEOUT_B4F', 8), 'silphScope')
        self.completed_steps.add('hideout-scope')
        self.warp(self.zone('RocketHideoutElevator'))
        self.floor_choice = 'B1F'
        self.background('pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1')
        self.floor_choice = None
        self.navigate((2 + self.model().padding, 1), transition=self.zone('RocketHideoutB1F'))
        self.travel(self.zone('GameCorner'))
        self.heal_here('CeladonPokecenter')
        self.save()

    def flee(self):
        expected = getattr(self, 'scripted_wild', None)
        enemy = lookup(self.state, 'battle.enemy')
        if expected and isinstance(enemy, dict) and enemy.get('species') == expected['species'] and enemy.get('level') == expected['level']:
            return self.battle('source-' + expected['species'], expected='win')
        return super().flee()

    def route_tower(self):
        scenes = self.scene_data('data/towerStory/scenes.json')
        self.heal_here('LavenderPokecenter')
        self.restock('LavenderMart')
        self.travel(self.zone('PokemonTower1F'))
        for floor in range(2, 7):
            self.warp(self.zone('PokemonTower' + str(floor) + 'F'))
            if floor == 2:
                self.require_event(cj.sid('POKEMON_TOWER_2F', 1))
                self.fight(cj.sid('POKEMON_TOWER_2F', 1))
        self.scripted_wild = dict(species=scenes['ghost']['species'], level=scenes['ghost']['level'])
        self.source_waypoint(10, 17)
        self.face('up')
        self.send('press up', 'wait 10')
        self.drain()
        self.scripted_wild = None
        if not self.flag('EVENT_BEAT_GHOST_MAROWAK'):
            raise ProtocolError('unavailable/unconfirmed actual Scope ghost victory')
        self.warp(self.zone('PokemonTower7F'))
        for index, point in [(1, (9, 12)), (2, (12, 10)), (3, (9, 8))]:
            self.source_waypoint(*point)
            self.fight(cj.sid('POKEMON_TOWER_7F', index))
            if not self.flag('POKEMON_TOWER_ROCKET_V1_LEFT_' + str(index)):
                raise ProtocolError('actual Tower Rocket departure incomplete')
        self.visit_event(cj.sid('POKEMON_TOWER_7F', 4))
        self.require(zone_id=self.zone('MrFujisHouse'))
        self.pickup(cj.sid('MR_FUJIS_HOUSE', 5), 'pokeFlute', 'EVENT_GOT_POKE_FLUTE')
        if not self.flag('EVENT_RESCUED_MR_FUJI'):
            raise ProtocolError('actual Fuji rescue missing')
        self.completed_steps.add('tower-fuji-flute')
        self.heal_here('LavenderPokecenter')
        self.save()

    def fixed_leg(self, filename, label):
        path = SCENARIOS / filename
        route = json.loads(path.read_bytes())['routes'][label]
        self.require(zone_id=self.zone(route['map']))
        padding = self.model().padding
        if self.position() != (route['start'][0] + padding, route['start'][1]):
            raise ProtocolError('fixed script entry differs: ' + label + ':' + str(self.position()))
        self.summary.setdefault('fixed_scripts', []).append(dict(script=filename, route=label,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        for number, step in enumerate(route['steps']):
            self.send('press ' + step['direction'], 'wait ' + ('18' if step['kind'] == 'ledge' else '10'))
            self.drain()
            target = route.get('destination')
            if target and number == len(route['steps']) - 1:
                self.require(zone_id=self.zone(target))
            elif self.position() != (step['to'][0] + padding, step['to'][1]):
                raise ProtocolError('fixed source script step failed: ' + label + ':' + str(step))
        self.refresh_world()

    def fixed_warp(self, index, approach=None):
        event = next((e for e in self.model().events['warps'] if e['source_index'] == index), None)
        if event is None:
            raise ProtocolError('fixed source warp is absent: ' + str(index))
        target, position = self.warp_projection(event)
        point = (event['x'], event['y'])
        if approach is None:
            paths = []
            for p, facing in self.model().approaches(point).items():
                try:
                    route = self.model().path(self.position(), {p}, self.occupied())
                    paths.append((len(route), p, facing))
                except ProtocolError:
                    pass
            if not paths:
                raise ProtocolError('fixed pad has no source-legal approach')
            _, approach, direction = min(paths)
        else:
            approach = (approach[0] + self.model().padding, approach[1])
            direction = next((d for d, (x, y) in DIRECTIONS.items()
                              if (approach[0] + x, approach[1] + y) == point), None)
        if direction is None:
            raise ProtocolError('fixed warp approach is not adjacent')
        self.navigate(approach)
        self.send('press ' + direction, 'wait 15')
        self.drain()
        self.require(zone_id=target, **{'player.x': position[0], 'player.y': position[1]})
        self.refresh_world()

    def ride_silph(self, floor):
        if self.state['zone_id'] != self.zone('SilphCoElevator'):
            # The cabin's raw UNUSED_MAP destination is resolved by the source
            # scene. Use real ingress input, never a debug warp or host rewrite.
            event = next(e for e in self.model().events['warps']
                         if e['destination'].get('map') == 'SILPH_CO_ELEVATOR')
            self.navigate((event['x'], event['y']), transition=self.zone('SilphCoElevator'))
            self.require(zone_id=self.zone('SilphCoElevator'))
        self.floor_choice = str(floor) + 'F'
        self.background('pokered:SILPH_CO_ELEVATOR:background_events:1')
        self.floor_choice = None
        self.refresh_world()
        self.navigate((1 + self.model().padding, 3), transition=self.zone('SilphCo' + str(floor) + 'F'))
        if self.state['zone_id'] == self.zone('SilphCoElevator'):
            self.send('press down', 'wait 15')
            self.drain()
        self.require(zone_id=self.zone('SilphCo' + str(floor) + 'F'))
        self.refresh_world()

    def key_door(self, point, facing, flag):
        if self.quantity('cardKey') < 1:
            raise ProtocolError('real Card Key is missing')
        self.source_waypoint(*point)
        self.face(facing)
        self.send('press a', 'wait 2')
        self.drain()
        if not self.flag(flag):
            raise ProtocolError('source Card Key door did not commit: ' + flag)
        self.refresh_world()

    def route_saffron(self):
        self.heal_here('CeladonPokecenter')
        self.travel(self.zone('CeladonMart1F'))
        for name in ('CeladonMart2F', 'CeladonMart3F', 'CeladonMart4F', 'CeladonMart5F', 'CeladonMartRoof'):
            self.warp(self.zone(name))
        vending = 'pokered:CELADON_MART_ROOF:background_events:1'
        before_money, before_water = self.inventory()['money'], self.quantity('freshWater')
        self.event_choices = {vending: 'FRESH WATER'}
        try:
            self.background(vending)
        finally:
            self.event_choices = {}
        if self.quantity('freshWater') != before_water + 1 or self.inventory()['money'] != before_money - 200:
            raise ProtocolError('actual source vending purchase unavailable/incomplete')
        self.travel(self.zone('Route7Gate'))
        flag = 'pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK'
        if not self.flag(flag):
            self.visit_event(cj.sid('ROUTE_7_GATE', 1))
        if not self.flag(flag):
            raise ProtocolError('actual guard drink transaction did not open Saffron')
        self.heal_here('SaffronPokecenter')
        self.ensure_room('SaffronMart')
        self.scene_data('data/silphStory/scenes.json')
        self.travel(self.zone('SilphCo1F'))
        self.ride_silph(5)
        self.fixed_leg('silph-fixed-routes.json', 'card-key-approach')
        self.fixed_warp(5, (9, 14))
        self.require(zone_id=self.zone('SilphCo9F'))
        self.warp(self.zone('SilphCo5F'), 'pokered:SILPH_CO_9F:warps:5')
        self.fixed_leg('silph-fixed-routes.json', 'card-key-corridor')
        self.pickup(cj.sid('SILPH_CO_5F', 8), 'cardKey')
        self.fixed_leg('silph-fixed-routes.json', 'card-key-return')
        self.fixed_warp(5, (9, 16))
        self.warp(self.zone('SilphCo5F'), 'pokered:SILPH_CO_9F:warps:5')
        self.fixed_leg('silph-fixed-routes.json', 'floor5-return')
        self.ride_silph(3)
        self.fixed_leg('silph-fixed-routes.json', 'floor3-door')
        self.key_door((18, 8), 'left', 'EVENT_SILPH_CO_3_UNLOCKED_DOOR2')
        self.fixed_leg('silph-fixed-routes.json', 'floor3-pad')
        self.fixed_warp(9, (11, 10))
        for point in ((4, 3), (4, 2), (3, 2)):
            self.source_waypoint(*point)
        if not self.defeated(cj.sid('SILPH_CO_7F', 9)) or not self.flag('SILPH_STORY_V1_RIVAL_LEFT'):
            raise ProtocolError('actual Silph rival battle/departure did not complete')
        self.event_offer(cj.sid('SILPH_CO_7F', 1))
        if not self.flag('BIT_GOT_LAPRAS') or not any(m['species'] == 'lapras' for m in self.party()):
            raise ProtocolError('actual Lapras gift did not enter the reserved party slot')
        self.fixed_warp(4, (5, 6))
        self.fixed_leg('silph-fixed-routes.json', 'giovanni-trigger')
        if not self.defeated(cj.sid('SILPH_CO_11F', 3)) or not self.flag('EVENT_BEAT_SILPH_CO_GIOVANNI'):
            raise ProtocolError('actual Silph Giovanni victory did not commit')
        self.key_door((6, 12), 'right', 'EVENT_SILPH_CO_11_UNLOCKED_DOOR')
        self.pickup(cj.sid('SILPH_CO_11F', 1), 'masterBall', 'EVENT_GOT_MASTER_BALL')
        self.completed_steps.add('silph-rival-lapras-giovanni-president')
        self.heal_here('SaffronPokecenter')
        self.restock('SaffronMart')
        self.travel(self.zone('SaffronGym'))
        route = json.loads((SCENARIOS / 'silph-fixed-routes.json').read_bytes())
        for index in route['saffron_gym_in']:
            self.fixed_warp(index)
        self.fight(cj.sid('SAFFRON_GYM', 1))
        if not self.flag('BADGE_MARSH') or not self.flag('EVENT_GOT_TM46') or self.quantity('tm46') < 1:
            raise ProtocolError('actual Sabrina reward missing')
        for index in route['saffron_gym_out']:
            self.fixed_warp(index)
        self.warp(self.zone('SaffronCity'))
        self.completed_steps.add('saffron_gym')
        self.heal_here('SaffronPokecenter')
        if self.quantity('escapeRope') == 0:
            clerk = cj.sid('SAFFRON_MART', 1)
            self.travel(self.zone('SaffronMart'))
            self.buy_item(clerk, 'escapeRope', 1, self.vermilion['shops'][clerk]['prices']['escapeRope'])
        self.save()

    def use_item(self, item):
        if self.quantity(item) < 1:
            raise ProtocolError('earned Bag item unavailable: ' + item)
        self.send('press b')
        self.pause_option('ITEM')
        self.send('press a')
        self.require(root='bag', **{'bag.phase': 'list'})
        slot = next(i for i, s in enumerate(self.inventory()['slots'], 1) if s['id'] == item)
        self.select('bag.selected', slot)
        self.send('press a', 'press a')
        if item == 'escapeRope':
            self.require(**{'bag.phase': 'field-confirm'})
            self.select('bag.menu.selected', 2)
            self.send('press a')
        self.drain()
        if self.state.get('root') != 'overworld':
            raise ProtocolError('actual field-item owner unavailable/incomplete: ' + item)

    def wake_snorlax(self, constant, index, point):
        self.travel(self.zone('Route12' if constant == 'ROUTE_12' else 'Route16'))
        self.source_waypoint(*point)
        self.require_event(cj.sid(constant, index))
        self.scripted_wild = dict(species='snorlax', level=30)
        self.use_item('pokeFlute')
        self.scripted_wild = None
        if not self.flag('EVENT_BEAT_' + constant.replace('_', '') + '_SNORLAX'):
            raise ProtocolError('actual source Snorlax battle did not remove blocker')
        self.refresh_world()

    def route_fuchsia(self):
        self.heal_here('LavenderPokecenter')
        self.wake_snorlax('ROUTE_12', 1, (10, 61))
        for name in ('Route13', 'Route14', 'Route15'):
            self.travel(self.zone(name))
        self.heal_here('FuchsiaPokecenter')
        self.leader('FUCHSIA_GYM', 'BADGE_SOUL', 'tm06', 'FuchsiaPokecenter', 'FuchsiaMart')
        gate = cj.sid('SAFARI_ZONE_GATE', 1)
        self.require_event(gate)
        self.event_choices = {gate: 'YES'}
        try:
            self.travel(self.zone('SafariZoneGate'))
            if not self.flag('EVENT_IN_SAFARI_ZONE'):
                self.visit_event(gate)
        finally:
            self.event_choices = {}
        if not self.flag('EVENT_IN_SAFARI_ZONE'):
            raise ProtocolError('actual Safari admission/balls/steps owner unavailable')
        self.safari_active = True
        self.warp(self.zone('SafariZoneCenter'))
        for label in ('center-east', 'east-north', 'north-west', 'teeth'):
            self.fixed_leg('safari-fixed-routes.json', label)
        self.pickup(cj.sid('SAFARI_ZONE_WEST', 4), 'goldTeeth')
        self.fixed_leg('safari-fixed-routes.json', 'secret-house')
        self.pickup(cj.sid('SAFARI_ZONE_SECRET_HOUSE', 1), 'hm03', 'EVENT_GOT_HM03')
        self.warp(self.zone('SafariZoneWest'))
        before_rope = self.quantity('escapeRope')
        self.use_item('escapeRope')
        if self.quantity('escapeRope') != before_rope - 1 or self.flag('EVENT_IN_SAFARI_ZONE'):
            raise ProtocolError('actual source Forest Escape Rope did not exit Safari atomically')
        self.safari_active = False
        self.heal_here('FuchsiaPokecenter')
        self.event_offer(cj.sid('WARDENS_HOUSE', 1))
        if not self.flag('EVENT_GOT_HM04') or self.quantity('hm04') < 1 or self.quantity('goldTeeth') != 0:
            raise ProtocolError('actual Gold Teeth/Strength transaction unavailable/incomplete')
        strength = self.teach('strength')
        self.use_field(strength, 'strength')
        self.source_waypoint(7, 4)
        self.face('right')
        self.send('press right', 'wait 10')
        self.drain()
        stone = next((n for n in sequence(self.state.get('npcs', []), 'npcs')
                      if n.get('source_event_id') == cj.sid('WARDENS_HOUSE', 3)), None)
        if not stone or (stone['x'], stone['y']) != (10, 4):
            raise ProtocolError('actual Warden actor did not complete the source boulder push')
        self.send('press right', 'wait 10')
        self.drain()
        self.require(**{'player.x': 9, 'player.y': 4})
        self.pickup(cj.sid('WARDENS_HOUSE', 2), 'rareCandy')
        self.heal_here('FuchsiaPokecenter')
        surf = self.teach('surf')
        self.travel(self.zone('FuchsiaCity'))
        self.source_waypoint(28, 20)
        self.face('right')
        self.use_field(surf, 'surf')
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'surfing':
            raise ProtocolError('actual Fuchsia pond Surf did not enter water')
        self.send('press left', 'wait 10')
        self.drain()
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'walking':
            raise ProtocolError('actual Surf landing did not return to walking')
        self.completed_steps.add('safari-hm03-gold-teeth-hm04-strength-surf')
        self.save()

    def advance_travel(self):
        observed = self.observe('midgame-state')
        runtime = observed.get('fieldRuntime', {})
        if runtime.get('installed') is not True:
            raise ProtocolError('FieldTravel runtime observation unavailable')
        phase = runtime['phase']
        if phase == 'destination':
            target = getattr(self, 'fly_target', None)
            if not target or target not in observed['fieldTravel']['visited']:
                raise ProtocolError('Fly requires a genuinely visited selected destination')
            for _ in range(12):
                if runtime['selected'] == target:
                    self.send('press a')
                    return True
                self.send('press down')
                runtime = self.observe('midgame-state')['fieldRuntime']
            raise ProtocolError('visited Fly destination missing from actual picker')
        if phase == 'confirm':
            menu = observed.get('fieldUI', {}).get('menu', {})
            if menu.get('options') != ['NO', 'YES']:
                raise ProtocolError('actual field travel confirmation differs')
            if menu['selected'] != 2:
                self.send('press down')
            self.send('press a')
        elif phase == 'announce':
            self.send('press a')
        elif phase in {'moving', 'push', 'fade'}:
            self.send('wait 3')
        elif phase == 'result':
            raise ProtocolError('actual field travel failed: ' + str(runtime.get('last')))
        else:
            raise ProtocolError('unavailable field travel phase: ' + str(phase))
        return True

    def route_fly(self, city):
        index = self.teach('fly')
        self.fly_target = self.zone(city)
        try:
            self.use_field(index, 'fly')
        finally:
            self.fly_target = None
        self.require(zone_id=self.zone(city))
        self.completed_steps.add('visited-city-fly')

    def optional_content(self):
        self.heal_here('SaffronPokecenter')
        self.travel(self.zone('FightingDojo'))
        self.source_waypoint(4, 3)
        self.fight(cj.sid('FIGHTING_DOJO', 1))
        self.event_offer(cj.sid('FIGHTING_DOJO', 6))
        if not self.flag('EVENT_GOT_HITMONLEE') or not self.flag('EVENT_DEFEATED_FIGHTING_DOJO'):
            raise ProtocolError('actual one-of-two Dojo gift transaction incomplete')
        self.pickup(cj.sid('MR_PSYCHICS_HOUSE', 1), 'tm29', 'EVENT_GOT_TM29')
        self.event_offer(cj.sid('FUCHSIA_GOOD_ROD_HOUSE', 1))
        if self.quantity('goodRod') < 1:
            raise ProtocolError('actual Good Rod service unavailable')
        self.event_offer(cj.sid('ROUTE_12_SUPER_ROD_HOUSE', 1))
        if self.quantity('superRod') < 1:
            raise ProtocolError('actual Super Rod service unavailable')
        self.wake_snorlax('ROUTE_16', 7, (27, 10))
        if self.quantity('bikeVoucher') == 0 and self.quantity('bicycle') == 0:
            self.event_offer(cj.sid('POKEMON_FAN_CLUB', 5))
        if self.quantity('bicycle') == 0:
            self.event_offer(cj.sid('BIKE_SHOP', 1))
        if self.quantity('bicycle') != 1:
            raise ProtocolError('actual Bike Voucher exchange did not give Bicycle')
        self.travel(self.zone('Route16'))
        self.use_item('bicycle')
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'bicycle':
            raise ProtocolError('actual Bicycle field service unavailable')
        for name in ('Route17', 'Route18', 'FuchsiaCity'):
            self.travel(self.zone(name))
        self.completed_steps.add('dojo-rods-bicycle-cycling-road-second-snorlax')

    def battle(self, name, strategy='attack', expected=None):
        stable = lookup(self.state, 'event.id')
        if lookup(self.state, 'battle.trainerName') and stable in {
                cj.sid('POKEMON_TOWER_2F', 1), cj.sid('SILPH_CO_7F', 9)}:
            actual = lookup(self.state, 'event.trainer.definition')
            source = cj.StagedSource(self.build_evidence)
            classes = source.read('data/midgameSaffron/trainers.json')['rival_classes']['OPP_RIVAL2']
            candidates = classes['parties']
            counter = {'charmander': 'squirtle', 'squirtle': 'bulbasaur', 'bulbasaur': 'charmander'}[self.starter]
            if (not isinstance(actual, dict) or actual.get('id') != stable
                    or not any(row['party'] == actual.get('party') for row in candidates)
                    or not actual['party'] or actual['party'][-1]['species'] not in cj.FAMILIES[counter]
                    or actual.get('payout') != classes['base_money'] * actual['party'][-1]['level']):
                raise ProtocolError('actual rival team differs from pinned Blue counter-pick source')
            self.source_trainers[stable] = dict(self.source_trainers.get(stable, {}), **actual)
        return super().battle(name, strategy, expected)

    def sell_old_item(self, mart):
        # Actual prior campaign items only, never key items/HMs/new 5.5 rewards.
        item = next((k for k in ('nugget', 'tm34', 'tm11', 'tm28', 'tm24') if self.quantity(k) > 0), None)
        if item is None:
            raise ProtocolError('bag full with no planned sellable prior-campaign item')
        self.travel(self.zone(mart))
        stable = self.zone(mart) + ':objects:1'
        self.interact(source_id=stable)
        self.require(root='shop', **{'shop.phase': 'mode'})
        self.select('shop.menu.selected', 2)
        self.send('press a')
        visited = set()
        for _ in range(20):
            current = lookup(self.state, 'shop.item')
            if current == item:
                break
            if current in visited:
                raise ProtocolError('planned earned sale item absent from actual shop list')
            visited.add(current)
            self.send('press down')
        else:
            raise ProtocolError('shop sell browse bound exceeded')
        before, quantity = self.inventory()['money'], self.quantity(item)
        self.send('press a')
        self.require(**{'shop.phase': 'quantity'})
        for _ in range(quantity - 1):
            self.send('press up')
        self.send('press a')
        self.select('shop.menu.selected', 1)
        self.send('press a')
        self.require(**{'shop.phase': 'result', 'shop.result.ok': True})
        total = lookup(self.state, 'shop.result.total')
        if type(total) is not int or total <= 0 or self.inventory()['money'] != before + total or self.quantity(item) != 0:
            raise ProtocolError('actual sale did not conserve observed item and money')
        self.summary.setdefault('sales', []).append(dict(item=item, quantity=quantity, actual_total=total))
        self.send('press a', 'press b', 'press b')
        self.drain()

    def ensure_room(self, mart):
        # Make room before entering long dungeons, through genuine retail input.
        while len(self.inventory()['slots']) > 15:
            self.sell_old_item(mart)

    def mansion_step_warp(self, index, destination):
        # Fixed source backstairs. These preserve root's original forced-down
        # arrival even when its normal collision is solid; no tile is changed.
        event = next(e for e in self.model().events['warps'] if e['source_index'] == index)
        target = self.models[self.zone(destination)]
        declared = event['destination']
        if declared['kind'] == 'map' and declared['map'] != target.source_data['source_map_constant']:
            raise ProtocolError('fixed Mansion script differs from source warp')
        if declared['kind'] == 'last_outdoor_map' and self.model().descriptor['last_outdoor'] != destination:
            raise ProtocolError('fixed Mansion outdoor context differs')
        arrival = target.events['warps'][declared['warp_index'] - 1]
        x, y = arrival['x'], arrival['y']
        if target.feet[y][x] in self.doors.get(target.source_data['tileset']['constant'], []):
            y += 1
        self.navigate((event['x'], event['y']), transition=self.zone(destination))
        if self.state['zone_id'] != self.zone(destination) and event['y'] in {0, self.model().height - 1}:
            self.send('press ' + ('up' if event['y'] == 0 else 'down'), 'wait 15')
            self.drain()
        self.require(zone_id=self.zone(destination), **{'player.x': x, 'player.y': y})
        self.refresh_world()

    def celadon_observation(self):
        result = self.observe('midgame-state')
        if type(result.get('coins')) is not int or not 0 <= result['coins'] <= 9999:
            raise ProtocolError('actual CoinWallet observation unavailable')
        return result

    def capture_slot_result(self):
        attempt = getattr(self, 'slot_attempt', None)
        if not attempt:
            return
        observation = self.celadon_observation()
        view = observation.get('celadonSlotView')
        if isinstance(view, dict) and view.get('phase') == 'result':
            if not attempt.get('spinning_observed') or view.get('bet') != 1:
                raise ProtocolError('slot result lacks actual one-coin spin')
            payout = view.get('payout')
            if type(payout) is not int or payout not in {0, 8, 15, 100, 300}:
                raise ProtocolError('slot result has an invalid source payout')
            if observation['coins'] != min(9999, attempt['coins_before'] - 1 + payout):
                raise ProtocolError('actual slot wallet differs from confirmed result')
            attempt['result'] = copy.deepcopy(view)
            attempt['coins_after'] = observation['coins']

    def celadon_service(self, stable, choices=(), background=False):
        self.celadon_choices = list(choices)
        try:
            if background:
                self.background(stable)
            else:
                self.visit_event(stable)
            if self.celadon_choices:
                raise ProtocolError('Celadon service ended before its fixed UI choices: ' + stable)
        finally:
            self.celadon_choices = []

    @staticmethod
    def species_count(owner, species):
        mons = owner['party']['members'] + [m for box in owner['storage']['boxes'] for m in sequence(box, 'box')]
        return sum(m['species'] == species for m in mons)

    def celadon_services_a(self):
        policy = cj.StagedSource(self.build_evidence).read('data/celadonServices/policy.json')['policy']
        if 'celadon-vending-drinks' not in self.completed_steps:
            self.ensure_room('CeladonMart2F')
            self.pickup(cj.sid('CELADON_MART_3F', 1), 'tm18', 'EVENT_GOT_TM18')
            self.travel(self.zone('CeladonMartRoof'))
            for drink, label in zip(policy['drinks'], ('FRESH WATER', 'SODA POP', 'LEMONADE')):
                if self.flag(drink['flag']):
                    continue
                before, money = self.quantity(drink['item']), self.inventory()['money']
                if money < drink['price']:
                    raise ProtocolError('earned money cannot afford planned vending drink')
                self.celadon_service('pokered:CELADON_MART_ROOF:background_events:1',
                    [label + '  ¥' + str(drink['price'])], background=True)
                if (self.quantity(drink['item']) != before + 1
                        or self.inventory()['money'] != money - drink['price']):
                    raise ProtocolError('actual vending purchase did not conserve money/items')
                tm = self.quantity(drink['tm'])
                self.celadon_service(cj.sid('CELADON_MART_ROOF', 2), ['YES', label])
                if (not self.flag(drink['flag']) or self.quantity(drink['item']) != before
                        or self.quantity(drink['tm']) != tm + 1):
                    raise ProtocolError('actual drink exchange did not grant its source TM')
                self.summary['rewards'].append(dict(id=cj.sid('CELADON_MART_ROOF', 2),
                    item=drink['tm'], flag=drink['flag']))
            self.heal_here('CeladonPokecenter')
            self.complete_at_center('celadon-vending-drinks')
        if 'celadon-eevee' not in self.completed_steps:
            self.travel(self.zone('CeladonCity'))
            for index, name in [(4, 'CeladonMansion1F'), (5, 'CeladonMansion2F'),
                    (4, 'CeladonMansion3F'), (3, 'CeladonMansionRoof'), (3, 'CeladonMansionRoofHouse')]:
                self.mansion_step_warp(index, name)
            if not self.flag(policy['eevee']['flag']):
                before = self.collection_owner()
                self.celadon_service(policy['eevee']['id'])
                after = self.collection_owner()
                if (self.species_count(after, 'eevee') != self.species_count(before, 'eevee') + 1
                        or not self.flag(policy['eevee']['flag'])):
                    raise ProtocolError('actual level 25 Eevee gift did not complete')
                added = after['party']['members'] + [m for box in after['storage']['boxes'] for m in sequence(box, 'box')]
                if not any(m['species'] == 'eevee' and m['level'] == 25 for m in added):
                    raise ProtocolError('source Eevee level differs')
            for index, name in [(1, 'CeladonMansionRoof'), (2, 'CeladonMansion3F'),
                    (4, 'CeladonMansion2F'), (3, 'CeladonMansion1F'), (3, 'CeladonCity')]:
                self.mansion_step_warp(index, name)
            self.heal_here('CeladonPokecenter')
            self.complete_at_center('celadon-eevee')
        if 'celadon-coins-prize-slot' in self.completed_steps:
            return
        self.pickup(cj.sid('CELADON_DINER', 5), 'coinCase', 'EVENT_GOT_COIN_CASE')
        self.travel(self.zone('GameCorner'))
        for stable, gift in sorted(policy['coin_gifts'].items()):
            if self.flag(gift['flag']):
                continue
            before = self.celadon_observation()['coins']
            self.celadon_service(stable)
            if not self.flag(gift['flag']) or self.celadon_observation()['coins'] != min(9999, before + gift['coins']):
                raise ProtocolError('actual source coin gift did not complete')
        # Buy only enough for Abra plus a losing one-coin spin. A random win is never required.
        for _ in range(3):
            before = self.celadon_observation()['coins']
            if before >= 121:
                break
            money = self.inventory()['money']
            if money < 1000:
                raise ProtocolError('earned money cannot fund the cheapest Blue prize and one spin')
            self.celadon_service(cj.sid('GAME_CORNER', 2), ['YES'])
            if self.celadon_observation()['coins'] != before + 50 or self.inventory()['money'] != money - 1000:
                raise ProtocolError('actual coin exchange did not conserve wallet/money')
        if self.celadon_observation()['coins'] < 121:
            raise ProtocolError('actual wallet cannot afford fixed Abra prize and wager')
        machine = policy['machines'][0]
        approaches = self.model().approaches((machine['x'] + self.model().padding, machine['y']))
        self.navigate(set(approaches))
        self.face(approaches[self.position()])
        self.slot_attempt = dict(id=machine['id'], coins_before=self.celadon_observation()['coins'])
        self.celadon_choices = ['YES', '×1', 'NO']
        try:
            self.send('press a', 'wait 2')
            self.drain()
            if self.celadon_choices or 'result' not in self.slot_attempt:
                raise ProtocolError('one real slot spin did not reach its confirmed terminal result')
            self.summary['slot_spin'] = copy.deepcopy(self.slot_attempt)
        finally:
            self.celadon_choices = []
            self.slot_attempt = None
        self.travel(self.zone('GameCornerPrizeRoom'))
        before, coins = self.collection_owner(), self.celadon_observation()['coins']
        self.celadon_service('pokered:GAME_CORNER_PRIZE_ROOM:background_events:1',
            ['ABRA  120', 'YES'], background=True)
        after = self.collection_owner()
        if (self.species_count(after, 'abra') != self.species_count(before, 'abra') + 1
                or self.celadon_observation()['coins'] != coins - 120):
            raise ProtocolError('actual Blue Abra prize did not conserve coins/specimens')
        members = after['party']['members'] + [m for box in after['storage']['boxes'] for m in sequence(box, 'box')]
        if not any(m['species'] == 'abra' and m['level'] == 6 for m in members):
            raise ProtocolError('Blue prize Abra must be level 6')
        self.summary['rewards'].append(dict(id='pokered:GAME_CORNER_PRIZE_ROOM:background_events:1',
            species='abra', level=6, actual_coin_cost=120))
        self.heal_here('CeladonPokecenter')
        self.complete_at_center('celadon-coins-prize-slot')

    def supplemental_services(self):
        self.pickup(cj.sid('CELADON_DINER', 5), 'coinCase', 'EVENT_GOT_COIN_CASE')
        self.pickup(cj.sid('CELADON_MART_3F', 1), 'tm18', 'EVENT_GOT_TM18')
        self.travel(self.zone('CeladonCity'))
        for index, name in [(4, 'CeladonMansion1F'), (5, 'CeladonMansion2F'),
                            (4, 'CeladonMansion3F'), (3, 'CeladonMansionRoof'), (3, 'CeladonMansionRoofHouse')]:
            self.mansion_step_warp(index, name)
        before = self.collection_owner()
        self.event_offer(cj.sid('CELADON_MANSION_ROOF_HOUSE', 2))
        after = self.collection_owner()
        def count_species(owner, species):
            mons = owner['party']['members'] + [m for box in owner['storage']['boxes'] for m in sequence(box, 'box')]
            return sum(m['species'] == species for m in mons)
        if count_species(after, 'eevee') != count_species(before, 'eevee') + 1:
            raise ProtocolError('actual Eevee gift acquisition unavailable/incomplete')
        for index, name in [(1, 'CeladonMansionRoof'), (2, 'CeladonMansion3F'),
                            (4, 'CeladonMansion2F'), (3, 'CeladonMansion1F'), (3, 'CeladonCity')]:
            self.mansion_step_warp(index, name)
        self.heal_here('FuchsiaPokecenter')
        self.travel(self.zone('FuchsiaCity'))
        self.source_waypoint(28, 20)
        before_encounters = len(self.summary['wild_encounters'])
        self.face('right')
        self.use_item('goodRod')
        if len(self.summary['wild_encounters']) <= before_encounters:
            raise ProtocolError('actual rod fishing encounter unavailable; no synthetic fishing success')
        self.event_offer(cj.sid('GAME_CORNER', 2))
        # No coin wallet observation exists in the supplied field packet yet.
        # An unavailable owner is an explicit gap, never a successful coin claim.
        raise ProtocolError('Game Corner coins/prizes/slots require field worker runtime and exact read-only wallet API')

    def route_full(self):
        self.route_celadon()
        self.route_hideout()
        self.route_tower()
        self.route_saffron()
        self.route_fuchsia()
        self.route_fly('CeladonCity')
        if self.config['content_scope'] == 'optional':
            self.optional_content()
            self.supplemental_services()
        self.route_fly('FuchsiaCity')
        self.heal_here('FuchsiaPokecenter')
        self.travel(self.zone('FuchsiaCity'))



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
