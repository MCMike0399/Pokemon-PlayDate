import json
import os
from pathlib import Path
import tempfile
import unittest

from tools.harness.parcel_journey import Geometry, ParcelJourney, NAMES, ProtocolError, load_geometry, offline_plan, project_connection


class FakeClient:
    def __init__(self):
        self.commands = []
    def send(self, commands, **kwargs):
        self.commands.extend(commands)
        return {"snapshot": {}}


class ParcelPlannerTests(unittest.TestCase):
    def test_empty_sdk_quest_array_is_map_but_malformed_arrays_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            journey = ParcelJourney(FakeClient(), directory, {"name": "parcel-natural"})
            for flags in ([], {}, {"EVENT_GOT_POKEDEX": True}):
                journey.state = {"session": {"flags": {"quest": flags}}}
                self.assertEqual(journey.flag("EVENT_GOT_POKEDEX"), flags == {"EVENT_GOT_POKEDEX": True})
            for flags in ([True], [{"EVENT_GOT_POKEDEX": True}], None, False, {"EVENT_GOT_POKEDEX": 1}):
                journey.state = {"session": {"flags": {"quest": flags}}}
                with self.subTest(flags=flags), self.assertRaises(ProtocolError):
                    journey.flag("EVENT_GOT_POKEDEX")

    def test_pause_item_and_save_follow_actual_option_names_after_dex_unlock(self):
        with tempfile.TemporaryDirectory() as directory:
            journey = ParcelJourney(FakeClient(), directory, {"name": "parcel-natural"})
            selected = []
            journey.select = lambda path, index: selected.append((path, index))
            for options, item_index, save_index in ((["POKEMON", "ITEM", "RED", "SAVE", "CLOSE"], 2, 4),
                    (["POKEDEX", "POKEMON", "ITEM", "RED", "SAVE", "CLOSE"], 3, 5)):
                journey.state = {"pause": {"menu": {"options": options}}}
                journey.pause_option("ITEM");journey.pause_option("SAVE")
                self.assertEqual(selected[-2:], [("pause.selected", item_index), ("pause.selected", save_index)])
            for options in (["SAVE", "SAVE"], ["POKEMON"], ["SAVE", 1], {}):
                journey.state = {"pause": {"menu": {"options": options}}}
                with self.subTest(options=options), self.assertRaises(ProtocolError):
                    journey.pause_option("SAVE")

    def test_real_collision_detour_and_no_path(self):
        model = Geometry("walls", [[0, 1, 0], [0, 1, 0], [0, 0, 0]])
        route = model.path((0, 0), {(2, 0)})
        self.assertEqual([step.destination for step in route], [(0, 1), (0, 2), (1, 2), (2, 2), (2, 1), (2, 0)])
        with self.assertRaisesRegex(ProtocolError, "no source-valid"):
            model.path((0, 0), {(2, 0)}, occupied={(1, 2)})

    def test_ledge_one_way_and_occupied_landing(self):
        rules = [{"facing": "SPRITE_FACING_DOWN", "standing_foot_tile": 44, "target_foot_tile": 55, "input": "PAD_DOWN"}]
        model = Geometry("ledge", [[0], [1], [0]], feet=[[44], [55], [44]], rules=rules)
        route = model.path((0, 0), {(0, 2)})
        self.assertEqual([(s.kind, s.destination) for s in route], [("ledge", (0, 2))])
        with self.assertRaises(ProtocolError):
            model.path((0, 2), {(0, 0)})
        with self.assertRaises(ProtocolError):
            model.path((0, 0), {(0, 2)}, occupied={(0, 2)})

    def test_other_doors_cannot_be_shortcuts_and_grass_stays_available(self):
        model = Geometry("doors", [[0, 0, 0], [0, 0, 0]], grass=[[False, True, False], [False] * 3],
                         events={"objects": [], "background_events": [], "warps": [{"x": 1, "y": 0}]})
        self.assertEqual([s.destination for s in model.path((0, 0), {(2, 0)})], [(0, 1), (1, 1), (2, 1), (2, 0)])
        self.assertEqual(model.path((0, 0), {(1, 0)}, allow_warps={(1, 0)})[0].destination, (1, 0))

    def test_natural_guard_rejects_teleport_later_fixture_and_inventory_injection(self):
        with tempfile.TemporaryDirectory() as directory:
            client = FakeClient()
            journey = ParcelJourney(client, directory, {"name": "parcel-natural", "seed": 42})
            for action in ["warp kanto_route1", "battle rattata 2", "encounters off", {"op": "fixture", "options": {"seed": 42}}]:
                with self.subTest(action=action), self.assertRaises(ProtocolError):
                    journey.send(action)
            journey.initializing = True
            with self.assertRaises(ProtocolError):
                journey.reset(inventory={"money": 999, "slots": []})
            self.assertEqual(client.commands, [])

    def test_wild_ready_intro_waits_for_inactive_command_menu_before_run(self):
        with tempfile.TemporaryDirectory() as directory:
            class WarmupClient:
                def __init__(self):
                    self.commands=[]
                    self.state={"root":"battle","battle":{"introPhase":"ready","phase":"command",
                        "trainerName":None,"menu":{"active":False,"options":[],"selected":1,"columns":2}}}
                def send(self, commands, **kwargs):
                    for command in commands:
                        self.commands.append(command)
                        if isinstance(command,dict):
                            self.asserted=command["path"]
                            if command["path"]=="battle.menu.active" and not self.state["battle"]["menu"]["active"]:
                                raise ProtocolError("menu readiness timed out")
                            continue
                        menu=self.state["battle"]["menu"]
                        if command=="wait 2":
                            menu.update(active=True,options=["FIGHT","ITEM","POKEMON","RUN"])
                        elif command=="press right":menu["selected"]=2
                        elif command=="press down":menu["selected"]=4
                        elif command=="press a":
                            if not menu["active"] or menu["selected"]!=4:raise AssertionError("A before actual RUN readiness")
                            self.state={"root":"overworld","last_battle_outcome":{"kind":"run","blackout":False}}
                    return {"snapshot":self.state}
            client=WarmupClient();journey=ParcelJourney(client,directory,{"name":"parcel-natural"});journey.state=client.state
            journey.flee()
            self.assertEqual(client.commands[1],"wait 2")
            self.assertEqual(client.commands[2],{"op":"await","path":"battle.menu.active","equals":True,"frames":60})
            self.assertEqual(client.commands[-3:],["press right","press down","press a"])
            self.assertEqual(journey.summary["wild_encounters"][0]["exit"]["kind"],"run")

    def test_battle_run_selection_supports_expanded_two_column_menu(self):
        with tempfile.TemporaryDirectory() as directory:
            class MenuClient:
                def __init__(self): self.inputs=[];self.selected=1
                def send(self, commands, **kwargs):
                    transitions={(1,"right"):2,(2,"down"):4,(1,"down"):3,(3,"down"):1}
                    for command in commands:
                        direction=command.split()[1];self.inputs.append(direction)
                        self.selected=transitions.get((self.selected,direction),self.selected)
                    return {"snapshot":{"battle":{"menu":{"selected":self.selected,"columns":2,"options":["FIGHT","ITEM","POKEMON","RUN"]}}}}
            client=MenuClient();journey=ParcelJourney(client,directory,{"name":"parcel-natural"})
            journey.state={"battle":{"menu":{"selected":1,"columns":2}}}
            journey.select("battle.menu.selected",4)
            self.assertEqual(client.inputs,["right","down"])

    def test_natural_rejects_outcome_fixture_and_failure_writes_normal_summary(self):
        from tools.harness.parcel_journey import run
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ProtocolError):
                ParcelJourney(FakeClient(), directory, {"rival_fixture": "win"})
            with self.assertRaises(ProtocolError):
                run(FakeClient(), {"journey": {"name": "unknown-parcel"}}, directory)
            report = json.loads((Path(directory) / "journey-summary.json").read_text())
            self.assertFalse(report["ok"])
            self.assertEqual(report["acceptance"], "pending")


@unittest.skipUnless(os.environ.get("PARCEL_BUNDLE_SOURCE"), "set PARCEL_BUNDLE_SOURCE to identified staged build")
class PinnedParcelPlannerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.evidence = Path(os.environ["PARCEL_BUNDLE_SOURCE"])
        cls.models = load_geometry(cls.evidence)

    def test_all_required_source_routes_exist_and_south_route_uses_real_ledges(self):
        plan = offline_plan(self.evidence)
        self.assertFalse(plan["ok"])
        self.assertEqual(len(plan["segments"]), 11)
        south = next(s for s in plan["segments"] if s["zone_id"] == NAMES["Route1"] and s["origin"] == (10, 0))
        self.assertTrue(any(s["kind"] == "ledge" for s in south["source_steps"]))
        self.assertLess(sum(len(s["source_steps"]) for s in plan["segments"]), 400)

    def test_original_counter_reaches_clerk_and_nurse_without_crossing_walls(self):
        mart, center = self.models[NAMES["ViridianMart"]], self.models[NAMES["ViridianPokecenter"]]
        self.assertEqual(mart.approaches((2, 5))[(4, 5)], "left")
        self.assertEqual(center.approaches((3, 1))[(3, 3)], "up")
        self.assertEqual(mart.path((5, 6), set(mart.approaches((2, 5))), occupied={(2, 5), (7, 5), (5, 3)})[-1].destination, (4, 5))
        self.assertTrue(all(mart.collision[s.destination[1]][s.destination[0]] == 0 for s in mart.path((5, 6), {(4, 5)})))

    def test_source_header_offsets_custom_pallet_seam_and_invalid_exits(self):
        route, city = NAMES["Route1"], NAMES["ViridianCity"]
        for x in (9, 10):
            target, point = project_connection(self.models, "pallet_town", (x, 0), "up")
            self.assertEqual((target, point), (route, (x + 1, 35)))
            self.assertEqual(project_connection(self.models, target, point, "down"), ("pallet_town", (x, 0)))
        self.assertEqual(project_connection(self.models, route, (10, 0), "up"), (city, (20, 35)))
        self.assertEqual(project_connection(self.models, city, (20, 35), "down"), (route, (10, 0)))
        with self.assertRaises(ProtocolError):
            project_connection(self.models, city, (19, 0), "up")
        with self.assertRaises(ProtocolError):
            project_connection(self.models, route, (10, 10), "up")

    def test_malformed_source_and_changed_authored_hash_fail_before_input(self):
        data = json.loads((self.evidence / "Source/data/viridianSlice/Route1.json").read_text())
        data["source_revision"] = "unreviewed"
        with self.assertRaises(ProtocolError):
            Geometry.imported(data)
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Source/data").mkdir(parents=True)
            (root / "Source/data/maps.lua").write_text("changed")
            (root / "source-manifest.json").write_text("{}")
            with self.assertRaisesRegex(ProtocolError, "authored Pallet"):
                load_geometry(root)


if __name__ == "__main__":
    unittest.main()
