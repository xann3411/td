-- ================================================
-- Auto Roll v14 — Random Anime Tower Defense
-- Remote: hookmetamethod with strict filtering
-- Rarity: reads the NEW unit card that appears after rolling
-- Hold fix: fires remote twice with 0.15s gap to simulate button hold
-- ================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function GetSvc(n)
    local ok,s = pcall(function() return game:GetService(n) end)
    return ok and s or nil
end

local Players           = GetSvc("Players")
local ReplicatedStorage = GetSvc("ReplicatedStorage")

if not Players then return end
local Player    = Players.LocalPlayer
local PlayerGui = Player and Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

-- ================================================
-- State
-- ================================================
local State = {
    rolling         = false,
    rollDelay       = 0.65,
    rollsSinceStart = 0,
    lastRarity      = "—",
    stopMode        = "AtLeast",
    stopRarities    = {
        Common=false, Rare=false, Epic=false,
        Legendary=true, Mythic=true, Secret=true, Limited=true
    },
}

local RARITIES = {
    {name="Common",rank=1},{name="Rare",rank=2},{name="Epic",rank=3},
    {name="Legendary",rank=4},{name="Mythic",rank=5},{name="Secret",rank=6},{name="Limited",rank=7},
}
local RARITY_SET = {}
for _,r in ipairs(RARITIES) do RARITY_SET[r.name:lower()] = r end

-- ================================================
-- Remote capture — hookmetamethod, strict name check
-- Only accepts remotes whose name strongly suggests rolling
-- ================================================
local RollRemote  = nil
local MethodLabel = nil  -- set after UI

-- These words MUST appear in the remote name
local MUST_HAVE = {"roll","gacha","summon","pull","reroll"}
-- These words disqualify a remote immediately
local BLACKLIST  = {
    "kill","damage","wave","enemy","spawn","move","attack","buy",
    "upgrade","sell","place","remove","delete","chat","message",
    "join","leave","report","vote","ready","start","stop","skip",
    "quest","mission","event","daily","reward","claim",
}

local function isRollRemote(name)
    local n = name:lower()
    for _, bad in ipairs(BLACKLIST) do
        if n:find(bad) then return false end
    end
    for _, good in ipairs(MUST_HAVE) do
        if n:find(good) then return true end
    end
    return false
end

local hooked    = false
local capturing = false

local function StartCapturing()
    capturing = true
    if hooked then return end
    hooked = true
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if capturing and not RollRemote then
                if method == "FireServer" or method == "InvokeServer" then
                    if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                        if isRollRemote(self.Name) then
                            RollRemote = self
                            capturing  = false
                            print("[AutoRoll] Captured:", self.Name)
                            pcall(function()
                                MethodLabel:Set("Remote: " .. self.Name .. " ✅")
                                Rayfield:Notify({
                                    Title   = "Remote Captured! ✅",
                                    Content = self.Name .. " — you can now roll from anywhere!",
                                    Duration = 5, Image = "check",
                                })
                            end)
                        end
                    end
                end
            end
            return old(self, ...)
        end)
        setreadonly(mt, true)
    end)
    if not ok then
        print("[AutoRoll] hookmetamethod failed — try Scan instead")
    end
end

local function ScanForRemote()
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and isRollRemote(d.Name) then
                result = d; return
            end
        end
    end)
    return result
end

task.spawn(function()
    task.wait(2)
    RollRemote = ScanForRemote()
    if RollRemote then
        print("[AutoRoll] Remote found via scan:", RollRemote.Name)
        pcall(function() MethodLabel:Set("Remote: " .. RollRemote.Name .. " ✅") end)
    else
        -- Auto-listen from the start so any manual roll captures it
        StartCapturing()
        print("[AutoRoll] Listening — press Roll once manually to capture remote")
        pcall(function() MethodLabel:Set("Remote: not found — press Roll once to capture") end)
    end
end)

-- ================================================
-- Fire the remote
-- Simulates a hold: fires once, waits 0.15s, fires again
-- to satisfy games that require a brief hold on the roll button
-- ================================================
local function FireRemote()
    if not RollRemote then return false end
    local ok = pcall(function()
        if RollRemote:IsA("RemoteFunction") then
            RollRemote:InvokeServer()
            task.wait(0.15)
            RollRemote:InvokeServer()
        else
            RollRemote:FireServer()
            task.wait(0.15)
            RollRemote:FireServer()
        end
    end)
    return ok
end

-- ================================================
-- Rarity detection — reads BillboardGui labels floating above units
-- in workspace (e.g. "Legendary" shown above Kakashi, Luffy, etc.)
-- Snapshots ALL rarity labels BEFORE roll, detects NEW ones after.
-- ================================================

-- Scan workspace BillboardGuis for rarity TextLabels
local function GetWorldRarities()
    local results = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not obj:IsA("TextLabel") then continue end
            local t = obj.Text:match("^%s*(.-)%s*$")
            if not t or #t == 0 or #t > 12 then continue end
            if t:find("[^%a%s%-]") then continue end
            local tl = t:lower():match("^%s*(.-)%s*$")
            if not RARITY_SET[tl] then continue end
            results[obj] = tl
        end
    end)
    return results
end

-- Also scan PlayerGui as fallback
local function GetGuiRarities()
    local results = {}
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not obj:IsA("TextLabel") then continue end
            local t = obj.Text:match("^%s*(.-)%s*$")
            if not t or #t == 0 or #t > 12 then continue end
            if t:find("[^%a%s%-]") then continue end
            local tl = t:lower():match("^%s*(.-)%s*$")
            if not RARITY_SET[tl] then continue end
            results[obj] = tl
        end
    end)
    return results
end

local function GetAllRarities()
    local m = GetWorldRarities()
    for k,v in pairs(GetGuiRarities()) do m[k]=v end
    return m
end

local function HighestRarity(tray)
    local found, rank = nil, 0
    for _, tl in pairs(tray) do
        local r = RARITY_SET[tl]
        if r and r.rank > rank then found = r.name; rank = r.rank end
    end
    return found
end

local function DetectNewRarity(before)
    local after = GetAllRarities()
    -- First: look for brand-new rarity labels not in the before snapshot
    local found, foundRank = nil, 0
    for obj, tl in pairs(after) do
        if not before[obj] then
            local r = RARITY_SET[tl]
            if r and r.rank > foundRank then found = r.name; foundRank = r.rank end
        end
    end
    -- Fallback: highest rarity visible anywhere on screen/world
    if not found then
        found = HighestRarity(after)
    end
    return found
end

local function ShouldStop(name)
    if not name then return false end
    if State.stopMode == "Exact" then return State.stopRarities[name] == true end
    local min = 999
    for _, r in ipairs(RARITIES) do if State.stopRarities[r.name] then min = math.min(min, r.rank) end end
    for _, r in ipairs(RARITIES) do if r.name == name then return r.rank >= min end end
    return false
end

-- ================================================
-- One roll cycle
-- ================================================
local function DoRoll()
    local before = GetAllRarities()

    local fired = FireRemote()
    if not fired then
        print("[AutoRoll] Remote not ready")
        return false
    end

    State.rollsSinceStart += 1

    -- Wait for animation + new card to appear (longer to account for hold + animation)
    task.wait(math.max(State.rollDelay * 0.7, 0.6))

    local rar = nil
    for _ = 1, 10 do
        rar = DetectNewRarity(before)
        if rar then break end
        task.wait(0.2)
    end

    if rar then
        State.lastRarity = rar
        return ShouldStop(rar)
    end
    return false
end

-- ================================================
-- RAYFIELD UI
-- ================================================
local Window = Rayfield:CreateWindow({
    Name            = "🎲 Auto Roll",
    Icon            = "dices",
    LoadingTitle    = "Auto Roll",
    LoadingSubtitle = "Random Anime Tower Defense",
    ShowText        = "Auto Roll",
    Theme           = "Default",
    DisableBuildWarnings = true,
    ConfigurationSaving = { Enabled=true, FolderName="AutoRoll", FileName="AutoRollConfig" },
    Discord         = { Enabled=false, Invite="", RememberJoins=false },
    KeySystem       = false,
})

-- Roll Control tab
local MainTab = Window:CreateTab("Roll Control", "play")
MainTab:CreateSection("Status")
local StatusLabel = MainTab:CreateLabel("● Idle — capture remote then press Start")
local RollsLabel  = MainTab:CreateLabel("Rolls this session: 0")
local RarityLabel = MainTab:CreateLabel("Last rarity: —")
MethodLabel       = MainTab:CreateLabel("Remote: scanning…")

MainTab:CreateDivider()
MainTab:CreateSection("Controls")

local rolling = false
local StartBtn
StartBtn = MainTab:CreateButton({
    Name = "▶  Start Rolling",
    Callback = function()
        if rolling then
            rolling = false; State.rolling = false
            StartBtn:Set("▶  Start Rolling")
            StatusLabel:Set("● Stopped — " .. State.rollsSinceStart .. " rolls")
        else
            if not RollRemote then
                Rayfield:Notify({
                    Title="No Remote",
                    Content="Tap 'Capture Remote' then press Roll once manually first.",
                    Duration=5, Image="alert-triangle"
                })
                return
            end
            rolling = true; State.rolling = true; State.rollsSinceStart = 0
            StartBtn:Set("⏹  Stop Rolling")
            StatusLabel:Set("● Rolling…")
            task.spawn(function()
                while State.rolling do
                    local stop = false
                    pcall(function() stop = DoRoll() end)
                    RollsLabel:Set("Rolls this session: " .. State.rollsSinceStart)
                    RarityLabel:Set("Last rarity: " .. State.lastRarity)
                    if stop then
                        State.rolling = false; rolling = false
                        StartBtn:Set("▶  Start Rolling")
                        StatusLabel:Set("🎉 Got " .. State.lastRarity .. "! (#" .. State.rollsSinceStart .. ")")
                        Rayfield:Notify({
                            Title="Target Hit! 🎉",
                            Content="Got "..State.lastRarity.." after "..State.rollsSinceStart.." rolls",
                            Duration=8, Image="trophy"
                        })
                        break
                    end
                    if State.rolling then task.wait(State.rollDelay) end
                end
            end)
        end
    end,
})

MainTab:CreateDivider()
MainTab:CreateSection("Setup — do this first")

MainTab:CreateButton({
    Name = "📡 Capture Remote",
    Callback = function()
        if RollRemote then
            Rayfield:Notify({ Title="Already Captured ✅", Content=RollRemote.Name, Duration=3, Image="check" })
            return
        end
        -- Try scan first
        RollRemote = ScanForRemote()
        if RollRemote then
            MethodLabel:Set("Remote: " .. RollRemote.Name .. " ✅")
            Rayfield:Notify({ Title="Found! ✅", Content=RollRemote.Name, Duration=4, Image="check" })
            return
        end
        -- Start listening
        StartCapturing()
        MethodLabel:Set("Listening… walk to pedestal and press Roll once now!")
        Rayfield:Notify({
            Title="Listening…",
            Content="Walk to the ROLL pedestal and press it once. Remote will auto-capture.",
            Duration=7, Image="radio"
        })
        task.spawn(function()
            for _ = 1, 40 do
                task.wait(0.5)
                if RollRemote then return end
            end
            if not RollRemote then
                capturing = false
                MethodLabel:Set("Timed out — try again")
                Rayfield:Notify({ Title="Timed Out", Content="Didn't catch it. Try again.", Duration=4, Image="alert-triangle" })
            end
        end)
    end,
})

MainTab:CreateButton({
    Name = "🔄 Reset & Re-capture",
    Callback = function()
        RollRemote = nil; capturing = false
        MethodLabel:Set("Remote cleared")
        Rayfield:Notify({ Title="Reset", Content="Remote cleared. Tap Capture Remote again.", Duration=3, Image="rotate-ccw" })
    end,
})

-- Settings tab
local SettingsTab = Window:CreateTab("Settings", "settings")
SettingsTab:CreateSection("Stop Rarities")
for _, rar in ipairs(RARITIES) do
    local name = rar.name
    SettingsTab:CreateToggle({
        Name="Stop on "..name, CurrentValue=State.stopRarities[name],
        Flag="StopOn"..name,
        Callback=function(v) State.stopRarities[name]=v end,
    })
end
SettingsTab:CreateDivider()
SettingsTab:CreateSection("Stop Mode")
SettingsTab:CreateDropdown({
    Name="Mode", Options={"AtLeast (rarity or better)","Exact (only that rarity)"},
    CurrentOption={"AtLeast (rarity or better)"}, MultipleOptions=false, Flag="StopMode",
    Callback=function(o) State.stopMode=tostring(o[1] or o):find("Exact") and "Exact" or "AtLeast" end,
})
SettingsTab:CreateDivider()
SettingsTab:CreateSection("Timing")
SettingsTab:CreateSlider({
    Name="Roll Delay (s)", Range={0.3,3.0}, Increment=0.05, Suffix="s",
    CurrentValue=State.rollDelay, Flag="RollDelay",
    Callback=function(v) State.rollDelay=v end,
})

-- Presets tab
local PresetsTab = Window:CreateTab("Presets", "zap")
PresetsTab:CreateSection("Quick Stop Presets")
local function Preset(list)
    for _,r in ipairs(RARITIES) do State.stopRarities[r.name]=false end
    for _,n in ipairs(list) do State.stopRarities[n]=true end
    Rayfield:Notify({ Title="Preset Applied", Content=table.concat(list,", "), Duration=3, Image="check" })
end
PresetsTab:CreateButton({ Name="Epic+",      Callback=function() Preset({"Epic","Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name="Legendary+", Callback=function() Preset({"Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name="Mythic+",    Callback=function() Preset({"Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name="Secret+",    Callback=function() Preset({"Secret","Limited"}) end })

Rayfield:LoadConfiguration()
print("[AutoRoll v14] Loaded")
