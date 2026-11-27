#!/usr/bin/env python3
"""Unapplied audio hooks for lanes E and G. Never edits production files."""
from __future__ import annotations

from pathlib import Path
import difflib
import sys

ROOT = Path(__file__).resolve().parents[2]
if __package__ in (None, ''):
    sys.path.insert(0, str(ROOT))

# Applying the battle-scene cry hunk duplicates KantoAudio.updateGame, which
# already cries when introPhase becomes ready and when Shown changes.
# Applying the pause start-menu hunk duplicates the observer's menuCue.
# Title playCue("title") is idempotent with the observer's title bed.
EDITS = {
    'tools/notes/lane-e-audio-hooks.patch': {
        'Source/main.lua': [
            ('import "game/battleState"',
             'import "game/battleState"\nimport "game/kantoAudio"'),
            ('    machine:handleInput()\n',
             '    machine:handleInput()\n    KantoAudio.updateGame(game)\n'),
        ],
        'Source/game/overworldState.lua': [
            (
                '            local session=game.session\n'
                '            rootMachine:push("dialog", lines, function()\n',
                '            local session=game.session\n'
                '            if KantoAudio and KantoAudio.trainerJingle then\n'
                '                local id = npc.trainerID\n'
                '                local definition = game.trainers and game.trainers:definition(id)\n'
                '                local class = BattleState.trainerClassFor(id, definition)\n'
                '                -- PlayTrainerMusic is silent for rivals. Those scripts play\n'
                '                -- MUSIC_MEET_RIVAL (scripts/OaksLab.asm and the other sites\n'
                '                -- listed in Source/audio/events.lua).\n'
                '                local score = KantoAudio.trainerJingle(class, nil)\n'
                '                if not score and (class == "OPP_RIVAL1" or class == "OPP_RIVAL2" or class == "OPP_RIVAL3") then\n'
                '                    score = "meet_rival"\n'
                '                end\n'
                '                if score then KantoAudio.playJingle(score) end\n'
                '            end\n'
                '            rootMachine:push("dialog", lines, function()\n',
            ),
            (
                '        local travel, cyclingForced = FieldWorld.entryTravel(game,\n'
                '            {zone_id=currentZone.stableID, x=pos.x, y=pos.y}, WorldDeltas.export(), "continue")\n',
                '        local travel, cyclingForced = FieldWorld.entryTravel(game,\n'
                '            {zone_id=currentZone.stableID, x=pos.x, y=pos.y}, WorldDeltas.export(), "continue")\n'
                '        if KantoAudio and KantoAudio.setTraversal then\n'
                '            KantoAudio.setTraversal(travel and travel.mode)\n'
                '        end\n',
            ),
        ],
        'Source/game/fieldTravelState.lua': [
            (
                '                self.game.lastFieldTravel = {key = "surf", kind = "complete", mode = self.session:fieldTravelData().mode}\n',
                '                self.game.lastFieldTravel = {key = "surf", kind = "complete", mode = self.session:fieldTravelData().mode}\n'
                '                if KantoAudio and KantoAudio.setTraversal then\n'
                '                    KantoAudio.setTraversal(self.game.lastFieldTravel.mode)\n'
                '                end\n',
            ),
        ],
        'Source/game/fieldGearState.lua': [
            (
                '    if result.kind == "bicycle" then\n'
                '        local label = result.mode == "bicycle" and "GotOn" or "GotOff"\n',
                '    if result.kind == "bicycle" then\n'
                '        if KantoAudio and KantoAudio.setTraversal then\n'
                '            KantoAudio.setTraversal(result.mode)\n'
                '        end\n'
                '        local label = result.mode == "bicycle" and "GotOn" or "GotOff"\n',
            ),
        ],
    },
    'tools/notes/lane-e-audio-gaps.patch': {
        'Source/game/endgameStory.lua': [
            (
                '    state.phase = "hall-photo"\n'
                '    state.waiting = "hall-of-fame"\n'
                'end\n',
                '    state.phase = "hall-photo"\n'
                '    state.waiting = "hall-of-fame"\n'
                '    if KantoAudio and KantoAudio.playCue then KantoAudio.playCue("hall_of_fame") end\n'
                'end\n',
            ),
            (
                '        if entry and entry.cry then\n'
                '            EndgameStory.playCry(entry.cry)\n'
                '        end\n',
                '        if entry and entry.cry then\n'
                '            if KantoAudio and KantoAudio.playCry then\n'
                '                KantoAudio.playCry(entry.cry)\n'
                '            else\n'
                '                EndgameStory.playCry(entry.cry)\n'
                '            end\n'
                '        end\n',
            ),
            (
                '    if step.audio and step.audio.name then\n'
                '        EndgameStory.playCue(step.audio.name)\n'
                '    end\n'
                '    if state.plan.spin and step.op == "move" and not state.spinStarted then\n'
                '        state.spinStarted = true\n'
                '        if state.plan.audio then\n'
                '            EndgameStory.playCue(state.plan.audio.name)\n'
                '        end\n'
                '    end\n',
                '    if step.audio and step.audio.name then\n'
                '        if KantoAudio and KantoAudio.playCue and (step.audio.name == "denied" or step.audio.name == "arrow_tiles") then\n'
                '            KantoAudio.playCue(step.audio.name)\n'
                '        else\n'
                '            EndgameStory.playCue(step.audio.name)\n'
                '        end\n'
                '    end\n'
                '    if state.plan.spin and step.op == "move" and not state.spinStarted then\n'
                '        state.spinStarted = true\n'
                '        if state.plan.audio then\n'
                '            if KantoAudio and KantoAudio.playCue then\n'
                '                KantoAudio.playCue(state.plan.audio.name)\n'
                '            else\n'
                '                EndgameStory.playCue(state.plan.audio.name)\n'
                '            end\n'
                '        end\n'
                '    end\n',
            ),
        ],
        'Source/game/eventState.lua': [
            (
                '        self.audioGaps[#self.audioGaps + 1] = {cue = "SFX_ARROW_TILES", owner = "SourceAudio",\n'
                '            wait_for_completion = false}\n',
                '        self.audioGaps[#self.audioGaps + 1] = {cue = "SFX_ARROW_TILES", owner = "SourceAudio",\n'
                '            wait_for_completion = false}\n'
                '        if KantoAudio and KantoAudio.playSFX then KantoAudio.playSFX("arrow_tiles") end\n',
            ),
        ],
        'Source/game/snorlaxStory.lua': [
            (
                'function SnorlaxStory.useFlute(bag)\n'
                '    local game <const> = bag.game\n',
                'function SnorlaxStory.useFlute(bag)\n'
                '    if KantoAudio and KantoAudio.playCue then KantoAudio.playCue("flute") end\n'
                '    local game <const> = bag.game\n',
            ),
        ],
    },
    'tools/notes/lane-g-audio-hooks.patch': {
        'Source/game/titleState.lua': [
            (
                'function TitleState:update()\n'
                '    if self.phase == "menu" and self:isTop() then\n',
                'function TitleState:update()\n'
                '    if KantoAudio and KantoAudio.playCue and self.phase ~= "closed" then\n'
                '        KantoAudio.playCue("title")\n'
                '    end\n'
                '    if self.phase == "menu" and self:isTop() then\n',
            ),
        ],
        'Source/game/pauseState.lua': [
            (
                'function PauseState:enter()\n'
                '    self.phase = "menu"\n',
                'function PauseState:enter()\n'
                '    if KantoAudio and KantoAudio.playSFX then KantoAudio.playSFX("start_menu") end\n'
                '    self.phase = "menu"\n',
            ),
        ],
    },
    'tools/audio/cry-hooks.patch': {
        'Source/battle/battleScene.lua': [
            (
                '        if self.introTimer >= duration then\n'
                '            self.introPhase = "ready"\n'
                '            self.irisRadius = maxRadius\n'
                '        end\n',
                '        if self.introTimer >= duration then\n'
                '            self.introPhase = "ready"\n'
                '            self.irisRadius = maxRadius\n'
                '            if KantoAudio and not self.battle.trainerName and self.battle.enemy then\n'
                '                KantoAudio.playCry(self.battle.enemy.species)\n'
                '            end\n'
                '        end\n',
            ),
            (
                '    if request.kind == "sendout" and self.presentationFrame >= 10 then\n'
                '        self[request.details.side .. "Shown"] = request.details.pokemon\n'
                '    end\n',
                '    if request.kind == "sendout" and self.presentationFrame >= 10 then\n'
                '        self[request.details.side .. "Shown"] = request.details.pokemon\n'
                '        if KantoAudio and request.details.pokemon then\n'
                '            KantoAudio.playCry(request.details.pokemon.species)\n'
                '        end\n'
                '    end\n',
            ),
        ],
    },
}


def patch_for(edits):
    chunks = []
    for name, pairs in edits.items():
        old = (ROOT / name).read_text()
        new = old
        for before, after in pairs:
            count = new.count(before)
            if count != 1:
                raise SystemExit(f'{name}: expected one match, found {count} for {before!r}')
            new = new.replace(before, after, 1)
        chunks.extend(difflib.unified_diff(
            old.splitlines(True), new.splitlines(True),
            fromfile='a/' + name, tofile='b/' + name, n=3,
        ))
    text = ''.join(chunks).replace('\n \n', '\n\n')
    if not text.endswith('\n'):
        text += '\n'
    return text


def payloads():
    files = {name: patch_for(edits) for name, edits in EDITS.items()}
    # research doc: python tools/audio/integration_patch.py > tools/audio/root-hooks.patch
    from tools.audio.integration_patch import generate as root_hooks
    files['tools/audio/root-hooks.patch'] = root_hooks()
    if not files['tools/audio/root-hooks.patch'].endswith('\n'):
        files['tools/audio/root-hooks.patch'] += '\n'
    return files


def main():
    for name, text in payloads().items():
        path = ROOT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        print(name)


if __name__ == '__main__':
    main()
