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
-- Remote finder — two strategies:
-- 1. Hook FireServer to auto-capture the remote when player manually rolls once
-- 2. Static path scan as fallback
-- ================================================
local RollRemote = nil
local remoteHooked = false

local function FindRollRemote()
    if not ReplicatedStorage then return nil end
    local result = nil
    pcall(function()
        local paths = {
            {"Events","Roll"}, {"Events","RollUnit"}, {"Events","Gacha"},
            {"Events","Summon"}, {"Events","RollAnime"}, {"Events","RollCharacter"},
            {"RemoteEvents","Roll"}, {"RemoteEvents","Gacha"}, {"RemoteEvents","RollUnit"},
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
                if n:find("roll") or n:find("gacha") or n:find("summon") or n:find("anime") then
                    result = d; return
                end
            end
        end
    end)
    return result
end

-- Hook ALL RemoteEvents to sniff which one fires when you manually press Roll
local function HookRemotes()
    if remoteHooked then return end
    remoteHooked = true
    pcall(function()
        local oldFireServer = RemoteEvent.FireServer
        hookfunction(oldFireServer, function(self, ...)
            -- Capture the first remote that fires after hooking
            -- Filter to likely roll remotes by name
            if not RollRemote then
                local n = self.Name:lower()
                if n:find("roll") or n:find("gacha") or n:find("summon") or n:find("unit") or n:find("anime") then
                    RollRemote = self
                    print("[AutoRoll] Captured remote via hook:", self.Name)
                    if MethodLabel then
                        pcall(function() MethodLabel:Set("Method: Remote (hooked) — " .. self.Name) end)
                    end
                end
            end
            return oldFireServer(self, ...)
        end)
    end)
end

task.spawn(function()
    -- Try static scan first
    RollRemote = FindRollRemote()
    if RollRemote then
        print("[AutoRoll] Remote found via scan:", RollRemote.Name)
    else
        -- Fall back to hooking
        HookRemotes()
        print("[AutoRoll] Hook active — press Roll once manually to capture remote")
    end
end)

-- ================================================
-- RATD Roll: the "ROLL" is a BillboardGui on a Workspace part.
-- Best approach: find + fire the ProximityPrompt, or fire the remote.
-- Fallback: find any ScreenGui button that appears after walking up.
-- ================================================
local rollPromptRef = nil
local rollBtnRef    = nil

local function FindRollPrompt()
    -- ProximityPrompt on the roll pedestal
    local result = nil
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                local n = obj.ActionText:lower()
                local pn = obj.Parent and obj.Parent.Name:lower() or ""
                if n:find("roll") or n:find("gacha") or n:find("summon")
                    or pn:find("roll") or pn:find("gacha") or pn:find("summon") then
                    result = obj; return
                end
            end
        end
        -- Also check BillboardGui parent parts for a ClickDetector
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                local n = obj.Name:lower()
                -- check TextLabel children
                for _, child in ipairs(obj:GetDescendants()) do
                    if child:IsA("TextLabel") then
                        local t = child.Text:lower():match("^%s*(.-)%s*$")
                        if t == "roll" or t:find("^roll") then
                            -- Look for ProximityPrompt or ClickDetector on the same part
                            local part = obj.Parent
                            if part then
                                local pp = part:FindFirstChildOfClass("ProximityPrompt")
                                    or part:FindFirstChildOfClass("ClickDetector")
                                if pp then result = pp; return end
                                -- Return the part itself so we can fireproximityprompt
                                result = part; return
                            end
                        end
                    end
                end
            end
        end
    end)
    return result
end

local function FindRollBtn()
    -- Fallback: ScreenGui button (appears when you're close to the pedestal)
    local best, bestSize = nil, 0
    pcall(function()
        for _, obj in ipairs(PlayerGui:GetDescendants()) do
            if not obj.Visible then continue end
            if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then continue end
            local n = obj.Name:lower()
            local t = (obj:IsA("TextButton") and obj.Text or ""):lower()
            local nameMatch = n:find("roll") or n:find("gacha") or n:find("summon")
            local textMatch = t == "roll" or t:find("^roll")
            local childMatch = false
            if not nameMatch and not textMatch then
                for _, c in ipairs(obj:GetDescendants()) do
                    if c:IsA("TextLabel") then
                        local ct = c.Text:lower():match("^%s*(.-)%s*$")
                        if ct == "roll" or ct:find("^roll") then childMatch = true; break end
                    end
                end
            end
            local sz = obj.AbsoluteSize
            if (nameMatch or textMatch or childMatch) and sz.X > 30 and sz.Y > 30 then
                local area = sz.X * sz.Y
                if area > bestSize then best = obj; bestSize = area end
            end
        end
    end)
    return best
end

local function TriggerPrompt(obj)
    if not obj or not obj.Parent then return false end
    -- fireproximityprompt (most executors support this)
    if obj:IsA("ProximityPrompt") then
        local ok = pcall(fireproximityprompt, obj)
        if ok then return true end
        -- fallback: trigger via signal
        local ok2 = pcall(function() obj.Triggered:Fire(Player) end)
        return ok2
    end
    -- ClickDetector
    if obj:IsA("ClickDetector") then
        local ok = pcall(fireclickdetector, obj)
        if ok then return true end
        local ok2 = pcall(function() obj.MouseClick:Fire(Player) end)
        return ok2
    end
    -- It's a BasePart — look inside for prompt/detector
    if obj:IsA("BasePart") or obj:IsA("Model") then
        local pp = obj:FindFirstChildOfClass("ProximityPrompt")
        if pp then return TriggerPrompt(pp) end
        local cd = obj:FindFirstChildOfClass("ClickDetector")
        if cd then return TriggerPrompt(cd) end
    end
    return false
end

local function FireClick(btn)
    if not btn or not btn.Parent then return false end
    if VIM then
        local ok = pcall(function()
            local ap = btn.AbsolutePosition; local as = btn.AbsoluteSize
            local cx = math.floor(ap.X + as.X/2); local cy = math.floor(ap.Y + as.Y/2)
            VIM:SendMouseButtonEvent(cx, cy, 0, true,  game, 1); task.wait(0.08)
            VIM:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
        end)
        if ok then return true end
    end
    local ok2 = pcall(function()
        firetouchinterest(btn, Player.Character, 0); task.wait(0.08)
        firetouchinterest(btn, Player.Character, 1)
    end)
    if ok2 then return true end
    local ok3 = pcall(function() btn.MouseButton1Click:Fire() end)
    return ok3
end

local function ClickBtn()
    -- 1. Try ProximityPrompt / ClickDetector on workspace part
    if not rollPromptRef or not rollPromptRef.Parent then
        rollPromptRef = FindRollPrompt()
    end
    if rollPromptRef then
        local ok = TriggerPrompt(rollPromptRef)
        if ok then return true end
    end
    -- 2. Try ScreenGui button fallback
    if not rollBtnRef or not rollBtnRef.Parent then
        rollBtnRef = FindRollBtn()
    end
    if rollBtnRef then return FireClick(rollBtnRef) end
    print("[AutoRoll] Nothing found to click!")
    return false
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
            -- Pre-scan for prompt, button and remote before starting
            rollPromptRef = FindRollPrompt()
            rollBtnRef    = FindRollBtn()
            if not RollRemote then RollRemote = FindRollRemote() end

            if not RollRemote and not rollBtnRef and not rollPromptRef then
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
            elseif rollPromptRef then
                MethodLabel:Set("Method: ProximityPrompt — " .. rollPromptRef.Name)
            elseif rollBtnRef then
                MethodLabel:Set("Method: Button — " .. rollBtnRef.Name)
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
        rollPromptRef = FindRollPrompt()
        rollBtnRef    = FindRollBtn()
        RollRemote    = FindRollRemote()
        local parts = {}
        if RollRemote    then table.insert(parts, "Remote: "  .. RollRemote.Name) end
        if rollPromptRef then table.insert(parts, "Prompt: "  .. rollPromptRef.ClassName .. " (" .. rollPromptRef.Name .. ")") end
        if rollBtnRef    then table.insert(parts, "Button: "  .. rollBtnRef.Name) end
        local msg = #parts > 0 and table.concat(parts, " | ") or "Nothing found — walk up to the ROLL pedestal first!"
        MethodLabel:Set(msg)
        Rayfield:Notify({
            Title = "Scan Result",
            Content = msg,
            Duration = 6,
            Image = "search",
        })
    end,
})

MainTab:CreateButton({
    Name = "📡 Capture Remote (press Roll once first)",
    Callback = function()
        if RollRemote then
            Rayfield:Notify({
                Title = "Already Captured!",
                Content = "Remote: " .. RollRemote.Name .. " — you're good to go!",
                Duration = 4,
                Image = "check",
            })
            return
        end
        -- Activate hook and wait for player to press Roll manually
        HookRemotes()
        MethodLabel:Set("Waiting… press Roll manually once now!")
        Rayfield:Notify({
            Title = "Hook Active",
            Content = "Now walk up and press Roll ONCE manually. The remote will be auto-captured.",
            Duration = 6,
            Image = "radio",
        })
        -- Poll for up to 15 seconds
        task.spawn(function()
            for _ = 1, 30 do
                task.wait(0.5)
                if RollRemote then
                    Rayfield:Notify({
                        Title = "Remote Captured! ✅",
                        Content = "Got: " .. RollRemote.Name .. " — Start Rolling now from anywhere!",
                        Duration = 6,
                        Image = "check",
                    })
                    MethodLabel:Set("Remote captured: " .. RollRemote.Name)
                    return
                end
            end
            if not RollRemote then
                MethodLabel:Set("Capture timed out — try Scan instead")
                Rayfield:Notify({
                    Title = "Timed Out",
                    Content = "Didn't catch the remote. Make sure you pressed Roll while this was active.",
                    Duration = 5,
                    Image = "alert-triangle",
                })
            end
        end)
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
print("[AutoRoll v8] Loaded")
