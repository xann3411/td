-- ================================================
-- Auto Roll v11 — Random Anime Tower Defense
-- Rayfield UI | hookmetamethod remote capture
-- ================================================

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local function GetSvc(n)
    local ok,s = pcall(function() return game:GetService(n) end)
    return ok and s or nil
end

local Players           = GetSvc("Players")
local ReplicatedStorage = GetSvc("ReplicatedStorage")
local RunService        = GetSvc("RunService")

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
    totalRolled     = 0,
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

-- ================================================
-- Remote capture via hookmetamethod (works on all mobile executors)
-- ================================================
local RollRemote   = nil
local capturing    = false
local MethodLabel  -- forward ref, set after UI build

local ROLL_KEYWORDS = {"roll","gacha","summon","unit","anime","character","pull"}
local function looksLikeRoll(name)
    local n = name:lower()
    for _, kw in ipairs(ROLL_KEYWORDS) do
        if n:find(kw) then return true end
    end
    return false
end

-- hookmetamethod on the game's __namecall — catches FireServer/InvokeServer
local hooked = false
local function StartCapturing()
    if hooked then capturing = true; return end
    hooked = true
    capturing = true
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if capturing and not RollRemote then
                if (method == "FireServer" or method == "InvokeServer") then
                    if self:IsA("RemoteEvent") or self:IsA("RemoteFunction") then
                        if looksLikeRoll(self.Name) then
                            RollRemote = self
                            capturing = false
                            print("[AutoRoll] Captured:", self.Name)
                            if MethodLabel then
                                pcall(function()
                                    MethodLabel:Set("Remote captured: " .. self.Name .. " ✅")
                                end)
                            end
                            -- Notify
                            pcall(function()
                                Rayfield:Notify({
                                    Title = "Remote Captured! ✅",
                                    Content = "Got: " .. self.Name .. " — Start Rolling from anywhere now!",
                                    Duration = 6, Image = "check",
                                })
                            end)
                        end
                    end
                end
            end
            return oldIndex(self, ...)
        end)
        setreadonly(mt, true)
    end)
end

-- Also try static scan
local function FindRollRemote()
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and looksLikeRoll(d.Name) then
                result = d; return
            end
        end
    end)
    return result
end

task.spawn(function()
    RollRemote = FindRollRemote()
    if RollRemote then
        print("[AutoRoll] Remote found via scan:", RollRemote.Name)
    else
        -- Auto-start capturing so any manual roll captures it immediately
        StartCapturing()
        print("[AutoRoll] Listening for remote — press Roll once to capture")
    end
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
-- Rarity detection — ONLY reads the roll result popup
-- Strategy: find a TextLabel whose text is EXACTLY a rarity name,
-- that appeared/changed AFTER the roll fired (we snapshot before & diff after)
-- ================================================
local function GetRarityLabels()
    -- Returns map of label -> text for all visible short center-ish labels
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800,600)
    local results = {}
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not (obj:IsA("TextLabel") and obj.Visible) then continue end
            local t = obj.Text:match("^%s*(.-)%s*$")
            if not t or #t == 0 or #t > 15 then continue end
            -- must be plain letters only
            if t:find("[^%a%s]") then continue end
            -- position filter: ignore far right and far left
            local pos = obj.AbsolutePosition
            if pos.X > vp.X * 0.78 then continue end
            if pos.X < vp.X * 0.12 then continue end
            results[obj] = t:lower()
        end
    end)
    return results
end

local function DetectRarityDiff(before, after)
    -- Find any label that is NOW showing a rarity name and wasn't before
    -- (or wasn't visible before)
    local found, foundRank = nil, 0
    for obj, txt in pairs(after) do
        local wasPresent = before[obj]
        -- It's new or changed
        if wasPresent ~= txt then
            for _, rar in ipairs(RARITIES) do
                if txt == rar.name:lower() and rar.rank > foundRank then
                    found = rar.name
                    foundRank = rar.rank
                end
            end
        end
    end
    -- Fallback: if diff found nothing, check if any current label is a rarity
    -- but only if its parent GUI looks like a result popup
    if not found then
        for obj, txt in pairs(after) do
            local cur = obj
            local inResultGui = false
            for _ = 1, 8 do
                if not cur or not cur.Parent then break end
                local n = cur.Name:lower()
                if n:find("result") or n:find("reward") or n:find("roll")
                    or n:find("obtained") or n:find("popup") or n:find("summon")
                    or n:find("get") or n:find("new") or n:find("unit") then
                    inResultGui = true; break
                end
                cur = cur.Parent
            end
            if inResultGui then
                for _, rar in ipairs(RARITIES) do
                    if txt == rar.name:lower() and rar.rank > foundRank then
                        found = rar.name
                        foundRank = rar.rank
                    end
                end
            end
        end
    end
    return found
end

local function ShouldStop(name)
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
    -- Snapshot labels BEFORE rolling
    local before = GetRarityLabels()

    local fired = FireRemote()
    if not fired then
        print("[AutoRoll] Remote not available — capture it first!")
    end

    State.rollsSinceStart += 1
    State.totalRolled += 1

    -- Wait for roll animation
    task.wait(math.max(State.rollDelay * 0.6, 0.3))

    -- Sample a few times to catch the popup
    local rar = nil
    for _ = 1, 4 do
        local after = GetRarityLabels()
        rar = DetectRarityDiff(before, after)
        if rar then break end
        task.wait(0.15)
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
local StatusLabel = MainTab:CreateLabel("● Idle")
local RollsLabel  = MainTab:CreateLabel("Rolls this session: 0")
local RarityLabel = MainTab:CreateLabel("Last rarity: —")
MethodLabel = MainTab:CreateLabel("Remote: " .. (RollRemote and RollRemote.Name.." ✅" or "not found yet"))

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
            StatusLabel:Set("● Stopped — " .. State.rollsSinceStart .. " rolls")
        else
            if not RollRemote then
                Rayfield:Notify({
                    Title = "No Remote Found",
                    Content = "Press 'Capture Remote', then press Roll once manually, then try again.",
                    Duration = 6, Image = "alert-triangle",
                })
                return
            end
            rolling = true
            State.rolling = true
            State.rollsSinceStart = 0
            StartBtn:Set("⏹  Stop Rolling")
            StatusLabel:Set("● Rolling…")
            MethodLabel:Set("Remote: " .. RollRemote.Name .. " ✅")

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
                            Duration = 8, Image = "trophy",
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
MainTab:CreateSection("Setup")

MainTab:CreateButton({
    Name = "📡 Capture Remote (press Roll once after)",
    Callback = function()
        if RollRemote then
            Rayfield:Notify({
                Title = "Already Have It ✅",
                Content = "Remote: " .. RollRemote.Name,
                Duration = 4, Image = "check",
            })
            return
        end
        RollRemote = FindRollRemote()
        if RollRemote then
            MethodLabel:Set("Remote: " .. RollRemote.Name .. " ✅")
            Rayfield:Notify({
                Title = "Found via Scan ✅",
                Content = RollRemote.Name,
                Duration = 4, Image = "check",
            })
            return
        end
        StartCapturing()
        MethodLabel:Set("Listening… press Roll once now!")
        Rayfield:Notify({
            Title = "Listening…",
            Content = "Now press Roll once manually. It will auto-capture.",
            Duration = 6, Image = "radio",
        })
        task.spawn(function()
            for _ = 1, 40 do
                task.wait(0.5)
                if RollRemote then return end
            end
            if not RollRemote then
                capturing = false
                MethodLabel:Set("Capture timed out — try Scan")
                Rayfield:Notify({
                    Title = "Timed Out",
                    Content = "Didn't catch it. Make sure you pressed Roll while listening.",
                    Duration = 5, Image = "alert-triangle",
                })
            end
        end)
    end,
})

MainTab:CreateButton({
    Name = "🔄 Reset Remote (re-capture)",
    Callback = function()
        RollRemote = nil
        capturing = false
        MethodLabel:Set("Remote cleared — use Capture to re-capture")
        Rayfield:Notify({ Title = "Reset", Content = "Remote cleared.", Duration = 3, Image = "rotate-ccw" })
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
        Callback = function(val) State.stopRarities[name] = val end,
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
    Callback = function(opt)
        State.stopMode = tostring(opt[1] or opt):find("Exact") and "Exact" or "AtLeast"
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
    Callback = function(val) State.rollDelay = val end,
})

-- ================================================
-- TAB: Presets
-- ================================================
local PresetsTab = Window:CreateTab("Presets", "zap")
PresetsTab:CreateSection("Quick Stop Presets")

local function ApplyPreset(list)
    for _, r in ipairs(RARITIES) do State.stopRarities[r.name] = false end
    for _, n in ipairs(list) do State.stopRarities[n] = true end
    Rayfield:Notify({ Title = "Preset Applied", Content = table.concat(list,", "), Duration = 3, Image = "check" })
end

PresetsTab:CreateButton({ Name = "Epic+", Callback = function() ApplyPreset({"Epic","Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Legendary+", Callback = function() ApplyPreset({"Legendary","Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Mythic+", Callback = function() ApplyPreset({"Mythic","Secret","Limited"}) end })
PresetsTab:CreateButton({ Name = "Secret+", Callback = function() ApplyPreset({"Secret","Limited"}) end })

Rayfield:LoadConfiguration()
print("[AutoRoll v11] Loaded")
