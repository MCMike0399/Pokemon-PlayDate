-- Publish and PC box saves. Loaded on first use so the boot chunk stays smaller.
function GameSaves:_publishPayload(payload)
    self:discardPreparedTitle()
    local request=self._replacement
    if request and request.session~=self.game.session then
        self.store:cancelReplacement(request.ticket); self._replacement=nil
        return false,{reason="replacement-session-changed"}
    end
    local publishers = GameSaves._ownerPublishers
    local ok, metadata, published
    if request then
        local publish = publishers[self]
        if publish then
            ok, metadata, published = publish(payload, request.ticket)
        else
            ok, metadata, published = self.store:replace(payload, request.ticket)
        end
        if ok then self._replacement = nil end
    else
        local publish = publishers[self]
        if publish then
            ok, metadata, published = publish(payload)
        else
            ok, metadata, published = self.store:save(payload)
        end
    end
    SessionCodec.releaseValidationProof()
    if ok and self.observeBoundary then
        self.observeBoundary(self.game.session, "saved", published, GameSession._copy(metadata))
    end
    SessionCodec.releaseValidationProof()
    return ok, metadata
end

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
        local payload, problem = GameSaves._capture(self, function()
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
