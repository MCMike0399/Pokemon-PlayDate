-- Delegated finite choice; existing services render/guard Yes/No and party gifts.
MidgameGymStoryController = {}
function MidgameGymStoryController.enter(state)
    state.dojoGiftStarted = false
end
function MidgameGymStoryController.advance(state)
    if not state.plan or state.plan.scene ~= "dojo-gift" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if state.dojoGiftStarted == "displayed" then
        state.dojoGiftStarted = "offering"
        MidgameGymStoryController.afterDisplay(state)
        return true
    end
    if state.dojoGiftStarted then
        state:finish()
        return true
    end
    state.dojoGiftStarted = true
    -- Source displays the species encyclopedia/cry before asking Yes/No.
    -- EventState owns that seen transaction and returns to advance(). The
    -- selection callback is guarded by this same event epoch and context.
    state:showPokemon({species = state.plan.species, audio = {
        cue = "cry", species = state.plan.species, wait_for_completion = true, owner = "SourceAudio",
    }})
    -- showPokemon's callback calls advance; the next stage is explicit below.
    state.dojoGiftStarted = "displayed"
    return true
end
function MidgameGymStoryController.afterDisplay(state)
    state:source({state.plan.choice_label}, function()
        state:serviceChoice({"YES", "NO"}, function(yes)
            if not yes then
                state:finish()
                return
            end
            local offer <const> = MidgameGymStory.giftOffer(state.id)
            local accepted, result = state.session:purchaseGiftPokemon(offer, state.session:inventory():money())
            if not accepted then
                if result == "box-full" then
                    state:source({"_BoxIsFullText"}, function()
                        state:finish()
                    end)
                else
                    state:fail(result)
                end
                return
            end
            state.committed = true
            state.plan.ram = {wNameBuffer = state.plan.species:upper(),
                wBoxMonNicks = state.plan.species:upper(), wStringBuffer = tostring(result.box or 1)}
            state:source({result.destination == "storage" and "_SentToBoxText" or "_GotMonText"}, function()
                state:finish()
            end)
        end)
    end)
end
