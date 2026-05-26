-- ================================================
-- Anime Power Defense (APD) Auto Farm Script
-- GameId: 5787561793
-- ================================================

if not game:IsLoaded() then game.Loaded:Wait() end
if game.GameId ~= 5787561793 then return end

-- ================================================
-- Services
-- ================================================
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")

local Player = Players.LocalPlayer

-- ================================================
-- Remotes
-- ================================================
local GameEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Game")

local RF = ReplicatedStorage
    :WaitForChild("Modules")
    :WaitForChild("Packages")
    :WaitForChild("Knit")
    :WaitForChild("Services")
    :WaitForChild("GameService")
    :WaitForChild("RF")

local GetPlacedUnitsRF = RF:WaitForChild("GetPlacedUnits")
local VoteSkipWaveRF   = RF:WaitForChild("VoteSkipWave")
local SellUnitRF       = RF:WaitForChild("SellUnit")
local SetGamespeedRF   = RF:WaitForChild("SetGamespeed")

-- ================================================
-- Remote Wrappers
-- ================================================
local function GetPlacedUnits()
    return GetPlacedUnitsRF:InvokeServer()
end

local function UpgradeUnit(guid)
    GameEvent:FireServer("UpgradeUnit", guid)
end

local function SellUnit(guid)
    SellUnitRF:InvokeServer(guid)
end

local function VoteSkipWave()
    VoteSkipWaveRF:InvokeServer()
end

local function SetGamespeed(speed)
    SetGamespeedRF:InvokeServer(speed)
end

local function Replay()
    GameEvent:FireServer("Retry")
end

-- ================================================
-- Folder + Settings
-- ================================================
if not isfolder("KarmaPanda") then makefolder("KarmaPanda") end
if not isfolder("KarmaPanda\\APD") then makefolder("KarmaPanda\\APD") end
if not isfolder("KarmaPanda\\APD\\Settings") then makefolder("KarmaPanda\\APD\\Settings") end

local SettingsFile = "KarmaPanda\\APD\\Settings\\" .. Player.UserId .. ".json"

local DefaultSettings = {
    auto_upgrade    = false,
    auto_skip_wave  = false,
    auto_replay     = false,
    auto_gamespeed  = false,
    gamespeed       = 1.5,
    upgrade_delay   = 0.5,
    skip_delay      = 3,
    auto_execute    = false,
}

local Settings = {}
for k, v in pairs(DefaultSettings) do Settings[k] = v end

local function Save()
    pcall(function()
        writefile(SettingsFile, HttpService:JSONEncode(Settings))
    end)
end

local function Load()
    if isfile(SettingsFile) then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(SettingsFile))
        end)
        if ok and data then
            for k, v in pairs(data) do
                if DefaultSettings[k] ~= nil then Settings[k] = v end
            end
        end
    end
end

Load()

-- ================================================
-- Loop State
-- ================================================
local Loops = {
    auto_upgrade   = false,
    auto_skip_wave = false,
    auto_replay    = false,
}

-- ================================================
-- Core Logic
-- ================================================

local function StartAutoUpgrade()
    if Loops.auto_upgrade then return end
    Loops.auto_upgrade = true
    task.spawn(function()
        while Settings.auto_upgrade do
            local ok, placed = pcall(GetPlacedUnits)
            if ok and placed then
                for guid, unitData in pairs(placed) do
                    if not Settings.auto_upgrade then break end
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
                        task.wait(Settings.upgrade_delay)
                    end
                end
            end
            task.wait(1)
        end
        Loops.auto_upgrade = false
    end)
end

local function SellAllUnits()
    task.spawn(function()
        local ok, placed = pcall(GetPlacedUnits)
        if ok and placed then
            for guid, _ in pairs(placed) do
                pcall(SellUnit, guid)
                task.wait(0.3)
            end
        end
    end)
end

local function StartAutoSkipWave()
    if Loops.auto_skip_wave then return end
    Loops.auto_skip_wave = true
    task.spawn(function()
        while Settings.auto_skip_wave do
            pcall(VoteSkipWave)
            task.wait(Settings.skip_delay)
        end
        Loops.auto_skip_wave = false
    end)
end

local function StartAutoReplay()
    if Loops.auto_replay then return end
    Loops.auto_replay = true
    task.spawn(function()
        while Settings.auto_replay do
            pcall(Replay)
            task.wait(5)
        end
        Loops.auto_replay = false
    end)
end

-- ================================================
-- Rayfield UI  (fixed URL -- no line breaks)
-- ================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name             = "Anime Power Defense Script",
    LoadingTitle     = "Anime Power Defense",
    LoadingSubtitle  = "Auto Farm",
    LoadingVersion   = "v1.2",
    ConfigurationSaving = { Enabled = false },
    KeySystem        = false,
})

-- ================================================
-- TAB: Auto Farm
-- ================================================
local FarmTab     = Window:CreateTab("Auto Farm", 4483362458)
local FarmSection = FarmTab:CreateSection("Farm")

FarmTab:CreateToggle({
    Name         = "Auto Upgrade Units",
    Info         = "Continuously upgrades all placed units to max level.",
    CurrentValue = Settings.auto_upgrade,
    Callback     = function(value)
        Settings.auto_upgrade = value
        Save()
        if value then StartAutoUpgrade() end
    end,
    SectionParent = FarmSection,
})

FarmTab:CreateButton({
    Name     = "Sell All Units Now",
    Callback = function()
        SellAllUnits()
        Rayfield:Notify({
            Title    = "Sell All",
            Content  = "Selling all placed units...",
            Duration = 3,
            Image    = 4483362458,
        })
    end,
    SectionParent = FarmSection,
})

local DelaySection = FarmTab:CreateSection("Delays")

FarmTab:CreateSlider({
    Name         = "Upgrade Delay (s)",
    Info         = "Time between each upgrade call.",
    Range        = {0.1, 5},
    Increment    = 0.1,
    Suffix       = "s",
    CurrentValue = Settings.upgrade_delay,
    Callback     = function(value)
        Settings.upgrade_delay = value
        Save()
    end,
    SectionParent = DelaySection,
})

-- ================================================
-- TAB: Wave
-- ================================================
local WaveTab     = Window:CreateTab("Wave", 4483362458)
local WaveSection = WaveTab:CreateSection("Wave Control")

WaveTab:CreateToggle({
    Name         = "Auto Skip Wave",
    Info         = "Votes to skip waves automatically.",
    CurrentValue = Settings.auto_skip_wave,
    Callback     = function(value)
        Settings.auto_skip_wave = value
        Save()
        if value then StartAutoSkipWave() end
    end,
    SectionParent = WaveSection,
})

WaveTab:CreateSlider({
    Name         = "Skip Interval (s)",
    Info         = "How often to vote skip.",
    Range        = {1, 10},
    Increment    = 0.5,
    Suffix       = "s",
    CurrentValue = Settings.skip_delay,
    Callback     = function(value)
        Settings.skip_delay = value
        Save()
    end,
    SectionParent = WaveSection,
})

WaveTab:CreateButton({
    Name     = "Skip Wave Now",
    Callback = function()
        pcall(VoteSkipWave)
        Rayfield:Notify({
            Title    = "Wave Skip",
            Content  = "Vote skip sent!",
            Duration = 2,
            Image    = 4483362458,
        })
    end,
    SectionParent = WaveSection,
})

local SpeedSection = WaveTab:CreateSection("Game Speed")

WaveTab:CreateToggle({
    Name         = "Auto Set Gamespeed",
    Info         = "Sets gamespeed automatically on load.",
    CurrentValue = Settings.auto_gamespeed,
    Callback     = function(value)
        Settings.auto_gamespeed = value
        Save()
        if value then pcall(SetGamespeed, Settings.gamespeed) end
    end,
    SectionParent = SpeedSection,
})

WaveTab:CreateSlider({
    Name         = "Gamespeed",
    Info         = "1 = normal, 1.5 = fast, 2 = max.",
    Range        = {1, 2},
    Increment    = 0.5,
    Suffix       = "x",
    CurrentValue = Settings.gamespeed,
    Callback     = function(value)
        Settings.gamespeed = value
        Save()
        if Settings.auto_gamespeed then pcall(SetGamespeed, value) end
    end,
    SectionParent = SpeedSection,
})

WaveTab:CreateButton({
    Name     = "Set Speed Now",
    Callback = function()
        pcall(SetGamespeed, Settings.gamespeed)
        Rayfield:Notify({
            Title    = "Gamespeed",
            Content  = "Speed set to " .. Settings.gamespeed .. "x",
            Duration = 2,
            Image    = 4483362458,
        })
    end,
    SectionParent = SpeedSection,
})

-- ================================================
-- TAB: Replay
-- ================================================
local ReplayTab     = Window:CreateTab("Replay", 4483362458)
local ReplaySection = ReplayTab:CreateSection("Auto Replay")

ReplayTab:CreateToggle({
    Name         = "Auto Replay",
    Info         = "Automatically retries the game after it ends.",
    CurrentValue = Settings.auto_replay,
    Callback     = function(value)
        Settings.auto_replay = value
        Save()
        if value then StartAutoReplay() end
    end,
    SectionParent = ReplaySection,
})

ReplayTab:CreateButton({
    Name     = "Replay Now",
    Callback = function()
        pcall(Replay)
        Rayfield:Notify({
            Title    = "Replay",
            Content  = "Retry fired!",
            Duration = 2,
            Image    = 4483362458,
        })
    end,
    SectionParent = ReplaySection,
})

-- ================================================
-- TAB: Settings
-- ================================================
local SettingsTab  = Window:CreateTab("Settings", 4483362458)
local MiscSection  = SettingsTab:CreateSection("Misc")

SettingsTab:CreateToggle({
    Name         = "Auto Execute",
    Info         = "Re-runs this script automatically on teleport. Replace the URL inside the script first.",
    CurrentValue = Settings.auto_execute,
    Callback     = function(value)
        Settings.auto_execute = value
        Save()
        if value and not _G.apd_auto_executed then
            _G.apd_auto_executed = true
            -- Replace YOUR_SCRIPT_URL_HERE with the raw URL where you host this script
            -- queue_on_teleport(game:HttpGet("YOUR_SCRIPT_URL_HERE"))
            Rayfield:Notify({
                Title    = "Auto Execute",
                Content  = "Replace YOUR_SCRIPT_URL_HERE in the script to enable this.",
                Duration = 5,
                Image    = 4483362458,
            })
        end
    end,
    SectionParent = MiscSection,
})

SettingsTab:CreateButton({
    Name     = "Reset to Defaults",
    Callback = function()
        for k, v in pairs(DefaultSettings) do Settings[k] = v end
        Save()
        Rayfield:Notify({
            Title    = "Reset",
            Content  = "Settings restored to default!",
            Duration = 3,
            Image    = 4483362458,
        })
    end,
    SectionParent = MiscSection,
})

-- ================================================
-- TAB: Credits
-- ================================================
local CreditsTab = Window:CreateTab("Credits", 4483362458)
local CreditsSection = CreditsTab:CreateSection("Credits")
CreditsTab:CreateParagraph({
    Title   = "Anime Power Defense Script v1.2",
    Content = "Remote paths reverse engineered via remote spy on GameId 5787561793. UI powered by Rayfield (sirius.menu/rayfield).",
    SectionParent = CreditsSection,
})

-- ================================================
-- Apply settings on load
-- ================================================
task.spawn(function()
    task.wait(2)
    if Settings.auto_gamespeed  then pcall(SetGamespeed, Settings.gamespeed) end
    if Settings.auto_skip_wave  then StartAutoSkipWave() end
    if Settings.auto_upgrade    then StartAutoUpgrade()  end
    if Settings.auto_replay     then StartAutoReplay()   end
end)

print("[APD Script] v1.2 loaded successfully!")
