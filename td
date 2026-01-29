-- TD MACRO SYSTEM (LEGIT / OWN GAME)
-- LocalScript

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local PlaceTower = ReplicatedStorage:WaitForChild("PlaceTower")

------------------------------------------------
-- STATE
------------------------------------------------
local macro = {}
local recording = false
local playing = false
local lastTime = 0

------------------------------------------------
-- GUI
------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "MacroGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function button(text, x)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromScale(0.25, 0.08)
	b.Position = UDim2.fromScale(x, 0.85)
	b.BackgroundColor3 = Color3.fromRGB(40,40,40)
	b.TextColor3 = Color3.new(1,1,1)
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.Parent = gui
	return b
end

local recordBtn = button("⏺ RECORD", 0.05)
local stopBtn   = button("⏹ STOP",   0.37)
local playBtn   = button("▶ PLAY",   0.69)

------------------------------------------------
-- RAYCAST (CAMERA INDEPENDENT)
------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Blacklist
rayParams.FilterDescendantsInstances = {player.Character}

local function screenToWorld(pos)
	local ray = camera:ViewportPointToRay(pos.X, pos.Y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, rayParams)
	return result and result.Position
end

------------------------------------------------
-- RECORD TOUCH
------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp or not recording then return end
	if input.UserInputType ~= Enum.UserInputType.Touch then return end

	local worldPos = screenToWorld(input.Position)
	if not worldPos then return end

	local now = tick()
	table.insert(macro, {
		delay = now - lastTime,
		position = worldPos
	})
	lastTime = now
end)

------------------------------------------------
-- BUTTON LOGIC
------------------------------------------------
recordBtn.MouseButton1Click:Connect(function()
	macro = {}
	recording = true
	lastTime = tick()
	warn("Recording macro")
end)

stopBtn.MouseButton1Click:Connect(function()
	recording = false
	warn("Stopped recording")
end)

playBtn.MouseButton1Click:Connect(function()
	if playing or #macro == 0 then return end
	playing = true
	warn("Playing macro")

	for _, action in ipairs(macro) do
		task.wait(action.delay)
		PlaceTower:FireServer(action.position)
	end

	playing = false
	warn("Macro finished")
end)
