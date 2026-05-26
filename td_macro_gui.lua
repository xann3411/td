-- ╔══════════════════════════════════════════════════════════════╗
-- ║       BridgeNet2 Tower Defense Macro — GUI Edition           ║
-- ╚══════════════════════════════════════════════════════════════╝

local Players        = game:GetService("Players")
local RS             = game:GetService("ReplicatedStorage")
local UIS            = game:GetService("UserInputService")
local TweenService   = game:GetService("TweenService")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")

local LocalPlayer    = Players.LocalPlayer
local PlayerGui      = LocalPlayer:WaitForChild("PlayerGui")

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

local CTRL_NAMES = {
    ["\b"] = "Replay",
    ["\v"] = "Difficulty",
    ["\t"] = "GameSpeed",
    ["\n"] = "Tower",
}

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, val in pairs(v) do c[deepCopy(k)] = deepCopy(val) end
    return c
end

-- ┌─────────────────────────────────────┐
-- │         GUI BUILD                   │
-- └─────────────────────────────────────┘

-- Remove old GUI if re-executing
if PlayerGui:FindFirstChild("TDMacroGui") then
    PlayerGui:FindFirstChild("TDMacroGui"):Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TDMacroGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = PlayerGui

-- ┌─────────────────────────────────────┐
-- │         UI SCALE STATE              │
-- └─────────────────────────────────────┘
local uiScale = 0.75  -- start at 75% for mobile
local BASE_W   = 560
local BASE_H   = 400
local BASE_H_MIN = 36  -- minimized height

-- ── Main Frame ──────────────────────────────────────────────────
local Main = Instance.new("Frame")
Main.Name = "Main"
local _initW = math.floor(BASE_W * uiScale)
local _initH = math.floor(BASE_H * uiScale)
Main.Size = UDim2.new(0, _initW, 0, _initH)
Main.Position = UDim2.new(0, 10, 0, 60)  -- top-left, always visible
Main.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)

-- Subtle border glow
local border = Instance.new("UIStroke", Main)
border.Color = Color3.fromRGB(60, 60, 80)
border.Thickness = 1

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
TitleLabel.Text = "⬡  TD MACRO"
TitleLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close button
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -34, 0, 4)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = TitleBar
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1, -66, 0, 4)
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(200,200,220)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 11
MinBtn.BorderSizePixel = 0
MinBtn.Parent = TitleBar
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

-- ── Scale Slider (in title bar) ──────────────────────────────────
local ScaleLabel = Instance.new("TextLabel")
ScaleLabel.Size = UDim2.new(0, 30, 0, 18)
ScaleLabel.Position = UDim2.new(0, 138, 0.5, -9)
ScaleLabel.BackgroundTransparency = 1
ScaleLabel.Text = "100%"
ScaleLabel.TextColor3 = Color3.fromRGB(130, 130, 160)
ScaleLabel.Font = Enum.Font.Gotham
ScaleLabel.TextSize = 10
ScaleLabel.TextXAlignment = Enum.TextXAlignment.Left
ScaleLabel.Parent = TitleBar

local ScaleTrack = Instance.new("Frame")
ScaleTrack.Size = UDim2.new(0, 90, 0, 4)
ScaleTrack.Position = UDim2.new(0, 170, 0.5, -2)
ScaleTrack.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
ScaleTrack.BorderSizePixel = 0
ScaleTrack.Parent = TitleBar
Instance.new("UICorner", ScaleTrack).CornerRadius = UDim.new(1, 0)

-- default scale pct = 0.75 maps to 1.0 (range 0.5–1.0 scale = 0%–100% on slider)
local ScaleFill = Instance.new("Frame")
ScaleFill.Size = UDim2.new(1, 0, 1, 0)
ScaleFill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
ScaleFill.BorderSizePixel = 0
ScaleFill.Parent = ScaleTrack
Instance.new("UICorner", ScaleFill).CornerRadius = UDim.new(1, 0)

local ScaleKnob = Instance.new("Frame")
ScaleKnob.Size = UDim2.new(0, 12, 0, 12)
ScaleKnob.Position = UDim2.new(1, -6, 0.5, -6)
ScaleKnob.BackgroundColor3 = Color3.fromRGB(220, 220, 255)
ScaleKnob.BorderSizePixel = 0
ScaleKnob.Parent = ScaleTrack
Instance.new("UICorner", ScaleKnob).CornerRadius = UDim.new(1, 0)

local ScaleBtn = Instance.new("TextButton")
ScaleBtn.Size = UDim2.new(1, 0, 0, 24)
ScaleBtn.Position = UDim2.new(0, 0, 0.5, -12)
ScaleBtn.BackgroundTransparency = 1
ScaleBtn.Text = ""
ScaleBtn.Parent = ScaleTrack

-- ── Floating Toggle Button ───────────────────────────────────────
local FloatBtn = Instance.new("TextButton")
FloatBtn.Name = "FloatToggle"
FloatBtn.Size = UDim2.new(0, 36, 0, 36)
FloatBtn.Position = UDim2.new(0, 10, 0.5, -18)
FloatBtn.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
FloatBtn.Text = "✕"
FloatBtn.TextColor3 = Color3.fromRGB(220, 100, 100)
FloatBtn.Font = Enum.Font.GothamBold
FloatBtn.TextSize = 14
FloatBtn.BorderSizePixel = 0
FloatBtn.ZIndex = 10
FloatBtn.Parent = ScreenGui
Instance.new("UICorner", FloatBtn).CornerRadius = UDim.new(0, 8)
local floatBorder = Instance.new("UIStroke", FloatBtn)
floatBorder.Color = Color3.fromRGB(60, 60, 80)
floatBorder.Thickness = 1

-- ── Sidebar ──────────────────────────────────────────────────────
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 150, 1, -36)
Sidebar.Position = UDim2.new(0, 0, 0, 36)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 16, 22)
Sidebar.BorderSizePixel = 0
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
local activeTab = "Macro"

local function makeTabBtn(tabData, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 36)
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
    Instance.new("UIPadding", btn).PaddingLeft = UDim.new(0, 10)
    return btn
end

-- ── Content Panel ────────────────────────────────────────────────
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -158, 1, -36)
Content.Position = UDim2.new(0, 154, 0, 36)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Separator line between sidebar and content
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0, 1, 1, -36)
Sep.Position = UDim2.new(0, 150, 0, 36)
Sep.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
Sep.BorderSizePixel = 0
Sep.Parent = Main

-- ── MACRO TAB CONTENT ────────────────────────────────────────────
local MacroPanel = Instance.new("Frame")
MacroPanel.Size = UDim2.new(1, 0, 1, 0)
MacroPanel.BackgroundTransparency = 1
MacroPanel.Parent = Content

local function makeLabel(text, posY, color, size)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 20)
    lbl.Position = UDim2.new(0, 10, 0, posY)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = color or Color3.fromRGB(160, 160, 190)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = size or 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = MacroPanel
    return lbl
end

-- Action counter
local ActionLabel = makeLabel("Action:  0 / 0", 14, Color3.fromRGB(200, 200, 230), 12)

-- Type field
makeLabel("Type:", 44, Color3.fromRGB(100, 100, 130), 11)
local TypeLabel = makeLabel("—", 58, Color3.fromRGB(170, 170, 210), 12)

-- Unit field
makeLabel("Unit:", 84, Color3.fromRGB(100, 100, 130), 11)
local UnitLabel = makeLabel("—", 98, Color3.fromRGB(170, 170, 210), 12)

-- Waiting for field
makeLabel("Waiting for:", 124, Color3.fromRGB(100, 100, 130), 11)
local WaitLabel = makeLabel("—", 138, Color3.fromRGB(170, 170, 210), 12)

-- Divider
local Div = Instance.new("Frame")
Div.Size = UDim2.new(1, -20, 0, 1)
Div.Position = UDim2.new(0, 10, 0, 165)
Div.BackgroundColor3 = Color3.fromRGB(40, 40, 58)
Div.BorderSizePixel = 0
Div.Parent = MacroPanel

-- ── Toggle helper ────────────────────────────────────────────────
local function makeToggleRow(labelText, posY, defaultOn)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 32)
    row.Position = UDim2.new(0, 10, 0, posY)
    row.BackgroundTransparency = 1
    row.Parent = MacroPanel

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -60, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(190, 190, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 44, 0, 22)
    track.Position = UDim2.new(1, -44, 0.5, -11)
    track.BackgroundColor3 = defaultOn and Color3.fromRGB(80, 120, 255) or Color3.fromRGB(50, 50, 70)
    track.BorderSizePixel = 0
    track.Parent = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local isOn = defaultOn or false

    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = track

    local function setToggle(state)
        isOn = state
        TweenService:Create(track, TweenInfo.new(0.15), {
            BackgroundColor3 = isOn and Color3.fromRGB(80, 120, 255) or Color3.fromRGB(50, 50, 70)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = isOn and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
    end

    return clickArea, setToggle, function() return isOn end
end

-- Auto Equip toggle (cosmetic for now)
local autoEquipClick, setAutoEquip, getAutoEquip = makeToggleRow("Auto Equip Macro Units", 176, true)

-- Record Macro toggle
local recordClick, setRecord, getRecord = makeToggleRow("Record Macro", 216, false)

-- Play Macro toggle
local playClick, setPlay, getPlay = makeToggleRow("Play Macro", 256, false)

-- Loop toggle
local loopClick, setLoop, getLoop = makeToggleRow("Loop Playback", 296, false)

-- ── Step Delay slider ────────────────────────────────────────────
local delayRowLabel = Instance.new("TextLabel")
delayRowLabel.Size = UDim2.new(1, -20, 0, 18)
delayRowLabel.Position = UDim2.new(0, 10, 0, 332)
delayRowLabel.BackgroundTransparency = 1
delayRowLabel.Text = "Step Delay"
delayRowLabel.TextColor3 = Color3.fromRGB(190, 190, 220)
delayRowLabel.Font = Enum.Font.Gotham
delayRowLabel.TextSize = 12
delayRowLabel.TextXAlignment = Enum.TextXAlignment.Left
delayRowLabel.Parent = MacroPanel

local SliderTrack = Instance.new("Frame")
SliderTrack.Size = UDim2.new(1, -90, 0, 4)
SliderTrack.Position = UDim2.new(0, 10, 0, 356)
SliderTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
SliderTrack.BorderSizePixel = 0
SliderTrack.Parent = MacroPanel
Instance.new("UICorner", SliderTrack).CornerRadius = UDim.new(1,0)

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderTrack
Instance.new("UICorner", SliderFill).CornerRadius = UDim.new(1,0)

local SliderKnob = Instance.new("Frame")
SliderKnob.Size = UDim2.new(0, 14, 0, 14)
SliderKnob.Position = UDim2.new(0.2, -7, 0.5, -7)
SliderKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
SliderKnob.BorderSizePixel = 0
SliderKnob.Parent = SliderTrack
Instance.new("UICorner", SliderKnob).CornerRadius = UDim.new(1,0)

local DelayValueBox = Instance.new("TextLabel")
DelayValueBox.Size = UDim2.new(0, 50, 0, 22)
DelayValueBox.Position = UDim2.new(1, -58, 0, 347)
DelayValueBox.BackgroundColor3 = Color3.fromRGB(25, 25, 38)
DelayValueBox.Text = "0.2"
DelayValueBox.TextColor3 = Color3.fromRGB(200,200,230)
DelayValueBox.Font = Enum.Font.GothamBold
DelayValueBox.TextSize = 12
DelayValueBox.BorderSizePixel = 0
DelayValueBox.Parent = MacroPanel
Instance.new("UICorner", DelayValueBox).CornerRadius = UDim.new(0,5)

-- Slider drag logic (mouse + touch)
local sliderDragging = false
local sliderActiveInput = nil

local sliderBtn = Instance.new("TextButton")
sliderBtn.Size = UDim2.new(1, 0, 0, 20)
sliderBtn.Position = UDim2.new(0, 0, 0.5, -10)
sliderBtn.BackgroundTransparency = 1
sliderBtn.Text = ""
sliderBtn.Parent = SliderTrack

local function onSliderInputBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        sliderDragging   = true
        sliderActiveInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                sliderDragging    = false
                sliderActiveInput = nil
            end
        end)
    end
end

sliderBtn.InputBegan:Connect(onSliderInputBegan)

UIS.InputEnded:Connect(function(input)
    if input == sliderActiveInput
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        sliderDragging    = false
        sliderActiveInput = nil
    end
end)

RunService.Heartbeat:Connect(function()
    if sliderDragging then
        local mouseX
        if sliderActiveInput then
            mouseX = sliderActiveInput.Position.X
        else
            mouseX = UIS:GetMouseLocation().X
        end
        local trackPos = SliderTrack.AbsolutePosition.X
        local trackW   = SliderTrack.AbsoluteSize.X
        local pct = math.clamp((mouseX - trackPos) / trackW, 0, 1)
        SliderFill.Size = UDim2.new(pct, 0, 1, 0)
        SliderKnob.Position = UDim2.new(pct, -7, 0.5, -7)
        stepDelay = math.floor(pct * 20 + 0.5) / 10  -- 0.0 to 2.0
        DelayValueBox.Text = string.format("%.1f", stepDelay)
    end
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

local panels = { Macro = MacroPanel }
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

-- ── Draggable (mouse + touch) ────────────────────────────────────
local dragging, dragStart, startPos

local function isDragInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

TitleBar.InputBegan:Connect(function(input)
    if isDragInput(input) then
        dragging  = true
        dragStart = input.Position
        startPos  = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
TitleBar.InputEnded:Connect(function(input)
    if isDragInput(input) then dragging = false end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        local screenSize = workspace.CurrentCamera.ViewportSize
        local mainSize   = Main.AbsoluteSize
        local newX = math.clamp(startPos.X.Offset + delta.X, 0, screenSize.X - mainSize.X)
        local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, screenSize.Y - mainSize.Y)
        Main.Position = UDim2.new(0, newX, 0, newY)
    end
end)

-- ── Close / Minimize ─────────────────────────────────────────────
local minimized = false
local fbMinimized = false  -- shared state for float button sync

local function applyScale(s)
    uiScale = s
    local w = math.floor(BASE_W * s)
    local h = minimized and math.floor(BASE_H_MIN * s) or math.floor(BASE_H * s)
    Main.Size = UDim2.new(0, w, 0, h)
    -- re-center offset based on current scale position
    local pct = math.clamp((s - 0.5) / 0.5, 0, 1)
    ScaleFill.Size = UDim2.new(pct, 0, 1, 0)
    ScaleKnob.Position = UDim2.new(pct, -6, 0.5, -6)
    ScaleLabel.Text = math.floor(s * 100) .. "%"
    -- Clamp window back on screen after resize
    local screenSize = workspace.CurrentCamera.ViewportSize
    local curPos = Main.Position
    local newX = math.clamp(curPos.X.Offset, 0, screenSize.X - w)
    local newY = math.clamp(curPos.Y.Offset, 0, screenSize.Y - h)
    Main.Position = UDim2.new(0, newX, 0, newY)
end

CloseBtn.MouseButton1Click:Connect(function()
    ScreenGui:Destroy()
end)
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    fbMinimized = minimized
    local w = math.floor(BASE_W * uiScale)
    local targetH = minimized and math.floor(BASE_H_MIN * uiScale) or math.floor(BASE_H * uiScale)
    TweenService:Create(Main, TweenInfo.new(0.2), { Size = UDim2.new(0, w, 0, targetH) }):Play()
    FloatBtn.Text = minimized and "☰" or "✕"
    FloatBtn.TextColor3 = minimized and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 100, 100)
end)

-- Float button: toggle minimize
FloatBtn.MouseButton1Click:Connect(function()
    fbMinimized = not fbMinimized
    minimized = fbMinimized
    local w = math.floor(BASE_W * uiScale)
    local targetH = minimized and math.floor(BASE_H_MIN * uiScale) or math.floor(BASE_H * uiScale)
    TweenService:Create(Main, TweenInfo.new(0.2), { Size = UDim2.new(0, w, 0, targetH) }):Play()
    FloatBtn.Text = minimized and "☰" or "✕"
    FloatBtn.TextColor3 = minimized and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(220, 100, 100)
end)

-- Float button: draggable (mouse + touch)
local fbDragging, fbDragStart, fbStartPos = false, nil, nil
FloatBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fbDragging  = true
        fbDragStart = input.Position
        fbStartPos  = FloatBtn.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                fbDragging = false
            end
        end)
    end
end)
FloatBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fbDragging = false
    end
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

-- Scale slider drag logic (mouse + touch, properly isolated)
local scaleDragging = false
local scaleActiveInput = nil

local function onScaleInputBegan(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        scaleDragging   = true
        scaleActiveInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                scaleDragging    = false
                scaleActiveInput = nil
            end
        end)
    end
end

ScaleBtn.InputBegan:Connect(onScaleInputBegan)

UIS.InputEnded:Connect(function(input)
    if input == scaleActiveInput
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
        scaleDragging    = false
        scaleActiveInput = nil
    end
end)

RunService.Heartbeat:Connect(function()
    if scaleDragging then
        local mouseX
        if scaleActiveInput then
            mouseX = scaleActiveInput.Position.X
        else
            mouseX = UIS:GetMouseLocation().X
        end
        local trackX = ScaleTrack.AbsolutePosition.X
        local trackW = ScaleTrack.AbsoluteSize.X
        local pct    = math.clamp((mouseX - trackX) / trackW, 0, 1)
        local newScale = 0.5 + pct * 0.5  -- range 0.5 → 1.0
        applyScale(newScale)
    end
end)

-- ┌─────────────────────────────────────┐
-- │         GUI UPDATE HELPERS          │
-- └─────────────────────────────────────┘

local function updateActionLabel()
    ActionLabel.Text = string.format("Action:  %d / %d", actionCount, actionTotal)
end

local function updateTypeLabel(ctrlChar)
    TypeLabel.Text = CTRL_NAMES[ctrlChar] or "Unknown"
end

local function flashStatus(msg, color)
    UnitLabel.Text = msg
    UnitLabel.TextColor3 = color or Color3.fromRGB(170,170,210)
end

-- ┌─────────────────────────────────────┐
-- │         HOOK FireServer             │
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
end

-- ┌─────────────────────────────────────┐
-- │         RECORD / PLAY LOGIC         │
-- └─────────────────────────────────────┘

local function startRecording()
    if playing then
        flashStatus("Stop playback first!", Color3.fromRGB(255,100,100))
        setRecord(false)
        return
    end
    macro       = {}
    recordStart = tick()
    recording   = true
    actionCount = 0
    actionTotal = 0
    updateActionLabel()
    TypeLabel.Text = "—"
    UnitLabel.Text = "—"
    WaitLabel.Text = "Recording..."
    flashStatus("Recording...", Color3.fromRGB(100,255,150))
end

local function stopRecording()
    recording = false
    actionTotal = #macro
    updateActionLabel()
    WaitLabel.Text = string.format("%d actions saved", #macro)
    flashStatus("Done", Color3.fromRGB(170,170,210))
end

local function startPlayback()
    if recording then
        flashStatus("Stop recording first!", Color3.fromRGB(255,100,100))
        setPlay(false)
        return
    end
    if #macro == 0 then
        flashStatus("No macro recorded!", Color3.fromRGB(255,100,100))
        setPlay(false)
        return
    end

    playing     = true
    actionTotal = #macro
    loopPlay    = getLoop()

    playThread = task.spawn(function()
        repeat
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

                WaitLabel.Text = string.format("Step %d / %d", i, #macro)

                local waitTime = entry.time - (tick() - startTime)
                if waitTime > stepDelay then
                    task.wait(waitTime)
                else
                    task.wait(stepDelay)
                end

                if not playing then break end
                oldFireServer(remote, unpack(deepCopy(entry.args)))
            end

            if loopPlay and playing then
                WaitLabel.Text = "Looping..."
                task.wait(0.5)
            end
        until not loopPlay or not playing

        playing = false
        setPlay(false)
        WaitLabel.Text = "Playback finished"
        flashStatus("Done", Color3.fromRGB(170,170,210))
    end)
end

local function stopPlayback()
    playing = false
    if playThread then
        task.cancel(playThread)
        playThread = nil
    end
    WaitLabel.Text = "Stopped"
end

-- ── Wire toggles ─────────────────────────────────────────────────
recordClick.MouseButton1Click:Connect(function()
    local nowOn = not getRecord()
    setRecord(nowOn)
    if nowOn then startRecording() else stopRecording() end
end)

playClick.MouseButton1Click:Connect(function()
    local nowOn = not getPlay()
    setPlay(nowOn)
    if nowOn then startPlayback() else stopPlayback() end
end)

loopClick.MouseButton1Click:Connect(function()
    local nowOn = not getLoop()
    setLoop(nowOn)
    loopPlay = nowOn
end)

-- ── Keybinds still work too ──────────────────────────────────────
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
Main.Size = UDim2.new(0, _initW, 0, 0)
Main.BackgroundTransparency = 1
TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, _initW, 0, _initH),
    BackgroundTransparency = 0
}):Play()
-- Initialise the scale slider visual to match starting scale
applyScale(uiScale)

print("[TD Macro GUI] Loaded! F5=Record  F6=Play  or use the GUI toggles.")
