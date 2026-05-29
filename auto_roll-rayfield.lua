-- ================================================
-- Auto Roll Script v5 — Random Anime Tower Defense
-- UI powered by Rayfield Interface Suite
-- ================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- ================================================
-- Safe service getter
-- ================================================
local function GetSvc(name)
    local ok, svc = pcall(function() return game:GetService(name) end)
    return ok and svc or nil
end

local Players           = GetSvc("Players")
local ReplicatedStorage = GetSvc("ReplicatedStorage")
local UserInputService  = GetSvc("UserInputService")
local RunService        = GetSvc("RunService")
local VIM               = GetSvc("VirtualInputManager")

if not Players then return end
local Player    = Players.LocalPlayer
local PlayerGui = Player and Player:WaitForChild("PlayerGui", 10)
if not PlayerGui then return end

-- ================================================
-- State
-- ================================================
local State = {
    rolling         = false,
    rollDelay       = 0.5,
    rollsSinceStart = 0,
    totalRolled     = 0,
    lastRarity      = "—",
    stopMode        = "AtLeast",  -- "Exact" or "AtLeast"
    useRemote       = true,
    stopRarities    = {
        Common=false, Rare=false, Epic=false,
        Legendary=true, Mythic=true, Secret=true, Limited=true
    },
}

local RARITIES = {
    { name="Common",    rank=1 },
    { name="Rare",      rank=2 },
    { name="Epic",      rank=3 },
    { name="Legendary", rank=4 },
    { name="Mythic",    rank=5 },
    { name="Secret",    rank=6 },
    { name="Limited",   rank=7 },
}

-- ================================================
-- Roll Remote — lazy-found
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
-- Roll logic
-- ================================================
local function DetectRarity()
    local found, foundRank = nil, 0
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local t = obj.Text:match("^%s*(.-)%s*$"):lower()
                for _, rar in ipairs(RARITIES) do
                    if t == rar.name:lower() and rar.rank > foundRank then
                        found = rar.name; foundRank = rar.rank
                    end
                end
            end
        end
    end)
    return found
end

local function FireRemote()
    if not State.useRemote then return false end
    if not RollRemote then RollRemote = FindRollRemote() end
    if not RollRemote then return false end
    local ok = pcall(function()
        if RollRemote:IsA("RemoteFunction") then RollRemote:InvokeServer()
        else RollRemote:FireServer() end
    end)
    return ok
end

local rollBtnRef = nil
local function ClickBtn()
    if not rollBtnRef or not rollBtnRef.Parent then
        pcall(function()
            for _, obj in ipairs(PlayerGui:GetDescendants()) do
                if (obj:IsA("TextButton") or obj:IsA("ImageButton")) and obj.Visible then
                    local n = obj.Name:lower()
                    local t = obj:IsA("TextButton") and obj.Text:lower() or ""
                    if (n:find("roll") or t == "roll" or t:find("^roll")) and obj.AbsoluteSize.X > 20 then
                        rollBtnRef = obj; break
                    end
                end
            end
        end)
    end
    if not rollBtnRef then return false end
    local ok = pcall(function()
        if VIM then
            local ap = rollBtnRef.AbsolutePosition; local as = rollBtnRef.AbsoluteSize
            local cx = math.floor(ap.X + as.X / 2); local cy = math.floor(ap.Y + as.Y / 2)
            VIM:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        else
            rollBtnRef.MouseButton1Click:Fire()
        end
    end)
    return ok
end

local function ShouldStop(name)
    if State.stopMode == "Exact" then return State.stopRarities[name] == true end
    local min = 999
    for _, r in ipairs(RARITIES) do if State.stopRarities[r.name] then min = math.min(min, r.rank) end end
    for _, r in ipairs(RARITIES) do if r.name == name then return r.rank >= min end end
    return false
end

local function DoRoll()
    local ok = FireRemote()
    if not ok then ok = ClickBtn() end
    State.rollsSinceStart += 1; State.totalRolled += 1
    task.wait(math.max(State.rollDelay * 0.5, 0.15))
    local rar = DetectRarity()
    if rar then
        State.lastRarity = rar
        return ShouldStop(rar)
    end
    return false
end

-- ================================================
-- BUILD RAYFIELD UI
-- ================================================
local Window = Rayfield:CreateWindow({
    Name = "🎲 Auto Roll",
    Icon = "dices",
    LoadingTitle = "Auto Roll",
    LoadingSubtitle = "Random Anime Tower Defense",
    ShowText = "Auto Roll",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "AutoRoll",
        FileName = "AutoRollConfig"
    },
    Discord = { Enabled = false, Invite = "", RememberJoins = false },
    KeySystem = false,
})

-- ================================================
-- TAB: Roll Control
-- ================================================
local MainTab = Window:CreateTab("Roll Control", "play")

MainTab:CreateSection("Status")

local StatusLabel = MainTab:CreateLabel("● Idle — pick rarities and press Start")
local RollsLabel  = MainTab:CreateLabel("Rolls this session: 0")
local RarityLabel = MainTab:CreateLabel("Last rarity: —")
local MethodLabel = MainTab:CreateLabel("Roll method: searching remote…")

MainTab:CreateDivider()
MainTab:CreateSection("Controls")

-- Start/Stop button
local rolling = false
local StartBtn = MainTab:CreateButton({
    Name = "▶  Start Rolling",
    Callback = function()
        if rolling then
            rolling = false
            State.rolling = false
            StartBtn:Set("▶  Start Rolling")
            StatusLabel:Set("● Stopped — " .. State.rollsSinceStart .. " rolls this run")
        else
            rolling = true
            State.rolling = true
            State.rollsSinceStart = 0
            rollBtnRef = nil
            StartBtn:Set("⏹  Stop Rolling")
            StatusLabel:Set("● Rolling…")
            task.spawn(function()
                while State.rolling do
                    local stop = false
                    pcall(function() stop = DoRoll() end)
                    RollsLabel:Set("Rolls this session: " .. State.rollsSinceStart)
                    RarityLabel:Set("Last rarity: " .. State.lastRarity)
                    if stop then
                        State.rolling = false
                        rolling = false
                        StartBtn:Set("▶  Start Rolling")
                        StatusLabel:Set("🎉 Got " .. State.lastRarity .. "! (#" .. State.rollsSinceStart .. ")")
                        Rayfield:Notify({
                            Title = "Target Hit!",
                            Content = "Got " .. State.lastRarity .. " after " .. State.rollsSinceStart .. " rolls",
                            Duration = 6,
                            Image = "trophy",
                        })
                        break
                    end
                    if State.rolling then task.wait(State.rollDelay) end
                end
            end)
        end
    end,
})

-- ================================================
-- TAB: Settings
-- ================================================
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Stop Rarities")

-- Rarity toggles
for _, rar in ipairs(RARITIES) do
    local name = rar.name
    SettingsTab:CreateToggle({
        Name = "Stop on " .. name,
        CurrentValue = State.stopRarities[name],
        Flag = "StopOn" .. name,
        Callback = function(val)
            State.stopRarities[name] = val
        end,
    })
end

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Stop Mode")

SettingsTab:CreateDropdown({
    Name = "Mode",
    Options = {"AtLeast (rarity or better)", "Exact (only that rarity)"},
    CurrentOption = {"AtLeast (rarity or better)"},
    MultipleOptions = false,
    Flag = "StopMode",
    Callback = function(option)
        local sel = option[1] or option
        if tostring(sel):find("Exact") then
            State.stopMode = "Exact"
        else
            State.stopMode = "AtLeast"
        end
    end,
})

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Delay")

SettingsTab:CreateSlider({
    Name = "Roll Delay (seconds)",
    Range = {0.1, 3.0},
    Increment = 0.1,
    Suffix = "s",
    CurrentValue = State.rollDelay,
    Flag = "RollDelay",
    Callback = function(val)
        State.rollDelay = val
    end,
})

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Method")

SettingsTab:CreateToggle({
    Name = "Use Remote Event (uncheck = button click)",
    CurrentValue = State.useRemote,
    Flag = "UseRemote",
    Callback = function(val)
        State.useRemote = val
        if val then
            MethodLabel:Set("Roll method: remote event")
        else
            MethodLabel:Set("Roll method: button click")
        end
    end,
})

-- ================================================
-- TAB: Presets
-- ================================================
local PresetsTab = Window:CreateTab("Presets", "zap")

PresetsTab:CreateSection("Quick Stop Presets")

local function ApplyPreset(list)
    -- reset all
    for _, r in ipairs(RARITIES) do State.stopRarities[r.name] = false end
    -- set selected
    for _, name in ipairs(list) do State.stopRarities[name] = true end
    Rayfield:Notify({
        Title = "Preset Applied",
        Content = "Stopping on: " .. table.concat(list, ", "),
        Duration = 3,
        Image = "check",
    })
end

PresetsTab:CreateButton({
    Name = "Epic+  (Epic, Legendary, Mythic, Secret, Limited)",
    Callback = function()
        ApplyPreset({"Epic","Legendary","Mythic","Secret","Limited"})
    end,
})
PresetsTab:CreateButton({
    Name = "Legendary+  (Legendary, Mythic, Secret, Limited)",
    Callback = function()
        ApplyPreset({"Legendary","Mythic","Secret","Limited"})
    end,
})
PresetsTab:CreateButton({
    Name = "Mythic+  (Mythic, Secret, Limited)",
    Callback = function()
        ApplyPreset({"Mythic","Secret","Limited"})
    end,
})
PresetsTab:CreateButton({
    Name = "Secret+  (Secret, Limited only)",
    Callback = function()
        ApplyPreset({"Secret","Limited"})
    end,
})

-- ================================================
-- Live total counter in background
-- ================================================
if RunService then
    RunService.Heartbeat:Connect(function()
        -- update method label from remote search
        if RollRemote and MethodLabel then
            pcall(function() MethodLabel:Set("Roll method: remote — " .. RollRemote.Name) end)
        end
    end)
end

Rayfield:LoadConfiguration()
print("[AutoRoll v5 Rayfield] Loaded")
