-- Brainrot Blast — the 3D world, built from Parts when the server starts.
-- A green plaza, a sandy trail from the north gate to the south end, eight
-- player bases on a ring around the plaza, trees, lamps, bushes and the
-- tsunami wave. The place file itself only carries a baseplate; everything
-- a player sees here is made by this module. It never touches money.

local World = {}

-- One colour per base, in join order.
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

local BUSH_SPOTS = {
	Vector3.new(-30, 0, -30), Vector3.new(32, 0, -38), Vector3.new(-60, 0, 38),
	Vector3.new(60, 0, -38), Vector3.new(-18, 0, 62), Vector3.new(20, 0, 66),
}

local LAMP_SPOTS = {
	Vector3.new(-14, 0, -20), Vector3.new(14, 0, -20),
	Vector3.new(-14, 0, 20), Vector3.new(14, 0, 20),
	Vector3.new(-8, 0, -45), Vector3.new(8, 0, 45),
}

-- spec: { name, size, pos, color, material, shape, collide }
local function makePart(parent, spec)
	local p = Instance.new("Part")
	p.Name = spec.name
	p.Anchored = true
	p.CanCollide = spec.collide ~= false
	p.Size = spec.size
	p.Position = spec.pos
	p.Color = spec.color
	p.Material = spec.material or Enum.Material.SmoothPlastic
	if spec.shape then
		p.Shape = spec.shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A wooden pole with a board that shows one line of text to the plaza.
local function makeSign(parent, pos, text)
	makePart(parent, {
		name = "SignPole", size = Vector3.new(0.6, 7, 0.6),
		pos = pos + Vector3.new(0, 3.5, 0),
		color = Color3.fromRGB(90, 60, 30), material = Enum.Material.Wood,
	})
	local board = makePart(parent, {
		name = "SignBoard", size = Vector3.new(9, 3, 0.6),
		pos = pos + Vector3.new(0, 7.5, 0),
		color = Color3.fromRGB(60, 40, 90), material = Enum.Material.WoodPlanks,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 240, 120)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.Parent = gui
	return label
end

local function makeTree(parent, spot)
	makePart(parent, {
		name = "Trunk", size = Vector3.new(1.5, 6, 1.5),
		pos = spot + Vector3.new(0, 3, 0),
		color = Color3.fromRGB(120, 80, 40), material = Enum.Material.Wood,
	})
	makePart(parent, {
		name = "Leaves", size = Vector3.new(7, 7, 7),
		pos = spot + Vector3.new(0, 8, 0),
		color = Color3.fromRGB(40, 160, 60), material = Enum.Material.Grass,
		shape = Enum.PartType.Ball, collide = false,
	})
end

local function makeLamp(parent, spot)
	makePart(parent, {
		name = "LampPole", size = Vector3.new(0.6, 6, 0.6),
		pos = spot + Vector3.new(0, 3, 0),
		color = Color3.fromRGB(60, 60, 60), material = Enum.Material.Metal,
	})
	makePart(parent, {
		name = "LampBulb", size = Vector3.new(1.6, 1.6, 1.6),
		pos = spot + Vector3.new(0, 6.5, 0),
		color = Color3.fromRGB(255, 240, 150), material = Enum.Material.Neon,
		collide = false,
	})
end

-- Builds one base: floor, back wall, six neon slot pads in two rows of
-- three, a SpawnLocation and a name sign. Returns the base's live data.
local function makeBase(folder, index, center, angle)
	local color = BASE_COLORS[index]
	local baseFolder = Instance.new("Folder")
	baseFolder.Name = "Base" .. index
	baseFolder.Parent = folder

	makePart(baseFolder, {
		name = "Floor", size = Vector3.new(18, 1, 18), pos = center,
		color = color,
	})
	-- Low wall on the far side so the base reads as a home zone.
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	makePart(baseFolder, {
		name = "BackWall", size = Vector3.new(18, 5, 1),
		pos = center - out * 8.5 + Vector3.new(0, 2.5, 0), color = color,
	})

	-- Slot pads: across the base (sideways) and along it (toward plaza).
	local right = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	local slots = {}
	for row = 1, 2 do
		for col = 1, 3 do
			local slotIndex = (row - 1) * 3 + col
			local padPos = center + right * ((col - 2) * 5) + out * ((row - 1) * 5 - 2)
			makePart(baseFolder, {
				name = "SlotPad" .. slotIndex, size = Vector3.new(4, 0.4, 4),
				pos = padPos + Vector3.new(0, 0.7, 0),
				color = Color3.fromRGB(255, 255, 255), material = Enum.Material.Neon,
			})
			slots[slotIndex] = padPos + Vector3.new(0, 1.5, 0)
		end
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn" .. index
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = center + Vector3.new(0, 0.5, 0)
	spawn.Color = color
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = false
	spawn.AllowTeamChangeOnTouch = false
	spawn.Parent = baseFolder

	local signLabel = makeSign(baseFolder, center - out * 10, "BASE " .. index)

	return {
		center = center + Vector3.new(0, 0.5, 0),
		slots = slots,
		spawn = spawn,
		signLabel = signLabel,
	}
end

function World.build()
	local world = { bases = {} }
	local workspace = game:GetService("Workspace")

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotWorld"
	folder.Parent = workspace
	world.folder = folder

	-- Central plaza the trail crosses, then the trail itself.
	makePart(folder, {
		name = "Plaza", size = Vector3.new(72, 1, 72), pos = Vector3.new(0, 0, 0),
		color = Color3.fromRGB(90, 200, 90), material = Enum.Material.Grass,
	})
	makePart(folder, {
		name = "Trail", size = Vector3.new(10, 0.6, 176), pos = Vector3.new(0, 0.3, 0),
		color = Color3.fromRGB(230, 200, 130), material = Enum.Material.Sand,
	})

	-- Spawn gate at the north end of the trail (z = -82).
	makePart(folder, {
		name = "GatePillar", size = Vector3.new(2, 12, 2), pos = Vector3.new(-7, 6, -82),
		color = Color3.fromRGB(150, 60, 200), material = Enum.Material.Neon,
	})
	makePart(folder, {
		name = "GatePillar", size = Vector3.new(2, 12, 2), pos = Vector3.new(7, 6, -82),
		color = Color3.fromRGB(150, 60, 200), material = Enum.Material.Neon,
	})
	makePart(folder, {
		name = "GateBeam", size = Vector3.new(16, 2, 2), pos = Vector3.new(0, 12, -82),
		color = Color3.fromRGB(255, 220, 90), material = Enum.Material.Neon,
	})
	makeSign(folder, Vector3.new(0, 0, -88), "BRAINROT GATE")

	-- Eight bases on a ring around the plaza, 45 degrees apart.
	for i = 1, 8 do
		local angle = math.rad((i - 1) * 45)
		local center = Vector3.new(math.cos(angle) * 55, 0, math.sin(angle) * 55)
		world.bases[i] = makeBase(folder, i, center, angle)
	end

	-- Greenery and light, kept off the trail and out of the bases.
	for _, spot in ipairs(TREE_SPOTS) do
		makeTree(folder, spot)
	end
	for _, spot in ipairs(BUSH_SPOTS) do
		makePart(folder, {
			name = "Bush", size = Vector3.new(3, 3, 3),
			pos = spot + Vector3.new(0, 1.5, 0),
			color = Color3.fromRGB(60, 180, 80), material = Enum.Material.Grass,
			shape = Enum.PartType.Ball, collide = false,
		})
	end
	for _, spot in ipairs(LAMP_SPOTS) do
		makeLamp(folder, spot)
	end

	-- The tsunami wave: parked far below the map until a wave starts.
	local wave = makePart(folder, {
		name = "TsunamiWave", size = Vector3.new(130, 16, 5),
		pos = Vector3.new(0, -40, -95),
		color = Color3.fromRGB(40, 140, 255), material = Enum.Material.Glass,
		collide = false,
	})
	wave.Transparency = 0.35
	world.wave = wave

	-- One folder holds every brainrot model, walking or owned.
	local brainrots = Instance.new("Folder")
	brainrots.Name = "Brainrots"
	brainrots.Parent = workspace
	world.brainrotFolder = brainrots

	return world
end

return World
