--[[
	BrainrotManager - Handles brainrot rewards and passive income
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local BrainrotManager = {}

-- Wait for DataManager to be available
local function getDataManager()
	while not _G.DataManager do task.wait(0.1) end
	return _G.DataManager
end

-- Award brainrots to player based on their current abyss
function BrainrotManager.AwardBrainrots(player: Player, abyssNumber: number): { string }
	local DataManager = getDataManager()
	local tier = GameConfig.GetTierForAbyss(abyssNumber)
	local count = GameConfig.GetBrainrotRewardCount(abyssNumber)
	local awarded = {}

	for _ = 1, count do
		local brainrot = BrainrotData.GetRandomFromTier(tier)
		if brainrot then
			DataManager.AddBrainrot(player, brainrot.name)
			table.insert(awarded, brainrot.name)
		end
	end

	return awarded
end

-- Calculate total passive income per second for a player
function BrainrotManager.CalculateIncomePerSecond(player: Player): number
	local DataManager = getDataManager()
	local data = DataManager.GetData(player)
	if not data then return 0 end

	local totalIncome = 0
	for brainrotName, count in pairs(data.collectedBrainrots) do
		local brainrotInfo = BrainrotData.GetByName(brainrotName)
		if brainrotInfo then
			totalIncome = totalIncome + (brainrotInfo.income * count)
		end
	end

	return totalIncome
end

-- Passive income loop - runs for each player
function BrainrotManager.StartPassiveIncome()
	task.spawn(function()
		while true do
			task.wait(GameConfig.PASSIVE_INCOME_INTERVAL)
			local DataManager = getDataManager()

			for _, player in ipairs(Players:GetPlayers()) do
				if DataManager.IsDataLoaded(player) then
					local income = BrainrotManager.CalculateIncomePerSecond(player)
					if income > 0 then
						DataManager.AddCoins(player, income)

						-- Notify client of updated data
						local remotes = ReplicatedStorage:FindFirstChild("Remotes")
						if remotes then
							local updateEvent = remotes:FindFirstChild("PlayerDataUpdate")
							if updateEvent then
								local data = DataManager.GetData(player)
								updateEvent:FireClient(player, data)
							end
						end
					end
				end
			end
		end
	end)
end

-- Make accessible
_G.BrainrotManager = BrainrotManager

-- Start passive income system
BrainrotManager.StartPassiveIncome()

return BrainrotManager
