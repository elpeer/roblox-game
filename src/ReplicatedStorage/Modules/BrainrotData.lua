local BrainrotData = {}

BrainrotData.Characters = {
	-- ===== COMMON (1-14 coins/sec) =====
	{ name = "Noobini Pizzanini",   rarity = "Common", income = 1 },
	{ name = "Lirili Larila",       rarity = "Common", income = 2 },
	{ name = "Tim Cheesee",         rarity = "Common", income = 3 },
	{ name = "Frurifrura",          rarity = "Common", income = 4 },
	{ name = "Talpa Di Fero",       rarity = "Common", income = 5 },
	{ name = "Svivina Borbardino",  rarity = "Common", income = 6 },
	{ name = "Noobini Santanini",   rarity = "Common", income = 7 },
	{ name = "Raccooni Jandelini",  rarity = "Common", income = 9 },
	{ name = "Pipi Kiwi",           rarity = "Common", income = 10 },
	{ name = "Tartaragno",          rarity = "Common", income = 12 },
	{ name = "Pipi Corni",          rarity = "Common", income = 14 },

	-- ===== RARE (15-75 coins/sec) =====
	{ name = "Trippi Troppi",       rarity = "Rare", income = 15 },
	{ name = "Gangster Footera",    rarity = "Rare", income = 21 },
	{ name = "Bandito Bobritto",    rarity = "Rare", income = 27 },
	{ name = "Boneca Ambalabu",     rarity = "Rare", income = 33 },
	{ name = "Cacto Hipopotamo",    rarity = "Rare", income = 39 },
	{ name = "Ta Ta Ta Ta Sahur",   rarity = "Rare", income = 45 },
	{ name = "Cupkake Koala",       rarity = "Rare", income = 51 },
	{ name = "Tric Tric Baraboom",  rarity = "Rare", income = 57 },
	{ name = "Frogo Elfo",          rarity = "Rare", income = 63 },
	{ name = "Pipi Avocado",        rarity = "Rare", income = 69 },
	{ name = "Pinealotto Fruttarino", rarity = "Rare", income = 75 },

	-- ===== EPIC (80-300 coins/sec) =====
	{ name = "Cappuccino Assassino",           rarity = "Epic", income = 80 },
	{ name = "Bandito Axolito",                rarity = "Epic", income = 98 },
	{ name = "Brr Brr Patapim",                rarity = "Epic", income = 115 },
	{ name = "Avocadini Antilopini",            rarity = "Epic", income = 132 },
	{ name = "Trullimero Trulicina",            rarity = "Epic", income = 150 },
	{ name = "Bambini Crostini",               rarity = "Epic", income = 167 },
	{ name = "Malame Amarele",                 rarity = "Epic", income = 185 },
	{ name = "Bananita Dolphinita",            rarity = "Epic", income = 202 },
	{ name = "Perochello Lemonchello",         rarity = "Epic", income = 220 },
	{ name = "Brri Brri Bicus Dicus Bombicus", rarity = "Epic", income = 237 },
	{ name = "Avocadini Guffo",                rarity = "Epic", income = 255 },
	{ name = "Ti Ti Ti Ti Sahur",              rarity = "Epic", income = 272 },
	{ name = "Mangolin",                       rarity = "Epic", income = 300 },

	-- ===== LEGENDARY (300-1800 coins/sec) =====
	{ name = "Burbaloni Loliloli",       rarity = "Legendary", income = 320 },
	{ name = "Chimpanzini Bananini",     rarity = "Legendary", income = 410 },
	{ name = "Ballerina Cappuccina",     rarity = "Legendary", income = 500 },
	{ name = "Chef Crabracadabra",       rarity = "Legendary", income = 580 },
	{ name = "Lionel Cactuseli",         rarity = "Legendary", income = 660 },
	{ name = "Glorbo Fruttodillo",       rarity = "Legendary", income = 740 },
	{ name = "Blueberrenni Octopusini",  rarity = "Legendary", income = 830 },
	{ name = "Cocosino Mama",            rarity = "Legendary", income = 920 },
	{ name = "Pandaccini Bananini",      rarity = "Legendary", income = 1000 },
	{ name = "Quackula",                 rarity = "Legendary", income = 1080 },
	{ name = "Sigma Boy",               rarity = "Legendary", income = 1160 },
	{ name = "Sigma Girl",              rarity = "Legendary", income = 1240 },
	{ name = "Chocco Bunny",            rarity = "Legendary", income = 1320 },
	{ name = "Puffaball",               rarity = "Legendary", income = 1400 },
	{ name = "Sealo Regalo",            rarity = "Legendary", income = 1490 },
	{ name = "Buho De Fuego",           rarity = "Legendary", income = 1580 },
	{ name = "Strawberrlli Flamingelli", rarity = "Legendary", income = 1680 },
	{ name = "Clickerino Clabo",        rarity = "Legendary", income = 1800 },

	-- ===== MYTHIC (1900-17000 coins/sec) =====
	{ name = "Frigo Camelo",        rarity = "Mythic", income = 1900 },
	{ name = "Cavallo Virtuoso",    rarity = "Mythic", income = 3600 },
	{ name = "Orangutini",          rarity = "Mythic", income = 5300 },
	{ name = "Ananassini",          rarity = "Mythic", income = 6900 },
	{ name = "Rhino Toasterino",    rarity = "Mythic", income = 8600 },
	{ name = "Borbadiro",           rarity = "Mythic", income = 10300 },
	{ name = "Cocrodilo",           rarity = "Mythic", income = 12000 },
	{ name = "Tigrillini",          rarity = "Mythic", income = 13600 },
	{ name = "Watermelini",         rarity = "Mythic", income = 15300 },
	{ name = "Gorillo Subwoofero",  rarity = "Mythic", income = 17000 },

	-- ===== BRAINROT GOD (17500-295000 coins/sec) =====
	{ name = "Cocofanto Elefanto",      rarity = "BrainrotGod", income = 17500 },
	{ name = "Giraffa Celeste",         rarity = "BrainrotGod", income = 48000 },
	{ name = "Tralalero Tralala",       rarity = "BrainrotGod", income = 79000 },
	{ name = "Matteo Tipi Topi Taco",   rarity = "BrainrotGod", income = 110000 },
	{ name = "Orcalero Orcala",         rarity = "BrainrotGod", income = 141000 },
	{ name = "Tralalita Tralala",       rarity = "BrainrotGod", income = 172000 },
	{ name = "Graipuss Medusi",         rarity = "BrainrotGod", income = 203000 },
	{ name = "Garamararambraramanmararaman", rarity = "BrainrotGod", income = 233000 },
	{ name = "Dragoni Canneloni",       rarity = "BrainrotGod", income = 264000 },
	{ name = "Tung Tung Tung Sahur",    rarity = "BrainrotGod", income = 295000 },

	-- ===== SECRET (300000-350000000 coins/sec) =====
	{ name = "La Vacca Saturno Saturnita", rarity = "Secret", income = 300000 },
	{ name = "Nuclearo Dinossauro",        rarity = "Secret", income = 2000000 },
	{ name = "Dragon Gingerini",           rarity = "Secret", income = 15000000 },
	{ name = "Baby Gronk",                 rarity = "Secret", income = 80000000 },
	{ name = "Fanum Tax",                  rarity = "Secret", income = 350000000 },

	-- ===== OG (400000000+ coins/sec) =====
	{ name = "Skibidi Toilet",       rarity = "OG", income = 400000000 },
	{ name = "Meowl",                rarity = "OG", income = 550000000 },
	{ name = "Strawberry Elephant",  rarity = "OG", income = 750000000 },
}

-- Index by rarity for quick lookup
BrainrotData.ByRarity = {}
for _, char in ipairs(BrainrotData.Characters) do
	if not BrainrotData.ByRarity[char.rarity] then
		BrainrotData.ByRarity[char.rarity] = {}
	end
	table.insert(BrainrotData.ByRarity[char.rarity], char)
end

-- Get a random brainrot from a specific rarity tier
function BrainrotData.GetRandomFromTier(rarity: string)
	local pool = BrainrotData.ByRarity[rarity]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[math.random(1, #pool)]
end

-- Get brainrot data by name
function BrainrotData.GetByName(name: string)
	for _, char in ipairs(BrainrotData.Characters) do
		if char.name == name then
			return char
		end
	end
	return nil
end

return BrainrotData
