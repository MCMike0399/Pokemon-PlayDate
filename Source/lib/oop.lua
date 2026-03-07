-- lib/oop.lua — OOP Library for Pokemon Playdate
--
-- Lightweight, Playdate-optimized OOP that works alongside CoreLibs/object.
-- Use CoreLibs class() for sprite-based entities (Player, NPC).
-- Use this for everything else: data models, systems, states.
--
-- Features:
--   Class(name)              — define a class, registered as global
--     :extends(Parent)       — single inheritance (methods flattened for O(1) lookup)
--     :includes(Mixin, ...)  — trait composition
--     :abstract("m1", "m2")  — enforce method contracts
--   Mixin(name)              — define a composable trait
--   Signal                   — built-in mixin for observer pattern
--   Pool(cls, prewarm)       — object recycling for GC management
--
-- Usage:
--   local Animal = Class("Animal")
--   function Animal:init(name) self.name = name end
--
--   local Dog = Class("Dog"):extends(Animal)
--   function Dog:init(name, breed)
--       Dog.super.init(self, name)
--       self.breed = breed
--   end
--
--   local Emitter = Class("Emitter"):includes(Signal)
--   local e = Emitter()
--   e:on("damage", function(amt) print(amt) end)
--   e:emit("damage", 42)

-- Localize for performance
local setmetatable <const> = setmetatable
local getmetatable <const> = getmetatable
local rawget <const> = rawget
local pairs <const> = pairs
local ipairs <const> = ipairs
local type <const> = type
local error <const> = error
local select <const> = select
local insert <const> = table.insert
local remove <const> = table.remove

-- ============================================================
-- BASE — root of all Class-created objects
-- ============================================================

local Base = {}
Base.__index = Base
Base.__name = "Base"
Base.__parent = nil
Base.__mixins = {}

function Base:is(classOrName)
    local current = getmetatable(self)
    if type(classOrName) == "string" then
        while current do
            if current.__name == classOrName then return true end
            current = current.__parent
        end
    else
        while current do
            if current == classOrName then return true end
            current = current.__parent
        end
    end
    return false
end

function Base:hasMixin(mixin)
    local cls = getmetatable(self)
    if not cls or not cls.__mixins then return false end
    for _, m in ipairs(cls.__mixins) do
        if m == mixin then return true end
    end
    return false
end

function Base:getClass()
    return getmetatable(self)
end

function Base:getClassName()
    return getmetatable(self).__name
end

-- Builder: set parent class (single inheritance).
-- Copies parent functions into child table for O(1) method lookup.
-- Metatable chain kept as fallback for methods added to parent later.
function Base:extends(parent)
    self.__parent = parent
    self.super = parent

    -- Flatten: copy parent functions for direct lookup
    for k, v in pairs(parent) do
        if type(v) == "function" and rawget(self, k) == nil then
            self[k] = v
        end
    end

    if parent.__abstracts then
        self.__abstracts = self.__abstracts or {}
        for k, v in pairs(parent.__abstracts) do
            self.__abstracts[k] = v
        end
    end

    if parent.__mixins then
        for _, mixin in ipairs(parent.__mixins) do
            local found = false
            for _, existing in ipairs(self.__mixins) do
                if existing == mixin then found = true; break end
            end
            if not found then
                insert(self.__mixins, mixin)
            end
        end
        -- Inherit parent's mixin init chain
        if parent.__mixinInits then
            self.__mixinInits = self.__mixinInits or {}
            for _, fn in ipairs(parent.__mixinInits) do
                insert(self.__mixinInits, fn)
            end
        end
    end

    local mt = getmetatable(self)
    mt.__index = parent
    return self
end

-- Builder: mix in one or more traits (avoids {…} allocation via select)
function Base:includes(...)
    for i = 1, select("#", ...) do
        local mixin = select(i, ...)
        insert(self.__mixins, mixin)

        for k, v in pairs(mixin) do
            if k ~= "init" and k ~= "__name" and k ~= "included"
               and type(v) == "function" and not rawget(self, k) then
                self[k] = v
            end
        end

        -- Pre-build mixin init chain for fast instantiation
        if mixin.init then
            if not self.__mixinInits then self.__mixinInits = {} end
            insert(self.__mixinInits, mixin.init)
        end

        if mixin.included then
            mixin.included(self)
        end
    end
    return self
end

-- Builder: declare abstract methods (enforced at first instantiation)
function Base:abstract(...)
    self.__abstracts = self.__abstracts or {}
    for i = 1, select("#", ...) do
        self.__abstracts[select(i, ...)] = true
    end
    return self
end

-- ============================================================
-- CLASS(name) — create and register a new class
-- ============================================================

function Class(name)
    local cls = {}
    cls.__index = cls
    cls.__name = name
    cls.__parent = Base
    cls.__mixins = {}
    cls.__mixinInits = nil
    cls.__abstracts = nil
    cls.__abstractsOk = false
    cls.super = Base

    setmetatable(cls, {
        __index = Base,

        __call = function(_, ...)
            -- Enforce abstract methods (cached after first success)
            if cls.__abstracts and not cls.__abstractsOk then
                for method in pairs(cls.__abstracts) do
                    if type(cls[method]) ~= "function" then
                        error(cls.__name .. ": abstract method '"
                              .. method .. "' not implemented")
                    end
                end
                cls.__abstractsOk = true
            end

            local instance = setmetatable({}, cls)

            -- Mixin init (pre-filtered, no conditional per mixin)
            local inits = cls.__mixinInits
            if inits then
                for i = 1, #inits do
                    inits[i](instance)
                end
            end

            -- Class init
            if instance.init then
                instance:init(...)
            end

            return instance
        end,

        __tostring = function()
            return "class<" .. name .. ">"
        end,
    })

    _G[name] = cls
    return cls
end

-- ============================================================
-- MIXIN(name) — create a composable trait table
-- ============================================================

function Mixin(name)
    return { __name = name }
end

-- ============================================================
-- SIGNAL — built-in mixin for the observer pattern
--
-- Provides: on, off, once, emit, clearListeners
-- Safe to add/remove listeners during emit (mark-and-compact).
-- ============================================================

Signal = Mixin("Signal")

function Signal.init(self)
    self._listeners = {}
end

function Signal:on(event, fn)
    if not self._listeners then self._listeners = {} end
    if not self._listeners[event] then
        self._listeners[event] = {}
    end
    insert(self._listeners[event], fn)
    return self
end

function Signal:off(event, fn)
    if not self._listeners or not self._listeners[event] then return self end
    local list = self._listeners[event]
    for i = #list, 1, -1 do
        if list[i] == fn then
            if self._emitting == event then
                list[i] = false  -- defer removal until emit completes
            else
                remove(list, i)
            end
            break
        end
    end
    return self
end

function Signal:once(event, fn)
    local wrapper
    wrapper = function(...)
        self:off(event, wrapper)
        fn(...)
    end
    return self:on(event, wrapper)
end

function Signal:emit(event, ...)
    if not self._listeners or not self._listeners[event] then return self end
    local list = self._listeners[event]
    self._emitting = event
    local n = #list
    local dirty = false
    for i = 1, n do
        local fn = list[i]
        if fn then
            fn(...)
        else
            dirty = true
        end
    end
    self._emitting = nil
    -- Compact any entries marked false by off() during iteration
    if dirty then
        local j = 0
        for i = 1, #list do
            if list[i] then
                j = j + 1
                if j ~= i then list[j] = list[i] end
            end
        end
        for i = j + 1, #list do
            list[i] = nil
        end
    end
    return self
end

function Signal:clearListeners(event)
    if not self._listeners then return self end
    if event then
        self._listeners[event] = nil
    else
        self._listeners = {}
    end
    return self
end

-- ============================================================
-- POOL(cls, prewarmCount) — object recycling for GC management
--
-- Classes used with Pool should implement:
--   :reset(...)      — reinitialize when pulled from pool
--   :deactivate()    — cleanup when returned to pool
-- ============================================================

function Pool(cls, prewarmCount)
    local pool = {
        _available = {},
        _cls = cls,
        _total = 0,
        _active = 0,
    }

    function pool:get(...)
        local obj
        if #self._available > 0 then
            obj = remove(self._available)
            if obj.reset then
                obj:reset(...)
            end
        else
            obj = self._cls(...)
            self._total += 1
        end
        self._active += 1
        return obj
    end

    function pool:release(obj)
        if obj.deactivate then
            obj:deactivate()
        end
        insert(self._available, obj)
        self._active -= 1
    end

    function pool:prewarm(n)
        for _ = 1, n do
            local obj = self._cls()
            if obj.deactivate then
                obj:deactivate()
            end
            insert(self._available, obj)
            self._total += 1
        end
    end

    function pool:drain()
        self._available = {}
    end

    function pool:totalCreated()
        return self._total
    end

    function pool:available()
        return #self._available
    end

    function pool:activeCount()
        return self._active
    end

    if prewarmCount and prewarmCount > 0 then
        pool:prewarm(prewarmCount)
    end

    return pool
end
