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
	-- PERIMETER WALLS (clean modern walls)
	-- ============================
	local wallHeight = 5
	local wallThickness = 1.5

	for _, wallInfo in ipairs({
		{name = "WallLeft", size = Vector3.new(wallThickness, wallHeight, bsZ), offset = Vector3.new(-bsX/2, wallHeight/2, 0)},
		{name = "WallRight", size = Vector3.new(wallThickness, wallHeight, bsZ), offset = Vector3.new(bsX/2, wallHeight/2, 0)},
		{name = "WallBack", size = Vector3.new(bsX, wallHeight, wallThickness), offset = Vector3.new(0, wallHeight/2, -bsZ/2)},
	}) do
		local wall = Instance.new("Part")
		wall.Name = wallInfo.name .. "_" .. userId
		wall.Size = wallInfo.size
		wall.Position = basePosition + wallInfo.offset
		wall.Anchored = true
		wall.Color = Color3.fromRGB(220, 220, 230)
		wall.Material = Enum.Material.SmoothPlastic
		wall.Transparency = 0.3
		wall.Parent = workspace
		table.insert(parts, wall)

		-- Neon strip on top of wall
		local strip = Instance.new("Part")
		strip.Name = wallInfo.name .. "Strip_" .. userId
		strip.Size = Vector3.new(wallInfo.size.X, 0.3, wallInfo.size.Z)
		strip.Position = basePosition + wallInfo.offset + Vector3.new(0, wallHeight/2 + 0.15, 0)
		strip.Anchored = true
		strip.CanCollide = false
		strip.Color = Color3.fromRGB(0, 180, 255)
		strip.Material = Enum.Material.Neon
		strip.Parent = workspace
		table.insert(parts, strip)
	end

	-- ============================
	-- CORNER PILLARS (modern glowing pillars)
	-- ============================
	local pillarPositions = {
		Vector3.new(-bsX/2, 0, -bsZ/2),
		Vector3.new(bsX/2, 0, -bsZ/2),
		Vector3.new(-bsX/2, 0, bsZ/2),
		Vector3.new(bsX/2, 0, bsZ/2),
	}
	for i, offset in ipairs(pillarPositions) do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar_" .. userId .. "_" .. i
		pillar.Size = Vector3.new(4, 10, 4)
		pillar.Position = basePosition + offset + Vector3.new(0, 5, 0)
		pillar.Anchored = true
		pillar.Color = Color3.fromRGB(240, 240, 250)
		pillar.Material = Enum.Material.SmoothPlastic
		pillar.Parent = workspace
		table.insert(parts, pillar)

		-- Glowing top cap
		local cap = Instance.new("Part")
		cap.Name = "PillarCap_" .. userId .. "_" .. i
		cap.Size = Vector3.new(5, 1.5, 5)
		cap.Position = basePosition + offset + Vector3.new(0, 10.75, 0)
		cap.Anchored = true
		cap.Color = Color3.fromRGB(0, 180, 255)
		cap.Material = Enum.Material.Neon
		cap.Parent = workspace
		table.insert(parts, cap)

		local pillarLight = Instance.new("PointLight")
		pillarLight.Color = Color3.fromRGB(0, 180, 255)
		pillarLight.Range = 25
		pillarLight.Brightness = 0.5
		pillarLight.Parent = cap
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
	signLabel.Font = Enum.Font.GothamBold
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
	treadmillLabel.Font = Enum.Font.GothamBold
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
	gymSignLabel.Font = Enum.Font.GothamBold
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
	brSignLabel.Font = Enum.Font.GothamBold
	brSignLabel.Parent = brSignGui

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
	createCorner(nameSignBacking, 4)

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
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	-- ============================
	-- MODERN LAMP POSTS (around the base)
	-- ============================
	local lampOffsets = {
		Vector3.new(-30, 0, 60),
		Vector3.new(30, 0, 60),
		Vector3.new(-30, 0, -60),
		Vector3.new(30, 0, -60),
		Vector3.new(-60, 0, 0),
		Vector3.new(60, 0, 0),
	}
	for i, offset in ipairs(lampOffsets) do
		local pole = Instance.new("Part")
		pole.Name = "LampPole_" .. userId .. "_" .. i
		pole.Size = Vector3.new(0.8, 12, 0.8)
		pole.Position = basePosition + offset + Vector3.new(0, 6.5, 0)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(200, 200, 210)
		pole.Material = Enum.Material.SmoothPlastic
		pole.Parent = workspace
		table.insert(parts, pole)

		local lampHead = Instance.new("Part")
		lampHead.Name = "LampHead_" .. userId .. "_" .. i
		lampHead.Size = Vector3.new(2.5, 1, 2.5)
		lampHead.Position = basePosition + offset + Vector3.new(0, 13, 0)
		lampHead.Anchored = true
		lampHead.Color = Color3.fromRGB(255, 240, 200)
		lampHead.Material = Enum.Material.Neon
		lampHead.Parent = workspace
		table.insert(parts, lampHead)

		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(255, 240, 200)
		pointLight.Range = 35
		pointLight.Brightness = 0.8
		pointLight.Parent = lampHead
	end

	-- ============================
	-- SPAWN POINT
	-- ============================
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlayerSpawn_" .. userId
	spawnLocation.Size = Vector3.new(8, 1, 8)
	spawnLocation.Position = basePosition + Vector3.new(0, 1, -30)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.TeamColor = BrickColor.new("Medium stone grey")
	spawnLocation.Enabled = false
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

	-- Create display models for collected brainrots
	local displayCenter = Vector3.new(basePos.X + 55, basePos.Y + 3, basePos.Z - 20)
	local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

	-- Folder for real brainrot models
	local brainrotModelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")

	local index = 0
	for brainrotName, count in pairs(data.placedBrainrots or {}) do
		local brainrotInfo = BrainrotData.GetByName(brainrotName)
		if brainrotInfo then
			local row = math.floor(index / 6)
			local col = index % 6
			local modelPos = displayCenter + Vector3.new(-20 + col * 8, 0, -18 + row * 8)
			local rarityColor = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)

			-- Try to use a real model from BrainrotModels folder
			local container = nil
			local adorneePart = nil

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

						-- Position the model
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

				-- Face (eyes and mouth on the head)
				local face = Instance.new("Decal")
				face.Name = "Face"
				face.Texture = "rbxassetid://7075502596"
				face.Face = Enum.NormalId.Front
				face.Parent = head

				-- Left eye
				local leftEye = Instance.new("Part")
				leftEye.Name = "LeftEye"
				leftEye.Size = Vector3.new(0.35, 0.35, 0.2)
				leftEye.Position = modelPos + Vector3.new(-0.35, 4.6, 0.85)
				leftEye.Anchored = true
				leftEye.Color = Color3.new(0, 0, 0)
				leftEye.Material = Enum.Material.SmoothPlastic
				leftEye.Parent = container

				-- Right eye
				local rightEye = Instance.new("Part")
				rightEye.Name = "RightEye"
				rightEye.Size = Vector3.new(0.35, 0.35, 0.2)
				rightEye.Position = modelPos + Vector3.new(0.35, 4.6, 0.85)
				rightEye.Anchored = true
				rightEye.Color = Color3.new(0, 0, 0)
				rightEye.Material = Enum.Material.SmoothPlastic
				rightEye.Parent = container

				-- Left arm
				local leftArm = Instance.new("Part")
				leftArm.Name = "LeftArm"
				leftArm.Size = Vector3.new(0.8, 2, 0.8)
				leftArm.Position = modelPos + Vector3.new(-1.4, 2.2, 0)
				leftArm.Anchored = true
				leftArm.Color = rarityColor
				leftArm.Material = Enum.Material.SmoothPlastic
				leftArm.Parent = container

				-- Right arm
				local rightArm = Instance.new("Part")
				rightArm.Name = "RightArm"
				rightArm.Size = Vector3.new(0.8, 2, 0.8)
				rightArm.Position = modelPos + Vector3.new(1.4, 2.2, 0)
				rightArm.Anchored = true
				rightArm.Color = rarityColor
				rightArm.Material = Enum.Material.SmoothPlastic
				rightArm.Parent = container

				-- Left leg
				local leftLeg = Instance.new("Part")
				leftLeg.Name = "LeftLeg"
				leftLeg.Size = Vector3.new(0.9, 1.8, 0.9)
				leftLeg.Position = modelPos + Vector3.new(-0.5, 0.9, 0)
				leftLeg.Anchored = true
				leftLeg.Color = rarityColor
				leftLeg.Material = Enum.Material.SmoothPlastic
				leftLeg.Parent = container

				-- Right leg
				local rightLeg = Instance.new("Part")
				rightLeg.Name = "RightLeg"
				rightLeg.Size = Vector3.new(0.9, 1.8, 0.9)
				rightLeg.Position = modelPos + Vector3.new(0.5, 0.9, 0)
				rightLeg.Anchored = true
				rightLeg.Color = rarityColor
				rightLeg.Material = Enum.Material.SmoothPlastic
				rightLeg.Parent = container

				container.PrimaryPart = body
				adorneePart = head
			end

			-- Rarity glow effect
			local glowParent = adorneePart or container:FindFirstChildWhichIsA("BasePart")
			if glowParent then
				local glow = Instance.new("PointLight")
				glow.Color = rarityColor
				glow.Range = 8
				glow.Brightness = 0.5
				glow.Parent = glowParent
			end

			-- Platform/pedestal under the character
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal"
			pedestal.Size = Vector3.new(3, 0.5, 3)
			pedestal.Position = modelPos + Vector3.new(0, -0.25, 0)
			pedestal.Anchored = true
			pedestal.Color = Color3.fromRGB(40, 40, 40)
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = container

			container.Parent = workspace

			-- Name and count label
			local labelPart = adorneePart or container:FindFirstChildWhichIsA("BasePart")
			if labelPart then
				local nameGui = Instance.new("BillboardGui")
				nameGui.Size = UDim2.new(0, 180, 0, 50)
				nameGui.StudsOffset = Vector3.new(0, 3.5, 0)
				nameGui.Adornee = labelPart
				nameGui.AlwaysOnTop = false
				nameGui.Parent = labelPart

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = brainrotName
				nameLabel.TextColor3 = rarityColor
				nameLabel.TextScaled = true
				nameLabel.Font = Enum.Font.GothamBold
				nameLabel.Parent = nameGui

				local countLabel = Instance.new("TextLabel")
				countLabel.Size = UDim2.new(1, 0, 0.45, 0)
				countLabel.Position = UDim2.new(0, 0, 0.55, 0)
				countLabel.BackgroundTransparency = 1
				countLabel.Text = "x" .. count
				countLabel.TextColor3 = Color3.new(1, 1, 1)
				countLabel.TextScaled = true
				countLabel.Font = Enum.Font.Gotham
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
	-- Wait for DataManager
	while not _G.DataManager do task.wait(0.1) end
	local DataManager = _G.DataManager

	-- Load data
	DataManager.LoadData(player)

	-- Create base
	local basePosition = GameManager.CreateBase(player)

	-- Create abyss course
	while not _G.MissionManager do task.wait(0.1) end
	_G.MissionManager.CreateAbyssCourse(player, basePosition)

	-- Teleport player to base
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, -30))
		end

		-- Apply speed stats
		task.wait(0.5)
		while not _G.EconomyManager do task.wait(0.1) end
		_G.EconomyManager.ApplySpeedToCharacter(player)
	end)

	-- If character already exists, teleport now
	if player.Character then
		local humanoidRootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, -30))
		end
		while not _G.EconomyManager do task.wait(0.1) end
		_G.EconomyManager.ApplySpeedToCharacter(player)
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
