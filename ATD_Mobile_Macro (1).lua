--// Anime Tower Defense Mobile Macro
--// Put inside StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

--// SETTINGS
local DEFAULT_DELAY = 0.3

--// STATES
local recording = false
local playing = false
local minimized = false
local loopEnabled = false

local actions = {}

--////////////////////////////////////////////////////
-- GUI
--////////////////////////////////////////////////////

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ATDMobileMacro"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = guiParent

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 340, 0, 300)
Main.Position = UDim2.new(0.03, 0, 0.2, 0)
Main.BackgroundColor3 = Color3.fromRGB(20,20,20)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0,12)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,0,0,40)
Title.BackgroundTransparency = 1
Title.Text = "Anime Tower Defense Macro"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.new(1,1,1)
Title.Parent = Main

local Status = Instance.new("TextLabel")
Status.Position = UDim2.new(0,0,0,35)
Status.Size = UDim2.new(1,0,0,25)
Status.BackgroundTransparency = 1
Status.Text = "Idle"
Status.Font = Enum.Font.Gotham
Status.TextColor3 = Color3.fromRGB(0,255,100)
Status.TextSize = 14
Status.Parent = Main

local LogBox = Instance.new("TextBox")
LogBox.Position = UDim2.new(0.05,0,0.22,0)
LogBox.Size = UDim2.new(0.9,0,0.3,0)
LogBox.BackgroundColor3 = Color3.fromRGB(35,35,35)
LogBox.TextColor3 = Color3.new(1,1,1)
LogBox.Font = Enum.Font.Code
LogBox.TextSize = 14
LogBox.MultiLine = true
LogBox.ClearTextOnFocus = false
LogBox.TextEditable = false
LogBox.TextWrapped = false
LogBox.TextYAlignment = Enum.TextYAlignment.Top
LogBox.Text = ""
LogBox.Parent = Main

Instance.new("UICorner", LogBox).CornerRadius = UDim.new(0,8)

local DelayLabel = Instance.new("TextLabel")
DelayLabel.Position = UDim2.new(0.05,0,0.55,0)
DelayLabel.Size = UDim2.new(0.3,0,0,25)
DelayLabel.BackgroundTransparency = 1
DelayLabel.Text = "Delay:"
DelayLabel.TextColor3 = Color3.new(1,1,1)
DelayLabel.Font = Enum.Font.GothamBold
DelayLabel.TextSize = 14
DelayLabel.Parent = Main

local DelayBox = Instance.new("TextBox")
DelayBox.Position = UDim2.new(0.25,0,0.55,0)
DelayBox.Size = UDim2.new(0.2,0,0,28)
DelayBox.BackgroundColor3 = Color3.fromRGB(40,40,40)
DelayBox.TextColor3 = Color3.new(1,1,1)
DelayBox.Font = Enum.Font.Gotham
DelayBox.TextSize = 14
DelayBox.Text = tostring(DEFAULT_DELAY)
DelayBox.Parent = Main

Instance.new("UICorner", DelayBox).CornerRadius = UDim.new(0,8)

local function createButton(text, pos, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.27,0,0,40)
	btn.Position = pos
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.new(1,1,1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = Main

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

	return btn
end

local RecordBtn = createButton(
	"Record",
	UDim2.new(0.05,0,0.67,0),
	Color3.fromRGB(255,170,0)
)

local StopRecordBtn = createButton(
	"Stop Rec",
	UDim2.new(0.365,0,0.67,0),
	Color3.fromRGB(255,80,80)
)

local PlayBtn = createButton(
	"Play",
	UDim2.new(0.68,0,0.67,0),
	Color3.fromRGB(0,170,255)
)

local StopBtn = createButton(
	"Stop",
	UDim2.new(0.05,0,0.84,0),
	Color3.fromRGB(255,70,70)
)

local ClearBtn = createButton(
	"Clear",
	UDim2.new(0.365,0,0.84,0),
	Color3.fromRGB(100,100,100)
)

local LoopBtn = createButton(
	"Loop OFF",
	UDim2.new(0.68,0,0.84,0),
	Color3.fromRGB(140,0,255)
)

local MiniBtn = Instance.new("TextButton")
MiniBtn.Size = UDim2.new(0,35,0,25)
MiniBtn.Position = UDim2.new(1,-40,0,8)
MiniBtn.Text = "-"
MiniBtn.Font = Enum.Font.GothamBold
MiniBtn.TextSize = 18
MiniBtn.TextColor3 = Color3.new(1,1,1)
MiniBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
MiniBtn.Parent = Main

Instance.new("UICorner", MiniBtn).CornerRadius = UDim.new(0,8)

local function log(text)
	LogBox.Text = LogBox.Text .. text .. "\n"
	LogBox.CursorPosition = #LogBox.Text
end

local function getDelay()
	local num = tonumber(DelayBox.Text)
	if num then
		return num
	end
	return DEFAULT_DELAY
end

local function simulateKey(key)
	VIM:SendKeyEvent(true, key, false, game)
	task.wait(0.05)
	VIM:SendKeyEvent(false, key, false, game)
end

RecordBtn.MouseButton1Click:Connect(function()
	actions = {}
	recording = true

	Status.Text = "Recording..."
	Status.TextColor3 = Color3.fromRGB(255,170,0)

	log("Started Recording")
end)

StopRecordBtn.MouseButton1Click:Connect(function()
	recording = false

	Status.Text = "Idle"
	Status.TextColor3 = Color3.fromRGB(0,255,100)

	log("Stopped Recording")
	log("Saved "..#actions.." actions")
end)

UIS.InputBegan:Connect(function(input, gp)
	if gp then return end

	if recording and input.UserInputType == Enum.UserInputType.Keyboard then

		local keyName = tostring(input.KeyCode):gsub("Enum.KeyCode.","")

		table.insert(actions,{
			key = input.KeyCode,
			name = keyName,
			delay = getDelay()
		})

		log("Captured: "..keyName)
	end
end)

local function playMacro()
	if #actions == 0 then
		log("No actions recorded")
		return
	end

	if playing then return end

	playing = true

	Status.Text = "Playing..."
	Status.TextColor3 = Color3.fromRGB(0,170,255)

	task.spawn(function()
		repeat
			for _,action in ipairs(actions) do

				if not playing then break end

				log("Executing: "..action.name)

				simulateKey(action.key)

				task.wait(action.delay)
			end

		until not loopEnabled or not playing

		playing = false

		Status.Text = "Idle"
		Status.TextColor3 = Color3.fromRGB(0,255,100)
	end)
end

PlayBtn.MouseButton1Click:Connect(function()
	playMacro()
end)

StopBtn.MouseButton1Click:Connect(function()
	playing = false

	Status.Text = "Stopped"
	Status.TextColor3 = Color3.fromRGB(255,70,70)

	log("Playback Stopped")
end)

ClearBtn.MouseButton1Click:Connect(function()
	actions = {}
	LogBox.Text = ""
	log("Cleared Macro")
end)

LoopBtn.MouseButton1Click:Connect(function()
	loopEnabled = not loopEnabled

	if loopEnabled then
		LoopBtn.Text = "Loop ON"
	else
		LoopBtn.Text = "Loop OFF"
	end
end)

MiniBtn.MouseButton1Click:Connect(function()
	minimized = not minimized

	if minimized then

		Main.Size = UDim2.new(0,340,0,40)

		Status.Visible = false
		LogBox.Visible = false
		DelayLabel.Visible = false
		DelayBox.Visible = false
		RecordBtn.Visible = false
		StopRecordBtn.Visible = false
		PlayBtn.Visible = false
		StopBtn.Visible = false
		ClearBtn.Visible = false
		LoopBtn.Visible = false

	else

		Main.Size = UDim2.new(0,340,0,300)

		Status.Visible = true
		LogBox.Visible = true
		DelayLabel.Visible = true
		DelayBox.Visible = true
		RecordBtn.Visible = true
		StopRecordBtn.Visible = true
		PlayBtn.Visible = true
		StopBtn.Visible = true
		ClearBtn.Visible = true
		LoopBtn.Visible = true
	end
end)

local dragging = false
local dragInput
local dragStart
local startPos

Title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
	or input.UserInputType == Enum.UserInputType.MouseButton1 then

		dragging = true
		dragStart = input.Position
		startPos = Main.Position

		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				dragging = false
			end
		end)
	end
end)

Title.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch
	or input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

UIS.InputChanged:Connect(function(input)
	if input == dragInput and dragging then

		local delta = input.Position - dragStart

		Main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end)

log("Mobile Macro Loaded")
log("Ready")
