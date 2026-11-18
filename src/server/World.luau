-- Brainrot Blast: builds the whole 3D world at runtime.
-- Plaza, trail, spawn gate, eight player bases, trees, lamps and the
-- tsunami wave are all plain Parts created here, so the place file only
-- needs a baseplate and the scripts. Nothing in this module touches money.

local World = {}

local BASE_COLORS = {
	Color3.fromRGB(255, 120, 120),
	Color3.fromRGB(120, 180, 255),
	Color3.fromRGB(120, 230, 130),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(200, 140, 255),
	Color3.fromRGB(255, 160, 90),
	Color3.fromRGB(100, 230, 220),
	Color3.fromRGB(255, 130, 200),
}

local TREE_SPOTS = {
	Vector3.new(-45, 0, -45), Vector3.new(45, 0, -50), Vector3.new(-55, 0, 10),
	Vector3.new(55, 0, 25), Vector3.new(-40, 0, 55), Vector3.new(48, 0, 58),
	Vector3.new(-25, 0, -62), Vector3.new(28, 0, -64), Vector3.new(-68, 0, -18),
	Vector3.new(68, 0, -8),
}

local LAMP_SPOTS = {
	Vector3.new(-14, 0, -20), Vector3.new(14, 0, -20),
	Vector3.new(-14, 0, 20), Vector3.new(14, 0, 20),
	Vector3.new(-8, 0, -45), Vector3.new(8, 0, 45),
}

local function part(name, size, position, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

local function makeSignPole(parent, position, titleText)
	local pole = part("SignPole", Vector3.new(0.6, 7, 0.6), position + Vector3.new(0, 3.5, 0),
		Color3.fromRGB(90, 60, 30), Enum.Material.Wood)
	pole.Parent = parent
	local board = part("SignBoard", Vector3.new(9, 3, 0.6), position + Vector3.new(0, 7.5, 0),
		Color3.fromRGB(60, 40, 90), Enum.Material.WoodPlanks)
	board.Parent = parent
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = titleText
	label.TextColor3 = Color3.fromRGB(255, 240, 120)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	return label
end

function World.build()
	local world = {}
	world.bases = {}

	local workspace = game:GetService("Workspace")

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = workspace
	world.folder = folder

	-- Central plaza: a flat green square the trail crosses.
	local plaza = part("Plaza", Vector3.new(72, 1, 72), Vector3.new(0, 0, 0),
		Color3.fromRGB(90, 200, 90), Enum.Material.Grass)
	plaza.Parent = folder

	-- The trail: brainrots walk from the north gate to the south end on it.
	local trail = part("Trail", Vector3.new(10, 0.6, 176), Vector3.new(0, 0.3, 0),
		Color3.fromRGB(230, 200, 130), Enum.Material.Sand)
	trail.Parent = folder

	-- Spawn gate at the north end of the trail.
	local gateLeft = part("GatePillar", Vector3.new(2, 12, 2), Vector3.new(-7, 6, -82),
		Color3.fromRGB(150, 60, 200), Enum.Material.Neon)
	gateLeft.Parent = folder
	local gateRight = part("GatePillar", Vector3.new(2, 12, 2), Vector3.new(7, 6, -82),
		Color3.fromRGB(150, 60, 200), Enum.Material.Neon)
	gateRight.Parent = folder
	local gateTop = part("GateBeam", Vector3.new(16, 2, 2), Vector3.new(0, 12, -82),
		Color3.fromRGB(255, 220, 90), Enum.Material.Neon)
	gateTop.Parent = folder
	makeSignPole(folder, Vector3.new(0, 0, -88), "BRAINROT GATE")

	-- Eight bases on a ring around the plaza.
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local center = Vector3.new(math.cos(angle) * 55, 0, math.sin(angle) * 55)
		local baseFolder = Instance.new("Folder")
		baseFolder.Name = "Base" .. i
		baseFolder.Parent = folder

		local floor = part("Floor", Vector3.new(18, 1, 18), center + Vector3.new(0, 0, 0),
			BASE_COLORS[i], Enum.Material.SmoothPlastic)
		floor.Parent = baseFolder

		-- Low back wall so the base reads as a home zone from the plaza.
		local back = part("BackWall", Vector3.new(18, 5, 1),
			center + Vector3.new(-math.cos(angle) * 8.5, 2.5, -math.sin(angle) * 8.5),
			BASE_COLORS[i], Enum.Material.SmoothPlastic)
		back.Parent = baseFolder

		-- Six slot pads in two rows of three, facing the plaza.
		local slots = {}
		for row = 1, 2 do
			for col = 1, 3 do
				local slotIndex = (row - 1) * 3 + col
				local across = (col - 2) * 5
				local along = (row - 1) * 5 - 2
				local slotPos = center
					+ Vector3.new(-math.sin(angle) * across, 0, math.cos(angle) * across)
					+ Vector3.new(math.cos(angle) * along, 0, math.sin(angle) * along)
				local pad = part("SlotPad" .. slotIndex, Vector3.new(4, 0.4, 4),
					slotPos + Vector3.new(0, 0.7, 0), Color3.fromRGB(255, 255, 255),
					Enum.Material.Neon)
				pad.Parent = baseFolder
				slots[slotIndex] = slotPos + Vector3.new(0, 1.5, 0)
			end
		end

		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Anchored = true
		spawn.Size = Vector3.new(8, 1, 8)
		spawn.Position = center + Vector3.new(0, 0.5, 0)
		spawn.Color = BASE_COLORS[i]
		spawn.Material = Enum.Material.SmoothPlastic
		spawn.TopSurface = Enum.SurfaceType.Smooth
		spawn.BottomSurface = Enum.SurfaceType.Smooth
		spawn.Neutral = false
		spawn.AllowTeamChangeOnTouch = false
		spawn.Parent = baseFolder

		local signLabel = makeSignPole(baseFolder, center
			+ Vector3.new(-math.cos(angle) * 10, 0, -math.sin(angle) * 10), "BASE " .. i)

		world.bases[i] = {
			center = center + Vector3.new(0, 0.5, 0),
			slots = slots,
			spawn = spawn,
			signLabel = signLabel,
		}
	end

	-- Trees and lamps for depth, kept out of the trail and the bases.
	for _, spot in ipairs(TREE_SPOTS) do
		local trunk = part("Trunk", Vector3.new(1.5, 6, 1.5), spot + Vector3.new(0, 3, 0),
			Color3.fromRGB(120, 80, 40), Enum.Material.Wood)
		trunk.Parent = folder
		local leaves = Instance.new("Part")
		leaves.Name = "Leaves"
		leaves.Shape = Enum.PartType.Ball
		leaves.Anchored = true
		leaves.CanCollide = false
		leaves.Size = Vector3.new(7, 7, 7)
		leaves.Position = spot + Vector3.new(0, 8, 0)
		leaves.Color = Color3.fromRGB(40, 160, 60)
		leaves.Material = Enum.Material.Grass
		leaves.Parent = folder
	end
	for _, spot in ipairs(LAMP_SPOTS) do
		local pole = part("LampPole", Vector3.new(0.6, 6, 0.6), spot + Vector3.new(0, 3, 0),
			Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
		pole.Parent = folder
		local bulb = part("LampBulb", Vector3.new(1.6, 1.6, 1.6), spot + Vector3.new(0, 6.5, 0),
			Color3.fromRGB(255, 240, 150), Enum.Material.Neon)
		bulb.CanCollide = false
		bulb.Parent = folder
	end

	-- The tsunami wave: parked far below the map until a wave starts.
	local wave = part("TsunamiWave", Vector3.new(130, 16, 5), Vector3.new(0, -40, -95),
		Color3.fromRGB(40, 140, 255), Enum.Material.Glass)
	wave.Transparency = 0.35
	wave.CanCollide = false
	wave.Parent = folder
	world.wave = wave

	-- One folder holds every brainrot model, walking or owned.
	local brainrots = Instance.new("Folder")
	brainrots.Name = "Brainrots"
	brainrots.Parent = workspace
	world.brainrotFolder = brainrots

	return world
end

return World
