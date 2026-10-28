-- Root applies inside GameSession, where state/copy/flags/dex are private.
-- CoinWallet's existing schema4 field/getter must be installed first. No codec
-- field or separate economy owner is added by these Celadon operations.
function GameSession:commitCeladonService(operation, expected)
    local current = state[self]
    local called, prepared = pcall(function()
        assert(GameSession.activeRNGSession() == self, "inactive-Celadon-session")
        assert(FieldMoves.same(CeladonEconomy.observe(self), expected), "stale-Celadon-service")
        local plan, reason = CeladonEconomy.prepare(expected, operation)
        if not plan then error(reason, 0) end
        local candidateCoins = CoinWallet.normalize(plan.coins)
        local combined = copy(current.questFlags)
        for id, value in pairs(plan.flags) do combined[id] = value end
        combined = flags(combined, 4096)
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, plan.bag))
        local destination, mon, stream
        local discovered = copy(current.dex)
        if plan.pokemon then
            destination = current.party:count() < Party.CAPACITY and "party" or "storage"
            if destination == "storage" and current.storage:count() >= Storage.BOX_CAPACITY then
                error("box-full", 0)
            end
            stream = RulesRNG.new(1)
            stream:restoreData(self:rngData())
            mon, reason = Specimen.create(plan.pokemon.species, plan.pokemon.level, "gift", stream)
            assert(mon, reason)
            assert(PokemonCodec.encode(mon), "invalid-Celadon-prize-specimen")
            discovered.seen[mon.species], discovered.owned[mon.species] = true, true
        end
        return {coins=candidateCoins,flags=combined,bag=bag:toData(),dex=dex(discovered),
            mon=mon,destination=destination,rng=stream and stream:snapshot(),item=plan.item,kind=plan.kind,
            received=plan.received,dropped=plan.dropped}
    end)
    if not called then return false, tostring(prepared) end
    local index
    if prepared.mon then
        local claimed
        if prepared.destination == "party" then claimed,index = current.party:add(prepared.mon)
        else claimed,index = current.storage:receive(prepared.mon) end
        if not claimed then return false, index end
    end
    assert(Inventory._replaceData(current.inventory, prepared.bag))
    current.coins, current.questFlags, current.dex = prepared.coins, prepared.flags, prepared.dex
    if prepared.rng then RulesRNG.restore(prepared.rng) end
    self:invalidateFieldWorldContext()
    return true, {kind=prepared.kind,item=prepared.item,destination=prepared.destination,index=index,
        received=prepared.received,dropped=prepared.dropped,
        box=prepared.destination == "storage" and current.storage:activeBox() or nil}
end
