-- ================================================
-- Anime Power Defense - Macro Recorder v2.0
-- GameId: 5787561793
-- ================================================

if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 5787561793 then return end

-- ================================================
-- Services
-- ================================================
local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local HttpService           = game:GetService("HttpService")
local UserInputService      = game:GetService("UserInputService")
local VirtualInputManager   = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer

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

local function GetPlacedUnits() return GetPlacedUnitsRF:InvokeServer() end
local function UpgradeUnit(guid) GameEvent:FireServer("UpgradeUnit", guid) end
local function SellUnit(guid) SellUnitRF:InvokeServer(guid) end
local function VoteSkipWave() VoteSkipWaveRF:InvokeServer() end
local function SetGamespeed(speed) SetGamespeedRF:InvokeServer(speed) end
local function Replay() GameEvent:FireServer("Retry") end

-- ================================================
-- Folder Setup
-- ================================================
if not isfolder("KarmaPanda") then makefolder("KarmaPanda") end
if not isfolder("KarmaPanda\\APD") then makefolder("KarmaPanda\\APD") end
if not isfolder("KarmaPanda\\APD\\Macros") then makefolder("KarmaPanda\\APD\\Macros") end
if not isfolder("KarmaPanda\\APD\\Settings") then makefolder("KarmaPanda\\APD\\Settings") end

-- ================================================
-- Macro Engine
-- ================================================
local MacroEngine = {
    IsRecording  = false,
    IsPlaying    = false,
    CurrentMacro = nil,   -- name of currently loaded macro
    Actions      = {},    -- { type, data, timestamp }
    StartTime    = 0,
    Speed        = 1,
}

-- Save a macro to file
function MacroEngine:Save(name)
    local data = {
        name    = name,
        actions = self.Actions,
        saved   = os.time(),
    }
    writefile("KarmaPanda\\APD\\Macros\\" .. name .. ".json", HttpService:JSONEncode(data))
end

-- Load a macro from file
function MacroEngine:Load(name)
    local path = "KarmaPanda\\APD\\Macros\\" .. name .. ".json"
    if isfile(path) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
        if ok and data then
            self.Actions      = data.actions or {}
            self.CurrentMacro = name
            return true
        end
    end
    return false
end

-- Delete a macro file
function MacroEngine:Delete(name)
    local path = "KarmaPanda\\APD\\Macros\\" .. name .. ".json"
    if isfile(path) then delfile(path) end
end

-- List all saved macros
function MacroEngine:List()
    local files = listfiles("KarmaPanda\\APD\\Macros")
    local names = {}
    for _, f in pairs(files) do
        local name = f:match("([^\\]+)%.json$")
        if name then table.insert(names, name) end
    end
    return names
end

-- Record an action
function MacroEngine:RecordAction(actionType, data)
    if not self.IsRecording then return end
    table.insert(self.Actions, {
        type      = actionType,
        data      = data,
        timestamp = tick() - self.StartTime,
    })
end

-- Start recording
function MacroEngine:StartRecording()
    self.IsRecording = true
    self.IsPlaying   = false
    self.Actions     = {}
    self.StartTime   = tick()
end

-- Stop recording
function MacroEngine:StopRecording()
    self.IsRecording = false
end

-- Play back recorded actions, looping forever until stopped
function MacroEngine:StartPlayback(onAction, onLoop, onStop)
    if self.IsPlaying then return end
    if #self.Actions == 0 then return end
    self.IsPlaying = true

    task.spawn(function()
        local loopCount = 0
        while self.IsPlaying do
            loopCount = loopCount + 1
            if onLoop then onLoop(loopCount) end

            for _, action in ipairs(self.Actions) do
                if not self.IsPlaying then break end

                -- Wait for the recorded delay between actions
                task.wait(action.timestamp / self.Speed)

                if not self.IsPlaying then break end

                -- Execute action
                if action.type == "click" then
                    local x, y = action.data[1], action.data[2]
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)

                elseif action.type == "touch" then
                    local x, y = action.data[1], action.data[2]
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
                    task.wait(0.05)
                    VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)

                elseif action.type == "upgrade_all" then
                    local ok, placed = pcall(GetPlacedUnits)
                    if ok and placed then
                        for guid, unitData in pairs(placed) do
                            local unitId = tostring(unitData.Type)
                            local upgradeLevel = 0
                            local maxUpgrades  = 0
                            if unitData.Info and unitData.Info[unitId] then
                                upgradeLevel = unitData.Info[unitId].Upgrade or 0
                                if unitData.Info[unitId].Data and unitData.Info[unitId].Data.upgrades then
                                    maxUpgrades = #unitData.Info[unitId].Data.upgrades
                                end
                            end
                            if upgradeLevel < maxUpgrades then
                                pcall(UpgradeUnit, guid)
                                task.wait(0.3)
                            end
                        end
                    end

                elseif action.type == "sell_all" then
                    local ok, placed = pcall(GetPlacedUnits)
                    if ok and placed then
                        for guid, _ in pairs(placed) do
                            pcall(SellUnit, guid)
                            task.wait(0.3)
                        end
                    end

                elseif action.type == "skip_wave" then
                    pcall(VoteSkipWave)

                elseif action.type == "replay" then
                    pcall(Replay)

                elseif action.type == "set_speed" then
                    pcall(SetGamespeed, action.data[1])

                elseif action.type == "wait" then
                    task.wait(action.data[1])
                end

                if onAction then onAction(action) end
            end

            -- Small gap between loops
            if self.IsPlaying then task.wait(0.5) end
        end

        if onStop then onStop() end
    end)
end

-- Stop playback
function MacroEngine:StopPlayback()
    self.IsPlaying = false
end

-- ================================================
-- Input Capture (clicks + touch for recording)
-- ================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not MacroEngine.IsRecording then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mouse = Player:GetMouse()
        MacroEngine:RecordAction("click", {mouse.X, mouse.Y})
    end
end)

if UserInputService.TouchEnabled then
    UserInputService.TouchStarted:Connect(function(touch, gameProcessed)
        if not MacroEngine.IsRecording then return end
        MacroEngine:RecordAction("touch", {touch.Position.X, touch.Position.Y})
    end)
end

-- ================================================
-- General Settings
-- ================================================
local SettingsFile = "KarmaPanda\\APD\\Settings\\" .. Player.UserId .. ".json"
local Settings = {
    auto_gamespeed = false,
    gamespeed      = 1.5,
    auto_execute   = false,
    macro_speed    = 1,
}

local function SaveSettings()
    pcall(function() writefile(SettingsFile, HttpService:JSONEncode(Settings)) end)
end

local function LoadSettings()
    if isfile(SettingsFile) then
        local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SettingsFile)) end)
        if ok and data then
            for k, v in pairs(data) do Settings[k] = v end
        end
    end
end

LoadSettings()
MacroEngine.Speed = Settings.macro_speed or 1

-- ================================================
-- Rayfield UI
-- ================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name            = "APD Macro Script",
    LoadingTitle    = "Anime Power Defense",
    LoadingSubtitle = "Macro Recorder v2.0",
    LoadingVersion  = "v2.0",
    ConfigurationSaving = { Enabled = false },
    KeySystem       = false,
})

-- ================================================
-- State tracked for UI
-- ================================================
local currentMacroName    = ""
local actionCountRef      = nil  -- label reference updated during recording
local statusLabelRef      = nil  -- label reference updated during playback
local macroListRef        = {}   -- dropdown reference

-- Helper: refresh macro dropdown options
local function GetMacroOptions()
    local list = MacroEngine:List()
    if #list == 0 then return {"(No macros saved)"} end
    return list
end

-- ================================================
-- TAB: Macro Recorder
-- ================================================
local MacroTab     = Window:CreateTab("Macro", 4483362458)
local RecSection   = MacroTab:CreateSection("Record")

-- Macro name input
MacroTab:CreateInput({
    Name        = "Macro Name",
    Info        = "Name for this macro profile. Set before recording.",
    PlaceholderText = "e.g. Wave1Farm",
    RemoveTextAfterFocusLost = false,
    Callback    = function(value)
        currentMacroName = value
    end,
    SectionParent = RecSection,
})

-- Record button
MacroTab:CreateButton({
    Name     = "🔴 Start Recording",
    Callback = function()
        if MacroEngine.IsRecording then
            -- Stop recording
            MacroEngine:StopRecording()
            Rayfield:Notify({
                Title    = "Recording Stopped",
                Content  = #MacroEngine.Actions .. " actions recorded. Save it below!",
                Duration = 4,
                Image    = 4483362458,
            })
        else
            -- Start recording
            MacroEngine:StartRecording()
            Rayfield:Notify({
                Title    = "Recording Started",
                Content  = "All clicks, touches and manual actions are now being captured.",
                Duration = 3,
                Image    = 4483362458,
            })
        end
    end,
    SectionParent = RecSection,
})

-- Record manual APD actions during recording session
local ActSection = MacroTab:CreateSection("Record APD Actions")

MacroTab:CreateButton({
    Name     = "📌 Record: Upgrade All",
    Callback = function()
        MacroEngine:RecordAction("upgrade_all", {})
        Rayfield:Notify({ Title = "Recorded", Content = "Upgrade All action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

MacroTab:CreateButton({
    Name     = "📌 Record: Sell All",
    Callback = function()
        MacroEngine:RecordAction("sell_all", {})
        Rayfield:Notify({ Title = "Recorded", Content = "Sell All action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

MacroTab:CreateButton({
    Name     = "📌 Record: Skip Wave",
    Callback = function()
        MacroEngine:RecordAction("skip_wave", {})
        Rayfield:Notify({ Title = "Recorded", Content = "Skip Wave action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

MacroTab:CreateButton({
    Name     = "📌 Record: Replay Game",
    Callback = function()
        MacroEngine:RecordAction("replay", {})
        Rayfield:Notify({ Title = "Recorded", Content = "Replay action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

MacroTab:CreateButton({
    Name     = "📌 Record: Wait 3 Seconds",
    Callback = function()
        MacroEngine:RecordAction("wait", {3})
        Rayfield:Notify({ Title = "Recorded", Content = "Wait 3s action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

MacroTab:CreateButton({
    Name     = "📌 Record: Wait 5 Seconds",
    Callback = function()
        MacroEngine:RecordAction("wait", {5})
        Rayfield:Notify({ Title = "Recorded", Content = "Wait 5s action added.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = ActSection,
})

-- Save section
local SaveSection = MacroTab:CreateSection("Save / Load")

MacroTab:CreateButton({
    Name     = "💾 Save Macro",
    Callback = function()
        if currentMacroName == "" then
            Rayfield:Notify({ Title = "Error", Content = "Enter a macro name first!", Duration = 3, Image = 4483362458 })
            return
        end
        if #MacroEngine.Actions == 0 then
            Rayfield:Notify({ Title = "Error", Content = "No actions recorded yet!", Duration = 3, Image = 4483362458 })
            return
        end
        MacroEngine:Save(currentMacroName)
        Rayfield:Notify({
            Title   = "Saved!",
            Content = "Macro '" .. currentMacroName .. "' saved with " .. #MacroEngine.Actions .. " actions.",
            Duration = 4,
            Image   = 4483362458,
        })
    end,
    SectionParent = SaveSection,
})

MacroTab:CreateButton({
    Name     = "🗑️ Delete Current Macro",
    Callback = function()
        if currentMacroName == "" then
            Rayfield:Notify({ Title = "Error", Content = "Enter the macro name to delete.", Duration = 3, Image = 4483362458 })
            return
        end
        MacroEngine:Delete(currentMacroName)
        Rayfield:Notify({ Title = "Deleted", Content = "Macro '" .. currentMacroName .. "' deleted.", Duration = 3, Image = 4483362458 })
    end,
    SectionParent = SaveSection,
})

-- ================================================
-- TAB: Profiles (select + play macros)
-- ================================================
local ProfileTab     = Window:CreateTab("Profiles", 4483362458)
local ProfileSection = ProfileTab:CreateSection("Select Macro Profile")

-- Dropdown to pick a saved macro
ProfileTab:CreateDropdown({
    Name    = "Select Macro",
    Options = GetMacroOptions(),
    CurrentOption = GetMacroOptions()[1] or "(No macros saved)",
    Info    = "Choose a saved macro profile to load and play.",
    Callback = function(value)
        if value == "(No macros saved)" then return end
        local loaded = MacroEngine:Load(value)
        if loaded then
            currentMacroName = value
            Rayfield:Notify({
                Title   = "Profile Loaded",
                Content = "'" .. value .. "' loaded — " .. #MacroEngine.Actions .. " actions.",
                Duration = 3,
                Image   = 4483362458,
            })
        else
            Rayfield:Notify({ Title = "Error", Content = "Could not load macro.", Duration = 3, Image = 4483362458 })
        end
    end,
    SectionParent = ProfileSection,
})

-- Playback section
local PlaySection = ProfileTab:CreateSection("Playback")

ProfileTab:CreateSlider({
    Name         = "Playback Speed",
    Info         = "1 = normal speed, 2 = 2x faster, 0.5 = slower.",
    Range        = {0.5, 5},
    Increment    = 0.5,
    Suffix       = "x",
    CurrentValue = Settings.macro_speed,
    Callback     = function(value)
        MacroEngine.Speed    = value
        Settings.macro_speed = value
        SaveSettings()
    end,
    SectionParent = PlaySection,
})

ProfileTab:CreateButton({
    Name     = "▶️ Play Macro (Loop Forever)",
    Callback = function()
        if #MacroEngine.Actions == 0 then
            Rayfield:Notify({ Title = "Error", Content = "No macro loaded! Go to Profiles and select one first.", Duration = 4, Image = 4483362458 })
            return
        end
        if MacroEngine.IsPlaying then
            Rayfield:Notify({ Title = "Already Playing", Content = "Stop the current macro first.", Duration = 3, Image = 4483362458 })
            return
        end
        local loopNum = 0
        MacroEngine:StartPlayback(
            nil, -- onAction
            function(loop) -- onLoop
                loopNum = loop
            end,
            function() -- onStop
                Rayfield:Notify({ Title = "Macro Stopped", Content = "Macro ended after " .. loopNum .. " loops.", Duration = 3, Image = 4483362458 })
            end
        )
        Rayfield:Notify({
            Title   = "▶️ Playing",
            Content = "Macro '" .. (currentMacroName ~= "" and currentMacroName or "unnamed") .. "' is looping. Press Stop to end.",
            Duration = 4,
            Image   = 4483362458,
        })
    end,
    SectionParent = PlaySection,
})

ProfileTab:CreateButton({
    Name     = "⏹️ Stop Macro",
    Callback = function()
        MacroEngine:StopPlayback()
        Rayfield:Notify({ Title = "Stopped", Content = "Macro playback stopped.", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = PlaySection,
})

-- Info section
local InfoSection = ProfileTab:CreateSection("Saved Macros")

ProfileTab:CreateButton({
    Name     = "🔄 Refresh Macro List",
    Callback = function()
        local list = MacroEngine:List()
        local names = table.concat(list, ", ")
        Rayfield:Notify({
            Title   = "Saved Macros (" .. #list .. ")",
            Content = #list > 0 and names or "No macros saved yet.",
            Duration = 5,
            Image   = 4483362458,
        })
    end,
    SectionParent = InfoSection,
})

-- ================================================
-- TAB: Quick Actions (manual one-shots)
-- ================================================
local QuickTab     = Window:CreateTab("Quick", 4483362458)
local QuickSection = QuickTab:CreateSection("One-Shot Actions")

QuickTab:CreateButton({
    Name     = "⬆️ Upgrade All Units Now",
    Callback = function()
        task.spawn(function()
            local ok, placed = pcall(GetPlacedUnits)
            if ok and placed then
                for guid, unitData in pairs(placed) do
                    local unitId = tostring(unitData.Type)
                    local upgradeLevel = 0
                    local maxUpgrades  = 0
                    if unitData.Info and unitData.Info[unitId] then
                        upgradeLevel = unitData.Info[unitId].Upgrade or 0
                        if unitData.Info[unitId].Data and unitData.Info[unitId].Data.upgrades then
                            maxUpgrades = #unitData.Info[unitId].Data.upgrades
                        end
                    end
                    if upgradeLevel < maxUpgrades then
                        pcall(UpgradeUnit, guid)
                        task.wait(0.3)
                    end
                end
            end
        end)
        Rayfield:Notify({ Title = "Upgrading", Content = "Upgrading all placed units...", Duration = 3, Image = 4483362458 })
    end,
    SectionParent = QuickSection,
})

QuickTab:CreateButton({
    Name     = "💰 Sell All Units Now",
    Callback = function()
        task.spawn(function()
            local ok, placed = pcall(GetPlacedUnits)
            if ok and placed then
                for guid, _ in pairs(placed) do
                    pcall(SellUnit, guid)
                    task.wait(0.3)
                end
            end
        end)
        Rayfield:Notify({ Title = "Selling", Content = "Selling all placed units...", Duration = 3, Image = 4483362458 })
    end,
    SectionParent = QuickSection,
})

QuickTab:CreateButton({
    Name     = "⏭️ Skip Wave Now",
    Callback = function()
        pcall(VoteSkipWave)
        Rayfield:Notify({ Title = "Wave Skip", Content = "Vote skip sent!", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = QuickSection,
})

QuickTab:CreateButton({
    Name     = "🔁 Replay Now",
    Callback = function()
        pcall(Replay)
        Rayfield:Notify({ Title = "Replay", Content = "Retry fired!", Duration = 2, Image = 4483362458 })
    end,
    SectionParent = QuickSection,
})

local SpeedSection = QuickTab:CreateSection("Game Speed")

QuickTab:CreateToggle({
    Name         = "Auto Set Gamespeed",
    CurrentValue = Settings.auto_gamespeed,
    Callback     = function(value)
        Settings.auto_gamespeed = value
        SaveSettings()
        if value then pcall(SetGamespeed, Settings.gamespeed) end
    end,
    SectionParent = SpeedSection,
})

QuickTab:CreateSlider({
    Name         = "Gamespeed",
    Range        = {1, 2},
    Increment    = 0.5,
    Suffix       = "x",
    CurrentValue = Settings.gamespeed,
    Callback     = function(value)
        Settings.gamespeed = value
        SaveSettings()
        if Settings.auto_gamespeed then pcall(SetGamespeed, value) end
    end,
    SectionParent = SpeedSection,
})

-- ================================================
-- TAB: Settings
-- ================================================
local SettingsTab  = Window:CreateTab("Settings", 4483362458)
local MiscSection  = SettingsTab:CreateSection("Misc")

SettingsTab:CreateToggle({
    Name         = "Auto Execute on Teleport",
    Info         = "Re-runs this script on teleport. Replace YOUR_SCRIPT_URL in the script.",
    CurrentValue = Settings.auto_execute,
    Callback     = function(value)
        Settings.auto_execute = value
        SaveSettings()
        if value and not _G.apd_macro_executed then
            _G.apd_macro_executed = true
            -- queue_on_teleport(game:HttpGet("YOUR_SCRIPT_URL_HERE"))
            Rayfield:Notify({ Title = "Auto Execute", Content = "Replace YOUR_SCRIPT_URL_HERE in the script to activate this.", Duration = 5, Image = 4483362458 })
        end
    end,
    SectionParent = MiscSection,
})

SettingsTab:CreateButton({
    Name     = "Reset Settings",
    Callback = function()
        Settings = { auto_gamespeed = false, gamespeed = 1.5, auto_execute = false, macro_speed = 1 }
        MacroEngine.Speed = 1
        SaveSettings()
        Rayfield:Notify({ Title = "Reset", Content = "Settings restored to default.", Duration = 3, Image = 4483362458 })
    end,
    SectionParent = MiscSection,
})

-- ================================================
-- TAB: Credits
-- ================================================
local CreditsTab = Window:CreateTab("Credits", 4483362458)
CreditsTab:CreateSection("Credits"):Name = "Credits"
CreditsTab:CreateParagraph({
    Title   = "APD Macro Script v2.0",
    Content = "Macro recorder with profile saving. Click/touch recording + APD remote actions (upgrade, sell, skip, replay). Profiles saved to KarmaPanda/APD/Macros/. UI: Rayfield (sirius.menu/rayfield).",
})

-- ================================================
-- Apply settings on load
-- ================================================
task.spawn(function()
    task.wait(2)
    if Settings.auto_gamespeed then pcall(SetGamespeed, Settings.gamespeed) end
end)

print("[APD Macro Script] v2.0 loaded!")
