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

	-- Safe Zone Platform
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

	-- Boundary Line (red glowing line at the edge of safe zone)
	local boundaryZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2
	local boundary = Instance.new("Part")
	boundary.Name = "Boundary_" .. userId
	boundary.Size = Vector3.new(GameConfig.BASE_SIZE.X, GameConfig.BOUNDARY_HEIGHT, 1)
	boundary.Position = Vector3.new(basePosition.X, basePosition.Y + GameConfig.BOUNDARY_HEIGHT / 2, boundaryZ)
	boundary.Anchored = true
	boundary.Color = GameConfig.BOUNDARY_COLOR
	boundary.Material = Enum.Material.Neon
	boundary.Transparency = 0.5
	boundary.CanCollide = false
	boundary.Parent = workspace
	table.insert(parts, boundary)

	-- Boundary sign
	local signGui = Instance.new("BillboardGui")
	signGui.Size = UDim2.new(0, 300, 0, 60)
	signGui.StudsOffset = Vector3.new(0, 2, 0)
	signGui.Adornee = boundary
	signGui.AlwaysOnTop = false
	signGui.Parent = boundary

	local signLabel = Instance.new("TextLabel")
	signLabel.Size = UDim2.new(1, 0, 1, 0)
	signLabel.BackgroundTransparency = 1
	signLabel.Text = "DANGER ZONE - ABYSS AHEAD!"
	signLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	signLabel.TextScaled = true
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Parent = signGui

	-- Treadmill model in the base
	local treadmillPosition = Vector3.new(basePosition.X - 15, basePosition.Y + 0.5, basePosition.Z - 10)
	local treadmillBase = Instance.new("Part")
	treadmillBase.Name = "Treadmill_" .. userId
	treadmillBase.Size = Vector3.new(6, 1, 10)
	treadmillBase.Position = treadmillPosition + Vector3.new(0, 0.5, 0)
	treadmillBase.Anchored = true
	treadmillBase.Color = Color3.fromRGB(150, 150, 150)
	treadmillBase.Material = Enum.Material.Metal
	treadmillBase.Parent = workspace
	table.insert(parts, treadmillBase)

	-- Treadmill handles
	local handleLeft = Instance.new("Part")
	handleLeft.Name = "TreadmillHandle_" .. userId
	handleLeft.Size = Vector3.new(0.5, 4, 0.5)
	handleLeft.Position = treadmillPosition + Vector3.new(-2.5, 2.5, -4)
	handleLeft.Anchored = true
	handleLeft.Color = Color3.fromRGB(80, 80, 80)
	handleLeft.Material = Enum.Material.Metal
	handleLeft.Parent = workspace
	table.insert(parts, handleLeft)

	local handleRight = Instance.new("Part")
	handleRight.Name = "TreadmillHandle_" .. userId
	handleRight.Size = Vector3.new(0.5, 4, 0.5)
	handleRight.Position = treadmillPosition + Vector3.new(2.5, 2.5, -4)
	handleRight.Anchored = true
	handleRight.Color = Color3.fromRGB(80, 80, 80)
	handleRight.Material = Enum.Material.Metal
	handleRight.Parent = workspace
	table.insert(parts, handleRight)

	-- Treadmill handle bar
	local handleBar = Instance.new("Part")
	handleBar.Name = "TreadmillBar_" .. userId
	handleBar.Size = Vector3.new(5.5, 0.5, 0.5)
	handleBar.Position = treadmillPosition + Vector3.new(0, 4.5, -4)
	handleBar.Anchored = true
	handleBar.Color = Color3.fromRGB(80, 80, 80)
	handleBar.Material = Enum.Material.Metal
	handleBar.Parent = workspace
	table.insert(parts, handleBar)

	-- Treadmill belt (the running surface)
	local belt = Instance.new("Part")
	belt.Name = "TreadmillBelt_" .. userId
	belt.Size = Vector3.new(4, 0.2, 8)
	belt.Position = treadmillPosition + Vector3.new(0, 1.1, 0)
	belt.Anchored = true
	belt.Color = Color3.fromRGB(40, 40, 40)
	belt.Material = Enum.Material.Fabric
	belt.Parent = workspace
	table.insert(parts, belt)

	-- Treadmill label
	local treadmillGui = Instance.new("BillboardGui")
	treadmillGui.Name = "TreadmillLabel"
	treadmillGui.Size = UDim2.new(0, 200, 0, 50)
	treadmillGui.StudsOffset = Vector3.new(0, 3, 0)
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

	-- Brainrot display area (right side of base)
	local displayAreaPosition = Vector3.new(basePosition.X + 15, basePosition.Y + 0.5, basePosition.Z - 10)
	local displayFloor = Instance.new("Part")
	displayFloor.Name = "BrainrotDisplay_" .. userId
	displayFloor.Size = Vector3.new(30, 0.2, 30)
	displayFloor.Position = displayAreaPosition
	displayFloor.Anchored = true
	displayFloor.Color = Color3.fromRGB(60, 60, 80)
	displayFloor.Material = Enum.Material.SmoothPlastic
	displayFloor.Parent = workspace
	table.insert(parts, displayFloor)

	local displayGui = Instance.new("BillboardGui")
	displayGui.Size = UDim2.new(0, 250, 0, 50)
	displayGui.StudsOffset = Vector3.new(0, 5, 0)
	displayGui.Adornee = displayFloor
	displayGui.AlwaysOnTop = false
	displayGui.Parent = displayFloor

	local displayLabel = Instance.new("TextLabel")
	displayLabel.Size = UDim2.new(1, 0, 1, 0)
	displayLabel.BackgroundTransparency = 1
	displayLabel.Text = player.Name .. "'s Brainrots"
	displayLabel.TextColor3 = Color3.new(1, 1, 1)
	displayLabel.TextScaled = true
	displayLabel.Font = Enum.Font.GothamBold
	displayLabel.Parent = displayGui

	-- Spawn point
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "PlayerSpawn_" .. userId
	spawnLocation.Size = Vector3.new(6, 1, 6)
	spawnLocation.Position = basePosition + Vector3.new(0, 1, -15)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.TeamColor = BrickColor.new("Medium stone grey")
	spawnLocation.Enabled = false -- We'll use manual teleport instead
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
	local displayCenter = Vector3.new(basePos.X + 15, basePos.Y + 1.5, basePos.Z - 10)
	local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

	local index = 0
	for brainrotName, count in pairs(data.collectedBrainrots) do
		local brainrotInfo = BrainrotData.GetByName(brainrotName)
		if brainrotInfo then
			local row = math.floor(index / 6)
			local col = index % 6

			local model = Instance.new("Part")
			model.Name = "BrainrotModel_" .. userId
			model.Size = Vector3.new(3, 3, 3)
			model.Shape = Enum.PartType.Ball
			model.Position = displayCenter + Vector3.new(-12 + col * 5, 1.5, -12 + row * 5)
			model.Anchored = true
			model.Material = Enum.Material.Neon
			model.Color = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)
			model.Parent = workspace

			local nameGui = Instance.new("BillboardGui")
			nameGui.Size = UDim2.new(0, 150, 0, 40)
			nameGui.StudsOffset = Vector3.new(0, 3, 0)
			nameGui.Adornee = model
			nameGui.AlwaysOnTop = false
			nameGui.Parent = model

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = brainrotName
			nameLabel.TextColor3 = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)
			nameLabel.TextScaled = true
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.Parent = nameGui

			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(1, 0, 0.4, 0)
			countLabel.Position = UDim2.new(0, 0, 0.6, 0)
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

	-- Clean up brainrot display models
	for _, child in ipairs(workspace:GetChildren()) do
		if child.Name == "BrainrotModel_" .. userId then
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
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, -15))
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
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, -15))
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
