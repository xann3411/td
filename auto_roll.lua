-- ================================================
-- Auto Roll Script v3 — Random Anime Tower Defense
-- Full pcall safety on every service + operation
-- ================================================

-- Safe service getter — never errors
local function GetSvc(name)
    local ok, svc = pcall(function() return game:GetService(name) end)
    return ok and svc or nil
end

local Players           = GetSvc("Players")
local ReplicatedStorage = GetSvc("ReplicatedStorage")
local TweenService      = GetSvc("TweenService")
local UserInputService  = GetSvc("UserInputService")
local RunService        = GetSvc("RunService")
local VIM               = GetSvc("VirtualInputManager")

-- Guard: can't run without Players
if not Players then return end

local Player    = Players.LocalPlayer
local PlayerGui = Player and Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

local IsMobile = (UserInputService and UserInputService.TouchEnabled
    and not UserInputService.KeyboardEnabled) or false

-- ================================================
-- Rarity Config
-- ================================================
local RARITIES = {
    { name="Common",    color=Color3.fromRGB(180,180,180), rank=1 },
    { name="Rare",      color=Color3.fromRGB(80,140,255),  rank=2 },
    { name="Epic",      color=Color3.fromRGB(170,80,255),  rank=3 },
    { name="Legendary", color=Color3.fromRGB(255,180,30),  rank=4 },
    { name="Mythic",    color=Color3.fromRGB(255,70,70),   rank=5 },
    { name="Secret",    color=Color3.fromRGB(255,50,180),  rank=6 },
    { name="Limited",   color=Color3.fromRGB(50,220,120),  rank=7 },
}

-- ================================================
-- State
-- ================================================
local State = {
    rolling         = false,
    stopRarities    = {Common=false,Rare=false,Epic=false,Legendary=true,Mythic=true,Secret=true,Limited=true},
    rollDelay       = 0.5,
    rollsSinceStart = 0,
    totalRolled     = 0,
    lastRarity      = "",
    stopMode        = "Exact",
    useRemote       = true,
}

-- ================================================
-- Roll Remote — lazy-found, never errors
-- ================================================
local RollRemote = nil
local function FindRollRemote()
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        local paths = {
            {"Events","Roll"},{"Events","RollUnit"},{"Events","Gacha"},
            {"Events","Summon"},{"RemoteEvents","Roll"},{"RemoteEvents","Gacha"},
        }
        for _, path in ipairs(paths) do
            local cur = ReplicatedStorage
            for _, key in ipairs(path) do
                cur = cur:FindFirstChild(key)
                if not cur then break end
            end
            if cur and (cur:IsA("RemoteEvent") or cur:IsA("RemoteFunction")) then
                result = cur; return
            end
        end
        -- Deep fallback
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = d.Name:lower()
                if n:find("roll") or n:find("gacha") or n:find("summon") then
                    result = d; return
                end
            end
        end
    end)
    return result
end
task.spawn(function()
    task.wait(3)
    RollRemote = FindRollRemote()
    print("[AutoRoll] Remote:", RollRemote and RollRemote.Name or "not found")
end)

-- ================================================
-- GUI Colors + Sizes
-- ================================================
local C = {
    BG=Color3.fromRGB(18,18,24), PANEL=Color3.fromRGB(26,26,36),
    CARD=Color3.fromRGB(34,34,48), BORDER=Color3.fromRGB(50,50,70),
    TEXT=Color3.fromRGB(225,225,240), SUB=Color3.fromRGB(130,130,160),
    WHITE=Color3.fromRGB(255,255,255), GREEN=Color3.fromRGB(60,210,100),
    RED=Color3.fromRGB(220,60,60), ACCENT=Color3.fromRGB(90,90,140),
    TOG_ON=Color3.fromRGB(80,210,130), TOG_OFF=Color3.fromRGB(55,55,80),
}
local FN=Enum.Font.GothamBold; local FNR=Enum.Font.Gotham
local W=IsMobile and 340 or 380; local BH=IsMobile and 30 or 32
local FSM=IsMobile and 10 or 11; local FMD=IsMobile and 11 or 12; local FLG=IsMobile and 13 or 14

-- ================================================
-- GUI Helpers — all pcall-safe
-- ================================================
local function Corner(p,r)
    pcall(function() local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 6); c.Parent=p end)
end
local function Stroke(p,col)
    pcall(function() local s=Instance.new("UIStroke"); s.Color=col or C.BORDER; s.Thickness=1; s.Parent=p end)
end
local function Lbl(parent,txt,sz,col,font,xa)
    local l=Instance.new("TextLabel")
    l.Text=txt or ""; l.TextSize=sz or FMD; l.TextColor3=col or C.TEXT
    l.Font=font or FNR; l.BackgroundTransparency=1
    l.TextXAlignment=xa or Enum.TextXAlignment.Left
    l.Parent=parent; return l
end

local Tween = TweenService and function(obj,t,props)
    pcall(function() TweenService:Create(obj,TweenInfo.new(t),props):Play() end)
end or function() end

local function MkBtn(parent,txt,bg,cb)
    local b=Instance.new("TextButton")
    b.Text=txt; b.TextSize=FMD; b.TextColor3=C.WHITE; b.Font=FN
    b.BackgroundColor3=bg or C.ACCENT; b.AutoButtonColor=false; b.Parent=parent
    Corner(b,6)
    b.MouseButton1Click:Connect(function()
        local o=b.BackgroundColor3
        b.BackgroundColor3=Color3.fromRGB(math.min(o.R*255+20,255)/255,math.min(o.G*255+20,255)/255,math.min(o.B*255+20,255)/255)
        task.delay(0.1,function() if b and b.Parent then b.BackgroundColor3=o end end)
        pcall(cb)
    end)
    return b
end

local function MkToggle(parent,init,cb)
    local track=Instance.new("Frame")
    track.Size=UDim2.new(0,40,0,21); track.BackgroundColor3=init and C.TOG_ON or C.TOG_OFF
    track.Parent=parent; Corner(track,11)
    local thumb=Instance.new("Frame")
    thumb.Size=UDim2.new(0,15,0,15); thumb.BackgroundColor3=C.WHITE
    thumb.Position=init and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)
    thumb.Parent=track; Corner(thumb,8)
    local val=init
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0); btn.BackgroundTransparency=1; btn.Text=""; btn.Parent=track
    btn.MouseButton1Click:Connect(function()
        val=not val
        Tween(track,0.12,{BackgroundColor3=val and C.TOG_ON or C.TOG_OFF})
        Tween(thumb,0.12,{Position=val and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)})
        pcall(cb,val)
    end)
    return track, function(nv)
        val=nv; track.BackgroundColor3=nv and C.TOG_ON or C.TOG_OFF
        thumb.Position=nv and UDim2.new(1,-18,0.5,-7) or UDim2.new(0,3,0.5,-7)
    end
end

local function ToggleRow(parent,txt,init,cb)
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,BH); row.BackgroundTransparency=1; row.Parent=parent
    Lbl(row,txt,FMD,C.TEXT,FNR).Size=UDim2.new(1,-48,1,0)
    local tog,set=MkToggle(row,init,cb); tog.Position=UDim2.new(1,-44,0.5,-10)
    return row,set
end

local function Section(txt)
    local l=Lbl(Body,txt:upper(),FSM,C.SUB,FN); l.Size=UDim2.new(1,0,0,14); return l
end

-- ================================================
-- BUILD GUI
-- ================================================
pcall(function()
    local existing = PlayerGui:FindFirstChild("AutoRoll")
    if existing then existing:Destroy() end
end)

local SG=Instance.new("ScreenGui")
SG.Name="AutoRoll"; SG.ResetOnSpawn=false; SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; SG.Parent=PlayerGui

local Win=Instance.new("Frame")
Win.Size=UDim2.new(0,W,0,0); Win.AutomaticSize=Enum.AutomaticSize.Y
Win.Position=UDim2.new(0.04,0,0.08,0); Win.BackgroundColor3=C.BG
Win.Active=true; Win.Parent=SG; Corner(Win,10); Stroke(Win)

local WL=Instance.new("UIListLayout"); WL.SortOrder=Enum.SortOrder.LayoutOrder; WL.Padding=UDim.new(0,0); WL.Parent=Win

-- Shadow
local Shad=Instance.new("ImageLabel")
Shad.Size=UDim2.new(1,32,1,32); Shad.Position=UDim2.new(0,-16,0,-16)
Shad.BackgroundTransparency=1; Shad.Image="rbxassetid://6014261993"
Shad.ImageTransparency=0.55; Shad.ImageColor3=Color3.fromRGB(0,0,0)
Shad.ScaleType=Enum.ScaleType.Slice; Shad.SliceCenter=Rect.new(49,49,450,450)
Shad.ZIndex=0; Shad.Parent=Win

-- Header
local Hdr=Instance.new("Frame"); Hdr.Size=UDim2.new(1,0,0,38); Hdr.BackgroundColor3=C.PANEL; Hdr.LayoutOrder=0; Hdr.Parent=Win; Corner(Hdr,10)
local HFix=Instance.new("Frame"); HFix.Size=UDim2.new(1,0,0,10); HFix.Position=UDim2.new(0,0,1,-10); HFix.BackgroundColor3=C.PANEL; HFix.BorderSizePixel=0; HFix.Parent=Hdr
local HTit=Lbl(Hdr,"🎲 Auto Roll",FLG,C.WHITE,FN); HTit.Size=UDim2.new(0,160,1,0); HTit.Position=UDim2.new(0,12,0,0)
local HSub=Lbl(Hdr,"Stops on target rarity",FSM,C.SUB,FNR); HSub.Size=UDim2.new(0,180,1,0); HSub.Position=UDim2.new(0,168,0,0)
local XBtn=MkBtn(Hdr,"✕",Color3.fromRGB(180,50,50),function() pcall(function() SG:Destroy() end) end)
XBtn.Size=UDim2.new(0,26,0,22); XBtn.Position=UDim2.new(1,-30,0.5,-11)

-- Drag header
local drag,ds,dp=false,nil,nil
Hdr.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
        drag=true; ds=i.Position; dp=Win.Position
        i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then drag=false end end)
    end
end)
if UserInputService then
    UserInputService.InputChanged:Connect(function(i)
        if not drag then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
            local d=i.Position-ds; Win.Position=UDim2.new(dp.X.Scale,dp.X.Offset+d.X,dp.Y.Scale,dp.Y.Offset+d.Y)
        end
    end)
end

-- Body
Body=Instance.new("Frame")  -- intentional upvalue for Section()
Body.Size=UDim2.new(1,0,0,0); Body.AutomaticSize=Enum.AutomaticSize.Y
Body.BackgroundTransparency=1; Body.LayoutOrder=1; Body.Parent=Win
local BL=Instance.new("UIListLayout"); BL.SortOrder=Enum.SortOrder.LayoutOrder; BL.Padding=UDim.new(0,6); BL.Parent=Body
local BP=Instance.new("UIPadding"); BP.PaddingLeft=UDim.new(0,8); BP.PaddingRight=UDim.new(0,8); BP.PaddingTop=UDim.new(0,8); BP.PaddingBottom=UDim.new(0,10); BP.Parent=Body

local function Gap(h) local f=Instance.new("Frame"); f.Size=UDim2.new(1,0,0,h or 2); f.BackgroundTransparency=1; f.Parent=Body end

-- ================================================
-- STATUS CARD
-- ================================================
Section("Status")
local SC=Instance.new("Frame"); SC.Size=UDim2.new(1,0,0,0); SC.AutomaticSize=Enum.AutomaticSize.Y; SC.BackgroundColor3=C.CARD; SC.Parent=Body; Corner(SC,7)
local SCL=Instance.new("UIListLayout"); SCL.SortOrder=Enum.SortOrder.LayoutOrder; SCL.Padding=UDim.new(0,3); SCL.Parent=SC
local SCP=Instance.new("UIPadding"); SCP.PaddingLeft=UDim.new(0,8); SCP.PaddingRight=UDim.new(0,8); SCP.PaddingTop=UDim.new(0,6); SCP.PaddingBottom=UDim.new(0,6); SCP.Parent=SC

local StatusLbl=Lbl(SC,"● Idle",FMD,C.SUB,FN); StatusLbl.Size=UDim2.new(1,0,0,20)
local function SRow(k)
    local r=Instance.new("Frame"); r.Size=UDim2.new(1,0,0,18); r.BackgroundTransparency=1; r.Parent=SC
    Lbl(r,k,FSM,C.SUB,FNR).Size=UDim2.new(0.52,0,1,0)
    local v=Lbl(r,"—",FSM,C.WHITE,FN,Enum.TextXAlignment.Right); v.Size=UDim2.new(0.48,0,1,0)
    return v
end
local SRolls  = SRow("Rolls this session:")
local SRarity = SRow("Last rarity:")
local SMethod = SRow("Roll method:")

local function SetStatus(txt,col)
    if StatusLbl and StatusLbl.Parent then StatusLbl.Text="● "..txt; StatusLbl.TextColor3=col or C.SUB end
end

-- ================================================
-- RARITY CHIPS
-- ================================================
Gap(2); Section("Stop when I get...")
local RF=Instance.new("Frame"); RF.Size=UDim2.new(1,0,0,0); RF.AutomaticSize=Enum.AutomaticSize.Y; RF.BackgroundColor3=C.CARD; RF.Parent=Body; Corner(RF,7)
local RFL=Instance.new("UIListLayout"); RFL.FillDirection=Enum.FillDirection.Horizontal; RFL.Wraps=true; RFL.Padding=UDim.new(0,4); RFL.Parent=RF
local RFP=Instance.new("UIPadding"); RFP.PaddingLeft=UDim.new(0,6); RFP.PaddingRight=UDim.new(0,6); RFP.PaddingTop=UDim.new(0,6); RFP.PaddingBottom=UDim.new(0,6); RFP.Parent=RF

local rarSetters={}
local chipW=math.floor((W-36)/2)-4
for _,rar in ipairs(RARITIES) do
    local on=State.stopRarities[rar.name]
    local chip=Instance.new("TextButton"); chip.Size=UDim2.new(0,chipW,0,BH-4); chip.BackgroundColor3=on and rar.color or C.PANEL; chip.Text=""; chip.AutoButtonColor=false; chip.Parent=RF; Corner(chip,6)
    local strk=Instance.new("UIStroke"); strk.Color=on and rar.color or C.BORDER; strk.Thickness=1; strk.Parent=chip
    local tic=Lbl(chip,on and "✓" or "○",FSM,on and C.WHITE or C.SUB,FN,Enum.TextXAlignment.Center); tic.Size=UDim2.new(0,18,1,0)
    local cL=Lbl(chip,rar.name,FSM,on and C.WHITE or C.SUB,FN); cL.Size=UDim2.new(1,-20,1,0); cL.Position=UDim2.new(0,20,0,0)
    local function setC(v)
        State.stopRarities[rar.name]=v
        Tween(chip,0.1,{BackgroundColor3=v and rar.color or C.PANEL})
        strk.Color=v and rar.color or C.BORDER; tic.Text=v and "✓" or "○"
        tic.TextColor3=v and C.WHITE or C.SUB; cL.TextColor3=v and C.WHITE or C.SUB
    end
    chip.MouseButton1Click:Connect(function() setC(not State.stopRarities[rar.name]) end)
    rarSetters[rar.name]=setC
end

-- Presets
local PR=Instance.new("Frame"); PR.Size=UDim2.new(1,0,0,BH); PR.BackgroundTransparency=1; PR.Parent=Body
local PRL=Instance.new("UIListLayout"); PRL.FillDirection=Enum.FillDirection.Horizontal; PRL.Padding=UDim.new(0,4); PRL.Parent=PR
local pBtnW=math.floor((W-36)/4)-2
local function PBtn(txt,bg,list)
    local b=MkBtn(PR,txt,bg,function()
        for _,r in ipairs(RARITIES) do rarSetters[r.name](false) end
        for _,n in ipairs(list) do if rarSetters[n] then rarSetters[n](true) end end
    end); b.Size=UDim2.new(0,pBtnW,1,0); b.TextSize=FSM
end
PBtn("Epic+",  Color3.fromRGB(130,60,200), {"Epic","Legendary","Mythic","Secret","Limited"})
PBtn("Lgnd+",  Color3.fromRGB(200,140,20), {"Legendary","Mythic","Secret","Limited"})
PBtn("Myth+",  Color3.fromRGB(200,50,50),  {"Mythic","Secret","Limited"})
PBtn("Secrt+", Color3.fromRGB(200,40,150), {"Secret","Limited"})

-- ================================================
-- DELAY SLIDER
-- ================================================
Gap(2); Section("Roll Delay")
local DR=Instance.new("Frame"); DR.Size=UDim2.new(1,0,0,BH+6); DR.BackgroundTransparency=1; DR.Parent=Body
Lbl(DR,"Roll Delay (s)",FMD,C.TEXT,FNR).Size=UDim2.new(0.6,0,0,14)
local DV=Lbl(DR,tostring(State.rollDelay),FMD,Color3.fromRGB(120,140,255),FN,Enum.TextXAlignment.Right); DV.Size=UDim2.new(0.4,0,0,14)
local DT=Instance.new("Frame"); DT.Size=UDim2.new(1,0,0,5); DT.Position=UDim2.new(0,0,0,20); DT.BackgroundColor3=C.CARD; DT.BorderSizePixel=0; DT.Parent=DR; Corner(DT,3)
local DF=Instance.new("Frame"); DF.Size=UDim2.new((State.rollDelay-0.1)/(2.9),0,1,0); DF.BackgroundColor3=Color3.fromRGB(90,100,220); DF.BorderSizePixel=0; DF.Parent=DT; Corner(DF,3)
local DTh=Instance.new("Frame"); DTh.Size=UDim2.new(0,13,0,13); DTh.AnchorPoint=Vector2.new(0.5,0.5); DTh.BackgroundColor3=C.WHITE; DTh.Position=UDim2.new((State.rollDelay-0.1)/2.9,0,0.5,0); DTh.Parent=DT; Corner(DTh,7)
local dragD=false
local function UpdD(ax) local ap=DT.AbsolutePosition.X; local as=DT.AbsoluteSize.X; if as==0 then return end
    local p=math.clamp((ax-ap)/as,0,1); local v=math.floor((0.1+p*2.9)*10+0.5)/10
    State.rollDelay=v; DV.Text=string.format("%.1f",v); DF.Size=UDim2.new(p,0,1,0); DTh.Position=UDim2.new(p,0,0.5,0)
end
DTh.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragD=true end end)
DTh.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then dragD=false end end)
DT.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then UpdD(i.Position.X) end end)
if UserInputService then
    UserInputService.InputChanged:Connect(function(i)
        if not dragD then return end
        if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then UpdD(i.Position.X) end
    end)
end

-- ================================================
-- OPTIONS
-- ================================================
Gap(2); Section("Options")

-- Stop mode
local smR=Instance.new("Frame"); smR.Size=UDim2.new(1,0,0,BH); smR.BackgroundTransparency=1; smR.Parent=Body
local smL=Lbl(smR,"Mode: Exact rarity only",FMD,C.TEXT,FNR); smL.Size=UDim2.new(1,-60,1,0)
local smB=MkBtn(smR,"Exact",C.ACCENT,function()
    if State.stopMode=="Exact" then State.stopMode="AtLeast"; smB.Text="AtLeast"; smL.Text="Mode: OR rarer (AtLeast)"; Tween(smB,0.1,{BackgroundColor3=Color3.fromRGB(60,150,80)})
    else State.stopMode="Exact"; smB.Text="Exact"; smL.Text="Mode: Exact rarity only"; Tween(smB,0.1,{BackgroundColor3=C.ACCENT}) end
end); smB.Size=UDim2.new(0,56,0,24); smB.Position=UDim2.new(1,-58,0.5,-12); smB.TextSize=FSM

ToggleRow(Body,"Use Remote (uncheck = button click)",State.useRemote,function(v) State.useRemote=v end)

-- ================================================
-- ROLL LOGIC — all pcall wrapped
-- ================================================
local function DetectRarity()
    local found,foundRank=nil,0
    pcall(function()
        for _,obj in ipairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local t=obj.Text:match("^%s*(.-)%s*$"):lower()
                for _,rar in ipairs(RARITIES) do
                    if t==rar.name:lower() and rar.rank>foundRank then found=rar.name; foundRank=rar.rank end
                end
            end
        end
    end)
    return found
end

local function FireRemote()
    if not State.useRemote then return false end
    if not RollRemote then RollRemote=FindRollRemote() end
    if not RollRemote then return false end
    local ok=pcall(function()
        if RollRemote:IsA("RemoteFunction") then RollRemote:InvokeServer()
        else RollRemote:FireServer() end
    end)
    if ok and SMethod and SMethod.Parent then SMethod.Text="Remote: "..RollRemote.Name end
    return ok
end

local rollBtnRef=nil
local function ClickBtn()
    if not rollBtnRef or not rollBtnRef.Parent then
        pcall(function()
            for _,obj in ipairs(PlayerGui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local n=obj.Name:lower()
                    local t=obj:IsA("TextButton") and obj.Text:lower() or ""
                    if (n:find("roll") or t=="roll" or t:find("^roll")) and obj.AbsoluteSize.X>20 then rollBtnRef=obj; break end
                end
            end
        end)
    end
    if not rollBtnRef then return false end
    local ok=pcall(function()
        -- Method 1: VIM click
        if VIM then
            local ap=rollBtnRef.AbsolutePosition; local as=rollBtnRef.AbsoluteSize
            local cx=math.floor(ap.X+as.X/2); local cy=math.floor(ap.Y+as.Y/2)
            VIM:SendMouseButtonEvent(cx,cy,0,true,game,1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(cx,cy,0,false,game,1)
        else
            -- Method 2: fire MouseButton1Click directly
            rollBtnRef.MouseButton1Click:Fire()
        end
    end)
    if SMethod and SMethod.Parent then SMethod.Text=ok and "Button click" or "Click failed" end
    return ok
end

local function ShouldStop(name)
    if State.stopMode=="Exact" then return State.stopRarities[name]==true end
    local min=999
    for _,r in ipairs(RARITIES) do if State.stopRarities[r.name] then min=math.min(min,r.rank) end end
    for _,r in ipairs(RARITIES) do if r.name==name then return r.rank>=min end end
    return false
end

local function DoRoll()
    local ok=FireRemote()
    if not ok then ok=ClickBtn() end
    State.rollsSinceStart+=1; State.totalRolled+=1
    if SRolls and SRolls.Parent then SRolls.Text=tostring(State.rollsSinceStart) end
    task.wait(math.max(State.rollDelay*0.5,0.15))
    local rar=DetectRarity()
    if rar then
        State.lastRarity=rar
        if SRarity and SRarity.Parent then
            SRarity.Text=rar
            for _,r in ipairs(RARITIES) do if r.name==rar then SRarity.TextColor3=r.color; break end end
        end
        return ShouldStop(rar)
    end
    return false
end

-- ================================================
-- START / STOP BUTTON
-- ================================================
Gap(2)
local RB=Instance.new("TextButton")
RB.Size=UDim2.new(1,0,0,BH+4); RB.BackgroundColor3=C.GREEN; RB.Text="▶  Start Rolling"
RB.TextSize=FLG; RB.TextColor3=C.WHITE; RB.Font=FN; RB.AutoButtonColor=false; RB.Parent=Body; Corner(RB,7)

RB.MouseButton1Click:Connect(function()
    if State.rolling then
        State.rolling=false
        Tween(RB,0.15,{BackgroundColor3=C.GREEN}); RB.Text="▶  Start Rolling"
        SetStatus("Stopped — "..State.rollsSinceStart.." rolls",C.SUB)
    else
        State.rolling=true; State.rollsSinceStart=0; rollBtnRef=nil
        Tween(RB,0.15,{BackgroundColor3=C.RED}); RB.Text="⏹  Stop Rolling"
        SetStatus("Rolling…",C.GREEN)
        task.spawn(function()
            while State.rolling do
                local stop=false
                pcall(function() stop=DoRoll() end)
                if stop then
                    State.rolling=false
                    Tween(RB,0.15,{BackgroundColor3=C.GREEN}); RB.Text="▶  Start Rolling"
                    SetStatus("🎉 Got "..State.lastRarity.."! (#"..State.rollsSinceStart..")",C.GREEN)
                    break
                end
                if State.rolling then task.wait(State.rollDelay) end
            end
        end)
    end
end)

-- Total counter
local TL=Lbl(Body,"Total rolls: 0",FSM,C.SUB,FNR,Enum.TextXAlignment.Center); TL.Size=UDim2.new(1,0,0,14)
if RunService then
    RunService.Heartbeat:Connect(function()
        if TL and TL.Parent then TL.Text="Total rolls this session: "..State.totalRolled end
    end)
end

SetStatus("Ready — pick rarities and tap Start",C.SUB)
SMethod.Text="Searching remote…"
print("[AutoRoll v3] Loaded clean")
