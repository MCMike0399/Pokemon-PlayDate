-- Field A/B arbitration. A brief A grace period recognizes either chord order.
-- A consumed gesture cannot interact, pause or run again until both are released.
Class("FieldGestures")

function FieldGestures:init()
    self:reset()
end

function FieldGestures:reset()
    self.phase = "consumed"
    self.frames = 0
    self.moved = false
end

function FieldGestures:consume(action)
    self:reset()
    return action, false
end

function FieldGestures:step(a, b, direction, moving)
    if self.phase == "consumed" then
        if not a and not b then
            self.phase = "idle"
        end
        return nil, false
    end
    if a and b then
        return self:consume("registered")
    end
    if self.phase == "idle" then
        if a then
            self.phase = "a"
            self.frames = 1
        elseif b then
            self.phase = "b"
            self.frames = 1
            self.moved = direction or moving
        end
    elseif self.phase == "a" then
        self.frames = self.frames + 1
        if not a or self.frames >= 4 then
            return self:consume("interact")
        end
    elseif self.phase == "b" then
        if not b then
            if self.frames < 9 and not self.moved then
                return self:consume("pause")
            end
            return self:consume()
        end
        self.frames = self.frames + 1
        self.moved = self.moved or direction or moving
    end
    return nil, self.phase == "b" and b and direction
end
