"""Host source-pose qualification; no SDK/runtime invocation."""
import copy
import hashlib
import json
import shutil
import tempfile
from pathlib import Path
import unittest

from PIL import Image
from tools.harness.brock_capture import qualify
from tools.harness.protocol import ProtocolError
from tools.visual.event_art import raster
from tools.harness.motion_journey import verify_rendered_poses

# Current fixtures exercise immutable source data and loader mutations. The old
# fixed-request replay belonged to a superseded multi-gigabyte failed journey.
REPO = Path(__file__).resolve().parents[2]


class SourcePoseTests(unittest.TestCase):
    def stage(self, root, name='Route25', package='sourceSlice', event_index=0):
        root = Path(root)
        manifest = json.loads((REPO / 'Source/data/sourceMaps.json').read_text())
        entry = manifest['maps'][name]
        paths = ['data/sourceMaps.json', entry['path'], f'data/{package}/sprites.json']
        hashes = {}
        for relative in paths:
            target = root / 'Source' / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(REPO / 'Source' / relative, target)
            hashes[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
        (root / 'source-manifest.json').write_text(json.dumps(hashes))
        definition = json.loads((root / 'Source' / entry['path']).read_text())
        event = definition['events']['objects'][event_index]
        sprites = json.loads((root / 'Source' / paths[-1]).read_text())
        key = event['sprite']
        if package == 'pewterSlice':
            key = sprites['mapping'][key]['name']
        elif package == 'viridianSlice':
            key = key.removeprefix('SPRITE_').lower()
        strip = sprites['sprites'][key]
        state = {'zone_id': entry['id'], 'zone': entry['key'], 'camera': {'x': 0, 'y': 16},
                 'npcs': [{'source_event_id': event['id'], 'pixel_x': 160, 'pixel_y': 104,
                           'facing': 'down', 'motion': {'phase': 'static', 'tick': 0}}]}
        return root, root / 'world.png', state, strip

    def paint(self, png, strip, direction='down', frame=0, flip=False):
        sprite = raster(strip['frames'][str(frame)])
        if flip:
            sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        image = Image.new('RGBA', (400, 240), 'white')
        image.alpha_composite(sprite, (160, 88))
        image.save(png)
        return image, sprite

    def repin(self, root, relative, data):
        path = root / 'Source' / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))
        manifest = json.loads((root / 'source-manifest.json').read_text())
        manifest[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        (root / 'source-manifest.json').write_text(json.dumps(manifest))

    def test_original_imported_maps_keep_exact_standing_schema(self):
        manifest = json.loads((REPO / 'Source/data/sourceMaps.json').read_text())
        original = [(name, entry) for name, entry in manifest['maps'].items()
                    if entry['profile'] in ('viridian', 'pewter')]
        # The original thirteen include authored Pallet, outside this source proof.
        self.assertEqual(len(original), 12)
        for name, entry in original:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                root, png, state, strip = self.stage(folder, name, entry['profile'] + 'Slice')
                frame = strip['standing']['down']
                self.paint(png, strip, frame=frame)
                proof = verify_rendered_poses(root, png, state)['actors'][0]
                self.assertEqual(proof['source_frame'], frame)
                self.assertGreater(proof['opaque_pixels_checked'], 32)

    def test_source_eight_ticks_all_directions_frames_flips_and_masks(self):
        with tempfile.TemporaryDirectory() as folder:
            root, png, state, strip = self.stage(folder)
            npc = state['npcs'][0]
            for direction in ('down', 'up', 'left', 'right'):
                for tick in range(1, 9):
                    with self.subTest(direction=direction, tick=tick):
                        pose = {2: 'walk', 3: 'walk', 6: 'alternate', 7: 'alternate'}.get(tick, 'stand')
                        frame = strip['standing' if pose == 'stand' else 'walking']['left' if direction == 'right' else direction]
                        flip = direction == 'right' or pose == 'alternate' and direction in ('up', 'down')
                        npc.update(facing=direction, motion={'phase': 'moving', 'tick': tick})
                        image, sprite = self.paint(png, strip, direction, frame, flip)
                        proof = verify_rendered_poses(root, png, state)['actors'][0]
                        self.assertEqual((proof['pose'], proof['source_frame'], proof['flip_x']), (pose, frame, flip))
                        x, y = next((x, y) for y in range(32) for x in range(32) if sprite.getpixel((x, y))[3] == 255)
                        pixel = image.getpixel((160+x, 88+y))
                        image.putpixel((160+x, 88+y), (255-pixel[0],)*3 + (255,))
                        image.save(png)
                        with self.assertRaisesRegex(ProtocolError, 'source pose mismatch'):
                            verify_rendered_poses(root, png, state)

    def test_manifest_and_definition_pins_and_identity_fail_closed(self):
        for mutation in ('manifest-drift', 'map-drift', 'sprite-drift', 'missing-map-pin',
                         'missing-map-file', 'unknown-zone', 'duplicate-id', 'wrong-key',
                         'wrong-decoded-id', 'wrong-source-pin', 'unsafe-path', 'wrong-profile', 'wrong-revision'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as folder:
                root, png, state, strip = self.stage(folder)
                self.paint(png, strip)
                manifest = json.loads((root / 'Source/data/sourceMaps.json').read_text())
                entry = manifest['maps']['Route25']
                if mutation.endswith('-drift'):
                    relative = {'manifest-drift': 'data/sourceMaps.json', 'map-drift': entry['path'],
                                'sprite-drift': 'data/sourceSlice/sprites.json'}[mutation]
                    path = root / 'Source' / relative
                    path.write_bytes(path.read_bytes() + b'\n')
                elif mutation == 'missing-map-pin':
                    hashes = json.loads((root / 'source-manifest.json').read_text())
                    del hashes[entry['path']]
                    (root / 'source-manifest.json').write_text(json.dumps(hashes))
                elif mutation == 'missing-map-file':
                    (root / 'Source' / entry['path']).unlink()
                elif mutation == 'unknown-zone':
                    state['zone_id'] = 'pokered:NOT_A_MAP'
                elif mutation == 'wrong-key':
                    state['zone'] = 'arbitrary_zone'
                elif mutation == 'wrong-decoded-id':
                    definition = json.loads((root / 'Source' / entry['path']).read_text())
                    definition['id'] = 'pokered:OTHER'
                    self.repin(root, entry['path'], definition)
                    entry['source_sha256'] = hashlib.sha256((root/'Source'/entry['path']).read_bytes()).hexdigest()
                    self.repin(root, 'data/sourceMaps.json', manifest)
                else:
                    if mutation == 'duplicate-id':
                        manifest['maps']['duplicate'] = copy.deepcopy(entry)
                    elif mutation == 'wrong-source-pin':
                        entry['source_sha256'] = '0' * 64
                    elif mutation == 'unsafe-path':
                        entry['path'] = '../outside.json'
                    elif mutation == 'wrong-profile':
                        entry['profile'] = 'anything'
                    elif mutation == 'wrong-revision':
                        manifest['source_revision'] = 'unqualified'
                    self.repin(root, 'data/sourceMaps.json', manifest)
                with self.assertRaises(ProtocolError):
                    verify_rendered_poses(root, png, state)

    def test_wrong_frame_missing_identity_and_visibility_still_fail(self):
        with tempfile.TemporaryDirectory() as folder:
            root, png, state, strip = self.stage(folder)
            npc = state['npcs'][0]
            npc['motion'] = {'phase': 'moving', 'tick': 2}
            self.paint(png, strip, frame=strip['standing']['down'])
            with self.assertRaisesRegex(ProtocolError, 'source pose mismatch'):
                verify_rendered_poses(root, png, state)
            self.paint(png, strip, frame=strip['walking']['down'])
            original = npc['source_event_id']
            npc['source_event_id'] += '-wrong'
            with self.assertRaisesRegex(ProtocolError, 'source identity missing'):
                verify_rendered_poses(root, png, state)
            del npc['source_event_id']
            with self.assertRaisesRegex(ProtocolError, 'source identity missing'):
                verify_rendered_poses(root, png, state)
            npc['source_event_id'] = original
            npc['pixel_x'] = -100
            with self.assertRaisesRegex(ProtocolError, 'not sufficiently visible'):
                verify_rendered_poses(root, png, state)

    def test_additive_keyed_package_and_duplicate_conflict(self):
        with tempfile.TemporaryDirectory() as folder:
            root, png, state, strip = self.stage(folder)
            relative = 'data/sourceSlice/sprites.json'
            source = json.loads((root / 'Source' / relative).read_text())
            sprite = 'SPRITE_YOUNGSTER'
            extra = {**source, 'sprites': {sprite: source['sprites'].pop(sprite)}}
            self.repin(root, relative, source)
            self.repin(root, 'data/vermilionPreparation/sprites.json', extra)
            self.paint(png, strip)
            self.assertTrue(verify_rendered_poses(root, png, state)['actors'])
            source['sprites'][sprite] = copy.deepcopy(extra['sprites'][sprite])
            self.repin(root, relative, source)
            self.assertTrue(verify_rendered_poses(root, png, state)['actors'])
            source['sprites'][sprite]['standing']['down'] = 1
            self.repin(root, relative, source)
            with self.assertRaisesRegex(ProtocolError, 'conflicting immutable'):
                verify_rendered_poses(root, png, state)

    def test_blue_policy_fails_with_scope(self):
        with tempfile.TemporaryDirectory() as folder:
            root, png, state, strip = self.stage(folder)
            self.paint(png, strip)
            manifest = json.loads((root / 'Source/data/sourceMaps.json').read_text())
            path = manifest['maps']['Route25']['path']
            definition = json.loads((root / 'Source' / path).read_text())
            definition['events']['objects'][0]['sprite'] = 'SPRITE_BLUE'
            self.repin(root, path, definition)
            manifest['maps']['Route25']['source_sha256'] = hashlib.sha256((root/'Source'/path).read_bytes()).hexdigest()
            self.repin(root, 'data/sourceMaps.json', manifest)
            for tick in (0, 2, 6):
                state['npcs'][0]['motion'] = {'phase': 'moving' if tick else 'static', 'tick': tick}
                with self.assertRaisesRegex(ProtocolError, 'SPRITE_BLUE .*protected greyhair/legacy-omitted.*ROUTE_25:objects:1'):
                    verify_rendered_poses(root, png, state)

    def test_missing_direction_frame_package_and_invalid_ticks_fail_closed(self):
        for mutation in ('direction', 'frame', 'package', 'tick-zero', 'tick-nine'):
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as folder:
                root, png, state, strip = self.stage(folder)
                self.paint(png, strip)
                state['npcs'][0]['motion'] = {'phase': 'moving', 'tick': 2}
                relative = 'data/sourceSlice/sprites.json'
                data = json.loads((root / 'Source' / relative).read_text())
                selected = data['sprites']['SPRITE_YOUNGSTER']
                if mutation == 'direction':
                    del selected['walking']['down']
                elif mutation == 'frame':
                    del selected['frames']['3']
                elif mutation == 'package':
                    data['sprites'].clear()
                else:
                    state['npcs'][0]['motion']['tick'] = 0 if mutation == 'tick-zero' else 9
                self.repin(root, relative, data)
                with self.assertRaises(ProtocolError):
                    verify_rendered_poses(root, png, state)

    def test_fixed_stand_retains_down_frame_without_flip(self):
        # Fixed original strip ignores facing; it never invents a walk frame.
        with tempfile.TemporaryDirectory() as folder:
            root, png, state, strip = self.stage(folder, 'Route25', event_index=9)
            self.assertTrue(strip['fixed'])
            self.paint(png, strip)
            state['npcs'][0]['facing'] = 'right'
            proof = verify_rendered_poses(root, png, state)['actors'][0]
            self.assertEqual(proof['source_frame'], 0)
            self.assertFalse(proof['flip_x'])
