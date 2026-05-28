-- ================================================
-- Anime Power Defense - Full Script v3.0
-- Custom GUI | Auto Farm + Macro Recorder
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

local Player     = Players.LocalPlayer
local PlayerGui  = Player:WaitForChild("PlayerGui")
local IsMobile   = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

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

local function GetPlacedUnits()  return GetPlacedUnitsRF:InvokeServer() end
local function UpgradeUnit(g)    GameEvent:FireServer("UpgradeUnit", g) end
local function SellUnit(g)       SellUnitRF:InvokeServer(g) end
local function VoteSkipWave()    VoteSkipWaveRF:InvokeServer() end
local function SetGamespeed(s)   SetGamespeedRF:InvokeServer(s) end
local function Replay()          GameEvent:FireServer("Retry") end

-- ================================================
-- File System
-- ================================================
if not isfolder("APDScript")            then makefolder("APDScript") end
if not isfolder("APDScript\\Macros")    then makefolder("APDScript\\Macros") end
if not isfolder("APDScript\\Settings")  then makefolder("APDScript\\Settings") end

local SETTINGS_FILE = "APDScript\\Settings\\" .. Player.UserId .. ".json"

local Settings = {
    gamespeed      = 1.5,
    auto_gamespeed = false,
    macro_speed    = 1.0,
    auto_upgrade   = false,
    auto_skip      = false,
    auto_replay    = false,
    skip_delay     = 3,
    upgrade_delay  = 0.5,
}

local function SaveSettings()
    pcall(function() writefile(SETTINGS_FILE, HttpService:JSONEncode(Settings)) end)
end
local function LoadSettings()
    if isfile(SETTINGS_FILE) then
        local ok, d = pcall(function() return HttpService:JSONDecode(readfile(SETTINGS_FILE)) end)
        if ok and d then for k,v in pairs(d) do Settings[k]=v end end
    end
end
LoadSettings()

-- ================================================
-- Macro Engine
-- ================================================
local MacroEngine = {
    IsRecording  = false,
    IsPlaying    = false,
    Actions      = {},
    StartTime    = 0,
    Speed        = Settings.macro_speed,
    CurrentName  = "",
}

function MacroEngine:RecordAction(t, d)
    if not self.IsRecording then return end
    table.insert(self.Actions, { type=t, data=d, ts=tick()-self.StartTime })
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
    writefile("APDScript\\Macros\\"..name..".json",
        HttpService:JSONEncode({ name=name, actions=self.Actions }))
    self.CurrentName = name
end

function MacroEngine:Load(name)
    local p = "APDScript\\Macros\\"..name..".json"
    if isfile(p) then
        local ok,d = pcall(function() return HttpService:JSONDecode(readfile(p)) end)
        if ok and d then
            self.Actions     = d.actions or {}
            self.CurrentName = name
            return true
        end
    end
    return false
end

function MacroEngine:Delete(name)
    local p = "APDScript\\Macros\\"..name..".json"
    if isfile(p) then delfile(p) end
end

function MacroEngine:List()
    local files = listfiles("APDScript\\Macros")
    local out = {}
    for _,f in pairs(files) do
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
                local wait_t = (action.ts - prev) / self.Speed
                if wait_t > 0 then task.wait(wait_t) end
                prev = action.ts
                if not self.IsPlaying then break end

                if action.type == "click" or action.type == "touch" then
                    local x,y = action.data[1], action.data[2]
                    VirtualInputManager:SendMouseButtonEvent(x,y,0,true,game,1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(x,y,0,false,game,1)
                elseif action.type == "upgrade_all" then
                    local ok,placed = pcall(GetPlacedUnits)
                    if ok and placed then
                        for guid,ud in pairs(placed) do
                            local uid = tostring(ud.Type)
                            local lv,mx = 0,0
                            if ud.Info and ud.Info[uid] then
                                lv = ud.Info[uid].Upgrade or 0
                                if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx=#ud.Info[uid].Data.upgrades end
                            end
                            if lv < mx then pcall(UpgradeUnit,guid) task.wait(0.3) end
                        end
                    end
                elseif action.type == "sell_all" then
                    local ok,placed = pcall(GetPlacedUnits)
                    if ok and placed then for g,_ in pairs(placed) do pcall(SellUnit,g) task.wait(0.3) end end
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

-- Input capture
UserInputService.InputBegan:Connect(function(input, gp)
    if not MacroEngine.IsRecording then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local m = Player:GetMouse()
        MacroEngine:RecordAction("click", {m.X, m.Y})
    end
end)
if UserInputService.TouchEnabled then
    UserInputService.TouchStarted:Connect(function(touch, gp)
        if not MacroEngine.IsRecording then return end
        MacroEngine:RecordAction("touch", {touch.Position.X, touch.Position.Y})
    end)
end

-- ================================================
-- Auto Farm Loops
-- ================================================
local AutoLoops = { upgrade=false, skip=false, replay=false }

local function StartAutoUpgrade()
    if AutoLoops.upgrade then return end
    AutoLoops.upgrade = true
    task.spawn(function()
        while Settings.auto_upgrade do
            local ok,placed = pcall(GetPlacedUnits)
            if ok and placed then
                for guid,ud in pairs(placed) do
                    if not Settings.auto_upgrade then break end
                    local uid = tostring(ud.Type)
                    local lv,mx = 0,0
                    if ud.Info and ud.Info[uid] then
                        lv = ud.Info[uid].Upgrade or 0
                        if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx=#ud.Info[uid].Data.upgrades end
                    end
                    if lv < mx then pcall(UpgradeUnit,guid) task.wait(Settings.upgrade_delay) end
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
        while Settings.auto_skip do pcall(VoteSkipWave) task.wait(Settings.skip_delay) end
        AutoLoops.skip = false
    end)
end

local function StartAutoReplay()
    if AutoLoops.replay then return end
    AutoLoops.replay = true
    task.spawn(function()
        while Settings.auto_replay do pcall(Replay) task.wait(5) end
        AutoLoops.replay = false
    end)
end

-- ================================================
-- GUI CONSTANTS
-- ================================================
local C = {
    BG          = Color3.fromRGB(18, 18, 24),
    PANEL       = Color3.fromRGB(26, 26, 34),
    CARD        = Color3.fromRGB(34, 34, 44),
    ACCENT      = Color3.fromRGB(90, 90, 130),
    ACCENT_LIT  = Color3.fromRGB(110, 110, 160),
    GREEN       = Color3.fromRGB(60, 180, 90),
    RED         = Color3.fromRGB(200, 60, 60),
    ORANGE      = Color3.fromRGB(210, 130, 40),
    TEXT        = Color3.fromRGB(220, 220, 235),
    SUBTEXT     = Color3.fromRGB(140, 140, 160),
    WHITE       = Color3.fromRGB(255, 255, 255),
    TOGGLE_OFF  = Color3.fromRGB(60, 60, 80),
    TOGGLE_ON   = Color3.fromRGB(80, 200, 120),
    BORDER      = Color3.fromRGB(50, 50, 65),
}

local FONT       = Enum.Font.GothamMedium
local FONT_BOLD  = Enum.Font.GothamBold
local FONT_SEMI  = Enum.Font.Gotham

-- Mobile scaling
local GUI_W      = IsMobile and 310 or 360
local GUI_H      = IsMobile and 480 or 540
local FONT_SM    = IsMobile and 11 or 12
local FONT_MD    = IsMobile and 12 or 13
local FONT_LG    = IsMobile and 14 or 15
local FONT_XL    = IsMobile and 16 or 18
local BTN_H      = IsMobile and 34 or 38
local PAD        = IsMobile and 8 or 10
local TAB_H      = IsMobile and 28 or 32

-- ================================================
-- GUI HELPERS
-- ================================================
local function Corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = parent
    return c
end

local function Stroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.BORDER
    s.Thickness = thickness or 1
    s.Parent = parent
    return s
end

local function Label(parent, text, size, color, font, halign)
    local l = Instance.new("TextLabel")
    l.Text = text
    l.TextSize = size or FONT_MD
    l.TextColor3 = color or C.TEXT
    l.Font = font or FONT_SEMI
    l.BackgroundTransparency = 1
    l.TextXAlignment = halign or Enum.TextXAlignment.Left
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
        -- press animation
        local orig = b.BackgroundColor3
        b.BackgroundColor3 = Color3.fromRGB(
            math.clamp(orig.R*255-20,0,255)/255*255,
            math.clamp(orig.G*255-20,0,255)/255*255,
            math.clamp(orig.B*255-20,0,255)/255*255
        )
        task.delay(0.1, function() b.BackgroundColor3 = orig end)
        callback()
    end)
    return b
end

local function MakeToggle(parent, initVal, callback)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 42, 0, 22)
    track.BackgroundColor3 = initVal and C.TOGGLE_ON or C.TOGGLE_OFF
    track.Parent = parent
    Corner(track, 11)

    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0, 16, 0, 16)
    thumb.Position = initVal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    thumb.BackgroundColor3 = C.WHITE
    thumb.Parent = track
    Corner(thumb, 8)

    local val = initVal
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = track

    btn.MouseButton1Click:Connect(function()
        val = not val
        local info = TweenInfo.new(0.15)
        TweenService:Create(track, info, {BackgroundColor3 = val and C.TOGGLE_ON or C.TOGGLE_OFF}):Play()
        TweenService:Create(thumb, info, {Position = val and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        callback(val)
    end)

    return track, function(newVal)
        val = newVal
        track.BackgroundColor3 = val and C.TOGGLE_ON or C.TOGGLE_OFF
        thumb.Position = val and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    end
end

local function ToggleRow(parent, labelText, initVal, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,BTN_H)
    row.BackgroundColor3 = C.CARD
    row.Parent = parent
    Corner(row, 6)

    local lbl = Label(row, labelText, FONT_MD, C.TEXT, FONT_SEMI)
    lbl.Size = UDim2.new(1,-56,1,0)
    lbl.Position = UDim2.new(0, PAD, 0, 0)

    local tog, setTog = MakeToggle(row, initVal, callback)
    tog.Position = UDim2.new(1,-46,0.5,-11)

    return row, setTog
end

local function BtnRow(parent, text, bg, callback)
    local b = Btn(parent, text, bg or C.ACCENT, callback)
    b.Size = UDim2.new(1,0,0,BTN_H)
    return b
end

local function SectionLabel(parent, text)
    local l = Label(parent, text, FONT_SM, C.SUBTEXT, FONT_BOLD)
    l.Size = UDim2.new(1,0,0,18)
    l.Text = text:upper()
    return l
end

local function Divider(parent)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(1,0,0,1)
    d.BackgroundColor3 = C.BORDER
    d.BorderSizePixel = 0
    d.Parent = parent
    return d
end

local function ScrollFrame(parent, h)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1,0,1,0)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 3
    sf.ScrollBarImageColor3 = C.ACCENT
    sf.BorderSizePixel = 0
    sf.CanvasSize = UDim2.new(0,0,0,0)
    sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sf.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0,6)
    layout.Parent = sf

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, PAD)
    pad.PaddingRight  = UDim.new(0, PAD)
    pad.PaddingTop    = UDim.new(0, PAD)
    pad.PaddingBottom = UDim.new(0, PAD)
    pad.Parent = sf

    return sf
end

-- Status badge
local function StatusBadge(parent, text, color)
    local f = Instance.new("Frame")
    f.BackgroundColor3 = color or C.ACCENT
    f.Size = UDim2.new(0,0,0,18)
    f.AutomaticSize = Enum.AutomaticSize.X
    f.Parent = parent
    Corner(f,4)
    local l = Label(f, text, FONT_SM, C.WHITE, FONT_BOLD, Enum.TextXAlignment.Center)
    l.Size = UDim2.new(0,0,1,0)
    l.AutomaticSize = Enum.AutomaticSize.X
    local p = Instance.new("UIPadding")
    p.PaddingLeft  = UDim.new(0,6)
    p.PaddingRight = UDim.new(0,6)
    p.Parent = l
    return f, l
end

-- ================================================
-- BUILD MAIN GUI
-- ================================================
-- Remove old instance
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
Main.Position = UDim2.new(0, 20, 0, 60)
Main.BackgroundColor3 = C.BG
Main.BorderSizePixel = 0
Main.Active = true
Main.Parent = ScreenGui
Corner(Main, 10)
Stroke(Main, C.BORDER, 1)

-- Drop shadow
local Shadow = Instance.new("ImageLabel")
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0,-15,0,-15)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ImageColor3 = Color3.fromRGB(0,0,0)
Shadow.ImageTransparency = 0.6
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49,49,450,450)
Shadow.ZIndex = 0
Shadow.Parent = Main

-- ================================================
-- TITLE BAR
-- ================================================
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1,0,0,44)
TitleBar.BackgroundColor3 = C.PANEL
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Main
Corner(TitleBar, 10)

-- Fix bottom corners of title bar
local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1,0,0,10)
TitleFix.Position = UDim2.new(0,0,1,-10)
TitleFix.BackgroundColor3 = C.PANEL
TitleFix.BorderSizePixel = 0
TitleFix.Parent = TitleBar

-- Icon + title
local TitleIcon = Label(TitleBar, "⚔", FONT_XL, C.ACCENT_LIT, FONT_BOLD, Enum.TextXAlignment.Center)
TitleIcon.Size = UDim2.new(0,30,1,0)
TitleIcon.Position = UDim2.new(0,10,0,0)

local TitleText = Label(TitleBar, "APD Script", FONT_LG, C.WHITE, FONT_BOLD)
TitleText.Size = UDim2.new(1,-120,1,0)
TitleText.Position = UDim2.new(0,44,0,0)

local VersionBadge, _ = StatusBadge(TitleBar, "v3.0", C.ACCENT)
VersionBadge.Position = UDim2.new(0,44,0.5,-9)
-- move it next to title
VersionBadge.Position = UDim2.new(0, 44 + 100, 0.5, -9)

-- Minimize button
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 28, 0, 28)
MinBtn.Position = UDim2.new(1,-36,0.5,-14)
MinBtn.BackgroundColor3 = C.CARD
MinBtn.Text = "—"
MinBtn.TextSize = FONT_MD
MinBtn.TextColor3 = C.SUBTEXT
MinBtn.Font = FONT_BOLD
MinBtn.AutoButtonColor = false
MinBtn.Parent = TitleBar
Corner(MinBtn, 6)

-- Minimized pill (shown when minimized)
local MinPill = Instance.new("TextButton")
MinPill.Size = UDim2.new(0, 120, 0, 36)
MinPill.Position = Main.Position
MinPill.BackgroundColor3 = C.PANEL
MinPill.Text = "⚔ APD Script"
MinPill.TextSize = FONT_MD
MinPill.TextColor3 = C.TEXT
MinPill.Font = FONT_BOLD
MinPill.Visible = false
MinPill.Active = true
MinPill.Parent = ScreenGui
Corner(MinPill, 18)
Stroke(MinPill, C.BORDER, 1)

-- Minimize logic
local isMinimized = false
MinBtn.MouseButton1Click:Connect(function()
    isMinimized = true
    Main.Visible = false
    MinPill.Visible = true
    MinPill.Position = UDim2.new(Main.Position.X.Scale, Main.Position.X.Offset,
                                  Main.Position.Y.Scale, Main.Position.Y.Offset)
end)
MinPill.MouseButton1Click:Connect(function()
    isMinimized = false
    Main.Visible = true
    MinPill.Visible = false
end)

-- Drag support (works on mobile too)
local dragging, dragStart, startPos = false, nil, nil

local function DragInput(input)
    if not dragging then return end
    local delta = input.Position - dragStart
    Main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
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
TitleBar.InputChanged:Connect(DragInput)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        DragInput(input)
    end
end)

-- Same for MinPill
local pdrag, pdragStart, pstartPos = false,nil,nil
MinPill.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        pdrag=true dragStart=input.Position pstartPos=MinPill.Position
        input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then pdrag=false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if not pdrag then return end
    if input.UserInputType==Enum.UserInputType.MouseMovement
    or input.UserInputType==Enum.UserInputType.Touch then
        local d = input.Position - dragStart
        MinPill.Position = UDim2.new(pstartPos.X.Scale, pstartPos.X.Offset+d.X,
                                      pstartPos.Y.Scale, pstartPos.Y.Offset+d.Y)
    end
end)

-- ================================================
-- TAB BAR
-- ================================================
local TABS = {"Farm","Macro","Profiles","Quick","Settings"}
local TabBar = Instance.new("Frame")
TabBar.Name = "TabBar"
TabBar.Size = UDim2.new(1,0,0,TAB_H+2)
TabBar.Position = UDim2.new(0,0,0,44)
TabBar.BackgroundColor3 = C.PANEL
TabBar.BorderSizePixel = 0
TabBar.Parent = Main

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabLayout.Padding = UDim.new(0,0)
TabLayout.Parent = TabBar

local TabPad = Instance.new("UIPadding")
TabPad.PaddingLeft  = UDim.new(0,4)
TabPad.PaddingRight = UDim.new(0,4)
TabPad.PaddingTop   = UDim.new(0,2)
TabPad.Parent       = TabBar

local TabBtns    = {}
local TabPages   = {}
local ActiveTab  = nil

-- Content area
local ContentArea = Instance.new("Frame")
ContentArea.Name = "Content"
ContentArea.Size = UDim2.new(1,0,1,-(44+TAB_H+4))
ContentArea.Position = UDim2.new(0,0,0,44+TAB_H+4)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = Main

local function SwitchTab(name)
    ActiveTab = name
    for tname, btn in pairs(TabBtns) do
        if tname == name then
            btn.BackgroundColor3 = C.ACCENT
            btn.TextColor3 = C.WHITE
        else
            btn.BackgroundColor3 = Color3.fromRGB(0,0,0,0)
            btn.BackgroundTransparency = 1
            btn.TextColor3 = C.SUBTEXT
        end
    end
    for tname, page in pairs(TabPages) do
        page.Visible = (tname == name)
    end
end

for i, tabName in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Text = tabName
    btn.TextSize = FONT_SM
    btn.Font = FONT
    btn.TextColor3 = C.SUBTEXT
    btn.BackgroundTransparency = 1
    btn.BackgroundColor3 = C.ACCENT
    btn.Size = UDim2.new(1/#TABS, -2, 1, -2)
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    btn.Parent = TabBar
    Corner(btn, 5)

    local page = Instance.new("Frame")
    page.Size = UDim2.new(1,0,1,0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = ContentArea

    TabBtns[tabName]  = btn
    TabPages[tabName] = page

    btn.MouseButton1Click:Connect(function() SwitchTab(tabName) end)
end

SwitchTab("Farm")

-- ================================================
-- STATUS BAR (bottom of window)
-- ================================================
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1,-PAD*2,0,22)
StatusBar.Position = UDim2.new(0,PAD,1,-26)
StatusBar.BackgroundTransparency = 1
StatusBar.Parent = Main

local StatusText = Label(StatusBar, "● Ready", FONT_SM, C.GREEN, FONT_SEMI)
StatusText.Size = UDim2.new(0.6,0,1,0)

local ActionCount = Label(StatusBar, "Actions: 0", FONT_SM, C.SUBTEXT, FONT_SEMI, Enum.TextXAlignment.Right)
ActionCount.Size = UDim2.new(0.4,0,1,0)
ActionCount.Position = UDim2.new(0.6,0,0,0)

local function SetStatus(text, color)
    StatusText.Text = "● " .. text
    StatusText.TextColor3 = color or C.GREEN
end

local function UpdateActionCount()
    ActionCount.Text = "Actions: " .. #MacroEngine.Actions
end

-- ================================================
-- PAGE: FARM
-- ================================================
local FarmScroll = ScrollFrame(TabPages["Farm"])

SectionLabel(FarmScroll, "Auto Actions")

local _, setUpgTog = ToggleRow(FarmScroll, "Auto Upgrade Units", Settings.auto_upgrade, function(v)
    Settings.auto_upgrade = v
    SaveSettings()
    if v then StartAutoUpgrade() end
    SetStatus(v and "Auto Upgrading..." or "Ready", v and C.GREEN or C.SUBTEXT)
end)

local _, setSkipTog = ToggleRow(FarmScroll, "Auto Skip Wave", Settings.auto_skip, function(v)
    Settings.auto_skip = v
    SaveSettings()
    if v then StartAutoSkip() end
end)

local _, setReplayTog = ToggleRow(FarmScroll, "Auto Replay", Settings.auto_replay, function(v)
    Settings.auto_replay = v
    SaveSettings()
    if v then StartAutoReplay() end
end)

local _, setSpeedTog = ToggleRow(FarmScroll, "Auto Set Gamespeed", Settings.auto_gamespeed, function(v)
    Settings.auto_gamespeed = v
    SaveSettings()
    if v then pcall(SetGamespeed, Settings.gamespeed) end
end)

Divider(FarmScroll)
SectionLabel(FarmScroll, "Game Speed")

-- Speed selector row
local SpeedRow = Instance.new("Frame")
SpeedRow.Size = UDim2.new(1,0,0,BTN_H)
SpeedRow.BackgroundColor3 = C.CARD
SpeedRow.Parent = FarmScroll
Corner(SpeedRow, 6)

local SpeedLbl = Label(SpeedRow, "Speed: "..Settings.gamespeed.."x", FONT_MD, C.TEXT, FONT_SEMI)
SpeedLbl.Size = UDim2.new(0.5,0,1,0)
SpeedLbl.Position = UDim2.new(0,PAD,0,0)

local speeds = {1, 1.5, 2}
local speedIdx = 1
for i,s in ipairs(speeds) do if s==Settings.gamespeed then speedIdx=i end end

local SpeedDec = Btn(SpeedRow, "<", C.ACCENT, function()
    speedIdx = math.max(1, speedIdx-1)
    Settings.gamespeed = speeds[speedIdx]
    SpeedLbl.Text = "Speed: "..Settings.gamespeed.."x"
    SaveSettings()
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
end)
SpeedDec.Size = UDim2.new(0,32,0,26)
SpeedDec.Position = UDim2.new(1,-70,0.5,-13)

local SpeedInc = Btn(SpeedRow, ">", C.ACCENT, function()
    speedIdx = math.min(#speeds, speedIdx+1)
    Settings.gamespeed = speeds[speedIdx]
    SpeedLbl.Text = "Speed: "..Settings.gamespeed.."x"
    SaveSettings()
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
end)
SpeedInc.Size = UDim2.new(0,32,0,26)
SpeedInc.Position = UDim2.new(1,-34,0.5,-13)

Divider(FarmScroll)
SectionLabel(FarmScroll, "Manual")

BtnRow(FarmScroll, "⬆ Upgrade All Now", C.ACCENT, function()
    task.spawn(function()
        SetStatus("Upgrading...", C.ORANGE)
        local ok,placed = pcall(GetPlacedUnits)
        if ok and placed then
            for guid,ud in pairs(placed) do
                local uid=tostring(ud.Type) local lv,mx=0,0
                if ud.Info and ud.Info[uid] then
                    lv=ud.Info[uid].Upgrade or 0
                    if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx=#ud.Info[uid].Data.upgrades end
                end
                if lv<mx then pcall(UpgradeUnit,guid) task.wait(0.3) end
            end
        end
        SetStatus("Done", C.GREEN)
    end)
end)

BtnRow(FarmScroll, "💰 Sell All Units", C.RED, function()
    task.spawn(function()
        SetStatus("Selling...", C.ORANGE)
        local ok,placed = pcall(GetPlacedUnits)
        if ok and placed then
            for g,_ in pairs(placed) do pcall(SellUnit,g) task.wait(0.3) end
        end
        SetStatus("Sold!", C.GREEN)
    end)
end)

BtnRow(FarmScroll, "⏭ Skip Wave", C.ACCENT, function()
    pcall(VoteSkipWave) SetStatus("Skip sent!", C.GREEN)
end)

BtnRow(FarmScroll, "🔁 Replay Game", C.ACCENT, function()
    pcall(Replay) SetStatus("Retry fired!", C.GREEN)
end)

-- ================================================
-- PAGE: MACRO (recorder)
-- ================================================
local MacroScroll = ScrollFrame(TabPages["Macro"])

SectionLabel(MacroScroll, "Record")

-- Macro name input
local NameRow = Instance.new("Frame")
NameRow.Size = UDim2.new(1,0,0,BTN_H)
NameRow.BackgroundColor3 = C.CARD
NameRow.Parent = MacroScroll
Corner(NameRow, 6)

local NameLbl = Label(NameRow, "Name:", FONT_MD, C.SUBTEXT, FONT_SEMI)
NameLbl.Size = UDim2.new(0,50,1,0)
NameLbl.Position = UDim2.new(0,PAD,0,0)

local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(1,-60,0,BTN_H-8)
NameBox.Position = UDim2.new(0,56,0,4)
NameBox.BackgroundColor3 = C.BG
NameBox.TextColor3 = C.WHITE
NameBox.PlaceholderText = "e.g. Wave1Farm"
NameBox.PlaceholderColor3 = C.SUBTEXT
NameBox.TextSize = FONT_MD
NameBox.Font = FONT_SEMI
NameBox.ClearTextOnFocus = false
NameBox.Text = ""
NameBox.Parent = NameRow
Corner(NameBox, 5)
local NBPad = Instance.new("UIPadding")
NBPad.PaddingLeft = UDim.new(0,6)
NBPad.Parent = NameBox

-- Record / Stop button
local RecBtn = BtnRow(MacroScroll, "🔴  Start Recording", C.RED, function() end)
local isRec = false
RecBtn.MouseButton1Click:Connect(function()
    isRec = not isRec
    if isRec then
        MacroEngine:StartRecording()
        RecBtn.Text = "⏹  Stop Recording"
        RecBtn.BackgroundColor3 = C.CARD
        SetStatus("Recording...", C.RED)
    else
        MacroEngine:StopRecording()
        RecBtn.Text = "🔴  Start Recording"
        RecBtn.BackgroundColor3 = C.RED
        SetStatus("Recording stopped ("..#MacroEngine.Actions.." actions)", C.ORANGE)
        UpdateActionCount()
    end
end)

Divider(MacroScroll)
SectionLabel(MacroScroll, "Record APD Actions")

local apd_actions = {
    {"📌 Upgrade All",  "upgrade_all", {}},
    {"📌 Sell All",     "sell_all",    {}},
    {"📌 Skip Wave",    "skip_wave",   {}},
    {"📌 Replay",       "replay",      {}},
    {"📌 Wait 3s",      "wait",        {3}},
    {"📌 Wait 5s",      "wait",        {5}},
    {"📌 Wait 10s",     "wait",        {10}},
}
for _, entry in ipairs(apd_actions) do
    local label, atype, adata = entry[1], entry[2], entry[3]
    BtnRow(MacroScroll, label, C.CARD, function()
        MacroEngine:RecordAction(atype, adata)
        UpdateActionCount()
        SetStatus("Recorded: "..atype, C.GREEN)
    end)
end

Divider(MacroScroll)
SectionLabel(MacroScroll, "Save")

BtnRow(MacroScroll, "💾  Save Macro", C.GREEN, function()
    local name = NameBox.Text
    if name == "" then SetStatus("Enter a name first!", C.RED) return end
    if #MacroEngine.Actions == 0 then SetStatus("Nothing recorded yet!", C.RED) return end
    MacroEngine:Save(name)
    SetStatus("Saved: "..name.." ("..#MacroEngine.Actions.." actions)", C.GREEN)
    UpdateActionCount()
end)

BtnRow(MacroScroll, "🗑  Delete Macro", Color3.fromRGB(100,40,40), function()
    local name = NameBox.Text
    if name == "" then SetStatus("Enter macro name to delete!", C.RED) return end
    MacroEngine:Delete(name)
    SetStatus("Deleted: "..name, C.ORANGE)
end)

BtnRow(MacroScroll, "🔄  Clear Actions", C.CARD, function()
    MacroEngine.Actions = {}
    UpdateActionCount()
    SetStatus("Actions cleared", C.SUBTEXT)
end)

-- ================================================
-- PAGE: PROFILES
-- ================================================
local ProfileScroll = ScrollFrame(TabPages["Profiles"])

SectionLabel(ProfileScroll, "Select Profile")

-- Macro list display
local MacroListFrame = Instance.new("Frame")
MacroListFrame.Size = UDim2.new(1,0,0,0)
MacroListFrame.AutomaticSize = Enum.AutomaticSize.Y
MacroListFrame.BackgroundColor3 = C.CARD
MacroListFrame.Parent = ProfileScroll
Corner(MacroListFrame, 6)

local MacroListLayout = Instance.new("UIListLayout")
MacroListLayout.SortOrder = Enum.SortOrder.LayoutOrder
MacroListLayout.Padding = UDim.new(0,2)
MacroListLayout.Parent = MacroListFrame

local MacroListPad = Instance.new("UIPadding")
MacroListPad.PaddingLeft   = UDim.new(0,6)
MacroListPad.PaddingRight  = UDim.new(0,6)
MacroListPad.PaddingTop    = UDim.new(0,6)
MacroListPad.PaddingBottom = UDim.new(0,6)
MacroListPad.Parent = MacroListFrame

local selectedMacro = ""
local macroRowBtns = {}

local function RefreshMacroList()
    -- clear existing rows
    for _, b in pairs(macroRowBtns) do b:Destroy() end
    macroRowBtns = {}

    local list = MacroEngine:List()
    if #list == 0 then
        local empty = Label(MacroListFrame, "No macros saved yet.", FONT_MD, C.SUBTEXT, FONT_SEMI)
        empty.Size = UDim2.new(1,0,0,30)
        table.insert(macroRowBtns, empty)
        return
    end

    for _, name in ipairs(list) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1,0,0,BTN_H)
        row.BackgroundColor3 = (name==selectedMacro) and C.ACCENT or C.BG
        row.Text = ""
        row.AutoButtonColor = false
        row.Parent = MacroListFrame
        Corner(row, 5)

        local ico = Label(row, "▶", FONT_MD, C.ACCENT_LIT, FONT_BOLD, Enum.TextXAlignment.Center)
        ico.Size = UDim2.new(0,24,1,0)
        ico.Position = UDim2.new(0,4,0,0)

        local namelbl = Label(row, name, FONT_MD, C.TEXT, FONT_SEMI)
        namelbl.Size = UDim2.new(1,-32,1,0)
        namelbl.Position = UDim2.new(0,28,0,0)

        row.MouseButton1Click:Connect(function()
            selectedMacro = name
            MacroEngine:Load(name)
            UpdateActionCount()
            SetStatus("Loaded: "..name.." ("..#MacroEngine.Actions.." actions)", C.GREEN)
            RefreshMacroList()
        end)

        table.insert(macroRowBtns, row)
    end
end

RefreshMacroList()

BtnRow(ProfileScroll, "🔄  Refresh List", C.CARD, function()
    RefreshMacroList()
    SetStatus("List refreshed", C.SUBTEXT)
end)

Divider(ProfileScroll)
SectionLabel(ProfileScroll, "Playback")

-- Playback speed row
local PBSpeedRow = Instance.new("Frame")
PBSpeedRow.Size = UDim2.new(1,0,0,BTN_H)
PBSpeedRow.BackgroundColor3 = C.CARD
PBSpeedRow.Parent = ProfileScroll
Corner(PBSpeedRow, 6)

local PBSpeedLbl = Label(PBSpeedRow, "Playback: "..Settings.macro_speed.."x", FONT_MD, C.TEXT, FONT_SEMI)
PBSpeedLbl.Size = UDim2.new(0.6,0,1,0)
PBSpeedLbl.Position = UDim2.new(0,PAD,0,0)

local pbSpeeds = {0.5, 1, 1.5, 2, 3, 5}
local pbIdx = 2
for i,s in ipairs(pbSpeeds) do if s==Settings.macro_speed then pbIdx=i end end

local PBDec = Btn(PBSpeedRow, "<", C.ACCENT, function()
    pbIdx = math.max(1,pbIdx-1)
    MacroEngine.Speed = pbSpeeds[pbIdx]
    Settings.macro_speed = pbSpeeds[pbIdx]
    PBSpeedLbl.Text = "Playback: "..MacroEngine.Speed.."x"
    SaveSettings()
end)
PBDec.Size = UDim2.new(0,32,0,26)
PBDec.Position = UDim2.new(1,-70,0.5,-13)

local PBInc = Btn(PBSpeedRow, ">", C.ACCENT, function()
    pbIdx = math.min(#pbSpeeds,pbIdx+1)
    MacroEngine.Speed = pbSpeeds[pbIdx]
    Settings.macro_speed = pbSpeeds[pbIdx]
    PBSpeedLbl.Text = "Playback: "..MacroEngine.Speed.."x"
    SaveSettings()
end)
PBInc.Size = UDim2.new(0,32,0,26)
PBInc.Position = UDim2.new(1,-34,0.5,-13)

local PlayBtn = BtnRow(ProfileScroll, "▶  Play Macro (Loop)", C.GREEN, function()
    if #MacroEngine.Actions == 0 then
        SetStatus("Load a macro first!", C.RED) return
    end
    if MacroEngine.IsPlaying then
        SetStatus("Already playing! Stop first.", C.ORANGE) return
    end
    MacroEngine:StartPlayback(function(loops)
        SetStatus("Macro finished ("..loops.." loops)", C.SUBTEXT)
        PlayBtn.Text = "▶  Play Macro (Loop)"
        PlayBtn.BackgroundColor3 = C.GREEN
    end)
    PlayBtn.Text = "▶  Playing..."
    PlayBtn.BackgroundColor3 = Color3.fromRGB(40,140,70)
    SetStatus("Playing: "..(MacroEngine.CurrentName~="" and MacroEngine.CurrentName or "macro").." (looping)", C.GREEN)
end)

BtnRow(ProfileScroll, "⏹  Stop Macro", C.RED, function()
    MacroEngine:StopPlayback()
    PlayBtn.Text = "▶  Play Macro (Loop)"
    PlayBtn.BackgroundColor3 = C.GREEN
    SetStatus("Macro stopped", C.SUBTEXT)
end)

-- ================================================
-- PAGE: QUICK
-- ================================================
local QuickScroll = ScrollFrame(TabPages["Quick"])

SectionLabel(QuickScroll, "One-Shot Actions")

BtnRow(QuickScroll, "⬆ Upgrade All", C.ACCENT, function()
    task.spawn(function()
        SetStatus("Upgrading...", C.ORANGE)
        local ok,placed=pcall(GetPlacedUnits)
        if ok and placed then
            for guid,ud in pairs(placed) do
                local uid=tostring(ud.Type) local lv,mx=0,0
                if ud.Info and ud.Info[uid] then
                    lv=ud.Info[uid].Upgrade or 0
                    if ud.Info[uid].Data and ud.Info[uid].Data.upgrades then mx=#ud.Info[uid].Data.upgrades end
                end
                if lv<mx then pcall(UpgradeUnit,guid) task.wait(0.3) end
            end
        end
        SetStatus("Upgraded!", C.GREEN)
    end)
end)

BtnRow(QuickScroll, "💰 Sell All", C.RED, function()
    task.spawn(function()
        SetStatus("Selling...", C.ORANGE)
        local ok,placed=pcall(GetPlacedUnits)
        if ok and placed then for g,_ in pairs(placed) do pcall(SellUnit,g) task.wait(0.3) end end
        SetStatus("All sold!", C.GREEN)
    end)
end)

BtnRow(QuickScroll, "⏭ Skip Wave", C.ACCENT, function()
    pcall(VoteSkipWave) SetStatus("Skip sent!", C.GREEN)
end)

BtnRow(QuickScroll, "🔁 Replay", C.ACCENT, function()
    pcall(Replay) SetStatus("Retry fired!", C.GREEN)
end)

BtnRow(QuickScroll, "⚡ Set Speed Now", C.ACCENT, function()
    pcall(SetGamespeed, Settings.gamespeed)
    SetStatus("Speed set to "..Settings.gamespeed.."x", C.GREEN)
end)

-- ================================================
-- PAGE: SETTINGS
-- ================================================
local SettingsScroll = ScrollFrame(TabPages["Settings"])

SectionLabel(SettingsScroll, "Delays")

-- Upgrade delay row
local UDRow = Instance.new("Frame")
UDRow.Size = UDim2.new(1,0,0,BTN_H)
UDRow.BackgroundColor3 = C.CARD
UDRow.Parent = SettingsScroll
Corner(UDRow, 6)
local UDLbl = Label(UDRow, "Upgrade Delay: "..Settings.upgrade_delay.."s", FONT_MD, C.TEXT)
UDLbl.Size = UDim2.new(0.65,0,1,0)
UDLbl.Position = UDim2.new(0,PAD,0,0)
local udDelays = {0.1,0.3,0.5,1,2}
local udIdx = 3
for i,v in ipairs(udDelays) do if v==Settings.upgrade_delay then udIdx=i end end
local UDDec = Btn(UDRow,"<",C.ACCENT,function()
    udIdx=math.max(1,udIdx-1) Settings.upgrade_delay=udDelays[udIdx]
    UDLbl.Text="Upgrade Delay: "..Settings.upgrade_delay.."s" SaveSettings()
end) UDDec.Size=UDim2.new(0,32,0,26) UDDec.Position=UDim2.new(1,-70,0.5,-13)
local UDInc = Btn(UDRow,">",C.ACCENT,function()
    udIdx=math.min(#udDelays,udIdx+1) Settings.upgrade_delay=udDelays[udIdx]
    UDLbl.Text="Upgrade Delay: "..Settings.upgrade_delay.."s" SaveSettings()
end) UDInc.Size=UDim2.new(0,32,0,26) UDInc.Position=UDim2.new(1,-34,0.5,-13)

-- Skip delay row
local SDRow = Instance.new("Frame")
SDRow.Size = UDim2.new(1,0,0,BTN_H)
SDRow.BackgroundColor3 = C.CARD
SDRow.Parent = SettingsScroll
Corner(SDRow, 6)
local SDLbl = Label(SDRow, "Skip Delay: "..Settings.skip_delay.."s", FONT_MD, C.TEXT)
SDLbl.Size = UDim2.new(0.65,0,1,0)
SDLbl.Position = UDim2.new(0,PAD,0,0)
local sdDelays = {1,2,3,5,10}
local sdIdx = 3
for i,v in ipairs(sdDelays) do if v==Settings.skip_delay then sdIdx=i end end
local SDDec = Btn(SDRow,"<",C.ACCENT,function()
    sdIdx=math.max(1,sdIdx-1) Settings.skip_delay=sdDelays[sdIdx]
    SDLbl.Text="Skip Delay: "..Settings.skip_delay.."s" SaveSettings()
end) SDDec.Size=UDim2.new(0,32,0,26) SDDec.Position=UDim2.new(1,-70,0.5,-13)
local SDInc = Btn(SDRow,">",C.ACCENT,function()
    sdIdx=math.min(#sdDelays,sdIdx+1) Settings.skip_delay=sdDelays[sdIdx]
    SDLbl.Text="Skip Delay: "..Settings.skip_delay.."s" SaveSettings()
end) SDInc.Size=UDim2.new(0,32,0,26) SDInc.Position=UDim2.new(1,-34,0.5,-13)

Divider(SettingsScroll)
SectionLabel(SettingsScroll, "Misc")

BtnRow(SettingsScroll, "Reset All Settings", Color3.fromRGB(100,40,40), function()
    Settings = {
        gamespeed=1.5, auto_gamespeed=false, macro_speed=1.0,
        auto_upgrade=false, auto_skip=false, auto_replay=false,
        skip_delay=3, upgrade_delay=0.5,
    }
    MacroEngine.Speed = 1
    SaveSettings()
    SetStatus("Settings reset!", C.ORANGE)
end)

BtnRow(SettingsScroll, "🔄 Reload Script", C.CARD, function()
    if PlayerGui:FindFirstChild("APDScript") then
        PlayerGui:FindFirstChild("APDScript"):Destroy()
    end
    SetStatus("Reloading...", C.SUBTEXT)
end)

-- Info
Divider(SettingsScroll)
SectionLabel(SettingsScroll, "Info")
local infoLbl = Label(SettingsScroll, "APD Script v3.0\nGameId: 5787561793\nMacros saved to:\nAPDScript/Macros/", FONT_SM, C.SUBTEXT, FONT_SEMI)
infoLbl.Size = UDim2.new(1,0,0,60)
infoLbl.TextWrapped = true

-- ================================================
-- Apply saved settings on load
-- ================================================
task.spawn(function()
    task.wait(2)
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
    if Settings.auto_upgrade   then StartAutoUpgrade() end
    if Settings.auto_skip      then StartAutoSkip()    end
    if Settings.auto_replay    then StartAutoReplay()  end
end)

UpdateActionCount()
SetStatus("Ready — APD Script v3.0", C.GREEN)
print("[APD Script] v3.0 loaded — Custom GUI")
