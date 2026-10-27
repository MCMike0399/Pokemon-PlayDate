"""Host call-boundary regressions; supplied owner packets are not an SDK model."""
import copy
import unittest
from unittest.mock import Mock, patch

from tools.harness import cerulean_journey as cj
from tools.harness.brock_journey import BrockJourney, NaturalBlackout
from tools.harness.protocol import ProtocolError


class ResourcesTests(unittest.TestCase):
    def driver(self, **config):
        driver = cj.CeruleanJourney(Mock(), '/unused', dict(name='cerulean-natural', **config))
        driver.stage = 'cerulean'
        return driver

    def test_natural_restores_and_restocks_between_rival_bridge_and_route25(self):
        driver = self.driver()
        calls = []
        driver.zone = lambda name: name
        driver.source_trainers = {}
        driver.models = {'MtMoonB2F': type('Geometry', (), {'padding': 0})()}
        driver.scenes = {'fossil_trigger': {'x': 1, 'y': 1}}
        driver.travel = lambda zone, *args: calls.append(('travel', zone))
        driver.fight = lambda trainer: calls.append(('fight', trainer))
        driver.heal_here = lambda zone: calls.append(('heal', zone))
        driver.stock_up = lambda zone: calls.append(('stock', zone))
        driver.defeated = lambda trainer: True
        driver.summary['source_receipts'] = [{'trainer_id': cj.NERD, 'won': True}]
        driver.flag = lambda flag: True
        driver.quantity = lambda item: 1
        for name in ('reward', 'fossil_exclusion', 'checkpoint', 'repeat_trainer',
                     'bill_scene', 'interact', 'save', 'write_receipt'):
            setattr(driver, name, Mock())
        with patch.object(BrockJourney, 'natural'):
            driver.natural()
        rival = calls.index(('fight', cj.BRIDGE_RIVAL))
        bridge = calls.index(('fight', cj.sid('ROUTE_24', 6)))
        rocket = calls.index(('fight', cj.NUGGET))
        route25 = calls.index(('travel', 'Route25'))
        for segment in (calls[rival + 1:bridge], calls[rocket + 1:route25]):
            self.assertIn(('heal', 'CeruleanPokecenter'), segment)
            self.assertIn(('stock', 'CeruleanMart'), segment)

    def test_stock_uses_observed_money_quantities_and_pinned_prices(self):
        driver = self.driver()
        driver.zone = lambda name: 'mart'
        stock = {'antidote': 0, 'potion': 2}
        money = [1000]
        driver.export = {'shops': {'mart:objects:1': {
            'stock': ['potion', 'antidote'], 'prices': {'potion': 300, 'antidote': 100}}}}
        driver.quantity = lambda item: stock[item]
        driver.inventory = lambda: {'money': money[0]}
        driver.travel = Mock()
        purchases = []
        def buy(clerk, item, count, price):
            purchases.append((item, count, price))
            stock[item] += count
            money[0] -= count * price
        driver.buy_item = buy
        driver.stock_up('CeruleanMart')
        self.assertEqual(purchases, [('antidote', 3, 100), ('potion', 2, 300)])
        self.assertEqual(money[0], 100)

    def test_center_requires_real_confirmation_and_complete_restoration(self):
        for incomplete in (None, 'hp', 'status', 'pp'):
            with self.subTest(incomplete=incomplete):
                driver = self.driver()
                driver.zone = lambda name: 'center'
                driver.travel = Mock()
                driver.interact = Mock()
                driver.select = Mock()
                driver.send = Mock()
                driver.drain = Mock()
                mon = {'hp': 73, 'maxHP': 73, 'status': 'none',
                       'pp': {'bite': 25, 'waterGun': 25}, 'maxPP': {'bite': 25, 'waterGun': 25}}
                if incomplete == 'hp':
                    mon['hp'] = 1
                elif incomplete == 'status':
                    mon['status'] = 'poison'
                elif incomplete == 'pp':
                    mon['pp']['waterGun'] = 0
                driver.party = lambda: [mon]
                driver.state = {'session': {'checkpoint': {'zone_id': 'city-door'}}}
                if incomplete:
                    with self.assertRaisesRegex(ProtocolError, 'restoration incomplete'):
                        driver.heal_here('CeruleanPokecenter')
                else:
                    driver.heal_here('CeruleanPokecenter')
                    driver.interact.assert_called_once_with(source_id='center:objects:1', stop_phase='heal-confirm')
                    driver.select.assert_called_once_with('event.menu.selected', 1)
                    driver.send.assert_called_once_with('press a')
                    driver.drain.assert_called_once_with()

    def test_purchases_fail_on_missing_pinned_stock_or_prices(self):
        for shop in ({'stock': ['potion'], 'prices': {'potion': 300}},
                     {'stock': ['antidote', 'potion'], 'prices': {'antidote': 0, 'potion': 300}}):
            driver = self.driver()
            driver.zone = lambda name: 'mart'
            driver.export = {'shops': {'mart:objects:1': shop}}
            driver.travel = Mock()
            with self.assertRaisesRegex(ProtocolError, 'stock/price'):
                driver.stock_up('CeruleanMart')
            driver.travel.assert_not_called()

    def recovered_driver(self, **config):
        driver = self.driver(**config)
        checkpoint = {'zone_id': 'center-door', 'x': 19, 'y': 18, 'facing': 'down'}
        party = [{'species': 'wartortle', 'level': 25, 'hp': 73, 'maxHP': 73,
                  'status': 'none', 'pp': {'bite': 25}, 'maxPP': {'bite': 25}}]
        driver.state = {'zone_id': 'center-door', 'player': {'x': 19, 'y': 18},
                        'session': {'checkpoint': checkpoint, 'flags': {'trainers': {'finished': True}},
                                    'party': {'members': party}, 'inventory': {'money': 3387, 'slots': [{'id': 'nugget', 'quantity': 1}]}}}
        outcome = {'trainer_id': 'lost', 'blackout': True, 'won': False,
                   'kind': 'defeat', 'money_delta': -3388, 'payout': 0}
        driver.state['last_battle_outcome'] = outcome
        driver.source_trainers = {'lost': {'map_id': 'route'}}
        driver.summary['battles'] = [{'trainer_id': 'lost', 'money_before': 6775, 'outcome': outcome}]
        driver.checkpoint = Mock()
        driver.codec_guard = Mock()
        return driver

    def test_travel_replans_from_actual_checkpoint_after_sight_loss(self):
        driver = self.recovered_driver(max_blackouts=1)
        checkpoint_state = copy.deepcopy(driver.state)
        driver.state = dict(driver.state, zone_id='route', player={'x': 2, 'y': 3})
        starts = []
        traversals = []
        def portal(target, goal):
            if driver.state['zone_id'] == 'center-door':
                return (19, 18), 'warp', {'id': 'real-exit'}, ('route', (0, 0))
            return None
        def navigate(goal):
            starts.append(driver.state['zone_id'])
            if len(starts) == 1:
                driver.state = copy.deepcopy(checkpoint_state)  # observed terminal return packet
                raise NaturalBlackout('actual sight trainer loss')
        def warp(target, event_id):
            traversals.append((driver.state['zone_id'], target, event_id))
            driver.state = dict(driver.state, zone_id='route', player={'x': 0, 'y': 0})
        driver.route_portal = portal
        driver.navigate = navigate
        driver.warp = warp
        driver.travel('route', (2, 3))
        self.assertEqual(starts, ['route', 'route'])
        self.assertEqual(traversals, [('center-door', 'route', 'real-exit')])
        self.assertEqual(driver.blackouts, 1)
        self.assertEqual(driver.state['session'], checkpoint_state['session'])
        self.assertEqual(driver.summary['blackouts'][0]['money'], 3387)

    def test_fight_retries_interaction_via_travel_without_replaying_finished_rewards(self):
        driver = self.recovered_driver(max_blackouts=1)
        driver.models = {'route': type('Geometry', (), {
            'events': {'objects': [{'id': 'lost', 'x': 2, 'y': 3}]},
            'approaches': lambda self, point: {(2, 4): 'up'}})()}
        driver.travel = Mock()
        attempts = []
        def interact(**kwargs):
            attempts.append(kwargs)
            if len(attempts) == 1:
                raise NaturalBlackout('actual interaction trainer loss')
            driver.state['session']['flags']['trainers']['lost'] = True
            driver.summary['source_receipts'].append({'trainer_id': 'lost', 'won': True})
        driver.interact = interact
        driver.summary['rewards'] = [{'item': 'nugget', 'quantity': 1}]
        driver.fight('lost')
        self.assertEqual(driver.travel.call_count, 2)
        self.assertEqual(len(attempts), 2)
        self.assertTrue(driver.defeated('finished'))
        self.assertEqual(driver.summary['rewards'], [{'item': 'nugget', 'quantity': 1}])

    def test_travel_honors_zero_blackout_budget_and_bad_half_money(self):
        for options in ({'max_blackouts': 0}, {'max_blackouts': 1}):
            driver = self.recovered_driver(**options)
            if options['max_blackouts']:
                driver.state['session']['inventory']['money'] = 6775
            driver.route_portal = Mock(return_value=None)
            driver.navigate = Mock(side_effect=NaturalBlackout('loss'))
            with self.assertRaises(ProtocolError):
                driver.travel('route', (2, 3))
            self.assertEqual(driver.navigate.call_count, 1)

    def test_loss_receipt_survives_base_battle_exception(self):
        driver = self.recovered_driver()
        definition = {'party': [{'species': 'oddish', 'level': 13}], 'payout': 195}
        driver.source_trainers['lost'] = definition
        driver.state['battle'] = {'trainerName': 'JUNIOR TRAINER'}
        driver.state['event'] = {'id': 'lost', 'trainer': {'definition': dict(id='lost', **definition)}}
        with patch.object(BrockJourney, 'battle', side_effect=NaturalBlackout('terminal loss')):
            with self.assertRaises(NaturalBlackout):
                driver.battle('source-trainer', expected='win')
        self.assertEqual(driver.summary['source_receipts'], [driver.state['last_battle_outcome']])
        self.assertFalse(driver.summary['source_receipts'][0]['won'])

    def test_wild_run_blackout_uses_real_penalty_and_existing_recovery_checks(self):
        driver = self.recovered_driver()
        driver.state['last_battle_outcome']['trainer_id'] = None
        driver.summary['battles'] = []
        driver.state['session']['inventory']['money'] = 6775
        def run_loss():
            driver.state['session']['inventory']['money'] = 3387
            raise ProtocolError('natural parcel walk interrupted by real blackout')
        with patch.object(BrockJourney, 'flee', side_effect=run_loss):
            with self.assertRaises(NaturalBlackout):
                driver.flee()
        driver.recover_blackout()
        self.assertEqual(driver.blackouts, 1)
        self.assertEqual(driver.summary['blackouts'][0]['money'], 3387)
        with patch.object(BrockJourney, 'flee', side_effect=ProtocolError('unrelated failure')):
            with self.assertRaisesRegex(ProtocolError, 'unrelated failure'):
                driver.flee()
        self.assertEqual(len(driver.summary['battles']), 1)

    def test_repeated_loss_exhausts_global_budget_and_transition_bound(self):
        for options in ({'max_blackouts': 1}, {'max_blackouts': 2, 'max_transitions': 1}):
            driver = self.recovered_driver(**options)
            driver.route_portal = Mock(return_value=None)
            driver.navigate = Mock(side_effect=NaturalBlackout('loss'))
            with self.assertRaisesRegex(ProtocolError, 'budget exhausted|recovery exhausted'):
                driver.travel('route', (2, 3))
            self.assertEqual(driver.blackouts, 1)

    def test_stock_rechecks_money_after_actual_travel_penalty(self):
        driver = self.driver()
        driver.zone = lambda name: 'mart'
        driver.export = {'shops': {'mart:objects:1': {
            'stock': ['potion', 'antidote'], 'prices': {'potion': 300, 'antidote': 100}}}}
        money = [600]
        driver.quantity = lambda item: 3 if item == 'antidote' else 0
        driver.inventory = lambda: {'money': money[0]}
        driver.travel = lambda zone: money.__setitem__(0, 300)
        driver.buy_item = Mock()
        driver.stock_up('CeruleanMart')
        driver.buy_item.assert_called_once_with('mart:objects:1', 'potion', 1, 300)


if __name__ == '__main__':
    unittest.main()
