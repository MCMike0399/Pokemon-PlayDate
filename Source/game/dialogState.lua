-- game/dialogState.lua — Dialog box as a pushed overlay
--
-- Pushed onto the root machine, so the overworld below keeps animating and
-- drawing; this state only owns the text box and the A button. When the last
-- line is dismissed it pops itself, then runs the onComplete callback (which
-- may immediately change() into a battle).

Class("DialogState"):extends(State)

function DialogState:init(game)
    DialogState.super.init(self, "dialog")
    self.game = game
    self.dialog = Dialog()
    self.onComplete = nil
    self.done = false
    self.generation = 0
end

function DialogState:enter(lines, onComplete)
    self.generation = self.generation + 1
    self.onComplete = onComplete
    self.done = false
    self.dialog:show(lines, function()
        self.done = true
    end)
end

function DialogState:exit()
    self.dialog.isActive = false
    self.onComplete = nil
end

function DialogState:update()
    self.dialog:update()
end

function DialogState:handleInput()
    self.dialog:handleInput()
    if self.done then
        self.done = false
        local callback = self.onComplete
        self.machine:pop()
        if callback then callback() end
    end
end

function DialogState:draw()
    local camera = self.game.camera
    camera:reset()
    self.dialog:draw()
    camera:apply()
end
