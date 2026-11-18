-- Brainrot Blast — shared catalogue.
-- The server and the client both require this module, so a price, a rate
-- or a rebirth rule can never be one number on one side and another on the
-- other. Every character, colour and name below is invented for this game.

local Catalogue = {}

-- Starting money, base size, trail shape and the clocks that drive play.
Catalogue.START_CASH = 100
Catalogue.MAX_SLOTS = 6
Catalogue.MAX_BASES = 8
Catalogue.MAX_WALKING = 10
Catalogue.SPAWN_EVERY = 6
Catalogue.WALK_SPEED = 4
Catalogue.TRAIL_START_Z = -80
Catalogue.TRAIL_END_Z = 80
Catalogue.CATCH_RANGE = 14
Catalogue.STEAL_RANGE = 12
Catalogue.STEAL_CARRY_SECONDS = 15
Catalogue.STEAL_COOLDOWN = 30
Catalogue.TSUNAMI_EVERY = 90
Catalogue.TSUNAMI_WARN = 10
Catalogue.REBIRTH_BASE_CASH = 10000

-- Rarities, rarest last. weight is the share of spawns, out of the total.
Catalogue.RARITIES = {
	{ name = "Common", color = Color3.fromRGB(190, 190, 190), weight = 45 },
	{ name = "Rare", color = Color3.fromRGB(80, 160, 255), weight = 25 },
	{ name = "Epic", color = Color3.fromRGB(170, 90, 255), weight = 15 },
	{ name = "Legendary", color = Color3.fromRGB(255, 180, 40), weight = 9 },
	{ name = "Mythic", color = Color3.fromRGB(255, 70, 120), weight = 4.5 },
	{ name = "Brainrot God", color = Color3.fromRGB(255, 240, 90), weight = 1.5 },
}

local function char(name, rarity, rate, price, body, head, size, trim)
	return {
		name = name,
		rarity = rarity,
		rate = rate,
		price = price,
		body = body,
		head = head,
		size = size,
		trim = trim,
	}
end

-- The cast. rate is dollars earned per second, price is what catching
-- costs on the trail, trim picks the head accessory the model builder adds.
Catalogue.CHARACTERS = {
	char("Capybara Kopi", "Common", 5, 50,
		Color3.fromRGB(150, 105, 60), Color3.fromRGB(120, 80, 45), 1.0, "cup"),
	char("Bebek Nasi Goreng", "Common", 8, 100,
		Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 170, 40), 1.0, "hat"),
	char("Kucing Es Teh", "Rare", 20, 350,
		Color3.fromRGB(240, 200, 150), Color3.fromRGB(220, 160, 110), 1.1, "cup"),
	char("Ayam Geprek Terbang", "Rare", 35, 600,
		Color3.fromRGB(255, 245, 230), Color3.fromRGB(255, 90, 60), 1.1, "wings"),
	char("Gajah Micin", "Epic", 80, 1500,
		Color3.fromRGB(140, 140, 200), Color3.fromRGB(110, 110, 170), 1.4, "hat"),
	char("Ular Mie Ayam", "Epic", 120, 2500,
		Color3.fromRGB(255, 215, 90), Color3.fromRGB(200, 60, 60), 1.3, "none"),
	char("Naga Indomie", "Legendary", 300, 6000,
		Color3.fromRGB(230, 60, 60), Color3.fromRGB(255, 200, 60), 1.6, "wings"),
	char("Kera Kopi Susu", "Legendary", 450, 9000,
		Color3.fromRGB(120, 85, 50), Color3.fromRGB(240, 210, 170), 1.5, "crown"),
	char("Raja Durian Emas", "Mythic", 1000, 20000,
		Color3.fromRGB(255, 210, 40), Color3.fromRGB(120, 180, 60), 1.8, "crown"),
	char("Hantu Soto Ayam", "Mythic", 1500, 30000,
		Color3.fromRGB(230, 240, 255), Color3.fromRGB(180, 200, 255), 1.7, "none"),
	char("Dewa Nasi Padang", "Brainrot God", 5000, 100000,
		Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 255, 255), 2.1, "crown"),
	char("Dewa Rendang Abadi", "Brainrot God", 8000, 150000,
		Color3.fromRGB(90, 40, 20), Color3.fromRGB(255, 190, 60), 2.2, "crown"),
}

-- Mutations, rolled once when a brainrot is caught. chance is the upper
-- edge of the roll slice; the slices are checked rarest first, so Golden
-- covers rolls from 0.05 up to 0.15 and the rest stay Normal.
Catalogue.MUTATIONS = {
	{ name = "Rainbow", chance = 0.01, mult = 8 },
	{ name = "Diamond", chance = 0.05, mult = 4 },
	{ name = "Golden", chance = 0.15, mult = 2 },
}

local totalWeight = 0
for _, rarity in ipairs(Catalogue.RARITIES) do
	totalWeight += rarity.weight
end

function Catalogue.rarityColor(rarityName)
	for _, rarity in ipairs(Catalogue.RARITIES) do
		if rarity.name == rarityName then
			return rarity.color
		end
	end
	return Color3.fromRGB(255, 255, 255)
end

function Catalogue.pickRarity()
	local roll = math.random() * totalWeight
	local running = 0
	for _, rarity in ipairs(Catalogue.RARITIES) do
		running += rarity.weight
		if roll <= running then
			return rarity.name
		end
	end
	return Catalogue.RARITIES[1].name
end

function Catalogue.pickCharacter(rarityName)
	local pool = {}
	for _, character in ipairs(Catalogue.CHARACTERS) do
		if character.rarity == rarityName then
			table.insert(pool, character)
		end
	end
	if #pool == 0 then
		return Catalogue.CHARACTERS[1]
	end
	return pool[math.random(#pool)]
end

-- Rolls a catch-time mutation. Returns its name and $/s multiplier.
function Catalogue.rollMutation()
	local roll = math.random()
	for _, mutation in ipairs(Catalogue.MUTATIONS) do
		if roll < mutation.chance then
			return mutation.name, mutation.mult
		end
	end
	return "Normal", 1
end

-- Cash a player must hold to rebirth for the (rebirths + 1)-th time.
-- At least one brainrot on the base is also required (checked server-side).
function Catalogue.rebirthCashNeeded(rebirths)
	return Catalogue.REBIRTH_BASE_CASH * (rebirths + 1)
end

-- Permanent income multiplier after this many rebirths: +50% each.
function Catalogue.rebirthMultiplier(rebirths)
	return 1 + rebirths * 0.5
end

return Catalogue
