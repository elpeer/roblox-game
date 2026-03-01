--[[
	MissionManager - Handles continuous abyss course generation, jump detection,
	brainrot collectibles at each stage, and carrying brainrots above the player's head.

	The course is now CONTINUOUS: after crossing one abyss, the next one follows immediately.
	Brainrot character models appear on each landing platform for the player to collect.
	When collected, the brainrot appears above the player's head (carried).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local MissionManager = {}
MissionManager.PlayerAbyssParts = {} -- [userId] = { all parts }
MissionManager.PlayerCourseState = {} -- [userId] = { currentZ, abyssNum, basePosition }
MissionManager.CarriedBrainrots = {} -- [userId] = model

-- Number of abyss stages to render ahead
local STAGES_AHEAD = 3

-- Folder for real brainrot models (created if missing)
local brainrotModelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")

------------------------------------------------------------
-- Helper: Try to clone a real model from BrainrotModels folder
-- Returns a cloned model positioned at `pos`, or nil if not found
------------------------------------------------------------
local function tryGetRealModel(name, pos, rarityColor, scale, userId)
	if not brainrotModelsFolder then return nil end
	local template = brainrotModelsFolder:FindFirstChild(name)
	if not template then return nil end

	local model = template:Clone()
	model.Name = "AbyssBrainrot_" .. userId

	-- Find the primary part or first BasePart
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				primaryPart = child
				model.PrimaryPart = primaryPart
				break
			end
		end
	end
	if not primaryPart then return nil end

	-- Scale the model if needed (scale=1 means original size)
	if scale and scale ~= 1 then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * scale
			end
		end
	end

	-- Position the model
	local offset = pos + Vector3.new(0, 2.5, 0) - primaryPart.Position
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Position = part.Position + offset
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Add glow
	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Parent = primaryPart

	-- Add name label
	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.new(0, 200, 0, 50)
	nameGui.StudsOffset = Vector3.new(0, 4, 0)
	nameGui.Adornee = primaryPart
	nameGui.AlwaysOnTop = true
	nameGui.Parent = primaryPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	return model
end

------------------------------------------------------------
-- Helper: Try to clone a real model as a mini carried version
-- Returns a model welded to the player's head, or nil if not found
------------------------------------------------------------
local function tryGetRealCarryModel(name, head, rarityColor, userId)
	if not brainrotModelsFolder then return nil end
	local template = brainrotModelsFolder:FindFirstChild(name)
	if not template then return nil end

	local model = template:Clone()
	model.Name = "CarriedBrainrot_" .. userId

	-- Find the primary part
	local primaryPart = model.PrimaryPart
	if not primaryPart then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				primaryPart = child
				model.PrimaryPart = primaryPart
				break
			end
		end
	end
	if not primaryPart then return nil end

	-- Scale down to mini size (0.4x)
	local miniScale = 0.4
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * miniScale
			part.Anchored = false
			part.CanCollide = false
		end
	end

	-- Position above head
	local targetPos = head.Position + Vector3.new(0, 3, 0)
	local offset = targetPos - primaryPart.Position
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + offset
		end
	end

	-- Weld all parts to primary part
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = part
			weld.Parent = primaryPart
		end
	end

	-- Weld primary part to head
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = head
	headWeld.Part1 = primaryPart
	headWeld.Parent = head

	-- Add glow
	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 8
	glow.Brightness = 0.6
	glow.Parent = primaryPart

	-- Add name label
	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.new(0, 150, 0, 30)
	nameGui.StudsOffset = Vector3.new(0, 2, 0)
	nameGui.Adornee = primaryPart
	nameGui.AlwaysOnTop = true
	nameGui.Parent = primaryPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	model.Parent = workspace
	return model
end

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

------------------------------------------------------------
-- Helper: Create a brainrot character model at a position
-- Tries to use a real model from BrainrotModels folder first
------------------------------------------------------------
local function createBrainrotCharacterModel(name, pos, rarityColor, userId)
	-- Try real model first
	local realModel = tryGetRealModel(name, pos, rarityColor, 1, userId)
	if realModel then
		return realModel
	end

	-- Fallback: build a dummy model from parts
	local container = Instance.new("Model")
	container.Name = "AbyssBrainrot_" .. userId

	-- Body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.5, 3, 1.5)
	body.Position = pos + Vector3.new(0, 2.5, 0)
	body.Anchored = true
	body.CanCollide = false
	body.Color = rarityColor
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = container

	-- Head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.Shape = Enum.PartType.Ball
	head.Position = pos + Vector3.new(0, 5.1, 0)
	head.Anchored = true
	head.CanCollide = false
	head.Color = rarityColor
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = container

	-- Eyes
	local leftEye = Instance.new("Part")
	leftEye.Name = "LeftEye"
	leftEye.Size = Vector3.new(0.4, 0.5, 0.25)
	leftEye.Position = pos + Vector3.new(-0.4, 5.3, 1.0)
	leftEye.Anchored = true
	leftEye.CanCollide = false
	leftEye.Color = Color3.new(1, 1, 1)
	leftEye.Material = Enum.Material.SmoothPlastic
	leftEye.Parent = container

	local leftPupil = Instance.new("Part")
	leftPupil.Name = "LeftPupil"
	leftPupil.Size = Vector3.new(0.2, 0.25, 0.1)
	leftPupil.Position = pos + Vector3.new(-0.4, 5.3, 1.15)
	leftPupil.Anchored = true
	leftPupil.CanCollide = false
	leftPupil.Color = Color3.new(0, 0, 0)
	leftPupil.Material = Enum.Material.SmoothPlastic
	leftPupil.Parent = container

	local rightEye = Instance.new("Part")
	rightEye.Name = "RightEye"
	rightEye.Size = Vector3.new(0.4, 0.5, 0.25)
	rightEye.Position = pos + Vector3.new(0.4, 5.3, 1.0)
	rightEye.Anchored = true
	rightEye.CanCollide = false
	rightEye.Color = Color3.new(1, 1, 1)
	rightEye.Material = Enum.Material.SmoothPlastic
	rightEye.Parent = container

	local rightPupil = Instance.new("Part")
	rightPupil.Name = "RightPupil"
	rightPupil.Size = Vector3.new(0.2, 0.25, 0.1)
	rightPupil.Position = pos + Vector3.new(0.4, 5.3, 1.15)
	rightPupil.Anchored = true
	rightPupil.CanCollide = false
	rightPupil.Color = Color3.new(0, 0, 0)
	rightPupil.Material = Enum.Material.SmoothPlastic
	rightPupil.Parent = container

	-- Mouth (smile)
	local mouth = Instance.new("Part")
	mouth.Name = "Mouth"
	mouth.Size = Vector3.new(0.6, 0.15, 0.1)
	mouth.Position = pos + Vector3.new(0, 4.7, 1.05)
	mouth.Anchored = true
	mouth.CanCollide = false
	mouth.Color = Color3.fromRGB(30, 30, 30)
	mouth.Material = Enum.Material.SmoothPlastic
	mouth.Parent = container

	-- Left arm
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(0.9, 2.2, 0.9)
	leftArm.Position = pos + Vector3.new(-1.7, 2.5, 0)
	leftArm.Anchored = true
	leftArm.CanCollide = false
	leftArm.Color = rarityColor
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.Parent = container

	-- Right arm
	local rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Size = Vector3.new(0.9, 2.2, 0.9)
	rightArm.Position = pos + Vector3.new(1.7, 2.5, 0)
	rightArm.Anchored = true
	rightArm.CanCollide = false
	rightArm.Color = rarityColor
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.Parent = container

	-- Left leg
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "LeftLeg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.Position = pos + Vector3.new(-0.6, 1, 0)
	leftLeg.Anchored = true
	leftLeg.CanCollide = false
	leftLeg.Color = rarityColor
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.Parent = container

	-- Right leg
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "RightLeg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.Position = pos + Vector3.new(0.6, 1, 0)
	rightLeg.Anchored = true
	rightLeg.CanCollide = false
	rightLeg.Color = rarityColor
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.Parent = container

	-- Glow
	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Parent = body

	-- Name label
	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.new(0, 200, 0, 50)
	nameGui.StudsOffset = Vector3.new(0, 4, 0)
	nameGui.Adornee = head
	nameGui.AlwaysOnTop = true
	nameGui.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	container.PrimaryPart = body
	return container
end

------------------------------------------------------------
-- Create a single abyss stage (platform + gap + landing + brainrots)
------------------------------------------------------------
local function createAbyssStage(player, userId, basePosition, abyssNum, startZ, parts)
	local abyssWidth = GameConfig.GetAbyssWidth(abyssNum)
	local tierName = GameConfig.GetTierForAbyss(abyssNum)
	local tierColor = GameConfig.RARITY_COLORS[tierName] or Color3.new(1, 1, 1)

	-- Start platform
	local startPlatform = Instance.new("Part")
	startPlatform.Name = "StartPlatform_" .. userId .. "_" .. abyssNum
	startPlatform.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, GameConfig.PLATFORM_HEIGHT, GameConfig.PLATFORM_WIDTH)
	startPlatform.Position = Vector3.new(
		basePosition.X,
		basePosition.Y,
		startZ + GameConfig.PLATFORM_WIDTH / 2
	)
	startPlatform.Anchored = true
	startPlatform.Color = GameConfig.PLATFORM_COLOR
	startPlatform.Material = Enum.Material.Concrete
	startPlatform.Parent = workspace
	table.insert(parts, startPlatform)

	-- Abyss number sign on the start platform
	local stageSign = Instance.new("BillboardGui")
	stageSign.Name = "StageSign"
	stageSign.Size = UDim2.new(0, 250, 0, 100)
	stageSign.StudsOffset = Vector3.new(0, 8, 0)
	stageSign.Adornee = startPlatform
	stageSign.AlwaysOnTop = true
	stageSign.Parent = startPlatform

	local stageLabel = Instance.new("TextLabel")
	stageLabel.Size = UDim2.new(1, 0, 1, 0)
	stageLabel.BackgroundTransparency = 1
	stageLabel.Text = "Abyss #" .. abyssNum .. "\n[" .. tierName .. "]\nJump Distance: " .. abyssWidth
	stageLabel.TextColor3 = tierColor
	stageLabel.TextScaled = true
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.Parent = stageSign

	-- Brainrot characters on the start platform (collectible preview)
	local brainrotCount = GameConfig.GetBrainrotRewardCount(abyssNum)
	local brainrotsOnStage = {}
	for i = 1, math.min(brainrotCount, 3) do
		local brainrot = BrainrotData.GetRandomFromTier(tierName)
		if brainrot then
			local xOffset = (i - 2) * 6  -- spread across the platform
			local brainrotPos = Vector3.new(
				basePosition.X + xOffset,
				basePosition.Y + 1,
				startZ + GameConfig.PLATFORM_WIDTH / 2
			)
			local brainrotColor = GameConfig.RARITY_COLORS[brainrot.rarity] or Color3.new(1, 1, 1)
			local brainrotModel = createBrainrotCharacterModel(brainrot.name, brainrotPos, brainrotColor, userId)
			brainrotModel.Parent = workspace
			table.insert(parts, brainrotModel)
			table.insert(brainrotsOnStage, brainrot)
		end
	end

	-- Landing platform (after the gap)
	local landingZ = startZ + GameConfig.PLATFORM_WIDTH + abyssWidth
	local landingPlatform = Instance.new("Part")
	landingPlatform.Name = "LandingPlatform_" .. userId .. "_" .. abyssNum
	landingPlatform.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, GameConfig.PLATFORM_HEIGHT, GameConfig.PLATFORM_WIDTH)
	landingPlatform.Position = Vector3.new(
		basePosition.X,
		basePosition.Y,
		landingZ + GameConfig.PLATFORM_WIDTH / 2
	)
	landingPlatform.Anchored = true
	landingPlatform.Color = Color3.fromRGB(85, 200, 85)
	landingPlatform.Material = Enum.Material.Concrete
	landingPlatform.Parent = workspace
	table.insert(parts, landingPlatform)

	-- Kill zone below the gap
	local killZone = Instance.new("Part")
	killZone.Name = "KillZone_" .. userId .. "_" .. abyssNum
	killZone.Size = Vector3.new(GameConfig.PLATFORM_LENGTH + 40, 1, abyssWidth + 20)
	killZone.Position = Vector3.new(
		basePosition.X,
		GameConfig.KILL_ZONE_Y,
		startZ + GameConfig.PLATFORM_WIDTH + abyssWidth / 2
	)
	killZone.Anchored = true
	killZone.Transparency = 1
	killZone.CanCollide = false
	killZone.Parent = workspace
	table.insert(parts, killZone)

	-- Kill zone: teleport back to start platform (not safe zone!)
	killZone.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			local character = hitPlayer.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					-- Teleport to start of this abyss stage
					hrp.CFrame = CFrame.new(
						basePosition.X,
						basePosition.Y + 5,
						startZ + GameConfig.PLATFORM_WIDTH / 2
					)
				end
			end
		end
	end)

	-- Landing trigger
	local landingTrigger = Instance.new("Part")
	landingTrigger.Name = "LandingTrigger_" .. userId .. "_" .. abyssNum
	landingTrigger.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, 10, GameConfig.PLATFORM_WIDTH)
	landingTrigger.Position = landingPlatform.Position + Vector3.new(0, 5, 0)
	landingTrigger.Anchored = true
	landingTrigger.Transparency = 1
	landingTrigger.CanCollide = false
	landingTrigger.Parent = workspace
	table.insert(parts, landingTrigger)

	landingTrigger.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			MissionManager.OnAbyssCompleted(hitPlayer, basePosition, abyssNum)
		end
	end)

	-- Side walls
	for _, xOffset in ipairs({-GameConfig.PLATFORM_LENGTH / 2 - 1, GameConfig.PLATFORM_LENGTH / 2 + 1}) do
		local wall = Instance.new("Part")
		wall.Name = "SideWall_" .. userId .. "_" .. abyssNum
		wall.Size = Vector3.new(1, 30, abyssWidth + GameConfig.PLATFORM_WIDTH * 2 + 20)
		wall.Position = Vector3.new(
			basePosition.X + xOffset,
			basePosition.Y + 15,
			startZ + GameConfig.PLATFORM_WIDTH + abyssWidth / 2
		)
		wall.Anchored = true
		wall.Transparency = 1
		wall.CanCollide = true
		wall.Parent = workspace
		table.insert(parts, wall)
	end

	-- Return the end Z position (where the next stage starts)
	local endZ = landingZ + GameConfig.PLATFORM_WIDTH
	return endZ
end

------------------------------------------------------------
-- Create the full continuous abyss course
------------------------------------------------------------
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
	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2

	-- Build multiple stages ahead
	local currentZ = safeZoneEdgeZ
	for i = 0, STAGES_AHEAD - 1 do
		local stageAbyssNum = abyssNum + i
		currentZ = createAbyssStage(player, userId, basePosition, stageAbyssNum, currentZ, parts)
	end

	-- Store course state
	MissionManager.PlayerCourseState[userId] = {
		basePosition = basePosition,
		currentAbyssNum = abyssNum,
		stagesBuiltUpTo = abyssNum + STAGES_AHEAD - 1,
	}
end

------------------------------------------------------------
-- Extend the course when player completes a stage
------------------------------------------------------------
local function extendCourse(player, basePosition)
	local userId = player.UserId
	local state = MissionManager.PlayerCourseState[userId]
	if not state then return end

	local parts = MissionManager.PlayerAbyssParts[userId]
	if not parts then return end

	-- Calculate where the next stage should start
	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2
	local currentZ = safeZoneEdgeZ

	-- Walk through all existing stages to find the end position
	for stageNum = state.currentAbyssNum, state.stagesBuiltUpTo do
		local abyssWidth = GameConfig.GetAbyssWidth(stageNum)
		currentZ = currentZ + GameConfig.PLATFORM_WIDTH + abyssWidth + GameConfig.PLATFORM_WIDTH
	end

	-- Add one more stage
	local newStageNum = state.stagesBuiltUpTo + 1
	createAbyssStage(player, userId, basePosition, newStageNum, currentZ, parts)
	state.stagesBuiltUpTo = newStageNum
	state.currentAbyssNum = state.currentAbyssNum + 1
end

------------------------------------------------------------
-- Carry brainrot above player's head
------------------------------------------------------------
function MissionManager.CarryBrainrot(player: Player, brainrotName: string, rarityColor: Color3)
	local userId = player.UserId
	local character = player.Character
	if not character then return end

	-- Remove old carried brainrot
	MissionManager.RemoveCarriedBrainrot(player)

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Try real model first
	local realCarry = tryGetRealCarryModel(brainrotName, head, rarityColor, userId)
	if realCarry then
		MissionManager.CarriedBrainrots[userId] = realCarry
		return
	end

	-- Fallback: Create a mini brainrot model to sit on the player's head
	local carryModel = Instance.new("Model")
	carryModel.Name = "CarriedBrainrot_" .. userId

	-- Mini body
	local miniBody = Instance.new("Part")
	miniBody.Name = "MiniBody"
	miniBody.Size = Vector3.new(1.2, 1.5, 0.8)
	miniBody.Anchored = false
	miniBody.CanCollide = false
	miniBody.Color = rarityColor
	miniBody.Material = Enum.Material.SmoothPlastic
	miniBody.Parent = carryModel

	-- Mini head
	local miniHead = Instance.new("Part")
	miniHead.Name = "MiniHead"
	miniHead.Size = Vector3.new(1.2, 1.2, 1.2)
	miniHead.Shape = Enum.PartType.Ball
	miniHead.Anchored = false
	miniHead.CanCollide = false
	miniHead.Color = rarityColor
	miniHead.Material = Enum.Material.SmoothPlastic
	miniHead.Parent = carryModel

	-- Mini eyes
	local mLeftEye = Instance.new("Part")
	mLeftEye.Name = "mLeftEye"
	mLeftEye.Size = Vector3.new(0.2, 0.25, 0.15)
	mLeftEye.Anchored = false
	mLeftEye.CanCollide = false
	mLeftEye.Color = Color3.new(1, 1, 1)
	mLeftEye.Material = Enum.Material.SmoothPlastic
	mLeftEye.Parent = carryModel

	local mRightEye = Instance.new("Part")
	mRightEye.Name = "mRightEye"
	mRightEye.Size = Vector3.new(0.2, 0.25, 0.15)
	mRightEye.Anchored = false
	mRightEye.CanCollide = false
	mRightEye.Color = Color3.new(1, 1, 1)
	mRightEye.Material = Enum.Material.SmoothPlastic
	mRightEye.Parent = carryModel

	-- Mini left arm
	local mLeftArm = Instance.new("Part")
	mLeftArm.Name = "mLeftArm"
	mLeftArm.Size = Vector3.new(0.4, 1.2, 0.4)
	mLeftArm.Anchored = false
	mLeftArm.CanCollide = false
	mLeftArm.Color = rarityColor
	mLeftArm.Material = Enum.Material.SmoothPlastic
	mLeftArm.Parent = carryModel

	-- Mini right arm
	local mRightArm = Instance.new("Part")
	mRightArm.Name = "mRightArm"
	mRightArm.Size = Vector3.new(0.4, 1.2, 0.4)
	mRightArm.Anchored = false
	mRightArm.CanCollide = false
	mRightArm.Color = rarityColor
	mRightArm.Material = Enum.Material.SmoothPlastic
	mRightArm.Parent = carryModel

	-- Glow
	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 8
	glow.Brightness = 0.6
	glow.Parent = miniBody

	-- Name label
	local nameGui = Instance.new("BillboardGui")
	nameGui.Size = UDim2.new(0, 150, 0, 30)
	nameGui.StudsOffset = Vector3.new(0, 2, 0)
	nameGui.Adornee = miniHead
	nameGui.AlwaysOnTop = true
	nameGui.Parent = miniHead

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = brainrotName
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = nameGui

	carryModel.PrimaryPart = miniBody

	-- Weld all parts to the body
	local function weldTo(part, offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = miniBody
		weld.Part1 = part
		weld.Parent = miniBody
		part.CFrame = miniBody.CFrame * offset
	end

	-- Place the model above the player's head
	miniBody.CFrame = head.CFrame * CFrame.new(0, 2.5, 0)
	weldTo(miniHead, CFrame.new(0, 1.35, 0))
	weldTo(mLeftEye, CFrame.new(-0.25, 1.5, 0.55))
	weldTo(mRightEye, CFrame.new(0.25, 1.5, 0.55))
	weldTo(mLeftArm, CFrame.new(-0.8, 0, 0))
	weldTo(mRightArm, CFrame.new(0.8, 0, 0))

	-- Weld the body to the player's head
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = head
	headWeld.Part1 = miniBody
	headWeld.Parent = head

	carryModel.Parent = workspace
	MissionManager.CarriedBrainrots[userId] = carryModel
end

function MissionManager.RemoveCarriedBrainrot(player: Player)
	local userId = player.UserId
	local model = MissionManager.CarriedBrainrots[userId]
	if model and model.Parent then
		model:Destroy()
	end
	MissionManager.CarriedBrainrots[userId] = nil
end

------------------------------------------------------------
-- Called when player successfully crosses an abyss
------------------------------------------------------------
local completionCooldown = {} -- prevent double-triggers
function MissionManager.OnAbyssCompleted(player: Player, basePosition: Vector3, completedAbyssNum: number)
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

	-- Only process if this is the current abyss (prevent re-triggering old stages)
	if completedAbyssNum ~= data.currentAbyss then
		return
	end

	local abyssNum = data.currentAbyss

	-- Award brainrots
	local awarded = BrainrotManager.AwardBrainrots(player, abyssNum)

	-- Carry the last awarded brainrot above the player's head
	if #awarded > 0 then
		local lastBrainrotName = awarded[#awarded]
		local brainrotInfo = BrainrotData.GetByName(lastBrainrotName)
		if brainrotInfo then
			local rarityColor = GameConfig.RARITY_COLORS[brainrotInfo.rarity] or Color3.new(1, 1, 1)
			MissionManager.CarryBrainrot(player, lastBrainrotName, rarityColor)
		end
	end

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

	sendDataUpdate(player)

	-- Extend the course forward instead of rebuilding
	extendCourse(player, basePosition)

	-- Update brainrot display in base
	if _G.GameManager then
		_G.GameManager.UpdateBrainrotDisplay(player)
	end
end

------------------------------------------------------------
-- Clean up course parts
------------------------------------------------------------
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
	MissionManager.PlayerCourseState[userId] = nil

	-- Also remove carried brainrot
	MissionManager.RemoveCarriedBrainrot(player)
end

-- Player leaving cleanup
Players.PlayerRemoving:Connect(function(player)
	MissionManager.CleanupCourse(player)
	completionCooldown[player.UserId] = nil
end)

-- Re-attach carried brainrot when character respawns
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- Small delay to let character fully load
		task.wait(1)
		MissionManager.RemoveCarriedBrainrot(player)
	end)
end)

_G.MissionManager = MissionManager

return MissionManager
