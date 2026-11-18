-- Brainrot Blast: shared catalogue of every brainrot character.
-- One table read by the server (spawning, prices, economy) and by the
-- client (HUD prices), so the two sides can never disagree about a price.
-- All names, shapes and colours here are original inventions for this game.

local BrainrotData = {}

BrainrotData.START_CASH = 100
BrainrotData.MAX_SLOTS = 6
BrainrotData.MAX_BASES = 8
BrainrotData.MAX_WALKING = 10
BrainrotData.SPAWN_EVERY_SECONDS = 6
BrainrotData.WALK_SPEED = 4
BrainrotData.TRAIL_START_Z = -80
BrainrotData.TRAIL_END_Z = 80
BrainrotData.CATCH_RANGE = 14
BrainrotData.STEAL_RANGE = 12
BrainrotData.STEAL_CARRY_SECONDS = 15
BrainrotData.STEAL_COOLDOWN_SECONDS = 30
BrainrotData.TSUNAMI_EVERY_SECONDS = 90
BrainrotData.TSUNAMI_WARN_SECONDS = 10

BrainrotData.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(190, 190, 190), weight = 45 },
	{ name = "Rare", color = Color3.fromRGB(80, 160, 255), weight = 25 },
	{ name = "Epic", color = Color3.fromRGB(170, 90, 255), weight = 15 },
	{ name = "Legendary", color = Color3.fromRGB(255, 180, 40), weight = 9 },
	{ name = "Mythic", color = Color3.fromRGB(255, 70, 120), weight = 4.5 },
	{ name = "Brainrot God", color = Color3.fromRGB(255, 240, 90), weight = 1.5 },
}

-- One entry per character. rate is $ earned per second, price is the cash
-- cost to catch it off the trail. body is the main block colour, head the
-- top block colour, size scales the whole model, trim picks the accessory.
BrainrotData.CHARACTERS = {
	{ name = "Capybara Kopi", rarity = "Common", rate = 5, price = 50,
		body = Color3.fromRGB(150, 105, 60), head = Color3.fromRGB(120, 80, 45), size = 1.0, trim = "cup" },
	{ name = "Bebek Nasi Goreng", rarity = "Common", rate = 8, price = 100,
		body = Color3.fromRGB(255, 220, 90), head = Color3.fromRGB(255, 170, 40), size = 1.0, trim = "hat" },
	{ name = "Kucing Es Teh", rarity = "Rare", rate = 20, price = 350,
		body = Color3.fromRGB(240, 200, 150), head = Color3.fromRGB(220, 160, 110), size = 1.1, trim = "cup" },
	{ name = "Ayam Geprek Terbang", rarity = "Rare", rate = 35, price = 600,
		body = Color3.fromRGB(255, 245, 230), head = Color3.fromRGB(255, 90, 60), size = 1.1, trim = "wings" },
	{ name = "Gajah Micin", rarity = "Epic", rate = 80, price = 1500,
		body = Color3.fromRGB(140, 140, 200), head = Color3.fromRGB(110, 110, 170), size = 1.4, trim = "hat" },
	{ name = "Ular Mie Ayam", rarity = "Epic", rate = 120, price = 2500,
		body = Color3.fromRGB(255, 215, 90), head = Color3.fromRGB(200, 60, 60), size = 1.3, trim = "none" },
	{ name = "Naga Indomie", rarity = "Legendary", rate = 300, price = 6000,
		body = Color3.fromRGB(230, 60, 60), head = Color3.fromRGB(255, 200, 60), size = 1.6, trim = "wings" },
	{ name = "Kera Kopi Susu", rarity = "Legendary", rate = 450, price = 9000,
		body = Color3.fromRGB(120, 85, 50), head = Color3.fromRGB(240, 210, 170), size = 1.5, trim = "crown" },
	{ name = "Raja Durian Emas", rarity = "Mythic", rate = 1000, price = 20000,
		body = Color3.fromRGB(255, 210, 40), head = Color3.fromRGB(120, 180, 60), size = 1.8, trim = "crown" },
	{ name = "Hantu Soto Ayam", rarity = "Mythic", rate = 1500, price = 30000,
		body = Color3.fromRGB(230, 240, 255), head = Color3.fromRGB(180, 200, 255), size = 1.7, trim = "none" },
	{ name = "Dewa Nasi Padang", rarity = "Brainrot God", rate = 5000, price = 100000,
		body = Color3.fromRGB(255, 240, 150), head = Color3.fromRGB(255, 255, 255), size = 2.1, trim = "crown" },
	{ name = "Dewa Rendang Abadi", rarity = "Brainrot God", rate = 8000, price = 150000,
		body = Color3.fromRGB(90, 40, 20), head = Color3.fromRGB(255, 190, 60), size = 2.2, trim = "crown" },
}

BrainrotData.MUTATIONS = {
	{ name = "Golden", chance = 0.10, mult = 2 },
	{ name = "Diamond", chance = 0.04, mult = 4 },
	{ name = "Rainbow", chance = 0.01, mult = 8 },
}

function BrainrotData.rarityColor(rarityName)
	for _, rarity in ipairs(BrainrotData.RARITIES) do
		if rarity.name == rarityName then
			return rarity.color
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

function BrainrotData.pickRarity()
	local total = 0
	for _, rarity in ipairs(BrainrotData.RARITIES) do
		total = total + rarity.weight
	end
	local roll = math.random() * total
	local running = 0
	for _, rarity in ipairs(BrainrotData.RARITIES) do
		running = running + rarity.weight
		if roll <= running then
			return rarity.name
		end
	end
	return "Common"
end

function BrainrotData.pickCharacter(rarityName)
	local pool = {}
	for _, character in ipairs(BrainrotData.CHARACTERS) do
		if character.rarity == rarityName then
			table.insert(pool, character)
		end
	end
	if #pool == 0 then
		return BrainrotData.CHARACTERS[1]
	end
	return pool[math.random(1, #pool)]
end

-- Rolls a mutation at catch time. Returns the mutation name and its $/s multiplier.
function BrainrotData.rollMutation()
	local roll = math.random()
	if roll < 0.01 then
		return "Rainbow", 8
	elseif roll < 0.05 then
		return "Diamond", 4
	elseif roll < 0.15 then
		return "Golden", 2
	end
	return "Normal", 1
end

function BrainrotData.rebirthCashNeeded(rebirths)
	return 10000 * (rebirths + 1)
end

function BrainrotData.rebirthMultiplier(rebirths)
	return 1 + rebirths * 0.5
end

return BrainrotData
