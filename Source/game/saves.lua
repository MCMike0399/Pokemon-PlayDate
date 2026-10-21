-- Disk ownership sits beside GameContext; domain/session code stays pure.
Class("GameSaves")

function GameSaves:init(game, prefix)
    self.game = game
    self.store = SessionCodec.store(prefix or "adventure", game:getSessionDependencies())
end

function GameSaves:inspect()
    return SessionCodec.load(self.store, self.game:getSessionDependencies())
end

function GameSaves:save()
    local payload, problem = self.game:captureSession()
    if not payload then return false, {reason = "unsafe-save-state", error = problem} end
    return self:_publishPayload(payload)
end

-- Both permitted capture boundaries share the exact same publication authority.
function GameSaves:_publishPayload(payload)
    local request=self._replacement
    if request and request.session~=self.game.session then
        self.store:cancelReplacement(request.ticket); self._replacement=nil
        return false,{reason="replacement-session-changed"}
    end
    if request then
        local ok,metadata=self.store:replace(payload,request.ticket)
        if ok then self._replacement=nil end
        return ok,metadata
    end
    return self.store:save(payload)
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

function GameSaves:continueGame()
    local candidate, metadata = self:inspect()
    if not candidate then return false, metadata end
    local ok, problem = self.game:installSession(candidate)
    if ok then
        if self._replacement then self.store:cancelReplacement(self._replacement.ticket); self._replacement=nil end
        self.game:offerPartyLearning()
    end
    return ok, ok and metadata or {reason = "cannot-install-session", error = problem}
end

function GameSaves:recover(source)
    return self.store:recover(source)
end

function GameSaves:start()
    local candidate, metadata = self:inspect()
    if candidate or metadata.reason ~= "empty" then
        self.game.machine:change("title")
    else
        assert(self.game:beginNewSession(RulesRNG.snapshot().seed))
        self.game.machine:push("dialog", Story.openingLines)
    end
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
        local payload,problem=self.game:captureSessionFromPC(pc,epoch)
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
