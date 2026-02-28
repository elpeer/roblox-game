local GameConfig = {}

-- Base / Safe Zone
GameConfig.BASE_SIZE = Vector3.new(80, 1, 80)
GameConfig.BASE_COLOR = Color3.fromRGB(85, 170, 85)
GameConfig.BOUNDARY_COLOR = Color3.fromRGB(255, 50, 50)
GameConfig.BOUNDARY_HEIGHT = 8
GameConfig.BASE_SPACING = 200 -- distance between player bases on X axis

-- Abyss / Mission
GameConfig.PLATFORM_WIDTH = 20 -- depth (Z) of each landing platform
GameConfig.PLATFORM_LENGTH = 80 -- width (X) of each landing platform
GameConfig.PLATFORM_HEIGHT = 1
GameConfig.PLATFORM_COLOR = Color3.fromRGB(120, 120, 120)
GameConfig.KILL_ZONE_Y = -50
GameConfig.STARTING_ABYSS_WIDTH = 8
GameConfig.ABYSS_WIDTH_INCREMENT = 2 -- each abyss grows by this much (+ scaling)

-- Speed / Jump
GameConfig.BASE_WALK_SPEED = 16
GameConfig.BASE_JUMP_POWER = 50
GameConfig.SPEED_TO_WALK_RATIO = 0.5
GameConfig.SPEED_TO_JUMP_RATIO = 0.08

-- Treadmill
GameConfig.TREADMILL_CLICK_COOLDOWN = 0.1 -- seconds between clicks

-- Economy
GameConfig.PASSIVE_INCOME_INTERVAL = 1 -- seconds between income ticks

-- Brainrot tier upgrade every N abysses
GameConfig.ABYSSES_PER_TIER = 5

-- Rarity tiers in order
GameConfig.RARITY_ORDER = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"BrainrotGod",
	"Secret",
	"OG",
}

-- Rarity colors for visual display
GameConfig.RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(0, 112, 255),
	Epic = Color3.fromRGB(163, 53, 238),
	Legendary = Color3.fromRGB(255, 215, 0),
	Mythic = Color3.fromRGB(255, 50, 50),
	BrainrotGod = Color3.fromRGB(255, 180, 0),
	Secret = Color3.fromRGB(0, 255, 180),
	OG = Color3.fromRGB(150, 255, 255),
}

-- Abyss width calculation: how wide is abyss number N
function GameConfig.GetAbyssWidth(abyssNumber: number): number
	if abyssNumber <= 20 then
		local widths = {8,10,12,15,18,21,24,28,32,36,40,45,50,55,60,66,72,78,85,92}
		return widths[abyssNumber]
	end
	return 92 + (abyssNumber - 20) * 8
end

-- How many brainrots you get from abyss number N
function GameConfig.GetBrainrotRewardCount(abyssNumber: number): number
	if abyssNumber <= 2 then return 1 end
	if abyssNumber <= 4 then return math.random(1, 2) end
	if abyssNumber <= 6 then return 2 end
	if abyssNumber <= 8 then return math.random(2, 3) end
	if abyssNumber <= 10 then return 3 end
	if abyssNumber <= 12 then return math.random(3, 4) end
	if abyssNumber <= 14 then return math.random(4, 5) end
	if abyssNumber <= 16 then return 5 end
	if abyssNumber <= 18 then return math.random(5, 6) end
	if abyssNumber <= 20 then return math.random(6, 7) end
	return math.random(6, 8)
end

-- Which rarity tier for a given abyss number
function GameConfig.GetTierForAbyss(abyssNumber: number): string
	local tierIndex = math.floor((abyssNumber - 1) / GameConfig.ABYSSES_PER_TIER) + 1
	tierIndex = math.min(tierIndex, #GameConfig.RARITY_ORDER)
	return GameConfig.RARITY_ORDER[tierIndex]
end

return GameConfig
