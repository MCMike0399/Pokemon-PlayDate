"""Earned checkpoint A/B and isolated accepted-B -> C input journeys. Root alone owns Simulator and save import.

Reuse existing route, battle, menu, capture and restart owners. No planner,
fixture, state setter, artificial reward or free preparation battle is provided.
"""
import copy
import hashlib
import json
import time
from pathlib import Path

from tools.harness import cerulean_journey as cj
from tools.harness import vermilion_journey as vj
from tools.harness.brock_journey import BrockJourney, NaturalBlackout, choose_battle_medicine
from tools.harness.journeys import DIRECTIONS, lookup
from tools.harness.parcel_journey import sequence
from tools.harness.protocol import ProtocolError, atomic_json
from tools.verify_moves.parse_lua import read_table

NAMES = {'midgame-natural', 'midgame-continue'}
SCENARIOS = Path(__file__).with_name('scenarios') / 'midgame'
BOUNDS = {'max_actions': (1, 120000), 'max_steps': (1, 20000),
          'max_encounters': (1, 256), 'max_blackouts': (0, 2), 'max_transitions': (1, 512)}
B_STEPS = {'tower-fuji-flute', 'route12-snorlax', 'bicycle-cycling-road',
           'fuchsia-koga', 'safari-hm03-gold-teeth-hm04-strength-surf'}
B_OPTIONAL = {'rods-fishing'}
C_STEPS = {'saffron-guard-entry', 'silph-rival-lapras-giovanni-president',
           'saffron_gym', 'dojo-gift', 'hm02-visited-fly'}
C_OPTIONAL = {'copycat-doll-tm31'}
B_AUXILIARY = {'fuchsia_gym', 'route13-rested'}
HMS = {'cut': 'hm01', 'fly': 'hm02', 'surf': 'hm03', 'strength': 'hm04', 'flash': 'hm05'}


def validate_config(config):
    allowed = set(BOUNDS) | {'name', 'starter', 'packet', 'content_scope', 'evolution_policy'}
    if not isinstance(config, dict) or set(config) - allowed or config.get('name') not in NAMES:
        raise ProtocolError('unknown or malformed midgame journey')
    for key, (low, high) in BOUNDS.items():
        if key in config and (type(config[key]) is not int or not low <= config[key] <= high):
            raise ProtocolError('invalid bounded midgame option: ' + key)
    if config.get('starter') not in cj.FAMILIES or config.get('packet') not in {'lavender', '5.5a', '5.5b', '5.5c'}:
        raise ProtocolError('midgame requires an original starter and explicit route packet')
    optional_starter = 'bulbasaur' if config['packet'] == '5.5c' else 'charmander'
    expected = 'optional' if config['starter'] == optional_starter else 'critical'
    if config.get('content_scope') != expected or config.get('evolution_policy', 'accept') != 'accept':
        raise ProtocolError('midgame scope must match the packet rotating starter; accept natural evolution')


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
            or starting.get('milestone') != ({'5.5b': '5.5a', '5.5c': '5.5b'}.get(groups[0]['journey']['packet'], '5.4'))
            or starting.get('starter') != groups[0]['journey']['starter']):
        raise ProtocolError('midgame starting milestone must match its explicit packet')
    if 'resume' in starting:
        reference = starting['resume']
        if (not isinstance(reference, dict) or set(reference) != {'path', 'sha256'}
                or not isinstance(reference['path'], str) or not Path(reference['path']).is_absolute()
                or not isinstance(reference['sha256'], str) or len(reference['sha256']) != 64):
            raise ProtocolError('resume requires an absolute checkpoint path and exact SHA256')


def validate_chain_record(record, spec, project):
    if spec['milestone'] == '5.5b':
        acceptance = 'docs/validation/midgame-b-acceptance-20261102.json'
        proof = json.loads((Path(project) / acceptance).read_bytes())
        rows = [row for row in proof.get('starters', []) if row.get('starter') == spec['starter']]
        if (proof.get('milestone') != '5.5b' or proof.get('milestone_accepted') is not True
                or proof.get('accepted_main_code') != 'af9a89380f9730767ff22b3ac5114cf32f216a75'
                or proof.get('production_source_sha256') != '9b086ab51d65b4ad212d8f4486ba01ce8562e563e41ebf3947e2c7dcad058284'
                or record.get('from_milestone') != '5.5b' or record.get('origin_milestone') != '5.5a'
                or record.get('starter') != spec['starter'] or len(rows) != 1
                or record.get('accepted_commit') != proof['accepted_main_code']
                or record.get('accepted_source_sha256') != proof['production_source_sha256']
                or record.get('acceptance') != acceptance or record.get('files') != rows[0].get('files')
                or record.get('source') != rows[0].get('evidence')
                or record.get('journey_source_sha256') != rows[0].get('journey_source_sha256')):
            raise ProtocolError('starting slots lack exact accepted 5.5b manifest binding')
        return
    if spec['milestone'] == '5.5a':
        proof = json.loads((Path(project) / 'docs/validation/midgame-a-acceptance-20261029.json').read_bytes())
        rows = [row for row in proof.get('starters', []) if row.get('starter') == spec['starter']]
        if (proof.get('milestone') != '5.5a' or proof.get('milestone_accepted') is not True
                or record.get('from_milestone') != '5.5a' or record.get('origin_milestone') != '5.4'
                or record.get('starter') != spec['starter'] or len(rows) != 1
                or record.get('accepted_commit') != proof.get('accepted_main_code')
                or record.get('accepted_source_sha256') != proof.get('production_source_sha256')
                or record.get('acceptance') != 'docs/validation/midgame-a-acceptance-20261029.json'
                or record.get('files') != rows[0].get('files')
                or record.get('source') != rows[0].get('evidence')
                or record.get('journey_source_sha256') != rows[0].get('source_sha256')):
            raise ProtocolError('starting slots lack exact accepted 5.5a manifest binding')
        return
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
               'celadon-vending-drinks', 'celadon-eevee', 'celadon-coins-prize-slot',
               'squirtle-ice-beam-preparation'}
    if state['packet'] == '5.5b':
        allowed = B_STEPS | B_AUXILIARY | (B_OPTIONAL if state['content_scope'] == 'optional' else set())
    if state['packet'] == '5.5c':
        allowed = C_STEPS | (C_OPTIONAL if state['content_scope'] == 'optional' else set())
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
    required = B_STEPS.copy() if state['packet'] == '5.5b' else {'rock-tunnel-flash-lavender'}
    if state['packet'] == '5.5b' and state['content_scope'] == 'optional':
        required |= B_OPTIONAL
    if state['packet'] == '5.5c':
        required = C_STEPS | (C_OPTIONAL if state['content_scope'] == 'optional' else set())
        if set(steps) != required:
            raise ProtocolError('C receipt requires only its complete story and scoped optional steps')
        flags = state['codec'].get('questFlags', {})
        quantities = {slot['id']: slot['quantity'] for slot in state['codec']['inventory']['slots']}
        required_flags = {'pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK',
                          'EVENT_BEAT_SILPH_CO_RIVAL', 'SILPH_STORY_V1_RIVAL_LEFT',
                          'BIT_GOT_LAPRAS', 'EVENT_BEAT_SILPH_CO_GIOVANNI',
                          'EVENT_GOT_MASTER_BALL', 'BADGE_MARSH', 'EVENT_GOT_TM46',
                          'EVENT_DEFEATED_FIGHTING_DOJO', 'EVENT_GOT_HITMONLEE', 'EVENT_GOT_HM02'}
        if state['content_scope'] == 'optional':
            required_flags.add('EVENT_GOT_TM31')
            if quantities.get('tm31', 0) < 1:
                raise ProtocolError('C optional receipt lacks actual TM31')
        if (any(flags.get(flag) is not True for flag in required_flags)
                or flags.get('EVENT_GOT_HITMONCHAN') is True
                or any(quantities.get(item, 0) < 1 for item in ('cardKey', 'masterBall', 'tm46', 'hm02'))):
            raise ProtocolError('C codec lacks actual required rewards')
        codec = state['codec']
        mons = codec['party']['members'] + [m for box in codec['storage']['boxes'] for m in sequence(box, 'PC box')]
        if (not any(m['species'] == 'lapras' and m['level'] >= 15 for m in mons)
                or not any(m['species'] == 'hitmonlee' and m['level'] >= 30 for m in mons)
                or not any('fly' in m['moves'] for m in codec['party']['members'])
                or not {'pokered:CELADON_CITY', 'pokered:SAFFRON_CITY'} <= set(codec['fieldTravel']['visited'])):
            raise ProtocolError('C codec lacks actual gifts, taught Fly or visited destinations')
    if state['packet'] == '5.5a':
        required |= {'celadon_gym', 'hideout-scope'}
        if state['content_scope'] == 'optional':
            required |= {'celadon-vending-drinks', 'celadon-eevee', 'celadon-coins-prize-slot'}
    if state['packet'] == '5.5b' and not set(steps) <= required | B_AUXILIARY:
        raise ProtocolError('B receipt contains an unrelated or unobserved route step')
    if not required <= set(steps):
        raise ProtocolError('incomplete route cannot publish a final saved receipt')
    if state['packet'] == '5.5b':
        codec = state['codec']
        flags = codec.get('questFlags', {})
        if not isinstance(flags, dict):
            flags = {}
        required_flags = {'BADGE_SOUL', 'EVENT_GOT_TM06', 'EVENT_RESCUED_MR_FUJI',
                          'EVENT_GOT_POKE_FLUTE', 'EVENT_BEAT_ROUTE12_SNORLAX',
                          'EVENT_BEAT_ROUTE16_SNORLAX', 'EVENT_GOT_HM03',
                          'EVENT_GOT_HM04', 'EVENT_GAVE_GOLD_TEETH'}
        slots = codec.get('inventory', {}).get('slots', [])
        quantities = {slot['id']: slot['quantity'] for slot in slots}
        items = {'pokeFlute', 'bicycle', 'hm03', 'hm04'}
        if state['content_scope'] == 'optional':
            items |= {'oldRod', 'goodRod', 'superRod'}
        safari = codec.get('safari', {})
        if (any(flags.get(flag) is not True for flag in required_flags)
                or any(quantities.get(item) != 1 for item in items)
                or quantities.get('goldTeeth', 0) != 0 or safari.get('active') is not False
                or safari.get('ending') != 'none' or safari.get('balls') != 0):
            raise ProtocolError('final B codec lacks verified rewards or settled Safari resources')


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
        self.summary.update(journey=copy.deepcopy(config), milestone=config['packet'] if config['packet'] in {'5.5b', '5.5c'} else '5.5a', acceptance='unrun candidate',
                            driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                            preparation_policy={'new_training_fights': 0, 'use_centers_and_shops': True})
        self.stage = 'cerulean'  # Existing shared source-trainer validation path.
        self.completed_steps = set()
        self.vermilion_active = True
        self.midgame_ready = False

    def frame_label(self, label):
        prefix = {'5.5b': 'm55b-', '5.5c': 'm55c-'}.get(self.config['packet'], 'm55a-')
        if label.startswith(prefix):
            return label
        for old_prefix in ('brock-', 'parcel-', 'cerulean-', 'vermilion-'):
            label = label.replace(old_prefix, '')
        if getattr(self, 'saving', False):
            label = 'save-' + str(self.save_number) + '-' + label
        return prefix + self.state.get('zone_id', 'title').replace('pokered:', '').lower() + '-' + label

    def send(self, *commands):
        if (getattr(self, 'restore_learning_brake', False)
                and self.state.get('root') == 'learning'
                and lookup(self.state, 'learning.phase') == 'message'
                and lookup(self.state, 'learning.remaining') == 0):
            # The choice is committed. Hold B again inside its final receipt,
            # before returning to the downhill world; menu choices stay unchanged.
            self.restore_learning_brake = False
            commands = ('hold b', *commands)
        if commands and commands[0] == 'press b' and self.state.get('root') == 'overworld':
            # Let the existing A/B gesture finish before opening a field menu.
            commands = ('wait 3', *commands)
        result = super().send(*commands)
        if getattr(self, 'midgame_ready', False):
            self.ensure_owner_map(self.state.get('zone_id'))
        return result

    def ensure_owner_map(self, zone):
        model = self.models.get(zone)
        source = getattr(model, 'source_data', None)
        if not source or source['name'] in self.owner_maps:
            return
        owners = self.observe('midgame-owners:' + source['name'])
        if owners.get('valid') is not True or owners.get('map_name') != source['name']:
            raise ProtocolError('actual bounded map owner observation differs')
        self.registered_events.update(self.owner_mapping(owners['registered_events']))
        shops = self.owner_mapping(owners['shops'])
        self.export['shops'].update(shops)
        self.vermilion['shops'].update(shops)
        self.source_trainers.update(self.owner_mapping(owners['trainers']))
        self.owner_maps.add(source['name'])

    @staticmethod
    def owner_mapping(value):
        if value == []:
            return {}
        if not isinstance(value, dict):
            raise ProtocolError('actual owner map must be a mapping')
        return value

    def learning(self):
        release = (getattr(self, 'cycling_brake', False)
                   and lookup(self.state, 'learning.input_blocked')
                   and lookup(self.state, 'learning.phase') != 'idle')
        if release:
            self.send('release b', 'wait 2')
            self.restore_learning_brake = True
            self.cycling_brake_needs_rearm = True
        try:
            return super().learning()
        finally:
            self.restore_learning_brake = False

    def rearm_cycling_brake(self):
        if not getattr(self, 'cycling_brake', False):
            return
        self.cycling_brake_needs_rearm = False
        before = dict(zone=self.state['zone_id'], position=self.position())
        # A door resets the field gesture to consumed. Release it physically;
        # any genuine first downhill cell is retained before braking again.
        self.send('release b', 'wait 1', 'hold b', 'wait 12')
        self.drain()
        self.summary.setdefault('cycling_brake_releases', []).append(dict(
            before=before, after=dict(zone=self.state['zone_id'], position=self.position())))

    def cross(self, direction, zone, destination):
        result = super().cross(direction, zone, destination)
        self.rearm_cycling_brake()
        return result

    def warp(self, target_id, event_id=None):
        result = super().warp(target_id, event_id)
        self.rearm_cycling_brake()
        return result

    def step(self, step):
        if (getattr(self, 'cycling_brake', False)
                and getattr(self, 'cycling_brake_needs_rearm', False)):
            self.rearm_cycling_brake()
            # Re-plan from the actual cell reached during the physical release.
            return
        zone, origin = self.state['zone_id'], self.position()
        try:
            result = super().step(step)
        except ProtocolError as error:
            block = lookup(self.state, 'player.lastTraversalBlock')
            if (step.kind != 'walk' or not str(error).startswith('source-valid walk failed:')
                    or self.state.get('zone_id') != zone or self.position() != origin
                    or block != {'kind': 'npc', 'id': 'occupied-next-cell'}):
                raise
            key = (zone, origin, step.destination)
            previous, count = getattr(self, 'npc_step_retry', (None, 0))
            count = count + 1 if previous == key else 1
            if count > 8:
                raise
            self.npc_step_retry = key, count
            self.summary.setdefault('npc_step_waits', []).append(dict(
                zone=zone, origin=origin, target=step.destination, retry=count))
            self.send('wait 8')
            return
        self.npc_step_retry = None, 0
        if (getattr(self, 'config', {}).get('packet') == '5.5c'
                and step.kind == 'walk' and self.position() != origin
                and self.state.get('root') == 'overworld'
                and self.state.get('overworld') == 'explore'
                and lookup(self.state, 'player.settled') is True
                and not lookup(self.state, 'player.pendingEdgeDoor')):
            self.c_transit_cells = getattr(self, 'c_transit_cells', 0) + 1
            if self.c_transit_cells >= 16:
                # Ordinary Save/codec observation only; this grants no quest
                # completion and uses the existing verified partial ancestry.
                self.save()
                self.c_transit_cells = 0
        return result

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
        self.export = {'session_codec': owners['version'], 'shops': self.owner_mapping(owners['shops'])}
        self.registered_events = self.owner_mapping(owners['registered_events'])
        self.owner_maps = set()
        self.vermilion['shops'].update(self.export['shops'])
        for stable, definition in self.owner_mapping(owners['trainers']).items():
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
        origin = {'5.5b': '5.5a', '5.5c': '5.5b'}.get(self.config['packet'], '5.4')
        if provenance.get('from_milestone') != origin or provenance.get('starter') != self.starter:
            raise ProtocolError('midgame requires imported accepted starting-save provenance')
        self.dependencies()
        self.title_continue()
        if self.config['packet'] in {'5.5b', '5.5c'}:
            accepted = provenance.get('accepted_boundary')
            if not isinstance(accepted, dict):
                raise ProtocolError('missing bound accepted previous checkpoint Save/Continue receipt')
            expected = provenance.get('resume', {}).get('state', accepted['state'])
            if self.codec_guard('loaded') != expected['codec']:
                raise ProtocolError('accepted previous checkpoint Continue differs from its complete actual saved codec')
            if self.quantity('silphScope') != 1 or not self.flag('BADGE_RAINBOW'):
                raise ProtocolError('accepted A Scope/Erika reward unavailable')
        if self.config['packet'] == '5.5c':
            validate_receipt_state(accepted['state'])
            if accepted['state']['packet'] != '5.5b':
                raise ProtocolError('C requires the complete accepted B receipt')
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
            if self.codec_migration:
                self.summary['startup_actor_visibility_migration'] = copy.deepcopy(self.codec_migration)
            self.completed_steps = set(saved['completed_steps'])
            self.summary['resumed_steps'] = sorted(self.completed_steps)
        self.summary['starting_save'] = provenance
        self.checkpoint('earned-flash-continue')

    def require_event(self, stable):
        self.ensure_owner_map(stable.rsplit(':', 2)[0])
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

    def teach(self, move, *, item=None, target=None):
        machine_target = target is not None
        if machine_target:
            source = cj.StagedSource(self.build_evidence)
            relative = 'data/machineData.lua'
            path = source.build / 'Source' / relative
            if hashlib.sha256(path.read_bytes()).hexdigest() != source.manifest.get(relative):
                raise ProtocolError('changed staged machine definitions')
            machines = read_table(path, 'MachineData')
            if (not 1 <= target <= len(self.party())
                    or machines['definitions'].get(item, {}).get('move') != move
                    or not machines['compatibility'].get(self.party()[target - 1]['species'], {}).get(item)):
                raise ProtocolError('source machine move/target compatibility unavailable: ' + str(item))
        known = next((i for i, mon in enumerate(self.party(), 1)
                      if move in mon['moves'] and (target is None or i == target)), None)
        if known:
            return known
        if machine_target:
            index = target
        else:
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
        item = item if machine_target else HMS[move]
        quantity = self.quantity(item)
        before_bag = copy.deepcopy(self.inventory())
        expected_moves = [list(mon['moves']) for mon in self.party()]
        replacement = None
        self.send('press b')
        self.pause_option('ITEM')
        self.send('press a')
        self.require(root='bag', **{'bag.phase': 'list'})
        slot = next((i for i, s in enumerate(self.inventory()['slots'], 1) if s['id'] == item), None)
        if slot is None:
            raise ProtocolError('earned machine missing: ' + item)
        self.select('bag.selected', slot)
        self.send('press a')
        self.select('bag.menu.selected', 1)
        self.send('press a')
        self.require(root='party')
        self.select('party_ui.selected', index)
        self.send('press a')
        if machine_target:
            self.require(root='learning', **{'learning.move_info.key': move})
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
                raise ProtocolError('unavailable machine teaching phase: ' + str(phase))
        else:
            raise ProtocolError('machine teaching action bound exhausted')
        if move not in self.party()[index - 1]['moves'] or self.quantity(item) != quantity:
            raise ProtocolError('actual reusable machine teaching did not complete: ' + move)
        if machine_target:
            if replacement is None:
                expected_moves[index - 1].append(move)
            else:
                expected_moves[index - 1][replacement - 1] = move
            if (self.inventory() != before_bag
                    or [mon['moves'] for mon in self.party()] != expected_moves):
                raise ProtocolError('machine teaching changed unexpected items or known moves')
            self.summary.setdefault('equipment_preparation', []).append(dict(
                item=item, move=move, party_index=index, species=self.party()[index - 1]['species'],
                known_moves=expected_moves[index - 1], replaced_slot=replacement,
                quantity_before=quantity, quantity_after=self.quantity(item)))
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

    def heal_here(self, name):
        if self.config['packet'] != '5.5c':
            return super().heal_here(name)
        self.travel(self.zone(name))
        if name == 'CeladonPokecenter':
            descriptor = cj.StagedSource(self.build_evidence).read(
                'data/midgameEast/events.json')['events'][self.zone(name) + ':objects:1']
            checkpoints = [step['checkpoint'] for step in descriptor['steps'] if step['op'] == 'heal']
            if (len(checkpoints) == 1
                    and lookup(self.state, 'session.checkpoint') == checkpoints[0]
                    and self.party()
                    and all(mon['hp'] == mon['maxHP'] and mon['status'] in {None, 'none'}
                            and mon['pp'] == mon['maxPP'] for mon in self.party())):
                self.summary.setdefault('already_restored_centers', []).append(name)
                return
        self.send('wait 1')
        history = getattr(self.client, 'history', None)
        if history:
            from tools.harness.restarting import validate_journey_pause
            validate_journey_pause(history.pause, self.client.read('result.json'))
            history.clear(time.monotonic() + 18)
        return super().heal_here(name)

    def save(self):
        # A final dialogue press can expose the overworld with its field
        # gesture still consumed. Release it before the inherited Save B tap.
        self.send('wait 1')
        history = getattr(self.client, 'history', None)
        if self.config['packet'] == '5.5c' and history:
            from tools.harness.restarting import validate_journey_pause
            # This is the existing, unacknowledged settled-overworld barrier.
            # Clear before deep Save work, without allowing a Clear inside UI/IO.
            validate_journey_pause(history.pause, self.client.read('result.json'))
            history.clear(time.monotonic() + 18)
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
        phases = [self.route_tower, self.route_fuchsia, self.route_bicycle] if self.config['packet'] == '5.5b' else [self.route_lavender]
        if self.config['packet'] == '5.5b' and self.config['content_scope'] == 'optional':
            phases.append(self.optional_b)
        if self.config['packet'] == '5.5a':
            phases.append(self.route_a)
        if self.config['packet'] == '5.5c':
            phases = [self.route_c_guard, self.route_c_silph, self.route_c_sabrina,
                      self.route_c_dojo, self.route_c_fly]
            if self.config['content_scope'] == 'optional':
                phases.append(self.optional_c_copycat)
        observed_groups = {'route_c_guard': {'saffron-guard-entry'},
                           'route_c_silph': {'silph-rival-lapras-giovanni-president'},
                           'route_c_sabrina': {'saffron_gym'}, 'route_c_dojo': {'dojo-gift'},
                           'route_c_fly': {'hm02-visited-fly'}, 'optional_c_copycat': C_OPTIONAL,
                           'route_tower': {'tower-fuji-flute'},
                           'route_fuchsia': {'route12-snorlax', 'fuchsia-koga', 'safari-hm03-gold-teeth-hm04-strength-surf'},
                           'route_bicycle': {'bicycle-cycling-road'}, 'optional_b': B_OPTIONAL}
        for index, phase in enumerate(phases):
            group = phase.__name__
            if self.config['packet'] in {'5.5b', '5.5c'} and observed_groups[group] <= self.completed_steps:
                continue
            for _ in range(self.config.get('max_blackouts', 1) + 1):
                try:
                    phase()
                    break
                except NaturalBlackout:
                    # Keep the real loss, half-money penalty and restored
                    # checkpoint. Won trainer flags persist through the retry.
                    self.recover_path_blackout(phase.__name__)
                    self.save()
            else:
                raise ProtocolError('midgame checkpoint recovery budget exhausted')
        self.save()
        self.write_receipt()
        self.summary['acceptance'] = 'earned candidate saved; actual process restart pending'

    def advance_event(self, stop_phase=None):
        baseline = getattr(self, 'safari_battle_before', None)
        if baseline is not None and self.state.get('root') != 'safariBattle':
            completed = self.safari_observation().get('lastBattle', {})
            if (completed.get('encounter') != baseline['encounter']
                    or self.inventory() != baseline['inventory']
                    or [mon['xp'] for mon in self.party()][:len(baseline['xp'])] != baseline['xp']):
                raise ProtocolError('Safari exit changed ordinary resources or lacks terminal encounter receipt')
            self.summary.setdefault('safari_battles', []).append(copy.deepcopy(completed))
            self.safari_battle_before = None
        if self.state.get('root') == 'safariPassage':
            passage = self.safari_observation()['passage']
            if self.state.get('root') != 'safariPassage':
                return True
            phase = passage['phase']
            if phase == 'failed':
                raise ProtocolError('actual Safari passage failed: ' + str(passage.get('lastFailure')))
            if phase == 'announcement':
                self.send('press a')
            elif phase in {'before', 'fade', 'after'}:
                self.send('wait 3')
            else:
                raise ProtocolError('unexpected Safari passage phase: ' + str(phase))
            return True
        if self.state.get('root') == 'safariBattle':
            return self.advance_safari_battle()
        if self.state.get('root') == 'fieldGear':
            gear = self.observe('midgame-state')['fieldGear']
            if self.state.get('root') != 'fieldGear':
                return True
            if not gear.get('installed') or not gear.get('active'):
                raise ProtocolError('actual FieldGear controller unavailable')
            attempt = getattr(self, 'fishing_attempt', None)
            if attempt is not None:
                attempt['phases'].append(copy.deepcopy(gear))
            if gear['phase'] in {'cast', 'bite'}:
                self.send('wait 3')
            elif gear['phase'] == 'result':
                self.send('press a')
            else:
                raise ProtocolError('unexpected FieldGear phase: ' + str(gear['phase']))
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
        attempt = getattr(self, 'fishing_attempt', None)
        if attempt is not None and self.state.get('root') == 'battle':
            attempt['battle'] = copy.deepcopy(self.state.get('battle'))
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

    def safari_observation(self):
        safari = self.observe('midgame-state').get('safari', {})
        if not safari.get('sessionInstalled') or not safari.get('battleRegistered'):
            raise ProtocolError('Safari requires installed resource and battle owners')
        return safari

    def advance_safari_battle(self):
        safari = self.safari_observation()
        if self.state.get('root') != 'safariBattle':
            return True
        battle = safari['battle']
        if not battle.get('active') or battle.get('lastFailure'):
            raise ProtocolError('actual Safari battle unavailable/failed: ' + str(battle))
        if getattr(self, 'safari_battle_before', None) is None:
            self.safari_battle_before = dict(encounter=battle['encounter'],
                inventory=copy.deepcopy(self.inventory()), xp=[mon['xp'] for mon in self.party()])
        if battle['phase'] == 'message':
            self.send('press a')
        elif battle['phase'] == 'action':
            self.send('wait 3')
        elif battle['phase'] == 'command':
            menu = battle['menu']
            if not menu.get('active') or menu.get('columns') != 2 or menu.get('options') != ['BALL', 'BAIT', 'ROCK', 'RUN']:
                raise ProtocolError('actual Safari command menu differs')
            # Optional Charmander throws one actual BALL; all other encounters
            # use RUN. Neither a catch nor an enemy remaining is required.
            command = 'ball' if (self.config['content_scope'] == 'optional'
                and not self.summary.get('safari_ball')) else 'run'
            target = 1 if command == 'ball' else 4
            selected = battle['selected']
            if (selected - 1) % 2 != (target - 1) % 2:
                self.send('press right' if target % 2 == 0 else 'press left')
            elif (selected - 1) // 2 != (target - 1) // 2:
                self.send('press down' if target > 2 else 'press up')
            else:
                inventory = copy.deepcopy(self.inventory())
                xp = [mon['xp'] for mon in self.party()]
                turns = battle['turns']
                self.send('press a')
                after = self.safari_observation()['battle']
                turn = after.get('lastTurn', {})
                if after.get('turns') != turns + 1 or turn.get('command') != command:
                    raise ProtocolError('Safari command did not actually commit')
                if (self.inventory() != inventory or [mon['xp'] for mon in self.party()][:len(xp)] != xp
                        or turn['before']['steps'] != turn['after']['steps']):
                    raise ProtocolError('Safari turn changed ordinary bag, money, XP or steps')
                if command == 'ball':
                    capture = turn.get('receipt', {}).get('capture', {})
                    if (turn['before']['balls'] - turn['after']['balls'] != 1
                            or capture.get('ballId') != 'safariBall' or type(capture.get('caught')) is not bool):
                        raise ProtocolError('Safari BALL lacks actual resource/capture receipt')
                    self.summary['safari_ball'] = copy.deepcopy(turn)
                elif turn['before']['balls'] != turn['after']['balls']:
                    raise ProtocolError('Safari RUN spent a ball')
                self.summary.setdefault('safari_turns', []).append(copy.deepcopy(turn))
        else:
            raise ProtocolError('unexpected Safari battle phase: ' + str(battle['phase']))
        return True

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

    def portals(self, model):
        # Ordinary shop trips use these source stair and exit warps. Elevator
        # travel requires an explicit floor choice through its own menu.
        stairs = {
            'CELADON_MART_1F': {1, 2, 3, 4, 5},
            'CELADON_MART_2F': {1, 2},
            'CELADON_MART_3F': {1, 2},
            'CELADON_MART_4F': {1, 2},
            'CELADON_MART_5F': {1, 2},
            'CELADON_MART_ROOF': {1},
        }
        source = getattr(model, 'source_data', None) or {}
        allowed = stairs.get(source.get('source_map_constant'))
        for point, kind, detail in super().portals(model):
            if allowed is not None and kind == 'warp' and detail['source_index'] not in allowed:
                continue
            yield point, kind, detail

    def project_warp(self, model, event):
        if model.name == self.zone('SilphCoElevator'):
            # Both cabin warps land on the floor the source scene persisted. A
            # genuine transit Save can resume inside the cabin, so the planner
            # must project its exits without replaying a floor selection.
            scenes = self.scene_data('data/silphStory/scenes.json')
            for floor in scenes['elevator']:
                if self.flag('SILPH_STORY_LIFT_V1_' + str(floor['floor'])):
                    target = self.models[self.zone('SilphCo' + str(floor['floor']) + 'F')]
                    destination = floor['destination']
                    return target.name, (destination['x'] + target.padding, destination['y'])
            raise ProtocolError('missing persisted Silph elevator destination')
        # Hideout lift entries use explicit cabin positions without a door step.
        scenes = self.scene_data('data/rocketHideoutStory/scenes.json')
        for floor in scenes['elevator']:
            if model.name != floor['map_id']:
                continue
            for index, exit in enumerate(floor['exits'], start=1):
                if event['source_index'] == exit['warp']:
                    cabin = self.models[self.zone('RocketHideoutElevator')]
                    return cabin.name, (index + 1 + cabin.padding, 1)
        return super().project_warp(model, event)

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
            if (number == len(route['steps']) - 1 and destination != route['map']
                    and self.state['zone_id'] == self.zone(destination)):
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

    def battle_preparation_action(self, battle, options):
        targets = getattr(self, 'surf_acquisition', None)
        if targets and not battle.get('trainerName') and battle['enemy']['species'] in targets:
            if choose_battle_medicine(battle['player'], self.inventory()):
                return False
            ball = next((key for key in ('ultraBall', 'greatBall', 'pokeBall') if self.quantity(key)), None)
            if not ball:
                raise ProtocolError('earned Surf-user capture exhausted actual balls')
            if self.surf_capture_throws >= 24:
                raise ProtocolError('earned Surf-user capture exceeded its real throw bound')
            before = self.collection_owner()
            bag = [i for i, value in enumerate(options, 1)
                   if value == 'BAG' or isinstance(value, dict) and value.get('action') == 'bag']
            if len(bag) != 1:
                raise ProtocolError('Surf-user capture requires the actual BAG action')
            quantity = self.quantity(ball)
            self.select('battle.menu.selected', bag[0])
            self.send('press a')
            self.require(root='bag')
            slot = next(i for i, row in enumerate(self.inventory()['slots'], 1) if row['id'] == ball)
            self.select('bag.selected', slot)
            self.send('press a')
            self.require(root='battle')
            result = copy.deepcopy(lookup(self.state, 'battle.capture_result'))
            if self.quantity(ball) != quantity - 1 or not isinstance(result, dict):
                raise ProtocolError('Surf-user capture lacks actual ball consumption/receipt')
            self.surf_capture_throws += 1
            record = dict(species=battle['enemy']['species'], ball=ball, result=result)
            after = self.collection_owner()
            if result.get('caught'):
                record['commit'] = vj.verify_capture_commit(before, after, battle['enemy']['species'], result)
            self.summary.setdefault('surf_user_throws', []).append(record)
            return True
        primary = self.starter_index()
        active = lookup(self.state, 'session.party.active')
        if active != primary:
            starter = self.party()[primary - 1]
            if starter['hp'] == 0 and self.quantity('revive') > 0:
                self.battle_medicine('revive', options, target=primary)
                return True
            if starter['hp'] > 0:
                # Spend real turns healing in reserve before exposing the starter.
                medicine = choose_battle_medicine(starter, self.inventory())
                if medicine:
                    self.battle_medicine(medicine, options, target=primary)
                    return True
                if self.battle_switch(primary, options, 'return to the earned starter'):
                    self.switch_back = False
                    return True
                # A trapping rejection closes Party without spending a turn.
                # Reopen the command menu once, then let FIGHT proceed (or fail
                # honestly on status-only moves), never retry Party in this hook.
                self.require(root='battle')
                self.await_value('battle.menu.active', True)
                self.switch_back = False
                return False
        return super().battle_preparation_action(battle, options)

    def restock(self, mart):
        clerk = self.zone(mart) + ':objects:1'
        shop = self.vermilion['shops'].get(clerk)
        if not shop:
            raise ProtocolError('actual shop owner unavailable: ' + mart)
        purchases = [('antidote', 2), ('superPotion', 4)]
        if self.config['packet'] == '5.5b':
            purchases = [('revive', 4), ('antidote', 4), ('superPotion', 12)]
        if self.config['packet'] == '5.5b' and mart == 'LavenderMart' and self.config['content_scope'] == 'critical':
            purchases.insert(0, ('escapeRope', 1))
        if mart == 'CeladonMart2F':
            # Stock and prices come from the existing midgame-owners projection.
            self.require_shop_stock(clerk, 'revive')
            purchases.insert(0, ('revive', 2))
            if self.starter == 'squirtle':
                # Use earned money against the Grass Gym rather than add XP
                # farming. Existing affordability caps keep the 1,200 reserve.
                purchases = [('revive', 4), ('antidote', 2), ('superPotion', 10)]
        for item, target in purchases:
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
        if constant == 'CELADON_GYM':
            cut = self.teach('cut')
            self.field_cut(cut, 'CeladonCity', (35, 32))
            self.field_cut(cut, 'CeladonGym', (5, 7))
        self.fight(stable)
        if not self.flag(badge) or not self.flag('EVENT_GOT_' + tm.upper()) or self.quantity(tm) < 1:
            raise ProtocolError('actual leader/badge/TM reward missing: ' + stable)
        self.completed_steps.add(constant.lower())
        self.checkpoint(constant.lower() + '-badge-and-' + tm)
        if constant == 'CELADON_GYM':
            # Leaving the Gym begins a new city visit and restores its tree.
            self.field_cut(cut, 'CeladonCity', (35, 32))
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
            if self.starter == 'squirtle':
                self.prepare_squirtle_ice_beam()
            self.ensure_room('CeladonMart2F')
            self.leader('CELADON_GYM', 'BADGE_RAINBOW', 'tm21', 'CeladonPokecenter', 'CeladonMart2F')

    def prepare_squirtle_ice_beam(self):
        # Equipment for the earned starter, using only the existing Blue service
        # and Bag/Party/learning UI. Charmander retains all optional roof gifts.
        policy = cj.StagedSource(self.build_evidence).read('data/celadonServices/policy.json')['policy']
        drink = next((d for d in policy['drinks'] if d['item'] == 'freshWater'), None)
        if (drink is None or drink['price'] != 200 or drink['tm'] != 'tm13'
                or drink['flag'] != 'EVENT_GOT_TM13'):
            raise ProtocolError('source Fresh Water/TM13 exchange unavailable')
        targets = [i for i, mon in enumerate(self.party(), 1) if mon['species'] in cj.FAMILIES['squirtle']]
        if len(targets) != 1:
            raise ProtocolError('equipment preparation requires exactly one earned Squirtle-family starter')
        target = targets[0]
        step = 'squirtle-ice-beam-preparation'
        if step in self.completed_steps:
            if (not self.flag(drink['flag']) or self.quantity('tm13') < 1
                    or 'iceBeam' not in self.party()[target - 1]['moves']):
                raise ProtocolError('saved Squirtle equipment preparation was lost')
            return
        self.ensure_room('CeladonMart2F')
        if not self.flag(drink['flag']):
            self.travel(self.zone('CeladonMartRoof'))
            before = copy.deepcopy(self.inventory())
            water, tm = self.quantity('freshWater'), self.quantity('tm13')
            money = before['money']
            if money < drink['price']:
                raise ProtocolError('earned money cannot afford Fresh Water equipment exchange')
            self.celadon_service('pokered:CELADON_MART_ROOF:background_events:1',
                ['FRESH WATER  ¥' + str(drink['price'])], background=True)
            if (self.quantity('freshWater') != water + 1
                    or self.inventory()['money'] != money - drink['price']):
                raise ProtocolError('actual Fresh Water purchase did not conserve money/items')
            self.celadon_service(cj.sid('CELADON_MART_ROOF', 2), ['YES', 'FRESH WATER'])
            expected = {slot['id']: slot['quantity'] for slot in before['slots']}
            expected['tm13'] = tm + 1
            if (not self.flag(drink['flag']) or self.quantity('freshWater') != water
                    or self.inventory()['money'] != money - drink['price']
                    or {slot['id']: slot['quantity'] for slot in self.inventory()['slots']} != expected):
                raise ProtocolError('actual Fresh Water exchange did not grant exactly TM13')
            self.summary['rewards'].append(dict(id=cj.sid('CELADON_MART_ROOF', 2),
                item='tm13', flag=drink['flag'], cost=drink['price']))
        if self.quantity('tm13') < 1:
            raise ProtocolError('earned rooftop TM13 missing')
        self.teach('iceBeam', item='tm13', target=target)
        self.heal_here('CeladonPokecenter')
        self.require(root='overworld', zone_id=self.zone('CeladonPokecenter'))
        self.complete_at_center(step)

    def route_a(self):
        self.route_celadon()
        if 'hideout-scope' not in self.completed_steps:
            self.route_hideout()
        elif self.state['zone_id'] == self.zone('RocketHideoutB4F'):
            # Continue from the actual post-Scope Save, without replaying fights.
            self.leave_hideout()
        if self.config['content_scope'] == 'optional':
            self.celadon_services_a()
        if (not self.flag('BADGE_RAINBOW') or not self.flag('EVENT_GOT_TM21')
                or self.quantity('silphScope') != 1):
            raise ProtocolError('5.5a requires actual Erika rewards and Silph Scope')
        self.heal_here('CeladonPokecenter')
        self.require(zone_id=self.zone('CeladonPokecenter'))

    def exit_hideout_lift(self, destination):
        self.require(zone_id=self.zone('RocketHideoutElevator'))
        # The panel approach can leave RED standing on an exit. Step off it
        # before walking onto the selected floor's existing source warp.
        self.source_waypoint(2, 2)
        self.navigate((2 + self.model().padding, 1), transition=self.zone(destination))
        self.require(zone_id=self.zone(destination))
        self.refresh_world()

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
        self.exit_hideout_lift('RocketHideoutB4F')
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 2))
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 3))
        # Source applies the guard door on map load. Re-enter the selected cabin.
        self.warp(self.zone('RocketHideoutElevator'))
        self.exit_hideout_lift('RocketHideoutB4F')
        self.fight(cj.sid('ROCKET_HIDEOUT_B4F', 1))
        self.pickup(cj.sid('ROCKET_HIDEOUT_B4F', 8), 'silphScope')
        self.completed_steps.add('hideout-scope')
        self.save()
        self.leave_hideout()

    def leave_hideout(self):
        self.require(zone_id=self.zone('RocketHideoutB4F'))
        if (self.quantity('silphScope') != 1
                or not all(self.defeated(cj.sid('ROCKET_HIDEOUT_B4F', index)) for index in (1, 2, 3))):
            raise ProtocolError('Hideout exit requires earned Scope and confirmed Giovanni/guard victories')
        self.warp(self.zone('RocketHideoutElevator'))
        # B1F's lift component stays sealed until its own Rocket is beaten.
        # Return through B2F's source spinner and entrance stairs instead.
        self.floor_choice = 'B2F'
        self.background('pokered:ROCKET_HIDEOUT_ELEVATOR:background_events:1')
        self.floor_choice = None
        self.exit_hideout_lift('RocketHideoutB2F')
        self.fixed_hideout(4, 'RocketHideoutB2F')
        self.fixed_warp(1, (26, 8))
        self.require(zone_id=self.zone('RocketHideoutB1F'), **{'player.x': 23, 'player.y': 3})
        self.source_waypoint(22, 3)
        self.fixed_warp(2, (22, 2))
        self.require(zone_id=self.zone('GameCorner'), **{'player.x': 17, 'player.y': 5})
        self.heal_here('CeladonPokecenter')
        self.save()

    def flee(self):
        targets = getattr(self, 'surf_acquisition', None)
        enemy = lookup(self.state, 'battle.enemy')
        if targets and isinstance(enemy, dict) and enemy.get('species') in targets:
            return self.battle('earned-surf-user')
        expected = getattr(self, 'scripted_wild', None)
        enemy = lookup(self.state, 'battle.enemy')
        if expected and isinstance(enemy, dict) and enemy.get('species') == expected['species'] and enemy.get('level') == expected['level']:
            return self.battle('source-' + expected['species'], expected='win')
        return super().flee()

    def route_tower(self):
        scenes = self.scene_data('data/towerStory/scenes.json')
        self.heal_here('LavenderPokecenter')
        self.restock('LavenderMart')
        self.ensure_room('LavenderMart')
        self.travel(self.zone('PokemonTower1F'))
        for floor in range(2, 7):
            self.warp(self.zone('PokemonTower' + str(floor) + 'F'))
            if floor == 2:
                self.require_event(cj.sid('POKEMON_TOWER_2F', 1))
                self.fight(cj.sid('POKEMON_TOWER_2F', 1))
        # The original Rare Candy occupies the only live route to the ghost.
        self.pickup(cj.sid('POKEMON_TOWER_6F', 4), 'rareCandy')
        self.scripted_wild = dict(species=scenes['ghost']['species'], level=scenes['ghost']['level'])
        self.source_waypoint(10, 15)
        # The trigger is walkable; face() requires a blocked, stationary press.
        self.send('press down', 'wait 10')
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

    def route_c_guard(self):
        flag = 'pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK'
        # A stopped genuine transit Save can already contain the committed
        # transaction. Do not buy/consume a second drink on its Continue.
        if not self.flag(flag):
            # B ends at Fuchsia. Reuse walking return legs without replaying B phases.
            if self.state['zone_id'] in {self.zone('FuchsiaPokecenter'), self.zone('FuchsiaCity')}:
                self.return_from_fuchsia_to_route12()
            # A genuine transit Continue may start partway through the eastern leg.
            # Reuse its declared cells instead of planning back through Fuchsia.
            if self.state['zone_id'] == self.zone('Route15'):
                self.source_waypoint(59, 8)
                self.cross('right', self.zone('Route14'), (0, 44))
            if self.state['zone_id'] == self.zone('Route14'):
                self.source_waypoint(19, 10)
                self.cross('right', self.zone('Route13'), (0, 10))
            if self.state['zone_id'] == self.zone('Route13'):
                self.source_waypoint(51, 0)
                self.cross('up', self.zone('Route12'), (11, 107))
            if self.state['zone_id'] == self.zone('Route12'):
                self.return_from_route12_to_lavender()
                # A genuine transit Save can resume this long return leg under the
                # unchanged per-process history budget. It completes no C quest.
                self.save()
            self.ensure_room('CeladonMart2F')
            self.heal_here('CeladonPokecenter')
            self.travel(self.zone('CeladonMart1F'))
            for name in ('CeladonMart2F', 'CeladonMart3F', 'CeladonMart4F', 'CeladonMart5F', 'CeladonMartRoof'):
                self.warp(self.zone(name))
            vending = 'pokered:CELADON_MART_ROOF:background_events:1'
            before_money, before_water = self.inventory()['money'], self.quantity('freshWater')
            self.celadon_service(vending, ['FRESH WATER  ¥200'], background=True)
            if self.quantity('freshWater') != before_water + 1 or self.inventory()['money'] != before_money - 200:
                raise ProtocolError('actual source vending purchase unavailable/incomplete')
            drinks = {item: self.quantity(item) for item in ('freshWater', 'sodaPop', 'lemonade')}
            money = self.inventory()['money']
            flag = 'pokered:wStatusFlags1:BIT_GAVE_SAFFRON_GUARDS_DRINK'
            opened = self.flag(flag)
            self.travel(self.zone('Route7Gate'))
            if not opened:
                self.visit_event(cj.sid('ROUTE_7_GATE', 1))
            if not self.flag(flag):
                raise ProtocolError('actual guard drink transaction did not open Saffron')
            if (any(self.quantity(item) != quantity - (1 if item == 'freshWater' and not opened else 0)
                    for item, quantity in drinks.items()) or self.inventory()['money'] != money):
                raise ProtocolError('guard did not consume exactly one priority drink')
        self.heal_here('SaffronPokecenter')
        self.travel(self.zone('SaffronCity'))
        if self.zone('SaffronCity') not in self.observe('midgame-state')['fieldTravel']['visited']:
            raise ProtocolError('actual Saffron entry did not record visited history')
        self.checkpoint('guard-drink-saffron-entry')
        self.complete_at_center('saffron-guard-entry')

    def route_c_silph(self):
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
        self.c_gift(cj.sid('SILPH_CO_7F', 1), 'lapras', 15, 'BIT_GOT_LAPRAS')
        self.fixed_warp(4, (5, 6))
        self.fixed_leg('silph-fixed-routes.json', 'giovanni-door-approach')
        self.key_door((6, 14), 'up', 'EVENT_SILPH_CO_11_UNLOCKED_DOOR')
        self.fixed_leg('silph-fixed-routes.json', 'giovanni-trigger')
        if not self.defeated(cj.sid('SILPH_CO_11F', 3)) or not self.flag('EVENT_BEAT_SILPH_CO_GIOVANNI'):
            raise ProtocolError('actual Silph Giovanni victory did not commit')
        self.fixed_leg('silph-fixed-routes.json', 'president-approach')
        self.pickup(cj.sid('SILPH_CO_11F', 1), 'masterBall', 'EVENT_GOT_MASTER_BALL')
        self.completed_steps.add('silph-rival-lapras-giovanni-president')
        self.heal_here('SaffronPokecenter')
        self.checkpoint('silph-liberated-master-ball')
        self.save()

    def route_c_sabrina(self):
        self.heal_here('SaffronPokecenter')
        self.ensure_room('SaffronMart')
        self.restock('SaffronMart')
        self.travel(self.zone('SaffronGym'))
        route = json.loads((SCENARIOS / 'silph-fixed-routes.json').read_bytes())
        for index in route['saffron_gym_in']:
            self.fixed_warp(index)
        self.fight(cj.sid('SAFFRON_GYM', 1))
        if not self.flag('EVENT_GOT_TM46'):
            self.visit_event(cj.sid('SAFFRON_GYM', 1))
        if not self.flag('BADGE_MARSH') or not self.flag('EVENT_GOT_TM46') or self.quantity('tm46') < 1:
            raise ProtocolError('actual Sabrina reward missing')
        for index in route['saffron_gym_out']:
            self.fixed_warp(index)
        self.warp(self.zone('SaffronCity'))
        self.completed_steps.add('saffron_gym')
        self.heal_here('SaffronPokecenter')
        self.checkpoint('sabrina-badge-tm46')
        self.save()

    def route_saffron(self):
        # Historical full-route entry point; never selected by A, B or C.
        self.route_c_guard()
        self.route_c_silph()
        self.route_c_sabrina()

    def c_gift(self, stable, species, level, flag):
        before = self.collection_owner()
        if self.flag(flag):
            if self.species_count(before, species) < 1:
                raise ProtocolError('committed gift missing from actual party and PC: ' + species)
            return
        storage = before['storage']
        destination = 'party' if len(before['party']['members']) < 6 else 'storage'
        box = storage['active']
        if destination == 'storage' and len(sequence(storage['boxes'][box - 1], 'selected PC box')) >= 20:
            raise ProtocolError('actual selected PC box is full; gift requires real PC capacity before retry')
        self.event_offer(stable)
        after = self.collection_owner()
        old = before['party']['members'] if destination == 'party' else sequence(storage['boxes'][box - 1], 'box')
        new = after['party']['members'] if destination == 'party' else sequence(after['storage']['boxes'][box - 1], 'box')
        if (not self.flag(flag) or self.species_count(after, species) != self.species_count(before, species) + 1
                or len(new) != len(old) + 1 or new[:-1] != old
                or new[-1]['species'] != species or new[-1]['level'] != level
                or (destination == 'storage' and after['party'] != before['party'])
                or (destination == 'party' and after['storage'] != before['storage'])):
            raise ProtocolError('actual gift destination/specimen differs: ' + species)
        expected_storage = copy.deepcopy(before['storage'])
        if destination == 'storage':
            expected_storage['boxes'][box - 1] = new
        if after['storage'] != expected_storage:
            raise ProtocolError('gift changed another PC box or active selection')
        self.summary.setdefault('c_gifts', []).append(dict(species=species, level=level,
            destination=destination, box=box if destination == 'storage' else None))
        self.checkpoint('earned-' + species + '-' + destination)

    def route_c_dojo(self):
        self.heal_here('SaffronPokecenter')
        self.travel(self.zone('FightingDojo'))
        self.source_waypoint(4, 3)
        self.fight(cj.sid('FIGHTING_DOJO', 1))
        self.c_gift(cj.sid('FIGHTING_DOJO', 6), 'hitmonlee', 30, 'EVENT_GOT_HITMONLEE')
        if (not self.flag('EVENT_DEFEATED_FIGHTING_DOJO')
                or self.flag('EVENT_GOT_HITMONCHAN')):
            raise ProtocolError('Dojo completion or mutually exclusive gift differs')
        self.completed_steps.add('dojo-gift')
        self.heal_here('SaffronPokecenter')
        self.save()

    def route_c_fly(self):
        self.ensure_room('CeladonMart2F')
        self.travel(self.zone('CeladonCity'))
        cut = self.teach('cut')
        self.travel(self.zone('Route16'))
        sites = self.field_definitions['maps'].get(self.zone('Route16'), {}).get('sites', [])
        if not sites:
            raise ProtocolError('prepared C lacks Route16 Cut site; root must supply pinned field capability for Fly house')
        targets = [target for site in sites for target in site['targets']]
        if len(targets) != 1:
            raise ProtocolError('Route16 Fly approach requires one pinned Cut target')
        self.field_cut(cut, 'Route16', (targets[0]['x'], targets[0]['y']))
        self.fixed_warp(7, (25, 4))
        self.require(zone_id=self.zone('Route16Gate1F'))
        self.fixed_warp(5, (1, 2))
        self.require(zone_id=self.zone('Route16'))
        self.fixed_warp(9, (7, 6))
        self.pickup(cj.sid('ROUTE_16_FLY_HOUSE', 1), 'hm02', 'EVENT_GOT_HM02')
        self.fixed_warp(1, (2, 6))
        self.require(zone_id=self.zone('Route16'))
        index = self.teach('fly')
        for city in ('CeladonCity', 'SaffronCity'):
            before = self.observe('midgame-state')['fieldTravel']
            target = self.zone(city)
            if target not in before['visited']:
                raise ProtocolError('Fly destination was never genuinely visited: ' + city)
            pp = copy.deepcopy(self.party()[index - 1]['pp'])
            self.fly_target = target
            try:
                self.use_field(index, 'fly')
            finally:
                self.fly_target = None
            self.require(zone_id=target)
            after = self.observe('midgame-state')['fieldTravel']
            if after['visited'] != before['visited'] or self.party()[index - 1]['pp'] != pp:
                raise ProtocolError('Fly changed visited history or consumed PP')
            self.checkpoint('actual-fly-' + city.lower())
        self.completed_steps.add('hm02-visited-fly')
        self.heal_here('SaffronPokecenter')
        self.save()

    def optional_c_copycat(self):
        self.ensure_room('CeladonMart2F')
        clerk = cj.sid('CELADON_MART_4F', 1)
        self.travel(self.zone('CeladonMart4F'))
        if self.quantity('pokeDoll') == 0:
            self.buy_item(clerk, 'pokeDoll', 1, self.vermilion['shops'][clerk]['prices']['pokeDoll'])
        self.travel(self.zone('CopycatsHouse2F'))
        before = copy.deepcopy(self.inventory())
        doll, tm = self.quantity('pokeDoll'), self.quantity('tm31')
        if not self.flag('EVENT_GOT_TM31'):
            self.visit_event(cj.sid('COPYCATS_HOUSE_2F', 1))
            if (not self.flag('EVENT_GOT_TM31') or self.quantity('pokeDoll') != doll - 1
                    or self.quantity('tm31') != tm + 1 or self.inventory()['money'] != before['money']):
                raise ProtocolError('actual Copycat Doll/TM31 exchange incomplete')
        inventory = copy.deepcopy(self.inventory())
        self.visit_event(cj.sid('COPYCATS_HOUSE_2F', 1))
        if self.inventory() != inventory:
            raise ProtocolError('Copycat repeated talk changed inventory')
        self.completed_steps.add('copycat-doll-tm31')
        self.checkpoint('copycat-earned-tm31')
        self.heal_here('SaffronPokecenter')
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
        destination = self.zone('Route12' if constant == 'ROUTE_12' else 'Route16')
        goal = (point[0] + self.models[destination].padding, point[1])
        self.travel(destination, goal=goal)
        self.source_waypoint(*point)
        self.require_event(cj.sid(constant, index))
        self.scripted_wild = dict(species='snorlax', level=30)
        self.use_item('pokeFlute')
        self.scripted_wild = None
        if not self.flag('EVENT_BEAT_' + constant.replace('_', '') + '_SNORLAX'):
            raise ProtocolError('actual source Snorlax battle did not remove blocker')
        self.refresh_world()

    def enter_route14_from_east(self):
        self.travel(self.zone('Route13'))
        self.source_waypoint(0, 10)
        self.cross('left', self.zone('Route14'), (19, 10))

    def finish_eastern_road_to_fuchsia(self):
        self.source_waypoint(0, 44)
        self.cross('left', self.zone('Route15'), (59, 8))
        self.warp(self.zone('Route15Gate1F'), event_id=self.zone('Route15') + ':warps:4')
        self.warp(self.zone('Route15'), event_id=self.zone('Route15Gate1F') + ':warps:2')
        self.source_waypoint(0, 8)
        self.cross('left', self.zone('FuchsiaCity'), (39, 16))

    def refill_after_route13(self):
        # Real return through already-traversed source roads; no repeat battles or XP farming.
        self.cross('right', self.zone('Route13'), (0, 10))
        self.source_waypoint(51, 0)
        self.cross('up', self.zone('Route12'), (11, 107))
        self.warp(self.zone('Route12Gate1F'), event_id=self.zone('Route12') + ':warps:3')
        self.warp(self.zone('Route12'), event_id=self.zone('Route12Gate1F') + ':warps:1')
        self.source_waypoint(9, 0)
        self.cross('up', self.zone('LavenderTown'), (9, 17))
        self.heal_here('LavenderPokecenter')
        self.restock('LavenderMart')
        self.completed_steps.add('route13-rested')
        self.save()

    def route_fuchsia(self):
        if 'fuchsia_gym' in self.completed_steps:
            if not self.flag('BADGE_SOUL') or not self.flag('EVENT_GOT_TM06') or self.quantity('tm06') < 1:
                raise ProtocolError('saved Koga progress lacks the actual badge and TM06')
            self.completed_steps.add('fuchsia-koga')
            self.safari_journey()
            return
        self.heal_here('LavenderPokecenter')
        if 'route12-snorlax' not in self.completed_steps:
            self.wake_snorlax('ROUTE_12', 1, (10, 61))
            self.completed_steps.add('route12-snorlax')
            self.save()
        self.restock('LavenderMart')
        self.enter_route14_from_east()
        if 'route13-rested' not in self.completed_steps:
            self.refill_after_route13()
            self.enter_route14_from_east()
        # Route14's northern y=6 arrival is blocked by its trainer; y=10 is open.
        self.finish_eastern_road_to_fuchsia()
        self.heal_here('FuchsiaPokecenter')
        self.leader('FUCHSIA_GYM', 'BADGE_SOUL', 'tm06', 'FuchsiaPokecenter', 'FuchsiaMart')
        self.completed_steps.add('fuchsia-koga')
        self.safari_journey()

    def safari_journey(self):
        self.safari_observation()
        self.prepared_safari_route()

    def prepared_safari_route(self):
        self.ensure_room('FuchsiaMart')
        # Fresh routes buy this before heading east. Older actual Koga Saves
        # use the same fixed source return road, never an unbounded map-name trip.
        if self.config['content_scope'] == 'critical' and self.quantity('escapeRope') == 0:
            self.return_from_fuchsia_to_route12()
            self.return_from_route12_to_lavender()
            self.restock('LavenderMart')
            if self.quantity('escapeRope') == 0:
                raise ProtocolError('Safari requires the earned Lavender Escape Rope before admission')
            self.enter_route14_from_east()
            self.finish_eastern_road_to_fuchsia()
            self.heal_here('FuchsiaPokecenter')
        # Retain real supplies and travel before paying the next admission fee.
        self.save()
        gate = cj.sid('SAFARI_ZONE_GATE', 1)
        self.require_event(gate)
        self.travel(self.zone('SafariZoneGate'))
        money = self.inventory()['money']
        before_step = self.safari_observation().get('lastStep', {}).get('sequence', 0)
        self.event_choices = {gate: 'YES'}
        try:
            # The source trigger is a completed cell, not worker interaction.
            self.source_waypoint(4, 3)
            self.send('press up', 'wait 2')
            self.await_value('event.id', gate)
            self.drain()
        finally:
            self.event_choices = {}
        admitted = self.safari_observation()
        receipt = admitted.get('lastPassage', {})
        if (receipt.get('kind') != 'admission' or receipt.get('ok') is not True
                or receipt.get('countedSteps') != 3 or receipt.get('moneyBefore') != money
                or receipt.get('moneyAfter') != money - 500 or self.inventory()['money'] != money - 500
                or not admitted.get('active') or admitted.get('steps') != 499
                or admitted.get('balls') != 30 or admitted.get('ending') != 'none'):
            raise ProtocolError('actual Safari admission did not commit fee 500 and source 499/30')
        self.require(zone_id=self.zone('SafariZoneCenter'),
                     **{'player.x': 15 + self.model().padding, 'player.y': 24})
        self.summary['safari_admission'] = copy.deepcopy(receipt)
        # Admission already arrived in Center. The fixed route starts here.
        for label in ('center-east', 'east-north', 'north-west', 'teeth'):
            self.fixed_leg('safari-fixed-routes.json', label)
        self.pickup(cj.sid('SAFARI_ZONE_WEST', 4), 'goldTeeth')
        if self.config['content_scope'] == 'optional' and not self.summary.get('safari_ball'):
            # Fixed source grass adjacent to the teeth approach. A finite
            # natural encounter attempt can fail honestly; there is no seeding.
            for _ in range(24):
                self.source_waypoint(19, 5)
                self.source_waypoint(19, 6)
                if self.summary.get('safari_ball'):
                    break
            else:
                raise ProtocolError('no natural Safari BALL opportunity within fixed grass bound')
        self.fixed_leg('safari-fixed-routes.json', 'secret-house')
        self.pickup(cj.sid('SAFARI_ZONE_SECRET_HOUSE', 1), 'hm03', 'EVENT_GOT_HM03')
        rewards = self.safari_observation()
        if not rewards.get('surfReceived') or not rewards.get('teethFound'):
            raise ProtocolError('actual source HM03/Gold Teeth rewards absent')
        if self.config['content_scope'] == 'optional':
            self.exhaust_safari_steps(before_step)
        else:
            self.warp(self.zone('SafariZoneWest'))
            before_rope = self.quantity('escapeRope')
            money = self.inventory()['money']
            self.use_item('escapeRope')
            exited = self.safari_observation()
            if (self.quantity('escapeRope') != before_rope - 1 or exited['active']
                    or exited['balls'] != 0 or self.inventory()['money'] != money):
                raise ProtocolError('actual source Forest Escape Rope did not exit Safari atomically')
            self.summary['safari_exit'] = dict(kind='escapeRope', resources=exited)
        self.heal_here('FuchsiaPokecenter')
        self.event_offer(cj.sid('WARDENS_HOUSE', 1))
        if not self.flag('EVENT_GOT_HM04') or self.quantity('hm04') < 1 or self.quantity('goldTeeth') != 0:
            raise ProtocolError('actual Gold Teeth/Strength transaction unavailable/incomplete')
        strength = self.teach('strength')
        self.travel(self.zone('WardensHouse'))
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
        self.ensure_surf_user()
        surf = self.teach('surf')
        self.travel(self.zone('FuchsiaGoodRodHouse'))
        self.fixed_warp(1, (2, 1))
        self.source_waypoint(29, 22)
        self.face('up')
        self.use_field(surf, 'surf')
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'surfing':
            raise ProtocolError('actual Fuchsia pond Surf did not enter water')
        self.send('press down', 'wait 10')
        self.drain()
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'walking':
            raise ProtocolError('actual Surf landing did not return to walking')
        self.completed_steps.add('safari-hm03-gold-teeth-hm04-strength-surf')
        self.save()

    def exhaust_safari_steps(self, admission_sequence):
        self.require(zone_id=self.zone('SafariZoneSecretHouse'))
        self.source_waypoint(2, 4)
        money = self.inventory()['money']
        rows = []
        # Both cells are source-passable, have no actors/warps/encounters, and
        # spend the live budget through completed Player cells only.
        for _ in range(501):
            before = self.safari_observation()
            if not before['active']:
                break
            previous = before.get('lastStep', {}).get('sequence', 0)
            direction = 'right' if self.position()[0] == 2 + self.model().padding else 'left'
            self.send('press ' + direction, 'wait 10')
            self.drain()
            after = self.safari_observation()
            step = after.get('lastStep', {})
            if (step.get('sequence') != previous + 1 or step['before']['steps'] != before['steps']
                    or step['after']['steps'] != max(0, before['steps'] - 1)):
                raise ProtocolError('Safari exhaustion lacks one actual completed-cell receipt')
            rows.append(copy.deepcopy(step))
            if not after['active']:
                passage = after.get('lastPassage', {})
                if (before['steps'] != 0 or step['after']['ending'] != 'steps'
                        or step['sequence'] - admission_sequence != 500
                        or passage.get('kind') != 'forced-return' or passage.get('ok') is not True
                        or passage['before']['ending'] != 'steps' or passage.get('countedSteps') != 3
                        or after['ending'] != 'none' or after['balls'] != 0
                        or self.inventory()['money'] != money):
                    raise ProtocolError('Safari actual 500-cell expiration/forced return differs')
                self.require(zone_id=self.zone('SafariZoneGate'),
                             **{'player.x': 3 + self.model().padding, 'player.y': 3})
                self.summary['safari_expiration'] = dict(cells=rows, passage=copy.deepcopy(passage),
                    ordinary_cells_since_admission=step['sequence'] - admission_sequence)
                return
        raise ProtocolError('Safari did not actually expire inside completed-cell bound')

    def ensure_surf_user(self):
        compatible = set(self.observe('midgame-owners')['hm_compatibility']['hm03'])
        def available():
            owner = self.collection_owner()
            specimens = list(owner['party']['members'])
            for box in sequence(owner['storage']['boxes'], 'PC boxes'):
                specimens.extend(sequence(box, 'PC box'))
            return any(mon['species'] in compatible for mon in specimens)
        if available():
            return
        self.ensure_room('FuchsiaMart')
        if not self.quantity('goodRod'):
            self.event_offer(cj.sid('FUCHSIA_GOOD_ROD_HOUSE', 1))
        clerk = cj.sid('FUCHSIA_MART', 1)
        self.travel(self.zone('FuchsiaMart'))
        price = self.vermilion['shops'][clerk]['prices']['greatBall']
        count = min(12, max(0, (self.inventory()['money'] - 1000) // price))
        if count:
            self.buy_item(clerk, 'greatBall', count, price)
        if not any(self.quantity(key) for key in ('pokeBall', 'greatBall', 'ultraBall')):
            raise ProtocolError('earned funds cannot supply a mandatory Surf user')
        self.travel(self.zone('FuchsiaGoodRodHouse'))
        self.fixed_warp(1, (2, 1))
        self.source_waypoint(29, 22)
        self.face('up')
        self.surf_acquisition = compatible
        self.surf_capture_throws = 0
        try:
            for _ in range(16):
                if available():
                    break
                self.use_item('goodRod')
            if not available():
                raise ProtocolError('bounded genuine fishing did not acquire a Surf-compatible Pokemon')
        finally:
            self.surf_acquisition = None
        self.heal_here('FuchsiaPokecenter')

    def return_from_fuchsia_to_route12(self):
        self.travel(self.zone('FuchsiaCity'), goal=(39, 16))
        self.cross('right', self.zone('Route15'), (0, 8))
        self.warp(self.zone('Route15Gate1F'), event_id=self.zone('Route15') + ':warps:2')
        self.warp(self.zone('Route15'), event_id=self.zone('Route15Gate1F') + ':warps:4')
        self.source_waypoint(59, 8)
        self.cross('right', self.zone('Route14'), (0, 44))
        self.source_waypoint(19, 10)
        self.cross('right', self.zone('Route13'), (0, 10))
        self.source_waypoint(51, 0)
        self.cross('up', self.zone('Route12'), (11, 107))

    def return_from_route12_to_lavender(self):
        self.warp(self.zone('Route12Gate1F'), event_id=self.zone('Route12') + ':warps:3')
        self.warp(self.zone('Route12'), event_id=self.zone('Route12Gate1F') + ':warps:1')
        self.source_waypoint(9, 0)
        self.cross('up', self.zone('LavenderTown'), (9, 17))

    def route_bicycle(self):
        # Approach the Bike Voucher/shop on the earned eastern route, avoiding
        # an unbraked Route 17 visit before Bicycle acquisition.
        if self.quantity('bicycle') == 0:
            self.return_from_fuchsia_to_route12()
            self.return_from_route12_to_lavender()
            if self.quantity('bikeVoucher') == 0:
                self.event_offer(cj.sid('POKEMON_FAN_CLUB', 5))
            self.event_offer(cj.sid('BIKE_SHOP', 1))
            self.heal_here('CeruleanPokecenter')
            self.save()
        if self.quantity('bicycle') != 1:
            raise ProtocolError('actual Bike Voucher exchange did not give Bicycle')
        if self.state['zone_id'] != self.zone('Route16'):
            self.travel(self.zone('CeladonCity'))
        if not self.flag('EVENT_BEAT_ROUTE16_SNORLAX'):
            self.wake_snorlax('ROUTE_16', 7, (27, 10))
        else:
            self.travel(self.zone('Route16'))
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'bicycle':
            self.use_item('bicycle')
        if self.observe('midgame-state')['fieldTravel']['mode'] != 'bicycle':
            raise ProtocolError('actual Bicycle field service unavailable')
        # A real Save before the road preserves the cleared Snorlax and bike,
        # rather than replaying the entire eastern approach after a UI failure.
        self.save()
        self.cycling_brake = True
        self.send('wait 1', 'hold b', 'wait 12')
        try:
            self.travel(self.zone('Route17'))
            before = dict(zone=self.state['zone_id'], position=self.position(),
                          travel=self.observe('midgame-state')['fieldTravel'])
            # Release with no direction for one input tick, then brake the
            # genuine automatic descent before ordinary planned travel resumes.
            self.send('release b', 'wait 1', 'hold b', 'wait 12')
            self.drain()
            after = dict(zone=self.state['zone_id'], position=self.position(),
                         travel=self.observe('midgame-state')['fieldTravel'])
            if (after['zone'] != before['zone'] or after['position'][0] != before['position'][0]
                    or after['position'][1] <= before['position'][1]
                    or after['travel']['mode'] != 'bicycle'):
                raise ProtocolError('Cycling Road did not show actual unsteered automatic descent')
            self.summary['cycling_descent'] = dict(before=before, after=after)
            for name in ('Route18', 'FuchsiaCity'):
                self.travel(self.zone(name))
        finally:
            self.cycling_brake = False
            self.send('release b', 'wait 2')
        self.completed_steps.add('bicycle-cycling-road')
        self.heal_here('FuchsiaPokecenter')
        self.save()

    def optional_b(self):
        # Keep Dojo, Saffron and Fly out of the B packet.
        self.ensure_room('FuchsiaMart')
        self.event_offer(cj.sid('FUCHSIA_GOOD_ROD_HOUSE', 1))
        self.return_from_fuchsia_to_route12()
        self.warp(self.zone('Route12SuperRodHouse'), event_id=self.zone('Route12') + ':warps:4')
        self.event_offer(cj.sid('ROUTE_12_SUPER_ROD_HOUSE', 1))
        self.warp(self.zone('Route12'), event_id=self.zone('Route12SuperRodHouse') + ':warps:1')
        self.source_waypoint(11, 107)
        self.cross('down', self.zone('Route13'), (51, 0))
        self.enter_route14_from_east()
        self.finish_eastern_road_to_fuchsia()
        if self.quantity('goodRod') < 1 or self.quantity('superRod') < 1:
            raise ProtocolError('actual rod rewards unavailable')
        for rod in ('oldRod', 'goodRod', 'superRod'):
            self.travel(self.zone('FuchsiaGoodRodHouse'))
            self.fixed_warp(1, (2, 1))
            self.source_waypoint(29, 22)
            self.face('up')
            attempt = dict(rod=rod, phases=[], inventory=copy.deepcopy(self.inventory()))
            self.fishing_attempt = attempt
            try:
                self.use_item(rod)
                result = self.observe('midgame-state')['fieldGear'].get('result', {})
                receipt = result.get('receipt', {})
                phases = {row['phase'] for row in attempt['phases']}
                if ('cast' not in phases or 'result' not in phases or result.get('item') != rod
                        or receipt.get('rod') != rod or receipt.get('map') != 'FUCHSIA_CITY'
                        or self.inventory() != attempt['inventory']):
                    raise ProtocolError('rod cast lacks actual phases/result or changed ordinary bag/money')
                if result.get('kind') == 'encounter':
                    if 'bite' not in phases or not attempt.get('battle') or receipt['response']['kind'] != 'bite':
                        raise ProtocolError('actual fishing bite did not open its natural battle')
                elif (result.get('kind') != 'no-bite' or attempt.get('battle')
                        or receipt.get('response', {}).get('kind') != result.get('kind')):
                    raise ProtocolError('unexpected actual fishing result: ' + str(result))
                attempt['result'] = copy.deepcopy(result)
                self.summary.setdefault('fishing', []).append(copy.deepcopy(attempt))
            finally:
                self.fishing_attempt = None
        self.completed_steps.add('rods-fishing')
        self.heal_here('FuchsiaPokecenter')
        self.save()

    def advance_travel(self):
        observed = self.observe('midgame-state')
        if self.state.get('root') != 'fieldTravel':
            return True
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
        result = super().battle(name, strategy, expected)
        if getattr(self, 'cycling_brake', False):
            self.cycling_brake_needs_rearm = True
        return result

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

    def store_unused_items(self, center):
        # Preserve completed quest items and unused TMs through the nearby item PC.
        self.heal_here(center)
        self.source_waypoint(13, 4)
        self.face('up')
        self.send('wait 1', 'press a', 'wait 2')
        self.require(root='pc', **{'pc.phase': 'top'})
        self.select('pc.menu.selected', 2)
        self.send('press a')
        self.require(root='itemPC', **{'item_pc.phase': 'menu'})
        self.select('item_pc.menu.selected', 2)
        self.send('press a')
        self.require(**{'item_pc.phase': 'list', 'item_pc.operation': 'deposit'})
        candidates = ('ssTicket', 'helixFossil', 'domeFossil', 'moonStone',
                      'tm34', 'tm11', 'tm28', 'tm24', 'coinCase', 'tm48', 'tm49', 'tm18', 'tm13',
                      'tm21', 'tm06', 'liftKey', 'silphScope', 'rareCandy')
        while len(self.inventory()['slots']) > 15:
            before = self.inventory()
            item = next((key for key in candidates if self.quantity(key) > 0), None)
            if item is None:
                raise ProtocolError('no unused item can be stored for Tower rewards')
            slots = before['slots']
            index = next(i for i, slot in enumerate(slots, 1) if slot['id'] == item)
            quantity = slots[index - 1]['quantity']
            stored = self.state['session']['item_storage']['slots']
            totals = {slot['id']: sum(row['quantity'] for row in stored if row['id'] == slot['id'])
                      for slot in stored}
            self.select('item_pc.selected', index)
            self.send('press a')
            if lookup(self.state, 'item_pc.phase') == 'quantity':
                for _ in range(quantity - 1):
                    self.send('press up')
                self.send('press a')
            self.require(**{'item_pc.phase': 'message', 'item_pc.result.ok': True})
            after = self.inventory()
            actual = self.state['session']['item_storage']['slots']
            actual_totals = {slot['id']: sum(row['quantity'] for row in actual if row['id'] == slot['id'])
                             for slot in actual}
            totals[item] = totals.get(item, 0) + quantity
            if (after['slots'] != slots[:index - 1] + slots[index:]
                    or after['money'] != before['money'] or actual_totals != totals):
                raise ProtocolError('item PC deposit did not conserve the exact earned stack')
            self.summary.setdefault('item_deposits', []).append(dict(item=item, quantity=quantity))
            self.send('press a')
            self.require(**{'item_pc.phase': 'list'})
        self.send('press b', 'press b', 'press b')
        self.require(root='overworld')

    def ensure_room(self, mart):
        # Make room before long dungeons through genuine retail or PC input.
        sellable = ('nugget', 'tm34', 'tm11', 'tm28', 'tm24')
        while len(self.inventory()['slots']) > 15:
            if any(self.quantity(item) > 0 for item in sellable):
                self.sell_old_item(mart)
            else:
                center = {'CeladonMart2F': 'CeladonPokecenter',
                          'FuchsiaMart': 'FuchsiaPokecenter',
                          'SaffronMart': 'SaffronPokecenter'}.get(mart, 'LavenderPokecenter')
                self.store_unused_items(center)


    def mansion_step_warp(self, index, destination):
        # Fixed source backstairs use the shared collision-checked arrival.
        event = next(e for e in self.model().events['warps'] if e['source_index'] == index)
        target = self.models[self.zone(destination)]
        declared = event['destination']
        if declared['kind'] == 'map' and declared['map'] != target.source_data['source_map_constant']:
            raise ProtocolError('fixed Mansion script differs from source warp')
        if declared['kind'] == 'last_outdoor_map' and self.model().descriptor['last_outdoor'] != destination:
            raise ProtocolError('fixed Mansion outdoor context differs')
        projected, (x, y) = self.project_warp(self.model(), event)
        if projected != target.name:
            raise ProtocolError('fixed Mansion projection differs from source destination')
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
