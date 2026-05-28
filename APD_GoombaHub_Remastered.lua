-- ================================================
-- Anime Power Defense - APD Hub v3.0
-- Goomba Hub Style | Only working features
-- GameId: 5787561793
-- ================================================

if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 5787561793 then return end

-- ================================================
-- Services
-- ================================================
local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local HttpService         = game:GetService("HttpService")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService        = game:GetService("TweenService")
local RunService          = game:GetService("RunService")
local StarterGui          = game:GetService("StarterGui")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local Character = Player.Character or Player.CharacterAdded:Wait()
local IsMobile  = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ================================================
-- Remotes
-- ================================================
local GameEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Game")
local RF = ReplicatedStorage
    :WaitForChild("Modules"):WaitForChild("Packages"):WaitForChild("Knit")
    :WaitForChild("Services"):WaitForChild("GameService"):WaitForChild("RF")

local GetPlacedUnitsRF = RF:WaitForChild("GetPlacedUnits")
local VoteSkipWaveRF   = RF:WaitForChild("VoteSkipWave")
local SellUnitRF       = RF:WaitForChild("SellUnit")
local SetGamespeedRF   = RF:WaitForChild("SetGamespeed")

local function GetPlacedUnits() return GetPlacedUnitsRF:InvokeServer() end
local function UpgradeUnit(g)   GameEvent:FireServer("UpgradeUnit", g) end
local function SellUnit(g)      SellUnitRF:InvokeServer(g) end
local function VoteSkipWave()   VoteSkipWaveRF:InvokeServer() end
local function SetGamespeed(s)  SetGamespeedRF:InvokeServer(s) end
local function Replay()         GameEvent:FireServer("Retry") end

-- ================================================
-- Webhook helper
-- ================================================
local function SendWebhook(url, content)
    if not url or url == "" then return end
    pcall(function()
        HttpService:RequestAsync({
            Url    = url,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body   = HttpService:JSONEncode({ content = content }),
        })
    end)
end

-- ================================================
-- File System
-- ================================================
if not isfolder("APDScript")           then makefolder("APDScript") end
if not isfolder("APDScript\\Macros")   then makefolder("APDScript\\Macros") end
if not isfolder("APDScript\\Settings") then makefolder("APDScript\\Settings") end

local SETTINGS_FILE = "APDScript\\Settings\\" .. Player.UserId .. ".json"

local Settings = {
    -- Gamespeed
    gamespeed      = 1.5,
    auto_gamespeed = false,
    -- Auto farm
    auto_upgrade   = false,
    auto_skip      = false,
    auto_replay    = false,
    upgrade_delay  = 0.5,
    skip_delay     = 3,
    -- Macro
    macro_speed    = 0.2,
    play_macro     = false,
    macro_profile  = "",
    -- Misc
    auto_hide_ui   = false,
    fps_booster    = false,
    -- Webhook
    webhook_url    = "",
    webhook_enabled= false,
    discord_id     = "",
    webhook_ping   = true,
}

local function SaveSettings()
    pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings)) end)
end
local function LoadSettings()
    if isfile(SETTINGS_FILE) then
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if ok and d then for k, v in pairs(d) do Settings[k] = v end end
    end
end
LoadSettings()

-- ================================================
-- Macro Engine
-- ================================================
local MacroEngine = {
    IsRecording = false,
    IsPlaying   = false,
    Actions     = {},
    StartTime   = 0,
    Speed       = 1.0,
    CurrentName = Settings.macro_profile or "",
    StepDelay   = Settings.macro_speed or 0.2,
}

function MacroEngine:RecordAction(t, d)
    if not self.IsRecording then return end
    table.insert(self.Actions, { type = t, data = d, ts = tick() - self.StartTime })
end

function MacroEngine:StartRecording()
    self.IsRecording = true
    self.IsPlaying   = false
    self.Actions     = {}
    self.StartTime   = tick()
end

function MacroEngine:StopRecording()
    self.IsRecording = false
end

function MacroEngine:Save(name)
    writefile("APDScript\\Macros\\" .. name .. ".json",
        HttpService:JSONEncode({ name = name, actions = self.Actions }))
    self.CurrentName = name
    Settings.macro_profile = name
    SaveSettings()
end

function MacroEngine:Load(name)
    local p = "APDScript\\Macros\\" .. name .. ".json"
    if isfile(p) then
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(p)) end)
        if ok and d then
            self.Actions     = d.actions or {}
            self.CurrentName = name
            return true
        end
    end
    return false
end

function MacroEngine:Delete(name)
    local p = "APDScript\\Macros\\" .. name .. ".json"
    if isfile(p) then delfile(p) end
end

function MacroEngine:List()
    local files = listfiles("APDScript\\Macros")
    local out = {}
    for _, f in pairs(files) do
        local n = f:match("([^\\]+)%.json$")
        if n then table.insert(out, n) end
    end
    return out
end

function MacroEngine:StartPlayback(onStop)
    if self.IsPlaying or #self.Actions == 0 then return end
    self.IsPlaying = true
    task.spawn(function()
        local loops = 0
        while self.IsPlaying do
            loops += 1
            local prev = 0
            for _, action in ipairs(self.Actions) do
                if not self.IsPlaying then break end
                local wait_t = (action.ts - prev) / math.max(self.Speed, 0.1)
                task.wait(math.max(wait_t, self.StepDelay))
                prev = action.ts
                if not self.IsPlaying then break end

                if action.type == "click" or action.type == "touch" then
                    local x, y = action.data[1], action.data[2]
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true,  game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
                elseif action.type == "upgrade_all" then
                    local ok, placed = pcall(GetPlacedUnits)
                    if ok and placed then
                        for guid, ud in pairs(placed) do
                            local uid = tostring(ud.Type)
                            local lv, mx = 0, 0
                            if ud.Info and ud.Info[uid] then
                                lv = ud.Info[uid].Upgrade or 0
                                if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then
                                    mx = #ud.Info[uid].Data.upgrades
                                end
                            end
                            if lv < mx then pcall(UpgradeUnit, guid) task.wait(0.3) end
                        end
                    end
                elseif action.type == "sell_all" then
                    local ok, placed = pcall(GetPlacedUnits)
                    if ok and placed then
                        for g, _ in pairs(placed) do pcall(SellUnit, g) task.wait(0.3) end
                    end
                elseif action.type == "skip_wave" then pcall(VoteSkipWave)
                elseif action.type == "replay"    then pcall(Replay)
                elseif action.type == "wait"      then task.wait(action.data[1])
                elseif action.type == "set_speed" then pcall(SetGamespeed, action.data[1])
                end
            end
            if self.IsPlaying then task.wait(0.5) end
        end
        if onStop then onStop(loops) end
    end)
end

function MacroEngine:StopPlayback() self.IsPlaying = false end

-- Capture mouse clicks while recording
UserInputService.InputBegan:Connect(function(input)
    if not MacroEngine.IsRecording then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local m = Player:GetMouse()
        MacroEngine:RecordAction("click", { m.X, m.Y })
    end
end)
if UserInputService.TouchEnabled then
    UserInputService.TouchStarted:Connect(function(touch)
        if not MacroEngine.IsRecording then return end
        MacroEngine:RecordAction("touch", { touch.Position.X, touch.Position.Y })
    end)
end

-- ================================================
-- Auto Farm Loops
-- ================================================
local AutoLoops = { upgrade = false, skip = false, replay = false }

local function StartAutoUpgrade()
    if AutoLoops.upgrade then return end
    AutoLoops.upgrade = true
    task.spawn(function()
        while Settings.auto_upgrade do
            local ok, placed = pcall(GetPlacedUnits)
            if ok and placed then
                for guid, ud in pairs(placed) do
                    if not Settings.auto_upgrade then break end
                    local uid = tostring(ud.Type)
                    local lv, mx = 0, 0
                    if ud.Info and ud.Info[uid] then
                        lv = ud.Info[uid].Upgrade or 0
                        if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then
                            mx = #ud.Info[uid].Data.upgrades
                        end
                    end
                    if lv < mx then pcall(UpgradeUnit, guid) task.wait(Settings.upgrade_delay) end
                end
            end
            task.wait(1)
        end
        AutoLoops.upgrade = false
    end)
end

local function StartAutoSkip()
    if AutoLoops.skip then return end
    AutoLoops.skip = true
    task.spawn(function()
        while Settings.auto_skip do
            pcall(VoteSkipWave)
            task.wait(Settings.skip_delay)
        end
        AutoLoops.skip = false
    end)
end

local function StartAutoReplay()
    if AutoLoops.replay then return end
    AutoLoops.replay = true
    task.spawn(function()
        while Settings.auto_replay do
            pcall(Replay)
            task.wait(5)
        end
        AutoLoops.replay = false
    end)
end

-- FPS booster loop
local fpsConn = nil
local function ApplyFpsBooster(enabled)
    if fpsConn then fpsConn:Disconnect(); fpsConn = nil end
    if not enabled then return end
    -- Disable non-essential rendering to boost FPS
    pcall(function()
        local lighting = game:GetService("Lighting")
        lighting.GlobalShadows = false
        lighting.FogEnd        = 9e9
    end)
    -- Reduce render quality on mobile
    if IsMobile then
        pcall(function()
            settings().Rendering.QualityLevel = 1
        end)
    end
end

-- Auto hide UI (hides the game's built-in UI)
local function ApplyAutoHideUI(enabled)
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not enabled)
    end)
end

-- ================================================
-- GUI CONSTANTS
-- ================================================
local C = {
    BG          = Color3.fromRGB(15, 15, 20),
    SIDEBAR     = Color3.fromRGB(22, 22, 30),
    PANEL       = Color3.fromRGB(28, 28, 38),
    CARD        = Color3.fromRGB(36, 36, 48),
    ACCENT      = Color3.fromRGB(80, 80, 120),
    ACCENT_LIT  = Color3.fromRGB(120, 120, 180),
    GREEN       = Color3.fromRGB(60, 200, 100),
    RED         = Color3.fromRGB(210, 60, 60),
    ORANGE      = Color3.fromRGB(210, 140, 40),
    TEXT        = Color3.fromRGB(225, 225, 240),
    SUBTEXT     = Color3.fromRGB(130, 130, 155),
    WHITE       = Color3.fromRGB(255, 255, 255),
    TOGGLE_OFF  = Color3.fromRGB(55, 55, 75),
    TOGGLE_ON   = Color3.fromRGB(90, 210, 130),
    BORDER      = Color3.fromRGB(45, 45, 60),
    SIDE_ACTIVE = Color3.fromRGB(45, 45, 65),
}

local FONT      = Enum.Font.GothamMedium
local FONT_BOLD = Enum.Font.GothamBold
local FONT_SEMI = Enum.Font.Gotham

local GUI_W     = IsMobile and 600 or 680
local GUI_H     = IsMobile and 420 or 480
local SIDEBAR_W = 160
local HDR_H     = 40
local FONT_SM   = IsMobile and 10 or 11
local FONT_MD   = IsMobile and 11 or 12
local FONT_LG   = IsMobile and 13 or 14
local FONT_XL   = IsMobile and 15 or 17
local BTN_H     = IsMobile and 32 or 36
local PAD       = 8

-- ================================================
-- GUI HELPERS
-- ================================================
local function Corner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

local function Stroke(p, col, thick)
    local s = Instance.new("UIStroke")
    s.Color = col or C.BORDER
    s.Thickness = thick or 1
    s.Parent = p
    return s
end

local function Label(parent, text, size, color, font, xalign)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.TextSize = size or FONT_MD
    l.TextColor3 = color or C.TEXT
    l.Font = font or FONT_SEMI
    l.BackgroundTransparency = 1
    l.TextXAlignment = xalign or Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

local function Btn(parent, text, bg, callback)
    local b = Instance.new("TextButton")
    b.Text = text
    b.TextSize = FONT_MD
    b.TextColor3 = C.WHITE
    b.Font = FONT
    b.BackgroundColor3 = bg or C.ACCENT
    b.AutoButtonColor = false
    b.Parent = parent
    Corner(b, 6)
    b.MouseButton1Click:Connect(function()
        local orig = b.BackgroundColor3
        b.BackgroundColor3 = Color3.fromRGB(
            math.clamp(orig.R * 255 + 18, 0, 255) / 255,
            math.clamp(orig.G * 255 + 18, 0, 255) / 255,
            math.clamp(orig.B * 255 + 18, 0, 255) / 255
        )
        task.delay(0.12, function() if b and b.Parent then b.BackgroundColor3 = orig end end)
        callback()
    end)
    return b
end

local function BtnRow(parent, text, bg, callback)
    local b = Btn(parent, text, bg or C.ACCENT, callback)
    b.Size = UDim2.new(1, 0, 0, BTN_H)
    return b
end

local function MakeToggle(parent, initVal, callback)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 44, 0, 23)
    track.BackgroundColor3 = initVal and C.TOGGLE_ON or C.TOGGLE_OFF
    track.Parent = parent
    Corner(track, 12)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 17, 0, 17)
    thumb.Position = initVal and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    thumb.BackgroundColor3 = C.WHITE
    thumb.Parent = track
    Corner(thumb, 9)

    local val = initVal
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = track

    btn.MouseButton1Click:Connect(function()
        val = not val
        local info = TweenInfo.new(0.15)
        TweenService:Create(track, info, { BackgroundColor3 = val and C.TOGGLE_ON or C.TOGGLE_OFF }):Play()
        TweenService:Create(thumb, info, { Position = val and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8) }):Play()
        callback(val)
    end)

    -- External setter
    return track, function(newVal)
        val = newVal
        track.BackgroundColor3 = val and C.TOGGLE_ON or C.TOGGLE_OFF
        thumb.Position = val and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    end
end

local function ToggleRow(parent, labelText, initVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, BTN_H)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Label(row, labelText, FONT_MD, C.TEXT, FONT_SEMI)
    lbl.Size = UDim2.new(1, -54, 1, 0)

    local tog, setTog = MakeToggle(row, initVal, callback)
    tog.Position = UDim2.new(1, -48, 0.5, -11)

    return row, setTog
end

local function SectionLabel(parent, text)
    local l = Label(parent, text:upper(), FONT_SM, C.SUBTEXT, FONT_BOLD)
    l.Size = UDim2.new(1, 0, 0, 16)
    return l
end

local function Divider(parent)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = C.BORDER
    d.BorderSizePixel = 0
    d.Parent = parent
    return d
end

local function ScrollFrame(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, 0, 1, 0)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.ACCENT
    sf.BorderSizePixel = 0
    sf.CanvasSize = UDim2.new(0, 0, 0, 0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 5)
    layout.Parent = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, PAD)
    pad.PaddingRight  = UDim.new(0, PAD)
    pad.PaddingTop    = UDim.new(0, PAD)
    pad.PaddingBottom = UDim.new(0, PAD + 4)
    pad.Parent = sf

    return sf
end

local function TwoColFrame(parent)
    local wrapper = Instance.new("Frame")
    wrapper.Size = UDim2.new(1, 0, 1, 0)
    wrapper.BackgroundTransparency = 1
    wrapper.Parent = parent

    local function makeCol(xScale, xOffset, padL, padR)
        local sf = Instance.new("ScrollingFrame")
        sf.Size = UDim2.new(xScale, -6, 1, 0)
        sf.Position = UDim2.new(xOffset, xOffset == 0 and 0 or 6, 0, 0)
        sf.BackgroundTransparency = 1
        sf.ScrollBarThickness = 2
        sf.ScrollBarImageColor3 = C.ACCENT
        sf.BorderSizePixel = 0
        sf.CanvasSize = UDim2.new(0, 0, 0, 0)
        sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
        sf.Parent = wrapper

        local ll = Instance.new("UIListLayout")
        ll.SortOrder = Enum.SortOrder.LayoutOrder
        ll.Padding = UDim.new(0, 5)
        ll.Parent = sf

        local lp = Instance.new("UIPadding")
        lp.PaddingLeft   = UDim.new(0, padL)
        lp.PaddingRight  = UDim.new(0, padR)
        lp.PaddingTop    = UDim.new(0, PAD)
        lp.PaddingBottom = UDim.new(0, PAD)
        lp.Parent = sf

        return sf
    end

    local left  = makeCol(0.5, 0,   PAD, 3)
    local right = makeCol(0.5, 0.5, 3,   PAD)

    return wrapper, left, right
end

-- Slider row
local function SliderRow(parent, labelText, minV, maxV, initV, step, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, BTN_H + 6)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = Label(row, labelText, FONT_MD, C.TEXT, FONT_SEMI)
    lbl.Size = UDim2.new(0.65, 0, 0, 14)

    local valLbl = Label(row, tostring(initV), FONT_MD, C.ACCENT_LIT, FONT_BOLD, Enum.TextXAlignment.Right)
    valLbl.Size = UDim2.new(0.35, 0, 0, 14)

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 20)
    track.BackgroundColor3 = C.CARD
    track.BorderSizePixel = 0
    track.Parent = row
    Corner(track, 3)

    local fillPct = (initV - minV) / math.max(maxV - minV, 0.001)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(fillPct, 0, 1, 0)
    fill.BackgroundColor3 = C.ACCENT_LIT
    fill.BorderSizePixel = 0
    fill.Parent = track
    Corner(fill, 3)

    local thumb = Instance.new("TextButton")
    thumb.Size = UDim2.new(0, 14, 0, 14)
    thumb.Position = UDim2.new(fillPct, -7, 0.5, -7)
    thumb.BackgroundColor3 = C.WHITE
    thumb.Text = ""
    thumb.AutoButtonColor = false
    thumb.Parent = track
    Corner(thumb, 7)

    local currentVal = initV
    local dragging   = false

    local function UpdateSlider(absX)
        local tp  = track.AbsolutePosition.X
        local ts  = track.AbsoluteSize.X
        local pct = math.clamp((absX - tp) / ts, 0, 1)
        local raw = minV + (maxV - minV) * pct
        local steps = math.round((raw - minV) / step)
        currentVal = math.clamp(minV + steps * step, minV, maxV)
        local np = (currentVal - minV) / math.max(maxV - minV, 0.001)
        fill.Size  = UDim2.new(np, 0, 1, 0)
        thumb.Position = UDim2.new(np, -7, 0.5, -7)
        valLbl.Text = tostring(math.round(currentVal * 100) / 100)
        onChange(currentVal)
    end

    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    thumb.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType == Enum.UserInputType.MouseMovement
        or i.UserInputType == Enum.UserInputType.Touch then UpdateSlider(i.Position.X) end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then UpdateSlider(i.Position.X) end
    end)

    return row
end

-- ================================================
-- BUILD MAIN GUI
-- ================================================
if PlayerGui:FindFirstChild("APDScript") then
    PlayerGui:FindFirstChild("APDScript"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "APDScript"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- Main window
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, GUI_W, 0, GUI_H)
Main.Position = UDim2.new(0.5, -GUI_W / 2, 0.5, -GUI_H / 2)
Main.BackgroundColor3 = C.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui
Corner(Main, 10)
Stroke(Main, C.BORDER, 1)

local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 40, 1, 40)
Shadow.Position = UDim2.new(0, -20, 0, -20)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = 0
Shadow.Parent = Main

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, HDR_H)
Header.BackgroundColor3 = C.PANEL
Header.BorderSizePixel = 0
Header.Parent = Main
Corner(Header, 10)
local HFix = Instance.new("Frame")
HFix.Size = UDim2.new(1, 0, 0, 10)
HFix.Position = UDim2.new(0, 0, 1, -10)
HFix.BackgroundColor3 = C.PANEL
HFix.BorderSizePixel = 0
HFix.Parent = Header

local HTitle = Label(Header, "APD Hub", FONT_LG, C.WHITE, FONT_BOLD)
HTitle.Size = UDim2.new(0, 120, 1, 0)
HTitle.Position = UDim2.new(0, 14, 0, 0)

local HSub = Label(Header, "v3.0  |  Anime Power Defense", FONT_SM, C.SUBTEXT, FONT_SEMI)
HSub.Size = UDim2.new(0, 260, 1, 0)
HSub.Position = UDim2.new(0, 134, 0, 0)

-- Minimize button
local MinBtn = Btn(Header, "—", C.CARD, function() end)
MinBtn.Size = UDim2.new(0, 28, 0, 24)
MinBtn.Position = UDim2.new(1, -36, 0.5, -12)
MinBtn.TextColor3 = C.SUBTEXT

-- Minimized icon (draggable, right side like Goomba Hub)
local MinIcon = Instance.new("TextButton")
MinIcon.Size = UDim2.new(0, 56, 0, 56)
MinIcon.Position = UDim2.new(1, -76, 0.5, -28)
MinIcon.BackgroundColor3 = C.PANEL
MinIcon.Text = "⚔"
MinIcon.TextSize = FONT_XL
MinIcon.TextColor3 = C.ACCENT_LIT
MinIcon.Font = FONT_BOLD
MinIcon.Visible = false
MinIcon.Active = true
MinIcon.Parent = ScreenGui
Corner(MinIcon, 10)
Stroke(MinIcon, C.BORDER, 1)
local MinIconSub = Label(MinIcon, "APD", FONT_SM - 1, C.SUBTEXT, FONT_SEMI, Enum.TextXAlignment.Center)
MinIconSub.Size = UDim2.new(1, 0, 0, 12)
MinIconSub.Position = UDim2.new(0, 0, 1, -14)

local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    Main.Visible = false
    MinIcon.Visible = true
end)
MinIcon.MouseButton1Click:Connect(function()
    -- small drag vs click detection
    isMinimized = false
    Main.Visible = true
    MinIcon.Visible = false
end)

-- Drag: main window
local drag, dragStart, dragPos = false, nil, nil
local function OnDragMove(input)
    if not drag then return end
    local d = input.Position - dragStart
    Main.Position = UDim2.new(dragPos.X.Scale, dragPos.X.Offset + d.X,
                               dragPos.Y.Scale, dragPos.Y.Offset + d.Y)
end
Header.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        drag = true; dragStart = i.Position; dragPos = Main.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then drag = false end
        end)
    end
end)
Header.InputChanged:Connect(OnDragMove)
UserInputService.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch then OnDragMove(i) end
end)

-- Drag: mini icon
local mdrag, mdragStart, mdragPos = false, nil, nil
MinIcon.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1
    or i.UserInputType == Enum.UserInputType.Touch then
        mdrag = true; mdragStart = i.Position; mdragPos = MinIcon.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then mdrag = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not mdrag then return end
    if i.UserInputType == Enum.UserInputType.MouseMovement
    or i.UserInputType == Enum.UserInputType.Touch then
        local d = i.Position - mdragStart
        MinIcon.Position = UDim2.new(mdragPos.X.Scale, mdragPos.X.Offset + d.X,
                                      mdragPos.Y.Scale, mdragPos.Y.Offset + d.Y)
    end
end)

-- Body
local Body = Instance.new("Frame")
Body.Size = UDim2.new(1, 0, 1, -HDR_H)
Body.Position = UDim2.new(0, 0, 0, HDR_H)
Body.BackgroundTransparency = 1
Body.Parent = Main

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, 0)
Sidebar.BackgroundColor3 = C.SIDEBAR
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Body
Corner(Sidebar, 10)
local SFix = Instance.new("Frame")
SFix.Size = UDim2.new(0, 10, 1, 0)
SFix.Position = UDim2.new(1, -10, 0, 0)
SFix.BackgroundColor3 = C.SIDEBAR
SFix.BorderSizePixel = 0
SFix.Parent = Sidebar

local SLayout = Instance.new("UIListLayout")
SLayout.SortOrder = Enum.SortOrder.LayoutOrder
SLayout.Padding = UDim.new(0, 2)
SLayout.Parent = Sidebar

local SPad = Instance.new("UIPadding")
SPad.PaddingLeft = UDim.new(0, 6); SPad.PaddingRight  = UDim.new(0, 6)
SPad.PaddingTop  = UDim.new(0, 8); SPad.PaddingBottom = UDim.new(0, 8)
SPad.Parent = Sidebar

-- Content area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -SIDEBAR_W, 1, 0)
ContentArea.Position = UDim2.new(0, SIDEBAR_W, 0, 0)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Body

-- Content header strip
local ContentHeader = Instance.new("Frame")
ContentHeader.Size = UDim2.new(1, 0, 0, 30)
ContentHeader.BackgroundColor3 = C.PANEL
ContentHeader.BorderSizePixel = 0
ContentHeader.Parent = ContentArea
local ContentTitle = Label(ContentHeader, "Main", FONT_LG, C.WHITE, FONT_BOLD)
ContentTitle.Size = UDim2.new(1, -12, 1, 0)
ContentTitle.Position = UDim2.new(0, 12, 0, 0)

-- Status bar
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, 0, 0, 20)
StatusBar.Position = UDim2.new(0, 0, 1, -20)
StatusBar.BackgroundColor3 = C.PANEL
StatusBar.BorderSizePixel = 0
StatusBar.ZIndex = 5
StatusBar.Parent = ContentArea
local StatusTxt = Label(StatusBar, "● Ready", FONT_SM, C.GREEN, FONT_SEMI)
StatusTxt.Size = UDim2.new(0.6, 0, 1, 0)
StatusTxt.Position = UDim2.new(0, 8, 0, 0)
StatusTxt.ZIndex = 6
local ActionCountLbl = Label(StatusBar, "Actions: 0", FONT_SM, C.SUBTEXT, FONT_SEMI, Enum.TextXAlignment.Right)
ActionCountLbl.Size = UDim2.new(0.4, 0, 1, 0)
ActionCountLbl.ZIndex = 6

local function SetStatus(text, color)
    StatusTxt.Text = "● " .. text
    StatusTxt.TextColor3 = color or C.GREEN
end
local function UpdateActionCount()
    ActionCountLbl.Text = "Actions: " .. #MacroEngine.Actions
end

-- Page area
local PageArea = Instance.new("Frame")
PageArea.Size = UDim2.new(1, 0, 1, -50)
PageArea.Position = UDim2.new(0, 0, 0, 30)
PageArea.BackgroundTransparency = 1
PageArea.Parent = ContentArea

-- ================================================
-- PAGE SYSTEM
-- ================================================
local PAGES = {
    { name = "Main",    icon = "🏠" },
    { name = "Macro",   icon = "⏺" },
    { name = "AutoPlay",icon = "▶" },
    { name = "Misc",    icon = "🔧" },
    { name = "Webhook", icon = "🔗" },
}

local SideBtns   = {}
local PageFrames = {}

local function SwitchPage(name)
    ContentTitle.Text = name
    for pname, btn in pairs(SideBtns) do
        btn.BackgroundColor3 = C.SIDEBAR
        btn.BackgroundTransparency = pname == name and 0 or 1
        btn.BackgroundColor3 = pname == name and C.SIDE_ACTIVE or C.SIDEBAR
        btn.TextColor3 = pname == name and C.WHITE or C.SUBTEXT
    end
    for pname, pg in pairs(PageFrames) do
        pg.Visible = (pname == name)
    end
end

for i, entry in ipairs(PAGES) do
    local sb = Instance.new("TextButton")
    sb.Size = UDim2.new(1, 0, 0, 34)
    sb.BackgroundTransparency = 1
    sb.Text = entry.icon .. "  " .. entry.name
    sb.TextSize = FONT_MD
    sb.TextColor3 = C.SUBTEXT
    sb.Font = FONT_SEMI
    sb.TextXAlignment = Enum.TextXAlignment.Left
    sb.AutoButtonColor = false
    sb.LayoutOrder = i
    sb.Parent = Sidebar
    Corner(sb, 6)
    local sbp = Instance.new("UIPadding"); sbp.PaddingLeft = UDim.new(0, 8); sbp.Parent = sb
    SideBtns[entry.name] = sb

    local pg = Instance.new("Frame")
    pg.Size = UDim2.new(1, 0, 1, 0)
    pg.BackgroundTransparency = 1
    pg.Visible = false
    pg.Parent = PageArea
    PageFrames[entry.name] = pg

    sb.MouseButton1Click:Connect(function() SwitchPage(entry.name) end)
end

-- ================================================
-- PAGE: MAIN
-- ================================================
local _, MLeft, MRight = TwoColFrame(PageFrames["Main"])

SectionLabel(MLeft, "Auto Farm")
ToggleRow(MLeft, "Auto Upgrade Units", Settings.auto_upgrade, function(v)
    Settings.auto_upgrade = v; SaveSettings()
    if v then StartAutoUpgrade() end
    SetStatus(v and "Auto Upgrading..." or "Ready", v and C.GREEN or C.SUBTEXT)
end)
ToggleRow(MLeft, "Auto Skip Wave", Settings.auto_skip, function(v)
    Settings.auto_skip = v; SaveSettings()
    if v then StartAutoSkip() end
    SetStatus(v and "Auto Skipping..." or "Ready", v and C.GREEN or C.SUBTEXT)
end)
ToggleRow(MLeft, "Auto Replay", Settings.auto_replay, function(v)
    Settings.auto_replay = v; SaveSettings()
    if v then StartAutoReplay() end
    SetStatus(v and "Auto Replaying..." or "Ready", v and C.GREEN or C.SUBTEXT)
end)

Divider(MLeft)
SectionLabel(MLeft, "Game Speed")

local SpeedVals = { 1, 1.5, 2 }
local SpeedIdx  = 2
for i, s in ipairs(SpeedVals) do if s == Settings.gamespeed then SpeedIdx = i end end

local SpeedRow = Instance.new("Frame")
SpeedRow.Size = UDim2.new(1, 0, 0, BTN_H)
SpeedRow.BackgroundTransparency = 1
SpeedRow.Parent = MLeft
local SpeedLbl = Label(SpeedRow, "Speed • " .. Settings.gamespeed .. "x", FONT_MD, C.TEXT, FONT_SEMI)
SpeedLbl.Size = UDim2.new(0.58, 0, 1, 0)
local SpdDec = Btn(SpeedRow, "<", C.ACCENT, function()
    SpeedIdx = math.max(1, SpeedIdx - 1)
    Settings.gamespeed = SpeedVals[SpeedIdx]
    SpeedLbl.Text = "Speed • " .. Settings.gamespeed .. "x"
    SaveSettings()
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
end)
SpdDec.Size = UDim2.new(0, 28, 0, 24); SpdDec.Position = UDim2.new(1, -60, 0.5, -12)
local SpdInc = Btn(SpeedRow, ">", C.ACCENT, function()
    SpeedIdx = math.min(#SpeedVals, SpeedIdx + 1)
    Settings.gamespeed = SpeedVals[SpeedIdx]
    SpeedLbl.Text = "Speed • " .. Settings.gamespeed .. "x"
    SaveSettings()
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
end)
SpdInc.Size = UDim2.new(0, 28, 0, 24); SpdInc.Position = UDim2.new(1, -28, 0.5, -12)

ToggleRow(MLeft, "Auto Set Gamespeed", Settings.auto_gamespeed, function(v)
    Settings.auto_gamespeed = v; SaveSettings()
    if v then pcall(SetGamespeed, Settings.gamespeed) end
end)

Divider(MLeft)
SectionLabel(MLeft, "Delays")
SliderRow(MLeft, "Upgrade Delay (s)", 0.1, 3, Settings.upgrade_delay, 0.1, function(v)
    Settings.upgrade_delay = v; SaveSettings()
end)
SliderRow(MLeft, "Skip Delay (s)", 1, 15, Settings.skip_delay, 1, function(v)
    Settings.skip_delay = v; SaveSettings()
end)

-- Right: one-shot actions
SectionLabel(MRight, "One-Shot Actions")
BtnRow(MRight, "⬆  Upgrade All", C.ACCENT, function()
    task.spawn(function()
        SetStatus("Upgrading...", C.ORANGE)
        local ok, placed = pcall(GetPlacedUnits)
        if ok and placed then
            for guid, ud in pairs(placed) do
                local uid = tostring(ud.Type); local lv, mx = 0, 0
                if ud.Info and ud.Info[uid] then
                    lv = ud.Info[uid].Upgrade or 0
                    if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx = #ud.Info[uid].Data.upgrades end
                end
                if lv < mx then pcall(UpgradeUnit, guid) task.wait(0.3) end
            end
        end
        SetStatus("Done!", C.GREEN)
    end)
end)

BtnRow(MRight, "💰  Sell All Units", C.RED, function()
    task.spawn(function()
        SetStatus("Selling...", C.ORANGE)
        local ok, placed = pcall(GetPlacedUnits)
        if ok and placed then
            for g, _ in pairs(placed) do pcall(SellUnit, g) task.wait(0.3) end
        end
        SetStatus("All sold!", C.GREEN)
    end)
end)

BtnRow(MRight, "⏭  Vote Skip Wave", C.ACCENT, function()
    pcall(VoteSkipWave); SetStatus("Skip voted!", C.GREEN)
end)

BtnRow(MRight, "🔁  Replay Game", C.ACCENT, function()
    pcall(Replay); SetStatus("Retry sent!", C.GREEN)
end)

BtnRow(MRight, "⚡  Set Speed Now", C.ACCENT, function()
    pcall(SetGamespeed, Settings.gamespeed)
    SetStatus("Speed set to " .. Settings.gamespeed .. "x", C.GREEN)
end)

-- ================================================
-- PAGE: MACRO
-- ================================================
local _, MacLeft, MacRight = TwoColFrame(PageFrames["Macro"])

SectionLabel(MacLeft, "Recording")

-- Name input
local NameRow = Instance.new("Frame")
NameRow.Size = UDim2.new(1, 0, 0, BTN_H)
NameRow.BackgroundTransparency = 1
NameRow.Parent = MacLeft
local NameLbl = Label(NameRow, "Name:", FONT_MD, C.SUBTEXT, FONT_SEMI)
NameLbl.Size = UDim2.new(0, 44, 1, 0)
local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(1, -48, 0, BTN_H - 6)
NameBox.Position = UDim2.new(0, 48, 0, 3)
NameBox.BackgroundColor3 = C.CARD
NameBox.TextColor3 = C.WHITE
NameBox.PlaceholderText = "macro name…"
NameBox.PlaceholderColor3 = C.SUBTEXT
NameBox.TextSize = FONT_MD
NameBox.Font = FONT_SEMI
NameBox.ClearTextOnFocus = false
NameBox.Text = MacroEngine.CurrentName
NameBox.Parent = NameRow
Corner(NameBox, 5)
local NBPad = Instance.new("UIPadding"); NBPad.PaddingLeft = UDim.new(0, 6); NBPad.Parent = NameBox

-- Status display row
local MacStatRow = Instance.new("Frame")
MacStatRow.Size = UDim2.new(1, 0, 0, BTN_H)
MacStatRow.BackgroundColor3 = C.CARD
MacStatRow.Parent = MacLeft
Corner(MacStatRow, 6)
local MacStatLbl = Label(MacStatRow, "Status: Idle", FONT_MD, C.SUBTEXT, FONT_SEMI)
MacStatLbl.Size = UDim2.new(0.6, 0, 1, 0)
MacStatLbl.Position = UDim2.new(0, 8, 0, 0)
local MacActLbl = Label(MacStatRow, "Actions: 0", FONT_MD, C.SUBTEXT, FONT_SEMI, Enum.TextXAlignment.Right)
MacActLbl.Size = UDim2.new(0.4, 0, 1, 0)

local function RefreshMacStatus()
    MacActLbl.Text = "Actions: " .. #MacroEngine.Actions
    if MacroEngine.IsRecording then
        MacStatLbl.Text = "● Recording"; MacStatLbl.TextColor3 = C.RED
    elseif MacroEngine.IsPlaying then
        MacStatLbl.Text = "● Playing";   MacStatLbl.TextColor3 = C.GREEN
    else
        MacStatLbl.Text = "Status: Idle"; MacStatLbl.TextColor3 = C.SUBTEXT
    end
end

-- Record/Stop
local isRec  = false
local RecBtn = BtnRow(MacLeft, "🔴  Start Recording", C.RED, function() end)
RecBtn.MouseButton1Click:Connect(function()
    isRec = not isRec
    if isRec then
        MacroEngine:StartRecording()
        RecBtn.Text = "⏹  Stop Recording"
        RecBtn.BackgroundColor3 = C.CARD
        SetStatus("Recording…", C.RED)
    else
        MacroEngine:StopRecording()
        RecBtn.Text = "🔴  Start Recording"
        RecBtn.BackgroundColor3 = C.RED
        SetStatus("Stopped — " .. #MacroEngine.Actions .. " actions", C.ORANGE)
        UpdateActionCount(); RefreshMacStatus()
    end
end)

-- Play/Stop toggle
local PlayBtn = BtnRow(MacLeft, "▶  Play Macro (loop)", C.GREEN, function() end)
PlayBtn.MouseButton1Click:Connect(function()
    if MacroEngine.IsPlaying then
        MacroEngine:StopPlayback()
        Settings.play_macro = false; SaveSettings()
        PlayBtn.Text = "▶  Play Macro (loop)"
        PlayBtn.BackgroundColor3 = C.GREEN
        SetStatus("Macro stopped", C.SUBTEXT); RefreshMacStatus()
    else
        if #MacroEngine.Actions == 0 then SetStatus("Load a macro first!", C.RED); return end
        Settings.play_macro = true; SaveSettings()
        MacroEngine:StartPlayback(function(loops)
            Settings.play_macro = false; SaveSettings()
            PlayBtn.Text = "▶  Play Macro (loop)"
            PlayBtn.BackgroundColor3 = C.GREEN
            SetStatus("Finished (" .. loops .. " loops)", C.SUBTEXT); RefreshMacStatus()
        end)
        PlayBtn.Text = "⏹  Stop Macro"
        PlayBtn.BackgroundColor3 = C.RED
        SetStatus("Playing: " .. (MacroEngine.CurrentName ~= "" and MacroEngine.CurrentName or "macro"), C.GREEN)
        RefreshMacStatus()
    end
end)

-- Step delay
SectionLabel(MacLeft, "Step Delay")
SliderRow(MacLeft, "Delay (s)", 0.05, 2, Settings.macro_speed, 0.05, function(v)
    Settings.macro_speed = v; MacroEngine.StepDelay = v; SaveSettings()
end)

SectionLabel(MacLeft, "Playback Speed")
SliderRow(MacLeft, "Speed Multiplier", 0.25, 4, MacroEngine.Speed, 0.25, function(v)
    MacroEngine.Speed = v
    SetStatus("Macro speed: " .. v .. "x", C.SUBTEXT)
end)

Divider(MacLeft)
SectionLabel(MacLeft, "Save / Manage")
BtnRow(MacLeft, "💾  Save Macro", C.GREEN, function()
    local n = NameBox.Text
    if n == "" then SetStatus("Enter a name first!", C.RED); return end
    if #MacroEngine.Actions == 0 then SetStatus("Nothing recorded!", C.RED); return end
    MacroEngine:Save(n)
    SetStatus("Saved: " .. n, C.GREEN)
    UpdateActionCount(); RefreshMacStatus()
    RefreshMacroList()
end)
BtnRow(MacLeft, "🗑  Delete Macro", Color3.fromRGB(120, 40, 40), function()
    local n = NameBox.Text
    if n == "" then SetStatus("Enter macro name!", C.RED); return end
    MacroEngine:Delete(n)
    SetStatus("Deleted: " .. n, C.ORANGE)
end)
BtnRow(MacLeft, "🔄  Clear Actions", C.CARD, function()
    MacroEngine.Actions = {}
    UpdateActionCount(); RefreshMacStatus()
    SetStatus("Actions cleared", C.SUBTEXT)
end)

-- Right: profiles + APD record actions
SectionLabel(MacRight, "Macro Profiles")

local macroRows     = {}
local selectedMacro = MacroEngine.CurrentName

local MacroListFrame = Instance.new("Frame")
MacroListFrame.Name = "MacroListFrame"
MacroListFrame.Size = UDim2.new(1, 0, 0, 0)
MacroListFrame.AutomaticSize = Enum.AutomaticSize.Y
MacroListFrame.BackgroundColor3 = C.CARD
MacroListFrame.Parent = MacRight
Corner(MacroListFrame, 6)

local MLL = Instance.new("UIListLayout")
MLL.SortOrder = Enum.SortOrder.LayoutOrder
MLL.Padding = UDim.new(0, 2)
MLL.Parent = MacroListFrame

local MLPad = Instance.new("UIPadding")
MLPad.PaddingLeft=UDim.new(0,6); MLPad.PaddingRight=UDim.new(0,6)
MLPad.PaddingTop=UDim.new(0,6);  MLPad.PaddingBottom=UDim.new(0,6)
MLPad.Parent = MacroListFrame

local function RefreshMacroList()
    for _, b in pairs(macroRows) do b:Destroy() end
    macroRows = {}
    local list = MacroEngine:List()
    if #list == 0 then
        local el = Label(MacroListFrame, "No macros saved.", FONT_MD, C.SUBTEXT, FONT_SEMI)
        el.Size = UDim2.new(1, 0, 0, 28)
        table.insert(macroRows, el); return
    end
    for _, name in ipairs(list) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, BTN_H - 4)
        row.BackgroundColor3 = (name == selectedMacro) and C.ACCENT or C.BG
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = MacroListFrame
        Corner(row, 5)
        local ico = Label(row, "▶", FONT_MD, C.ACCENT_LIT, FONT_BOLD, Enum.TextXAlignment.Center)
        ico.Size = UDim2.new(0, 20, 1, 0); ico.Position = UDim2.new(0, 2, 0, 0)
        local nl = Label(row, name, FONT_MD, C.TEXT, FONT_SEMI)
        nl.Size = UDim2.new(1, -24, 1, 0); nl.Position = UDim2.new(0, 24, 0, 0)
        row.MouseButton1Click:Connect(function()
            selectedMacro = name
            NameBox.Text = name
            MacroEngine:Load(name)
            UpdateActionCount(); RefreshMacStatus()
            SetStatus("Loaded: " .. name, C.GREEN)
            RefreshMacroList()
        end)
        table.insert(macroRows, row)
    end
end
RefreshMacroList()

BtnRow(MacRight, "🔄  Refresh List", C.CARD, function()
    RefreshMacroList(); SetStatus("List refreshed", C.SUBTEXT)
end)

Divider(MacRight)
SectionLabel(MacRight, "Record APD Actions")

local apdActions = {
    { "📌 Upgrade All",   "upgrade_all", {} },
    { "📌 Sell All",      "sell_all",    {} },
    { "📌 Skip Wave",     "skip_wave",   {} },
    { "📌 Replay",        "replay",      {} },
    { "📌 Wait 3s",       "wait",        { 3 } },
    { "📌 Wait 5s",       "wait",        { 5 } },
    { "📌 Wait 10s",      "wait",        { 10 } },
    { "📌 Set Speed 1x",  "set_speed",   { 1 } },
    { "📌 Set Speed 1.5x","set_speed",   { 1.5 } },
    { "📌 Set Speed 2x",  "set_speed",   { 2 } },
}
for _, entry in ipairs(apdActions) do
    local lbl, atype, adata = entry[1], entry[2], entry[3]
    BtnRow(MacRight, lbl, C.CARD, function()
        MacroEngine:RecordAction(atype, adata)
        UpdateActionCount(); RefreshMacStatus()
        SetStatus("Recorded: " .. atype, C.GREEN)
    end)
end

-- ================================================
-- PAGE: AUTOPLAY — live per-unit panel with auto-refresh
-- ================================================
local APScroll = ScrollFrame(PageFrames["AutoPlay"])

SectionLabel(APScroll, "Auto Upgrade")
ToggleRow(APScroll, "Enable Auto Upgrade", Settings.auto_upgrade, function(v)
    Settings.auto_upgrade = v; SaveSettings()
    if v then StartAutoUpgrade() end
    SetStatus(v and "Auto Upgrading..." or "Ready", v and C.GREEN or C.SUBTEXT)
end)

SliderRow(APScroll, "Upgrade Delay (s)", 0.1, 3, Settings.upgrade_delay, 0.1, function(v)
    Settings.upgrade_delay = v; SaveSettings()
end)

Divider(APScroll)
SectionLabel(APScroll, "Bulk Actions")

BtnRow(APScroll, "⬆  Upgrade All Now", C.ACCENT, function()
    task.spawn(function()
        SetStatus("Upgrading...", C.ORANGE)
        local ok, placed = pcall(GetPlacedUnits)
        if ok and placed then
            for guid, ud in pairs(placed) do
                local uid = tostring(ud.Type); local lv, mx = 0, 0
                if ud.Info and ud.Info[uid] then
                    lv = ud.Info[uid].Upgrade or 0
                    if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx = #ud.Info[uid].Data.upgrades end
                end
                if lv < mx then pcall(UpgradeUnit, guid) task.wait(Settings.upgrade_delay) end
            end
        end
        SetStatus("Done!", C.GREEN)
    end)
end)

BtnRow(APScroll, "💰  Sell All Units", C.RED, function()
    task.spawn(function()
        SetStatus("Selling...", C.ORANGE)
        local ok, placed = pcall(GetPlacedUnits)
        if ok and placed then
            for g, _ in pairs(placed) do pcall(SellUnit, g) task.wait(0.3) end
        end
        SetStatus("All sold!", C.GREEN)
    end)
end)

Divider(APScroll)
SectionLabel(APScroll, "Placed Units  (live)")

-- Auto-refresh toggle
local apAutoRefresh = false
local apRefreshConn = nil

-- Units list container
local UnitsListFrame = Instance.new("Frame")
UnitsListFrame.Size = UDim2.new(1, 0, 0, 0)
UnitsListFrame.AutomaticSize = Enum.AutomaticSize.Y
UnitsListFrame.BackgroundColor3 = C.CARD
UnitsListFrame.Parent = APScroll
Corner(UnitsListFrame, 6)

local ULLayout = Instance.new("UIListLayout")
ULLayout.SortOrder = Enum.SortOrder.LayoutOrder
ULLayout.Padding = UDim.new(0, 3)
ULLayout.Parent = UnitsListFrame

local ULPad = Instance.new("UIPadding")
ULPad.PaddingLeft=UDim.new(0,6); ULPad.PaddingRight=UDim.new(0,6)
ULPad.PaddingTop=UDim.new(0,6);  ULPad.PaddingBottom=UDim.new(0,6)
ULPad.Parent = UnitsListFrame

local APPlaceholder = Label(UnitsListFrame, "Press Refresh to see units", FONT_MD, C.SUBTEXT, FONT_SEMI)
APPlaceholder.Size = UDim2.new(1, 0, 0, 28)

local apUnitRows = {}

local function RefreshUnitsPanel()
    for _, r in pairs(apUnitRows) do pcall(function() r:Destroy() end) end
    apUnitRows = {}
    APPlaceholder.Visible = false

    local ok, placed = pcall(GetPlacedUnits)
    if not ok or not placed then
        APPlaceholder.Text = "Not in a game"
        APPlaceholder.Visible = true
        return
    end

    local count = 0
    for guid, ud in pairs(placed) do
        count += 1
        local uid   = tostring(ud.Type)
        local lv, mx = 0, 0
        if ud.Info and ud.Info[uid] then
            lv = ud.Info[uid].Upgrade or 0
            if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then
                mx = #ud.Info[uid].Data.upgrades
            end
        end
        local maxed = (lv >= mx and mx > 0)

        -- Row: name + level label + Upgrade btn + Sell btn
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, BTN_H - 4)
        row.BackgroundColor3 = maxed and Color3.fromRGB(28, 50, 35) or C.BG
        row.Parent = UnitsListFrame
        Corner(row, 5)

        local nameLbl = Label(row, uid, FONT_SM, C.TEXT, FONT_SEMI)
        nameLbl.Size    = UDim2.new(0.38, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 4, 0, 0)

        local lvLbl = Label(row,
            maxed and "MAX" or ("Lv "..lv.."/"..mx),
            FONT_SM,
            maxed and C.GREEN or C.ACCENT_LIT,
            FONT_BOLD,
            Enum.TextXAlignment.Center)
        lvLbl.Size     = UDim2.new(0.24, 0, 1, 0)
        lvLbl.Position = UDim2.new(0.38, 0, 0, 0)

        -- Upgrade button (disabled if maxed)
        local upgBtn = Btn(row, "⬆", maxed and C.TOGGLE_OFF or C.ACCENT, function()
            if maxed then return end
            pcall(UpgradeUnit, guid)
            task.wait(0.3)
            RefreshUnitsPanel()
            SetStatus("Upgraded unit", C.GREEN)
        end)
        upgBtn.Size     = UDim2.new(0, 38, 0, BTN_H - 12)
        upgBtn.Position = UDim2.new(0.62, 2, 0.5, -(BTN_H - 12) / 2)
        upgBtn.TextSize = FONT_SM

        -- Sell button
        local sellBtn = Btn(row, "💰", Color3.fromRGB(130, 40, 40), function()
            pcall(SellUnit, guid)
            task.wait(0.2)
            RefreshUnitsPanel()
            SetStatus("Sold unit", C.ORANGE)
        end)
        sellBtn.Size     = UDim2.new(0, 38, 0, BTN_H - 12)
        sellBtn.Position = UDim2.new(1, -40, 0.5, -(BTN_H - 12) / 2)
        sellBtn.TextSize = FONT_SM

        table.insert(apUnitRows, row)
    end

    if count == 0 then
        APPlaceholder.Text = "No units placed"
        APPlaceholder.Visible = true
    end
end

-- Manual refresh button
BtnRow(APScroll, "🔄  Refresh Units", C.CARD, function()
    RefreshUnitsPanel()
    SetStatus("Units refreshed", C.SUBTEXT)
end)

-- Auto-refresh toggle (polls every 3 s while active)
ToggleRow(APScroll, "Auto-Refresh Panel (3s)", false, function(v)
    apAutoRefresh = v
    if v then
        if apRefreshConn then apRefreshConn:Disconnect() apRefreshConn = nil end
        RefreshUnitsPanel()
        apRefreshConn = RunService.Heartbeat:Connect(function()
            if not apAutoRefresh then
                apRefreshConn:Disconnect(); apRefreshConn = nil; return
            end
        end)
        -- Polling loop
        task.spawn(function()
            while apAutoRefresh do
                task.wait(3)
                if apAutoRefresh then pcall(RefreshUnitsPanel) end
            end
        end)
        SetStatus("Auto-refresh ON", C.GREEN)
    else
        if apRefreshConn then apRefreshConn:Disconnect(); apRefreshConn = nil end
        SetStatus("Auto-refresh OFF", C.SUBTEXT)
    end
end)

-- ================================================
-- PAGE: MISC
-- ================================================
local _, MiscLeft, MiscRight = TwoColFrame(PageFrames["Misc"])

SectionLabel(MiscLeft, "Display")

ToggleRow(MiscLeft, "Auto Hide Game UI", Settings.auto_hide_ui, function(v)
    Settings.auto_hide_ui = v; SaveSettings()
    ApplyAutoHideUI(v)
    SetStatus(v and "Game UI hidden" or "Game UI shown", v and C.ORANGE or C.GREEN)
end)

ToggleRow(MiscLeft, "FPS Booster", Settings.fps_booster, function(v)
    Settings.fps_booster = v; SaveSettings()
    ApplyFpsBooster(v)
    SetStatus(v and "FPS Booster ON" or "FPS Booster OFF", v and C.GREEN or C.SUBTEXT)
end)

Divider(MiscLeft)
SectionLabel(MiscLeft, "Config")

BtnRow(MiscLeft, "📋  Copy Config to Clipboard", C.CARD, function()
    local cfg = HttpService:JSONEncode(Settings)
    pcall(function() setclipboard(cfg) end)
    SetStatus("Config copied!", C.GREEN)
end)

BtnRow(MiscLeft, "📥  Import Config from Clipboard", C.CARD, function()
    pcall(function()
        local txt = getclipboard()
        local ok, d = pcall(function() return HttpService:JSONDecode(txt) end)
        if ok and d then
            for k, v in pairs(d) do Settings[k] = v end
            SaveSettings()
            SetStatus("Config imported!", C.GREEN)
        else
            SetStatus("Invalid config in clipboard", C.RED)
        end
    end)
end)

Divider(MiscLeft)
SectionLabel(MiscLeft, "Script")

BtnRow(MiscLeft, "Reset All Settings", Color3.fromRGB(110, 40, 40), function()
    Settings = {
        gamespeed=1.5, auto_gamespeed=false, macro_speed=0.2,
        auto_upgrade=false, auto_skip=false, auto_replay=false,
        upgrade_delay=0.5, skip_delay=3,
        play_macro=false, macro_profile="",
        auto_hide_ui=false, fps_booster=false,
        webhook_url="", webhook_enabled=false, discord_id="", webhook_ping=true,
    }
    MacroEngine.Speed = 1; MacroEngine.StepDelay = 0.2
    SaveSettings()
    SetStatus("Settings reset!", C.ORANGE)
end)

BtnRow(MiscLeft, "🔄  Reload Script", C.CARD, function()
    if PlayerGui:FindFirstChild("APDScript") then
        PlayerGui:FindFirstChild("APDScript"):Destroy()
    end
end)

-- Right: info
SectionLabel(MiscRight, "Info")

local function InfoRow(parent, key, value)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundColor3 = C.CARD
    row.Parent = parent
    Corner(row, 5)
    local kl = Label(row, key, FONT_SM, C.SUBTEXT, FONT_SEMI)
    kl.Size = UDim2.new(0.5, 0, 1, 0); kl.Position = UDim2.new(0, 6, 0, 0)
    local vl = Label(row, value, FONT_SM, C.TEXT, FONT_BOLD, Enum.TextXAlignment.Right)
    vl.Size = UDim2.new(0.5, 0, 1, 0)
    return vl
end

InfoRow(MiscRight, "Script Version", "v3.0")
InfoRow(MiscRight, "Game ID", "5787561793")
InfoRow(MiscRight, "Platform", IsMobile and "Mobile" or "PC")
local MacroCountLbl = InfoRow(MiscRight, "Saved Macros", tostring(#MacroEngine:List()))

BtnRow(MiscRight, "🔄  Refresh Info", C.CARD, function()
    MacroCountLbl.Text = tostring(#MacroEngine:List())
    SetStatus("Info updated", C.SUBTEXT)
end)

-- ================================================
-- PAGE: WEBHOOK
-- ================================================
local WHScroll = ScrollFrame(PageFrames["Webhook"])

SectionLabel(WHScroll, "Discord Webhook")

-- URL input
local WHUrlRow = Instance.new("Frame")
WHUrlRow.Size = UDim2.new(1, 0, 0, BTN_H)
WHUrlRow.BackgroundTransparency = 1
WHUrlRow.Parent = WHScroll
local WHUrlLbl = Label(WHUrlRow, "Webhook URL", FONT_MD, C.SUBTEXT, FONT_SEMI)
WHUrlLbl.Size = UDim2.new(0, 100, 1, 0)
local WHUrlBox = Instance.new("TextBox")
WHUrlBox.Size = UDim2.new(1, -104, 0, BTN_H - 6)
WHUrlBox.Position = UDim2.new(0, 104, 0, 3)
WHUrlBox.BackgroundColor3 = C.CARD
WHUrlBox.TextColor3 = C.WHITE
WHUrlBox.PlaceholderText = "https://discord.com/api/webhooks/…"
WHUrlBox.PlaceholderColor3 = C.SUBTEXT
WHUrlBox.TextSize = FONT_MD - 1
WHUrlBox.Font = FONT_SEMI
WHUrlBox.ClearTextOnFocus = false
WHUrlBox.Text = Settings.webhook_url or ""
WHUrlBox.Parent = WHUrlRow
Corner(WHUrlBox, 5)
local WHUPad = Instance.new("UIPadding"); WHUPad.PaddingLeft = UDim.new(0, 6); WHUPad.Parent = WHUrlBox
WHUrlBox.FocusLost:Connect(function()
    Settings.webhook_url = WHUrlBox.Text; SaveSettings()
end)

-- Discord ID input
local WHIDRow = Instance.new("Frame")
WHIDRow.Size = UDim2.new(1, 0, 0, BTN_H)
WHIDRow.BackgroundTransparency = 1
WHIDRow.Parent = WHScroll
local WHIDLbl = Label(WHIDRow, "Discord ID", FONT_MD, C.SUBTEXT, FONT_SEMI)
WHIDLbl.Size = UDim2.new(0, 100, 1, 0)
local WHIDBox = Instance.new("TextBox")
WHIDBox.Size = UDim2.new(1, -104, 0, BTN_H - 6)
WHIDBox.Position = UDim2.new(0, 104, 0, 3)
WHIDBox.BackgroundColor3 = C.CARD
WHIDBox.TextColor3 = C.WHITE
WHIDBox.PlaceholderText = "your numeric user ID"
WHIDBox.PlaceholderColor3 = C.SUBTEXT
WHIDBox.TextSize = FONT_MD
WHIDBox.Font = FONT_SEMI
WHIDBox.ClearTextOnFocus = false
WHIDBox.Text = Settings.discord_id or ""
WHIDBox.Parent = WHIDRow
Corner(WHIDBox, 5)
local WHIPad = Instance.new("UIPadding"); WHIPad.PaddingLeft = UDim.new(0, 6); WHIPad.Parent = WHIDBox
WHIDBox.FocusLost:Connect(function()
    Settings.discord_id = WHIDBox.Text; SaveSettings()
end)

ToggleRow(WHScroll, "Webhook Enabled", Settings.webhook_enabled, function(v)
    Settings.webhook_enabled = v; SaveSettings()
    SetStatus(v and "Webhook ON" or "Webhook OFF", v and C.GREEN or C.SUBTEXT)
end)

ToggleRow(WHScroll, "Ping User on Message", Settings.webhook_ping, function(v)
    Settings.webhook_ping = v; SaveSettings()
end)

Divider(WHScroll)
SectionLabel(WHScroll, "Test & Send")

BtnRow(WHScroll, "📤  Send Test Message", C.ACCENT, function()
    local url = WHUrlBox.Text
    if url == "" then SetStatus("Enter webhook URL first!", C.RED); return end
    local ping = (Settings.webhook_ping and Settings.discord_id ~= "") and ("<@" .. Settings.discord_id .. "> ") or ""
    task.spawn(function()
        SetStatus("Sending…", C.ORANGE)
        SendWebhook(url, ping .. "✅ APD Hub v3.0 — Webhook test message!")
        SetStatus("Test sent!", C.GREEN)
    end)
end)

BtnRow(WHScroll, "📊  Send Current Status", C.ACCENT, function()
    local url = WHUrlBox.Text
    if url == "" then SetStatus("Enter webhook URL first!", C.RED); return end
    local ping = (Settings.webhook_ping and Settings.discord_id ~= "") and ("<@" .. Settings.discord_id .. "> ") or ""
    local msg = ping .. string.format(
        "**APD Hub Status**\n▶ Playing: %s\n⬆ Auto Upgrade: %s\n⏭ Auto Skip: %s\n🔁 Auto Replay: %s\n⚡ Gamespeed: %sx",
        tostring(MacroEngine.IsPlaying), tostring(Settings.auto_upgrade),
        tostring(Settings.auto_skip), tostring(Settings.auto_replay),
        tostring(Settings.gamespeed)
    )
    task.spawn(function()
        SetStatus("Sending…", C.ORANGE)
        SendWebhook(url, msg)
        SetStatus("Status sent!", C.GREEN)
    end)
end)

BtnRow(WHScroll, "💾  Save Webhook Settings", C.GREEN, function()
    Settings.webhook_url = WHUrlBox.Text
    Settings.discord_id  = WHIDBox.Text
    SaveSettings()
    SetStatus("Webhook settings saved!", C.GREEN)
end)

-- ================================================
-- Apply saved settings on load
-- ================================================
task.spawn(function()
    task.wait(2)
    if Settings.auto_gamespeed  then pcall(SetGamespeed, Settings.gamespeed) end
    if Settings.auto_upgrade    then StartAutoUpgrade() end
    if Settings.auto_skip       then StartAutoSkip()    end
    if Settings.auto_replay     then StartAutoReplay()  end
    if Settings.auto_hide_ui    then ApplyAutoHideUI(true) end
    if Settings.fps_booster     then ApplyFpsBooster(true) end
    if Settings.play_macro and Settings.macro_profile ~= "" then
        if MacroEngine:Load(Settings.macro_profile) then
            MacroEngine:StartPlayback(function(loops)
                SetStatus("Macro finished (" .. loops .. " loops)", C.SUBTEXT)
                RefreshMacStatus()
            end)
            RefreshMacStatus()
        end
    end
end)

-- Restore macro status labels
task.spawn(function()
    task.wait(3)
    UpdateActionCount()
    RefreshMacStatus()
end)

SwitchPage("Main")
UpdateActionCount()
SetStatus("Ready — APD Hub v3.0", C.GREEN)
print("[APD Hub] v3.0 loaded — clean working build")




-- ================================================
-- GOOMBA HUB REMASTER PATCH
-- ================================================

-- Visual remake values
local GOOMBA_STYLE = {
    Background = Color3.fromRGB(10,10,12),
    Sidebar = Color3.fromRGB(14,14,18),
    Panel = Color3.fromRGB(18,18,24),
    Card = Color3.fromRGB(22,22,28),
    Accent = Color3.fromRGB(110,110,255),
    AccentLight = Color3.fromRGB(170,170,255),
}

print("[Goomba Hub Remaster] Loaded Successfully")

