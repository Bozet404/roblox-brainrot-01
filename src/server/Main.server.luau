-- Brainrot Blast — server. One script owns the economy, the trail spawner,
-- catching, stealing, rebirths and the tsunami. Clients only ask, through
-- RemoteEvents; every rule (price, distance, free slots, cooldowns) is
-- checked here again, so a client can never grant itself cash or a brainrot
-- it did not earn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
local World = require(script.Parent:WaitForChild("World"))
local Brainrots = require(script.Parent:WaitForChild("Brainrots"))

local world = World.build()

-- RemoteEvents, created by the server so the client never has to guess.
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local catchRemote = makeRemote("CatchBrainrot")
local stealRemote = makeRemote("StealBrainrot")
local rebirthRemote = makeRemote("Rebirth")
local notifyRemote = makeRemote("Notify")
local statsRemote = makeRemote("Stats")

-- Live state. brainrots: id -> record; players: Player -> wallet + base;
-- carrying: Player -> { id, deadline }; stealReadyAt: Player -> os.clock().
local brainrots = {}
local players = {}
local carrying = {}
local stealReadyAt = {}
local nextId = 1
local joinCount = 0

-- ---------------------------------------------------------------- helpers

local function tell(player, kind, text)
	notifyRemote:FireClient(player, kind, text)
end

local function tellEveryone(kind, text)
	for _, player in ipairs(Players:GetPlayers()) do
		tell(player, kind, text)
	end
end

local function rootPart(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function distanceTo(player, position)
	local root = rootPart(player)
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

local function setSpeed(player, speed)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function isInsideBase(player)
	local data = players[player]
	local root = rootPart(player)
	if not data or not root then
		return false
	end
	local base = world.bases[data.baseIndex]
	local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
	local centre = Vector3.new(base.center.X, 0, base.center.Z)
	return (flat - centre).Magnitude <= 13
end

local function freeSlot(data)
	for i = 1, Data.MAX_SLOTS do
		if not data.owned[i] then
			return i
		end
	end
	return nil
end

local function countOwned(data)
	local count = 0
	for _ in pairs(data.owned) do
		count += 1
	end
	return count
end

local function ownedRate(data)
	local total = 0
	for _, id in pairs(data.owned) do
		local record = brainrots[id]
		if record then
			total += record.rate
		end
	end
	return total
end

local function refreshCashLeaderstat(player, cash)
	local folder = player:FindFirstChild("leaderstats")
	local value = folder and folder:FindFirstChild("Cash")
	if value then
		value.Value = cash
	end
end

local function pushStats(player)
	local data = players[player]
	if not data then
		return
	end
	statsRemote:FireClient(player, data.cash, ownedRate(data) * data.mult,
		countOwned(data), data.rebirths, data.mult,
		Data.rebirthCashNeeded(data.rebirths))
end

local function pushStatsAll()
	for _, player in ipairs(Players:GetPlayers()) do
		pushStats(player)
	end
end

-- Sends a brainrot back to its owner's first free slot, or destroys it
-- when the owner left or has no slot. Used when a steal fails or a wave hits.
local function sendHome(record)
	local owner = record.owner
	local data = owner and players[owner]
	if data then
		local slot = record.slotIndex
		if not (slot and not data.owned[slot]) then
			slot = freeSlot(data)
			record.slotIndex = slot
		end
		if slot then
			data.owned[slot] = record.id
			local base = world.bases[data.baseIndex]
			Brainrots.placeOnSlot(record.model, base.slots[slot], owner.Name,
				record.rate, record.mutation)
			record.state = "owned"
			pushStats(owner)
			return
		end
	end
	brainrots[record.id] = nil
	record.model:Destroy()
end

local function dropCarried(player, reason)
	local carry = carrying[player]
	if not carry then
		return
	end
	carrying[player] = nil
	setSpeed(player, 16)
	local record = brainrots[carry.id]
	if record and record.state == "carried" then
		sendHome(record)
		if record.owner then
			tell(record.owner, "info", "Brainrotmu kembali ke base! (" .. reason .. ")")
		end
	end
end

-- ---------------------------------------------------------------- catching

-- Catch: only a walking brainrot, only within reach, only if the player can
-- pay and has a free slot. The mutation is rolled here, on the server.
local function tryCatch(player, id)
	local record = brainrots[id]
	local data = players[player]
	if not record or not data or record.state ~= "walking" then
		return false
	end
	local body = record.model.PrimaryPart
	if not body then
		return false
	end
	if distanceTo(player, body.Position) > Data.CATCH_RANGE + 2 then
		tell(player, "info", "Terlalu jauh! Dekati brainrotnya dulu.")
		return false
	end
	if data.cash < record.price then
		tell(player, "info", "Uang kurang! " .. record.charName
			.. " harganya $" .. tostring(record.price) .. ".")
		return false
	end
	local slot = freeSlot(data)
	if not slot then
		tell(player, "info", "Basemu penuh! Rebirth dulu untuk slot baru.")
		return false
	end
	data.cash -= record.price
	local mutation, mult = Data.rollMutation()
	record.rate = record.baseRate * mult
	record.mutation = mutation
	record.state = "owned"
	record.owner = player
	record.slotIndex = slot
	data.owned[slot] = id
	local base = world.bases[data.baseIndex]
	Brainrots.placeOnSlot(record.model, base.slots[slot], player.Name,
		record.rate, mutation)
	refreshCashLeaderstat(player, data.cash)
	if mutation == "Normal" then
		tell(player, "catch", "Dapat " .. record.charName .. "! +$"
			.. tostring(record.rate) .. "/detik")
	else
		tell(player, "catch", "Dapat " .. mutation .. " " .. record.charName
			.. "! +$" .. tostring(record.rate) .. "/detik")
	end
	pushStats(player)
	return true
end

-- ---------------------------------------------------------------- stealing

-- Finds the nearest brainrot on someone else's base within steal reach.
local function nearestStealable(player)
	local best, bestDistance = nil, Data.STEAL_RANGE + 2
	for _, record in pairs(brainrots) do
		if record.state == "owned" and record.owner and record.owner ~= player then
			local body = record.model.PrimaryPart
			if body then
				local d = distanceTo(player, body.Position)
				if d < bestDistance then
					best, bestDistance = record, d
				end
			end
		end
	end
	return best
end

-- Steal: only a brainrot owned by someone else, only within reach, only
-- once per cooldown, only while not already carrying one.
local function trySteal(player, id)
	local data = players[player]
	if not data then
		return false
	end
	if carrying[player] then
		tell(player, "info", "Kamu sudah membawa curian! Bawa ke basemu dulu.")
		return false
	end
	if id == nil then
		-- The HUD Steal button with no target: take the nearest stealable one.
		local best = nearestStealable(player)
		if best then
			id = best.id
		end
	end
	local record = brainrots[id]
	if not record or record.state ~= "owned" or not record.owner
		or record.owner == player then
		return false
	end
	local now = os.clock()
	if stealReadyAt[player] and now < stealReadyAt[player] then
		tell(player, "info", "Curi lagi dalam "
			.. tostring(math.ceil(stealReadyAt[player] - now)) .. " detik.")
		return false
	end
	local body = record.model.PrimaryPart
	if not body or distanceTo(player, body.Position) > Data.STEAL_RANGE + 2 then
		tell(player, "info", "Terlalu jauh untuk mencuri!")
		return false
	end
	local victim = record.owner
	local victimData = players[victim]
	if victimData then
		victimData.owned[record.slotIndex] = nil
	end
	stealReadyAt[player] = now + Data.STEAL_COOLDOWN
	record.state = "carried"
	record.model:SetAttribute("State", "carried")
	carrying[player] = { id = id, deadline = now + Data.STEAL_CARRY_SECONDS }
	setSpeed(player, 8)
	tell(player, "steal", "Kamu mencuri " .. record.charName
		.. "! Lari ke basemu, 15 detik!")
	tell(victim, "alert", player.Name .. " mencuri " .. record.charName
		.. " dari basemu!")
	pushStats(victim)
	return true
end

local function finishSteal(player)
	local carry = carrying[player]
	if not carry then
		return
	end
	local record = brainrots[carry.id]
	carrying[player] = nil
	setSpeed(player, 16)
	if not record or record.state ~= "carried" then
		return
	end
	local data = players[player]
	local victim = record.owner
	if data then
		local slot = freeSlot(data)
		if slot then
			record.state = "owned"
			record.owner = player
			record.slotIndex = slot
			data.owned[slot] = record.id
			local base = world.bases[data.baseIndex]
			Brainrots.placeOnSlot(record.model, base.slots[slot], player.Name,
				record.rate, record.mutation)
			tell(player, "steal", "Curian berhasil! " .. record.charName
				.. " sekarang milikmu.")
			if victim then
				tell(victim, "alert", player.Name .. " berhasil mencuri "
					.. record.charName .. "!")
				pushStats(victim)
			end
			pushStats(player)
			return
		end
		tell(player, "info", "Basemu penuh, curian dikembalikan!")
	end
	sendHome(record)
end

-- ---------------------------------------------------------------- spawner

local function spawnBrainrot()
	local walking = 0
	for _, record in pairs(brainrots) do
		if record.state == "walking" then
			walking += 1
		end
	end
	if walking >= Data.MAX_WALKING then
		return
	end
	local rarity = Data.pickRarity()
	local character = Data.pickCharacter(rarity)
	local id = nextId
	nextId += 1
	local model = Brainrots.build(character, Data.rarityColor(rarity), id,
		Vector3.new(0, 0, Data.TRAIL_START_Z))
	model.Parent = world.brainrotFolder
	local record = {
		id = id,
		model = model,
		charName = character.name,
		rarity = rarity,
		price = character.price,
		baseRate = character.rate,
		rate = character.rate,
		mutation = "Normal",
		state = "walking",
		owner = nil,
		slotIndex = nil,
		walkZ = Data.TRAIL_START_Z,
		bobPhase = math.random() * math.pi * 2,
	}
	brainrots[id] = record
	local detector = model.PrimaryPart:FindFirstChild("CatchDetector")
	if detector then
		detector.MouseClick:Connect(function(clickingPlayer)
			if record.state == "walking" then
				tryCatch(clickingPlayer, id)
			elseif record.state == "owned" and record.owner ~= clickingPlayer then
				trySteal(clickingPlayer, id)
			end
		end)
	end
end

-- ---------------------------------------------------------------- players

local function onPlayerAdded(player)
	joinCount += 1
	local baseIndex = ((joinCount - 1) % Data.MAX_BASES) + 1
	players[player] = {
		cash = Data.START_CASH,
		rebirths = 0,
		mult = 1,
		owned = {},
		baseIndex = baseIndex,
	}

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = Data.START_CASH
	cashValue.Parent = leaderstats

	player.RespawnLocation = world.bases[baseIndex].spawn
	world.bases[baseIndex].signLabel.Text = player.Name .. "'s BASE"
	task.wait(1)
	pushStats(player)
	tell(player, "info",
		"Selamat datang di Brainrot Blast! Tangkap brainrot di trail, bawa ke basemu.")
end

local function onPlayerRemoving(player)
	dropCarried(player, "pemain keluar")
	local data = players[player]
	if data then
		for _, id in pairs(data.owned) do
			local record = brainrots[id]
			if record then
				brainrots[id] = nil
				record.model:Destroy()
			end
		end
	end
	players[player] = nil
	carrying[player] = nil
	stealReadyAt[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- ---------------------------------------------------------------- remotes

catchRemote.OnServerEvent:Connect(function(player, id)
	tryCatch(player, id)
end)

stealRemote.OnServerEvent:Connect(function(player, id)
	trySteal(player, id)
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local data = players[player]
	if not data then
		return
	end
	local needed = Data.rebirthCashNeeded(data.rebirths)
	if countOwned(data) < 1 then
		tell(player, "info", "Tangkap minimal 1 brainrot dulu sebelum rebirth.")
		return
	end
	if data.cash < needed then
		tell(player, "info", "Rebirth butuh $" .. tostring(needed)
			.. ". Kamu punya $" .. tostring(data.cash) .. ".")
		return
	end
	for _, id in pairs(data.owned) do
		local record = brainrots[id]
		if record then
			brainrots[id] = nil
			record.model:Destroy()
		end
	end
	data.owned = {}
	data.cash = 0
	data.rebirths += 1
	data.mult = Data.rebirthMultiplier(data.rebirths)
	refreshCashLeaderstat(player, 0)
	tell(player, "rebirth", "REBIRTH " .. tostring(data.rebirths)
		.. "! Pengali permanen sekarang x" .. tostring(data.mult))
	pushStats(player)
end)

-- ---------------------------------------------------------------- loops

-- Income: every second each owned brainrot pays its rate times the
-- player's rebirth multiplier.
task.spawn(function()
	while true do
		task.wait(1)
		for player, data in pairs(players) do
			local income = ownedRate(data) * data.mult
			if income > 0 then
				data.cash += income
				refreshCashLeaderstat(player, data.cash)
			end
		end
	end
end)

-- HUD stats push; twice a second is plenty for numbers on screen.
task.spawn(function()
	while true do
		task.wait(0.5)
		pushStatsAll()
	end
end)

-- One new brainrot walks in from the north gate every few seconds.
task.spawn(function()
	while true do
		task.wait(Data.SPAWN_EVERY)
		spawnBrainrot()
	end
end)

-- Tsunami: warn, then sweep a wave down the trail. Anyone caught outside
-- their base is flung and drops what they stole; walking brainrots wash away.
task.spawn(function()
	while true do
		task.wait(Data.TSUNAMI_EVERY)
		tellEveryone("tsunami", "TSUNAMI DATANG DALAM 10 DETIK! LARI KE BASEMU!")
		task.wait(Data.TSUNAMI_WARN)
		for _, record in pairs(brainrots) do
			if record.state == "walking" then
				brainrots[record.id] = nil
				record.model:Destroy()
			end
		end
		local wave = world.wave
		for z = -95, 95, 4 do
			wave.Position = Vector3.new(0, 4, z)
			for player in pairs(players) do
				if not isInsideBase(player) then
					local root = rootPart(player)
					if root then
						root.AssemblyLinearVelocity = Vector3.new(0, 45, 70)
					end
					if carrying[player] then
						dropCarried(player, "tersapu tsunami")
					end
				end
			end
			task.wait(0.1)
		end
		wave.Position = Vector3.new(0, -40, -95)
		tellEveryone("info", "Tsunami lewat! Trail aman lagi, brainrot baru berdatangan.")
	end
end)

-- Per-frame movement: walking brainrots march south with a little bob,
-- and a stolen brainrot rides above its carrier's head. Steal delivery
-- and timeout are checked here too, so the handoff is instant.
RunService.Heartbeat:Connect(function(dt)
	for id, record in pairs(brainrots) do
		if record.state == "walking" then
			record.walkZ += Data.WALK_SPEED * dt
			if record.walkZ >= Data.TRAIL_END_Z then
				brainrots[id] = nil
				record.model:Destroy()
			else
				local bob = math.sin(os.clock() * 4 + record.bobPhase) * 0.35
				record.model:PivotTo(CFrame.new(0, bob, record.walkZ))
			end
		elseif record.state == "carried" then
			local carrier = nil
			for player, carry in pairs(carrying) do
				if carry.id == id then
					carrier = player
					break
				end
			end
			if carrier then
				local root = rootPart(carrier)
				if root then
					record.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 6, 0)))
				else
					dropCarried(carrier, "karakter hilang")
				end
			end
		end
	end
	for player, carry in pairs(carrying) do
		local record = brainrots[carry.id]
		if not record or record.state ~= "carried" then
			carrying[player] = nil
			setSpeed(player, 16)
		elseif not rootPart(player) then
			dropCarried(player, "karakter hilang")
		elseif isInsideBase(player) then
			finishSteal(player)
		elseif os.clock() >= carry.deadline then
			tell(player, "info", "Waktu curi habis! Brainrot kembali ke pemiliknya.")
			dropCarried(player, "waktu habis")
		end
	end
end)

print("Brainrot Blast server ready: 8 bases, trail -80..80, tsunami every "
	.. tostring(Data.TSUNAMI_EVERY) .. "s")
