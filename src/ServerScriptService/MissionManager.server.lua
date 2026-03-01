--[[
	MissionManager - Handles continuous abyss course generation, jump detection,
	brainrot collectibles with E-key pickup (ProximityPrompt), carry/drop mechanic,
	lava visuals, and 100 continuous stages.

	Flow:
	1. Player crosses abyss -> brainrots spawn on landing platform
	2. Player presses E to pick up (ProximityPrompt) -> brainrot on head
	3. Red DROP button on client UI
	4. Return to base gate -> brainrot added to inventory (collectedBrainrots)
	5. At display area, press E -> place from inventory to stage (placedBrainrots) -> earns money
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local MissionManager = {}
MissionManager.PlayerAbyssParts = {}    -- [userId] = { all parts }
MissionManager.PlayerCourseState = {}   -- [userId] = { basePosition, currentAbyssNum, stagesBuiltUpTo }
MissionManager.CarriedBrainrots = {}    -- [userId] = { model = Model, name = string, rarity = string }
MissionManager.SpawnedBrainrots = {}    -- [userId] = { Model, Model, ... } (brainrots on platforms)

-- Number of abyss stages to render ahead
local STAGES_AHEAD = 100

-- Folder for real brainrot models
local brainrotModelsFolder = ReplicatedStorage:FindFirstChild("BrainrotModels")

------------------------------------------------------------
-- Helper: Try to clone a real model from BrainrotModels folder
------------------------------------------------------------
local function tryGetRealModel(name, pos, rarityColor, scale, userId)
	if not brainrotModelsFolder then return nil end
	local template = brainrotModelsFolder:FindFirstChild(name)
	if not template then return nil end

	local model = template:Clone()
	model.Name = "AbyssBrainrot_" .. userId

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

	if scale and scale ~= 1 then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * scale
			end
		end
	end

	local offset = pos + Vector3.new(0, 2.5, 0) - primaryPart.Position
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Position = part.Position + offset
			part.Anchored = true
			part.CanCollide = false
		end
	end

	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 12
	glow.Brightness = 0.8
	glow.Parent = primaryPart

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
------------------------------------------------------------
local function tryGetRealCarryModel(name, head, rarityColor, userId)
	if not brainrotModelsFolder then return nil end
	local template = brainrotModelsFolder:FindFirstChild(name)
	if not template then return nil end

	local model = template:Clone()
	model.Name = "CarriedBrainrot_" .. userId

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

	local miniScale = 0.4
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * miniScale
			part.Anchored = false
			part.CanCollide = false
		end
	end

	local targetPos = head.Position + Vector3.new(0, 3, 0)
	local offset = targetPos - primaryPart.Position
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CFrame = part.CFrame + offset
		end
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= primaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primaryPart
			weld.Part1 = part
			weld.Parent = primaryPart
		end
	end

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = head
	headWeld.Part1 = primaryPart
	headWeld.Parent = head

	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 8
	glow.Brightness = 0.6
	glow.Parent = primaryPart

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

local function sendCarryUpdate(player: Player, brainrotName, rarity)
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local carryEvent = remotes:FindFirstChild("CarryUpdate")
		if carryEvent then
			carryEvent:FireClient(player, brainrotName, rarity)
		end
	end
end

------------------------------------------------------------
-- Helper: Generate a unique body color from a brainrot name
------------------------------------------------------------
local function nameToColor(brainrotName)
	local hash = 0
	for i = 1, #brainrotName do
		hash = (hash * 31 + string.byte(brainrotName, i)) % 16777216
	end
	local r = math.floor(hash / 65536) % 256
	local g = math.floor(hash / 256) % 256
	local b = hash % 256
	-- Ensure brightness (avoid too dark)
	r = math.max(80, r)
	g = math.max(80, g)
	b = math.max(80, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------
-- Helper: Create brainrot character model with ProximityPrompt
------------------------------------------------------------
local function createBrainrotWithPrompt(name, pos, rarityColor, userId, brainrotInfo)
	local container

	-- Try real model
	local realModel = tryGetRealModel(name, pos, rarityColor, 1, userId)
	if realModel then
		container = realModel
	else
		-- Build a distinctive character model per brainrot
		container = Instance.new("Model")
		container.Name = "AbyssBrainrot_" .. userId

		local bodyColor = nameToColor(name)

		-- Glowing pedestal base
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Size = Vector3.new(5, 0.5, 5)
		pedestal.Position = pos + Vector3.new(0, 0.25, 0)
		pedestal.Anchored = true
		pedestal.CanCollide = false
		pedestal.Color = rarityColor
		pedestal.Material = Enum.Material.Neon
		pedestal.Transparency = 0.3
		pedestal.Parent = container

		-- Body (torso)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 3.5, 2)
		body.Position = pos + Vector3.new(0, 2.75, 0)
		body.Anchored = true
		body.CanCollide = false
		body.Color = bodyColor
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = container

		-- Head
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2.8, 2.8, 2.8)
		head.Shape = Enum.PartType.Ball
		head.Position = pos + Vector3.new(0, 5.9, 0)
		head.Anchored = true
		head.CanCollide = false
		head.Color = bodyColor
		head.Material = Enum.Material.SmoothPlastic
		head.Parent = container

		-- Eyes (white with black pupils)
		for _, eyeX in ipairs({-0.5, 0.5}) do
			local eyeWhite = Instance.new("Part")
			eyeWhite.Size = Vector3.new(0.7, 0.8, 0.3)
			eyeWhite.Position = pos + Vector3.new(eyeX, 6.1, 1.25)
			eyeWhite.Anchored = true
			eyeWhite.CanCollide = false
			eyeWhite.Color = Color3.new(1, 1, 1)
			eyeWhite.Material = Enum.Material.SmoothPlastic
			eyeWhite.Parent = container

			local pupil = Instance.new("Part")
			pupil.Size = Vector3.new(0.35, 0.4, 0.15)
			pupil.Position = pos + Vector3.new(eyeX, 6.1, 1.4)
			pupil.Anchored = true
			pupil.CanCollide = false
			pupil.Color = Color3.new(0, 0, 0)
			pupil.Material = Enum.Material.SmoothPlastic
			pupil.Parent = container
		end

		-- Smile
		local mouth = Instance.new("Part")
		mouth.Size = Vector3.new(0.8, 0.2, 0.15)
		mouth.Position = pos + Vector3.new(0, 5.4, 1.3)
		mouth.Anchored = true
		mouth.CanCollide = false
		mouth.Color = Color3.fromRGB(50, 50, 50)
		mouth.Material = Enum.Material.SmoothPlastic
		mouth.Parent = container

		-- Arms
		for _, armX in ipairs({-2, 2}) do
			local arm = Instance.new("Part")
			arm.Size = Vector3.new(1, 2.5, 1)
			arm.Position = pos + Vector3.new(armX, 2.75, 0)
			arm.Anchored = true
			arm.CanCollide = false
			arm.Color = bodyColor
			arm.Material = Enum.Material.SmoothPlastic
			arm.Parent = container
		end

		-- Legs
		for _, legX in ipairs({-0.7, 0.7}) do
			local leg = Instance.new("Part")
			leg.Size = Vector3.new(1.2, 2, 1.2)
			leg.Position = pos + Vector3.new(legX, 1, 0)
			leg.Anchored = true
			leg.CanCollide = false
			leg.Color = bodyColor
			leg.Material = Enum.Material.SmoothPlastic
			leg.Parent = container
		end

		-- Rarity-colored glow
		local glow = Instance.new("PointLight")
		glow.Color = rarityColor
		glow.Range = 20
		glow.Brightness = 1.2
		glow.Parent = body

		-- Sparkle particles for Epic+ rarities
		local rarityIndex = 1
		for i, r in ipairs(GameConfig.RARITY_ORDER) do
			if r == brainrotInfo.rarity then rarityIndex = i break end
		end
		if rarityIndex >= 3 then -- Epic and above
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Color = ColorSequence.new(rarityColor)
			sparkle.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(1, 0),
			})
			sparkle.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
			sparkle.Lifetime = NumberRange.new(0.5, 1.5)
			sparkle.Rate = 8 + rarityIndex * 2
			sparkle.Speed = NumberRange.new(1, 3)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.LightEmission = 1
			sparkle.Parent = head
		end

		-- Large name plate with rarity background
		local nameGui = Instance.new("BillboardGui")
		nameGui.Size = UDim2.new(0, 280, 0, 90)
		nameGui.StudsOffset = Vector3.new(0, 5, 0)
		nameGui.Adornee = head
		nameGui.AlwaysOnTop = true
		nameGui.Parent = head

		-- Rarity banner background
		local rarityBg = Instance.new("Frame")
		rarityBg.Size = UDim2.new(1, 0, 0.4, 0)
		rarityBg.Position = UDim2.new(0, 0, 0, 0)
		rarityBg.BackgroundColor3 = rarityColor
		rarityBg.BackgroundTransparency = 0.3
		rarityBg.BorderSizePixel = 0
		rarityBg.Parent = nameGui

		local rarityLabel = Instance.new("TextLabel")
		rarityLabel.Size = UDim2.new(1, 0, 1, 0)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = "[" .. brainrotInfo.rarity .. "]"
		rarityLabel.TextColor3 = Color3.new(1, 1, 1)
		rarityLabel.TextScaled = true
		rarityLabel.Font = Enum.Font.GothamBold
		rarityLabel.Parent = rarityBg

		-- Brainrot name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.4, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = name
		nameLabel.TextColor3 = rarityColor
		nameLabel.TextScaled = true
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		nameLabel.Parent = nameGui

		-- "Press E" hint below name
		local hintGui = Instance.new("BillboardGui")
		hintGui.Size = UDim2.new(0, 180, 0, 35)
		hintGui.StudsOffset = Vector3.new(0, -0.5, 0)
		hintGui.Adornee = pedestal
		hintGui.AlwaysOnTop = true
		hintGui.Parent = pedestal

		local hintLabel = Instance.new("TextLabel")
		hintLabel.Size = UDim2.new(1, 0, 1, 0)
		hintLabel.BackgroundTransparency = 1
		hintLabel.Text = "[E] Collect"
		hintLabel.TextColor3 = Color3.fromRGB(255, 255, 100)
		hintLabel.TextScaled = true
		hintLabel.Font = Enum.Font.GothamBold
		hintLabel.TextStrokeTransparency = 0.5
		hintLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
		hintLabel.Parent = hintGui

		container.PrimaryPart = body
	end

	-- Add ProximityPrompt for E key pickup
	local promptPart = container.PrimaryPart or container:FindFirstChildWhichIsA("BasePart")
	if promptPart then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Collect"
		prompt.ObjectText = name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptPart

		-- Store brainrot info on the model for pickup
		local infoValue = Instance.new("StringValue")
		infoValue.Name = "BrainrotName"
		infoValue.Value = name
		infoValue.Parent = container

		local rarityValue = Instance.new("StringValue")
		rarityValue.Name = "BrainrotRarity"
		rarityValue.Value = brainrotInfo.rarity
		rarityValue.Parent = container

		-- Handle pickup
		prompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer.UserId ~= userId then return end
			-- Can only carry one at a time
			if MissionManager.CarriedBrainrots[userId] then return end

			-- Pick up brainrot
			local bName = container:FindFirstChild("BrainrotName")
			local bRarity = container:FindFirstChild("BrainrotRarity")
			if not bName or not bRarity then return end

			local pickupName = bName.Value
			local pickupRarity = bRarity.Value
			local pickupColor = GameConfig.RARITY_COLORS[pickupRarity] or Color3.new(1, 1, 1)

			-- Remove from platform
			container:Destroy()

			-- Remove from spawned list
			local spawned = MissionManager.SpawnedBrainrots[userId]
			if spawned then
				for i, m in ipairs(spawned) do
					if m == container then
						table.remove(spawned, i)
						break
					end
				end
			end

			-- Set carry data first, then add visual (CarryBrainrotOnHead adds .model to same table)
			MissionManager.CarriedBrainrots[userId] = {
				name = pickupName,
				rarity = pickupRarity,
			}
			MissionManager.CarryBrainrotOnHead(triggerPlayer, pickupName, pickupColor)

			-- Notify client
			sendCarryUpdate(triggerPlayer, pickupName, pickupRarity)
		end)
	end

	return container
end

------------------------------------------------------------
-- Create a single abyss stage (platform + gap + landing + lava)
-- NO brainrots pre-spawned (they spawn on completion)
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

	-- Neon edge strips on platforms for visual effect
	local edgeStrip = Instance.new("Part")
	edgeStrip.Name = "Edge_" .. abyssNum
	edgeStrip.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, 0.3, 1)
	edgeStrip.Position = startPlatform.Position + Vector3.new(0, 0.5, GameConfig.PLATFORM_WIDTH / 2)
	edgeStrip.Anchored = true
	edgeStrip.CanCollide = false
	edgeStrip.Color = tierColor
	edgeStrip.Material = Enum.Material.Neon
	edgeStrip.Parent = workspace
	table.insert(parts, edgeStrip)

	-- Stage sign
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
	stageLabel.Text = "Abyss #" .. abyssNum .. "\n[" .. tierName .. "]\nJump: " .. abyssWidth
	stageLabel.TextColor3 = tierColor
	stageLabel.TextScaled = true
	stageLabel.Font = Enum.Font.GothamBold
	stageLabel.Parent = stageSign

	-- Landing platform
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

	-- Landing neon edge
	local landingEdge = Instance.new("Part")
	landingEdge.Name = "LandingEdge_" .. abyssNum
	landingEdge.Size = Vector3.new(GameConfig.PLATFORM_LENGTH, 0.3, 1)
	landingEdge.Position = landingPlatform.Position + Vector3.new(0, 0.5, -GameConfig.PLATFORM_WIDTH / 2)
	landingEdge.Anchored = true
	landingEdge.CanCollide = false
	landingEdge.Color = Color3.fromRGB(0, 255, 100)
	landingEdge.Material = Enum.Material.Neon
	landingEdge.Parent = workspace
	table.insert(parts, landingEdge)

	-- ============================
	-- LAVA at bottom of abyss
	-- ============================
	local gapCenterZ = startZ + GameConfig.PLATFORM_WIDTH + abyssWidth / 2
	local lavaGlow = Instance.new("Part")
	lavaGlow.Name = "Lava_" .. userId .. "_" .. abyssNum
	lavaGlow.Size = Vector3.new(GameConfig.PLATFORM_LENGTH + 10, 3, abyssWidth + 10)
	lavaGlow.Position = Vector3.new(basePosition.X, GameConfig.KILL_ZONE_Y + 8, gapCenterZ)
	lavaGlow.Anchored = true
	lavaGlow.CanCollide = false
	lavaGlow.Color = Color3.fromRGB(255, 80, 0)
	lavaGlow.Material = Enum.Material.Neon
	lavaGlow.Transparency = 0.2
	lavaGlow.Parent = workspace
	table.insert(parts, lavaGlow)

	-- Lava surface layer
	local lavaSurface = Instance.new("Part")
	lavaSurface.Name = "LavaSurface_" .. abyssNum
	lavaSurface.Size = Vector3.new(GameConfig.PLATFORM_LENGTH + 10, 1, abyssWidth + 10)
	lavaSurface.Position = Vector3.new(basePosition.X, GameConfig.KILL_ZONE_Y + 10, gapCenterZ)
	lavaSurface.Anchored = true
	lavaSurface.CanCollide = false
	lavaSurface.Color = Color3.fromRGB(255, 140, 0)
	lavaSurface.Material = Enum.Material.Neon
	lavaSurface.Transparency = 0.4
	lavaSurface.Parent = workspace
	table.insert(parts, lavaSurface)

	-- Fire particles on lava
	local fireEmitter = Instance.new("ParticleEmitter")
	fireEmitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 100, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 0)),
	})
	fireEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(0.5, 4),
		NumberSequenceKeypoint.new(1, 0),
	})
	fireEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	fireEmitter.Lifetime = NumberRange.new(0.5, 2)
	fireEmitter.Rate = 15
	fireEmitter.Speed = NumberRange.new(3, 8)
	fireEmitter.SpreadAngle = Vector2.new(20, 20)
	fireEmitter.LightEmission = 1
	fireEmitter.Parent = lavaSurface

	-- Lava glow light
	local lavaLight = Instance.new("PointLight")
	lavaLight.Color = Color3.fromRGB(255, 100, 0)
	lavaLight.Range = 50
	lavaLight.Brightness = 1.5
	lavaLight.Parent = lavaGlow

	-- Kill zone (invisible, above lava)
	local killZone = Instance.new("Part")
	killZone.Name = "KillZone_" .. userId .. "_" .. abyssNum
	killZone.Size = Vector3.new(GameConfig.PLATFORM_LENGTH + 40, 1, abyssWidth + 20)
	killZone.Position = Vector3.new(
		basePosition.X,
		GameConfig.KILL_ZONE_Y + 15,
		gapCenterZ
	)
	killZone.Anchored = true
	killZone.Transparency = 1
	killZone.CanCollide = false
	killZone.Parent = workspace
	table.insert(parts, killZone)

	killZone.Touched:Connect(function(hit)
		local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)
		if hitPlayer and hitPlayer.UserId == userId then
			local character = hitPlayer.Character
			if character then
				local hrp = character:FindFirstChild("HumanoidRootPart")
				if hrp then
					-- Drop carried brainrot when falling
					if MissionManager.CarriedBrainrots[userId] then
						MissionManager.LoseCarriedBrainrot(hitPlayer)
					end
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

	-- Side walls (tall visible concrete walls forming a corridor)
	local corridorWallHeight = 50
	local corridorWallThickness = 4
	local stageLength = abyssWidth + GameConfig.PLATFORM_WIDTH * 2
	local stageCenterZ = startZ + stageLength / 2

	for wallIdx, xOffset in ipairs({-GameConfig.PLATFORM_LENGTH / 2 - corridorWallThickness / 2, GameConfig.PLATFORM_LENGTH / 2 + corridorWallThickness / 2}) do
		-- Main wall
		local wall = Instance.new("Part")
		wall.Name = "SideWall_" .. userId .. "_" .. abyssNum
		wall.Size = Vector3.new(corridorWallThickness, corridorWallHeight, stageLength)
		wall.Position = Vector3.new(
			basePosition.X + xOffset,
			basePosition.Y + corridorWallHeight / 2 - 5,
			stageCenterZ
		)
		wall.Anchored = true
		wall.Color = Color3.fromRGB(90, 85, 80)
		wall.Material = Enum.Material.Concrete
		wall.Parent = workspace
		table.insert(parts, wall)

		-- Horizontal accent lines on wall (at intervals)
		for _, accentY in ipairs({8, 20, 32}) do
			local accent = Instance.new("Part")
			accent.Name = "WallAccent_" .. userId .. "_" .. abyssNum
			accent.Size = Vector3.new(0.5, 0.6, stageLength)
			accent.Position = Vector3.new(
				basePosition.X + xOffset + (wallIdx == 1 and (corridorWallThickness / 2 + 0.1) or -(corridorWallThickness / 2 + 0.1)),
				basePosition.Y + accentY,
				stageCenterZ
			)
			accent.Anchored = true
			accent.CanCollide = false
			accent.Color = Color3.fromRGB(70, 65, 60)
			accent.Material = Enum.Material.Concrete
			accent.Parent = workspace
			table.insert(parts, accent)
		end

		-- Neon strip at top of wall
		local topStrip = Instance.new("Part")
		topStrip.Name = "WallTopStrip_" .. userId .. "_" .. abyssNum
		topStrip.Size = Vector3.new(corridorWallThickness + 1, 0.5, stageLength)
		topStrip.Position = Vector3.new(
			basePosition.X + xOffset,
			basePosition.Y + corridorWallHeight - 5 + 0.25,
			stageCenterZ
		)
		topStrip.Anchored = true
		topStrip.CanCollide = false
		topStrip.Color = tierColor
		topStrip.Material = Enum.Material.Neon
		topStrip.Parent = workspace
		table.insert(parts, topStrip)
	end

	local endZ = landingZ + GameConfig.PLATFORM_WIDTH
	return endZ
end

------------------------------------------------------------
-- Create the full continuous abyss course (100 stages)
------------------------------------------------------------
function MissionManager.CreateAbyssCourse(player: Player, basePosition: Vector3)
	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return end

	-- Clean up old course
	MissionManager.CleanupCourse(player)

	local userId = player.UserId
	MissionManager.PlayerAbyssParts[userId] = {}
	MissionManager.SpawnedBrainrots[userId] = {}
	local parts = MissionManager.PlayerAbyssParts[userId]

	local abyssNum = data.currentAbyss
	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2

	-- Build 100 stages ahead
	local currentZ = safeZoneEdgeZ
	for i = 0, STAGES_AHEAD - 1 do
		local stageAbyssNum = abyssNum + i
		currentZ = createAbyssStage(player, userId, basePosition, stageAbyssNum, currentZ, parts)
	end

	MissionManager.PlayerCourseState[userId] = {
		basePosition = basePosition,
		currentAbyssNum = abyssNum,
		stagesBuiltUpTo = abyssNum + STAGES_AHEAD - 1,
	}
end

------------------------------------------------------------
-- Extend the course when player progresses
------------------------------------------------------------
local function extendCourse(player, basePosition)
	local userId = player.UserId
	local state = MissionManager.PlayerCourseState[userId]
	if not state then return end

	local parts = MissionManager.PlayerAbyssParts[userId]
	if not parts then return end

	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2
	local currentZ = safeZoneEdgeZ

	for stageNum = state.currentAbyssNum, state.stagesBuiltUpTo do
		local abyssWidth = GameConfig.GetAbyssWidth(stageNum)
		currentZ = currentZ + GameConfig.PLATFORM_WIDTH + abyssWidth + GameConfig.PLATFORM_WIDTH
	end

	-- Add 3 more stages ahead
	for _ = 1, 3 do
		local newStageNum = state.stagesBuiltUpTo + 1
		currentZ = createAbyssStage(player, userId, basePosition, newStageNum, currentZ, parts)
		state.stagesBuiltUpTo = newStageNum
	end
end

------------------------------------------------------------
-- Spawn brainrot collectibles on landing platform after crossing
------------------------------------------------------------
local function spawnBrainrotsOnPlatform(player, abyssNum, basePosition)
	local userId = player.UserId
	local tierName = GameConfig.GetTierForAbyss(abyssNum)
	local brainrotCount = GameConfig.GetBrainrotRewardCount(abyssNum)
	local spawned = MissionManager.SpawnedBrainrots[userId]
	if not spawned then
		spawned = {}
		MissionManager.SpawnedBrainrots[userId] = spawned
	end

	-- Calculate landing platform position
	local safeZoneEdgeZ = basePosition.Z + GameConfig.BASE_SIZE.Z / 2
	local currentZ = safeZoneEdgeZ
	local state = MissionManager.PlayerCourseState[userId]
	if state then
		for stageNum = state.currentAbyssNum, abyssNum - 1 do
			local w = GameConfig.GetAbyssWidth(stageNum)
			currentZ = currentZ + GameConfig.PLATFORM_WIDTH + w + GameConfig.PLATFORM_WIDTH
		end
	end
	local abyssWidth = GameConfig.GetAbyssWidth(abyssNum)
	local landingZ = currentZ + GameConfig.PLATFORM_WIDTH + abyssWidth
	local landingCenter = landingZ + GameConfig.PLATFORM_WIDTH / 2

	-- Spawn brainrots on the landing platform
	local awardedNames = {}
	for i = 1, math.min(brainrotCount, 3) do
		local brainrot = BrainrotData.GetRandomFromTier(tierName)
		if brainrot then
			local xOffset = (i - 2) * 6
			local brainrotPos = Vector3.new(
				basePosition.X + xOffset,
				basePosition.Y + 1,
				landingCenter
			)
			local brainrotColor = GameConfig.RARITY_COLORS[brainrot.rarity] or Color3.new(1, 1, 1)
			local brainrotModel = createBrainrotWithPrompt(brainrot.name, brainrotPos, brainrotColor, userId, brainrot)
			brainrotModel.Parent = workspace
			table.insert(spawned, brainrotModel)
			table.insert(awardedNames, brainrot.name)
		end
	end

	return awardedNames
end

------------------------------------------------------------
-- Carry brainrot on player's head (visual only)
------------------------------------------------------------
function MissionManager.CarryBrainrotOnHead(player: Player, brainrotName: string, rarityColor: Color3)
	local userId = player.UserId
	local character = player.Character
	if not character then return end

	-- Remove old visual
	MissionManager.RemoveCarryVisual(player)

	local head = character:FindFirstChild("Head")
	if not head then return end

	-- Try real model
	local realCarry = tryGetRealCarryModel(brainrotName, head, rarityColor, userId)
	if realCarry then
		MissionManager.CarriedBrainrots[userId] = MissionManager.CarriedBrainrots[userId] or {}
		MissionManager.CarriedBrainrots[userId].model = realCarry
		return
	end

	-- Fallback: mini dummy
	local carryModel = Instance.new("Model")
	carryModel.Name = "CarriedBrainrot_" .. userId

	local miniBody = Instance.new("Part")
	miniBody.Name = "MiniBody"
	miniBody.Size = Vector3.new(1.2, 1.5, 0.8)
	miniBody.Anchored = false
	miniBody.CanCollide = false
	miniBody.Color = rarityColor
	miniBody.Material = Enum.Material.SmoothPlastic
	miniBody.Parent = carryModel

	local miniHead = Instance.new("Part")
	miniHead.Name = "MiniHead"
	miniHead.Size = Vector3.new(1.2, 1.2, 1.2)
	miniHead.Shape = Enum.PartType.Ball
	miniHead.Anchored = false
	miniHead.CanCollide = false
	miniHead.Color = rarityColor
	miniHead.Material = Enum.Material.SmoothPlastic
	miniHead.Parent = carryModel

	local mLeftEye = Instance.new("Part")
	mLeftEye.Size = Vector3.new(0.2, 0.25, 0.15)
	mLeftEye.Anchored = false
	mLeftEye.CanCollide = false
	mLeftEye.Color = Color3.new(1, 1, 1)
	mLeftEye.Material = Enum.Material.SmoothPlastic
	mLeftEye.Parent = carryModel

	local mRightEye = Instance.new("Part")
	mRightEye.Size = Vector3.new(0.2, 0.25, 0.15)
	mRightEye.Anchored = false
	mRightEye.CanCollide = false
	mRightEye.Color = Color3.new(1, 1, 1)
	mRightEye.Material = Enum.Material.SmoothPlastic
	mRightEye.Parent = carryModel

	local glow = Instance.new("PointLight")
	glow.Color = rarityColor
	glow.Range = 8
	glow.Brightness = 0.6
	glow.Parent = miniBody

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

	local function weldTo(part, offset)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = miniBody
		weld.Part1 = part
		weld.Parent = miniBody
		part.CFrame = miniBody.CFrame * offset
	end

	miniBody.CFrame = head.CFrame * CFrame.new(0, 2.5, 0)
	weldTo(miniHead, CFrame.new(0, 1.35, 0))
	weldTo(mLeftEye, CFrame.new(-0.25, 1.5, 0.55))
	weldTo(mRightEye, CFrame.new(0.25, 1.5, 0.55))

	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = head
	headWeld.Part1 = miniBody
	headWeld.Parent = head

	carryModel.Parent = workspace

	if not MissionManager.CarriedBrainrots[userId] then
		MissionManager.CarriedBrainrots[userId] = {}
	end
	MissionManager.CarriedBrainrots[userId].model = carryModel
end

------------------------------------------------------------
-- Remove carry visual only
------------------------------------------------------------
function MissionManager.RemoveCarryVisual(player: Player)
	local userId = player.UserId
	local data = MissionManager.CarriedBrainrots[userId]
	if data and data.model and data.model.Parent then
		data.model:Destroy()
	end
	if data then
		data.model = nil
	end
end

------------------------------------------------------------
-- Remove carried brainrot completely (visual + data)
------------------------------------------------------------
function MissionManager.RemoveCarriedBrainrot(player: Player)
	local userId = player.UserId
	MissionManager.RemoveCarryVisual(player)
	MissionManager.CarriedBrainrots[userId] = nil
	sendCarryUpdate(player, nil, nil)
end

------------------------------------------------------------
-- Drop carried brainrot (player chose to drop)
------------------------------------------------------------
function MissionManager.DropCarriedBrainrot(player: Player)
	local userId = player.UserId
	local carryData = MissionManager.CarriedBrainrots[userId]
	if not carryData or not carryData.name then return end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")

	-- Respawn the brainrot at player's feet
	if hrp then
		local dropPos = hrp.Position + Vector3.new(0, -2, 3)
		local brainrotInfo = BrainrotData.GetByName(carryData.name)
		if brainrotInfo then
			local rarityColor = GameConfig.RARITY_COLORS[carryData.rarity] or Color3.new(1, 1, 1)
			local model = createBrainrotWithPrompt(carryData.name, dropPos, rarityColor, userId, brainrotInfo)
			model.Parent = workspace

			local spawned = MissionManager.SpawnedBrainrots[userId]
			if spawned then
				table.insert(spawned, model)
			end
		end
	end

	MissionManager.RemoveCarriedBrainrot(player)
end

------------------------------------------------------------
-- Lose carried brainrot (fell into abyss - brainrot is destroyed)
------------------------------------------------------------
function MissionManager.LoseCarriedBrainrot(player: Player)
	MissionManager.RemoveCarriedBrainrot(player)

	-- Notify client
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local notifyEvent = remotes:FindFirstChild("BrainrotNotification")
		if notifyEvent then
			notifyEvent:FireClient(player, {"Lost brainrot! Be careful!"}, "Common")
		end
	end
end

------------------------------------------------------------
-- Player returned to base through gate (carrying brainrot -> inventory)
------------------------------------------------------------
local returnCooldown = {}
function MissionManager.OnPlayerReturnedToBase(player: Player)
	local userId = player.UserId
	local now = tick()
	if returnCooldown[userId] and (now - returnCooldown[userId]) < 2 then return end
	returnCooldown[userId] = now

	local carryData = MissionManager.CarriedBrainrots[userId]
	if not carryData or not carryData.name then return end

	local DataManager = getDataManager()
	DataManager.AddBrainrot(player, carryData.name)

	-- Remove carried brainrot
	MissionManager.RemoveCarriedBrainrot(player)

	-- Notify client
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local notifyEvent = remotes:FindFirstChild("BrainrotNotification")
		if notifyEvent then
			notifyEvent:FireClient(player, {carryData.name .. " added to inventory!"}, "Legendary")
		end
	end

	sendDataUpdate(player)

	-- Update display
	if _G.GameManager then
		_G.GameManager.UpdateBrainrotDisplay(player)
	end
end

------------------------------------------------------------
-- Called when player successfully crosses an abyss
------------------------------------------------------------
local completionCooldown = {}
function MissionManager.OnAbyssCompleted(player: Player, basePosition: Vector3, completedAbyssNum: number)
	local userId = player.UserId
	local now = tick()

	if completionCooldown[userId] and (now - completionCooldown[userId]) < 2 then
		return
	end
	completionCooldown[userId] = now

	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return end

	if completedAbyssNum ~= data.currentAbyss then
		return
	end

	local abyssNum = data.currentAbyss

	-- Spawn brainrots on the landing platform (player picks them up with E)
	local awardedNames = spawnBrainrotsOnPlatform(player, abyssNum, basePosition)

	-- Advance to next abyss
	data.currentAbyss = data.currentAbyss + 1
	data.totalAbyssesPassed = data.totalAbyssesPassed + 1

	-- Notify client about available brainrots
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local notifyEvent = remotes:FindFirstChild("BrainrotNotification")
		if notifyEvent then
			notifyEvent:FireClient(player, awardedNames, GameConfig.GetTierForAbyss(abyssNum))
		end
	end

	sendDataUpdate(player)

	-- Extend course if needed
	local state = MissionManager.PlayerCourseState[userId]
	if state and data.currentAbyss + 10 >= state.stagesBuiltUpTo then
		extendCourse(player, basePosition)
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

	-- Clean spawned brainrots
	local spawned = MissionManager.SpawnedBrainrots[userId]
	if spawned then
		for _, m in ipairs(spawned) do
			if m and m.Parent then m:Destroy() end
		end
	end
	MissionManager.SpawnedBrainrots[userId] = nil

	-- Remove carried brainrot
	MissionManager.RemoveCarriedBrainrot(player)
end

-- Player leaving cleanup
Players.PlayerRemoving:Connect(function(player)
	MissionManager.CleanupCourse(player)
	completionCooldown[player.UserId] = nil
	returnCooldown[player.UserId] = nil
end)

-- Drop carried brainrot when character respawns
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		MissionManager.RemoveCarriedBrainrot(player)
	end)
end)

_G.MissionManager = MissionManager

return MissionManager
