#!/usr/bin/env python3
"""Rebuild the Hall continue save with the flags a champion has already set.

The published envelope stays the SaveStore format: compact payload JSON and
the FNV-1a checksum over ``schema\\nsequence\\npayload``. This tool sets
flags. It does not hand-edit the pin.

pokered citations, from the scripts this port already follows:

- ``scripts/ViridianMart.asm`` gives Oak's Parcel and sets
  ``EVENT_GOT_OAKS_PARCEL``. ``Source/game/sourceEventHandlers.lua`` hands
  that parcel to Oak and sets ``EVENT_OAK_GOT_PARCEL`` and
  ``EVENT_GOT_POKEDEX``.
- ``scripts/ViridianCity.asm`` shows the sleepy old man before
  ``EVENT_GOT_POKEDEX`` and the awake old man after it. The tutorial gate
  is that same flag (``docs/plans/tutorial-escort/README.md``).
- Daisy gives the Town Map only after the dex
  (``Source/game/fieldItems.lua``).
- A finished save has the eight badges, Brock defeated
  (``TrainerEvents.BROCK`` is ``pokered:PEWTER_GYM:objects:1``), the
  Viridian gym badge from Giovanni, the Cerulean rocket gone, the S.S.
  Ticket, and one fossil. ``tools/tests/postgame_route.py`` treats those
  actors as already gone. ``HallOfFameResetEventsAndSaveScript`` clears the
  indigo range; those false flags stay false.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "tools/tests/fixtures/lane-h-hall-continue-8e72131f.json"

# Appended in this order when they are not already keys.
QUEST_FLAGS = (
    "EVENT_GOT_OAKS_PARCEL",
    "EVENT_OAK_GOT_PARCEL",
    "EVENT_GOT_POKEDEX",
    "EVENT_GOT_TOWN_MAP",
    "TOGGLE_CERULEAN_ROCKET",
    "EVENT_GOT_SS_TICKET",
    "EVENT_MET_BILL",
    "EVENT_MET_BILL_2",
    "EVENT_LEFT_BILLS_HOUSE_AFTER_HELPING",
    "EVENT_GOT_DOME_FOSSIL",
    "EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI",
    "BADGE_BOULDER",
    "BADGE_CASCADE",
    "BADGE_THUNDER",
    "BADGE_RAINBOW",
    "BADGE_MARSH",
    "BADGE_VOLCANO",
    "BADGE_EARTH",
)
BROCK = "pokered:PEWTER_GYM:objects:1"
# The published party is one Blastoise and the bag was empty. A catch needs
# a ball the marts sell. Twenty is one stack, not a Master Ball.
CATCH_BALL = {"id": "pokeBall", "quantity": 20}


def fnv(data):
    """SaveStore._checksum. Unsigned low 32 bits match the signed SDK hex."""
    value = 2166136261
    for byte in data:
        value = ((value ^ byte) * 16777619) & 0xffffffff
    return f"{value:08x}"


def bound_checksum(schema, sequence, payload):
    if not isinstance(sequence, str) or not sequence.isdecimal():
        raise ValueError("sequence must be a canonical decimal")
    body = f"{int(schema)}\n{sequence}\n{payload}".encode()
    return fnv(body)


def champion_hall_save(raw):
    """Return the envelope bytes with champion story flags set."""
    if isinstance(raw, str):
        raw = raw.encode()
    envelope = json.loads(raw.decode("utf-8"))
    payload = json.loads(envelope["payload"])
    if not isinstance(payload.get("questFlags"), dict):
        raise ValueError("questFlags object required")
    for flag in QUEST_FLAGS:
        payload["questFlags"][flag] = True
    trainers = payload.get("trainerFlags")
    if trainers == [] or trainers is None:
        trainers = {}
    if not isinstance(trainers, dict):
        raise ValueError("trainerFlags object required")
    trainers[BROCK] = True
    payload["trainerFlags"] = trainers
    slots = payload["inventory"]["slots"]
    if not isinstance(slots, list):
        raise ValueError("inventory slots required")
    for slot in slots:
        if slot.get("id") == CATCH_BALL["id"]:
            slot["quantity"] = CATCH_BALL["quantity"]
            break
    else:
        slots.append(dict(CATCH_BALL))
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    envelope["payload"] = encoded
    envelope["checksum"] = bound_checksum(envelope["schema"], envelope["sequence"], encoded)
    return json.dumps(envelope, separators=(",", ":"), ensure_ascii=False).encode()


def main():
    FIXTURE.write_bytes(champion_hall_save(FIXTURE.read_bytes()))


if __name__ == "__main__":
    main()
