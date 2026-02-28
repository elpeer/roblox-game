--[[
	EconomyManager - Handles treadmill clicks and shop purchases
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local TreadmillData = require(Modules:WaitForChild("TreadmillData"))

local EconomyManager = {}

local lastClickTime = {} -- [userId] = tick

-- Wait for DataManager
local function getDataManager()
	while not _G.DataManager do task.wait(0.1) end
	return _G.DataManager
end

local function sendDataUpdate(player: Player)
	local DataManager = getDataManager()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if remotes then
		local updateEvent = remotes:FindFirstChild("PlayerDataUpdate")
		if updateEvent then
			local data = DataManager.GetData(player)
			updateEvent:FireClient(player, data)
		end
	end
end

-- Handle treadmill click
function EconomyManager.HandleTreadmillClick(player: Player)
	local DataManager = getDataManager()
	local userId = player.UserId

	-- Cooldown check
	local now = tick()
	if lastClickTime[userId] and (now - lastClickTime[userId]) < GameConfig.TREADMILL_CLICK_COOLDOWN then
		return
	end
	lastClickTime[userId] = now

	local data = DataManager.GetData(player)
	if not data then return end

	local treadmill = TreadmillData.GetByName(data.currentTreadmill)
	if not treadmill then return end

	DataManager.AddSpeed(player, treadmill.speedPerClick)

	-- Update character walk speed and jump power
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = GameConfig.BASE_WALK_SPEED + (data.speed * GameConfig.SPEED_TO_WALK_RATIO)
			humanoid.JumpPower = GameConfig.BASE_JUMP_POWER + (data.speed * GameConfig.SPEED_TO_JUMP_RATIO)
		end
	end

	sendDataUpdate(player)
end

-- Handle treadmill purchase
function EconomyManager.HandlePurchase(player: Player, treadmillName: string): boolean
	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return false end

	local treadmill = TreadmillData.GetByName(treadmillName)
	if not treadmill then return false end

	-- Check if already owned
	if data.currentTreadmill == treadmillName then return false end

	-- Check if can afford
	if not DataManager.RemoveCoins(player, treadmill.price) then
		return false
	end

	data.currentTreadmill = treadmillName
	sendDataUpdate(player)
	return true
end

-- Apply speed stats to character
function EconomyManager.ApplySpeedToCharacter(player: Player)
	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.WalkSpeed = GameConfig.BASE_WALK_SPEED + (data.speed * GameConfig.SPEED_TO_WALK_RATIO)
	humanoid.JumpPower = GameConfig.BASE_JUMP_POWER + (data.speed * GameConfig.SPEED_TO_JUMP_RATIO)
end

-- Setup remote event listeners
task.spawn(function()
	-- Wait for remotes to be created by GameManager
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	if not remotes then
		warn("[EconomyManager] Remotes folder not found")
		return
	end

	local treadmillClickEvent = remotes:WaitForChild("TreadmillClick", 10)
	local purchaseEvent = remotes:WaitForChild("PurchaseTreadmill", 10)

	if treadmillClickEvent then
		treadmillClickEvent.OnServerEvent:Connect(function(player)
			EconomyManager.HandleTreadmillClick(player)
		end)
	end

	if purchaseEvent then
		purchaseEvent.OnServerEvent:Connect(function(player, treadmillName)
			if type(treadmillName) ~= "string" then return end
			local success = EconomyManager.HandlePurchase(player, treadmillName)

			local resultEvent = remotes:FindFirstChild("PurchaseResult")
			if resultEvent then
				resultEvent:FireClient(player, success, treadmillName)
			end
		end)
	end
end)

_G.EconomyManager = EconomyManager

return EconomyManager
