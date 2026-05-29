-- ================================================
-- Auto Roll Script — Random Anime Tower Defense
-- Stops on selected rarity | Fixed v2
-- ================================================

if not game:IsLoaded() then game.Loaded:Wait() end

local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local UserInputService   = game:GetService("UserInputService")
local RunService         = game:GetService("RunService")
local VIM                = game:GetService("VirtualInputManager")  -- FIXED: get as service, not call

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")
local IsMobile  = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- ================================================
-- Rarity Config
-- ================================================
local RARITIES = {
    { name = "Common",    color = Color3.fromRGB(180, 180, 180), rank = 1 },
    { name = "Rare",      color = Color3.fromRGB(80,  140, 255), rank = 2 },
    { name = "Epic",      color = Color3.fromRGB(170,  80, 255), rank = 3 },
    { name = "Legendary", color = Color3.fromRGB(255, 180,  30), rank = 4 },
    { name = "Mythic",    color = Color3.fromRGB(255,  70,  70), rank = 5 },
    { name = "Secret",    color = Color3.fromRGB(255,  50, 180), rank = 6 },
    { name = "Limited",   color = Color3.fromRGB(50,  220, 120), rank = 7 },
}

-- ================================================
-- State
-- ================================================
local State = {
    rolling        = false,
    stopRarities   = { Common=false, Rare=false, Epic=false, Legendary=true, Mythic=true, Secret=true, Limited=true },
    rollDelay      = 0.5,
    rollsSinceStart= 0,
    lastRarity     = "",
    stopMode       = "Exact",
    useRemote      = true,
    totalRolled    = 0,
}

-- ================================================
-- Remote finder — safe, no errors if not found
-- ================================================
local RollRemote = nil

local function FindRollRemote()
    -- Known path patterns
    local paths = {
        {"Events","Roll"}, {"Events","RollUnit"}, {"Events","Gacha"},
        {"Events","Summon"}, {"RemoteEvents","Roll"}, {"RemoteEvents","Gacha"},
    }
    for _, path in ipairs(paths) do
        local cur = ReplicatedStorage
        local ok = true
        for _, key in ipairs(path) do
            local child = cur:FindFirstChild(key)
            if not child then ok=false; break end
            cur = child
        end
        if ok and cur and (cur:IsA("RemoteEvent") or cur:IsA("RemoteFunction")) then
            return cur
        end
    end
    -- Deep search
    local found = nil
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = d.Name:lower()
                if n:find("roll") or n:find("gacha") or n:find("summon") then
                    found = d; break
                end
            end
        end
    end)
    return found
end

-- Search in background — never errors on main thread
task.spawn(function()
    task.wait(3)
    RollRemote = FindRollRemote()
    print("[AutoRoll] Remote:", RollRemote and RollRemote.Name or "not found — using button click fallback")
end)

-- ================================================
-- GUI CONSTANTS
-- ================================================
local C = {
    BG     = Color3.fromRGB(18, 18, 24),
    PANEL  = Color3.fromRGB(26, 26, 36),
    CARD   = Color3.fromRGB(34, 34, 48),
    BORDER = Color3.fromRGB(50, 50, 70),
    TEXT   = Color3.fromRGB(225, 225, 240),
    SUB    = Color3.fromRGB(130, 130, 160),
    WHITE  = Color3.fromRGB(255, 255, 255),
    GREEN  = Color3.fromRGB(60, 210, 100),
    RED    = Color3.fromRGB(220, 60, 60),
    ORANGE = Color3.fromRGB(220, 145, 40),
    ACCENT = Color3.fromRGB(90, 90, 140),
    TOG_ON = Color3.fromRGB(80, 210, 130),
    TOG_OFF= Color3.fromRGB(55, 55, 80),
}
local FN   = Enum.Font.GothamBold
local FNR  = Enum.Font.Gotham
local W    = IsMobile and 340 or 380
local BH   = IsMobile and 30 or 32
local FSM  = IsMobile and 10 or 11
local FMD  = IsMobile and 11 or 12
local FLG  = IsMobile and 13 or 14

-- ================================================
-- GUI Helpers
-- ================================================
local function Corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p
end
local function Stroke(p, col)
    local s = Instance.new("UIStroke"); s.Color = col or C.BORDER; s.Thickness = 1; s.Parent = p
end
local function Lbl(parent, txt, sz, col, font, xa)
    local l = Instance.new("TextLabel")
    l.Text = txt; l.TextSize = sz or FMD; l.TextColor3 = col or C.TEXT
    l.Font = font or FNR; l.BackgroundTransparency = 1
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.Parent = parent; return l
end
local function MkBtn(parent, txt, bg, cb)
    local b = Instance.new("TextButton")
    b.Text = txt; b.TextSize = FMD; b.TextColor3 = C.WHITE; b.Font = FN
    b.BackgroundColor3 = bg or C.ACCENT; b.AutoButtonColor = false; b.Parent = parent
    Corner(b, 6)
    b.MouseButton1Click:Connect(function()
        local o = b.BackgroundColor3
        b.BackgroundColor3 = Color3.fromRGB(
            math.min(o.R*255+20,255)/255, math.min(o.G*255+20,255)/255, math.min(o.B*255+20,255)/255)
        task.delay(0.1, function() if b and b.Parent then b.BackgroundColor3 = o end end)
        cb()
    end)
    return b
end
local function MkToggle(parent, init, cb)
    local track = Instance.new("Frame")
    track.Size = UDim2.new(0,40,0,21); track.BackgroundColor3 = init and C.TOG_ON or C.TOG_OFF
    track.Parent = parent; Corner(track, 11)
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0,15,0,15); thumb.BackgroundColor3 = C.WHITE
    thumb.Position = init and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)
    thumb.Parent = track; Corner(thumb, 8)
    local val = init
    local btn = Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=track
    btn.MouseButton1Click:Connect(function()
        val = not val
        TweenService:Create(track, TweenInfo.new(0.12), {BackgroundColor3 = val and C.TOG_ON or C.TOG_OFF}):Play()
        TweenService:Create(thumb, TweenInfo.new(0.12), {Position = val and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)}):Play()
        cb(val)
    end)
    return track, function(nv)
        val = nv; track.BackgroundColor3 = nv and C.TOG_ON or C.TOG_OFF
        thumb.Position = nv and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)
    end
end
local function ToggleRow(parent, txt, init, cb)
    local row = Instance.new("Frame"); row.Size=UDim2.new(1,0,0,BH); row.BackgroundTransparency=1; row.Parent=parent
    local l = Lbl(row, txt, FMD, C.TEXT, FNR); l.Size = UDim2.new(1,-48,1,0)
    local tog, setTog = MkToggle(row, init, cb); tog.Position = UDim2.new(1,-44,0.5,-10)
    return row, setTog
end

-- ================================================
-- Build GUI
-- ================================================
if PlayerGui:FindFirstChild("AutoRoll") then PlayerGui:FindFirstChild("AutoRoll"):Destroy() end

local SG = Instance.new("ScreenGui")
SG.Name = "AutoRoll"; SG.ResetOnSpawn = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; SG.Parent = PlayerGui

-- Window
local Win = Instance.new("Frame")
Win.Size = UDim2.new(0,W,0,0); Win.AutomaticSize = Enum.AutomaticSize.Y
Win.Position = UDim2.new(0.04,0,0.08,0); Win.BackgroundColor3 = C.BG
Win.Active = true; Win.Parent = SG; Corner(Win,10); Stroke(Win)

local WL = Instance.new("UIListLayout"); WL.SortOrder = Enum.SortOrder.LayoutOrder; WL.Padding = UDim.new(0,0); WL.Parent = Win

-- Shadow
local Shad = Instance.new("ImageLabel")
Shad.Size=UDim2.new(1,32,1,32); Shad.Position=UDim2.new(0,-16,0,-16)
Shad.BackgroundTransparency=1; Shad.Image="rbxassetid://6014261993"
Shad.ImageTransparency=0.55; Shad.ImageColor3=Color3.fromRGB(0,0,0)
Shad.ScaleType=Enum.ScaleType.Slice; Shad.SliceCenter=Rect.new(49,49,450,450)
Shad.ZIndex=0; Shad.Parent=Win

-- Header
local Hdr = Instance.new("Frame")
Hdr.Size=UDim2.new(1,0,0,38); Hdr.BackgroundColor3=C.PANEL; Hdr.LayoutOrder=0; Hdr.Parent=Win; Corner(Hdr,10)
local HFix=Instance.new("Frame"); HFix.Size=UDim2.new(1,0,0,10); HFix.Position=UDim2.new(0,0,1,-10); HFix.BackgroundColor3=C.PANEL; HFix.BorderSizePixel=0; HFix.Parent=Hdr
Lbl(Hdr,"🎲 Auto Roll",FLG,C.WHITE,FN).Size = UDim2.new(0,160,1,0); local htl = Hdr:FindFirstChildWhichIsA("TextLabel"); if htl then htl.Position=UDim2.new(0,12,0,0) end
local HSub = Lbl(Hdr,"Stops on target rarity",FSM,C.SUB,FNR); HSub.Size=UDim2.new(0,180,1,0); HSub.Position=UDim2.new(0,170,0,0)
local CloseBtn = MkBtn(Hdr,"✕",Color3.fromRGB(180,50,50),function() SG:Destroy() end)
CloseBtn.Size=UDim2.new(0,26,0,22); CloseBtn.Position=UDim2.new(1,-30,0.5,-11)

-- Drag
local drag,ds,dp=false,nil,nil
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drag=true; ds=i.Position; dp=Win.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if not drag then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local d=i.Position-ds; Win.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
    end
end)

-- Body
local Body = Instance.new("Frame")
Body.Size=UDim2.new(1,0,0,0); Body.AutomaticSize=Enum.AutomaticSize.Y
Body.BackgroundTransparency=1; Body.LayoutOrder=1; Body.Parent=Win
local BLayout=Instance.new("UIListLayout"); BLayout.SortOrder=Enum.SortOrder.LayoutOrder; BLayout.Padding=UDim.new(0,6); BLayout.Parent=Body
local BPad=Instance.new("UIPadding")
BPad.PaddingLeft=UDim.new(0,8); BPad.PaddingRight=UDim.new(0,8)
BPad.PaddingTop=UDim.new(0,8); BPad.PaddingBottom=UDim.new(0,10); BPad.Parent=Body

local function Section(txt)
    local l = Lbl(Body,txt:upper(),FSM,C.SUB,FN); l.Size=UDim2.new(1,0,0,14); return l
end
local function Gap(h)
    local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,h or 2); f.BackgroundTransparency=1; f.Parent=Body
end

-- ================================================
-- STATUS CARD
-- ================================================
Section("Status")
local StatCard=Instance.new("Frame"); StatCard.Size=UDim2.new(1,0,0,0); StatCard.AutomaticSize=Enum.AutomaticSize.Y
StatCard.BackgroundColor3=C.CARD; StatCard.Parent=Body; Corner(StatCard,7)
local SCL=Instance.new("UIListLayout"); SCL.SortOrder=Enum.SortOrder.LayoutOrder; SCL.Padding=UDim.new(0,3); SCL.Parent=StatCard
local SCP=Instance.new("UIPadding"); SCP.PaddingLeft=UDim.new(0,8); SCP.PaddingRight=UDim.new(0,8)
SCP.PaddingTop=UDim.new(0,6); SCP.PaddingBottom=UDim.new(0,6); SCP.Parent=StatCard

local StatusLbl=Lbl(StatCard,"● Idle",FMD,C.SUB,FN); StatusLbl.Size=UDim2.new(1,0,0,20)

local function StatRow(key)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,18); row.BackgroundTransparency=1; row.Parent=StatCard
    local kl=Lbl(row,key,FSM,C.SUB,FNR); kl.Size=UDim2.new(0.52,0,1,0)
    local vl=Lbl(row,"—",FSM,C.WHITE,FN,Enum.TextXAlignment.Right); vl.Size=UDim2.new(0.48,0,1,0)
    return vl
end
local StatRolls  = StatRow("Rolls this session:")
local StatRarity = StatRow("Last rarity:")
local StatMethod = StatRow("Roll method:")

local function SetStatus(txt, col)
    StatusLbl.Text = "● "..txt; StatusLbl.TextColor3 = col or C.SUB
end

-- ================================================
-- RARITY CHIPS
-- ================================================
Gap(2); Section("Stop when I get...")

local RarFrame=Instance.new("Frame"); RarFrame.Size=UDim2.new(1,0,0,0); RarFrame.AutomaticSize=Enum.AutomaticSize.Y
RarFrame.BackgroundColor3=C.CARD; RarFrame.Parent=Body; Corner(RarFrame,7)
local RFL=Instance.new("UIListLayout"); RFL.SortOrder=Enum.SortOrder.LayoutOrder
RFL.FillDirection=Enum.FillDirection.Horizontal; RFL.Wraps=true; RFL.Padding=UDim.new(0,4); RFL.Parent=RarFrame
local RFP=Instance.new("UIPadding"); RFP.PaddingLeft=UDim.new(0,6); RFP.PaddingRight=UDim.new(0,6)
RFP.PaddingTop=UDim.new(0,6); RFP.PaddingBottom=UDim.new(0,6); RFP.Parent=RarFrame

local raritySetters = {}
for _, rar in ipairs(RARITIES) do
    local isOn = State.stopRarities[rar.name]
    local chipW = math.floor((W - 36) / 2) - 4

    local chip = Instance.new("TextButton")
    chip.Size = UDim2.new(0, chipW, 0, BH - 4)
    chip.BackgroundColor3 = isOn and rar.color or C.PANEL
    chip.Text = ""; chip.AutoButtonColor = false; chip.Parent = RarFrame; Corner(chip, 6)

    local strk = Instance.new("UIStroke"); strk.Color = isOn and rar.color or C.BORDER; strk.Thickness = 1; strk.Parent = chip

    local tick_ = Lbl(chip, isOn and "✓" or "○", FSM, isOn and C.WHITE or C.SUB, FN, Enum.TextXAlignment.Center)
    tick_.Size = UDim2.new(0,18,1,0)
    local cLbl = Lbl(chip, rar.name, FSM, isOn and C.WHITE or C.SUB, FN)
    cLbl.Size = UDim2.new(1,-20,1,0); cLbl.Position = UDim2.new(0,20,0,0)

    local function setChip(v)
        State.stopRarities[rar.name] = v
        TweenService:Create(chip,TweenInfo.new(0.1),{BackgroundColor3=v and rar.color or C.PANEL}):Play()
        strk.Color = v and rar.color or C.BORDER
        tick_.Text = v and "✓" or "○"; tick_.TextColor3 = v and C.WHITE or C.SUB
        cLbl.TextColor3 = v and C.WHITE or C.SUB
    end
    chip.MouseButton1Click:Connect(function() setChip(not State.stopRarities[rar.name]) end)
    raritySetters[rar.name] = setChip
end

-- Quick presets row
local PresetRow=Instance.new("Frame"); PresetRow.Size=UDim2.new(1,0,0,BH); PresetRow.BackgroundTransparency=1; PresetRow.Parent=Body
local PRL=Instance.new("UIListLayout"); PRL.SortOrder=Enum.SortOrder.LayoutOrder; PRL.FillDirection=Enum.FillDirection.Horizontal; PRL.Padding=UDim.new(0,4); PRL.Parent=PresetRow

local function PresetBtn(txt, bg, rarList)
    local b = MkBtn(PresetRow, txt, bg, function()
        for _, rar in ipairs(RARITIES) do raritySetters[rar.name](false) end
        for _, n in ipairs(rarList) do if raritySetters[n] then raritySetters[n](true) end end
    end)
    b.Size = UDim2.new(0, math.floor((W-36)/4)-2, 1, 0); b.TextSize = FSM
end
PresetBtn("Epic+",    Color3.fromRGB(130,60,200),  {"Epic","Legendary","Mythic","Secret","Limited"})
PresetBtn("Legend+",  Color3.fromRGB(200,140,20),  {"Legendary","Mythic","Secret","Limited"})
PresetBtn("Mythic+",  Color3.fromRGB(200,50,50),   {"Mythic","Secret","Limited"})
PresetBtn("Secret+",  Color3.fromRGB(200,40,150),  {"Secret","Limited"})

-- ================================================
-- DELAY SLIDER
-- ================================================
Gap(2); Section("Roll Delay")

local DelayRow=Instance.new("Frame"); DelayRow.Size=UDim2.new(1,0,0,BH+6); DelayRow.BackgroundTransparency=1; DelayRow.Parent=Body
local DelLbl=Lbl(DelayRow,"Roll Delay (s)",FMD,C.TEXT,FNR); DelLbl.Size=UDim2.new(0.6,0,0,14)
local DelVal=Lbl(DelayRow,tostring(State.rollDelay),FMD,Color3.fromRGB(120,140,255),FN,Enum.TextXAlignment.Right); DelVal.Size=UDim2.new(0.4,0,0,14)
local DelTrack=Instance.new("Frame"); DelTrack.Size=UDim2.new(1,0,0,5); DelTrack.Position=UDim2.new(0,0,0,20)
DelTrack.BackgroundColor3=C.CARD; DelTrack.BorderSizePixel=0; DelTrack.Parent=DelayRow; Corner(DelTrack,3)
local DelFill=Instance.new("Frame"); DelFill.Size=UDim2.new((State.rollDelay-0.1)/(3-0.1),0,1,0)
DelFill.BackgroundColor3=Color3.fromRGB(90,100,220); DelFill.BorderSizePixel=0; DelFill.Parent=DelTrack; Corner(DelFill,3)
local DelThumb=Instance.new("Frame"); DelThumb.Size=UDim2.new(0,13,0,13); DelThumb.AnchorPoint=Vector2.new(0.5,0.5)
DelThumb.BackgroundColor3=C.WHITE; DelThumb.Position=UDim2.new((State.rollDelay-0.1)/(3-0.1),0,0.5,0)
DelThumb.Parent=DelTrack; Corner(DelThumb,7)

local draggingDelay=false
local function UpdateDelaySlider(absX)
    local ap=DelTrack.AbsolutePosition.X; local as_=DelTrack.AbsoluteSize.X
    local pct=math.clamp((absX-ap)/as_,0,1)
    local val=math.floor((0.1+pct*(3-0.1))*10+0.5)/10
    State.rollDelay=val; DelVal.Text=string.format("%.1f",val)
    DelFill.Size=UDim2.new(pct,0,1,0); DelThumb.Position=UDim2.new(pct,0,0.5,0)
end
DelThumb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then draggingDelay=true end end)
DelThumb.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then draggingDelay=false end end)
DelTrack.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then UpdateDelaySlider(i.Position.X) end end)
UserInputService.InputChanged:Connect(function(i)
    if not draggingDelay then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then UpdateDelaySlider(i.Position.X) end
end)

-- ================================================
-- OPTIONS
-- ================================================
Gap(2); Section("Options")

-- Stop mode button
local smRow=Instance.new("Frame"); smRow.Size=UDim2.new(1,0,0,BH); smRow.BackgroundTransparency=1; smRow.Parent=Body
local smLbl=Lbl(smRow,"Mode: Exact rarity only",FMD,C.TEXT,FNR); smLbl.Size=UDim2.new(1,-60,1,0)
local smBtn=MkBtn(smRow,"Exact",C.ACCENT,function()
    if State.stopMode=="Exact" then
        State.stopMode="AtLeast"; smBtn.Text="AtLeast"
        smLbl.Text="Mode: Stop at rarity OR rarer"
        TweenService:Create(smBtn,TweenInfo.new(0.1),{BackgroundColor3=Color3.fromRGB(60,150,80)}):Play()
    else
        State.stopMode="Exact"; smBtn.Text="Exact"
        smLbl.Text="Mode: Exact rarity only"
        TweenService:Create(smBtn,TweenInfo.new(0.1),{BackgroundColor3=C.ACCENT}):Play()
    end
end)
smBtn.Size=UDim2.new(0,56,0,24); smBtn.Position=UDim2.new(1,-58,0.5,-12); smBtn.TextSize=FSM

ToggleRow(Body,"Use Remote (uncheck = button click)",State.useRemote,function(v) State.useRemote=v end)

-- ================================================
-- DETECTION LOGIC
-- ================================================

-- Read rarity from GUI text labels
local function DetectRarityFromGui()
    local found, foundRank = nil, 0
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextLabel") then
            local t = obj.Text:lower():match("^%s*(.-)%s*$")  -- trimmed
            for _, rar in ipairs(RARITIES) do
                if t == rar.name:lower() then
                    if rar.rank > foundRank then found=rar.name; foundRank=rar.rank end
                end
            end
        end
    end
    return found
end

-- Fire roll remote safely
local function FireRollRemote()
    if not RollRemote then RollRemote = FindRollRemote() end
    if not RollRemote then return false end
    local ok = pcall(function()
        if RollRemote:IsA("RemoteFunction") then
            RollRemote:InvokeServer()
        else
            RollRemote:FireServer()
        end
    end)
    if ok then StatMethod.Text = "Remote: "..RollRemote.Name end
    return ok
end

-- Find Roll button in UI and click it using VIM
local rollBtnRef = nil
local function FindRollButton()
    for _, obj in ipairs(PlayerGui:GetDescendants()) do
        if obj:IsA("TextButton") or obj:IsA("ImageButton") then
            local n = obj.Name:lower()
            local t = (obj:IsA("TextButton") and obj.Text:lower() or "")
            if (n:find("roll") or t == "roll" or t:find("^roll")) and obj.Visible and obj.AbsoluteSize.X > 20 then
                return obj
            end
        end
    end
    return nil
end

local function ClickRollButton()
    if not rollBtnRef or not rollBtnRef.Parent then
        rollBtnRef = FindRollButton()
    end
    if not rollBtnRef then return false end
    local ap = rollBtnRef.AbsolutePosition
    local as_ = rollBtnRef.AbsoluteSize
    local cx = math.floor(ap.X + as_.X / 2)
    local cy = math.floor(ap.Y + as_.Y / 2)
    -- FIXED: VIM is already a service variable, just call methods on it
    pcall(function()
        VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 1)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
    end)
    StatMethod.Text = "Button click"
    return true
end

-- Check if we should stop for a detected rarity
local function ShouldStop(rarName)
    if State.stopMode == "Exact" then
        return State.stopRarities[rarName] == true
    else
        -- AtLeast: stop if rarity >= lowest checked rank
        local minRank = 999
        for _, rar in ipairs(RARITIES) do
            if State.stopRarities[rar.name] then minRank=math.min(minRank,rar.rank) end
        end
        for _, rar in ipairs(RARITIES) do
            if rar.name==rarName then return rar.rank>=minRank end
        end
    end
    return false
end

-- ================================================
-- MAIN ROLL LOOP
-- ================================================
local function DoSingleRoll()
    -- Execute roll
    local ok = false
    if State.useRemote then ok = FireRollRemote() end
    if not ok then ok = ClickRollButton() end
    if not ok then StatMethod.Text = "⚠ Not found!" end

    State.rollsSinceStart += 1
    State.totalRolled += 1
    StatRolls.Text = tostring(State.rollsSinceStart)

    -- Wait for result to appear
    task.wait(math.max(State.rollDelay * 0.55, 0.2))

    local rarity = DetectRarityFromGui()
    if rarity then
        State.lastRarity = rarity
        StatRarity.Text = rarity
        for _, rar in ipairs(RARITIES) do
            if rar.name==rarity then StatRarity.TextColor3=rar.color; break end
        end
        return ShouldStop(rarity)
    end
    return false
end

-- ================================================
-- START / STOP BUTTON
-- ================================================
Gap(2)
local RollBtn = Instance.new("TextButton")
RollBtn.Size=UDim2.new(1,0,0,BH+4); RollBtn.BackgroundColor3=C.GREEN
RollBtn.Text="▶  Start Rolling"; RollBtn.TextSize=FLG; RollBtn.TextColor3=C.WHITE; RollBtn.Font=FN
RollBtn.AutoButtonColor=false; RollBtn.Parent=Body; Corner(RollBtn,7)

RollBtn.MouseButton1Click:Connect(function()
    if State.rolling then
        -- STOP
        State.rolling = false
        TweenService:Create(RollBtn,TweenInfo.new(0.15),{BackgroundColor3=C.GREEN}):Play()
        RollBtn.Text = "▶  Start Rolling"
        SetStatus("Stopped — "..State.rollsSinceStart.." rolls", C.SUB)
    else
        -- START
        State.rolling = true
        State.rollsSinceStart = 0
        rollBtnRef = nil  -- re-find button each session
        TweenService:Create(RollBtn,TweenInfo.new(0.15),{BackgroundColor3=C.RED}):Play()
        RollBtn.Text = "⏹  Stop Rolling"
        SetStatus("Rolling…", C.GREEN)

        task.spawn(function()
            while State.rolling do
                local shouldStop = false
                pcall(function() shouldStop = DoSingleRoll() end)
                if shouldStop then
                    State.rolling = false
                    TweenService:Create(RollBtn,TweenInfo.new(0.15),{BackgroundColor3=C.GREEN}):Play()
                    RollBtn.Text = "▶  Start Rolling"
                    SetStatus("🎉 Got "..State.lastRarity.."! Stopped at roll #"..State.rollsSinceStart, C.GREEN)
                    break
                end
                if State.rolling then task.wait(State.rollDelay) end
            end
        end)
    end
end)

-- Counter label
local TotalLbl=Lbl(Body,"Total rolls: 0",FSM,C.SUB,FNR,Enum.TextXAlignment.Center)
TotalLbl.Size=UDim2.new(1,0,0,14)
RunService.Heartbeat:Connect(function()
    if TotalLbl and TotalLbl.Parent then
        TotalLbl.Text="Total rolls this session: "..State.totalRolled
    end
end)

-- Init
SetStatus("Idle — pick rarities then Start", C.SUB)
StatMethod.Text = "Searching remote…"
print("[AutoRoll v2] Loaded — no errors")
