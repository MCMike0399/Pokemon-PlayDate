#!/usr/bin/env python3
"""The Pewter Gym guide is on his tile and is not drawn.

pret/pokered af519899 PewterGym.asm places SPRITE_GYM_GUIDE at (7, 10),
facing down, between the entrance statues. The port's object, standing
grid, and catalog pose match that. The sprite is in the live NPC list
(pixel 256, 312, which is tile (8, 10) after the gym's one-cell pad).
pewter-jr.mp4 at the entrance shows the statues, the player, and the door,
and the floor cell beside the right statue is empty.

Spawn calls setImage before the camera snap. A STAY actor never calls
setImage again, and that first dirty rect is below the 240px screen while
the offset is still the previous map. Source/game/overworldState.lua is
shared, so the fix is tools/notes/lane-e-pewter-gym-guide.patch. This test
fails until that patch is in the shared file.
"""

import json
import unittest
from pathlib import Path

from tools.visual.event_art import raster

ROOT = Path(__file__).resolve().parents[2]
GYM = ROOT / "Source/data/pewterSlice/PewterGym.json"
SPRITES = ROOT / "Source/data/pewterSlice/sprites.json"
ENTER = ROOT / "Source/game/overworldState.lua"
PATCH = ROOT / "tools/notes/lane-e-pewter-gym-guide.patch"
POKERED = Path("/tmp/pokered/data/maps/objects/PewterGym.asm")


class PewterGymGuideTest(unittest.TestCase):
    def test_guide_art_and_tile_match_pokered(self):
        asm = POKERED.read_text(encoding="utf-8")
        self.assertIn(
            "object_event  7, 10, SPRITE_GYM_GUIDE, STAY, DOWN, TEXT_PEWTERGYM_GYM_GUIDE",
            asm,
        )
        gym = json.loads(GYM.read_text(encoding="utf-8"))
        guide = next(obj for obj in gym["events"]["objects"] if obj["sprite"] == "SPRITE_GYM_GUIDE")
        self.assertEqual((guide["x"], guide["y"], guide["movement"], guide["range_or_facing"]),
                         (7, 10, "STAY", "DOWN"))
        sprites = json.loads(SPRITES.read_text(encoding="utf-8"))
        strip = sprites["sprites"]["gym_guide"]
        frame = strip["standing"]["down"]
        image = raster(strip["frames"][str(frame)])
        opaque = sum(1 for pixel in image.getdata() if pixel[3])
        self.assertGreater(opaque, 32)

    def test_other_stay_actors_spawn_off_the_origin_screen(self):
        # NPC:init calls setImage before OverworldState snaps the camera.
        # NPCMotion:tick calls setImage again only for random walkers, and
        # that call is still before camera:apply. A STAY actor never moves,
        # so any sprite whose top is outside the 400 by 240 origin screen
        # keeps the same missed dirty rect as the Pewter guide.
        off = []
        for path in (ROOT / "Source/data").rglob("*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            events = data.get("events") if isinstance(data, dict) else None
            objects = events.get("objects") if isinstance(events, dict) else None
            if not isinstance(objects, list):
                continue
            for obj in objects:
                if not isinstance(obj, dict) or obj.get("movement") != "STAY":
                    continue
                x, y = obj.get("x"), obj.get("y")
                if not isinstance(x, int) or not isinstance(y, int):
                    continue
                if y * 32 - 8 >= 240 or x * 32 >= 400:
                    off.append((path.name, obj.get("sprite")))
        self.assertIn(("PewterGym.json", "SPRITE_GYM_GUIDE"), off)
        self.assertIn(("CeruleanGym.json", "SPRITE_GYM_GUIDE"), off)
        self.assertIn(("ViridianGym.json", "SPRITE_GYM_GUIDE"), off)
        self.assertGreater(len(off), 1)

    def test_enter_redraws_stay_actors_after_the_camera_snap(self):
        source = ENTER.read_text(encoding="utf-8")
        patch = PATCH.read_text(encoding="utf-8")
        enter = source.split("function OverworldState:enter", 1)[1].split("\nfunction ", 1)[0]
        self.assertIn("npc:markDirty()", patch)
        snap = enter.index("game.camera:snapTo")
        dirty = enter.index("gfx.sprite.addDirtyRect")
        self.assertIn(
            "npc:markDirty()",
            enter[snap:dirty],
            "Mark STAY actors dirty after the camera snap. The Pewter Gym guide "
            "is spawned below the screen and never setImage'd again. "
            "Apply tools/notes/lane-e-pewter-gym-guide.patch",
        )
        self.assertLess(enter.index("game.camera:apply()"), enter.index("npc:markDirty()"))
        self.assertIn("for _, npc in ipairs(game.npcManager.npcs)", enter[snap:dirty])


if __name__ == "__main__":
    unittest.main()
