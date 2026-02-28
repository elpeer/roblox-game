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
}

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
	-- MAIN GROUND PLATFORM (grass)
	-- ============================
	local safeZone = Instance.new("Part")
	safeZone.Name = "SafeZone_" .. userId
	safeZone.Size = GameConfig.BASE_SIZE
	safeZone.Position = basePosition
	safeZone.Anchored = true
	safeZone.Color = GameConfig.BASE_COLOR
	safeZone.Material = Enum.Material.Grass
	safeZone.TopSurface = Enum.SurfaceType.Smooth
	safeZone.Parent = workspace
	table.insert(parts, safeZone)

	-- ============================
	-- STONE PATH (center walkway leading to abyss)
	-- ============================
	local pathWidth = 12
	local pathLength = bsZ
	local path = Instance.new("Part")
	path.Name = "Path_" .. userId
	path.Size = Vector3.new(pathWidth, 0.15, pathLength)
	path.Position = basePosition + Vector3.new(0, 0.55, 0)
	path.Anchored = true
	path.Color = Color3.fromRGB(180, 170, 150)
	path.Material = Enum.Material.Cobblestone
	path.Parent = workspace
	table.insert(parts, path)

	-- Side paths to treadmill area and brainrot display area
	local sidePath1 = Instance.new("Part")
	sidePath1.Name = "SidePath1_" .. userId
	sidePath1.Size = Vector3.new(60, 0.15, 8)
	sidePath1.Position = basePosition + Vector3.new(-35, 0.55, -20)
	sidePath1.Anchored = true
	sidePath1.Color = Color3.fromRGB(180, 170, 150)
	sidePath1.Material = Enum.Material.Cobblestone
	sidePath1.Parent = workspace
	table.insert(parts, sidePath1)

	local sidePath2 = Instance.new("Part")
	sidePath2.Name = "SidePath2_" .. userId
	sidePath2.Size = Vector3.new(60, 0.15, 8)
	sidePath2.Position = basePosition + Vector3.new(35, 0.55, -20)
	sidePath2.Anchored = true
	sidePath2.Color = Color3.fromRGB(180, 170, 150)
	sidePath2.Material = Enum.Material.Cobblestone
	sidePath2.Parent = workspace
	table.insert(parts, sidePath2)

	-- ============================
	-- PERIMETER WALLS (wooden fence)
	-- ============================
	local wallHeight = 6
	local wallThickness = 2

	-- Left wall
	local wallLeft = Instance.new("Part")
	wallLeft.Name = "WallLeft_" .. userId
	wallLeft.Size = Vector3.new(wallThickness, wallHeight, bsZ)
	wallLeft.Position = basePosition + Vector3.new(-bsX/2, wallHeight/2, 0)
	wallLeft.Anchored = true
	wallLeft.Color = Color3.fromRGB(139, 90, 43)
	wallLeft.Material = Enum.Material.WoodPlanks
	wallLeft.Parent = workspace
	table.insert(parts, wallLeft)

	-- Right wall
	local wallRight = Instance.new("Part")
	wallRight.Name = "WallRight_" .. userId
	wallRight.Size = Vector3.new(wallThickness, wallHeight, bsZ)
	wallRight.Position = basePosition + Vector3.new(bsX/2, wallHeight/2, 0)
	wallRight.Anchored = true
	wallRight.Color = Color3.fromRGB(139, 90, 43)
	wallRight.Material = Enum.Material.WoodPlanks
	wallRight.Parent = workspace
	table.insert(parts, wallRight)

	-- Back wall
	local wallBack = Instance.new("Part")
	wallBack.Name = "WallBack_" .. userId
	wallBack.Size = Vector3.new(bsX, wallHeight, wallThickness)
	wallBack.Position = basePosition + Vector3.new(0, wallHeight/2, -bsZ/2)
	wallBack.Anchored = true
	wallBack.Color = Color3.fromRGB(139, 90, 43)
	wallBack.Material = Enum.Material.WoodPlanks
	wallBack.Parent = workspace
	table.insert(parts, wallBack)

	-- ============================
	-- CORNER TOWERS
	-- ============================
	local towerPositions = {
		Vector3.new(-bsX/2, 0, -bsZ/2),
		Vector3.new(bsX/2, 0, -bsZ/2),
		Vector3.new(-bsX/2, 0, bsZ/2),
		Vector3.new(bsX/2, 0, bsZ/2),
	}
	for i, offset in ipairs(towerPositions) do
		local tower = Instance.new("Part")
		tower.Name = "Tower_" .. userId .. "_" .. i
		tower.Size = Vector3.new(5, 12, 5)
		tower.Position = basePosition + offset + Vector3.new(0, 6, 0)
		tower.Anchored = true
		tower.Color = Color3.fromRGB(100, 65, 30)
		tower.Material = Enum.Material.Wood
		tower.Parent = workspace
		table.insert(parts, tower)

		-- Tower top
		local towerTop = Instance.new("Part")
		towerTop.Name = "TowerTop_" .. userId .. "_" .. i
		towerTop.Size = Vector3.new(7, 1, 7)
		towerTop.Position = basePosition + offset + Vector3.new(0, 12.5, 0)
		towerTop.Anchored = true
		towerTop.Color = Color3.fromRGB(180, 50, 50)
		towerTop.Material = Enum.Material.SmoothPlastic
		towerTop.Parent = workspace
		table.insert(parts, towerTop)
	end

	-- ============================
	-- ENTRANCE ARCH (at the abyss side)
	-- ============================
	local archZ = basePosition.Z + bsZ/2
	local archLeft = Instance.new("Part")
	archLeft.Name = "ArchLeft_" .. userId
	archLeft.Size = Vector3.new(4, 14, 4)
	archLeft.Position = Vector3.new(basePosition.X - 10, basePosition.Y + 7, archZ)
	archLeft.Anchored = true
	archLeft.Color = Color3.fromRGB(100, 100, 110)
	archLeft.Material = Enum.Material.Brick
	archLeft.Parent = workspace
	table.insert(parts, archLeft)

	local archRight = Instance.new("Part")
	archRight.Name = "ArchRight_" .. userId
	archRight.Size = Vector3.new(4, 14, 4)
	archRight.Position = Vector3.new(basePosition.X + 10, basePosition.Y + 7, archZ)
	archRight.Anchored = true
	archRight.Color = Color3.fromRGB(100, 100, 110)
	archRight.Material = Enum.Material.Brick
	archRight.Parent = workspace
	table.insert(parts, archRight)

	local archTop = Instance.new("Part")
	archTop.Name = "ArchTop_" .. userId
	archTop.Size = Vector3.new(24, 3, 4)
	archTop.Position = Vector3.new(basePosition.X, basePosition.Y + 15, archZ)
	archTop.Anchored = true
	archTop.Color = Color3.fromRGB(100, 100, 110)
	archTop.Material = Enum.Material.Brick
	archTop.Parent = workspace
	table.insert(parts, archTop)

	-- Arch sign: "DANGER ZONE - ABYSS AHEAD!"
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.new(0, 400, 0, 80)
	signGui.StudsOffset = Vector3.new(0, 2, 0)
	signGui.Adornee = archTop
	signGui.AlwaysOnTop = false
	signGui.Parent = archTop

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "DANGER ZONE - ABYSS AHEAD!"
	signLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- ============================
	-- TREES (decorative)
	-- ============================
	local treeOffsets = {
		Vector3.new(-70, 0, -60),
		Vector3.new(-80, 0, -30),
		Vector3.new(-65, 0, 20),
		Vector3.new(-75, 0, 50),
		Vector3.new(70, 0, -60),
		Vector3.new(80, 0, -30),
		Vector3.new(65, 0, 20),
		Vector3.new(75, 0, 50),
		Vector3.new(-40, 0, -80),
		Vector3.new(40, 0, -80),
		Vector3.new(-50, 0, 70),
		Vector3.new(50, 0, 70),
	}
	for i, offset in ipairs(treeOffsets) do
		-- Trunk
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk_" .. userId .. "_" .. i
		trunk.Size = Vector3.new(3, 10, 3)
		trunk.Position = basePosition + offset + Vector3.new(0, 5.5, 0)
		trunk.Anchored = true
		trunk.Color = Color3.fromRGB(101, 67, 33)
		trunk.Material = Enum.Material.Wood
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Orientation = Vector3.new(0, 0, 90)
		trunk.Parent = workspace
		table.insert(parts, trunk)

		-- Leaves
		local leaves = Instance.new("Part")
		leaves.Name = "TreeLeaves_" .. userId .. "_" .. i
		leaves.Size = Vector3.new(10, 8, 10)
		leaves.Position = basePosition + offset + Vector3.new(0, 13, 0)
		leaves.Anchored = true
		leaves.Color = Color3.fromRGB(50, 140, 50)
		leaves.Material = Enum.Material.Grass
		leaves.Shape = Enum.PartType.Ball
		leaves.Parent = workspace
		table.insert(parts, leaves)
	end

	-- ============================
	-- TREADMILL AREA (left side - on a raised platform)
	-- ============================
	local treadmillAreaPos = basePosition + Vector3.new(-55, 0, -20)

	-- Raised platform
	local treadmillPlatform = Instance.new("Part")
	treadmillPlatform.Name = "TreadmillPlatform_" .. userId
	treadmillPlatform.Size = Vector3.new(50, 1.5, 40)
	treadmillPlatform.Position = treadmillAreaPos + Vector3.new(0, 0.75, 0)
	treadmillPlatform.Anchored = true
	treadmillPlatform.Color = Color3.fromRGB(160, 160, 160)
	treadmillPlatform.Material = Enum.Material.Concrete
	treadmillPlatform.Parent = workspace
	table.insert(parts, treadmillPlatform)

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

	-- "GYM" sign above treadmill area
	local gymSign = Instance.new("Part")
	gymSign.Name = "GymSign_" .. userId
	gymSign.Size = Vector3.new(20, 4, 1)
	gymSign.Position = treadmillAreaPos + Vector3.new(0, 10, -18)
	gymSign.Anchored = true
	gymSign.Color = Color3.fromRGB(0, 120, 255)
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
	-- BRAINROT DISPLAY AREA (right side - on a raised platform)
	-- ============================
	local displayAreaPos = basePosition + Vector3.new(55, 0, -20)

	local displayPlatform = Instance.new("Part")
	displayPlatform.Name = "DisplayPlatform_" .. userId
	displayPlatform.Size = Vector3.new(60, 1.5, 50)
	displayPlatform.Position = displayAreaPos + Vector3.new(0, 0.75, 0)
	displayPlatform.Anchored = true
	displayPlatform.Color = Color3.fromRGB(60, 60, 80)
	displayPlatform.Material = Enum.Material.SmoothPlastic
	displayPlatform.Parent = workspace
	table.insert(parts, displayPlatform)

	local displayFloor = Instance.new("Part")
	displayFloor.Name = "BrainrotDisplay_" .. userId
	displayFloor.Size = Vector3.new(58, 0.2, 48)
	displayFloor.Position = displayAreaPos + Vector3.new(0, 1.6, 0)
	displayFloor.Anchored = true
	displayFloor.Color = Color3.fromRGB(50, 50, 70)
	displayFloor.Material = Enum.Material.SmoothPlastic
	displayFloor.Parent = workspace
	table.insert(parts, displayFloor)

	-- "MY BRAINROTS" sign
	local brSign = Instance.new("Part")
	brSign.Name = "BrainrotSign_" .. userId
	brSign.Size = Vector3.new(24, 4, 1)
	brSign.Position = displayAreaPos + Vector3.new(0, 10, -23)
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
	-- PLAYER NAME SIGN (center-back of base)
	-- ============================
	local nameSign = Instance.new("Part")
	nameSign.Name = "NameSign_" .. userId
	nameSign.Size = Vector3.new(30, 6, 2)
	nameSign.Position = basePosition + Vector3.new(0, 10, -bsZ/2 + 5)
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
	-- DECORATIVE LIGHTS (around the base)
	-- ============================
	local lightColors = {
		Color3.fromRGB(255, 200, 50),
		Color3.fromRGB(0, 200, 255),
		Color3.fromRGB(255, 100, 100),
		Color3.fromRGB(100, 255, 100),
	}
	local lightOffsets = {
		Vector3.new(-30, 0, 60),
		Vector3.new(30, 0, 60),
		Vector3.new(-30, 0, -60),
		Vector3.new(30, 0, -60),
	}
	for i, offset in ipairs(lightOffsets) do
		local pole = Instance.new("Part")
		pole.Name = "LightPole_" .. userId .. "_" .. i
		pole.Size = Vector3.new(1, 10, 1)
		pole.Position = basePosition + offset + Vector3.new(0, 5.5, 0)
		pole.Anchored = true
		pole.Color = Color3.fromRGB(80, 80, 80)
		pole.Material = Enum.Material.Metal
		pole.Parent = workspace
		table.insert(parts, pole)

		local lamp = Instance.new("Part")
		lamp.Name = "Lamp_" .. userId .. "_" .. i
		lamp.Size = Vector3.new(3, 3, 3)
		lamp.Shape = Enum.PartType.Ball
		lamp.Position = basePosition + offset + Vector3.new(0, 12, 0)
		lamp.Anchored = true
		lamp.Color = lightColors[i]
		lamp.Material = Enum.Material.Neon
		lamp.Parent = workspace
		table.insert(parts, lamp)

		local pointLight = Instance.new("PointLight")
		pointLight.Color = lightColors[i]
		pointLight.Range = 30
		pointLight.Brightness = 1
		pointLight.Parent = lamp
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

	local index = 0
	for brainrotName, count in pairs(data.collectedBrainrots) do
		local brainrotInfo = BrainrotData.GetByName(brainrotName)
		if brainrotInfo then
			local row = math.floor(index / 6)
			local col = index % 6
			local modelPos = displayCenter + Vector3.new(-20 + col * 8, 0, -18 + row * 8)
			local rarityColor = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)

			-- Create a character-like model (head + body + arms + legs)
			local container = Instance.new("Model")
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

			-- Rarity glow effect
			local glow = Instance.new("PointLight")
			glow.Color = rarityColor
			glow.Range = 8
			glow.Brightness = 0.5
			glow.Parent = body

			-- Platform/pedestal under the character
			local pedestal = Instance.new("Part")
			pedestal.Name = "Pedestal"
			pedestal.Size = Vector3.new(3, 0.5, 3)
			pedestal.Position = modelPos + Vector3.new(0, -0.25, 0)
			pedestal.Anchored = true
			pedestal.Color = Color3.fromRGB(40, 40, 40)
			pedestal.Material = Enum.Material.SmoothPlastic
			pedestal.Parent = container

			container.PrimaryPart = body
			container.Parent = workspace

			-- Name and count label
			local nameGui = Instance.new("BillboardGui")
			nameGui.Size = UDim2.new(0, 180, 0, 50)
			nameGui.StudsOffset = Vector3.new(0, 3.5, 0)
			nameGui.Adornee = head
			nameGui.AlwaysOnTop = false
			nameGui.Parent = head

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
