#!/usr/bin/env python3
"""Return codec/session changes as an unapplied patch for the exclusive root."""
from pathlib import Path
import difflib

ROOT = Path(__file__).resolve().parents[2]
changes = {}


def edit(name, old, new):
    text = changes.get(name, (ROOT / name).read_text())
    if old not in text:
        raise ValueError(f'root Safari seam changed: {name}: {old!r}')
    changes[name] = text.replace(old, new, 1)


session = 'Source/domain/gameSession.lua'
edit(session, 'fieldTravel = FieldTravel.empty(),', 'fieldTravel = FieldTravel.empty(),\n        safari = SafariGame.empty(),\n        coins = CoinWallet.empty(),')
edit(session, 'values.fieldTravel = FieldTravel.normalize(values.fieldTravel)',
     'values.fieldTravel = FieldTravel.normalize(values.fieldTravel)\n    values.safari = SafariGame.normalize(values.safari)\n    values.coins = CoinWallet.normalize(values.coins)')
edit(session, 'function GameSession:useEscapeRope(request) return FieldItems._commit(self,request) end',
     """function GameSession:useEscapeRope(request)
    local current = state[self]
    local checked, prepared = pcall(function()
        local plan, reason = SafariGame.escape(current.safari)
        assert(plan, reason)
        local combined = copy(current.questFlags)
        for id, value in pairs(SafariGame.flags(plan.after)) do
            if value or combined[id] ~= nil then
                combined[id] = value
            end
        end
        return {after = plan.after, flags = flags(combined, 4096)}
    end)
    if not checked then
        return false, tostring(prepared)
    end
    -- Existing Escape Rope owns item/world/arrival validation and rollback.
    -- No Safari mutation precedes that guarded commit. All values below are
    -- already prepared; no fallible callback follows the item's success.
    local accepted, result = FieldItems._commit(self, request)
    if not accepted then
        return false, result
    end
    current.safari, current.questFlags = prepared.after, prepared.flags
    self:invalidateFieldWorldContext()
    return true, result
end""")
changes[session] += '\n' + (ROOT / 'docs/implementation/safari-services/root-session-methods.lua').read_text()
codec = 'Source/domain/sessionCodec.lua'
edit(codec, 'daycare=true,fieldTravel=true})', 'daycare=true,fieldTravel=true,safari=true,coins=true})')
edit(codec, 'travel = FieldTravel.normalize(travel)', '''travel = FieldTravel.normalize(travel)
    local safari = data.safari
    if data.version < 4 then
        assert(safari == nil, "legacy session cannot contain Safari provenance")
        safari = SafariGame.empty()
    end
    safari = SafariGame.normalize(safari)
    local coins = data.coins
    if data.version < 4 then
        assert(coins == nil, "legacy session cannot contain coin provenance")
        coins = CoinWallet.empty()
    end
    coins = CoinWallet.normalize(coins)
    for id, value in pairs(SafariGame.flags(safari)) do
        assert((quests[id] or false) == value, "inconsistent saved Safari source flag")
    end''')
edit(codec, 'fieldWorld=fieldWorld,fieldTravel=travel}', 'fieldWorld=fieldWorld,fieldTravel=travel,safari=safari,coins=coins}')
edit(codec, 'fieldTravel=session:fieldTravelData(),', 'coins=session:coins(),safari=session:safariData(),fieldTravel=session:fieldTravelData(),')
edit(codec, 'fieldTravel=prepared.fieldTravel})', 'fieldTravel=prepared.fieldTravel,safari=prepared.safari,coins=prepared.coins})')
patch = ''.join(''.join(difflib.unified_diff((ROOT / name).read_text().splitlines(True), text.splitlines(True),
                                           fromfile='a/' + name, tofile='b/' + name))
                for name, text in changes.items())
(ROOT / 'docs/implementation/safari-services/root-api.patch').write_text(patch.replace('\n \n', '\n\n'))
print('Returned Safari session/codec patch; shared Source files untouched.')
