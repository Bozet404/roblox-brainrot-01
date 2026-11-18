-- Brainrot Blast — client. Draws the HUD over the 3D world, binds the E key
-- with ContextActionService (so the default camera never eats it), fires the
-- server's RemoteEvents, and shows tsunami warnings and steal alerts.
-- No money or ownership is decided here; the server checks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local catchRemote = remotes:WaitForChild("CatchBrainrot")
local stealRemote = remotes:WaitForChild("StealBrainrot")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local notifyRemote = remotes:WaitForChild("Notify")
local statsRemote = remotes:WaitForChild("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local brainrotFolder = workspace:WaitForChild("Brainrots")

-- ---------------------------------------------------------------- HUD build

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function makeText(name, parent, pos, size, text, textSize, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = pos
	label.Size = size
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Font = font or Enum.Font.FredokaOne
	label.Parent = parent
	return label
end

local function makeButton(name, parent, pos, size, text, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.Text = text
	b.TextSize = 20
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.TextStrokeTransparency = 0.2
	b.Font = Enum.Font.FredokaOne
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = b
	return b
end

-- Top bar, centred, so the Roblox menu buttons in the top-left never cover it.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 8)
topBar.Size = UDim2.fromOffset(560, 64)
topBar.BackgroundColor3 = Color3.fromRGB(30, 25, 60)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

makeText("Title", topBar, UDim2.fromOffset(10, 2), UDim2.fromOffset(540, 24),
	"BRAINROT BLAST", 22, Color3.fromRGB(255, 230, 90))
local cashLabel = makeText("CashLabel", topBar, UDim2.fromOffset(10, 28),
	UDim2.fromOffset(260, 30), "Cash: $100", 20, Color3.fromRGB(140, 255, 140))
local rateLabel = makeText("RateLabel", topBar, UDim2.fromOffset(280, 28),
	UDim2.fromOffset(270, 30), "$0/detik  |  0 brainrot", 20,
	Color3.fromRGB(255, 255, 255))
local rebirthLabel = makeText("RebirthLabel", topBar, UDim2.fromOffset(10, 52),
	UDim2.fromOffset(540, 12), "Rebirth: 0  (x1.0)  -  butuh $10000", 12,
	Color3.fromRGB(200, 200, 255), Enum.Font.SourceSansBold)

-- Tsunami banner, hidden until the server warns us.
local tsunamiBanner = makeText("TsunamiBanner", gui, UDim2.new(0.5, 0, 0, 84),
	UDim2.fromOffset(560, 48), "", 26, Color3.fromRGB(255, 80, 80))
tsunamiBanner.AnchorPoint = Vector2.new(0.5, 0)
tsunamiBanner.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
tsunamiBanner.BackgroundTransparency = 0.2
tsunamiBanner.Visible = false

-- One-line alert in the middle of the screen; it hides itself after a while.
local alertLabel = makeText("AlertLabel", gui, UDim2.new(0.5, 0, 0.42, 0),
	UDim2.fromOffset(560, 34), "", 22, Color3.fromRGB(255, 255, 255))
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
alertLabel.BackgroundTransparency = 0.35
alertLabel.Visible = false

-- Catch / steal hint just above the bottom of the screen.
local promptLabel = makeText("PromptLabel", gui, UDim2.new(0.5, 0, 1, -120),
	UDim2.fromOffset(560, 30), "", 20, Color3.fromRGB(255, 240, 150))
promptLabel.AnchorPoint = Vector2.new(0.5, 0)
promptLabel.Visible = false

-- Buttons: Activated fires for a mouse click and for a touch tap alike.
local rebirthButton = makeButton("RebirthButton", gui,
	UDim2.new(1, -190, 0.5, -30), UDim2.fromOffset(170, 56),
	"REBIRTH", Color3.fromRGB(150, 60, 220))
local stealButton = makeButton("StealButton", gui,
	UDim2.new(1, -190, 0.5, 36), UDim2.fromOffset(170, 56),
	"CURI (E)", Color3.fromRGB(220, 60, 60))

local alertHideAt = 0
local function showAlert(text, seconds)
	alertLabel.Text = text
	alertLabel.Visible = true
	alertHideAt = os.clock() + (seconds or 4)
end

-- ------------------------------------------------------- finding brainrots

local function myRoot()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

-- The closest model in the wanted state, within maxDistance studs.
local function closestModel(maxDistance, wantState)
	local root = myRoot()
	if not root then
		return nil
	end
	local best, bestDistance = nil, maxDistance
	for _, model in ipairs(brainrotFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("State") == wantState then
			local body = model.PrimaryPart
			if body then
				local d = (root.Position - body.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = model, d
				end
			end
		end
	end
	return best
end

local function closestStealable()
	local root = myRoot()
	if not root then
		return nil
	end
	local best, bestDistance = nil, Data.STEAL_RANGE + 2
	for _, model in ipairs(brainrotFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("State") == "owned"
			and model:GetAttribute("Owner") ~= player.Name then
			local body = model.PrimaryPart
			if body then
				local d = (root.Position - body.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = model, d
				end
			end
		end
	end
	return best
end

-- ---------------------------------------------------------------- actions

-- E does the obvious thing: catch a walker nearby, else steal from a base.
local function doInteract()
	local walking = closestModel(Data.CATCH_RANGE + 2, "walking")
	if walking then
		catchRemote:FireServer(walking:GetAttribute("BrainrotId"))
		return
	end
	local stealable = closestStealable()
	if stealable then
		stealRemote:FireServer(stealable:GetAttribute("BrainrotId"))
	end
end

local function onInteract(_actionName, inputState, _inputObject)
	if inputState == Enum.UserInputState.Begin then
		doInteract()
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("BrainrotInteract", onInteract, false, Enum.KeyCode.E)

rebirthButton.Activated:Connect(function()
	rebirthRemote:FireServer()
end)

stealButton.Activated:Connect(function()
	local stealable = closestStealable()
	if stealable then
		stealRemote:FireServer(stealable:GetAttribute("BrainrotId"))
	else
		showAlert("Tidak ada brainrot curian di dekatmu!", 3)
	end
end)

-- --------------------------------------------------------- server messages

notifyRemote.OnClientEvent:Connect(function(kind, text)
	if kind == "tsunami" then
		tsunamiBanner.Text = text
		tsunamiBanner.Visible = true
		task.delay(Data.TSUNAMI_WARN + 8, function()
			tsunamiBanner.Visible = false
		end)
	elseif kind == "alert" then
		showAlert(text, 5)
	else
		showAlert(text, 4)
	end
end)

statsRemote.OnClientEvent:Connect(function(cash, rate, count, rebirths, mult, rebirthNeeded)
	cashLabel.Text = "Cash: $" .. tostring(cash)
	rateLabel.Text = "$" .. tostring(rate) .. "/detik  |  " .. tostring(count) .. " brainrot"
	rebirthLabel.Text = "Rebirth: " .. tostring(rebirths) .. "  (x" .. tostring(mult)
		.. ")  -  butuh $" .. tostring(rebirthNeeded)
end)

-- ------------------------------------------- prompt + alert housekeeping

RunService.RenderStepped:Connect(function()
	if os.clock() >= alertHideAt then
		alertLabel.Visible = false
	end
	local walking = closestModel(Data.CATCH_RANGE + 2, "walking")
	if walking then
		local price = walking:GetAttribute("Price") or 0
		promptLabel.Text = "Tekan E / ketuk untuk tangkap " .. walking.Name
			.. "  ($" .. tostring(price) .. ")"
		promptLabel.Visible = true
		return
	end
	local stealable = closestStealable()
	if stealable then
		local owner = stealable:GetAttribute("Owner") or "?"
		promptLabel.Text = "Tekan E / CURI untuk mencuri dari " .. owner .. "!"
		promptLabel.Visible = true
		return
	end
	promptLabel.Visible = false
end)

print("Brainrot Blast client ready")
