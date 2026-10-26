"""Independent primary-source/data checks. Lua execution belongs to the SDK."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from tools.generate_daycare import ROOT, REFERENCE, REVISION, build, sources


class DaycarePreparationTests(unittest.TestCase):
    def test_checked_generation_is_exact(self):
        self.assertEqual((ROOT / 'Source/data/daycare/policy.json').read_bytes(), build())

    def test_pins_equal_primary_git_bytes(self):
        reference = Path(os.environ['POKERED_REFERENCE_DIR'])
        pin = json.loads((REFERENCE / 'manifest.json').read_text())
        self.assertEqual(pin['revision'], REVISION)
        for name, digest in pin['files'].items():
            raw = subprocess.check_output(['git', '-C', str(reference), 'show', REVISION + ':' + name])
            self.assertEqual(hashlib.sha256(raw).hexdigest(), digest, name)
            self.assertEqual((REFERENCE / name).read_bytes(), raw, name)

    def test_modified_pin_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'pins'
            shutil.copytree(REFERENCE, target)
            path = target / 'engine/overworld/daycare_exp.asm'
            path.write_bytes(path.read_bytes().replace(b'inc [hl]', b'dec [hl]', 1))
            with self.assertRaisesRegex(ValueError, 'unverified Day Care source'):
                build(target)

    def test_original_single_slot_guards_and_payment_order(self):
        script = sources()['scripts/Daycare.asm']
        self.assertIn('ld a, [wDayCareInUse]', script)
        self.assertIn('ld a, [wPartyCount]\n\tdec a', script)
        self.assertLess(script.index('callfar KnowsHMMove'), script.index('ld a, PARTY_TO_DAYCARE'))
        self.assertLess(script.index('cp PARTY_LENGTH'), script.index('.calcPriceLoop'))
        self.assertLess(script.index('call HasEnoughMoney'), script.index('predef SubBCDPredef'))
        self.assertLess(script.index('predef SubBCDPredef'), script.index('ld a, DAYCARE_TO_PARTY'))
        self.assertIn('ld [wDayCareMonBoxLevel], a', script[script.index('.leaveMonInDayCare\n'):])

    def test_source_learning_is_crossed_levels_fifo_without_evolution(self):
        src = sources()
        script = src['scripts/Daycare.asm']
        learning = src['engine/pokemon/evos_moves.asm'].split('WriteMonMoves:', 1)[1]
        self.assertIn('jr nc, .nextMove2 ; min level >= move level', learning)
        self.assertIn('shift all moves one up (deleting move 1)', learning)
        self.assertIn('shift PP as well if learning moves from day care', learning)
        self.assertNotIn('EvolvePokemon', script)
        self.assertIn('; set mon\'s HP to max', script)

    def test_step_xp_precedes_four_step_poison_gate_and_excludes_scripted_movement(self):
        poison = sources()['engine/events/poison.asm']
        self.assertLess(poison.index('jp c, .noBlackOut'), poison.index('call IncrementDayCareMonExp'))
        self.assertLess(poison.index('call IncrementDayCareMonExp'), poison.index('and $3'))
        step = sources()['engine/overworld/daycare_exp.asm']
        self.assertIn('ld hl, wDayCareMonExp + 2\n\tinc [hl]', step)

    def test_descriptor_uses_prepared_identity_and_every_original_text(self):
        output = json.loads(build())
        self.assertEqual(list(output['events']), ['pokered:DAYCARE:objects:1'])
        self.assertEqual(len(output['labels']), 15)
        self.assertEqual(output['hm_moves'], ['cut', 'fly', 'surf', 'strength', 'flash'])
        src = sources()
        labels = []
        for name in ['text/Daycare.asm', 'text/Daycare_2.asm']:
            labels.extend(line.removesuffix('::') for line in src[name].splitlines() if line.endswith('::'))
        self.assertEqual(sorted(labels), output['labels'])

    def test_original_text_recipes_equal_prepared_resource(self):
        from tools.generate_vermilion_preparation import text_recipes
        from tools.generate_cerulean_content import blue_source
        prepared = json.loads((ROOT / 'Source/data/vermilionPreparation/dialogue.json').read_text())
        for name in ['text/Daycare.asm', 'text/Daycare_2.asm']:
            for label, recipe in text_recipes(blue_source(sources()[name])).items():
                self.assertEqual(prepared['texts'][label]['source'], name)
                self.assertEqual(prepared['texts'][label]['recipe'], recipe)

    def test_root_api_patch_applies_without_touching_checkout(self):
        # Real git checks patch context on independent copies of exactly the
        # shared files. This does not execute or translate any Lua.
        patch = ROOT / 'tools/integration/daycare-api.patch'
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary)
            subprocess.run(['git', 'init', '-q', str(stage)], check=True)
            for name in ['Source/domain/gameSession.lua', 'Source/domain/sessionCodec.lua', 'Source/game/overworldState.lua']:
                target = stage / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(subprocess.check_output(['git', 'show', '2a207be:' + name], cwd=ROOT))
            subprocess.run(['git', 'apply', '--check', str(patch)], cwd=stage, check=True)
            subprocess.run(['git', 'apply', str(patch)], cwd=stage, check=True)
            codec = (stage / 'Source/domain/sessionCodec.lua').read_text()
            self.assertIn('data.daycare = Daycare.toData(session, unique)', codec)
            self.assertIn('Daycare.normalize(daycareRecord, checkMon)', codec)
            self.assertIn('SessionCodec={VERSION=3,', codec)
            self.assertIn('fieldWorld=session:fieldWorldData()', codec)
            self.assertIn('GameSession._location(deps,data.location,world,true)', codec)
            self.assertIn('GameSession._location(deps,data.checkpoint,world)', codec)
            self.assertIn('Daycare.restore(session, prepared.daycare', codec)


if __name__ == '__main__':
    unittest.main()
