-- Detached economy planning. GameSession alone publishes bag/money/coin/flag
-- changes or claims a Gen V specimen. Callers never supply prices or payouts.
CeladonEconomy = {}
local function copy(value)
    return GameSession._copy(value)
end
local function reject(reason)
    return nil, reason
end
function CeladonEconomy.observe(session)
    assert(type(session.coins) == "function", "CoinWallet session owner required")
    return {coins = CoinWallet.normalize(session:coins()), bag = session:inventory():toData(),
        flags = session:flags().quest, epoch = session:fieldWorldEpoch()}
end
function CeladonEconomy.prepare(observation, operation)
    assert(type(operation) == "table" and type(operation.kind) == "string", "bounded Celadon operation required")
    local policy = CeladonServiceData.policy()
    local coins = CoinWallet.normalize(observation.coins)
    local bag = assert(Inventory.fromData(ItemData.definitions, copy(observation.bag)))
    local plan = {coins = coins, flags = {}, kind = operation.kind}
    if operation.kind == "vending" then
        local drink = policy.drinks[operation.choice]
        assert(drink, "source vending choice required")
        -- Source checks only ¥200, then SubBCD clamps at zero. Preserve both
        -- the displayed prices and that exact low-funds source behavior.
        if bag:money() < policy.vending_minimum_money then return reject("insufficient-money") end
        local accepted, reason = bag:add(drink.item, 1)
        if not accepted then return reject(reason) end
        assert(bag:spend(math.min(bag:money(), drink.price)))
        plan.item = drink.item
    elseif operation.kind == "coin-exchange" then
        if bag:quantity("coinCase") == 0 then return reject("no-coin-case") end
        if coins >= policy.coin_sale.full_threshold then return reject("coin-case-full") end
        if bag:money() < policy.coin_sale.price then return reject("insufficient-money") end
        assert(bag:spend(policy.coin_sale.price))
        plan.coins = math.min(CoinWallet.limit(), coins + policy.coin_sale.coins)
    elseif operation.kind == "drink-girl" then
        local drink = policy.drinks[operation.choice]
        assert(drink, "source drink choice required")
        if observation.flags[drink.flag] then return reject("already-gave-drink") end
        if bag:quantity(drink.item) == 0 then return reject("no-drink") end
        assert(bag:consume(drink.item, 1))
        local accepted, reason = bag:add(drink.tm, 1)
        if not accepted then return reject(reason) end
        plan.flags[drink.flag] = true
        plan.item = drink.tm
    elseif operation.kind == "coin-gift" then
        local gift = assert(policy.coin_gifts[operation.id], "source coin giver required")
        if observation.flags[gift.flag] then return reject("already-complete") end
        if bag:quantity("coinCase") == 0 then return reject("no-coin-case") end
        local full = gift.exact_full and coins == 9990 or not gift.exact_full and coins >= 9990
        if full then return reject("coin-case-full") end
        plan.coins = math.min(CoinWallet.limit(), coins + gift.coins)
        plan.flags[gift.flag] = true
    elseif operation.kind == "hidden-coins" then
        local hidden
        for _, candidate in ipairs(policy.hidden_coins) do
            if candidate.id == operation.id then hidden = candidate end
        end
        assert(hidden and not hidden.shadowed_by_slot, "reachable source hidden coin required")
        if bag:quantity("coinCase") == 0 then return reject("no-coin-case") end
        if observation.flags[hidden.flag] then return reject("already-complete") end
        plan.coins = math.min(CoinWallet.limit(),coins+hidden.credited_coins)
        plan.flags[hidden.flag] = true
        plan.received = hidden.credited_coins
        plan.dropped = plan.coins == CoinWallet.limit()
    elseif operation.kind == "prize" then
        local window = assert(policy.prizes[operation.window], "source prize window required")
        local prize = assert(window[operation.choice], "source prize choice required")
        if bag:quantity("coinCase") == 0 then return reject("no-coin-case") end
        if coins < prize.price then return reject("insufficient-coins") end
        if prize.item then
            local accepted, reason = bag:add(prize.item, 1)
            if not accepted then return reject(reason) end
            plan.item = prize.item
        else
            plan.pokemon = {species = prize.species, level = prize.level}
        end
        plan.coins = coins - prize.price
    else
        error("unsupported Celadon economy operation")
    end
    plan.bag = bag:toData()
    return plan
end
