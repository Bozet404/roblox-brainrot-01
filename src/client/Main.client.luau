-- Brainrot Blast: client. Draws the HUD over the 3D world, binds the E key
-- with ContextActionService (so the default camera never eats it), fires the
-- server's RemoteEvents, and shows tsunami warnings and steal alerts.
-- No money or ownership is decided here; the server checks everything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local catchRemote = remotes:WaitForChild("CatchBrainrot")
local stealRemote = remotes:WaitForChild("StealBrainrot")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local notifyRemote = remotes:WaitForChild("Notify")
local statsRemote = remotes:WaitForChild("Stats")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local brainrotFolder = workspace:WaitForChild("Brainrots")

-- ---------- HUD ----------

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local function label(name, parent, position, size, text, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = position
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = textSize
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Font = Enum.Font.FredokaOne
	l.Parent = parent
	return l
end

local function button(name, parent, position, size, text, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Position = position
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

-- Top bar, centred so the top-left Roblox menu buttons never cover it.
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

label("Title", topBar, UDim2.fromOffset(10, 2), UDim2.fromOffset(540, 24),
	"BRAINROT BLAST", 22, Color3.fromRGB(255, 230, 90))
local cashLabel = label("CashLabel", topBar, UDim2.fromOffset(10, 28), UDim2.fromOffset(260, 30),
	"Cash: $100", 20, Color3.fromRGB(140, 255, 140))
local rateLabel = label("RateLabel", topBar, UDim2.fromOffset(280, 28), UDim2.fromOffset(270, 30),
	"$0/detik  |  0 brainrot", 20, Color3.fromRGB(255, 255, 255))
local rebirthLabel = label("RebirthLabel", topBar, UDim2.fromOffset(10, 52), UDim2.fromOffset(540, 12),
	"Rebirth: 0  (x1.0)  -  butuh $10000", 12, Color3.fromRGB(200, 200, 255))
rebirthLabel.Font = Enum.Font.SourceSansBold

-- Tsunami banner, hidden until the server warns.
local tsunamiBanner = label("TsunamiBanner", gui, UDim2.new(0.5, 0, 0, 84),
	UDim2.fromOffset(560, 48), "", 26, Color3.fromRGB(255, 80, 80))
tsunamiBanner.AnchorPoint = Vector2.new(0.5, 0)
tsunamiBanner.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
tsunamiBanner.BackgroundTransparency = 0.2
tsunamiBanner.Visible = false

-- One-line alert in the middle of the screen, auto-hides.
local alertLabel = label("AlertLabel", gui, UDim2.new(0.5, 0, 0.42, 0),
	UDim2.fromOffset(560, 34), "", 22, Color3.fromRGB(255, 255, 255))
alertLabel.AnchorPoint = Vector2.new(0.5, 0)
alertLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
alertLabel.BackgroundTransparency = 0.35
alertLabel.Visible = false

-- Catch / steal prompt above the bottom of the screen.
local promptLabel = label("PromptLabel", gui, UDim2.new(0.5, 0, 1, -120),
	UDim2.fromOffset(560, 30), "", 20, Color3.fromRGB(255, 240, 150))
promptLabel.AnchorPoint = Vector2.new(0.5, 0)
promptLabel.Visible = false

-- Buttons: Activated fires for mouse and touch alike.
local rebirthButton = button("RebirthButton", gui, UDim2.new(1, -190, 0.5, -30),
	UDim2.fromOffset(170, 56), "REBIRTH", Color3.fromRGB(150, 60, 220))
local stealButton = button("StealButton", gui, UDim2.new(1, -190, 0.5, 36),
	UDim2.fromOffset(170, 56), "CURI (E)", Color3.fromRGB(220, 60, 60))

local alertHideAt = 0
local function showAlert(text, seconds)
	alertLabel.Text = text
	alertLabel.Visible = true
	alertHideAt = os.clock() + (seconds or 4)
end

-- ---------- Finding the nearest brainrot ----------

local function nearestBrainrot(maxDistance, wantState)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, nil
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
	return best, bestDistance
end

local function nearestStealable()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, BrainrotData.STEAL_RANGE + 2
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

-- ---------- Actions ----------

local function doInteract()
	local walking = nearestBrainrot(BrainrotData.CATCH_RANGE + 2, "walking")
	if walking then
		catchRemote:FireServer(walking:GetAttribute("BrainrotId"))
		return
	end
	local stealable = nearestStealable()
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
	local stealable = nearestStealable()
	if stealable then
		stealRemote:FireServer(stealable:GetAttribute("BrainrotId"))
	else
		showAlert("Tidak ada brainrot curian di dekatmu!", 3)
	end
end)

-- ---------- Server messages ----------

notifyRemote.OnClientEvent:Connect(function(kind, text)
	if kind == "tsunami" then
		tsunamiBanner.Text = text
		tsunamiBanner.Visible = true
		task.delay(BrainrotData.TSUNAMI_WARN_SECONDS + 8, function()
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

-- ---------- Prompt + alert housekeeping ----------

RunService.RenderStepped:Connect(function()
	if os.clock() >= alertHideAt then
		alertLabel.Visible = false
	end
	local walking = nearestBrainrot(BrainrotData.CATCH_RANGE + 2, "walking")
	if walking then
		local name = walking.Name
		local price = walking:GetAttribute("Price") or 0
		promptLabel.Text = "Tekan E / ketuk untuk tangkap " .. name .. "  ($" .. tostring(price) .. ")"
		promptLabel.Visible = true
		return
	end
	local stealable = nearestStealable()
	if stealable then
		local owner = stealable:GetAttribute("Owner") or "?"
		promptLabel.Text = "Tekan E / CURI untuk mencuri dari " .. owner .. "!"
		promptLabel.Visible = true
		return
	end
	promptLabel.Visible = false
end)

print("Brainrot Blast client ready")
