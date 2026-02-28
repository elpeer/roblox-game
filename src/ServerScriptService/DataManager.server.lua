--[[
	DataManager - Handles saving and loading player data using DataStoreService
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerDataStore = DataStoreService:GetDataStore("BrainrotSimulator_v1")

local DataManager = {}
DataManager.PlayerData = {} -- [userId] = data table
DataManager.DataLoaded = {} -- [userId] = true when loaded

local DEFAULT_DATA = {
	coins = 0,
	speed = 0,
	currentTreadmill = "Basic Treadmill",
	currentAbyss = 1,
	totalAbyssesPassed = 0,
	collectedBrainrots = {}, -- { ["name"] = count }
}

function DataManager.GetDefaultData()
	local data = {}
	for key, value in pairs(DEFAULT_DATA) do
		if type(value) == "table" then
			data[key] = {}
			for k, v in pairs(value) do
				data[key][k] = v
			end
		else
			data[key] = value
		end
	end
	return data
end

function DataManager.LoadData(player: Player)
	local userId = player.UserId
	local key = "Player_" .. tostring(userId)

	local success, data = pcall(function()
		return PlayerDataStore:GetAsync(key)
	end)

	if success and data then
		-- Merge with defaults to handle new fields
		local defaultData = DataManager.GetDefaultData()
		for k, v in pairs(defaultData) do
			if data[k] == nil then
				data[k] = v
			end
		end
		DataManager.PlayerData[userId] = data
	else
		DataManager.PlayerData[userId] = DataManager.GetDefaultData()
	end

	DataManager.DataLoaded[userId] = true
	return DataManager.PlayerData[userId]
end

function DataManager.SaveData(player: Player)
	local userId = player.UserId
	local key = "Player_" .. tostring(userId)
	local data = DataManager.PlayerData[userId]

	if not data then return end

	local success, err = pcall(function()
		PlayerDataStore:SetAsync(key, data)
	end)

	if not success then
		warn("[DataManager] Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataManager.GetData(player: Player)
	local userId = player.UserId
	return DataManager.PlayerData[userId]
end

function DataManager.SetData(player: Player, key: string, value: any)
	local userId = player.UserId
	if DataManager.PlayerData[userId] then
		DataManager.PlayerData[userId][key] = value
	end
end

function DataManager.AddCoins(player: Player, amount: number)
	local data = DataManager.GetData(player)
	if data then
		data.coins = data.coins + amount
	end
end

function DataManager.RemoveCoins(player: Player, amount: number): boolean
	local data = DataManager.GetData(player)
	if data and data.coins >= amount then
		data.coins = data.coins - amount
		return true
	end
	return false
end

function DataManager.AddBrainrot(player: Player, brainrotName: string)
	local data = DataManager.GetData(player)
	if data then
		if not data.collectedBrainrots[brainrotName] then
			data.collectedBrainrots[brainrotName] = 0
		end
		data.collectedBrainrots[brainrotName] = data.collectedBrainrots[brainrotName] + 1
	end
end

function DataManager.AddSpeed(player: Player, amount: number)
	local data = DataManager.GetData(player)
	if data then
		data.speed = data.speed + amount
	end
end

function DataManager.IsDataLoaded(player: Player): boolean
	return DataManager.DataLoaded[player.UserId] == true
end

-- Auto-save loop
task.spawn(function()
	while true do
		task.wait(60) -- save every 60 seconds
		for _, player in ipairs(Players:GetPlayers()) do
			if DataManager.IsDataLoaded(player) then
				DataManager.SaveData(player)
			end
		end
	end
end)

-- Save on player leave
Players.PlayerRemoving:Connect(function(player)
	if DataManager.IsDataLoaded(player) then
		DataManager.SaveData(player)
	end
	DataManager.PlayerData[player.UserId] = nil
	DataManager.DataLoaded[player.UserId] = nil
end)

-- Save all on shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if DataManager.IsDataLoaded(player) then
			DataManager.SaveData(player)
		end
	end
end)

-- Make it accessible as a module via _G for other server scripts
_G.DataManager = DataManager

return DataManager
