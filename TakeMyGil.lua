-- TakeMyGil.lua
-- Automates sending gil via trade, splitting large amounts.

local TMG = {}
TMG.Name = "TakeMyGil"
TMG.Version = "2.1.0"

TMG.Settings = {
    AmountToGive = 0,
}
TMG.State = {
    IsRunning = false,
    CurrentStep = "IDLE", 
    RemainingAmount = 0,
    LastActionTime = 0,
    TradeSessionAmount = 0,
    StateEntryTime = 0,
    RetryCount = 0,
    TotalAmount = 0,
    SendStartTime = nil,
    LastResultAmount = nil,
    LastResultDuration = nil,
    ResultPending = false,
    IsReceiving = false,
    GilBeforeSession = nil,
    GilCheckStart = 0,
    InputOkSent = false,
    ChatLastTimestamp = 0,
    ChatLastLines = {},
    ChatTradeComplete = false,
    ChatTradeCancelled = false,
    ChatTradeAmount = nil,
    ChatTradeReceived = 0,
    CancelledDelayUntil = 0,
    TradeWindowOpenAt = 0,
    LastGilSetAt = 0,
    GilSetRetries = 0,
    ReceiveTradeOpenTime = 0,
    ReceiveOtherState = nil,
    ReceiveOtherStateStable = 0,
    TradeTargetMismatchLogged = false,
    PaletteIndex = 4,
    MiniPosX = 0,
    MiniDragging = false,
    MiniDragLastX = 0,
    UIOpen = false,
}

TMG.MAX_TRADE_GIL = 1000000
TMG.MAX_GIL = 999999999
TMG.DELAY_SHORT = 200
TMG.DELAY_MEDIUM = 400
TMG.DELAY_LONG = 600
TMG.TIMEOUT_TRADE_WINDOW = 10000
TMG.TIMEOUT_PARTNER = 60000
TMG.MAX_RETRY = 3
TMG.TIMEOUT_GIL_UPDATE = 6000
TMG.TRADE_RANGE = 3.0
TMG.TARGET_GRACE_MS = 500
TMG.TRADE_GIL_VERIFY_DELAY = 300
TMG.MAX_GIL_SET_RETRY = 2

local visible = false

local function Log(msg)
    d("[TakeMyGil] " .. msg)
end

local function FormatNumber(n)
    local formatted = tostring(n)
    while true do
        local k
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function Throttle(ms)
    if (TimeSince(TMG.State.LastActionTime) > ms) then
        TMG.State.LastActionTime = Now()
        return true
    end
    return false
end

local function SetState(newState)
    TMG.State.CurrentStep = newState
    TMG.State.StateEntryTime = Now()
end

local function StateTimedOut(timeoutMs)
    return TimeSince(TMG.State.StateEntryTime) > timeoutMs
end

local function ControlIsReady(controlName)
    local control = GetControl(controlName)
    if not control or type(control.IsReady) ~= "function" then
        return false
    end
    local ok, ready = pcall(control.IsReady, control)
    return ok and ready or false
end

local GetTarget
local function GetTargetDistance(target)
    if not target then
        return nil
    end
    return target.distance2d or target.distance
end

local function IsPlayerMoving()
    return Player and Player.IsMoving and Player:IsMoving() or false
end

local function StopPlayerMovement()
    if ml_navigation and ml_navigation.StopMovement then
        ml_navigation.StopMovement()
    end
    if Player and Player.Stop then
        Player:Stop()
    end
    if Player and Player.StopMovement then
        Player:StopMovement()
    elseif Player and Player.PauseMovement then
        Player:PauseMovement()
    end
end

local function NoteTradeWindowOpen()
    if IsControlOpen("Trade") and TMG.State.TradeWindowOpenAt == 0 then
        TMG.State.TradeWindowOpenAt = Now()
    elseif not IsControlOpen("Trade") then
        TMG.State.TradeWindowOpenAt = 0
    end
end

local function NormalizeName(s)
    if not s then
        return ""
    end
    return tostring(s):lower():gsub("%s+", "")
end

local function ParseNumber(s)
    if not s then
        return nil
    end
    local digits = tostring(s):gsub("[^0-9]", "")
    if digits == "" then
        return nil
    end
    return tonumber(digits)
end

local function GetTradeMyGilAmount()
    local keys = {"mygil", "mygilmoney", "mygiltxt", "myGil", "myGilText"}
    for _, k in ipairs(keys) do
        local v = GetControlData("Trade", k)
        local n = tonumber(v)
        if n then
            return n
        end
        n = ParseNumber(v)
        if n then
            return n
        end
    end
    local strings = GetControlStrings("Trade")
    if not table.valid(strings) then
        return nil
    end
    for _, s in pairs(strings) do
        local line = tostring(s)
        if line:find("Gil") or line:find("gil") or line:find("ギル") then
            local n = ParseNumber(line)
            if n then
                return n
            end
        end
    end
    return nil
end

local function TradeMatchesTarget()
    local target = GetTarget()
    if not target or not target.name then
        return false
    end
    local strings = GetControlStrings("Trade")
    if not table.valid(strings) then
        return nil
    end
    local targetName = NormalizeName(target.name)
    for _, s in pairs(strings) do
        local line = NormalizeName(s)
        if line ~= "" and targetName ~= "" and line:find(targetName, 1, true) then
            return true
        end
    end
    return false
end

local function ResetTradeChatState()
    TMG.State.ChatTradeComplete = false
    TMG.State.ChatTradeCancelled = false
    TMG.State.ChatTradeAmount = nil
    TMG.State.ChatTradeReceived = 0
end

local function ResetSendSessionState()
    TMG.State.GilBeforeSession = nil
    TMG.State.TradeSessionAmount = 0
    TMG.State.InputOkSent = false
    TMG.State.TotalAmount = 0
    TMG.State.ResultPending = false
    TMG.State.LastGilSetAt = 0
    TMG.State.GilSetRetries = 0
    TMG.State.TradeTargetMismatchLogged = false
    ResetTradeChatState()
end

local function InitChatCursor()
    local latest = 0
    local seen = {}
    local lines = GetChatLines and GetChatLines() or nil
    if table.valid(lines) then
        for _, k in pairs(lines) do
            local ts = tonumber(k.timestamp) or 0
            if ts > latest then latest = ts end
        end
        for _, k in pairs(lines) do
            local ts = tonumber(k.timestamp) or 0
            if ts == latest then
                local key = tostring(k.rawline or k.line or "")
                seen[key] = true
            end
        end
    end
    TMG.State.ChatLastTimestamp = latest
    TMG.State.ChatLastLines = seen
    ResetTradeChatState()
end

local function DrawProgressBar(total, remaining, contentWidth, opts)
    if not total or total <= 0 then
        return
    end
    opts = opts or {}
    local charWidth = GUI:CalcTextSize("-")
    if not charWidth or charWidth <= 0 then
        charWidth = 6
    end
    local maxChars = 20
    local sent = math.max(total - remaining, 0)
    local steps = math.max(1, math.ceil(total / TMG.MAX_TRADE_GIL))
    local stepAmount = total / steps
    local completedTrades = math.floor((sent / stepAmount) + 0.0001)
    if completedTrades < 0 then completedTrades = 0 end
    if completedTrades > steps then completedTrades = steps end
    local blocksPerStep = maxChars / steps
    local filled = math.floor(completedTrades * blocksPerStep + 0.0001)
    if filled > maxChars then filled = maxChars end
    local blinkStart = nil
    local blinkEnd = nil
    if completedTrades < steps then
        blinkStart = filled + 1
        blinkEnd = math.floor((completedTrades + 1) * blocksPerStep + 0.0001)
        if blinkEnd < blinkStart then
            blinkEnd = blinkStart
        end
        if blinkEnd > maxChars then
            blinkEnd = maxChars
        end
    end
    local spacing = 0
    if maxChars > 1 then
        spacing = math.max(0, (contentWidth - (charWidth * maxChars)) / (maxChars - 1))
    end
    local frameStep = 1000 / 24
    local nowMs = Now()
    local quantizedMs = math.floor(nowMs / frameStep) * frameStep
    local blinkMs = tonumber(opts.blinkMs) or 700
    local blinkOn = ((quantizedMs % blinkMs) / blinkMs) < 0.5
    local filledStops = {
        {0.22, 0.52, 0.22},
        {0.2, 0.75, 0.35},
        {0.55, 0.9, 0.6},
    }
    local function FilledGradient(t)
        local segs = #filledStops - 1
        local scaled = t * segs
        local idx = math.min(segs, math.floor(scaled) + 1)
        local lt = scaled - (idx - 1)
        local s1 = filledStops[idx]
        local s2 = filledStops[idx + 1]
        local r = s1[1] + (s2[1] - s1[1]) * lt
        local g = s1[2] + (s2[2] - s1[2]) * lt
        local b = s1[3] + (s2[3] - s1[3]) * lt
        return r, g, b
    end
    local emptyR, emptyG, emptyB = 0.2, 0.2, 0.2
    for i = 1, maxChars do
        local r, g, b = emptyR, emptyG, emptyB
        local ch = "-"
        if i <= filled then
            local t = (i - 1) / math.max(maxChars - 1, 1)
            r, g, b = FilledGradient(t)
            ch = "="
        end
        if blinkStart and blinkEnd and i >= blinkStart and i <= blinkEnd then
            if blinkOn then
                local t = (i - 1) / math.max(maxChars - 1, 1)
                r, g, b = FilledGradient(t)
                ch = "="
            else
                r, g, b = emptyR, emptyG, emptyB
                ch = "-"
            end
        end
        GUI:TextColored(r, g, b, 1.0, ch)
        if i < maxChars then
            GUI:SameLine(0, spacing)
        end
    end
end

local function FormatDuration(ms)
    if not ms or ms < 0 then
        return "00:00"
    end
    local total = math.floor(ms / 1000)
    local h = math.floor(total / 3600)
    local m = math.floor((total % 3600) / 60)
    local s = total % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local function UpdateChatState()
    local lines = GetChatLines and GetChatLines() or nil
    if not table.valid(lines) then
        return
    end

    local latest = TMG.State.ChatLastTimestamp or 0
    local seen = TMG.State.ChatLastLines or {}
    for _, k in pairs(lines) do
        local ts = tonumber(k.timestamp) or 0
        local key = tostring(k.rawline or k.line or "")
        local isNewTs = ts > latest
        local isSameTsNewLine = ts == latest and not seen[key]
        if isNewTs or isSameTsNewLine then
            local line = tostring(k.line or "")
            if line:find("Trade complete%.") then
                TMG.State.ChatTradeComplete = true
            elseif line:find("Trade cancel") then
                TMG.State.ChatTradeCancelled = true
            elseif line:find("You hand over") and line:find("gil") then
                local digits = line:gsub("[^0-9]", "")
                local amount = tonumber(digits)
                if amount and amount > 0 then
                    TMG.State.ChatTradeAmount = amount
                end
            elseif line:find("You receive") and line:find("gil") then
                local digits = line:gsub("[^0-9]", "")
                local amount = tonumber(digits)
                if amount and amount > 0 then
                    TMG.State.ChatTradeReceived = (TMG.State.ChatTradeReceived or 0) + amount
                end
            end
            if ts > latest then
                latest = ts
                seen = {}
            end
            seen[key] = true
        end
    end
    TMG.State.ChatLastTimestamp = latest
    TMG.State.ChatLastLines = seen
end

-- Get target (player)
GetTarget = function()
    if not Player then
        return nil
    end
    local target = Player:GetTarget()
    if table.valid(target) then 
        return target 
    end
    return nil
end

-- Logic: Receive (Auto Accept)
local function RunReceiveLogic()
    if not IsControlOpen("Trade") and not IsControlOpen("SelectYesno") then
        TMG.State.ReceiveTradeOpenTime = 0
        TMG.State.ReceiveOtherState = nil
        TMG.State.ReceiveOtherStateStable = 0
        return 
    end

    if IsControlOpen("SelectYesno") then
        if Throttle(TMG.DELAY_SHORT) then
            Log("Receive: Confirming Final Dialog.")
            UseControlAction("SelectYesno", "Yes")
        end
        return
    end

    if IsControlOpen("Trade") then
        if TMG.State.ReceiveTradeOpenTime == 0 then
            TMG.State.ReceiveTradeOpenTime = Now()
            return
        end
        if TimeSince(TMG.State.ReceiveTradeOpenTime) < 500 then
            return
        end
        if not ControlIsReady("Trade") then
            return
        end
        local otherstate = tonumber(GetControlData("Trade", "otherstate") or 0) or 0
        local mystate = tonumber(GetControlData("Trade", "mystate") or 0) or 0
        if TMG.State.ReceiveOtherState == otherstate then
            TMG.State.ReceiveOtherStateStable = TMG.State.ReceiveOtherStateStable + 1
        else
            TMG.State.ReceiveOtherState = otherstate
            TMG.State.ReceiveOtherStateStable = 0
        end
        if mystate < 4 and otherstate >= 4 and TMG.State.ReceiveOtherStateStable >= 1 then
            if Throttle(TMG.DELAY_MEDIUM) then
                UseControlAction("Trade", "Trade") 
            end
        end
    end
end

-- Logic: Send (Give Gil)
local function RunSendLogic()
    local state = TMG.State.CurrentStep
    NoteTradeWindowOpen()
    
    if state == "INIT_TRADE" then
        if IsControlOpen("Trade") or IsControlOpen("InputNumeric") then
            if TMG.State.RemainingAmount <= 0 then
                Log("Amount reached. Stopping.")
                TMG.State.IsRunning = false
                SetState("IDLE")
                return
            end
            TMG.State.GilBeforeSession = Inventory:GetCurrencyCountByID(1) or 0
            TMG.State.TradeSessionAmount = math.min(TMG.State.RemainingAmount, TMG.MAX_TRADE_GIL)
            InitChatCursor()
            SetState("INPUT_GIL")
            return
        end
        if Throttle(TMG.DELAY_MEDIUM) then
            if TMG.State.RemainingAmount <= 0 then
                Log("Amount reached. Stopping.")
                TMG.State.IsRunning = false
                SetState("IDLE")
                return
            end

            local target = GetTarget()
            if not target then
                Log("Target lost. Stopping.")
                TMG.State.IsRunning = false
                return
            end

            local dist = GetTargetDistance(target)
            if dist and dist > TMG.TRADE_RANGE and target.pos then
                Log("Target too far (" .. string.format("%.1f", dist) .. "). Moving closer...")
                Player:MoveTo(target.pos.x, target.pos.y, target.pos.z, TMG.TRADE_RANGE, 0, 0, target.id)
                return
            end
            if IsPlayerMoving() then
                Player:PauseMovement()
                return
            end

            Log("Initiating Trade... Remaining: " .. TMG.State.RemainingAmount)
            SendTextCommand("/trade")
            InitChatCursor()
            SetState("WAIT_WINDOW")
        end

    elseif state == "WAIT_WINDOW" then
        if IsControlOpen("Trade") then
            TMG.State.GilBeforeSession = Inventory:GetCurrencyCountByID(1) or 0
            TMG.State.TradeSessionAmount = math.min(TMG.State.RemainingAmount, TMG.MAX_TRADE_GIL)
            InitChatCursor()
            SetState("INPUT_GIL")
        elseif StateTimedOut(TMG.TIMEOUT_TRADE_WINDOW) then
            TMG.State.RetryCount = TMG.State.RetryCount + 1
            if TMG.State.RetryCount >= TMG.MAX_RETRY then
                Log("Max retries reached. Stopping.")
                TMG.State.IsRunning = false
                SetState("IDLE")
            else
                Log("Timeout waiting for trade window. Retry " .. TMG.State.RetryCount .. "/" .. TMG.MAX_RETRY)
                SetState("INIT_TRADE")
            end
        end

    elseif state == "INPUT_GIL" then
        if not IsControlOpen("Trade") and not IsControlOpen("InputNumeric") then
            Log("Trade window closed unexpectedly.")
            ResetSendSessionState()
            SetState("INIT_TRADE")
            return
        end
        if IsControlOpen("Trade") then
            local match = TradeMatchesTarget()
            if match == nil then
                return
            elseif match == false then
                local grace = TMG.State.TradeWindowOpenAt > 0
                    and TimeSince(TMG.State.TradeWindowOpenAt) < TMG.TARGET_GRACE_MS
                if not grace and not TMG.State.TradeTargetMismatchLogged then
                    Log("Trade target mismatch or no target. Waiting.")
                    TMG.State.TradeTargetMismatchLogged = true
                end
                return
            end
            TMG.State.TradeTargetMismatchLogged = false
        end

        if IsControlOpen("InputNumeric") then
            if not ControlIsReady("InputNumeric") then
                return
            end
            if Throttle(TMG.DELAY_SHORT) then
                local amount = math.floor(tonumber(TMG.State.TradeSessionAmount) or 0)
                Log("Attempting to set Amount via InputNumeric: " .. tostring(amount) .. " (Type: " .. type(amount) .. ")")
                UseControlAction("InputNumeric", "EnterAmount", amount)
                TMG.State.InputOkSent = false
                TMG.State.LastGilSetAt = Now()
                SetState("WAIT_INPUT_CONFIRM")
            end
            return
        end

        if Throttle(TMG.DELAY_MEDIUM) then
            if GameHacks and GameHacks.SetTradeGil then
                Log("Setting Gil (GameHacks): " .. TMG.State.TradeSessionAmount)
                GameHacks:SetTradeGil(TMG.State.TradeSessionAmount)
                TMG.State.LastGilSetAt = Now()
                SetState("CONFIRM_MY")
                return
            end
            
            Log("Clicking Gil slot to open input...")
            UseControlAction("Trade", "Gil")
        end
        
        if StateTimedOut(TMG.TIMEOUT_TRADE_WINDOW) then
            Log("Gil input timed out. Cancelling trade.")
            UseControlAction("Trade", "Cancel")
            SetState("INIT_TRADE")
        end

    elseif state == "WAIT_INPUT_CONFIRM" then
        if IsControlOpen("InputNumeric") then
            if ControlIsReady("InputNumeric") and not TMG.State.InputOkSent and Throttle(TMG.DELAY_SHORT) then
                UseControlAction("InputNumeric", "Ok")
                TMG.State.InputOkSent = true
                TMG.State.LastGilSetAt = Now()
            end
            return
        end
        TMG.State.InputOkSent = false
        SetState("CONFIRM_MY")

    elseif state == "CONFIRM_MY" then
        if not IsControlOpen("Trade") then
            SetState("INIT_TRADE")
            return
        end
        do
            local match = TradeMatchesTarget()
            if match == nil then
                return
            elseif match == false then
                local grace = TMG.State.TradeWindowOpenAt > 0
                    and TimeSince(TMG.State.TradeWindowOpenAt) < TMG.TARGET_GRACE_MS
                if not grace and not TMG.State.TradeTargetMismatchLogged then
                    Log("Trade target mismatch or no target. Waiting.")
                    TMG.State.TradeTargetMismatchLogged = true
                end
                return
            end
            TMG.State.TradeTargetMismatchLogged = false
        end
        if TMG.State.LastGilSetAt > 0 and TimeSince(TMG.State.LastGilSetAt) < TMG.TRADE_GIL_VERIFY_DELAY then
            return
        end
        local mygil = GetTradeMyGilAmount()
        if mygil and mygil ~= TMG.State.TradeSessionAmount then
            if TMG.State.GilSetRetries >= TMG.MAX_GIL_SET_RETRY then
                Log("Trade gil mismatch persists. Stopping to avoid wrong amount.")
                TMG.State.IsRunning = false
                SetState("IDLE")
                return
            end
            if Throttle(TMG.DELAY_MEDIUM) then
                TMG.State.GilSetRetries = TMG.State.GilSetRetries + 1
                Log("Trade gil mismatch (" .. tostring(mygil) .. "). Re-entering amount.")
                UseControlAction("Trade", "Gil")
                SetState("INPUT_GIL")
                return
            end
        end
        local mystate = tonumber(GetControlData("Trade", "mystate") or 0) or 0
        if mystate < 4 and Throttle(TMG.DELAY_MEDIUM) then
             Log("Confirming Trade...")
             UseControlAction("Trade", "Trade")
             SetState("WAIT_PARTNER")
        elseif mystate >= 4 then
             SetState("WAIT_PARTNER")
        end
        
    elseif state == "WAIT_PARTNER" then
         if IsControlOpen("SelectYesno") then
             TMG.State.RetryCount = 0
             SetState("WAIT_FINAL_CONFIRM")
         elseif IsControlOpen("Trade") then
             local mystate = tonumber(GetControlData("Trade", "mystate") or 0) or 0
             if mystate < 4 and Throttle(TMG.DELAY_MEDIUM) then
                 UseControlAction("Trade", "Trade")
             end
         elseif not IsControlOpen("Trade") and not IsControlOpen("SelectYesno") then
             Log("Trade closed. Verifying via chat/gil update.")
             TMG.State.GilCheckStart = Now()
             SetState("WAIT_GIL_UPDATE")
         elseif StateTimedOut(TMG.TIMEOUT_PARTNER) then
             Log("Partner confirmation timed out. Cancelling.")
             UseControlAction("Trade", "Cancel")
             ResetSendSessionState()
             SetState("NEXT_LOOP")
         end

    elseif state == "WAIT_FINAL_CONFIRM" then
        if IsControlOpen("SelectYesno") then
            if Throttle(TMG.DELAY_SHORT) then
                UseControlAction("SelectYesno", "Yes")
            end
        else
            if IsControlOpen("Trade") then
                if StateTimedOut(TMG.TIMEOUT_PARTNER) then
                    Log("Partner confirmation timed out after final dialog. Cancelling.")
                    UseControlAction("Trade", "Cancel")
                    ResetSendSessionState()
                    SetState("NEXT_LOOP")
                end
                return
            end
            TMG.State.GilCheckStart = Now()
            SetState("WAIT_GIL_UPDATE")
        end

    elseif state == "WAIT_GIL_UPDATE" then
        UpdateChatState()
        if TMG.State.GilBeforeSession == nil then
            TMG.State.GilBeforeSession = Inventory:GetCurrencyCountByID(1) or 0
        end
        if TMG.State.ChatTradeCancelled then
            Log("Trade cancelled via chat log.")
            ResetSendSessionState()
            TMG.State.CancelledDelayUntil = Now() + 500
            SetState("NEXT_LOOP")
            return
        end

        local gilAfter = Inventory:GetCurrencyCountByID(1) or 0
        local gilBefore = TMG.State.GilBeforeSession or gilAfter
        local delta = gilBefore - gilAfter
        local received = TMG.State.ChatTradeReceived or 0
        local expectedNet = math.max(TMG.State.TradeSessionAmount - received, 0)
        if expectedNet > 0 and delta >= expectedNet then
            local applied = expectedNet
            TMG.State.RemainingAmount = TMG.State.RemainingAmount - applied
            if TMG.State.RemainingAmount < 0 then TMG.State.RemainingAmount = 0 end
            TMG.Settings.AmountToGive = TMG.State.RemainingAmount
            Log("Trade completed (delta). Applied: " .. tostring(applied) .. " Remaining: " .. TMG.State.RemainingAmount)
            TMG.State.GilBeforeSession = nil
            SetState("NEXT_LOOP")
        elseif TMG.State.ChatTradeComplete and (TMG.State.ChatTradeAmount or received > 0) then
            local sent = TMG.State.ChatTradeAmount or TMG.State.TradeSessionAmount
            local net = math.max(sent - received, 0)
            local applied = math.min(net, math.max(TMG.State.TradeSessionAmount, 0))
            TMG.State.RemainingAmount = TMG.State.RemainingAmount - applied
            if TMG.State.RemainingAmount < 0 then TMG.State.RemainingAmount = 0 end
            TMG.Settings.AmountToGive = TMG.State.RemainingAmount
            Log("Trade completed (chat fallback). Applied: " .. tostring(applied) .. " Remaining: " .. TMG.State.RemainingAmount)
            TMG.State.GilBeforeSession = nil
            SetState("NEXT_LOOP")
        elseif TimeSince(TMG.State.GilCheckStart) > TMG.TIMEOUT_GIL_UPDATE then
            Log("Trade result unconfirmed. Stopping to avoid duplicate send. Gil delta: " .. tostring(delta))
            TMG.State.GilBeforeSession = nil
            TMG.State.IsRunning = false
            SetState("IDLE")
        end
    elseif state == "NEXT_LOOP" then
         if Throttle(TMG.DELAY_SHORT) then
              if TMG.State.CancelledDelayUntil and Now() < TMG.State.CancelledDelayUntil then
                  return
              end
               if TMG.State.RemainingAmount > 0 then
                   SetState("INIT_TRADE")
               else
                   Log("All transfers complete.")
                   if TMG.State.SendStartTime and TMG.State.TotalAmount > 0 then
                       TMG.State.LastResultAmount = TMG.State.TotalAmount
                       TMG.State.LastResultDuration = Now() - TMG.State.SendStartTime
                       TMG.State.ResultPending = true
                   end
                   TMG.State.SendStartTime = nil
                   TMG.State.RetryCount = 0
                  SetState("IDLE")
              end
          end
    end
end

function TMG.Draw()
    GUI:PushStyleVar(GUI.StyleVar_WindowRounding, 6)
    GUI:PushStyleVar(GUI.StyleVar_FrameRounding, 4)
    GUI:PushStyleVar(GUI.StyleVar_WindowPadding, 8, 8)
    GUI:PushStyleColor(GUI.Col_WindowBg, 0.12, 0.14, 0.16, 0.96)
    GUI:PushStyleColor(GUI.Col_Border, 0.32, 0.36, 0.42, 1.0)
    GUI:PushStyleColor(GUI.Col_TitleBg, 0.16, 0.18, 0.2, 1.0)
    GUI:PushStyleColor(GUI.Col_TitleBgActive, 0.16, 0.18, 0.2, 1.0)
    GUI:PushStyleColor(GUI.Col_TitleBgCollapsed, 0.16, 0.18, 0.2, 1.0)
    GUI:PushStyleColor(GUI.Col_FrameBg, 0.18, 0.2, 0.22, 1.0)
    GUI:PushStyleColor(GUI.Col_FrameBgHovered, 0.22, 0.25, 0.28, 1.0)
    GUI:PushStyleColor(GUI.Col_FrameBgActive, 0.26, 0.3, 0.34, 1.0)

    GUI:SetNextWindowSize(184, 0, GUI.SetCond_Always)
    
    local flags = GUI.WindowFlags_NoResize + GUI.WindowFlags_AlwaysAutoResize
    if TMG.State.UIOpen then
        local winVisible
        winVisible, TMG.State.UIOpen = GUI:Begin(TMG.Name, TMG.State.UIOpen, flags)
        if TMG.State.UIOpen ~= visible then
            Log("UI open: " .. tostring(TMG.State.UIOpen) .. " winVisible: " .. tostring(winVisible))
        end
        visible = TMG.State.UIOpen
        
        if winVisible then
            local padX = 8
            local gap = 6
            local contentWidth = math.max(120, GUI:GetWindowWidth() - (padX * 2))
            local currentGil = Inventory:GetCurrencyCountByID(1) or 0
            local maxGive = math.min(currentGil, TMG.MAX_GIL)
            
            if TMG.State.IsReceiving then
                GUI:TextColored(1.0, 0.7, 0.3, 1.0, "RECV ON. SEND LOCKED.")
            else
                GUI:TextColored(0.62, 0.85, 0.55, 1.0, FormatNumber(TMG.Settings.AmountToGive) .. " Gil")
            end
            
            GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.24, 0.28, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.24, 0.3, 0.36, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.28, 0.34, 0.42, 1.0)

            local btnW = (contentWidth - gap) / 2
            local inputW = math.max(60, btnW)
            GUI:PushItemWidth(inputW)
            local newAmt, changedAmt = GUI:InputInt("##amt", TMG.Settings.AmountToGive, 0, 0)
            if changedAmt then 
                TMG.Settings.AmountToGive = math.min(math.max(0, newAmt), maxGive) 
            end
            GUI:PopItemWidth()
            GUI:SameLine()
            GUI:SameLine(0, gap)
            if GUI:Button("CLR", btnW, 20) then 
                TMG.Settings.AmountToGive = 0 
            end
            
            if GUI:Button("+1M", btnW, 22) then 
                TMG.Settings.AmountToGive = math.min(TMG.Settings.AmountToGive + 1000000, maxGive) 
            end
            GUI:SameLine(0, gap)
            if GUI:Button("+10M", btnW, 22) then 
                TMG.Settings.AmountToGive = math.min(TMG.Settings.AmountToGive + 10000000, maxGive) 
            end
            
            if GUI:Button("+100M", btnW, 22) then 
                TMG.Settings.AmountToGive = math.min(TMG.Settings.AmountToGive + 100000000, maxGive) 
            end
            GUI:SameLine(0, gap)
            if GUI:Button("ALL", btnW, 22) then 
                TMG.Settings.AmountToGive = maxGive
            end
            
            GUI:Spacing()
            GUI:PopStyleColor(3)

            local target = GetTarget()
            if target then
                GUI:TextDisabled("To: " .. target.name)
            else
                GUI:TextDisabled("To: -")
            end
            
            local btnLabel = "SHUT UP AND TAKE MY GIL"
            local btnColor
            if TMG.State.IsRunning then
                btnColor = {0.2, 0.6, 0.35, 1.0}
            else
                btnColor = {0.55, 0.2, 0.2, 1.0}
            end
            
            GUI:PushStyleColor(GUI.Col_Button, btnColor[1], btnColor[2], btnColor[3], btnColor[4])
            GUI:PushStyleColor(GUI.Col_ButtonHovered, btnColor[1]+0.1, btnColor[2]+0.1, btnColor[3]+0.1, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonActive, btnColor[1]-0.1, btnColor[2]-0.1, btnColor[3]-0.1, 1.0)
            
            if GUI:Button(btnLabel, contentWidth, 28) then
                TMG.State.IsRunning = not TMG.State.IsRunning
                
                if TMG.State.IsRunning then
                    if TMG.State.IsReceiving then
                        Log("Cannot start SEND while RECV is running.")
                        TMG.State.IsRunning = false
                        return
                    end
                    TMG.Settings.AmountToGive = math.min(TMG.Settings.AmountToGive, maxGive)
                    TMG.State.RemainingAmount = TMG.Settings.AmountToGive
                    TMG.State.TotalAmount = TMG.Settings.AmountToGive
                    TMG.State.RetryCount = 0
                    TMG.State.SendStartTime = Now()
                    TMG.State.LastResultAmount = nil
                    TMG.State.LastResultDuration = nil
                    TMG.State.ResultPending = false
                    InitChatCursor()
                    SetState("INIT_TRADE")
                    Log("Started Sending " .. TMG.Settings.AmountToGive .. " Gil.")
                else
                    TMG.State.ResultPending = false
                    TMG.State.LastResultAmount = nil
                    TMG.State.LastResultDuration = nil
                    TMG.State.SendStartTime = nil
                    SetState("IDLE")
                    StopPlayerMovement()
                    Log("Stopped.")
                end
            end
            
            GUI:PopStyleColor(3)
            
            if TMG.State.IsRunning and not TMG.State.ResultPending then
                GUI:TextDisabled("Sending...")
                DrawProgressBar(TMG.State.TotalAmount, TMG.State.RemainingAmount, contentWidth, {})
            elseif TMG.State.LastResultAmount and TMG.State.LastResultDuration then
                GUI:TextColored(0.62, 0.85, 0.55, 1.0, "Sent: " .. FormatNumber(TMG.State.LastResultAmount) .. " Gil")
                GUI:TextColored(0.6, 0.72, 0.9, 1.0, "Time: " .. FormatDuration(TMG.State.LastResultDuration))
            end
        end
        GUI:End()
    end

    GUI:PopStyleColor(8)
    GUI:PopStyleVar(3)

    local sw, sh = GUI:GetScreenSize()
    local sendLabel, recvLabel = "SEND", "RECV"
    local sendW = math.max(36, GUI:CalcTextSize(sendLabel) + 12)
    local recvW = math.max(36, GUI:CalcTextSize(recvLabel) + 12)
    local btnH = 22
    local showSend = not TMG.State.UIOpen
    local pad = 2
    local gap = 2
    local miniW = sendW + pad + recvW
    local miniH = btnH
    local baseY = sh - miniH - gap
    if TMG.State.MiniPosX == 0 then
        TMG.State.MiniPosX = sw - miniW - 230
    end
    TMG.State.MiniPosX = math.max(0, math.min(sw - miniW, TMG.State.MiniPosX))
    GUI:SetNextWindowPos(TMG.State.MiniPosX, baseY, GUI.SetCond_Always)
    GUI:SetNextWindowSize(miniW, miniH, GUI.SetCond_Always)

    local miniFlags = 0
    if (GUI.WindowFlags_NoTitleBar)      then miniFlags = miniFlags + GUI.WindowFlags_NoTitleBar end
    if (GUI.WindowFlags_NoResize)        then miniFlags = miniFlags + GUI.WindowFlags_NoResize end
    if (GUI.WindowFlags_NoMove)          then miniFlags = miniFlags + GUI.WindowFlags_NoMove end
    if (GUI.WindowFlags_NoCollapse)      then miniFlags = miniFlags + GUI.WindowFlags_NoCollapse end
    if (GUI.WindowFlags_NoScrollbar)     then miniFlags = miniFlags + GUI.WindowFlags_NoScrollbar end
    if (GUI.WindowFlags_NoSavedSettings) then miniFlags = miniFlags + GUI.WindowFlags_NoSavedSettings end
    if (GUI.WindowFlags_NoBackground)    then miniFlags = miniFlags + GUI.WindowFlags_NoBackground end

    GUI:PushStyleVar(GUI.StyleVar_WindowPadding, 0, 0)
    GUI:PushStyleVar(GUI.StyleVar_FramePadding, 4, 2)
    GUI:PushStyleVar(GUI.StyleVar_FrameRounding, 6)
    GUI:PushStyleVar(GUI.StyleVar_WindowRounding, 0)
    GUI:PushStyleColor(GUI.Col_WindowBg, 0, 0, 0, 0)
    GUI:PushStyleColor(GUI.Col_Border, 0, 0, 0, 0)
    if (GUI:Begin("TakeMyGilMini###TakeMyGilMini", true, miniFlags)) then
        local x = 0
        local y = 0
        local dragHovered = GUI:IsWindowHovered()
        GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.24, 0.26, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.26, 0.32, 0.34, 1.0)
        GUI:PushStyleColor(GUI.Col_ButtonActive, 0.3, 0.36, 0.38, 1.0)
        GUI:SetCursorPos(x, y)
        if showSend then
            if GUI:Button(sendLabel, sendW, btnH) then
                visible = true
                TMG.State.UIOpen = true
            end
        else
            GUI:InvisibleButton("##MiniSendHidden", sendW, btnH)
        end
        x = x + sendW + pad
        GUI:SetCursorPos(x, y)
        GUI:PopStyleColor(3)
        local recvOn = TMG.State.IsReceiving
        if recvOn then
            GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.6, 0.2, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.3, 0.7, 0.3, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.25, 0.65, 0.25, 1.0)
        else
            GUI:PushStyleColor(GUI.Col_Button, 0.2, 0.24, 0.26, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonHovered, 0.26, 0.32, 0.34, 1.0)
            GUI:PushStyleColor(GUI.Col_ButtonActive, 0.3, 0.36, 0.38, 1.0)
        end
        if GUI:Button(recvLabel, recvW, btnH) then
            TMG.ToggleReceive()
        end
        GUI:PopStyleColor(3)
        
        if dragHovered and (GUI:IsMouseDown(1) or GUI:IsMouseDragging(1)) then
            local mx, my = GUI:GetMousePos()
            if not TMG.State.MiniDragging then
                TMG.State.MiniDragging = true
                TMG.State.MiniDragLastX = mx
            else
                local dx = mx - (TMG.State.MiniDragLastX or mx)
                TMG.State.MiniPosX = (TMG.State.MiniPosX or 0) + dx
                TMG.State.MiniDragLastX = mx
            end
        else
            TMG.State.MiniDragging = false
        end
    end
    GUI:End()
    GUI:PopStyleColor(2)
    GUI:PopStyleVar(4)
end

-- Update Loop
function TMG.Update(event, tick)
    if TMG.State.IsRunning and not TMG.State.ResultPending then
        RunSendLogic()
    end
    if TMG.State.IsReceiving then
        RunReceiveLogic()
    end
end

RegisterEventHandler("Gameloop.Draw", TMG.Draw, TMG.Name)
RegisterEventHandler("Gameloop.Update", TMG.Update, TMG.Name)

function TMG.IsVisible()
    return visible
end

function TMG.SetVisible(v)
    visible = v and true or false
    TMG.State.UIOpen = visible
end

function TMG.ToggleReceive()
    if TMG.State.IsReceiving then
        TMG.State.IsReceiving = false
        Log("Stopped Receiving Monitor.")
        return
    end
    if TMG.State.IsRunning then
        Log("Cannot start RECV while SEND is running.")
        return
    end
    TMG.State.IsReceiving = true
    InitChatCursor()
    Log("Started Receiving Monitor.")
end

return TMG
