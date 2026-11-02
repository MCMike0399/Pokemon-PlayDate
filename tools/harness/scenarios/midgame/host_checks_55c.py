"""Host checks for packet isolation and accepted B C import; no game runtime."""
import copy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT))
from tools.harness import midgame_journey as driver
from tools.harness import restarting
from tools.harness.protocol import ProtocolError

DATA = Path(__file__).parent


def scenario(starter='bulbasaur', packet='5.5c'):
    prefix = 'restart-55c-' if packet == '5.5c' else 'restart-55b-' if packet == '5.5b' else 'restart-'
    return json.loads((DATA / (prefix + starter + '.json')).read_bytes())


class PacketBoundary(unittest.TestCase):
    def test_three_c_scenarios_and_unchanged_a_b_scenarios(self):
        for packet in ('5.5a', '5.5b', '5.5c'):
            for starter in ('bulbasaur', 'charmander', 'squirtle'):
                with self.subTest(packet=packet, starter=starter):
                    driver.validate_scenario(scenario(starter, packet))

    def test_c_rejects_a_save_and_a_b_packet_in_second_process(self):
        for change in ('ancestor', 'packet', 'scope', 'restart'):
            with self.subTest(change=change):
                value = scenario()
                if change == 'ancestor':
                    value['initial_save']['milestone'] = '5.5a'
                elif change == 'packet':
                    value['processes'][1]['journey']['packet'] = '5.5b'
                elif change == 'scope':
                    value['processes'][1]['journey']['content_scope'] = 'critical'
                else:
                    value['processes'][1]['restart'] = False
                with self.assertRaises(ProtocolError):
                    driver.validate_scenario(value)

    def test_c_never_accepts_fabricated_chain_records(self):
        for record in ({}, {'from_milestone': '5.5b', 'accepted_commit': '0' * 40}):
            with self.assertRaisesRegex(ProtocolError, 'accepted 5.5b manifest binding'):
                driver.validate_chain_record(record, dict(milestone='5.5b', starter='bulbasaur'), ROOT)

    def test_c_import_requires_the_real_manifest(self):
        # Nonexistent paths make any accidental file access fail the check.
        missing = ROOT / 'does-not-exist-c-host-boundary'
        with self.assertRaises(FileNotFoundError):
            restarting.import_chain_save(scenario(), missing, missing, missing)

    def test_budget_limits_remain_bounded(self):
        config = scenario()['processes'][0]['journey']
        for key, (_, high) in driver.BOUNDS.items():
            value = copy.deepcopy(config)
            value[key] = high + 1
            with self.subTest(key=key), self.assertRaises(ProtocolError):
                driver.validate_config(value)

    def test_c_dispatch_never_calls_a_b_or_legacy_phases(self):
        # Exercise actual packet selection with only phase bodies replaced.
        for starter in ('bulbasaur', 'charmander', 'squirtle'):
            owner = driver.MidgameJourney.__new__(driver.MidgameJourney)
            owner.config = scenario(starter)['processes'][0]['journey']
            owner.completed_steps, owner.summary = set(), {}
            calls = []
            names = ('route_c_guard', 'route_c_silph', 'route_c_sabrina', 'route_c_dojo', 'route_c_fly')
            expected = list(names) + (['optional_c_copycat'] if starter == 'bulbasaur' else [])
            patches = []
            for name in names + ('optional_c_copycat', 'route_tower', 'route_fuchsia', 'route_bicycle',
                                 'route_lavender', 'route_a', 'route_full', 'supplemental_services',
                                 'start_earned', 'save', 'write_receipt'):
                def action(name=name):
                    calls.append(name)
                action.__name__ = name
                patches.append(patch.object(owner, name, action))
            try:
                for item in patches:
                    item.start()
                owner.natural()
            finally:
                for item in reversed(patches):
                    item.stop()
            self.assertEqual(calls, ['start_earned'] + expected + ['save', 'write_receipt'])

    def test_full_selected_box_blocks_gift_before_any_input(self):
        owner = driver.MidgameJourney.__new__(driver.MidgameJourney)
        value = dict(party=dict(members=[dict(species='pidgey')] * 6),
                     storage=dict(active=2, boxes=[[], [dict(species='pidgey')] * 20]))
        with patch.object(owner, 'collection_owner', return_value=value), \
                patch.object(owner, 'flag', return_value=False), \
                patch.object(owner, 'event_offer') as offer:
            with self.assertRaisesRegex(ProtocolError, 'selected PC box is full'):
                owner.c_gift('pokered:SILPH_CO_7F:objects:1', 'lapras', 15, 'BIT_GOT_LAPRAS')
            offer.assert_not_called()


if __name__ == '__main__':
    unittest.main()
