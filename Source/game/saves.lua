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

local function saveGame(self)
    BootTrace.mark("Save.begin")
    local payload, problem = capture(self, function()
        return self.game:captureSession()
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
    return GameBootstrap.withLoading("Save", function()
        return saveGame(self)
    end)
end

-- Both permitted capture boundaries share the exact same publication authority.
function GameSaves:_publishPayload(payload)
    local request=self._replacement
    if request and request.session~=self.game.session then
        self.store:cancelReplacement(request.ticket); self._replacement=nil
        return false,{reason="replacement-session-changed"}
    end
    local ok, metadata, published
    if request then
        local publish = ownerPublishers[self]
        if publish then
            ok, metadata, published = publish(payload, request.ticket)
        else
            ok, metadata, published = self.store:replace(payload, request.ticket)
        end
        if ok then self._replacement = nil end
    else
        local publish = ownerPublishers[self]
        if publish then
            ok, metadata, published = publish(payload)
        else
            ok, metadata, published = self.store:save(payload)
        end
    end
    -- Optional read-only observer is installed explicitly by the private
    -- harness. Observe the actual verified disk boundary, never recapture play.
    if ok and self.observeBoundary then
        -- SaveStore returns only the detached data from its exact published
        -- readback. Observing it must not load/decode/encode the same bytes again.
        self.observeBoundary(self.game.session, "saved", published, GameSession._copy(metadata))
    end
    return ok, metadata
end

-- Called only by the YES branch of the Title confirmation. No writes happen
-- here; the exact observation is tied to the newly installed session identity.
function GameSaves:beginNewGame(seed)
    local ticket,problem=self.store:prepareReplacement()
    if not ticket then return false,problem end
    local ok,err=self.game:beginNewSession(seed)
    if not ok then self.store:cancelReplacement(ticket); return false,err end
    if self._replacement then self.store:cancelReplacement(self._replacement.ticket) end
    self._replacement={ticket=ticket,session=self.game.session}
    return true
end

local function continueGame(self)
    if BootTrace then
        BootTrace.mark("Continue.begin")
    end
    local payload, metadata = self.store:load()
    if BootTrace then
        BootTrace.mark("Continue.store.loaded")
        GameBootstrap.yieldIfDue()
    end
    if not payload then return false, metadata end
    local candidate, decodeProblem = SessionCodec.decode(payload, self.game:getSessionDependencies())
    if BootTrace then
        BootTrace.mark("Continue.decoded")
        GameBootstrap.yieldIfDue()
    end
    if not candidate then return false, {reason="invalid-session", error=decodeProblem, store=metadata} end
    if self.game.fieldWorld then
        local prepared,reason=self.game.fieldWorld.prepareContinue(candidate)
        if BootTrace then
            BootTrace.mark("Continue.fieldReload.end")
        GameBootstrap.yieldIfDue()
        end
        if not prepared then return false,{reason="invalid-field-reload",error=reason} end
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

function GameSaves:recover(source)
    return self.store:recover(source)
end

function GameSaves:start()
    self.game.machine:change("title")
end

-- Synchronous trusted-PC transaction; this never makes an ordinary overlay
-- eligible for captureSession. Failed publication restores active-box state.
function GameSaves:changeBoxFromPC(pc,index,epoch)
    if not self.game:isPCSaveBoundary(pc,epoch) then return false,{reason="unsafe-pc-save-state"} end
    local storage=self.game.session:storage()
    if type(index)~="number" or index%1~=0 or index<1 or index>Storage.BOX_COUNT then
        return false,{reason="invalid-box"}
    end
    local previous=storage:activeBox()
    local traversal={location=self.game.session:location(),world=self.game.session:worldData(),checkpoint=self.game.session:checkpoint()}
    local ok,result,metadata=pcall(function()
        assert(storage:selectBox(index))
        local payload, problem = capture(self, function()
            return self.game:captureSessionFromPC(pc, epoch)
        end)
        if not payload then return false,{reason="unsafe-pc-save-state",error=problem} end
        return self:_publishPayload(payload)
    end)
    if not ok or not result then
        assert(storage:selectBox(previous))
        assert(self.game.session:captureTraversal(traversal))
        return false,ok and metadata or {reason="pc-save-error",error=tostring(result)}
    end
    return true,metadata
end
