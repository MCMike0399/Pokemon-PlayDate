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
