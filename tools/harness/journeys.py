"""Semantic input-driven journeys, invoked inside the runner's owned session.

No process or mailbox ownership here: the runner passes its already-owned Client.
"""
from pathlib import Path
from tools.harness.protocol import ProtocolError, atomic_json

DIRECTIONS = {"up": (0, -1), "down": (0, 1), "left": (-1, 0), "right": (1, 0)}
COUNTERS = {"charmander": "squirtle", "squirtle": "bulbasaur", "bulbasaur": "charmander"}

def lookup(state, path):
    """Use the runtime's one-based array paths in host assertions too."""
    actual = state
    for key in path.split("."):
        if isinstance(actual, dict):
            actual = actual.get(key)
        elif isinstance(actual, list) and key.isdigit() and 1 <= int(key) <= len(actual):
            actual = actual[int(key) - 1]
        else:
            return None
    return actual


class Journey:
    def __init__(self, client, evidence, config):
        self.client = client
        self.evidence = Path(evidence)
        self.frames_dir = self.evidence / "frames"
        self.config = config
        self.state = {}
        self.checkpoints = []
        self.recordings = []
        self.fixtures = []
        self.summary = {"schema": 1, "journey": config, "checkpoints": self.checkpoints,
                        "recordings": self.recordings, "fixtures": self.fixtures}

    def send(self, *commands):
        result = self.client.send(list(commands), timeout=60, max_frames=1800)
        self.state = result["snapshot"]
        for command in commands:
            if isinstance(command, str):
                parts = command.split()
                if parts[0] == "record":
                    name, count = parts[1], int(parts[2])
                    for number in range(1, count + 1):
                        filename = f"{name}-{number:02d}.png"
                        if not (self.frames_dir / filename).is_file():
                            raise ProtocolError(f"journey recording missing: {filename}")
                    self.recordings.append({"name": name, "frames": count})
                elif parts[0] == "shot" and not (self.frames_dir / (parts[1] + ".png")).is_file():
                    raise ProtocolError(f"journey screenshot missing: {parts[1]}")
        return self.state

    def require(self, **values):
        for path, expected in values.items():
            actual = lookup(self.state, path)
            if actual != expected:
                raise ProtocolError(f"journey expected {path}={expected!r}, got {actual!r}")

    def await_value(self, path, value, frames=180):
        return self.send({"op": "await", "path": path, "equals": value, "frames": frames})

    def checkpoint(self, label):
        if self.state.get("root") == "dialog":
            self.await_value("dialog.ready", True, frames=300)
        self.send("shot " + label)
        self.checkpoints.append({"name": label, "snapshot": self.state})
        atomic_json(self.evidence / "journey-progress.json", self.summary)

    def reset(self, **options):
        options.setdefault("seed", self.config.get("seed", 42))
        self.fixtures.append({"kind": "session-reset", "options": options})
        self.send({"op": "fixture", "options": options})

    def adjust_battle(self, **values):
        self.fixtures.append({"kind": "supplementary-existing-battle-hp", "options": values})
        self.send({"op": "fixture", "options": {"adjust_battle": values}})

    def dialog(self):
        # Each press is gated by the current semantic overlay, so a final A
        # cannot reopen an NPC or select the next menu. First A reveals text;
        # the next advances it. No narrative text is used as an oracle.
        for _ in range(64):
            if self.state.get("root") != "dialog":
                return
            previous = (self.state["dialog"].get("instance"), self.state["dialog"].get("line"))
            ready = self.state["dialog"].get("ready")
            self.send("press a")
            if self.state.get("root") == "dialog" and ready:
                current = (self.state["dialog"].get("instance"), self.state["dialog"].get("line"))
                if current == previous:
                    raise ProtocolError("ready dialog failed to advance on A")
        raise ProtocolError("dialog exceeded 64 semantic presses")

    def walk(self, direction, count=1, record=None, arrival=None, root="overworld"):
        self.require(root="overworld", **{"overworld": "explore", "player.settled": True})
        old = self.state["player"]
        dx, dy = DIRECTIONS[direction]
        commands = [f"record {record} {max(24, count * 10 + 4)}"] if record else []
        # One-frame physical inputs, followed by the eight-frame movement.
        # Segments stop at the first expected story/door trigger.
        for _ in range(count):
            commands += [f"press {direction}", "wait 9"]
        self.send(*commands)
        if arrival:
            zone, x, y = arrival
            self.await_value("zone", zone)
            self.await_value("overworld", "explore")
            self.require(zone=zone, root=root, **{"player.x": x, "player.y": y, "player.settled": True})
        else:
            self.require(root=root, **{"player.x": old["x"] + dx*count, "player.y": old["y"] + dy*count,
                                      "player.settled": True})

    def face(self, direction):
        # A directional press against a solid tile changes facing but cannot
        # move. Starter-facing uses the actual table's collision, no face helper.
        x, y = self.state["player"]["x"], self.state["player"]["y"]
        self.send("press " + direction, "wait 2")
        self.require(**{"player.x": x, "player.y": y, "player.facing": direction, "player.settled": True})

    def battle(self, name, strategy="attack", expected=None):
        self.require(root="battle")
        self.await_value("battle.introPhase", "ready")
        initial = self.state["battle"]
        self.checkpoint(name + "-intro")
        selections = 0
        attack_recorded = False
        terminal = None
        for _ in range(240):
            if self.state.get("root") != "battle":
                break
            battle = self.state["battle"]
            phase = battle["phase"]
            if phase == "ended":
                terminal = {"player_hp": battle["player"]["hp"], "enemy_hp": battle["enemy"]["hp"]}
                self.checkpoint(name + "-ended")
                self.send("press a")
                continue
            if phase == "script":
                if not battle.get("waiting"):
                    self.send("wait 2")
                    continue
                # The production message minimum is 10 frames. One A advances
                # exactly one coroutine yield, then the next snapshot is read.
                if selections and not attack_recorded:
                    self.send(f"record {name}-attack 32", "wait 12", "press a")
                    attack_recorded = True
                else:
                    self.send("wait 12", "press a")
            elif phase == "command":
                if not battle.get("inMoveSelect"):
                    self.send("press a")
                    self.require(**{"battle.inMoveSelect": True, "battle.moveMenu.active": True})
                    self.checkpoint(name + f"-moves-{selections:02d}")
                else:
                    if strategy == "status":
                        # Both intro and default fixture starters have exactly
                        # two level-1 moves: damage first, stat move second.
                        self.send("press right")
                        self.require(**{"battle.moveMenu.selected": 2})
                    else:
                        self.require(**{"battle.moveMenu.selected": 1})
                    selections += 1
                    self.send("press a")
                    self.require(**{"battle.phase": "script", "battle.inMoveSelect": False})
            else:
                raise ProtocolError(f"unknown battle phase: {phase}")
        else:
            raise ProtocolError("battle exceeded 240 semantic actions")
        if self.state.get("root") == "battle" or terminal is None:
            raise ProtocolError("battle did not reach and acknowledge terminal phase")
        won = terminal["enemy_hp"] <= 0 and terminal["player_hp"] > 0
        lost = terminal["player_hp"] <= 0
        if expected == "win" and not won or expected == "loss" and not lost:
            raise ProtocolError(f"unexpected battle outcome: {terminal}; wanted {expected}")
        self.checkpoints.append({"name": name + "-outcome", "terminal": terminal, "won": won, "lost": lost,
                                 "selections": selections, "initial": initial})
        return won, lost

    def natural_intro(self):
        starter = self.config.get("starter", "squirtle")
        if starter not in COUNTERS:
            raise ProtocolError("starter must be charmander, squirtle or bulbasaur")
        self.reset()
        self.require(root="dialog", zone="reds_house_2f", **{"story.stage": "pre_oak", "pokemon.present": False})
        self.checkpoint("opening")
        self.dialog()
        self.require(root="overworld", **{"player.x": 5, "player.y": 3})
        self.face("up")  # TV collision; the player stays at (5,3).
        self.checkpoint("bedroom-collision")
        self.walk("right", 4, record="walking-bedroom")
        self.walk("up", arrival=("reds_house", 9, 2), record="stairs-down")
        self.walk("down", 4)
        self.walk("left", 6)
        self.walk("down")
        self.checkpoint("exit-mat")
        self.walk("down", arrival=("pallet_town", 5, 5), record="door-exterior")
        self.require(**{"player.facing": "down"})
        self.walk("down")
        self.walk("right", 4, record="camera-scroll")
        self.walk("up", 4, record="grass-oak-stop", root="dialog")
        self.require(zone="pallet_town", **{"story.stage": "pre_oak", "player.tile": 8})
        self.checkpoint("oak-stop")
        self.dialog()
        self.await_value("zone", "oaks_lab")
        self.await_value("root", "dialog")
        self.require(**{"story.stage": "choose"})
        self.checkpoint("lab-greeting")
        self.dialog()
        self.walk("up")
        ball_x = {"charmander": 6, "squirtle": 7, "bulbasaur": 8}[starter]
        self.walk("right", ball_x - 5)
        self.walk("up")
        self.face("up")
        self.send("press a")
        self.require(root="dialog", **{"story.stage": "pre_rival", "story.starter": starter,
                                        "story.rivalStarter": COUNTERS[starter], "pokemon.species": starter})
        self.checkpoint("starter-" + starter)
        self.dialog()
        self.walk("down")
        self.walk("left", ball_x - 5)
        self.walk("down", 4, root="dialog")
        self.checkpoint("rival-challenge")
        self.dialog()
        self.require(root="battle", **{"story.stage": "rival_fight", "battle.enemy.species": COUNTERS[starter]})
        outcome = self.config.get("rival_fixture")
        if outcome == "win":
            self.adjust_battle(enemy_hp=1)
        elif outcome == "loss":
            self.adjust_battle(player_hp=1)
        elif outcome is not None:
            raise ProtocolError("rival_fixture must be win or loss")
        won, lost = self.battle("rival", strategy="status" if outcome == "loss" else "attack",
                                expected=outcome or self.config.get("expected_outcome"))
        # A confirmed lab victory can present its payout before exploration
        # advances the goodbye gate. Finish that overlay before awaiting it.
        self.dialog()
        self.await_value("story.stage", "done")
        self.require(zone="oaks_lab", **{"story.rivalOutcome": won})
        self.dialog()
        self.require(root="overworld", **{"story.stage": "done", "pokemon.present": True})
        if any(npc["name"] == "BLUE" for npc in self.state.get("npcs", [])):
            raise ProtocolError("BLUE remained in lab after goodbye")
        if lost:
            self.require(**{"pokemon.hp": self.state["pokemon"]["maxHP"], "player.x": 5, "player.y": 9})
        self.checkpoint("intro-complete")
        self.summary["natural_intro"] = outcome is None
        self.summary["outcome"] = "win" if won else "loss"

    def interiors(self):
        # Explicit free-play fixture isolates traversal from story progression.
        self.reset(intro="skip", zone="pallet_town", entry={"x": 5, "y": 6, "facing": "up"})
        self.walk("up", arrival=("reds_house", 3, 7), record="red-house-enter")
        self.walk("up")
        self.walk("right", 6)
        self.walk("up", 4, arrival=("reds_house_2f", 9, 2), record="stairs-up")
        self.walk("left")
        self.walk("right", arrival=("reds_house", 9, 2), record="stairs-return")
        self.walk("down", 4)
        self.walk("left", 6)
        self.walk("down")
        self.walk("down", arrival=("pallet_town", 5, 5), record="red-house-exit")
        self.require(**{"player.facing": "down"})
        self.walk("down", 2)
        self.walk("right", 8)
        self.walk("up", 2, arrival=("blues_house", 3, 7), record="blue-house-enter")
        self.walk("up")
        self.walk("down")
        self.walk("down", arrival=("pallet_town", 13, 5), record="blue-house-exit")
        self.require(**{"player.facing": "down"})
        self.walk("down", 2)
        self.walk("right")
        self.walk("down", 5)
        self.walk("left", 4)
        self.walk("up", arrival=("oaks_lab", 5, 9), record="lab-enter")
        self.walk("up")
        self.walk("down")
        self.walk("down", arrival=("pallet_town", 10, 11), record="lab-exit")
        self.require(**{"player.facing": "down"})
        self.checkpoint("interior-roundtrips-complete")

    def overlays_inputs(self):
        self.reset(intro="skip", zone="reds_house_2f", entry={"x": 5, "y": 3, "facing": "up"})
        self.send("debug open")
        self.require(root="debug")
        self.send("record debug-overlay 24", "press down", "press up", "wait 4")
        self.require(root="debug", **{"player.x": 5, "player.y": 3, "player.settled": True})
        self.send("press b")
        self.require(root="overworld")
        # Held input moves continuously. Release while still in open floor,
        # wait for its last step, then prove subsequent frames stay still.
        self.send("record held-walking 32", "hold left", "wait 9", "release left", "wait 16")
        self.require(root="overworld", **{"player.settled": True})
        x, y = self.state["player"]["x"], self.state["player"]["y"]
        if not (2 <= x < 5 and y == 3):
            raise ProtocolError(f"held input did not move on valid floor: {x},{y}")
        self.send("wait 20")
        self.require(**{"player.x": x, "player.y": y, "player.settled": True})
        self.checkpoint("release-stopped")

    def session_resets(self):
        # Keep the reset command in the same request as the active-state await:
        # the host cannot accidentally let a short door fade finish first.
        reset_options = {"seed": self.config.get("seed", 42)}
        for source in ("dialog", "door", "battle"):
            if source == "dialog":
                self.reset(zone="pallet_town", entry={"x": 9, "y": 3, "facing": "up"}, opening=False)
                self.send("press up", {"op": "await", "path": "root", "equals": "dialog", "frames": 40})
                self.require(**{"story.stage": "pre_oak"})
                # This Oak-stop overlay has a callback which would otherwise
                # warp to the lab; reset must remove it, not resume/pop it.
                expected_path, expected_value = "root", "dialog"
            elif source == "door":
                self.reset(intro="skip", zone="reds_house_2f", entry={"x": 9, "y": 3, "facing": "up"})
                expected_path, expected_value = "overworld", "doorWarp"
                self.send("hold a", "press up",
                          {"op": "await", "path": expected_path, "equals": expected_value, "frames": 40},
                          {"op": "fixture", "options": reset_options})
            else:
                self.reset(intro="skip", zone="pallet_town", entry={"x": 9, "y": 7, "facing": "up"})
                self.send("battle rattata 3")
                self.await_value("battle.introPhase", "ready")
                self.require(root="battle", **{"battle.phase": "script", "battle.waiting": True})
                expected_path, expected_value = "root", "battle"
            if source != "door":
                self.send("hold a", {"op": "assert", "path": expected_path, "equals": expected_value},
                          {"op": "fixture", "options": reset_options})
            self.fixtures.append({"kind": "reset-from-active-" + source, "options": reset_options})
            self.require(root="dialog", zone="reds_house_2f", overworld="explore",
                         **{"story.stage": "pre_oak", "story.starter": "none", "story.rivalStarter": "none",
                            "pokemon.present": False, "battle.present": False, "player.x": 5, "player.y": 3,
                            "player.settled": True})
            self.send("wait 40")
            self.require(root="dialog", zone="reds_house_2f", **{"story.stage": "pre_oak", "battle.present": False})
            self.checkpoint("reset-from-" + source)
            self.dialog()
            self.send("wait 24")
            self.require(root="overworld", zone="reds_house_2f", overworld="explore",
                         **{"story.stage": "pre_oak", "player.x": 5, "player.y": 3, "player.settled": True,
                            "pokemon.present": False})
            self.checkpoint("reset-settled-" + source)

    def battle_learning(self):
        # XP positions the fixture just below level 7; the real battle must
        # award the remaining XP and open learning through BattleState.finish.
        self.reset(intro="skip", opening=False, zone="reds_house_2f",
                   player_pokemon={"species": "charmander", "level": 6},
                   grant_xp={"amount": 56})
        # Pinned B2W2 medium-slow thresholds: Lv6=179, Lv7=236.
        self.require(root="overworld", **{"pokemon.level": 6, "pokemon.xp": 235,
                                         "pokemon.pending_moves": 0})
        self.send("battle rattata 2")
        self.battle("level-up-battle", expected="win")
        self.require(root="learning", **{"pokemon.level": 7, "learning.phase": "message",
                                         "pokemon.moves.3": "ember"})
        self.await_value("learning.dialog_ready", True)
        self.checkpoint("battle-learned-ember")
        self.send("press a")
        self.await_value("root", "overworld")
        self.require(**{"pokemon.pending_moves": 0, "pokemon.pp.ember": 25})
        self.checkpoint("battle-learning-return")

    def wild(self, blackout=False):
        self.reset(intro="skip", zone="pallet_town", entry={"x": 9, "y": 3, "facing": "up"})
        self.send("encounters on")
        # Walk on actual grass until the real encounter rule starts irisOut.
        # Each request has one press: a battle can never consume later steps.
        for attempt in range(60):
            direction = "up" if self.state["player"]["y"] >= 2 else "down"
            self.send(f"record grass-encounter-{attempt:02d} 50", "press " + direction, "wait 12")
            if self.state.get("root") == "battle":
                break
            self.require(root="overworld", **{"overworld": "explore", "player.tile": 8, "player.settled": True})
        else:
            raise ProtocolError("no actual grass encounter within 60 steps")
        self.checkpoint("wild-entry")
        if blackout:
            self.adjust_battle(player_hp=1)
        self.battle("wild-blackout" if blackout else "wild-return", strategy="status" if blackout else "attack",
                    expected="loss" if blackout else "win")
        self.require(root="overworld", zone="reds_house_2f" if blackout else "pallet_town", **{"story.stage": "done"})
        if blackout:
            self.require(**{"player.x": 5, "player.y": 3, "pokemon.hp": self.state["pokemon"]["maxHP"]})
        else:
            self.require(**{"player.x": 9, "player.tile": 8})
        self.checkpoint("blackout-return" if blackout else "wild-return")


def run(client, scenario, evidence_dir, build_evidence=None, prior_receipt=None, capture_dir=None):
    if scenario.get("journey", {}).get("name") == "battle-medicine":
        from tools.harness.battle_medicine_journey import run as run_medicine
        return run_medicine(client, scenario, evidence_dir)
    if scenario.get("journey", {}).get("name") in {"npc-motion", "npc-motion-save", "npc-motion-continue"}:
        from tools.harness.motion_journey import run as run_motion
        return run_motion(client, scenario, evidence_dir, build_evidence, prior_receipt, capture_dir)
    config = scenario["journey"]
    if not isinstance(config, dict):
        raise ProtocolError("journey must be an object")
    if config.get("name") == "reward-hud":
        from tools.harness.reward_hud import run as run_reward_hud
        return run_reward_hud(client, scenario, evidence_dir)
    if config.get("name") == "brock-source-supplementary" and config.get("case") == "field-rope-input":
        from tools.harness.field_rope_journey import run as run_rope
        return run_rope(client, scenario, evidence_dir, build_evidence=build_evidence, capture_dir=capture_dir)
    if config.get("name") in {"brock-natural", "brock-continue", "brock-source-supplementary"}:
        from tools.harness.brock_journey import run as run_brock
        return run_brock(client, scenario, evidence_dir, build_evidence, prior_receipt, capture_dir)
    if config.get("name") in {"parcel-natural", "parcel-full-bag-supplementary", "parcel-visibility-checkpoint-supplementary"}:
        from tools.harness.parcel_journey import run as run_parcel
        return run_parcel(client, scenario, evidence_dir)
    journey = Journey(client, evidence_dir, config)
    name = config.get("name")
    actions = {"intro": journey.natural_intro, "interiors": journey.interiors,
               "overlays-inputs": journey.overlays_inputs, "session-resets": journey.session_resets, "wild-return": journey.wild,
               "wild-blackout": lambda: journey.wild(blackout=True),
               "battle-learning": journey.battle_learning}
    if name not in actions:
        raise ProtocolError("unknown journey: " + str(name))
    try:
        actions[name]()
    except BaseException as error:
        journey.summary.update(ok=False, error=str(error), last_snapshot=journey.state)
        atomic_json(Path(evidence_dir) / "journey-summary.json", journey.summary)
        raise
    journey.summary.update(ok=True, last_snapshot=journey.state)
    return journey.summary
