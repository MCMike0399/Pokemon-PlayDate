Class("StateMachine")

function StateMachine:init()
    self.states = {}
    self.currentState = nil
end

function StateMachine:register(name, callbacks)
    self.states[name] = callbacks
end

function StateMachine:change(newState, ...)
    if self.currentState and self.states[self.currentState] and self.states[self.currentState].exit then
        self.states[self.currentState].exit()
    end
    self.currentState = newState
    if self.states[self.currentState] and self.states[self.currentState].enter then
        self.states[self.currentState].enter(...)
    end
end

function StateMachine:getCurrent()
    return self.currentState
end

function StateMachine:update()
    if self.currentState and self.states[self.currentState] and self.states[self.currentState].update then
        self.states[self.currentState].update()
    end
end

function StateMachine:draw()
    if self.currentState and self.states[self.currentState] and self.states[self.currentState].draw then
        self.states[self.currentState].draw()
    end
end

function StateMachine:input(button)
    if self.currentState and self.states[self.currentState] and self.states[self.currentState].input then
        self.states[self.currentState].input(button)
    end
end
