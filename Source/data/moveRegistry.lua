-- Canonical definitions are constructed on request. Assignments and removals
-- retain the historical moveData interface, including stable object identity.
MoveRegistry = {}
local indices = setmetatable({}, {__mode = "k"})

function MoveRegistry.new(factories)
    local values = {}
    local removed = {}
    local registry = {}
    local names = setmetatable({}, {__mode = "k"})
    indices[registry] = names
    local function lookup(_, key)
        if removed[key] then
            return nil
        end
        if values[key] ~= nil then
            return values[key]
        end
        local factory = factories[key]
        if factory then
            local value = factory()
            values[key] = value
            names[value] = key
            return value
        end
    end
    return setmetatable(registry, {
        __index = lookup,
        __newindex = function(_, key, value)
            values[key] = value
            removed[key] = value == nil or nil
            if value ~= nil then
                names[value] = key
            end
        end,
        __pairs = function()
            local key
            local extras = false
            return function()
                if not extras then
                    key = next(factories, key)
                    while key and removed[key] do
                        key = next(factories, key)
                    end
                    if key then
                        return key, lookup(registry, key)
                    end
                    extras = true
                end
                key = next(values, key)
                while key and factories[key] do
                    key = next(values, key)
                end
                if key then
                    return key, values[key]
                end
            end
        end,
    })
end

function MoveRegistry.owns(registry)
    return indices[registry] ~= nil
end

function MoveRegistry.keyOf(registry, move)
    local names = indices[registry]
    local key = names and names[move]
    if key and registry[key] == move then
        return key
    end
end
