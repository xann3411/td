-- ================================================
-- Auto Roll v15 — Random Anime Tower Defense
-- v15: Catch-all remote logger + manual remote picker
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
-- Remote
-- ================================================
local RollRemote   = nil
local MethodLabel  = nil
local DebugLabel   = nil
local LastFiredLog = {}  -- stores last 5 fired remote names

-- Catch-all hook: logs EVERY remote that fires, no filter
-- Also captures the one that fires right after pressing Roll manually
local hooked         = false
local catchAllMode   = false  -- when true: next FireServer sets RollRemote
local catchAllTarget = nil    -- name chosen by user from log

local function HookAll()
    if hooked then return end
    hooked = true
    pcall(function()
        local mt  = getrawmetatable(game)
        local old = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" or method == "InvokeServer" then
                if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                    local name = self.Name

                    -- Always log to debug list
                    table.insert(LastFiredLog, 1, name)
                    if #LastFiredLog > 8 then table.remove(LastFiredLog) end
                    pcall(function()
                        if DebugLabel then
                            DebugLabel:Set("Last fired: " .. table.concat(LastFiredLog, ", "))
                        end
                    end)

                    -- CatchAll mode: first fire after button press = our remote
                    if catchAllMode and not RollRemote then
                        if catchAllTarget == nil or name == catchAllTarget then
                            RollRemote    = self
                            catchAllMode  = false
                            print("[AutoRoll] Caught remote:", name)
                            pcall(function()
                                MethodLabel:Set("Remote: " .. name .. " ✅")
                                Rayfield:Notify({
                                    Title   = "Remote Captured! ✅",
                                    Content = name,
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
end

-- Scan ReplicatedStorage and return all remote names
local function GetAllRemoteNames()
    local names = {}
    if not ReplicatedStorage then return names end
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                table.insert(names, d.Name)
            end
        end
    end)
    return names
end

local function FindRemoteByName(name)
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name == name then
                result = d; return
            end
        end
    end)
    return result
end

-- Start the hook immediately so we log everything from the start
task.spawn(function()
    task.wait(1)
    HookAll()
    print("[AutoRoll] Hook active — all remotes being logged")
end)

-- ================================================
-- Fire the remote
-- ================================================
local function FireRemote()
    if not RollRemote then return false end
    local ok = pcall(function()
        if RollRemote:IsA("RemoteFunction") then
            RollRemote:InvokeServer()
        else
            RollRemote:FireServer()
        end
    end)
    return ok
end

-- ================================================
-- Rarity detection — reads BillboardGui labels above units in workspace
-- ================================================
local function GetAllRarities()
    local results = {}
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not obj:IsA("TextLabel") then continue end
            local t = obj.Text:match("^%s*(.-)%s*$")
            if not t or #t == 0 or #t > 15 then continue end
            local tl = t:lower():match("^%s*(.-)%s*$")
            if RARITY_SET[tl] then results[obj] = tl end
        end
    end)
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not obj:IsA("TextLabel") then continue end
            local t = obj.Text:match("^%s*(.-)%s*$")
            if not t or #t == 0 or #t > 15 then continue end
            local tl = t:lower():match("^%s*(.-)%s*$")
            if RARITY_SET[tl] then results[obj] = tl end
        end
    end)
    return results
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
    local found, foundRank = nil, 0
    for obj, tl in pairs(after) do
        if not before[obj] then
            local r = RARITY_SET[tl]
            if r and r.rank > foundRank then found = r.name; foundRank = r.rank end
        end
    end
    if not found then found = HighestRarity(after) end
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
    local fired  = FireRemote()
    if not fired then
        print("[AutoRoll] Remote not ready")
        return false
    end
    State.rollsSinceStart += 1
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

-- ── Roll Control tab ──────────────────────────────
local MainTab = Window:CreateTab("Roll Control", "play")
MainTab:CreateSection("Status")
local StatusLabel = MainTab:CreateLabel("● Idle")
local RollsLabel  = MainTab:CreateLabel("Rolls this session: 0")
local RarityLabel = MainTab:CreateLabel("Last rarity: —")
MethodLabel       = MainTab:CreateLabel("Remote: not set — use Debug tab")

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
                    Title="No Remote Set",
                    Content="Go to Debug tab → scan remotes → pick the roll one, then come back.",
                    Duration=6, Image="alert-triangle"
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

-- ── Debug tab ────────────────────────────────────
local DebugTab = Window:CreateTab("Debug / Remote", "search")
DebugTab:CreateSection("Step 1 — Scan ReplicatedStorage")
DebugTab:CreateLabel("Lists every remote in the game")

local ScanResultLabel = DebugTab:CreateLabel("Press Scan to see all remotes")
DebugTab:CreateButton({
    Name = "🔍 Scan All Remotes",
    Callback = function()
        local names = GetAllRemoteNames()
        if #names == 0 then
            ScanResultLabel:Set("None found in ReplicatedStorage")
            Rayfield:Notify({ Title="Scan Result", Content="No remotes found. Try Step 2 instead.", Duration=5, Image="alert-triangle" })
            return
        end
        local out = table.concat(names, " | ")
        ScanResultLabel:Set(out)
        -- Also print to console for full list
        print("[AutoRoll] All remotes in ReplicatedStorage:")
        for i, n in ipairs(names) do print("  " .. i .. ". " .. n) end
        Rayfield:Notify({
            Title = #names .. " Remotes Found",
            Content = "See label below. Pick one with 'Set Remote By Name'.",
            Duration = 6, Image = "list"
        })
    end,
})

DebugTab:CreateDivider()
DebugTab:CreateSection("Step 2 — Live Fire Logger")
DebugTab:CreateLabel("Press Roll manually — watch what fires here")
DebugLabel = DebugTab:CreateLabel("Last fired: (none yet)")

DebugTab:CreateButton({
    Name = "🟢 CatchAll Mode — press Roll now",
    Callback = function()
        RollRemote   = nil
        catchAllMode = true
        catchAllTarget = nil
        MethodLabel:Set("Remote: waiting for Roll press…")
        Rayfield:Notify({
            Title = "CatchAll Active",
            Content = "Now press the Roll button in-game. First remote that fires = captured.",
            Duration = 7, Image = "radio"
        })
        task.spawn(function()
            for _ = 1, 60 do
                task.wait(0.5)
                if RollRemote then return end
            end
            if not RollRemote then
                catchAllMode = false
                Rayfield:Notify({ Title="Timed Out", Content="Nothing fired. Try again.", Duration=4, Image="alert-triangle" })
            end
        end)
    end,
})

DebugTab:CreateDivider()
DebugTab:CreateSection("Step 3 — Set Remote Manually By Name")
DebugTab:CreateLabel("Type exact remote name from the scan list")
DebugTab:CreateInput({
    Name        = "Remote Name",
    PlaceholderText = "e.g. Roll, Spin, DrawUnit…",
    RemoveTextAfterFocusLost = false,
    Callback    = function(txt)
        if not txt or txt == "" then return end
        local found = FindRemoteByName(txt)
        if found then
            RollRemote = found
            MethodLabel:Set("Remote: " .. txt .. " ✅")
            Rayfield:Notify({ Title="Set! ✅", Content=txt, Duration=4, Image="check" })
        else
            -- Store name for CatchAll to match against
            catchAllTarget = txt
            catchAllMode   = true
            MethodLabel:Set("Watching for: " .. txt)
            Rayfield:Notify({
                Title = "Not in RS — watching",
                Content = "Press Roll once and I'll catch it when it fires.",
                Duration = 5, Image = "radio"
            })
        end
    end,
})

DebugTab:CreateDivider()
DebugTab:CreateSection("Reset")
DebugTab:CreateButton({
    Name = "🔄 Clear Remote",
    Callback = function()
        RollRemote = nil; catchAllMode = false; catchAllTarget = nil
        MethodLabel:Set("Remote cleared — use steps above")
        Rayfield:Notify({ Title="Cleared", Content="Remote reset.", Duration=3, Image="rotate-ccw" })
    end,
})

-- ── Settings tab ──────────────────────────────────
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

-- ── Presets tab ───────────────────────────────────
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
print("[AutoRoll v15] Loaded")
