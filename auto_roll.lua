-- ================================================
-- Auto Roll Script v6 — Random Anime Tower Defense
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
    rollDelay       = 0.65,   -- slightly longer default, safer for animation
    rollsSinceStart = 0,
    totalRolled     = 0,
    lastRarity      = "—",
    stopMode        = "AtLeast",
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
-- Roll Remote — searches every attempt, caches on success
-- ================================================
local RollRemote = nil
local function FindRollRemote()
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        -- Common path patterns in RATD
        local paths = {
            {"Events","Roll"},
            {"Events","RollUnit"},
            {"Events","Gacha"},
            {"Events","Summon"},
            {"Events","RollAnime"},
            {"RemoteEvents","Roll"},
            {"RemoteEvents","Gacha"},
            {"RemoteEvents","RollUnit"},
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
        -- Deep scan fallback
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
                local n = d.Name:lower()
                if n:find("roll") or n:find("gacha") or n:find("summon") or n:find("anime") then
                    result = d; return
                end
            end
        end
    end)
    return result
end

-- Search immediately AND after a short delay
task.spawn(function()
    RollRemote = FindRollRemote()
    if not RollRemote then
        task.wait(5)
        RollRemote = FindRollRemote()
    end
    print("[AutoRoll] Remote:", RollRemote and RollRemote.Name or "not found — will use button click")
end)

-- ================================================
-- Button finder — broad search, works for RATD's Roll button
-- The Roll button in RATD is typically a large ImageButton or Frame
-- named something like "RollButton", "Roll", "BtnRoll", "GachaBtn"
-- with a TextLabel child saying "Roll"
-- ================================================
local rollBtnRef = nil
local function FindRollBtn()
    local best = nil
    local bestSize = 0
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not obj.Visible then continue end
            local isClickable = obj:IsA("TextButton") or obj:IsA("ImageButton")
            if not isClickable then continue end

            local n = obj.Name:lower()
            local t = (obj:IsA("TextButton") and obj.Text or ""):lower()
            local sz = obj.AbsoluteSize

            -- Check button name / text directly
            local nameMatch = n:find("roll") or n:find("gacha") or n:find("summon") or n == "btn" and t:find("roll")
            local textMatch = t == "roll" or t:find("^roll") or t == "reroll"

            -- Also check if any TextLabel child says "Roll"
            local childMatch = false
            if not nameMatch and not textMatch then
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        local ct = child.Text:lower():match("^%s*(.-)%s*$")
                        if ct == "roll" or ct:find("^roll") then
                            childMatch = true; break
                        end
                    end
                end
            end

            if (nameMatch or textMatch or childMatch) and sz.X > 30 and sz.Y > 30 then
                -- Pick the largest matching button (the main Roll button, not sub-buttons)
                local area = sz.X * sz.Y
                if area > bestSize then
                    best = obj
                    bestSize = area
                end
            end
        end
    end)
    return best
end

-- ================================================
-- Click helpers — try every method available on mobile
-- ================================================
local function FireClick(btn)
    if not btn or not btn.Parent then return false end

    -- Method 1: VirtualInputManager (works on most mobile executors)
    if VIM then
        local ok = pcall(function()
            local ap = btn.AbsolutePosition
            local as = btn.AbsoluteSize
            local cx = math.floor(ap.X + as.X / 2)
            local cy = math.floor(ap.Y + as.Y / 2)
            VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 1)
            task.wait(0.08)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
        if ok then return true end
    end

    -- Method 2: firetouchinterest (Delta/Fluxus/etc)
    local ok2 = pcall(function()
        firetouchinterest(btn, Player.Character, 0)
        task.wait(0.08)
        firetouchinterest(btn, Player.Character, 1)
    end)
    if ok2 then return true end

    -- Method 3: Fire the signal directly
    local ok3 = pcall(function()
        if btn:IsA("TextButton") or btn:IsA("ImageButton") then
            btn.MouseButton1Click:Fire()
        end
    end)
    return ok3
end

local function ClickBtn()
    -- Re-find every time in case the UI rebuilds
    if not rollBtnRef or not rollBtnRef.Parent then
        rollBtnRef = FindRollBtn()
    end
    if not rollBtnRef then
        print("[AutoRoll] Roll button not found!")
        return false
    end
    return FireClick(rollBtnRef)
end

-- ================================================
-- Remote fire
-- ================================================
local function FireRemote()
    if not State.useRemote then return false end
    if not RollRemote then RollRemote = FindRollRemote() end
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
-- Rarity detection
-- ================================================
local function DetectRarity()
    local found, foundRank = nil, 0
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Visible then
                local t = obj.Text:match("^%s*(.-)%s*$"):lower()
                for _, rar in ipairs(RARITIES) do
                    if t == rar.name:lower() and rar.rank > foundRank then
                        found = rar.name
                        foundRank = rar.rank
                    end
                end
            end
        end
    end)
    return found
end

local function ShouldStop(name)
    if State.stopMode == "Exact" then
        return State.stopRarities[name] == true
    end
    local min = 999
    for _, r in ipairs(RARITIES) do
        if State.stopRarities[r.name] then min = math.min(min, r.rank) end
    end
    for _, r in ipairs(RARITIES) do
        if r.name == name then return r.rank >= min end
    end
    return false
end

-- ================================================
-- One roll cycle
-- ================================================
local function DoRoll()
    -- Try remote first, fall back to button
    local fired = FireRemote()
    if not fired then
        fired = ClickBtn()
    end

    if not fired then
        -- Nothing worked — give debug info
        print("[AutoRoll] WARNING: Could not fire roll. Remote=", RollRemote, "Button=", rollBtnRef)
    end

    State.rollsSinceStart += 1
    State.totalRolled += 1

    -- Wait for the roll animation to settle before reading rarity
    task.wait(math.max(State.rollDelay * 0.6, 0.25))

    local rar = DetectRarity()
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
    Name = "🎲 Auto Roll",
    Icon = "dices",
    LoadingTitle = "Auto Roll",
    LoadingSubtitle = "Random Anime Tower Defense",
    ShowText = "Auto Roll",
    Theme = "Default",
    DisableRayfieldPrompts = false,
    DisableBuildWarnings = true,
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
local StatusLabel = MainTab:CreateLabel("● Idle — configure settings then press Start")
local RollsLabel  = MainTab:CreateLabel("Rolls this session: 0")
local RarityLabel = MainTab:CreateLabel("Last rarity: —")
local MethodLabel = MainTab:CreateLabel("Roll method: scanning…")

MainTab:CreateDivider()
MainTab:CreateSection("Controls")

local rolling = false
local StartBtn
StartBtn = MainTab:CreateButton({
    Name = "▶  Start Rolling",
    Callback = function()
        if rolling then
            rolling = false
            State.rolling = false
            StartBtn:Set("▶  Start Rolling")
            StatusLabel:Set("● Stopped — " .. State.rollsSinceStart .. " rolls this run")
        else
            -- Pre-scan for button and remote before starting
            rollBtnRef = FindRollBtn()
            if not RollRemote then RollRemote = FindRollRemote() end

            if not RollRemote and not rollBtnRef then
                Rayfield:Notify({
                    Title = "Nothing Found!",
                    Content = "Can't find Roll button or Remote. Open the Roll UI first then try again.",
                    Duration = 6,
                    Image = "alert-triangle",
                })
                return
            end

            -- Update method label
            if RollRemote then
                MethodLabel:Set("Method: Remote — " .. RollRemote.Name)
            elseif rollBtnRef then
                MethodLabel:Set("Method: Button click — " .. rollBtnRef.Name)
            end

            rolling = true
            State.rolling = true
            State.rollsSinceStart = 0
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
                            Title = "Target Hit! 🎉",
                            Content = "Got " .. State.lastRarity .. " after " .. State.rollsSinceStart .. " rolls",
                            Duration = 8,
                            Image = "trophy",
                        })
                        break
                    end
                    if State.rolling then
                        task.wait(State.rollDelay)
                    end
                end
            end)
        end
    end,
})

MainTab:CreateDivider()
MainTab:CreateSection("Debug")

MainTab:CreateButton({
    Name = "🔍 Scan for Roll Button Now",
    Callback = function()
        rollBtnRef = FindRollBtn()
        RollRemote = FindRollRemote()
        local msg = ""
        if RollRemote then msg = msg .. "Remote: " .. RollRemote.Name .. "  " end
        if rollBtnRef then msg = msg .. "Button: " .. rollBtnRef.Name end
        if msg == "" then msg = "Nothing found — open the Roll UI first!" end
        MethodLabel:Set(msg)
        Rayfield:Notify({
            Title = "Scan Result",
            Content = msg,
            Duration = 5,
            Image = "search",
        })
    end,
})

-- ================================================
-- TAB: Settings
-- ================================================
local SettingsTab = Window:CreateTab("Settings", "settings")

SettingsTab:CreateSection("Stop Rarities")
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
        State.stopMode = tostring(sel):find("Exact") and "Exact" or "AtLeast"
    end,
})

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Timing")
SettingsTab:CreateSlider({
    Name = "Roll Delay (seconds)",
    Range = {0.3, 3.0},
    Increment = 0.05,
    Suffix = "s",
    CurrentValue = State.rollDelay,
    Flag = "RollDelay",
    Callback = function(val)
        State.rollDelay = val
    end,
})

SettingsTab:CreateDivider()
SettingsTab:CreateSection("Roll Method")
SettingsTab:CreateToggle({
    Name = "Try Remote Event first",
    CurrentValue = State.useRemote,
    Flag = "UseRemote",
    Callback = function(val)
        State.useRemote = val
    end,
})

-- ================================================
-- TAB: Presets
-- ================================================
local PresetsTab = Window:CreateTab("Presets", "zap")
PresetsTab:CreateSection("Quick Stop Presets")

local function ApplyPreset(list)
    for _, r in ipairs(RARITIES) do State.stopRarities[r.name] = false end
    for _, name in ipairs(list) do State.stopRarities[name] = true end
    Rayfield:Notify({
        Title = "Preset Applied",
        Content = "Stopping on: " .. table.concat(list, ", "),
        Duration = 3,
        Image = "check",
    })
end

PresetsTab:CreateButton({ Name = "Epic+  (Epic → Limited)", Callback = function() ApplyPreset({"Epic","Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Legendary+  (Legendary → Limited)", Callback = function() ApplyPreset({"Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Mythic+  (Mythic → Limited)", Callback = function() ApplyPreset({"Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Secret+  (Secret & Limited only)", Callback = function() ApplyPreset({"Secret","Limited"}) end })

Rayfield:LoadConfiguration()
print("[AutoRoll v6] Loaded")
