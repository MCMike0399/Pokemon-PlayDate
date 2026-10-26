"""Host contracts only: real staged JSON, route graphs and registration patch.

No SDK emulation, Lua evaluation, Simulator, RNG prediction or game outcome
simulation. Runtime acceptance remains the owning root's separate job.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools.harness import cerulean_journey as cj, suite
from tools.harness.brock_journey import BrockJourney, SourceGeometry
from tools.harness.protocol import ProtocolError

ROOT = Path(__file__).resolve().parents[2]
CASES = ROOT / "tools/harness/scenarios/cerulean"
PATCH = CASES / "root-registration.patch"


class NoRuntime:
    identity = {"build_id": "host-contract", "session_id": "owned-test"}

    def send(self, *args, **kwargs):
        raise AssertionError("host contract must not execute game input")


def structural_payload():
    # Host schema/receipt validation only; no claim of SDK-valid gameplay data.
    return {**{key: {} for key in cj.CODEC_FIELDS - {"version", "pokemonEncoding"}},
            "version": 1, "pokemonEncoding": "decimal-counters-v1"}


def receipt_state():
    return {"starter": "squirtle", "fossil": "dome", "zone_id": "pokered:ROUTE_25",
            "player": {"x": 2, "y": 3, "facing": "down"}, "flags": {"quest": {}, "trainers": {}},
            "inventory": {}, "party": {}, "checkpoint": {}, "codec": structural_payload()}


class ConfigurationTests(unittest.TestCase):
    def test_all_starters_restart_and_all_supplements_discovered_by_actual_suite(self):
        jobs = [j for j in suite.available_jobs() if j.get("scenario", Path()).parent == CASES]
        self.assertEqual(len(jobs), 8)
        self.assertEqual(len({j["name"] for j in jobs}), 8)
        self.assertEqual(suite.select_jobs([",".join(j["name"] for j in jobs)]), jobs)
        starters = set()
        supplements = set()
        for job in jobs:
            scenario = json.loads(job["scenario"].read_text())
            if "processes" in scenario:
                groups = scenario["processes"]
                self.assertEqual(len(groups), 2)
                self.assertTrue(groups[1]["restart"])
                previous = {}
                for index, group in enumerate(groups):
                    cj.validate_process_journey(group["journey"], index, previous)
                    previous = group["journey"]
                starters.add(groups[0]["journey"]["starter"])
            else:
                config = scenario["journey"]
                cj.validate_config(config)
                self.assertTrue(config["supplementary"])
                supplements.add((config["case"], config["fossil"]))
        self.assertEqual(starters, set(cj.FAMILIES))
        self.assertEqual({case for case, fossil in supplements}, cj.CASES)
        self.assertIn(("fossil-full-retry", "dome"), supplements)
        self.assertIn(("fossil-full-retry", "helix"), supplements)

    def test_bounds_unknown_options_and_unlabeled_fixtures_fail_before_input(self):
        for mutation in ({"max_actions": True}, {"max_steps": 5001}, {"max_transitions": 0},
                         {"starter": "pikachu"}, {"fossil": "amber"}, {"quest_flags": {}},
                         {"supplementary": True}, {"case": "blackout"}):
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                cj.CeruleanJourney(NoRuntime(), "/unused", dict(name="cerulean-natural", **mutation))

    def test_new_game_cannot_run_later_and_continue_cannot_change_choice(self):
        natural = {"name": "cerulean-natural", "starter": "charmander", "fossil": "helix"}
        with self.assertRaises(ProtocolError):
            cj.validate_process_journey(natural, 1, natural)
        for config in ({"name": "cerulean-continue", "starter": "bulbasaur"},
                       {"name": "cerulean-continue", "fossil": "dome"}):
            with self.assertRaises(ProtocolError):
                cj.validate_process_journey(config, 1, natural)
        with self.assertRaises(ProtocolError):
            cj.validate_process_journey({"name": "cerulean-continue"}, 0, {})

    def test_inherited_natural_guard_blocks_every_shortcut(self):
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-natural"})
        for command in ("warp kanto_cerulean_city", "intro skip", "battle staryu 1", "move right 20",
                        "encounters off", {"op": "fixture", "options": {"quest_flags": {"EVENT_MET_BILL": True}}}):
            with self.subTest(command=command), self.assertRaises(ProtocolError):
                journey.send(command)
        journey.initializing = True
        with self.assertRaises(ProtocolError):
            journey.reset(inventory={"money": 9999, "slots": []})

    def test_reuses_bounded_production_host_apis(self):
        for method in ("drain", "learning", "evolution", "navigate", "interact", "battle_medicine",
                       "battle_switch", "train_to", "recover_blackout"):
            self.assertIs(getattr(cj.CeruleanJourney, method), getattr(BrockJourney, method))


class SourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.build = Path(cls.temporary.name)
        # This is ordinary data staging, not a pretend SDK or game runtime.
        shutil.copytree(ROOT / "Source", cls.build / "Source")
        shutil.copyfile(cls.build / "Source/main.lua", cls.build / "original-main.lua")
        manifest = {p.relative_to(cls.build / "Source").as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                    for p in (cls.build / "Source").rglob("*") if p.is_file()}
        (cls.build / "source-manifest.json").write_text(json.dumps(manifest))
        cls.source = cj.StagedSource(cls.build)

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def test_real_unified_cache_and_header_geometry_load_without_lua_or_sdk(self):
        models, manifest, doors = cj.source_models(self.source)
        self.assertEqual(set(manifest["maps"]), set(json.loads((ROOT / "Source/data/sourceMaps.json").read_text())["maps"]))
        for entry in manifest["maps"].values():
            self.assertEqual((models[entry["id"]].width, models[entry["id"]].height), (entry["width"], entry["height"]))
        route2 = models["pokered:ROUTE_2"]
        self.assertEqual(cj.connection_projection(models, route2, (8, 0), "up"), ("pokered:PEWTER_CITY", (18, 35)))
        with self.assertRaises(ProtocolError):
            cj.connection_projection(models, route2, (8, 1), "up")
        self.assertIn("OVERWORLD", doors)

    def test_staged_bytes_are_verified_instead_of_live_checkout(self):
        with tempfile.TemporaryDirectory() as directory:
            staged = Path(directory)
            (staged / "Source").mkdir()
            raw = {"schema": 1, "source_revision": cj.REVISION}
            path = staged / "Source/data.json"
            path.write_text(json.dumps(raw))
            (staged / "source-manifest.json").write_text(json.dumps({"data.json": hashlib.sha256(path.read_bytes()).hexdigest()}))
            source = cj.StagedSource(staged)
            self.assertEqual(source.read("data.json"), raw)
            path.write_text(json.dumps(dict(raw, changed=True)))
            with self.assertRaises(ProtocolError):
                source.read("data.json")
            for unsafe in ("../data.json", "/etc/passwd"):
                with self.assertRaises(ProtocolError):
                    source.read(unsafe)

    def test_missing_or_stale_owner_projection_fails_closed(self):
        required = ("data/sourceMaps.json", "domain/sessionCodec.lua", "data/items.lua",
                    "data/sourceSlice/trainers.json", "data/ceruleanStory/events.json")
        # A contract validator double supplies hashes only. No game APIs exist.
        source = type("ProjectionHashes", (), {"manifest": {p: "digest" for p in required}, "build": self.build})()
        export = {"sources": {}, "events": [], "trainers": {}, "rivals": {}, "session_codec": 8}
        with self.assertRaises(ProtocolError):
            cj.validate_export(export, source)
        export["sources"] = {"data/sourceMaps.json": "stale"}
        with self.assertRaises(ProtocolError):
            cj.validate_export(export, source)
        projected = self.source.read("data/ceruleanJourney.json")
        self.assertEqual(cj.validate_export(projected, self.source), projected)
        archived = self.build / "original-main.lua"
        original = archived.read_bytes()
        try:
            archived.write_bytes(original + b"\n-- archive drift\n")
            with self.assertRaises(ProtocolError):
                cj.validate_export(projected, self.source)
        finally:
            archived.write_bytes(original)


class NavigationTests(unittest.TestCase):
    def test_disconnected_floor_requires_specific_exit_and_reentry(self):
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-natural"})
        def floor(name, collision, exits):
            model = SourceGeometry(name, [collision], events={"objects": [], "background_events": [], "warps": exits})
            model.padding = 0
            model.source_data = {"source_map_constant": name, "name": name, "connections": [], "tileset": {"constant": "CAVERN"}}
            model.descriptor = {"blocked_connections": []}
            return model
        def warp(index, x, target, target_index):
            return {"id": f"{index}-{x}-{target}", "source_index": index, "x": x, "y": 0,
                    "destination": {"kind": "map", "map": target, "warp_index": target_index}}
        a = floor("A", [0, 0, 1, 0, 0], [warp(1, 0, "B", 1), warp(2, 4, "B", 2)])
        b = floor("B", [0, 0, 0], [warp(1, 0, "A", 1), warp(2, 2, "A", 2)])
        journey.models, journey.doors = {"A": a, "B": b}, {}
        journey.state = {"zone_id": "A", "player": {"x": 1, "y": 0}, "npcs": [], "session": {"flags": {"quest": {}}}}
        original = copy.deepcopy(journey.state)
        portal = journey.route_portal("A", {(3, 0)})
        self.assertEqual(portal[2]["source_index"], 1)
        self.assertEqual(portal[3], ("B", (0, 0)))
        self.assertEqual(journey.state, original)
        b.collision[0][1] = 1
        with self.assertRaises(ProtocolError):
            journey.route_portal("A", {(3, 0)})

    def test_horizontal_connection_uses_header_adjustment(self):
        a = SourceGeometry("a", [[0] * 3 for _ in range(4)])
        b = SourceGeometry("b", [[0] * 3 for _ in range(6)])
        for model, name in ((a, "A"), (b, "B")):
            model.padding = 0
            model.descriptor = {"blocked_connections": []}
            model.source_data = {"name": name, "connections": []}
        a.source_data["connections"] = [{"direction": "east", "target_header": "B", "entry_lateral_adjustment_cells": 2}]
        self.assertEqual(cj.connection_projection({"a": a, "b": b}, a, (2, 1), "right"), ("b", (0, 3)))
        a.descriptor["blocked_connections"] = ["east"]
        with self.assertRaises(ProtocolError):
            cj.connection_projection({"a": a, "b": b}, a, (2, 1), "right")


class ReceiptTests(unittest.TestCase):
    def test_fossil_exclusion_requires_matching_flags_items_and_hidden_actors(self):
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-natural", "fossil": "dome"})
        journey.map_manifest = {"maps": {"MtMoonB2F": {"id": "pokered:MT_MOON_B2F"}}}
        journey.state = {"zone_id": "pokered:MT_MOON_B2F", "npcs": [], "session": {
            "flags": {"quest": {"EVENT_GOT_DOME_FOSSIL": True}},
            "inventory": {"slots": [{"id": "domeFossil", "quantity": 1}]}}}
        journey.fossil_exclusion()
        good = copy.deepcopy(journey.state)
        journey.state["session"]["flags"]["quest"]["EVENT_GOT_HELIX_FOSSIL"] = True
        with self.assertRaises(ProtocolError):
            journey.fossil_exclusion()
        journey.state = copy.deepcopy(good)
        journey.state["session"]["inventory"]["slots"].append({"id": "helixFossil", "quantity": 1})
        with self.assertRaises(ProtocolError):
            journey.fossil_exclusion()
        journey.state = copy.deepcopy(good)
        journey.state["npcs"] = [{"source_event_id": cj.FOSSILS["helix"][0]}]
        with self.assertRaises(ProtocolError):
            journey.fossil_exclusion()

    def test_no_reward_inference_from_english_dialogue(self):
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-natural"})
        journey.state = {"dialog": {"line": "Received the S.S. Ticket!"}, "session": {
            "flags": {"quest": {}}, "inventory": {"slots": []}}}
        # Interaction is intentionally not executed by this host validator test.
        # A story text alone cannot satisfy the actual transaction assertion.
        journey.interact = lambda **kwargs: None
        with self.assertRaises(ProtocolError):
            journey.reward(cj.TICKET, "ssTicket", "EVENT_GOT_SS_TICKET")

    def test_codec_guard_rejects_invalid_roundtrip_version_and_aliasing(self):
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-natural"})
        journey.export = {"session_codec": 1}
        codec = {"version": 1, "valid": True, "roundtrip_equal": True, "payload": structural_payload()}
        journey.observe = lambda kind: codec
        payload = journey.codec_guard("saved")
        payload["party"]["changed"] = True
        self.assertEqual(codec["payload"]["party"], {})
        for mutation in ({"version": 7}, {"valid": False}, {"roundtrip_equal": False}, {"payload": []}):
            journey.observe = lambda kind: dict(codec, **mutation)
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                journey.codec_guard("saved")
        journey.observe = lambda kind: codec
        with self.assertRaises(ProtocolError):
            journey.codec_guard()  # validation cannot return a receipt payload

    def test_wrong_process_identity_and_incomplete_receipts_fail_before_io(self):
        state = receipt_state()
        cj.validate_receipt_state(state)
        for mutation in ({"fossil": "amber"}, {"starter": "pikachu"}, {"codec": {}}, {"player": {"x": True, "y": 0}}):
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                cj.validate_receipt_state(dict(state, **mutation))
        journey = cj.CeruleanJourney(NoRuntime(), "/unused", {"name": "cerulean-continue"})
        packet = {"schema": 1, "kind": "cerulean-saved", **NoRuntime.identity, "state": state}
        for mutation in ({"build_id": "other"}, {"session_id": "other"}, {"kind": "brock-saved"}):
            with self.subTest(mutation=mutation), self.assertRaises(ProtocolError):
                journey.continue_saved(dict(packet, **mutation))


class RootRegistrationTests(unittest.TestCase):
    def test_registered_dispatch_validates_real_scenarios_and_immutable_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            paths = ("brock_journey.py", "journeys.py", "restarting.py", "brock_capture.py")
            for name in paths:
                target = root / "tools/harness" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / "tools/harness" / name, target)
            def load(name):
                spec = importlib.util.spec_from_file_location("cerulean_patch_test_" + name, root / "tools/harness" / (name + ".py"))
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                return module
            restarting = load("restarting")
            journeys = load("journeys")
            for path in CASES.glob("*.json"):
                scenario = json.loads(path.read_text())
                restarting.validate(scenario)
            expected = {"ok": True}
            scenario = {"journey": {"name": "cerulean-continue"}}
            with patch.object(cj, "run", return_value=expected) as dispatch:
                self.assertIs(journeys.run(None, scenario, root, root, {"receipt": True}, root), expected)
                dispatch.assert_called_once_with(None, scenario, root, root, {"receipt": True}, root)
            path = root / "journey-receipt.json"
            packet = {"schema": 1, "kind": "cerulean-saved", **NoRuntime.identity, "state": receipt_state()}
            path.write_text(json.dumps(packet))
            reference = {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
            self.assertEqual(restarting.read_receipt(reference, NoRuntime.identity), packet)
            path.write_text(json.dumps(dict(packet, session_id="changed")))
            with self.assertRaises(ProtocolError):
                restarting.read_receipt(reference, NoRuntime.identity)


if __name__ == "__main__":
    unittest.main()
