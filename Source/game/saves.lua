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
    return self.store:save(payload)
end

function GameSaves:continueGame()
    local candidate, metadata = self:inspect()
    if not candidate then return false, metadata end
    local ok, problem = self.game:installSession(candidate)
    if ok then self.game:offerPartyLearning() end
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
        return self.store:save(payload)
    end)
    if not ok or not result then
        assert(storage:selectBox(previous))
        assert(self.game.session:captureTraversal(traversal))
        return false,ok and metadata or {reason="pc-save-error",error=tostring(result)}
    end
    return true,metadata
end
