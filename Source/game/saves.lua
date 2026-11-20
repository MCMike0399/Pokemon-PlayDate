-- Disk ownership sits beside GameContext; domain/session code stays pure.
Class("GameSaves")
local ownerCaptures = setmetatable({}, {__mode="k"})
local ownerPublishers = setmetatable({}, {__mode="k"})
local function capture(self, callback)
    local export = ownerCaptures[self]
    if export then
        return export(callback)
    end
    return callback()
end
-- The publish and PC bodies live in a standalone pdz so a Hall continue
-- can stay in this boot chunk without raising the contract pool.
GameSaves._ownerPublishers = ownerPublishers
GameSaves._capture = capture

function GameSaves:init(game, prefix)
    self.game = game
    local store, captureExport, publishExport = SessionCodec.gameSaveStore(game, prefix or "adventure")
    self.store = store
    ownerCaptures[self] = captureExport
    ownerPublishers[self] = publishExport
end

function GameSaves:inspect()
    return SessionCodec.load(self.store, self.game:getSessionDependencies())
end

local function saveGame(self, capturePayload)
    BootTrace.mark("Save.begin")
    local payload, problem = capture(self, function()
        return capturePayload()
    end)
    if not payload then
        return false, {reason = "unsafe-save-state", error = problem}
    end
    BootTrace.mark("Save.capture.end")
    GameBootstrap.yieldIfDue()
    local ok, metadata = self:_publishPayload(payload)
    BootTrace.mark("Save.publish.end")
    if DEVICE_TEST_BUILD then
        BootTrace.requestCollect("Save.live")
    end
    return ok, metadata
end

function GameSaves:save()
    -- SaveMenu keeps the map and the text box. Returning true keeps that frame.
    return GameBootstrap.withLoading("Save", function()
        return saveGame(self, function()
            return self.game:captureSession()
        end)
    end, function()
        return true
    end)
end
function GameSaves:saveFromHall(event)
    -- Same frame keep as GameSaves:save. The Hall of Fame save has no
    -- separate loading screen in scripts/HallOfFame.asm.
    return GameBootstrap.withLoading("Save", function()
        return saveGame(self, function()
            return self.game:captureSessionFromHall(event)
        end)
    end, function()
        return true
    end)
end

function GameSaves:_publishPayload(payload)
    local folder, name = "game/", "savesPublish"
    playdate.file.run(folder .. name)
    return self:_publishPayload(payload)
end

-- Called only by the YES branch of the Title confirmation. No writes happen
-- here; the exact observation is tied to the newly installed session identity.
function GameSaves:beginNewGame(seed)
    self:discardPreparedTitle()
    local ticket,problem=self.store:prepareReplacement()
    if not ticket then return false,problem end
    local ok,err=self.game:beginNewSession(seed)
    if not ok then self.store:cancelReplacement(ticket); return false,err end
    if self._replacement then self.store:cancelReplacement(self._replacement.ticket) end
    self._replacement={ticket=ticket,session=self.game.session}
    return true
end

local function prepareContinue(self, phase)
    local payload, metadata = self.store:load()
    if BootTrace then
        BootTrace.mark(phase .. ".store.loaded")
        GameBootstrap.yieldIfDue()
    end
    if not payload then return nil, metadata end
    local candidate, decodeProblem = SessionCodec.decode(payload, self.game:getSessionDependencies())
    if BootTrace then
        BootTrace.mark(phase .. ".decoded")
        GameBootstrap.yieldIfDue()
    end
    if not candidate then return nil, {reason="invalid-session", error=decodeProblem, store=metadata} end
    return {candidate=candidate, payload=payload, metadata=metadata,
        session=self.game.session, store=self.store, fieldWorld=self.game.fieldWorld}
end

local function prepareField(self, record, phase)
    if record.fieldReady then return true end
    if self.game.fieldWorld then
        local ok, reason = self.game.fieldWorld.prepareContinue(record.candidate)
        if BootTrace then
            BootTrace.mark(phase .. ".fieldReload.end")
            GameBootstrap.yieldIfDue()
        end
        if not ok then return false, {reason="invalid-field-reload", error=reason} end
    end
    record.fieldReady = true
    return true
end

function GameSaves:discardPreparedTitle()
    self._titleGeneration = (self._titleGeneration or 0) + 1
    self._preparedTitle = nil
end

function GameSaves:prepareTitle()
    local prepared = self._preparedTitle
    if prepared and prepared.session == self.game.session and prepared.store == self.store
        and prepared.fieldWorld == self.game.fieldWorld then
        return prepared.candidate, prepared.metadata
    end
    self:discardPreparedTitle()
    local generation = self._titleGeneration
    local session, store, fieldWorld = self.game.session, self.store, self.game.fieldWorld
    -- Same store validation and full decode/constructors as inspect/cold
    -- Continue. Retain exact load payload for the existing boundary observer.
    local record, problem = prepareContinue(self, "title.save")
    if not record then return nil, problem end
    -- Field failure must not hide the valid inspected save or recovery actions.
    -- Continue retries through the same owner and reports failure normally.
    prepareField(self, record, "title.save")
    if generation == self._titleGeneration and session == self.game.session
        and store == self.store and fieldWorld == self.game.fieldWorld then
        record.generation = generation
        self._preparedTitle = record
        return record.candidate, record.metadata
    end
    return nil, {reason="stale-title-preparation"}
end

-- A literal import compiles the module into main.pdz and runs boot() on
-- every contract shard. file.run loads the standalone pdz for this save.
local function loadHallContinue(candidate)
    if PostgameStory ~= nil or type(candidate) ~= "table" or type(candidate.location) ~= "function" then
        return nil
    end
    local location = candidate:location()
    if type(location) ~= "table" or location.zone_id ~= "pokered:HALL_OF_FAME" then
        return nil
    end
    local record = type(candidate.hallOfFame) == "function" and candidate:hallOfFame() or nil
    local teams = type(record) == "table" and record.teams or nil
    if type(teams) ~= "table" or #teams < 1 then
        return nil
    end
    if playdate == nil or playdate.file == nil or type(playdate.file.run) ~= "function" then
        return false, "postgame-story-unavailable"
    end
    local folder, name = "game/", "postgameStory"
    playdate.file.run(folder .. name)
    if PostgameStory == nil or type(PostgameStory.relocateContinue) ~= "function" then
        return false, "postgame-story-unavailable"
    end
    local moved, reason = PostgameStory.relocateContinue(candidate)
    if moved == false then return false, reason or "hall-continue-not-relocated" end
    return true
end

local function continueGame(self, prepared)
    if prepared and prepared.generation ~= self._titleGeneration then prepared = nil end
    if BootTrace then
        BootTrace.mark("Continue.begin")
    end
    self:discardPreparedTitle()
    local generation = self._titleGeneration
    if prepared and (prepared.session ~= self.game.session or prepared.store ~= self.store
        or prepared.fieldWorld ~= self.game.fieldWorld) then
        prepared = nil
    end
    local metadata
    if prepared then
        BootTrace.mark("Continue.prepared")
    else
        prepared, metadata = prepareContinue(self, "Continue")
    end
    if not prepared then return false, metadata end
    local fieldOK, fieldProblem = prepareField(self, prepared, "Continue")
    if not fieldOK then return false, fieldProblem end
    if generation ~= self._titleGeneration or prepared.session ~= self.game.session
        or prepared.store ~= self.store or prepared.fieldWorld ~= self.game.fieldWorld then
        return false, {reason="stale-title-preparation"}
    end
    local candidate, payload = prepared.candidate, prepared.payload
    metadata = prepared.metadata
    local loaded, why = loadHallContinue(candidate)
    if loaded == false then
        return false, {reason = why or "hall-continue-not-relocated"}
    end
    if BootTrace then
        BootTrace.mark("Continue.map.begin")
    end
    local ok, problem = self.game:installSession(candidate)
    if BootTrace then
        BootTrace.mark("Continue.map.end")
    end
    if ok then
        if self._replacement then self.store:cancelReplacement(self._replacement.ticket); self._replacement=nil end
        if self.observeBoundary then
            self.observeBoundary(candidate, "loaded", payload, metadata)
        end
        self.game:offerPartyLearning()
    end
    if BootTrace then
        BootTrace.mark("Continue.end")
    end
    if BootTrace and DEVICE_TEST_BUILD and ok then
        BootTrace.requestCollect("Continue.live")
    end
    return ok, ok and metadata or {reason = "cannot-install-session", error = problem}
end

function GameSaves:continueGame()
    if GameBootstrap then
        return GameBootstrap.withLoading("Continue", function()
            return continueGame(self)
        end)
    end
    return continueGame(self)
end

-- Explicit title-only opt-in. Public continueGame still reloads disk on every
-- call; only this method consumes the fully checked title observation once.
function GameSaves:continuePreparedTitle()
    local prepared = self._preparedTitle
    return GameBootstrap.withLoading("Continue", function()
        return continueGame(self, prepared)
    end)
end

function GameSaves:recover(source)
    self:discardPreparedTitle()
    return self.store:recover(source)
end

function GameSaves:start()
    self.game.machine:change("title")
end

function GameSaves:changeBoxFromPC(pc,index,epoch)
    local folder, name = "game/", "savesPublish"
    playdate.file.run(folder .. name)
    return self:changeBoxFromPC(pc,index,epoch)
end
