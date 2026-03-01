--[[
	GameManager - Main game orchestrator
	Creates RemoteEvents, handles player join/leave, creates player bases
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local TreadmillData = require(Modules:WaitForChild("TreadmillData"))

local GameManager = {}
GameManager.PlayerBases = {} -- [userId] = { basePart, boundaryPart, treadmillModel, ... }
GameManager.BasePositions = {} -- [userId] = Vector3
local nextBaseIndex = 0

------------------------------------------------------------
-- 1. Create Remote Events
------------------------------------------------------------
local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = ReplicatedStorage

local remoteNames = {
	"TreadmillClick",      -- Client → Server
	"PurchaseTreadmill",   -- Client → Server
	"PlayerDataUpdate",    -- Server → Client
	"BrainrotNotification",-- Server → Client
	"PurchaseResult",      -- Server → Client
	"RequestData",         -- Client → Server
	"DropBrainrot",        -- Client → Server (drop carried brainrot)
	"CarryUpdate",         -- Server → Client (notify carry state change)
	"PlaceBrainrots",      -- Client → Server (place inventory brainrots on stage)
}

------------------------------------------------------------
-- Daylight Environment Setup
------------------------------------------------------------
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(140, 140, 140)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
Lighting.FogEnd = 10000
Lighting.FogColor = Color3.fromRGB(180, 200, 220)
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1

-- Remove existing sky/atmosphere
for _, child in ipairs(Lighting:GetChildren()) do
	if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") or child:IsA("ColorCorrectionEffect") then
		child:Destroy()
	end
end

-- Bright daytime sky
local sky = Instance.new("Sky")
sky.StarCount = 0
sky.CelestialBodiesShown = true
sky.Parent = Lighting

-- Atmosphere for depth and haze
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Color = Color3.fromRGB(199, 215, 232)
atmosphere.Decay = Color3.fromRGB(92, 120, 160)
atmosphere.Glare = 0.2
atmosphere.Haze = 1
atmosphere.Offset = 0.25
atmosphere.Parent = Lighting

-- Subtle bloom
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.3
bloom.Size = 30
bloom.Threshold = 2
bloom.Parent = Lighting

-- Color correction for vibrant look
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Brightness = 0.05
colorCorrection.Contrast = 0.1
colorCorrection.Saturation = 0.15
colorCorrection.Parent = Lighting

for _, name in ipairs(remoteNames) do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
end

------------------------------------------------------------
-- Clean up default workspace objects (Baseplate, SpawnLocation)
-- These come from Roblox Studio by default and conflict with our bases
------------------------------------------------------------
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("SpawnLocation") or child.Name == "Baseplate" or child.Name == "SpawnLocation" then
		child:Destroy()
	end
end

------------------------------------------------------------
-- Helper: format large numbers (1500 → "1.5K", 2400000 → "2.4M")
------------------------------------------------------------
local function formatNumber(n)
	if n >= 1e12 then return string.format("%.1fT", n / 1e12) end
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

------------------------------------------------------------
-- 2. Create Player Base
------------------------------------------------------------
function GameManager.CreateBase(player: Player): Vector3
	local userId = player.UserId
	local baseIndex = nextBaseIndex
	nextBaseIndex = nextBaseIndex + 1

	-- Position each base along the X axis
	local baseX = baseIndex * GameConfig.BASE_SPACING
	local baseY = 10
	local baseZ = 0
	local basePosition = Vector3.new(baseX, baseY, baseZ)

	GameManager.BasePositions[userId] = basePosition
	GameManager.PlayerBases[userId] = {}
	local parts = GameManager.PlayerBases[userId]

	local bsX = GameConfig.BASE_SIZE.X  -- 200
	local bsZ = GameConfig.BASE_SIZE.Z  -- 200

	-- ============================
	-- MAIN GROUND PLATFORM (clean modern look)
	-- ============================
	local safeZone = Instance.new("Part")
	safeZone.Name = "SafeZone_" .. userId
	safeZone.Size = GameConfig.BASE_SIZE
	safeZone.Position = basePosition
	safeZone.Anchored = true
	safeZone.Color = Color3.fromRGB(85, 170, 75)
	safeZone.Material = Enum.Material.Grass
	safeZone.TopSurface = Enum.SurfaceType.Smooth
	safeZone.Parent = workspace
	table.insert(parts, safeZone)

	-- Neon border ring around the base
	local borderThickness = 1.5
	local borderHeight = 0.5
	local borderColor = Color3.fromRGB(0, 180, 255)
	local borderParts = {
		{size = Vector3.new(bsX + 3, borderHeight, borderThickness), offset = Vector3.new(0, 0.5, -bsZ/2)},
		{size = Vector3.new(bsX + 3, borderHeight, borderThickness), offset = Vector3.new(0, 0.5, bsZ/2)},
		{size = Vector3.new(borderThickness, borderHeight, bsZ), offset = Vector3.new(-bsX/2, 0.5, 0)},
		{size = Vector3.new(borderThickness, borderHeight, bsZ), offset = Vector3.new(bsX/2, 0.5, 0)},
	}
	for i, bp in ipairs(borderParts) do
		local border = Instance.new("Part")
		border.Name = "Border_" .. userId .. "_" .. i
		border.Size = bp.size
		border.Position = basePosition + bp.offset
		border.Anchored = true
		border.Color = borderColor
		border.Material = Enum.Material.Neon
		border.Parent = workspace
		table.insert(parts, border)
	end

	-- ============================
	-- CENTER WALKWAY (clean path leading to abyss)
	-- ============================
	local pathWidth = 14
	local pathLength = bsZ
	local path = Instance.new("Part")
	path.Name = "Path_" .. userId
	path.Size = Vector3.new(pathWidth, 0.2, pathLength)
	path.Position = basePosition + Vector3.new(0, 0.55, 0)
	path.Anchored = true
	path.Color = Color3.fromRGB(200, 200, 200)
	path.Material = Enum.Material.Marble
	path.Parent = workspace
	table.insert(parts, path)

	-- Path neon center stripe
	local centerStripe = Instance.new("Part")
	centerStripe.Name = "PathStripe_" .. userId
	centerStripe.Size = Vector3.new(1, 0.1, pathLength)
	centerStripe.Position = basePosition + Vector3.new(0, 0.7, 0)
	centerStripe.Anchored = true
	centerStripe.CanCollide = false
	centerStripe.Color = Color3.fromRGB(0, 200, 255)
	centerStripe.Material = Enum.Material.Neon
	centerStripe.Parent = workspace
	table.insert(parts, centerStripe)

	-- Side paths to treadmill and display areas
	for _, sideInfo in ipairs({
		{offset = Vector3.new(-35, 0.55, -20)},
		{offset = Vector3.new(35, 0.55, -20)},
	}) do
		local sidePath = Instance.new("Part")
		sidePath.Name = "SidePath_" .. userId
		sidePath.Size = Vector3.new(60, 0.2, 10)
		sidePath.Position = basePosition + sideInfo.offset
		sidePath.Anchored = true
		sidePath.Color = Color3.fromRGB(200, 200, 200)
		sidePath.Material = Enum.Material.Marble
		sidePath.Parent = workspace
		table.insert(parts, sidePath)
	end

	-- ============================
	-- PERIMETER WALLS (brown terraced terrain walls with trees)
	-- ============================
	local wallHeight = 45
	local wallThickness = 8

	-- Terrace layer definitions: {heightFrom, heightTo, color, thickness, material}
	local terraceColors = {
		Color3.fromRGB(100, 70, 40),   -- dark brown (bottom)
		Color3.fromRGB(130, 95, 55),   -- medium brown
		Color3.fromRGB(155, 120, 75),  -- tan
		Color3.fromRGB(170, 140, 95),  -- light tan (top)
	}
	local grassColor = Color3.fromRGB(55, 140, 40)
	local wallTreeColors = {
		Color3.fromRGB(40, 150, 45),
		Color3.fromRGB(50, 170, 55),
		Color3.fromRGB(35, 130, 40),
	}

	-- Helper: build a terraced wall section at a position
	local function buildTerracedWall(wallName, wallSize, wallPos, lengthAxis)
		-- lengthAxis: "X" or "Z" - which axis the wall extends along
		local layerCount = 4
		local layerHeight = wallHeight / layerCount

		for layer = 1, layerCount do
			local yBottom = (layer - 1) * layerHeight
			local yCenter = yBottom + layerHeight / 2
			-- Each layer gets slightly thinner (recessed)
			local recess = (layer - 1) * 1.5
			local layerSize
			if lengthAxis == "X" then
				layerSize = Vector3.new(wallSize.X, layerHeight, wallThickness - recess)
			else
				layerSize = Vector3.new(wallThickness - recess, layerHeight, wallSize.Z)
			end

			local layerPart = Instance.new("Part")
			layerPart.Name = wallName .. "_Layer" .. layer .. "_" .. userId
			layerPart.Size = layerSize
			layerPart.Position = wallPos + Vector3.new(0, yCenter, 0)
			layerPart.Anchored = true
			layerPart.Color = terraceColors[layer]
			layerPart.Material = Enum.Material.Slate
			layerPart.Parent = workspace
			table.insert(parts, layerPart)

			-- Grass strip on each ledge (except bottom)
			if layer > 1 then
				local grassSize
				if lengthAxis == "X" then
					grassSize = Vector3.new(wallSize.X, 0.4, 2)
				else
					grassSize = Vector3.new(2, 0.4, wallSize.Z)
				end
				local grassStrip = Instance.new("Part")
				grassStrip.Name = wallName .. "_Grass" .. layer .. "_" .. userId
				grassStrip.Size = grassSize
				grassStrip.Position = wallPos + Vector3.new(0, yBottom + 0.2, 0)
				grassStrip.Anchored = true
				grassStrip.CanCollide = false
				grassStrip.Color = grassColor
				grassStrip.Material = Enum.Material.Grass
				grassStrip.Parent = workspace
				table.insert(parts, grassStrip)
			end
		end

		-- Top grass strip
		local topGrassSize
		if lengthAxis == "X" then
			topGrassSize = Vector3.new(wallSize.X, 0.5, wallThickness + 2)
		else
			topGrassSize = Vector3.new(wallThickness + 2, 0.5, wallSize.Z)
		end
		local topGrass = Instance.new("Part")
		topGrass.Name = wallName .. "_TopGrass_" .. userId
		topGrass.Size = topGrassSize
		topGrass.Position = wallPos + Vector3.new(0, wallHeight + 0.25, 0)
		topGrass.Anchored = true
		topGrass.CanCollide = false
		topGrass.Color = grassColor
		topGrass.Material = Enum.Material.Grass
		topGrass.Parent = workspace
		table.insert(parts, topGrass)

		-- Trees along the top of the wall
		local wallLength = (lengthAxis == "X") and wallSize.X or wallSize.Z
		local treeCount = math.floor(wallLength / 25)
		for t = 1, treeCount do
			local tFrac = (t - 0.5) / treeCount
			local treeOffset
			if lengthAxis == "X" then
				treeOffset = Vector3.new(-wallSize.X / 2 + tFrac * wallSize.X, wallHeight, 0)
			else
				treeOffset = Vector3.new(0, wallHeight, -wallSize.Z / 2 + tFrac * wallSize.Z)
			end
			-- Vary tree position slightly
			local jitter = math.sin(t * 7.3) * 2

			local trunk = Instance.new("Part")
			trunk.Name = wallName .. "_TreeTrunk_" .. userId .. "_" .. t
			trunk.Size = Vector3.new(2, 8, 2)
			trunk.Position = wallPos + treeOffset + Vector3.new(
				(lengthAxis == "Z") and jitter or 0,
				4.5,
				(lengthAxis == "X") and jitter or 0
			)
			trunk.Anchored = true
			trunk.Color = Color3.fromRGB(80, 55, 25)
			trunk.Material = Enum.Material.Wood
			trunk.Shape = Enum.PartType.Cylinder
			trunk.Orientation = Vector3.new(0, 0, 90)
			trunk.Parent = workspace
			table.insert(parts, trunk)

			local leaves = Instance.new("Part")
			leaves.Name = wallName .. "_TreeLeaves_" .. userId .. "_" .. t
			local leafScale = 0.8 + math.abs(math.sin(t * 3.7)) * 0.6
			leaves.Size = Vector3.new(8 * leafScale, 7 * leafScale, 8 * leafScale)
			leaves.Position = trunk.Position + Vector3.new(0, 6 * leafScale, 0)
			leaves.Anchored = true
			leaves.Color = wallTreeColors[(t % #wallTreeColors) + 1]
			leaves.Material = Enum.Material.Grass
			leaves.Shape = Enum.PartType.Ball
			leaves.Parent = workspace
			table.insert(parts, leaves)
		end
	end

	-- Left wall
	buildTerracedWall("WallLeft",
		Vector3.new(wallThickness, wallHeight, bsZ),
		basePosition + Vector3.new(-bsX/2, 0, 0),
		"Z"
	)
	-- Right wall
	buildTerracedWall("WallRight",
		Vector3.new(wallThickness, wallHeight, bsZ),
		basePosition + Vector3.new(bsX/2, 0, 0),
		"Z"
	)
	-- Back wall
	buildTerracedWall("WallBack",
		Vector3.new(bsX + wallThickness * 2, wallHeight, wallThickness),
		basePosition + Vector3.new(0, 0, -bsZ/2),
		"X"
	)

	-- Front transition walls (close gap between base 200-wide and abyss corridor 100-wide)
	local corridorHalfWidth = GameConfig.PLATFORM_LENGTH / 2 -- 50
	local frontWallWidth = (bsX / 2) - corridorHalfWidth -- 50 studs each side
	if frontWallWidth > 0 then
		for _, fwInfo in ipairs({
			{name = "FrontWallLeft", xOffset = -(corridorHalfWidth + frontWallWidth / 2)},
			{name = "FrontWallRight", xOffset = (corridorHalfWidth + frontWallWidth / 2)},
		}) do
			buildTerracedWall(fwInfo.name,
				Vector3.new(frontWallWidth, wallHeight, wallThickness),
				basePosition + Vector3.new(fwInfo.xOffset, 0, bsZ / 2),
				"X"
			)
		end
	end

	-- ============================
	-- ENTRANCE ARCH (modern neon portal)
	-- ============================
	local archZ = basePosition.Z + bsZ/2
	local archLeft = Instance.new("Part")
	archLeft.Name = "ArchLeft_" .. userId
	archLeft.Size = Vector3.new(3, 16, 3)
	archLeft.Position = Vector3.new(basePosition.X - 10, basePosition.Y + 8, archZ)
	archLeft.Anchored = true
	archLeft.Color = Color3.fromRGB(240, 240, 250)
	archLeft.Material = Enum.Material.SmoothPlastic
	archLeft.Parent = workspace
	table.insert(parts, archLeft)

	local archRight = Instance.new("Part")
	archRight.Name = "ArchRight_" .. userId
	archRight.Size = Vector3.new(3, 16, 3)
	archRight.Position = Vector3.new(basePosition.X + 10, basePosition.Y + 8, archZ)
	archRight.Anchored = true
	archRight.Color = Color3.fromRGB(240, 240, 250)
	archRight.Material = Enum.Material.SmoothPlastic
	archRight.Parent = workspace
	table.insert(parts, archRight)

	local archTop = Instance.new("Part")
	archTop.Name = "ArchTop_" .. userId
	archTop.Size = Vector3.new(24, 2, 3)
	archTop.Position = Vector3.new(basePosition.X, basePosition.Y + 17, archZ)
	archTop.Anchored = true
	archTop.Color = Color3.fromRGB(240, 240, 250)
	archTop.Material = Enum.Material.SmoothPlastic
	archTop.Parent = workspace
	table.insert(parts, archTop)

	-- Neon strips on arch columns
	for _, archPillar in ipairs({archLeft, archRight}) do
		local neonStrip = Instance.new("Part")
		neonStrip.Name = "ArchNeon_" .. userId
		neonStrip.Size = Vector3.new(0.5, 16, 0.5)
		neonStrip.Position = archPillar.Position + Vector3.new(0, 0, 1.5)
		neonStrip.Anchored = true
		neonStrip.CanCollide = false
		neonStrip.Color = Color3.fromRGB(255, 60, 60)
		neonStrip.Material = Enum.Material.Neon
		neonStrip.Parent = workspace
		table.insert(parts, neonStrip)
	end

	-- Neon strip on arch top
	local archTopNeon = Instance.new("Part")
	archTopNeon.Name = "ArchTopNeon_" .. userId
	archTopNeon.Size = Vector3.new(24, 0.5, 0.5)
	archTopNeon.Position = Vector3.new(basePosition.X, basePosition.Y + 18.2, archZ + 1.5)
	archTopNeon.Anchored = true
	archTopNeon.CanCollide = false
	archTopNeon.Color = Color3.fromRGB(255, 60, 60)
	archTopNeon.Material = Enum.Material.Neon
	archTopNeon.Parent = workspace
	table.insert(parts, archTopNeon)

	-- Arch sign
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.new(0, 400, 0, 80)
	signGui.StudsOffset = Vector3.new(0, 2, 0)
	signGui.Adornee = archTop
	signGui.AlwaysOnTop = false
	signGui.Parent = archTop

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "ABYSS COURSE"
	signLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.FredokaOne
	signLabel.TextStrokeTransparency = 0
	signLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	signLabel.Parent = signGui

	-- ============================
	-- TREES (decorative, varied sizes)
	-- ============================
	local treeOffsets = {
		{offset = Vector3.new(-70, 0, -60), scale = 1.0},
		{offset = Vector3.new(-80, 0, -30), scale = 0.8},
		{offset = Vector3.new(-65, 0, 20), scale = 1.2},
		{offset = Vector3.new(-75, 0, 50), scale = 0.9},
		{offset = Vector3.new(70, 0, -60), scale = 1.1},
		{offset = Vector3.new(80, 0, -30), scale = 0.7},
		{offset = Vector3.new(65, 0, 20), scale = 1.0},
		{offset = Vector3.new(75, 0, 50), scale = 1.3},
		{offset = Vector3.new(-40, 0, -80), scale = 0.9},
		{offset = Vector3.new(40, 0, -80), scale = 1.0},
		{offset = Vector3.new(-50, 0, 70), scale = 1.1},
		{offset = Vector3.new(50, 0, 70), scale = 0.8},
	}
	local treeColors = {
		Color3.fromRGB(40, 160, 50),
		Color3.fromRGB(50, 180, 60),
		Color3.fromRGB(35, 140, 45),
		Color3.fromRGB(60, 170, 55),
	}
	for i, treeInfo in ipairs(treeOffsets) do
		local s = treeInfo.scale
		-- Trunk
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk_" .. userId .. "_" .. i
		trunk.Size = Vector3.new(2.5 * s, 10 * s, 2.5 * s)
		trunk.Position = basePosition + treeInfo.offset + Vector3.new(0, 5.5 * s, 0)
		trunk.Anchored = true
		trunk.Color = Color3.fromRGB(90, 60, 30)
		trunk.Material = Enum.Material.Wood
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Orientation = Vector3.new(0, 0, 90)
		trunk.Parent = workspace
		table.insert(parts, trunk)

		-- Leaves
		local leaves = Instance.new("Part")
		leaves.Name = "TreeLeaves_" .. userId .. "_" .. i
		leaves.Size = Vector3.new(10 * s, 9 * s, 10 * s)
		leaves.Position = basePosition + treeInfo.offset + Vector3.new(0, 12 * s, 0)
		leaves.Anchored = true
		leaves.Color = treeColors[(i % #treeColors) + 1]
		leaves.Material = Enum.Material.Grass
		leaves.Shape = Enum.PartType.Ball
		leaves.Parent = workspace
		table.insert(parts, leaves)
	end

	-- ============================
	-- TREADMILL AREA (left side - raised platform with modern look)
	-- ============================
	local treadmillAreaPos = basePosition + Vector3.new(-55, 0, -20)

	-- Raised platform
	local treadmillPlatform = Instance.new("Part")
	treadmillPlatform.Name = "TreadmillPlatform_" .. userId
	treadmillPlatform.Size = Vector3.new(50, 2, 40)
	treadmillPlatform.Position = treadmillAreaPos + Vector3.new(0, 1, 0)
	treadmillPlatform.Anchored = true
	treadmillPlatform.Color = Color3.fromRGB(200, 200, 210)
	treadmillPlatform.Material = Enum.Material.Marble
	treadmillPlatform.Parent = workspace
	table.insert(parts, treadmillPlatform)

	-- Neon border around treadmill platform
	local tmBorderColor = Color3.fromRGB(0, 150, 255)
	for _, bi in ipairs({
		{size = Vector3.new(50, 0.3, 0.5), offset = Vector3.new(0, 2.15, -20)},
		{size = Vector3.new(50, 0.3, 0.5), offset = Vector3.new(0, 2.15, 20)},
		{size = Vector3.new(0.5, 0.3, 40), offset = Vector3.new(-25, 2.15, 0)},
		{size = Vector3.new(0.5, 0.3, 40), offset = Vector3.new(25, 2.15, 0)},
	}) do
		local tmBorder = Instance.new("Part")
		tmBorder.Name = "TMBorder_" .. userId
		tmBorder.Size = bi.size
		tmBorder.Position = treadmillAreaPos + bi.offset
		tmBorder.Anchored = true
		tmBorder.CanCollide = false
		tmBorder.Color = tmBorderColor
		tmBorder.Material = Enum.Material.Neon
		tmBorder.Parent = workspace
		table.insert(parts, tmBorder)
	end

	-- Treadmill
	local treadmillPosition = treadmillAreaPos + Vector3.new(0, 1.5, 0)
	local treadmillBase = Instance.new("Part")
	treadmillBase.Name = "Treadmill_" .. userId
	treadmillBase.Size = Vector3.new(8, 1, 12)
	treadmillBase.Position = treadmillPosition + Vector3.new(0, 0.5, 0)
	treadmillBase.Anchored = true
	treadmillBase.Color = Color3.fromRGB(150, 150, 150)
	treadmillBase.Material = Enum.Material.Metal
	treadmillBase.Parent = workspace
	table.insert(parts, treadmillBase)

	-- Treadmill handles
	local handleLeft = Instance.new("Part")
	handleLeft.Name = "TreadmillHandle_" .. userId
	handleLeft.Size = Vector3.new(0.5, 5, 0.5)
	handleLeft.Position = treadmillPosition + Vector3.new(-3.5, 3, -5)
	handleLeft.Anchored = true
	handleLeft.Color = Color3.fromRGB(80, 80, 80)
	handleLeft.Material = Enum.Material.Metal
	handleLeft.Parent = workspace
	table.insert(parts, handleLeft)

	local handleRight = Instance.new("Part")
	handleRight.Name = "TreadmillHandle_" .. userId
	handleRight.Size = Vector3.new(0.5, 5, 0.5)
	handleRight.Position = treadmillPosition + Vector3.new(3.5, 3, -5)
	handleRight.Anchored = true
	handleRight.Color = Color3.fromRGB(80, 80, 80)
	handleRight.Material = Enum.Material.Metal
	handleRight.Parent = workspace
	table.insert(parts, handleRight)

	-- Treadmill handle bar
	local handleBar = Instance.new("Part")
	handleBar.Name = "TreadmillBar_" .. userId
	handleBar.Size = Vector3.new(7.5, 0.5, 0.5)
	handleBar.Position = treadmillPosition + Vector3.new(0, 5.5, -5)
	handleBar.Anchored = true
	handleBar.Color = Color3.fromRGB(80, 80, 80)
	handleBar.Material = Enum.Material.Metal
	handleBar.Parent = workspace
	table.insert(parts, handleBar)

	-- Treadmill belt
	local belt = Instance.new("Part")
	belt.Name = "TreadmillBelt_" .. userId
	belt.Size = Vector3.new(6, 0.2, 10)
	belt.Position = treadmillPosition + Vector3.new(0, 1.1, 0)
	belt.Anchored = true
	belt.Color = Color3.fromRGB(40, 40, 40)
	belt.Material = Enum.Material.Fabric
	belt.Parent = workspace
	table.insert(parts, belt)

	-- Treadmill label
	local treadmillGui = Instance.new("BillboardGui")
	treadmillGui.Name = "TreadmillLabel"
	treadmillGui.Size = UDim2.new(0, 250, 0, 60)
	treadmillGui.StudsOffset = Vector3.new(0, 4, 0)
	treadmillGui.Adornee = treadmillBase
	treadmillGui.AlwaysOnTop = false
	treadmillGui.Parent = treadmillBase

	local treadmillLabel = Instance.new("TextLabel")
	treadmillLabel.Size = UDim2.new(1, 0, 1, 0)
	treadmillLabel.BackgroundTransparency = 1
	treadmillLabel.Text = "TREADMILL\n(Click in Inventory)"
	treadmillLabel.TextColor3 = Color3.new(1, 1, 1)
	treadmillLabel.TextScaled = true
	treadmillLabel.Font = Enum.Font.FredokaOne
	treadmillLabel.TextStrokeTransparency = 0
	treadmillLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	treadmillLabel.Parent = treadmillGui

	-- "GYM" sign with modern backing panel
	local gymSignBacking = Instance.new("Part")
	gymSignBacking.Name = "GymSignBack_" .. userId
	gymSignBacking.Size = Vector3.new(22, 5, 1)
	gymSignBacking.Position = treadmillAreaPos + Vector3.new(0, 10, -18)
	gymSignBacking.Anchored = true
	gymSignBacking.Color = Color3.fromRGB(30, 30, 40)
	gymSignBacking.Material = Enum.Material.SmoothPlastic
	gymSignBacking.Parent = workspace
	table.insert(parts, gymSignBacking)

	local gymSign = Instance.new("Part")
	gymSign.Name = "GymSign_" .. userId
	gymSign.Size = Vector3.new(20, 3.5, 0.5)
	gymSign.Position = treadmillAreaPos + Vector3.new(0, 10, -17.5)
	gymSign.Anchored = true
	gymSign.Color = Color3.fromRGB(0, 150, 255)
	gymSign.Material = Enum.Material.Neon
	gymSign.Parent = workspace
	table.insert(parts, gymSign)

	local gymSignGui = Instance.new("BillboardGui")
	gymSignGui.Size = UDim2.new(0, 200, 0, 50)
	gymSignGui.Adornee = gymSign
	gymSignGui.AlwaysOnTop = false
	gymSignGui.Parent = gymSign

	local gymSignLabel = Instance.new("TextLabel")
	gymSignLabel.Size = UDim2.new(1, 0, 1, 0)
	gymSignLabel.BackgroundTransparency = 1
	gymSignLabel.Text = "GYM"
	gymSignLabel.TextColor3 = Color3.new(1, 1, 1)
	gymSignLabel.TextScaled = true
	gymSignLabel.Font = Enum.Font.FredokaOne
	gymSignLabel.TextStrokeTransparency = 0
	gymSignLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	gymSignLabel.Parent = gymSignGui

	-- ============================
	-- BRAINROT DISPLAY AREA (right side - showcase stage)
	-- ============================
	local displayAreaPos = basePosition + Vector3.new(55, 0, -20)

	local displayPlatform = Instance.new("Part")
	displayPlatform.Name = "DisplayPlatform_" .. userId
	displayPlatform.Size = Vector3.new(60, 2, 50)
	displayPlatform.Position = displayAreaPos + Vector3.new(0, 1, 0)
	displayPlatform.Anchored = true
	displayPlatform.Color = Color3.fromRGB(50, 50, 65)
	displayPlatform.Material = Enum.Material.Marble
	displayPlatform.Parent = workspace
	table.insert(parts, displayPlatform)

	local displayFloor = Instance.new("Part")
	displayFloor.Name = "BrainrotDisplay_" .. userId
	displayFloor.Size = Vector3.new(58, 0.2, 48)
	displayFloor.Position = displayAreaPos + Vector3.new(0, 2.15, 0)
	displayFloor.Anchored = true
	displayFloor.Color = Color3.fromRGB(40, 40, 55)
	displayFloor.Material = Enum.Material.SmoothPlastic
	displayFloor.Parent = workspace
	table.insert(parts, displayFloor)

	-- Neon border around display platform
	local dpBorderColor = Color3.fromRGB(180, 50, 255)
	for _, bi in ipairs({
		{size = Vector3.new(60, 0.3, 0.5), offset = Vector3.new(0, 2.15, -25)},
		{size = Vector3.new(60, 0.3, 0.5), offset = Vector3.new(0, 2.15, 25)},
		{size = Vector3.new(0.5, 0.3, 50), offset = Vector3.new(-30, 2.15, 0)},
		{size = Vector3.new(0.5, 0.3, 50), offset = Vector3.new(30, 2.15, 0)},
	}) do
		local dpBorder = Instance.new("Part")
		dpBorder.Name = "DPBorder_" .. userId
		dpBorder.Size = bi.size
		dpBorder.Position = displayAreaPos + bi.offset
		dpBorder.Anchored = true
		dpBorder.CanCollide = false
		dpBorder.Color = dpBorderColor
		dpBorder.Material = Enum.Material.Neon
		dpBorder.Parent = workspace
		table.insert(parts, dpBorder)
	end

	-- "MY BRAINROTS" sign with backing panel
	local brSignBacking = Instance.new("Part")
	brSignBacking.Name = "BrainrotSignBack_" .. userId
	brSignBacking.Size = Vector3.new(26, 5, 1)
	brSignBacking.Position = displayAreaPos + Vector3.new(0, 10, -23)
	brSignBacking.Anchored = true
	brSignBacking.Color = Color3.fromRGB(30, 30, 40)
	brSignBacking.Material = Enum.Material.SmoothPlastic
	brSignBacking.Parent = workspace
	table.insert(parts, brSignBacking)

	local brSign = Instance.new("Part")
	brSign.Name = "BrainrotSign_" .. userId
	brSign.Size = Vector3.new(24, 3.5, 0.5)
	brSign.Position = displayAreaPos + Vector3.new(0, 10, -22.5)
	brSign.Anchored = true
	brSign.Color = Color3.fromRGB(180, 50, 255)
	brSign.Material = Enum.Material.Neon
	brSign.Parent = workspace
	table.insert(parts, brSign)

	local brSignGui = Instance.new("BillboardGui")
	brSignGui.Size = UDim2.new(0, 300, 0, 60)
	brSignGui.Adornee = brSign
	brSignGui.AlwaysOnTop = false
	brSignGui.Parent = brSign

	local brSignLabel = Instance.new("TextLabel")
	brSignLabel.Size = UDim2.new(1, 0, 1, 0)
	brSignLabel.BackgroundTransparency = 1
	brSignLabel.Text = player.Name .. "'s BRAINROTS"
	brSignLabel.TextColor3 = Color3.new(1, 1, 1)
	brSignLabel.TextScaled = true
	brSignLabel.Font = Enum.Font.FredokaOne
	brSignLabel.TextStrokeTransparency = 0
	brSignLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	brSignLabel.Parent = brSignGui

	-- ============================
	-- DISPLAY AREA ROOF / CANOPY
	-- ============================
	local roofHeight = 18 -- height above base Y
	local roofY = basePosition.Y + roofHeight

	-- 4 roof support pillars at corners of display area
	local roofPillarPositions = {
		Vector3.new(-28, 0, -23),
		Vector3.new(28, 0, -23),
		Vector3.new(-28, 0, 23),
		Vector3.new(28, 0, 23),
	}
	for i, rOffset in ipairs(roofPillarPositions) do
		local roofPillar = Instance.new("Part")
		roofPillar.Name = "RoofPillar_" .. userId .. "_" .. i
		roofPillar.Size = Vector3.new(2.5, roofHeight - 2, 2.5)
		roofPillar.Position = displayAreaPos + rOffset + Vector3.new(0, (roofHeight - 2) / 2 + 2, 0)
		roofPillar.Anchored = true
		roofPillar.Color = Color3.fromRGB(220, 220, 230)
		roofPillar.Material = Enum.Material.SmoothPlastic
		roofPillar.Parent = workspace
		table.insert(parts, roofPillar)

		-- Neon accent strip on each pillar
		local pillarStrip = Instance.new("Part")
		pillarStrip.Name = "RoofPillarStrip_" .. userId .. "_" .. i
		pillarStrip.Size = Vector3.new(0.5, roofHeight - 2, 0.5)
		pillarStrip.Position = displayAreaPos + rOffset + Vector3.new(0, (roofHeight - 2) / 2 + 2, 1.2)
		pillarStrip.Anchored = true
		pillarStrip.CanCollide = false
		pillarStrip.Color = Color3.fromRGB(180, 50, 255)
		pillarStrip.Material = Enum.Material.Neon
		pillarStrip.Parent = workspace
		table.insert(parts, pillarStrip)
	end

	-- Main roof slab
	local roofSlab = Instance.new("Part")
	roofSlab.Name = "RoofSlab_" .. userId
	roofSlab.Size = Vector3.new(62, 1.5, 52)
	roofSlab.Position = displayAreaPos + Vector3.new(0, roofHeight + 0.75, 0)
	roofSlab.Anchored = true
	roofSlab.Color = Color3.fromRGB(50, 50, 65)
	roofSlab.Material = Enum.Material.SmoothPlastic
	roofSlab.Transparency = 0.15
	roofSlab.Parent = workspace
	table.insert(parts, roofSlab)

	-- Neon border around roof edge
	local roofBorderColor = Color3.fromRGB(180, 50, 255)
	for _, rbi in ipairs({
		{size = Vector3.new(62, 0.4, 0.6), offset = Vector3.new(0, roofHeight + 1.6, -26)},
		{size = Vector3.new(62, 0.4, 0.6), offset = Vector3.new(0, roofHeight + 1.6, 26)},
		{size = Vector3.new(0.6, 0.4, 52), offset = Vector3.new(-31, roofHeight + 1.6, 0)},
		{size = Vector3.new(0.6, 0.4, 52), offset = Vector3.new(31, roofHeight + 1.6, 0)},
	}) do
		local roofBorder = Instance.new("Part")
		roofBorder.Name = "RoofBorder_" .. userId
		roofBorder.Size = rbi.size
		roofBorder.Position = displayAreaPos + rbi.offset
		roofBorder.Anchored = true
		roofBorder.CanCollide = false
		roofBorder.Color = roofBorderColor
		roofBorder.Material = Enum.Material.Neon
		roofBorder.Parent = workspace
		table.insert(parts, roofBorder)
	end

	-- Roof cross beams for visual detail
	for _, beamInfo in ipairs({
		{size = Vector3.new(62, 0.8, 1.5), offset = Vector3.new(0, roofHeight, 0)},
		{size = Vector3.new(1.5, 0.8, 52), offset = Vector3.new(0, roofHeight, 0)},
	}) do
		local beam = Instance.new("Part")
		beam.Name = "RoofBeam_" .. userId
		beam.Size = beamInfo.size
		beam.Position = displayAreaPos + beamInfo.offset
		beam.Anchored = true
		beam.Color = Color3.fromRGB(70, 70, 85)
		beam.Material = Enum.Material.SmoothPlastic
		beam.Parent = workspace
		table.insert(parts, beam)
	end

	-- Hanging lights under roof
	for _, lightOffset in ipairs({
		Vector3.new(-15, roofHeight - 1.5, -10),
		Vector3.new(15, roofHeight - 1.5, -10),
		Vector3.new(-15, roofHeight - 1.5, 10),
		Vector3.new(15, roofHeight - 1.5, 10),
		Vector3.new(0, roofHeight - 1.5, 0),
	}) do
		local roofLight = Instance.new("Part")
		roofLight.Name = "RoofLight_" .. userId
		roofLight.Size = Vector3.new(3, 0.5, 3)
		roofLight.Position = displayAreaPos + lightOffset
		roofLight.Anchored = true
		roofLight.CanCollide = false
		roofLight.Color = Color3.fromRGB(255, 240, 200)
		roofLight.Material = Enum.Material.Neon
		roofLight.Parent = workspace
		table.insert(parts, roofLight)

		local hangLight = Instance.new("PointLight")
		hangLight.Color = Color3.fromRGB(255, 240, 200)
		hangLight.Range = 25
		hangLight.Brightness = 1
		hangLight.Parent = roofLight
	end

	-- ============================
	-- PLAYER NAME SIGN (modern floating sign at center-back)
	-- ============================
	local nameSignBacking = Instance.new("Part")
	nameSignBacking.Name = "NameSignBack_" .. userId
	nameSignBacking.Size = Vector3.new(35, 8, 2)
	nameSignBacking.Position = basePosition + Vector3.new(0, 12, -bsZ/2 + 5)
	nameSignBacking.Anchored = true
	nameSignBacking.Color = Color3.fromRGB(30, 30, 40)
	nameSignBacking.Material = Enum.Material.SmoothPlastic
	nameSignBacking.Parent = workspace
	table.insert(parts, nameSignBacking)

	local nameSign = Instance.new("Part")
	nameSign.Name = "NameSign_" .. userId
	nameSign.Size = Vector3.new(33, 6, 1)
	nameSign.Position = basePosition + Vector3.new(0, 12, -bsZ/2 + 5.5)
	nameSign.Anchored = true
	nameSign.Color = Color3.fromRGB(255, 200, 50)
	nameSign.Material = Enum.Material.Neon
	nameSign.Parent = workspace
	table.insert(parts, nameSign)

	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.new(0, 400, 0, 80)
	nameGui.Adornee = nameSign
	nameGui.AlwaysOnTop = false
	nameGui.Parent = nameSign

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.Name .. "'s Base"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Parent = nameGui

	-- ============================
	-- TORCHES WITH FIRE (around the base)
	-- ============================
	local torchOffsets = {
		Vector3.new(-30, 0, 60),
		Vector3.new(30, 0, 60),
		Vector3.new(-30, 0, -60),
		Vector3.new(30, 0, -60),
		Vector3.new(-60, 0, 0),
		Vector3.new(60, 0, 0),
		Vector3.new(-60, 0, 50),
		Vector3.new(60, 0, 50),
		Vector3.new(-60, 0, -50),
		Vector3.new(60, 0, -50),
		Vector3.new(0, 0, 80),
		Vector3.new(-50, 0, 80),
		Vector3.new(50, 0, 80),
	}
	for i, offset in ipairs(torchOffsets) do
		-- Stone base block
		local torchBase = Instance.new("Part")
		torchBase.Name = "TorchBase_" .. userId .. "_" .. i
		torchBase.Size = Vector3.new(3, 1.5, 3)
		torchBase.Position = basePosition + offset + Vector3.new(0, 0.75, 0)
		torchBase.Anchored = true
		torchBase.Color = Color3.fromRGB(80, 80, 85)
		torchBase.Material = Enum.Material.Slate
		torchBase.Parent = workspace
		table.insert(parts, torchBase)

		-- Wooden pole
		local torchPole = Instance.new("Part")
		torchPole.Name = "TorchPole_" .. userId .. "_" .. i
		torchPole.Size = Vector3.new(1.2, 10, 1.2)
		torchPole.Position = basePosition + offset + Vector3.new(0, 6.5, 0)
		torchPole.Anchored = true
		torchPole.Color = Color3.fromRGB(90, 60, 30)
		torchPole.Material = Enum.Material.Wood
		torchPole.Parent = workspace
		table.insert(parts, torchPole)

		-- Bowl / dish at top
		local torchBowl = Instance.new("Part")
		torchBowl.Name = "TorchBowl_" .. userId .. "_" .. i
		torchBowl.Size = Vector3.new(2.5, 1.5, 2.5)
		torchBowl.Position = basePosition + offset + Vector3.new(0, 12.25, 0)
		torchBowl.Anchored = true
		torchBowl.Color = Color3.fromRGB(50, 50, 55)
		torchBowl.Material = Enum.Material.Metal
		torchBowl.Parent = workspace
		table.insert(parts, torchBowl)

		-- Glowing ember core in the bowl
		local emberCore = Instance.new("Part")
		emberCore.Name = "TorchEmber_" .. userId .. "_" .. i
		emberCore.Size = Vector3.new(1.8, 1, 1.8)
		emberCore.Position = basePosition + offset + Vector3.new(0, 13, 0)
		emberCore.Anchored = true
		emberCore.CanCollide = false
		emberCore.Color = Color3.fromRGB(255, 120, 0)
		emberCore.Material = Enum.Material.Neon
		emberCore.Parent = workspace
		table.insert(parts, emberCore)

		-- Fire particle emitter
		local fireEmitter = Instance.new("ParticleEmitter")
		fireEmitter.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 140, 20)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(255, 60, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 20, 0)),
		})
		fireEmitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.5),
			NumberSequenceKeypoint.new(0.3, 2.5),
			NumberSequenceKeypoint.new(0.7, 1.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		fireEmitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.5, 0.4),
			NumberSequenceKeypoint.new(1, 1),
		})
		fireEmitter.Lifetime = NumberRange.new(0.4, 1.2)
		fireEmitter.Rate = 25
		fireEmitter.Speed = NumberRange.new(3, 7)
		fireEmitter.SpreadAngle = Vector2.new(15, 15)
		fireEmitter.LightEmission = 1
		fireEmitter.Parent = emberCore

		-- Warm fire glow light
		local fireLight = Instance.new("PointLight")
		fireLight.Color = Color3.fromRGB(255, 150, 50)
		fireLight.Range = 40
		fireLight.Brightness = 1.2
		fireLight.Parent = emberCore
	end

	-- ============================
	-- SPAWN POINT (enabled, collidable so players land on it)
	-- ============================
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlayerSpawn_" .. userId
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = basePosition + Vector3.new(0, 1.5, -30)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = true
	spawnLocation.TeamColor = BrickColor.new("Medium stone grey")
	spawnLocation.Enabled = true
	spawnLocation.Parent = workspace
	table.insert(parts, spawnLocation)

	-- ============================
	-- GATE TRIGGER (detect player returning to base with carried brainrot)
	-- ============================
	local gateTrigger = Instance.new("Part")
	gateTrigger.Name = "GateTrigger_" .. userId
	gateTrigger.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, 20, 6)
	gateTrigger.Position = Vector3.new(basePosition.X, basePosition.Y + 10, archZ)
	gateTrigger.Anchored = true
	gateTrigger.Transparency = 1
	gateTrigger.CanCollide = false
	gateTrigger.Parent = workspace
	table.insert(parts, gateTrigger)

	gateTrigger.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			-- Check if player is coming FROM the abyss (moving in -Z direction)
			local hrp = hit.Parent:FindFirstChild("HumanoidRootPart")
			if hrp and hrp.Velocity.Z < -1 then
				-- Player is returning to base
				task.defer(function()
					if _G.MissionManager then
						_G.MissionManager.OnPlayerReturnedToBase(hitPlayer)
					end
				end)
			end
		end
	end)

	-- ============================
	-- BRAINROT PLACEMENT PROMPT (on display area)
	-- ============================
	local placementPart = Instance.new("Part")
	placementPart.Name = "PlacementArea_" .. userId
	placementPart.Size = Vector3.new(30, 4, 30)
	placementPart.Position = displayAreaPos + Vector3.new(0, 3, 0)
	placementPart.Anchored = true
	placementPart.Transparency = 1
	placementPart.CanCollide = false
	placementPart.Parent = workspace
	table.insert(parts, placementPart)

	local placePrompt = Instance.new("ProximityPrompt")
	placePrompt.ActionText = "Place Brainrots"
	placePrompt.ObjectText = "Display Stage"
	placePrompt.KeyboardKeyCode = Enum.KeyCode.E
	placePrompt.HoldDuration = 0
	placePrompt.MaxActivationDistance = 20
	placePrompt.RequiresLineOfSight = false
	placePrompt.Parent = placementPart

	placePrompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer.UserId ~= userId then return end
		local DataManager = _G.DataManager
		if not DataManager then return end
		local data = DataManager.GetData(triggerPlayer)
		if not data then return end

		-- Check if there are brainrots to place
		local hasUnplaced = false
		for _, count in pairs(data.collectedBrainrots) do
			if count > 0 then hasUnplaced = true break end
		end
		if not hasUnplaced then return end

		-- Place all brainrots from inventory to stage
		DataManager.PlaceAllBrainrots(triggerPlayer)

		-- Update display
		GameManager.UpdateBrainrotDisplay(triggerPlayer)

		-- Notify client
		local updateEvent = remotesFolder:FindFirstChild("PlayerDataUpdate")
		if updateEvent then
			updateEvent:FireClient(triggerPlayer, DataManager.GetData(triggerPlayer))
		end

		local notifyEvent = remotesFolder:FindFirstChild("BrainrotNotification")
		if notifyEvent then
			notifyEvent:FireClient(triggerPlayer, {"Brainrots placed on stage!"}, "Legendary")
		end
	end)

	return basePosition
end

-- Update brainrot display models in the base
function GameManager.UpdateBrainrotDisplay(player: Player)
	local DataManager = _G.DataManager
	if not DataManager then return end

	local data = DataManager.GetData(player)
	if not data then return end

	local userId = player.UserId
	local basePos = GameManager.BasePositions[userId]
	if not basePos then return end

	-- Remove old display models
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "BrainrotModel_" .. userId then
			child:Destroy()
		end
	end

	-- Display area: right side of base
	local displayCenter = Vector3.new(basePos.X + 55, basePos.Y + 3, basePos.Z - 20)
	local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

	-- Folder for real brainrot models
	local brainrotModelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")
		or ReplicatedStorage:WaitForChild("BrainrotModels", 5)

	-- Grid layout: 5 columns, 11-stud spacing for roomy individual pedestals
	local columns = 5
	local colSpacing = 11
	local rowSpacing = 11

	local index = 0
	for brainrotName, count in pairs(data.placedBrainrots or {}) do
		local brainrotInfo = BrainrotData.GetByName(brainrotName)
		if brainrotInfo then
			local row = math.floor(index / columns)
			local col = index % columns
			local modelPos = displayCenter + Vector3.new(
				-((columns - 1) * colSpacing / 2) + col * colSpacing,
				0,
				-18 + row * rowSpacing
			)
			local rarityColor = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)

			-- ===== Individual Pedestal =====
			-- Main pedestal base (dark raised platform)
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal"
			pedestal.Size = Vector3.new(6, 1.5, 6)
			pedestal.Position = modelPos + Vector3.new(0, -0.75, 0)
			pedestal.Anchored = true
			pedestal.Color = Color3.fromRGB(50, 50, 60)
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = workspace

			-- Pedestal top surface (slightly lighter)
			local pedestalTop = Instance.new("Part")
			pedestalTop.Name = "PedestalTop"
			pedestalTop.Size = Vector3.new(5.5, 0.15, 5.5)
			pedestalTop.Position = modelPos + Vector3.new(0, 0.08, 0)
			pedestalTop.Anchored = true
			pedestalTop.CanCollide = false
			pedestalTop.Color = Color3.fromRGB(70, 70, 80)
			pedestalTop.Material = Enum.Material.SmoothPlastic
			pedestalTop.Parent = workspace

			-- Neon rim around pedestal in rarity color
			for _, rimInfo in ipairs({
				{size = Vector3.new(6, 0.2, 0.3), offset = Vector3.new(0, 0.1, -3)},
				{size = Vector3.new(6, 0.2, 0.3), offset = Vector3.new(0, 0.1, 3)},
				{size = Vector3.new(0.3, 0.2, 6), offset = Vector3.new(-3, 0.1, 0)},
				{size = Vector3.new(0.3, 0.2, 6), offset = Vector3.new(3, 0.1, 0)},
			}) do
				local rim = Instance.new("Part")
				rim.Name = "PedestalRim"
				rim.Size = rimInfo.size
				rim.Position = modelPos + rimInfo.offset
				rim.Anchored = true
				rim.CanCollide = false
				rim.Color = rarityColor
				rim.Material = Enum.Material.Neon
				rim.Parent = workspace
			end

			-- ===== Green Income Pad (in front of pedestal) =====
			local padPos = modelPos + Vector3.new(0, -0.6, 4.2)
			local incomePad = Instance.new("Part")
			incomePad.Name = "IncomePad"
			incomePad.Size = Vector3.new(5, 0.3, 2.5)
			incomePad.Position = padPos
			incomePad.Anchored = true
			incomePad.Color = Color3.fromRGB(50, 180, 50)
			incomePad.Material = Enum.Material.Neon
			incomePad.Parent = workspace

			-- Income text on the green pad
			local incomePerSec = brainrotInfo.income * count
			local incomeGui = Instance.new("BillboardGui")
			incomeGui.Size = UDim2.new(0, 160, 0, 45)
			incomeGui.StudsOffset = Vector3.new(0, 1.2, 0)
			incomeGui.Adornee = incomePad
			incomeGui.AlwaysOnTop = false
			incomeGui.Parent = incomePad

			local incomeLabel = Instance.new("TextLabel")
			incomeLabel.Size = UDim2.new(1, 0, 1, 0)
			incomeLabel.BackgroundTransparency = 1
			incomeLabel.Text = "$" .. formatNumber(incomePerSec) .. "/s"
			incomeLabel.TextColor3 = Color3.new(1, 1, 1)
			incomeLabel.TextScaled = true
			incomeLabel.Font = Enum.Font.FredokaOne
			incomeLabel.TextStrokeTransparency = 0
			incomeLabel.TextStrokeColor3 = Color3.fromRGB(0, 80, 0)
			incomeLabel.Parent = incomeGui

			-- Create a container model for the brainrot + pedestal parts
			local container = nil
			local adorneePart = nil

			-- Try to use a real model from BrainrotModels folder
			if brainrotModelsFolder then
				local template = brainrotModelsFolder:FindFirstChild(brainrotName)
				if template then
					container = template:Clone()
					container.Name = "BrainrotModel_" .. userId

					-- Find primary part
					local primaryPart = container.PrimaryPart
					if not primaryPart then
						for _, child in ipairs(container:GetDescendants()) do
							if child:IsA("BasePart") then
								primaryPart = child
								container.PrimaryPart = primaryPart
								break
							end
						end
					end

					if primaryPart then
						-- Scale down for display (0.6x)
						local displayScale = 0.6
						for _, part in ipairs(container:GetDescendants()) do
							if part:IsA("BasePart") then
								part.Size = part.Size * displayScale
							end
						end

						-- Position the model on pedestal
						local offset = modelPos + Vector3.new(0, 2, 0) - primaryPart.Position
						for _, part in ipairs(container:GetDescendants()) do
							if part:IsA("BasePart") then
								part.Position = part.Position + offset
								part.Anchored = true
								part.CanCollide = false
							end
						end
						adorneePart = primaryPart
					else
						container:Destroy()
						container = nil
					end
				end
			end

			-- Fallback: build dummy model from parts
			if not container then
				container = Instance.new("Model")
				container.Name = "BrainrotModel_" .. userId

				-- Body (torso)
				local body = Instance.new("Part")
				body.Name = "Body"
				body.Size = Vector3.new(2, 2.5, 1.2)
				body.Position = modelPos + Vector3.new(0, 2.25, 0)
				body.Anchored = true
				body.Color = rarityColor
				body.Material = Enum.Material.SmoothPlastic
				body.Parent = container

				-- Head
				local head = Instance.new("Part")
				head.Name = "Head"
				head.Size = Vector3.new(1.8, 1.8, 1.8)
				head.Shape = Enum.PartType.Ball
				head.Position = modelPos + Vector3.new(0, 4.4, 0)
				head.Anchored = true
				head.Color = rarityColor
				head.Material = Enum.Material.SmoothPlastic
				head.Parent = container

				-- Face
				local face = Instance.new("Decal")
				face.Name = "Face"
				face.Texture = "rbxassetid://7075502596"
				face.Face = Enum.NormalId.Front
				face.Parent = head

				-- Eyes
				for _, eyeOffset in ipairs({-0.35, 0.35}) do
					local eye = Instance.new("Part")
					eye.Name = "Eye"
					eye.Size = Vector3.new(0.35, 0.35, 0.2)
					eye.Position = modelPos + Vector3.new(eyeOffset, 4.6, 0.85)
					eye.Anchored = true
					eye.Color = Color3.new(0, 0, 0)
					eye.Material = Enum.Material.SmoothPlastic
					eye.Parent = container
				end

				-- Arms
				for _, armOffset in ipairs({-1.4, 1.4}) do
					local arm = Instance.new("Part")
					arm.Name = "Arm"
					arm.Size = Vector3.new(0.8, 2, 0.8)
					arm.Position = modelPos + Vector3.new(armOffset, 2.2, 0)
					arm.Anchored = true
					arm.Color = rarityColor
					arm.Material = Enum.Material.SmoothPlastic
					arm.Parent = container
				end

				-- Legs
				for _, legOffset in ipairs({-0.5, 0.5}) do
					local leg = Instance.new("Part")
					leg.Name = "Leg"
					leg.Size = Vector3.new(0.9, 1.8, 0.9)
					leg.Position = modelPos + Vector3.new(legOffset, 0.9, 0)
					leg.Anchored = true
					leg.Color = rarityColor
					leg.Material = Enum.Material.SmoothPlastic
					leg.Parent = container
				end

				container.PrimaryPart = body
				adorneePart = head
			end

			-- Rarity glow effect
			local glowParent = adorneePart or container:FindFirstChildWhichIsA("BasePart")
			if glowParent then
				local glow = Instance.new("PointLight")
				glow.Color = rarityColor
				glow.Range = 10
				glow.Brightness = 0.6
				glow.Parent = glowParent
			end

			-- Parent pedestal parts into the container for cleanup
			pedestal.Parent = container
			pedestalTop.Parent = container
			incomePad.Parent = container

			container.Parent = workspace

			-- Name and count label (floating above character)
			local labelPart = adorneePart or container:FindFirstChildWhichIsA("BasePart")
			if labelPart then
				local nameGui = Instance.new("BillboardGui")
				nameGui.Size = UDim2.new(0, 200, 0, 55)
				nameGui.StudsOffset = Vector3.new(0, 4, 0)
				nameGui.Adornee = labelPart
				nameGui.AlwaysOnTop = false
				nameGui.Parent = labelPart

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = brainrotName
				nameLabel.TextColor3 = rarityColor
				nameLabel.TextScaled = true
				nameLabel.Font = Enum.Font.FredokaOne
				nameLabel.TextStrokeTransparency = 0
				nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				nameLabel.Parent = nameGui

				local countLabel = Instance.new("TextLabel")
				countLabel.Size = UDim2.new(1, 0, 0.45, 0)
				countLabel.Position = UDim2.new(0, 0, 0.55, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "x" .. count
				countLabel.TextColor3 = Color3.new(1, 1, 1)
				countLabel.TextScaled = true
				countLabel.Font = Enum.Font.FredokaOne
				countLabel.TextStrokeTransparency = 0
				countLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				countLabel.Parent = nameGui
			end

			index = index + 1
		end
	end
end

------------------------------------------------------------
-- 3. Cleanup Base
------------------------------------------------------------
function GameManager.CleanupBase(player: Player)
	local userId = player.UserId
	local parts = GameManager.PlayerBases[userId]
	if parts then
		for _, part in ipairs(parts) do
			if part and part.Parent then
				part:Destroy()
			end
		end
	end

	-- Clean up brainrot display models and carried brainrot models
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "BrainrotModel_" .. userId or child.Name == "CarriedBrainrot_" .. userId then
			child:Destroy()
		end
	end

	GameManager.PlayerBases[userId] = nil
	GameManager.BasePositions[userId] = nil
end

------------------------------------------------------------
-- 4. Player Join / Leave
------------------------------------------------------------
local function onPlayerAdded(player: Player)
	-- Track base readiness
	local basePosition = nil
	local baseReady = false

	-- Helper: teleport player to base once ready
	local function teleportToBase(character)
		while not baseReady do task.wait(0.1) end
		task.wait(0.1) -- small delay for character to fully load
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, -30))
		end
		while not _G.EconomyManager do task.wait(0.1) end
		_G.EconomyManager.ApplySpeedToCharacter(player)
	end

	-- Connect CharacterAdded EARLY (before waiting for systems)
	-- so we never miss the first character spawn
	player.CharacterAdded:Connect(function(character)
		teleportToBase(character)
	end)

	-- Wait for DataManager
	while not _G.DataManager do task.wait(0.1) end
	local DataManager = _G.DataManager

	-- Load data
	DataManager.LoadData(player)

	-- Create base
	basePosition = GameManager.CreateBase(player)
	baseReady = true

	-- Create abyss course
	while not _G.MissionManager do task.wait(0.1) end
	_G.MissionManager.CreateAbyssCourse(player, basePosition)

	-- If character already exists, teleport now
	if player.Character then
		task.spawn(function()
			teleportToBase(player.Character)
		end)
	end

	-- Send initial data to client
	task.wait(1)
	local data = DataManager.GetData(player)
	if data then
		local updateEvent = remotesFolder:FindFirstChild("PlayerDataUpdate")
		if updateEvent then
			updateEvent:FireClient(player, data)
		end
	end

	-- Update brainrot display
	GameManager.UpdateBrainrotDisplay(player)
end

local function onPlayerRemoving(player: Player)
	GameManager.CleanupBase(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Handle data request from client
local requestDataEvent = remotesFolder:WaitForChild("RequestData")
requestDataEvent.OnServerEvent:Connect(function(player)
	local DataManager = _G.DataManager
	if DataManager and DataManager.IsDataLoaded(player) then
		local data = DataManager.GetData(player)
		local updateEvent = remotesFolder:FindFirstChild("PlayerDataUpdate")
		if updateEvent and data then
			updateEvent:FireClient(player, data)
		end
	end
end)

-- Handle DropBrainrot from client
local dropEvent = remotesFolder:WaitForChild("DropBrainrot")
dropEvent.OnServerEvent:Connect(function(player)
	if _G.MissionManager then
		_G.MissionManager.DropCarriedBrainrot(player)
	end
end)

-- Handle PlaceBrainrots from client
local placeEvent = remotesFolder:WaitForChild("PlaceBrainrots")
placeEvent.OnServerEvent:Connect(function(player)
	local DataManager = _G.DataManager
	if not DataManager then return end
	local data = DataManager.GetData(player)
	if not data then return end

	DataManager.PlaceAllBrainrots(player)
	GameManager.UpdateBrainrotDisplay(player)

	local updateEvent = remotesFolder:FindFirstChild("PlayerDataUpdate")
	if updateEvent then
		updateEvent:FireClient(player, DataManager.GetData(player))
	end
end)

-- Periodically update brainrot displays
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			GameManager.UpdateBrainrotDisplay(player)
		end
	end
end)

-- Handle players that joined before this script loaded
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		onPlayerAdded(player)
	end)
end

_G.GameManager = GameManager

return GameManager
