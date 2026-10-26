-- Bespoke scenes only. Ordinary source interactions live in data/sourceEvents.json.
SourceEventHandlers = {}
local function flag(state, id) return state.flags[id] == true end
local function item(state, id) return state.items[id] or 0 end
local function dialogue(...) return { op = "dialog", labels = { ... } } end
SourceEventHandlers["pokered:OAKS_LAB:script:parcel-handoff"] = function(state)
    if flag(state, "EVENT_GOT_POKEDEX") then
        return { status = "already-complete", steps = { dialogue("_OaksLabOak1PokemonAroundTheWorldText") } }
    end
    if item(state, "oaksParcel") == 0 then
        return { status = "no-item", steps = { dialogue("_OaksLabOak1RaiseYourYoungPokemonText") } }
    end
    assert(flag(state, "EVENT_GOT_OAKS_PARCEL") and item(state, "oaksParcel") == 1, "invalid parcel quest state")
    return { status = "ready", scene = "oak-pokedex", source = "scripts/OaksLab.asm:OaksLabOakGivesPokedexScript",
        steps = { dialogue("_OaksLabOak1DeliverParcelText", "_OaksLabOak1ParcelThanksText"),
            dialogue("_OaksLabRivalWhatDidYouCallMeForText", "_OaksLabOakIHaveARequestText", "_OaksLabOakMyInventionPokedexText", "_OaksLabOakGotPokedexText", "_OaksLabOakThatWasMyDreamText", "_OaksLabRivalLeaveItAllToMeText") },
        required_actor_sequence = "rival arrival, Oak/rival facing, Pokédex object removal, rival departure; adapted to protected authored lab by root",
        expected = { flags = { EVENT_GOT_OAKS_PARCEL = true, EVENT_OAK_GOT_PARCEL = false, EVENT_GOT_POKEDEX = false }, items = { oaksParcel = 1 } },
        changes = { items = { { op = "handoff", id = "oaksParcel", quantity = 1 } }, flags = { EVENT_OAK_GOT_PARCEL = true, EVENT_GOT_POKEDEX = true } } }
end
