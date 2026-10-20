-- lib/statemachine.lua — Hierarchical, stack-based state machine
--
-- Two classes:
--
--   State — base class for game states. Lifecycle hooks:
--     enter(...)      — became active (change/push args forwarded)
--     exit()          — removed (change away, or popped)
--     pause()         — another state was pushed on top
--     resume(...)     — the state above was popped (pop args forwarded)
--     update()        — every frame, for EVERY state on the stack (bottom→top)
--     draw()          — every frame, for EVERY state on the stack (bottom→top)
--     handleInput()   — every frame, ONLY for the top state
--
--   StateMachine — owns named states and an active stack.
--     register(name, state)  — state: State instance or plain callbacks table
--     change(name, ...)      — exit the whole stack, enter `name` as the base
--     push(name, ...)        — pause the top, overlay `name` (dialogs, menus)
--     pop(...)               — exit the top, resume the state below
--     update() / handleInput() / draw() — drive the stack each frame
--     getCurrent()           — top state name; current()/getState(name) for objects
--     stackNames()           — "overworld>dialog" (debug/triage)
--
-- Hierarchy by composition: a State may own its own StateMachine and forward
-- update/draw/handleInput to it (see OverworldState substates, Battle phases).
-- Emits "changed" (kind, from, to) via Signal for tracing/tooling.

Class("State")

function State:init(name)
    self.name = name or self:getClassName()
    self.machine = nil   -- set by StateMachine:register
end

function State:enter(...) end
function State:exit() end
function State:pause() end
function State:resume(...) end
function State:update() end
function State:draw() end
function State:handleInput() end

-- True when this state is the top of its machine's stack (receives input)
function State:isTop()
    return self.machine ~= nil and self.machine:current() == self
end

-- ============================================================

Class("StateMachine"):includes(Signal)

function StateMachine:init()
    self.states = {}
    self.stack = {}
    self._generation = 0
    self._transitioning = false
    self._pending = {}
end

-- Accepts a State instance or a plain table of callbacks
-- ({enter=, exit=, update=, draw=, handleInput=, pause=, resume=}).
function StateMachine:register(name, state)
    if type(state.is) ~= "function" or not state:is("State") then
        local callbacks = state
        state = State(name)
        for k, v in pairs(callbacks) do
            state[k] = v
        end
    end
    state.name = name
    state.machine = self
    self.states[name] = state
    return state
end

function StateMachine:get(name)
    return self.states[name]
end

function StateMachine:current()
    return self.stack[#self.stack]
end

function StateMachine:getCurrent()
    local top = self.stack[#self.stack]
    return top and top.name or nil
end

function StateMachine:is(name)
    return self:getCurrent() == name
end

function StateMachine:depth()
    return #self.stack
end

function StateMachine:stackNames()
    local names = {}
    for i, state in ipairs(self.stack) do
        names[i] = state.name
    end
    return table.concat(names, ">")
end

local function resolve(self, name)
    local state = self.states[name]
    if not state then
        error("StateMachine: unknown state '" .. tostring(name) .. "'", 3)
    end
    return state
end

-- Lifecycle-triggered transitions are queued until the current transition
-- finishes: exit/changed/enter cannot recursively overwrite a half-built stack.
-- Calls from update/draw/input remain synchronous. State objects are registered
-- once and cannot occupy two overlay slots simultaneously.
function StateMachine:_transition(kind, name, ...)
    local state = name and resolve(self, name) or nil
    local result = state or self:current()
    local request = { kind = kind, state = state, args = table.pack(...) }
    self._pending[#self._pending + 1] = request
    if self._transitioning then return result end
    self._transitioning = true
    local ok, err = pcall(function()
        local count = 0
        while #self._pending > 0 do
            count = count + 1
            assert(count <= 100, "StateMachine: lifecycle transition loop")
            local nextRequest = table.remove(self._pending, 1)
            self:_applyTransition(nextRequest)
        end
    end)
    self._transitioning = false
    if not ok then
        self._pending = {}
        error(err, 0)
    end
    return result
end

function StateMachine:_applyTransition(request)
    local kind, state, args = request.kind, request.state, request.args
    local top = self:current()
    if kind == "push" then
        for _, active in ipairs(self.stack) do
            assert(active ~= state, "StateMachine: state already on stack: " .. state.name)
        end
    elseif kind == "pop" and not top then return end
    self._generation = self._generation + 1
    if kind == "change" then
        for i = #self.stack, 1, -1 do
            local exiting = self.stack[i]
            self.stack[i] = nil
            exiting:exit()
        end
        self.stack[1] = state
        self:emit("changed", "change", top and top.name, state.name)
        state:enter(table.unpack(args, 1, args.n))
    elseif kind == "push" then
        if top then top:pause() end
        self.stack[#self.stack + 1] = state
        self:emit("changed", "push", top and top.name, state.name)
        state:enter(table.unpack(args, 1, args.n))
    else
        self.stack[#self.stack] = nil
        top:exit()
        local below = self:current()
        self:emit("changed", "pop", top.name, below and below.name)
        if below then below:resume(table.unpack(args, 1, args.n)) end
    end
end

function StateMachine:change(name, ...)
    return self:_transition("change", name, ...)
end

function StateMachine:push(name, ...)
    return self:_transition("push", name, ...)
end

function StateMachine:pop(...)
    return self:_transition("pop", nil, ...)
end

-- Update every stacked state bottom→top (the world keeps animating under
-- overlays). If a state transitions the machine mid-update, the rest of this
-- frame's pass is skipped — the new stack takes over next frame.
function StateMachine:update()
    local stack = self.stack
    local generation = self._generation
    local i = 1
    while i <= #stack do
        local state = stack[i]
        state:update()
        if self._generation ~= generation then return end
        i = i + 1
    end
end

-- Input goes to the top state only. Kept separate from update() so a state
-- that owns a nested machine can forward input only while it is itself top.
function StateMachine:handleInput()
    local top = self.stack[#self.stack]
    if top then top:handleInput() end
end

function StateMachine:draw()
    local stack = self.stack
    local generation = self._generation
    local i = 1
    while i <= #stack do
        local state = stack[i]
        state:draw()
        if self._generation ~= generation then return end
        i = i + 1
    end
end
