-- Extend the existing SourceEvents -> EventState -> services -> gifts chain.
-- This installs one bespoke descriptor, never another dispatcher/provider.
local gfx <const> = playdate.graphics
local ID <const> = "pokered:DAYCARE:objects:1"
local PREFIX <const> = "_DaycareGentleman"
-- The existing prepared-text resolver already verifies the source revision
-- and returns detached recipes; share it rather than decode a second corpus.
function Daycare.text(label)
    return VermilionGifts.text(label)
end
function Daycare.actorMetadata()
    return {visibility={}}
end
function Daycare.install()
    assert(not SourceEvents.has(ID) and not SourceEventHandlers[ID], "duplicate Day Care event")
    SourceEventHandlers[ID] = function()
        return {status="ready", scene="daycare", service="daycare", steps={}}
    end
    SourceEvents.registerEventSource("daycare", Daycare.policy().events)
    SourceEvents.registerTextSource("daycare", Daycare.text)
end
Class("DaycareState"):extends(VermilionStoryState)
function DaycareState:enter(id, options)
    self.daycareStarted = false
    DaycareState.super.enter(self, id, options)
end
function DaycareState:advance()
    if not self.plan or self.plan.scene ~= "daycare" then
        return DaycareState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then
        return
    end
    if self.daycareStarted then
        self:finish()
        return
    end
    self.daycareStarted = true
    if Daycare.observe(self.session).pokemon then
        self:daycareWithdraw()
    else
        self:daycareText({"IntroText"}, function()
            self:serviceChoice({"YES", "NO"}, function(yes)
                if yes then
                    self:daycareSelect()
                else
                    self:daycareText({"ComeAgainText"})
                end
            end)
        end)
    end
end
function DaycareState:daycareText(suffixes, callback)
    local labels = {}
    for i, suffix in ipairs(suffixes) do
        labels[i] = PREFIX .. suffix
    end
    self:serviceText(labels, callback)
end
function DaycareState:daycareFailure(reason)
    if reason == "last-member" then
        self:daycareText({"OnlyHaveOneMonText"})
    elseif reason == "hm-move" then
        self:daycareText({"CantAcceptMonWithHMText"})
    elseif reason == "party-full" then
        self:daycareText({"NoRoomForMonText"})
    elseif reason == "insufficient-money" then
        self:daycareText({"NotEnoughMoneyText"})
    elseif reason == "last-usable" or reason == "pending-progression" then
        local message = reason == "last-usable" and "Keep a POKEMON that can battle with you."
            or "Finish this POKEMON's learning or evolution first."
        self:dialog({{label="daycare-guard", text=message}}, function()
            self:finish()
        end)
    else
        self:fail(reason)
    end
end
function DaycareState:daycareSelect()
    if self.session:party():count() <= 1 then
        self:daycareFailure("last-member")
        return
    end
    self:daycareText({"WhichMonText"}, function()
        self.phase = "daycare-party"
        self.machine:push("party", {
            mode="daycare", allowCancel=true,
            onSelect=self:guard(function(index)
                local request, plan = Daycare.prepare(self.session, "deposit", index)
                if plan.status ~= "ready" then
                    self.session:resolveDaycare(request, false)
                    self:daycareFailure(plan.status)
                    return
                end
                self.plan.ram = {wNameBuffer=plan.pokemon.name}
                self:daycareText({"WillLookAfterMonText"}, function()
                    local ok, result = self.session:resolveDaycare(request, true)
                    if not ok then
                        self:daycareFailure(result)
                        return
                    end
                    self.committed = true
                    self:daycareText({"ComeSeeMeInAWhileText"})
                end)
            end),
            onCancel=nil,
        })
        -- Both callbacks must share the same EventState serial. Creating a
        -- second guard would invalidate the selection callback above.
        local party = self.machine:get("party")
        local epoch, serial = self.epoch, self.serial
        party.options.onCancel = function()
            if self:valid() and self:isTop() and self.epoch == epoch and self.serial == serial then
                self.serial = self.serial + 1
                self:daycareText({"AllRightThenText", "ComeAgainText"})
            end
        end
    end)
end
function DaycareState:daycareWithdraw()
    local request, plan = Daycare.prepare(self.session, "withdraw")
    self.plan.ram = {wNameBuffer=plan.pokemon.name, wDayCareMonName=plan.pokemon.name,
        wDayCareNumLevelsGrown=plan.grown, wDayCareTotalCost=plan.fee}
    local grownText = plan.grown > 0 and "MonHasGrownText" or "MonNeedsMoreTimeText"
    self:daycareText({grownText}, function()
        if plan.status == "party-full" then
            self.session:resolveDaycare(request, false)
            self:daycareFailure("party-full")
            return
        end
        self:daycareText({"OweMoneyText"}, function()
            self:serviceChoice({"YES", "NO"}, function(yes)
                local ok, result = self.session:resolveDaycare(request, yes)
                if not ok then
                    self:daycareFailure(result)
                elseif result.kind == "cancelled" then
                    self:daycareText({"AllRightThenText", "ComeAgainText"})
                else
                    self.committed = true
                    self:daycareText({"HeresYourMonText", "GotMonBackText"})
                end
            end)
        end)
    end)
end
function DaycareState:draw()
    DaycareState.super.draw(self)
    if not self:valid() or self.plan.scene ~= "daycare" or not self.plan.ram
        or not self.plan.ram.wDayCareTotalCost then
        return
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setFont(gfx.getSystemFont())
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(236, 4, 160, 46)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(236, 4, 160, 46)
    gfx.drawText("MONEY", 246, 8)
    gfx.drawText("¥" .. self.session:inventory():money(), 246, 27)
    gfx.popContext()
end
