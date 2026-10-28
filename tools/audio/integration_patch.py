#!/usr/bin/env python3
"""Emit root's optional gameplay hook patch. Never modifies gameplay files."""
from pathlib import Path
import difflib
ROOT=Path(__file__).resolve().parents[2]
EDITS={
'Source/main.lua': [
 ('import "game/battleState"','import "game/battleState"\nimport "game/kantoAudio"'),
 ('    machine:handleInput()\n','    machine:handleInput()\n    KantoAudio.update()\n')],
'Source/game/overworldState.lua': [
 ('function OverworldState:enter(opts)\n','function OverworldState:enter(opts)\n    KantoAudio.enterMap(currentZone)\n')],
'Source/game/battleState.lua': [
 ('    self.battle,self.scene=battle,scene\n','    self.battle,self.scene=battle,scene\n    KantoAudio.battleStart(npc and "trainer" or "wild")\n'),
 ('function BattleState:exit()\n','function BattleState:exit()\n    KantoAudio.battleEnd()\n'),
 ('function BattleState:update()\n','function BattleState:update()\n    if self.battle then\n        local mon=self.battle.player\n        KantoAudio.setLowHP(mon.hp>0 and mon.hp*5<=mon.maxHP)\n    end\n')],
'Source/game/eventState.lua': [
 ('    self.phase,self.waiting="heal-animation","healing"\n','    self.phase,self.waiting="heal-animation","healing"\n    KantoAudio.playSFX("heal")\n')],
'Source/ui/menu.lua': [
 ('function BattleMenu:handleInput()\n    if not self.isActive then return end\n','function BattleMenu:handleInput()\n    if not self.isActive then return end\n    local previousIndex = self.selectedIndex\n'),
 ('    elseif playdate.buttonJustPressed(playdate.kButtonA) then\n','    elseif playdate.buttonJustPressed(playdate.kButtonA) then\n        KantoAudio.playSFX("menu")\n'),
 ('    elseif playdate.buttonJustPressed(playdate.kButtonB) then\n','    elseif playdate.buttonJustPressed(playdate.kButtonB) then\n        KantoAudio.playSFX("menu")\n'),
 ('        end\n    end\nend\n\nfunction BattleMenu:draw','        end\n    end\n    if self.selectedIndex ~= previousIndex then KantoAudio.playSFX("menu") end\nend\n\nfunction BattleMenu:draw')],
'Source/battle/effects.lua': [
 ('    local removed=before-mon.hp\n','    local removed=before-mon.hp\n    if removed>0 then KantoAudio.playSFX("hit") end\n')],
'Source/battle/battle.lua': [
 ('            self.faintAnnounced[side] = true\n','            self.faintAnnounced[side] = true\n            KantoAudio.playSFX("faint")\n')],
}

def generate():
    patch=[]
    for name,edits in EDITS.items():
        old=(ROOT/name).read_text();new=old
        for before,after in edits:
            if new.count(before)!=1: raise ValueError(f'{name}: ambiguous/missing hook context: {before!r}')
            new=new.replace(before,after,1)
        patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+name,tofile='b/'+name))
    return ''.join(patch).replace('\n \n', '\n\n')

if __name__=='__main__':
    print(generate(),end='')
