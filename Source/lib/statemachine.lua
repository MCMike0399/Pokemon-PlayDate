local states = {}
local currentState = nil

function registerState(name, callbacks)
    states[name] = callbacks
end

function changeState(newState, ...)
    if currentState and states[currentState] and states[currentState].exit then
        states[currentState].exit()
    end
    currentState = newState
    if states[currentState] and states[currentState].enter then
        states[currentState].enter(...)
    end
end

function getCurrentState()
    return currentState
end

function updateCurrentState()
    if currentState and states[currentState] and states[currentState].update then
        states[currentState].update()
    end
end

function drawCurrentState()
    if currentState and states[currentState] and states[currentState].draw then
        states[currentState].draw()
    end
end

function inputCurrentState(button)
    if currentState and states[currentState] and states[currentState].input then
        states[currentState].input(button)
    end
end
