-- Brainrot Blast: builds one brainrot character as a 3D model of Parts.
-- Body block, head block, eyes and one accessory, sized and coloured from
-- the shared catalogue, plus a name tag and a click target. The model is
-- anchored and moved by the server; it has no Humanoid, so it can never
-- wander off on its own.

local Brainrots = {}

local function block(parent, name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function addTrim(model, trim, size, headTopY)
	if trim == "cup" then
		local cup = Instance.new("Part")
		cup.Name = "Cup"
		cup.Shape = Enum.PartType.Cylinder
		cup.Anchored = true
		cup.CanCollide = false
		cup.Size = Vector3.new(1.2 * size, 1.4 * size, 1.2 * size)
		cup.CFrame = CFrame.new(0, headTopY + 0.7 * size, 0) * CFrame.Angles(0, 0, math.rad(90))
		cup.Color = Color3.fromRGB(255, 255, 255)
		cup.Material = Enum.Material.SmoothPlastic
		cup.Parent = model
	elseif trim == "hat" then
		block(model, "Hat", Vector3.new(3.4 * size, 0.5 * size, 3.4 * size),
			Vector3.new(0, headTopY + 0.4 * size, 0), Color3.fromRGB(255, 210, 60))
		block(model, "HatTop", Vector3.new(2 * size, 1.2 * size, 2 * size),
			Vector3.new(0, headTopY + 1.2 * size, 0), Color3.fromRGB(255, 210, 60))
	elseif trim == "crown" then
		block(model, "Crown", Vector3.new(2.6 * size, 1 * size, 2.6 * size),
			Vector3.new(0, headTopY + 0.6 * size, 0), Color3.fromRGB(255, 220, 40),
			Enum.Material.Neon)
	elseif trim == "wings" then
		block(model, "WingLeft", Vector3.new(0.4 * size, 2 * size, 2.6 * size),
			Vector3.new(-1.8 * size, 0.4 * size, 0), Color3.fromRGB(255, 255, 255))
		block(model, "WingRight", Vector3.new(0.4 * size, 2 * size, 2.6 * size),
			Vector3.new(1.8 * size, 0.4 * size, 0), Color3.fromRGB(255, 255, 255))
	end
end

-- Builds the model at the given position, facing down the trail (+Z).
-- id is the server's brainrot id; rate and price come from the catalogue.
function Brainrots.build(character, rarityColor, id, position)
	local size = character.size
	local model = Instance.new("Model")
	model.Name = character.name .. "_" .. tostring(id)

	local bodySize = 3 * size
	local body = block(model, "Body", Vector3.new(bodySize, bodySize, bodySize),
		Vector3.new(0, bodySize / 2, 0), character.body)
	model.PrimaryPart = body

	local headSize = 2.2 * size
	local head = block(model, "Head", Vector3.new(headSize, headSize, headSize),
		Vector3.new(0, bodySize + headSize / 2, 0), character.head)

	-- Two eyes on the front (+Z) face of the head.
	block(model, "EyeLeft", Vector3.new(0.4 * size, 0.6 * size, 0.2 * size),
		Vector3.new(-0.55 * size, bodySize + headSize * 0.6, headSize / 2 + 0.05),
		Color3.fromRGB(20, 20, 20))
	block(model, "EyeRight", Vector3.new(0.4 * size, 0.6 * size, 0.2 * size),
		Vector3.new(0.55 * size, bodySize + headSize * 0.6, headSize / 2 + 0.05),
		Color3.fromRGB(20, 20, 20))

	addTrim(model, character.trim, size, bodySize + headSize)

	-- A rarity-coloured base ring so the rarity reads from across the map.
	block(model, "Ring", Vector3.new(4 * size, 0.4 * size, 4 * size),
		Vector3.new(0, 0.2, 0), rarityColor, Enum.Material.Neon)

	-- Name tag floating above the head.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(180, 56)
	tag.StudsOffsetWorldSpace = Vector3.new(0, bodySize + headSize + 2.5, 0)
	tag.AlwaysOnTop = true
	tag.Parent = body
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.55)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = character.name
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Parent = tag
	local rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "RateLabel"
	rateLabel.Position = UDim2.fromScale(0, 0.55)
	rateLabel.Size = UDim2.fromScale(1, 0.45)
	rateLabel.BackgroundTransparency = 1
	rateLabel.Text = character.rarity .. "  $" .. tostring(character.rate) .. "/s"
	rateLabel.TextColor3 = rarityColor
	rateLabel.TextStrokeTransparency = 0
	rateLabel.TextScaled = true
	rateLabel.Font = Enum.Font.SourceSansBold
	rateLabel.Parent = tag

	-- Click / tap target: the server listens to this for catch-by-click.
	local detector = Instance.new("ClickDetector")
	detector.Name = "CatchDetector"
	detector.MaxActivationDistance = 32
	detector.Parent = body

	model:SetAttribute("BrainrotId", id)
	model:SetAttribute("State", "walking")
	model:SetAttribute("Owner", "")
	model:SetAttribute("BaseRate", character.rate)
	model:SetAttribute("Rate", character.rate)
	model:SetAttribute("Price", character.price)
	model:SetAttribute("Rarity", character.rarity)
	model:SetAttribute("Mutation", "Normal")

	model:PivotTo(CFrame.new(position))
	return model
end

-- Moves a model to a base slot and marks it owned. rateLabel shows the
-- mutated rate so the owner can see what the brainrot really earns.
function Brainrots.placeOnSlot(model, slotPosition, ownerName, rate, mutation)
	model:PivotTo(CFrame.new(slotPosition))
	model:SetAttribute("State", "owned")
	model:SetAttribute("Owner", ownerName)
	model:SetAttribute("Rate", rate)
	model:SetAttribute("Mutation", mutation)
	local body = model.PrimaryPart
	if body then
		local tag = body:FindFirstChild("NameTag")
		if tag then
			local rateLabel = tag:FindFirstChild("RateLabel")
			if rateLabel then
				rateLabel.Text = mutation .. "  $" .. tostring(rate) .. "/s"
			end
		end
	end
end

return Brainrots
