--[[
	MissionManager - Handles abyss generation, jump detection, and mission completion
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local MissionManager = {}
MissionManager.PlayerAbyssParts = {} -- [userId] = { gapPart, landingPart, killZone, ... }

local function getDataManager()
	while not _G.DataManager do task.wait(0.1) end
	return _G.DataManager
end

local function getBrainrotManager()
	while not _G.BrainrotManager do task.wait(0.1) end
	return _G.BrainrotManager
end

local function sendDataUpdate(player: Player)
	local DataManager = getDataManager()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local updateEvent = remotes:FindFirstChild("PlayerDataUpdate")
		if updateEvent then
			updateEvent:FireClient(player, DataManager.GetData(player))
		end
	end
end

-- Create the abyss course for a player at the given base position
function MissionManager.CreateAbyssCourse(player: Player, basePosition: Vector3)
	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return end

	-- Clean up old course
	MissionManager.CleanupCourse(player)

	local userId = player.UserId
	MissionManager.PlayerAbyssParts[userId] = {}
	local parts = MissionManager.PlayerAbyssParts[userId]

	local abyssNum = data.currentAbyss
	local abyssWidth = GameConfig.GetAbyssWidth(abyssNum)

	-- The abyss area starts at the edge of the Safe Zone
	-- Safe Zone extends from basePosition.Z to basePosition.Z + BASE_SIZE.Z/2
	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2

	-- Start platform (before the gap)
	local startPlatformSize = Vector3.new(GameConfig.PLATFORM_LENGTH, GameConfig.PLATFORM_HEIGHT, GameConfig.PLATFORM_WIDTH)
	local startPlatform = Instance.new("Part")
	startPlatform.Name = "StartPlatform_" .. userId
	startPlatform.Size = startPlatformSize
	startPlatform.Position = Vector3.new(
		basePosition.X,
		basePosition.Y,
		safeZoneEdgeZ + GameConfig.PLATFORM_WIDTH / 2
	)
	startPlatform.Anchored = true
	startPlatform.Color = GameConfig.PLATFORM_COLOR
	startPlatform.Material = Enum.Material.Concrete
	startPlatform.Parent = workspace
	table.insert(parts, startPlatform)

	-- Landing platform (after the gap)
	local landingPlatform = Instance.new("Part")
	landingPlatform.Name = "LandingPlatform_" .. userId
	landingPlatform.Size = startPlatformSize
	landingPlatform.Position = Vector3.new(
		basePosition.X,
		basePosition.Y,
		safeZoneEdgeZ + GameConfig.PLATFORM_WIDTH + abyssWidth + GameConfig.PLATFORM_WIDTH / 2
	)
	landingPlatform.Anchored = true
	landingPlatform.Color = Color3.fromRGB(85, 200, 85)
	landingPlatform.Material = Enum.Material.Concrete
	landingPlatform.Parent = workspace
	table.insert(parts, landingPlatform)

	-- Abyss number display (BillboardGui on landing platform)
	local tierName = GameConfig.GetTierForAbyss(abyssNum)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "AbyssInfo"
	billboard.Size = UDim2.new(0, 200, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.Adornee = landingPlatform
	billboard.AlwaysOnTop = true
	billboard.Parent = landingPlatform

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "Abyss #" .. abyssNum .. "\n[" .. tierName .. "]"
	label.TextColor3 = GameConfig.RARITY_COLORS[tierName] or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	-- Kill zone (invisible part below the gap)
	local killZone = Instance.new("Part")
	killZone.Name = "KillZone_" .. userId
	killZone.Size = Vector3.new(GameConfig.PLATFORM_LENGTH + 40, 1, abyssWidth + 100)
	killZone.Position = Vector3.new(
		basePosition.X,
		GameConfig.KILL_ZONE_Y,
		safeZoneEdgeZ + GameConfig.PLATFORM_WIDTH + abyssWidth / 2
	)
	killZone.Anchored = true
	killZone.Transparency = 1
	killZone.CanCollide = false
	killZone.Parent = workspace
	table.insert(parts, killZone)

	-- Kill zone detection
	killZone.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			-- Teleport back to safe zone
			local character = hitPlayer.Character
			if character then
				local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
				if humanoidRootPart then
					humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, 0))
				end
			end
		end
	end)

	-- Landing detection (invisible trigger on the landing platform)
	local landingTrigger = Instance.new("Part")
	landingTrigger.Name = "LandingTrigger_" .. userId
	landingTrigger.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, 8, GameConfig.PLATFORM_WIDTH)
	landingTrigger.Position = landingPlatform.Position + Vector3.new(0, 4, 0)
	landingTrigger.Anchored = true
	landingTrigger.Transparency = 1
	landingTrigger.CanCollide = false
	landingTrigger.Parent = workspace
	table.insert(parts, landingTrigger)

	landingTrigger.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			MissionManager.OnAbyssCompleted(hitPlayer, basePosition)
		end
	end)

	-- Side walls (invisible) to prevent falling off the sides
	for _, xOffset in ipairs({-GameConfig.PLATFORM_LENGTH / 2 - 1, GameConfig.PLATFORM_LENGTH / 2 + 1}) do
		local wall = Instance.new("Part")
		wall.Name = "SideWall_" .. userId
		wall.Size = Vector3.new(1, 20, abyssWidth + GameConfig.PLATFORM_WIDTH * 2 + 20)
		wall.Position = Vector3.new(
			basePosition.X + xOffset,
			basePosition.Y + 10,
			safeZoneEdgeZ + GameConfig.PLATFORM_WIDTH + abyssWidth / 2
		)
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanCollide = true
		wall.Parent = workspace
		table.insert(parts, wall)
	end
end

-- Called when player successfully crosses the abyss
local completionCooldown = {} -- prevent double-triggers
function MissionManager.OnAbyssCompleted(player: Player, basePosition: Vector3)
	local userId = player.UserId
	local now = tick()

	if completionCooldown[userId] and (now - completionCooldown[userId]) < 2 then
		return
	end
	completionCooldown[userId] = now

	local DataManager = getDataManager()
	local BrainrotManager = getBrainrotManager()
	local data = DataManager.GetData(player)
	if not data then return end

	local abyssNum = data.currentAbyss

	-- Award brainrots
	local awarded = BrainrotManager.AwardBrainrots(player, abyssNum)

	-- Advance to next abyss
	data.currentAbyss = data.currentAbyss + 1
	data.totalAbyssesPassed = data.totalAbyssesPassed + 1

	-- Notify client
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local notifyEvent = remotes:FindFirstChild("BrainrotNotification")
		if notifyEvent then
			notifyEvent:FireClient(player, awarded, GameConfig.GetTierForAbyss(abyssNum))
		end
	end

	-- Teleport player back to safe zone
	local character = player.Character
	if character then
		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart then
			humanoidRootPart.CFrame = CFrame.new(basePosition + Vector3.new(0, 5, 0))
		end
	end

	sendDataUpdate(player)

	-- Regenerate the abyss course with the new (bigger) abyss
	task.wait(1)
	MissionManager.CreateAbyssCourse(player, basePosition)
end

-- Clean up course parts
function MissionManager.CleanupCourse(player: Player)
	local userId = player.UserId
	local parts = MissionManager.PlayerAbyssParts[userId]
	if parts then
		for _, part in ipairs(parts) do
			if part and part.Parent then
				part:Destroy()
			end
		end
	end
	MissionManager.PlayerAbyssParts[userId] = nil
end

-- Player leaving cleanup
Players.PlayerRemoving:Connect(function(player)
	MissionManager.CleanupCourse(player)
	completionCooldown[player.UserId] = nil
end)

_G.MissionManager = MissionManager

return MissionManager
