-- ╔══════════════════════════════════════════════════════════════╗
-- ║       BridgeNet2 Tower Defense Macro — GUI Edition v3        ║
-- ║  + Action Log  + Auto Game Speed x2  + Auto Difficulty       ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local UIS         = game:GetService("UserInputService")
local TweenService= game:GetService("TweenService")
local RunService  = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ┌─────────────────────────────────────┐
-- │         REMOTE                      │
-- └─────────────────────────────────────┘
local remote = RS:WaitForChild("BridgeNet2"):WaitForChild("dataRemoteEvent")
local oldFireServer = remote.FireServer

-- ┌─────────────────────────────────────┐
-- │         MACRO STATE                 │
-- └─────────────────────────────────────┘
local recording   = false
local playing     = false
local macro       = {}
local recordStart = 0
local playThread  = nil
local stepDelay   = 0.2
local loopPlay    = false
local actionCount = 0
local actionTotal = 0

-- Auto features state
local autoGameSpeed  = false
local autoDifficulty = false
local autoSpeedThread  = nil
local autoDiffThread   = nil

local CTRL_NAMES = {
    ["\b"] = "Replay",
    ["\v"] = "Difficulty",
    ["\t"] = "GameSpeed",
    ["\n"] = "Tower",
}

-- Readable label for a recorded entry
local function entryLabel(entry)
    local payload  = entry.args[1]
    local ctrlChar = type(payload) == "table" and payload[2] or nil
    local typeName = CTRL_NAMES[ctrlChar] or "Action"
    local data     = type(payload) == "table" and payload[1] or {}
    local unitName = (type(data) == "table" and data[1]) and tostring(data[1]) or "?"
    return string.format("[%.2fs] %s — %s", entry.time, typeName, unitName)
end

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[deepCopy(k)] = deepCopy(val) end
    return c
end

-- ┌─────────────────────────────────────┐
-- │         GUI BUILD                   │
-- └─────────────────────────────────────┘
if PlayerGui:FindFirstChild("TDMacroGui") then
    PlayerGui:FindFirstChild("TDMacroGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TDMacroGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = PlayerGui

local uiScaleVal = 0.75

local BASE_W    = 600
local BASE_H    = 480
local BASE_H_MIN = 36

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, BASE_W, 0, BASE_H)
Main.Position = UDim2.new(0, 10, 0, 60)
Main.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local border = Instance.new("UIStroke", Main)
border.Color = Color3.fromRGB(60, 60, 80)
border.Thickness = 1

local UIScaleObj = Instance.new("UIScale", Main)
UIScaleObj.Scale = uiScaleVal

local function scaledSize()
    return Vector2.new(BASE_W * UIScaleObj.Scale, BASE_H * UIScaleObj.Scale)
end

-- ── Title Bar ───────────────────────────────────────────────────
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 120, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⬡  TD MACRO v3"
TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -36, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 13
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 32, 0, 32)
MinBtn.Position = UDim2.new(1, -72, 0, 2)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200,200,220)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 13
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

local ScaleLabel = Instance.new("TextLabel")
ScaleLabel.Size = UDim2.new(0, 34, 0, 18)
ScaleLabel.Position = UDim2.new(0, 135, 0.5, -9)
ScaleLabel.BackgroundTransparency = 1
ScaleLabel.Text = "75%"
ScaleLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
ScaleLabel.Font = Enum.Font.Gotham
ScaleLabel.TextSize = 10
ScaleLabel.TextXAlignment = Enum.TextXAlignment.Left
ScaleLabel.Parent = TitleBar

local ScaleTrack = Instance.new("Frame")
ScaleTrack.Size = UDim2.new(0, 90, 0, 8)
ScaleTrack.Position = UDim2.new(0, 172, 0.5, -4)
ScaleTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ScaleTrack.BorderSizePixel = 0
ScaleTrack.Parent = TitleBar
Instance.new("UICorner", ScaleTrack).CornerRadius = UDim.new(1, 0)

local ScaleFill = Instance.new("Frame")
ScaleFill.Size = UDim2.new(0.5, 0, 1, 0)
ScaleFill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
ScaleFill.BorderSizePixel = 0
ScaleFill.Parent = ScaleTrack
Instance.new("UICorner", ScaleFill).CornerRadius = UDim.new(1, 0)

local ScaleKnob = Instance.new("Frame")
ScaleKnob.Size = UDim2.new(0, 16, 0, 16)
ScaleKnob.Position = UDim2.new(0.5, -8, 0.5, -8)
ScaleKnob.BackgroundColor3 = Color3.fromRGB(220, 220, 255)
ScaleKnob.BorderSizePixel = 0
ScaleKnob.Parent = ScaleTrack
Instance.new("UICorner", ScaleKnob).CornerRadius = UDim.new(1, 0)

local ScaleHit = Instance.new("TextButton")
ScaleHit.Size = UDim2.new(1, 20, 0, 36)
ScaleHit.Position = UDim2.new(0, -10, 0.5, -18)
ScaleHit.BackgroundTransparency = 1
ScaleHit.Text = ""
ScaleHit.ZIndex = 5
ScaleHit.Parent = ScaleTrack

-- ── Floating Toggle Button ───────────────────────────────────────
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 44, 0, 44)
FloatBtn.Position = UDim2.new(0, 10, 0, 60)
FloatBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
FloatBtn.Text = "✕"
FloatBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 16
FloatBtn.BorderSizePixel = 0
FloatBtn.ZIndex = 10
FloatBtn.Visible = false
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 10)
local floatBorder = Instance.new("UIStroke", FloatBtn)
floatBorder.Color = Color3.fromRGB(80, 120, 255)
floatBorder.Thickness = 1

-- ── Sidebar ──────────────────────────────────────────────────────
local Sidebar = Instance.new("ScrollingFrame")
Sidebar.Size = UDim2.new(0, 150, 1, -36)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Sidebar.BorderSizePixel = 0
Sidebar.ScrollBarThickness = 0
Sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
Sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
Sidebar.Parent = Main

local SidebarList = Instance.new("UIListLayout", Sidebar)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Padding = UDim.new(0, 2)
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 8)

local TABS = {
    { name = "Macro",          icon = "⏺" },
    { name = "Gameplay",       icon = "🎮" },
    { name = "Game Mechanics", icon = "⚙" },
    { name = "AutoPlay",       icon = "▶" },
    { name = "Macro Maps",     icon = "🗺" },
    { name = "Misc",           icon = "☰" },
    { name = "Priority",       icon = "⚡" },
    { name = "Infos",          icon = "ℹ" },
}

local tabButtons = {}
local activeTab  = "Macro"

local function makeTabBtn(tabData, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    btn.BackgroundTransparency = 1
    btn.Text = tabData.icon .. "  " .. tabData.name
    btn.TextColor3 = Color3.fromRGB(130, 130, 160)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    btn.LayoutOrder = order
    btn.Parent = Sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local pad = Instance.new("UIPadding", btn)
    pad.PaddingLeft = UDim.new(0, 10)
    return btn
end

-- ── Content Panel ────────────────────────────────────────────────
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -155, 1, -36)
Content.Position = UDim2.new(0, 154, 0, 36)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = Main

local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0, 1, 1, -36)
Sep.Position = UDim2.new(0, 150, 0, 36)
Sep.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
Sep.BorderSizePixel = 0
Sep.Parent = Main

-- ┌─────────────────────────────────────┐
-- │   MACRO TAB                         │
-- └─────────────────────────────────────┘
local MacroScroll = Instance.new("ScrollingFrame")
MacroScroll.Size = UDim2.new(1, 0, 1, 0)
MacroScroll.BackgroundTransparency = 1
MacroScroll.BorderSizePixel = 0
MacroScroll.ScrollBarThickness = 4
MacroScroll.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
MacroScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MacroScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MacroScroll.Parent = Content

local MacroPanel = Instance.new("Frame")
MacroPanel.Size = UDim2.new(1, 0, 0, 0)
MacroPanel.AutomaticSize = Enum.AutomaticSize.Y
MacroPanel.BackgroundTransparency = 1
MacroPanel.Parent = MacroScroll

local MacroList = Instance.new("UIListLayout", MacroPanel)
MacroList.SortOrder = Enum.SortOrder.LayoutOrder
MacroList.Padding = UDim.new(0, 6)

local MacroPad = Instance.new("UIPadding", MacroPanel)
MacroPad.PaddingLeft   = UDim.new(0, 10)
MacroPad.PaddingRight  = UDim.new(0, 10)
MacroPad.PaddingTop    = UDim.new(0, 10)
MacroPad.PaddingBottom = UDim.new(0, 14)

-- ── Info row helper ──────────────────────────────────────────────
local function makeInfoRow(labelText, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.Parent = MacroPanel
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.45, 0, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(100, 100, 140)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.5, 0, 1, 0)
    val.Position = UDim2.new(0.48, 0, 0, 0)
    val.BackgroundTransparency = 1
    val.Text = "—"
    val.TextColor3 = Color3.fromRGB(200, 200, 230)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Left
    val.Parent = row

    return val
end

local ActionLabel = makeInfoRow("Action",  1)
local TypeLabel   = makeInfoRow("Type",    2)
local UnitLabel   = makeInfoRow("Unit",    3)
local WaitLabel   = makeInfoRow("Status",  4)

-- ── Divider helper ───────────────────────────────────────────────
local function makeDivider(order)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1, 0, 0, 1)
    d.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
    d.BorderSizePixel = 0
    d.LayoutOrder = order
    d.Parent = MacroPanel
end
makeDivider(5)

-- ── Toggle row helper ────────────────────────────────────────────
local function makeToggleRow(labelText, order, defaultOn, onToggle)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 52)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    row.BackgroundTransparency = 0
    row.Text = ""
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.AutoButtonColor = false
    row.Parent = MacroPanel
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(200, 200, 230)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 50, 0, 26)
    track.Position = UDim2.new(1, -64, 0.5, -13)
    track.BackgroundColor3 = defaultOn and Color3.fromRGB(80, 120, 255) or Color3.fromRGB(50, 50, 70)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = defaultOn and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local isOn = defaultOn or false

    local function setToggle(state)
        isOn = state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = isOn and Color3.fromRGB(80, 120, 255) or Color3.fromRGB(50, 50, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = isOn and UDim2.new(1, -23, 0.5, -10) or UDim2.new(0, 3, 0.5, -10)
        }):Play()
    end

    row.MouseButton1Click:Connect(function()
        local newState = not isOn
        setToggle(newState)
        if onToggle then onToggle(newState) end
    end)

    return setToggle, function() return isOn end, row
end

-- Forward-declare functions so toggles can reference them
local startRecording, stopRecording, startPlayback, stopPlayback
local startAutoGameSpeed, stopAutoGameSpeed
local startAutoDifficulty, stopAutoDifficulty

local setAutoEquip, getAutoEquip = makeToggleRow("Auto Equip Macro Units", 6, true, nil)

local setRecord, getRecord = makeToggleRow("Record Macro", 7, false, function(nowOn)
    if nowOn then startRecording() else stopRecording() end
end)

local setPlay, getPlay = makeToggleRow("Play Macro", 8, false, function(nowOn)
    if nowOn then startPlayback() else stopPlayback() end
end)

local setLoop, getLoop = makeToggleRow("Loop Playback", 9, false, function(nowOn)
    loopPlay = nowOn
end)

makeDivider(10)

-- ── Auto Game Speed x2 toggle ────────────────────────────────────
local setAutoSpeed, getAutoSpeed = makeToggleRow("Auto Game Speed x2", 11, false, function(nowOn)
    if nowOn then startAutoGameSpeed() else stopAutoGameSpeed() end
end)

-- ── Auto Difficulty toggle ───────────────────────────────────────
local setAutoDiff, getAutoDiff = makeToggleRow("Auto Difficulty", 12, false, function(nowOn)
    if nowOn then startAutoDifficulty() else stopAutoDifficulty() end
end)

makeDivider(13)

-- ── Step Delay slider ────────────────────────────────────────────
local delaySection = Instance.new("Frame")
delaySection.Size = UDim2.new(1, 0, 0, 64)
delaySection.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
delaySection.BorderSizePixel = 0
delaySection.LayoutOrder = 14
delaySection.Parent = MacroPanel
Instance.new("UICorner", delaySection).CornerRadius = UDim.new(0, 8)

local delayLbl = Instance.new("TextLabel")
delayLbl.Size = UDim2.new(1, -80, 0, 22)
delayLbl.Position = UDim2.new(0, 14, 0, 8)
delayLbl.BackgroundTransparency = 1
delayLbl.Text = "Step Delay"
delayLbl.TextColor3 = Color3.fromRGB(200, 200, 230)
delayLbl.Font = Enum.Font.GothamBold
delayLbl.TextSize = 13
delayLbl.TextXAlignment = Enum.TextXAlignment.Left
delayLbl.Parent = delaySection

local DelayValueBox = Instance.new("TextLabel")
DelayValueBox.Size = UDim2.new(0, 56, 0, 22)
DelayValueBox.Position = UDim2.new(1, -68, 0, 8)
DelayValueBox.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
DelayValueBox.Text = "0.2s"
DelayValueBox.TextColor3 = Color3.fromRGB(200,200,230)
DelayValueBox.Font = Enum.Font.GothamBold
DelayValueBox.TextSize = 12
DelayValueBox.BorderSizePixel = 0
DelayValueBox.Parent = delaySection
Instance.new("UICorner", DelayValueBox).CornerRadius = UDim.new(0,5)

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, -28, 0, 8)
SliderTrack.Position = UDim2.new(0, 14, 0, 40)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
SliderTrack.BorderSizePixel = 0
SliderTrack.Parent = delaySection
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1, 0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.1, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderTrack
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1, 0)

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 18, 0, 18)
SliderKnob.Position = UDim2.new(0.1, -9, 0.5, -9)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
SliderKnob.BorderSizePixel = 0
SliderKnob.Parent = SliderTrack
Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1, 0)

local SliderHit = Instance.new("TextButton")
SliderHit.Size = UDim2.new(1, 0, 0, 40)
SliderHit.Position = UDim2.new(0, 0, 0.5, -20)
SliderHit.BackgroundTransparency = 1
SliderHit.Text = ""
SliderHit.ZIndex = 5
SliderHit.Parent = SliderTrack

makeDivider(15)

-- ┌─────────────────────────────────────────────────────────────────┐
-- │  ACTION LOG — shows every recorded event live                   │
-- └─────────────────────────────────────────────────────────────────┘
local logHeader = Instance.new("TextLabel")
logHeader.Size = UDim2.new(1, 0, 0, 22)
logHeader.BackgroundTransparency = 1
logHeader.Text = "📋  Recorded Actions"
logHeader.TextColor3 = Color3.fromRGB(120, 120, 160)
logHeader.Font = Enum.Font.GothamBold
logHeader.TextSize = 11
logHeader.TextXAlignment = Enum.TextXAlignment.Left
logHeader.LayoutOrder = 16
logHeader.Parent = MacroPanel
Instance.new("UIPadding", logHeader).PaddingLeft = UDim.new(0, 4)

local LogBox = Instance.new("ScrollingFrame")
LogBox.Size = UDim2.new(1, 0, 0, 130)
LogBox.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
LogBox.BorderSizePixel = 0
LogBox.ScrollBarThickness = 3
LogBox.ScrollBarImageColor3 = Color3.fromRGB(80, 120, 255)
LogBox.CanvasSize = UDim2.new(0, 0, 0, 0)
LogBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
LogBox.LayoutOrder = 17
LogBox.Parent = MacroPanel
Instance.new("UICorner", LogBox).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", LogBox).Color = Color3.fromRGB(40, 40, 60)

local LogList = Instance.new("UIListLayout", LogBox)
LogList.SortOrder = Enum.SortOrder.LayoutOrder
LogList.Padding = UDim.new(0, 1)
Instance.new("UIPadding", LogBox).PaddingTop = UDim.new(0, 4)

-- Clear log button
local ClearLogBtn = Instance.new("TextButton")
ClearLogBtn.Size = UDim2.new(1, 0, 0, 30)
ClearLogBtn.BackgroundColor3 = Color3.fromRGB(50, 30, 30)
ClearLogBtn.Text = "🗑  Clear Macro"
ClearLogBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
ClearLogBtn.Font = Enum.Font.GothamBold
ClearLogBtn.TextSize = 11
ClearLogBtn.BorderSizePixel = 0
ClearLogBtn.LayoutOrder = 18
ClearLogBtn.Parent = MacroPanel
Instance.new("UICorner", ClearLogBtn).CornerRadius = UDim.new(0, 6)

-- Add a row to the log box
local logRowCount = 0
local function addLogRow(text, isHighlight)
    logRowCount += 1
    local row = Instance.new("TextLabel")
    row.Size = UDim2.new(1, -8, 0, 18)
    row.BackgroundTransparency = logRowCount % 2 == 0 and 0.95 or 1
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    row.Text = text
    row.TextColor3 = isHighlight
        and Color3.fromRGB(120, 220, 140)
        or  Color3.fromRGB(150, 150, 190)
    row.Font = Enum.Font.Code
    row.TextSize = 10
    row.TextXAlignment = Enum.TextXAlignment.Left
    row.LayoutOrder = logRowCount
    row.Parent = LogBox
    Instance.new("UIPadding", row).PaddingLeft = UDim.new(0, 6)
    -- auto-scroll to bottom
    task.defer(function()
        LogBox.CanvasPosition = Vector2.new(0, LogBox.AbsoluteCanvasSize.Y)
    end)
    return row
end

local function clearLog()
    for _, child in ipairs(LogBox:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    logRowCount = 0
end

ClearLogBtn.MouseButton1Click:Connect(function()
    if playing then return end
    macro = {}
    actionCount = 0
    actionTotal = 0
    clearLog()
    ActionLabel.Text = "0 / 0"
    TypeLabel.Text   = "—"
    UnitLabel.Text   = "—"
    WaitLabel.Text   = "Cleared"
    WaitLabel.TextColor3 = Color3.fromRGB(200, 200, 230)
end)

-- ── Placeholder panels for other tabs ───────────────────────────
local function makePlaceholderPanel(tabName)
    local p = Instance.new("Frame")
    p.Size = UDim2.new(1,0,1,0)
    p.BackgroundTransparency = 1
    p.Visible = false
    p.Parent = Content
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text = tabName .. "\n(coming soon)"
    lbl.TextColor3 = Color3.fromRGB(80,80,110)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.Parent = p
    return p
end

local panels = { Macro = MacroScroll }
for _, tab in ipairs(TABS) do
    if tab.name ~= "Macro" then
        panels[tab.name] = makePlaceholderPanel(tab.name)
    end
end

-- ── Tab switching ────────────────────────────────────────────────
local function switchTab(name)
    activeTab = name
    for tabName, panel in pairs(panels) do
        panel.Visible = (tabName == name)
    end
    for _, btn in pairs(tabButtons) do
        local isActive = (btn.Name == name)
        btn.TextColor3 = isActive and Color3.fromRGB(220,220,255) or Color3.fromRGB(130,130,160)
        btn.BackgroundTransparency = isActive and 0 or 1
        btn.BackgroundColor3 = Color3.fromRGB(30,30,48)
    end
end

for i, tab in ipairs(TABS) do
    local btn = makeTabBtn(tab, i)
    btn.Name = tab.name
    tabButtons[tab.name] = btn
    btn.MouseButton1Click:Connect(function()
        switchTab(tab.name)
    end)
end

switchTab("Macro")

-- ┌─────────────────────────────────────┐
-- │   DRAGGING (mouse + touch)          │
-- └─────────────────────────────────────┘
local dragging, dragStart, startPos

local function startDrag(pos)
    dragging  = true
    dragStart = pos
    startPos  = Main.Position
end
local function endDrag() dragging = false end
local function moveDrag(pos)
    if not dragging then return end
    local delta = pos - dragStart
    local sc    = UIScaleObj.Scale
    local screenSize = workspace.CurrentCamera.ViewportSize
    local newX = math.clamp(startPos.X.Offset + delta.X, 0, screenSize.X - BASE_W * sc)
    local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, screenSize.Y - BASE_H * sc)
    Main.Position = UDim2.new(0, newX, 0, newY)
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        startDrag(input.Position)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then endDrag() end
        end)
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then endDrag() end
end)
UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        moveDrag(input.Position)
    end
end)

local fbDragging, fbDragStart, fbStartPos = false, nil, nil
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fbDragging  = true
        fbDragStart = input.Position
        fbStartPos  = FloatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then fbDragging = false end
        end)
    end
end)
FloatBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then fbDragging = false end
end)
UIS.InputChanged:Connect(function(input)
    if fbDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - fbDragStart
        local screenSize = workspace.CurrentCamera.ViewportSize
        local btnSize    = FloatBtn.AbsoluteSize
        local newX = math.clamp(fbStartPos.X.Offset + delta.X, 0, screenSize.X - btnSize.X)
        local newY = math.clamp(fbStartPos.Y.Offset + delta.Y, 0, screenSize.Y - btnSize.Y)
        FloatBtn.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- ┌─────────────────────────────────────┐
-- │   CLOSE / MINIMIZE                  │
-- └─────────────────────────────────────┘
local minimized = false

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)

local function setMinimized(state)
    minimized = state
    local targetH = minimized and BASE_H_MIN or BASE_H
    TweenService:Create(Main, TweenInfo.new(0.2), {
        Size = UDim2.new(0, BASE_W, 0, targetH)
    }):Play()
    Main.ClipsDescendants = true
    FloatBtn.Visible = minimized
    FloatBtn.Text = "☰"
    FloatBtn.TextColor3 = Color3.fromRGB(100, 200, 100)
    MinBtn.Text = minimized and "□" or "—"
end

MinBtn.MouseButton1Click:Connect(function() setMinimized(not minimized) end)
FloatBtn.MouseButton1Click:Connect(function() setMinimized(false) end)

-- ┌─────────────────────────────────────┐
-- │   SCALE SLIDER                      │
-- └─────────────────────────────────────┘
local scaleDragging = false
local scaleInput    = nil

local function applyUIScale(s)
    s = math.clamp(s, 0.4, 1.0)
    UIScaleObj.Scale = s
    uiScaleVal = s
    local pct = (s - 0.4) / 0.6
    ScaleFill.Size = UDim2.new(pct, 0, 1, 0)
    ScaleKnob.Position = UDim2.new(pct, -8, 0.5, -8)
    ScaleLabel.Text = math.floor(s * 100) .. "%"
    local screenSize = workspace.CurrentCamera.ViewportSize
    local cur = Main.Position
    local curH = minimized and BASE_H_MIN or BASE_H
    Main.Position = UDim2.new(0,
        math.clamp(cur.X.Offset, 0, screenSize.X - BASE_W * s),
        0,
        math.clamp(cur.Y.Offset, 0, screenSize.Y - curH * s)
    )
end

ScaleHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        scaleDragging = true
        scaleInput    = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                scaleDragging = false
                scaleInput    = nil
            end
        end)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input == scaleInput then scaleDragging = false; scaleInput = nil end
end)
RunService.Heartbeat:Connect(function()
    if not scaleDragging then return end
    local posX   = scaleInput and scaleInput.Position.X or UIS:GetMouseLocation().X
    local trackX = ScaleTrack.AbsolutePosition.X
    local trackW = ScaleTrack.AbsoluteSize.X
    if trackW <= 0 then return end
    local pct = math.clamp((posX - trackX) / trackW, 0, 1)
    applyUIScale(0.4 + pct * 0.6)
end)

-- ┌─────────────────────────────────────┐
-- │   STEP DELAY SLIDER                 │
-- └─────────────────────────────────────┘
local delayDragging = false
local delayInput    = nil

SliderHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        delayDragging = true
        delayInput    = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                delayDragging = false
                delayInput    = nil
            end
        end)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input == delayInput then delayDragging = false; delayInput = nil end
end)
RunService.Heartbeat:Connect(function()
    if not delayDragging then return end
    local posX   = delayInput and delayInput.Position.X or UIS:GetMouseLocation().X
    local trackX = SliderTrack.AbsolutePosition.X
    local trackW = SliderTrack.AbsoluteSize.X
    if trackW <= 0 then return end
    local pct = math.clamp((posX - trackX) / trackW, 0, 1)
    SliderFill.Size = UDim2.new(pct, 0, 1, 0)
    SliderKnob.Position = UDim2.new(pct, -9, 0.5, -9)
    stepDelay = math.floor(pct * 20 + 0.5) / 10
    DelayValueBox.Text = string.format("%.1fs", stepDelay)
end)

-- ┌─────────────────────────────────────┐
-- │   GUI UPDATE HELPERS                │
-- └─────────────────────────────────────┘
local function updateActionLabel()
    ActionLabel.Text = string.format("%d / %d", actionCount, actionTotal)
end

local function updateTypeLabel(ctrlChar)
    TypeLabel.Text = CTRL_NAMES[ctrlChar] or "Unknown"
end

local function flashStatus(msg, color)
    WaitLabel.Text = msg
    WaitLabel.TextColor3 = color or Color3.fromRGB(200, 200, 230)
end

-- ┌─────────────────────────────────────┐
-- │   HOOK FireServer                   │
-- └─────────────────────────────────────┘
remote.FireServer = function(self, ...)
    oldFireServer(self, ...)
    if not recording then return end

    local args    = deepCopy({...})
    local elapsed = tick() - recordStart
    table.insert(macro, { time = elapsed, args = args })

    actionTotal = #macro
    actionCount = #macro
    updateActionLabel()

    local payload  = args[1]
    local ctrlChar = type(payload) == "table" and payload[2] or nil
    if ctrlChar then updateTypeLabel(ctrlChar) end

    local data = type(payload) == "table" and payload[1] or {}
    if type(data) == "table" and data[1] then
        UnitLabel.Text = tostring(data[1])
    end

    -- ✅ Live log — show the recorded entry
    local lastEntry = macro[#macro]
    addLogRow(string.format("#%d  %s", #macro, entryLabel(lastEntry)), true)
end

-- ┌─────────────────────────────────────┐
-- │   RECORD LOGIC                      │
-- └─────────────────────────────────────┘
startRecording = function()
    if playing then
        flashStatus("Stop playback first!", Color3.fromRGB(255,100,100))
        task.defer(function() setRecord(false) end)
        return
    end
    macro       = {}
    recordStart = tick()
    recording   = true
    actionCount = 0
    actionTotal = 0
    clearLog()
    updateActionLabel()
    TypeLabel.Text = "—"
    UnitLabel.Text = "—"
    flashStatus("● Recording...", Color3.fromRGB(100, 255, 150))
end

stopRecording = function()
    recording   = false
    actionTotal = #macro
    updateActionLabel()
    flashStatus(string.format("%d actions saved ✓", #macro), Color3.fromRGB(170,170,210))
    -- Mark last log row as complete
    if #macro > 0 then
        addLogRow(string.format("── Done: %d actions ──", #macro), false)
    end
end

-- ┌─────────────────────────────────────┐
-- │   PLAY LOGIC  (fixed loop + status) │
-- └─────────────────────────────────────┘
startPlayback = function()
    if recording then
        flashStatus("Stop recording first!", Color3.fromRGB(255,100,100))
        task.defer(function() setPlay(false) end)
        return
    end
    if #macro == 0 then
        flashStatus("No macro recorded!", Color3.fromRGB(255,100,100))
        task.defer(function() setPlay(false) end)
        return
    end

    playing     = true
    actionTotal = #macro
    -- ✅ Read loopPlay from the toggle at the moment we start
    loopPlay    = getLoop()

    playThread = task.spawn(function()
        local loopNum = 0
        repeat
            loopNum += 1
            local startTime = tick()

            for i, entry in ipairs(macro) do
                if not playing then break end

                actionCount = i
                updateActionLabel()

                local payload  = entry.args[1]
                local ctrlChar = type(payload) == "table" and payload[2] or nil
                if ctrlChar then updateTypeLabel(ctrlChar) end

                local data = type(payload) == "table" and payload[1] or {}
                if type(data) == "table" and data[1] then
                    UnitLabel.Text = tostring(data[1])
                end

                -- ✅ Status shows loop number when looping
                if loopPlay then
                    flashStatus(
                        string.format("▶ Loop %d  Step %d/%d", loopNum, i, #macro),
                        Color3.fromRGB(120, 200, 255)
                    )
                else
                    flashStatus(
                        string.format("▶ Step %d / %d", i, #macro),
                        Color3.fromRGB(200, 200, 230)
                    )
                end

                -- Timing: honour original gaps but never go below stepDelay
                local waitTime = entry.time - (tick() - startTime)
                task.wait(math.max(waitTime, stepDelay))

                if not playing then break end
                oldFireServer(remote, unpack(deepCopy(entry.args)))
            end

            if loopPlay and playing then
                flashStatus(
                    string.format("↺ Loop %d done — restarting…", loopNum),
                    Color3.fromRGB(120, 180, 255)
                )
                task.wait(0.5)
                -- ✅ Refresh loopPlay from toggle each loop in case user toggled mid-run
                loopPlay = getLoop()
            end
        until not loopPlay or not playing

        playing = false
        setPlay(false)
        flashStatus("Playback finished ✓", Color3.fromRGB(170,170,210))
    end)
end

stopPlayback = function()
    playing = false
    if playThread then
        task.cancel(playThread)
        playThread = nil
    end
    flashStatus("Stopped", Color3.fromRGB(170,170,210))
end

-- ┌─────────────────────────────────────┐
-- │   AUTO GAME SPEED x2                │
-- └─────────────────────────────────────┘
startAutoGameSpeed = function()
    if autoSpeedThread then task.cancel(autoSpeedThread) end
    autoGameSpeed = true
    autoSpeedThread = task.spawn(function()
        while autoGameSpeed do
            -- Fire the GameSpeed control character (\t) with speed value 2
            -- Payload structure mirrors what the game sends: { data, ctrlChar }
            -- data table for GameSpeed typically carries the speed multiplier
            pcall(function()
                oldFireServer(remote, { {2}, "\t" })
            end)
            task.wait(3)  -- re-assert every 3s in case game resets it
        end
    end)
    flashStatus("⚡ Auto Speed x2 ON", Color3.fromRGB(255, 220, 80))
end

stopAutoGameSpeed = function()
    autoGameSpeed = false
    if autoSpeedThread then
        task.cancel(autoSpeedThread)
        autoSpeedThread = nil
    end
    -- Restore speed x1
    pcall(function()
        oldFireServer(remote, { {1}, "\t" })
    end)
    flashStatus("Auto Speed OFF", Color3.fromRGB(170,170,210))
end

-- ┌─────────────────────────────────────┐
-- │   AUTO DIFFICULTY                   │
-- └─────────────────────────────────────┘
startAutoDifficulty = function()
    if autoDiffThread then task.cancel(autoDiffThread) end
    autoDifficulty = true
    autoDiffThread = task.spawn(function()
        while autoDifficulty do
            -- Fire the Difficulty control character (\v)
            -- data[1] carries the difficulty index (e.g. highest available)
            pcall(function()
                oldFireServer(remote, { {4}, "\v" })  -- 4 = highest difficulty tier
            end)
            task.wait(3)
        end
    end)
    flashStatus("🎯 Auto Difficulty ON", Color3.fromRGB(255, 150, 80))
end

stopAutoDifficulty = function()
    autoDifficulty = false
    if autoDiffThread then
        task.cancel(autoDiffThread)
        autoDiffThread = nil
    end
    flashStatus("Auto Difficulty OFF", Color3.fromRGB(170,170,210))
end

-- ┌─────────────────────────────────────┐
-- │   KEYBINDS                          │
-- └─────────────────────────────────────┘
UIS.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        local nowOn = not getRecord()
        setRecord(nowOn)
        if nowOn then startRecording() else stopRecording() end
    elseif input.KeyCode == Enum.KeyCode.F6 then
        local nowOn = not getPlay()
        setPlay(nowOn)
        if nowOn then startPlayback() else stopPlayback() end
    end
end)

-- ── Entry animation ──────────────────────────────────────────────
Main.Size = UDim2.new(0, BASE_W, 0, 0)
Main.BackgroundTransparency = 1
TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, BASE_W, 0, BASE_H),
    BackgroundTransparency = 0
}):Play()

applyUIScale(uiScaleVal)

print("[TD Macro GUI v3] Loaded!")
print("  F5 = Record toggle   F6 = Play toggle")
print("  Toggles: Record | Play | Loop | Auto Speed x2 | Auto Difficulty")
