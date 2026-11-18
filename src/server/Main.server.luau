-- Brainrot Blast: server. Owns the economy, the trail spawner, catching,
-- stealing, rebirths and the tsunami. Clients only ask through RemoteEvents;
-- every rule (price, distance, slots, cooldowns) is checked here again, so
-- a client can never grant itself cash or a brainrot it did not earn.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BrainrotData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BrainrotData"))
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

local brainrots = {} -- id -> record
local playerData = {} -- Player -> { cash, rebirths, mult, owned, baseIndex, slotsUsed }
local carrying = {} -- Player -> { id, deadline }
local stealCooldownUntil = {} -- Player -> os.clock() timestamp
local nextBrainrotId = 1
local joinOrder = 0
local tsunamiActive = false

local function notify(player, kind, text)
	notifyRemote:FireClient(player, kind, text)
end

local function notifyAll(kind, text)
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, kind, text)
	end
end

local function characterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function distanceTo(player, position)
	local root = characterRoot(player)
	if not root then
		return math.huge
	end
	return (root.Position - position).Magnitude
end

local function setWalkSpeed(player, speed)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function freeSlotIndex(data)
	for i = 1, BrainrotData.MAX_SLOTS do
		if not data.owned[i] then
			return i
		end
	end
	return nil
end

local function ownedCount(data)
	local count = 0
	for _ in pairs(data.owned) do
		count = count + 1
	end
	return count
end

local function ownedRate(data)
	local total = 0
	for _, id in pairs(data.owned) do
		local record = brainrots[id]
		if record then
			total = total + record.rate
		end
	end
	return total
end

local function sendStats(player)
	local data = playerData[player]
	if not data then
		return
	end
	statsRemote:FireClient(player, data.cash, ownedRate(data) * data.mult,
		ownedCount(data), data.rebirths, data.mult,
		BrainrotData.rebirthCashNeeded(data.rebirths))
end

local function sendStatsToAll()
	for _, player in ipairs(Players:GetPlayers()) do
		sendStats(player)
	end
end

-- Returns the brainrot to its owner's free slot, or destroys it if the
-- owner left or has no slot. Used when a steal fails or a wave hits.
local function returnToOwner(record)
	local owner = record.owner
	if owner and playerData[owner] then
		local data = playerData[owner]
		local slot = record.slotIndex
		if slot and not data.owned[slot] then
			data.owned[slot] = record.id
		else
			slot = freeSlotIndex(data)
			if slot then
				data.owned[slot] = record.id
				record.slotIndex = slot
			end
		end
		if slot then
			local base = world.bases[data.baseIndex]
			Brainrots.placeOnSlot(record.model, base.slots[slot], owner.Name,
				record.rate, record.mutation)
			record.state = "owned"
			sendStats(owner)
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
	setWalkSpeed(player, 16)
	local record = brainrots[carry.id]
	if record and record.state == "carried" then
		returnToOwner(record)
		if record.owner then
			notify(record.owner, "info", "Brainrotmu kembali ke base! (" .. reason .. ")")
		end
	end
end

-- Catch: only a walking brainrot, only within reach, only if the player can
-- pay and has a free slot. Mutation is rolled here, on the server.
local function tryCatch(player, id)
	local record = brainrots[id]
	local data = playerData[player]
	if not record or not data or record.state ~= "walking" then
		return false
	end
	local body = record.model.PrimaryPart
	if not body then
		return false
	end
	if distanceTo(player, body.Position) > BrainrotData.CATCH_RANGE + 2 then
		notify(player, "info", "Terlalu jauh! Dekati brainrotnya dulu.")
		return false
	end
	if data.cash < record.price then
		notify(player, "info", "Uang kurang! " .. record.charName .. " harganya $" .. tostring(record.price) .. ".")
		return false
	end
	local slot = freeSlotIndex(data)
	if not slot then
		notify(player, "info", "Basemu penuh! Rebirth dulu untuk slot baru.")
		return false
	end
	data.cash = data.cash - record.price
	local mutation, mult = BrainrotData.rollMutation()
	record.rate = record.baseRate * mult
	record.mutation = mutation
	record.state = "owned"
	record.owner = player
	record.slotIndex = slot
	data.owned[slot] = id
	local base = world.bases[data.baseIndex]
	Brainrots.placeOnSlot(record.model, base.slots[slot], player.Name, record.rate, mutation)
	local cashValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	if cashValue then
		cashValue.Value = data.cash
	end
	if mutation == "Normal" then
		notify(player, "catch", "Dapat " .. record.charName .. "! +$" .. tostring(record.rate) .. "/detik")
	else
		notify(player, "catch", "Dapat " .. mutation .. " " .. record.charName .. "! +$" .. tostring(record.rate) .. "/detik")
	end
	sendStats(player)
	return true
end

-- Steal: only a brainrot owned by someone else, only within reach, only
-- once per cooldown, only while not already carrying one.
local function trySteal(player, id)
	local data = playerData[player]
	if not data then
		return false
	end
	if carrying[player] then
		notify(player, "info", "Kamu sudah membawa curian! Bawa ke basemu dulu.")
		return false
	end
	if id == nil then
		-- HUD Steal button without a target: take the nearest stealable one.
		local best, bestDistance = nil, BrainrotData.STEAL_RANGE + 2
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
		if best then
			id = best.id
		end
	end
	local record = brainrots[id]
	if not record or record.state ~= "owned" or not record.owner or record.owner == player then
		return false
	end
	local now = os.clock()
	if stealCooldownUntil[player] and now < stealCooldownUntil[player] then
		notify(player, "info", "Curi lagi dalam " .. tostring(math.ceil(stealCooldownUntil[player] - now)) .. " detik.")
		return false
	end
	local body = record.model.PrimaryPart
	if not body or distanceTo(player, body.Position) > BrainrotData.STEAL_RANGE + 2 then
		notify(player, "info", "Terlalu jauh untuk mencuri!")
		return false
	end
	local victim = record.owner
	local victimData = playerData[victim]
	if victimData then
		victimData.owned[record.slotIndex] = nil
	end
	stealCooldownUntil[player] = now + BrainrotData.STEAL_COOLDOWN_SECONDS
	record.state = "carried"
	record.model:SetAttribute("State", "carried")
	carrying[player] = { id = id, deadline = now + BrainrotData.STEAL_CARRY_SECONDS }
	setWalkSpeed(player, 8)
	notify(player, "steal", "Kamu mencuri " .. record.charName .. "! Lari ke basemu, 15 detik!")
	notify(victim, "alert", player.Name .. " mencuri " .. record.charName .. " dari basemu!")
	sendStats(victim)
	return true
end

local function completeSteal(player)
	local carry = carrying[player]
	if not carry then
		return
	end
	local record = brainrots[carry.id]
	carrying[player] = nil
	setWalkSpeed(player, 16)
	if not record or record.state ~= "carried" then
		return
	end
	local data = playerData[player]
	local victim = record.owner
	if data then
		local slot = freeSlotIndex(data)
		if slot then
			record.state = "owned"
			record.owner = player
			record.slotIndex = slot
			data.owned[slot] = record.id
			local base = world.bases[data.baseIndex]
			Brainrots.placeOnSlot(record.model, base.slots[slot], player.Name, record.rate, record.mutation)
			notify(player, "steal", "Curian berhasil! " .. record.charName .. " sekarang milikmu.")
			if victim then
				notify(victim, "alert", player.Name .. " berhasil mencuri " .. record.charName .. "!")
				sendStats(victim)
			end
			sendStats(player)
			return
		end
		notify(player, "info", "Basemu penuh, curian dikembalikan!")
	end
	returnToOwner(record)
end

-- Spawner: one new brainrot walks in from the north gate every few seconds.
local function spawnBrainrot()
	local walking = 0
	for _, record in pairs(brainrots) do
		if record.state == "walking" then
			walking = walking + 1
		end
	end
	if walking >= BrainrotData.MAX_WALKING then
		return
	end
	local rarity = BrainrotData.pickRarity()
	local character = BrainrotData.pickCharacter(rarity)
	local id = nextBrainrotId
	nextBrainrotId = nextBrainrotId + 1
	local model = Brainrots.build(character, BrainrotData.rarityColor(rarity), id,
		Vector3.new(0, 0, BrainrotData.TRAIL_START_Z))
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
		walkZ = BrainrotData.TRAIL_START_Z,
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

local function onPlayerAdded(player)
	joinOrder = joinOrder + 1
	local baseIndex = ((joinOrder - 1) % BrainrotData.MAX_BASES) + 1
	local data = {
		cash = BrainrotData.START_CASH,
		rebirths = 0,
		mult = 1,
		owned = {},
		baseIndex = baseIndex,
	}
	playerData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = data.cash
	cashValue.Parent = leaderstats

	player.RespawnLocation = world.bases[baseIndex].spawn
	world.bases[baseIndex].signLabel.Text = player.Name .. "'s BASE"
	task.wait(1)
	sendStats(player)
	notify(player, "info", "Selamat datang di Brainrot Blast! Tangkap brainrot di trail, bawa ke basemu.")
end

local function onPlayerRemoving(player)
	dropCarried(player, "pemain keluar")
	local data = playerData[player]
	if data then
		for _, id in pairs(data.owned) do
			local record = brainrots[id]
			if record then
				brainrots[id] = nil
				record.model:Destroy()
			end
		end
	end
	playerData[player] = nil
	carrying[player] = nil
	stealCooldownUntil[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

catchRemote.OnServerEvent:Connect(function(player, id)
	tryCatch(player, id)
end)

stealRemote.OnServerEvent:Connect(function(player, id)
	trySteal(player, id)
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local data = playerData[player]
	if not data then
		return
	end
	local needed = BrainrotData.rebirthCashNeeded(data.rebirths)
	if ownedCount(data) < 1 then
		notify(player, "info", "Tangkap minimal 1 brainrot dulu sebelum rebirth.")
		return
	end
	if data.cash < needed then
		notify(player, "info", "Rebirth butuh $" .. tostring(needed) .. ". Kamu punya $" .. tostring(data.cash) .. ".")
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
	data.rebirths = data.rebirths + 1
	data.mult = BrainrotData.rebirthMultiplier(data.rebirths)
	local cashValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
	if cashValue then
		cashValue.Value = 0
	end
	notify(player, "rebirth", "REBIRTH " .. tostring(data.rebirths) .. "! Pengali permanen sekarang x" .. tostring(data.mult))
	sendStats(player)
end)

-- Income: every second each owned brainrot pays its rate times the
-- player's rebirth multiplier.
task.spawn(function()
	while true do
		task.wait(1)
		for player, data in pairs(playerData) do
			local income = ownedRate(data) * data.mult
			if income > 0 then
				data.cash = data.cash + income
				local cashValue = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
				if cashValue then
					cashValue.Value = data.cash
				end
			end
		end
	end
end)

-- HUD stats push, twice a second is plenty for numbers on screen.
task.spawn(function()
	while true do
		task.wait(0.5)
		sendStatsToAll()
	end
end)

-- Spawner loop.
task.spawn(function()
	while true do
		task.wait(BrainrotData.SPAWN_EVERY_SECONDS)
		spawnBrainrot()
	end
end)

-- Tsunami: warn, then sweep a wave down the trail. Anyone caught outside
-- their base is flung and drops what they stole; walking brainrots wash away.
task.spawn(function()
	while true do
		task.wait(BrainrotData.TSUNAMI_EVERY_SECONDS)
		notifyAll("tsunami", "TSUNAMI DATANG DALAM 10 DETIK! LARI KE BASEMU!")
		task.wait(BrainrotData.TSUNAMI_WARN_SECONDS)
		tsunamiActive = true
		for _, record in pairs(brainrots) do
			if record.state == "walking" then
				brainrots[record.id] = nil
				record.model:Destroy()
			end
		end
		local wave = world.wave
		for z = -95, 95, 4 do
			wave.Position = Vector3.new(0, 4, z)
			for player, data in pairs(playerData) do
				local root = characterRoot(player)
				if root then
					local base = world.bases[data.baseIndex]
					local inBase = (Vector3.new(root.Position.X, 0, root.Position.Z)
						- Vector3.new(base.center.X, 0, base.center.Z)).Magnitude <= 13
					if not inBase then
						root.AssemblyLinearVelocity = Vector3.new(0, 45, 70)
						if carrying[player] then
							dropCarried(player, "tersapu tsunami")
						end
					end
				end
			end
			task.wait(0.1)
		end
		wave.Position = Vector3.new(0, -40, -95)
		tsunamiActive = false
		notifyAll("info", "Tsunami lewat! Trail aman lagi, brainrot baru berdatangan.")
	end
end)

-- Per-frame movement: walking brainrots march south with a little bob,
-- and a stolen brainrot rides above its carrier's head.
RunService.Heartbeat:Connect(function(dt)
	for id, record in pairs(brainrots) do
		if record.state == "walking" then
			record.walkZ = record.walkZ + BrainrotData.WALK_SPEED * dt
			if record.walkZ >= BrainrotData.TRAIL_END_Z then
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
				local root = characterRoot(carrier)
				if root then
					record.model:PivotTo(CFrame.new(root.Position + Vector3.new(0, 6, 0)))
				else
					dropCarried(carrier, "karakter hilang")
				end
			end
		end
	end
	-- Steal delivery and timeout, checked every frame so the handoff is instant.
	for player, carry in pairs(carrying) do
		local record = brainrots[carry.id]
		if not record or record.state ~= "carried" then
			carrying[player] = nil
			setWalkSpeed(player, 16)
		else
			local data = playerData[player]
			local root = characterRoot(player)
			if not root then
				dropCarried(player, "karakter hilang")
			elseif data then
				local base = world.bases[data.baseIndex]
				local home = (Vector3.new(root.Position.X, 0, root.Position.Z)
					- Vector3.new(base.center.X, 0, base.center.Z)).Magnitude <= 13
				if home then
					completeSteal(player)
				elseif os.clock() >= carry.deadline then
					notify(player, "info", "Waktu curi habis! Brainrot kembali ke pemiliknya.")
					dropCarried(player, "waktu habis")
				end
			end
		end
	end
end)

print("Brainrot Blast server ready: 8 bases, trail -80..80, tsunami every "
	.. tostring(BrainrotData.TSUNAMI_EVERY_SECONDS) .. "s")
