#!/usr/bin/env python3
"""Emit root's optional gameplay hook patch. Never modifies gameplay files."""
from pathlib import Path
import difflib
ROOT=Path(__file__).resolve().parents[2]
EDITS={
'Source/main.lua': [
 ('import "game/battleState"','import "game/battleState"\nimport "game/kantoAudio"'),
 ('    machine:handleInput()\n','    machine:handleInput()\n    KantoAudio.updateGame(game)\n')],
}

def generate():
    patch=[]
    for name,edits in EDITS.items():
        old=(ROOT/name).read_text();new=old
        for before,after in edits:
            if new.count(before)!=1: raise ValueError(f'{name}: ambiguous/missing hook context: {before!r}')
            new=new.replace(before,after,1)
        patch.extend(difflib.unified_diff(old.splitlines(True),new.splitlines(True),fromfile='a/'+name,tofile='b/'+name,n=2))
    return ''.join(patch).replace('\n \n', '\n\n')

if __name__=='__main__':
    print(generate(),end='')
