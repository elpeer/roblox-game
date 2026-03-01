--[[
	ClientController - Client-side logic
	Handles input, data sync, and coordinates with GUI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))
local TreadmillData = require(Modules:WaitForChild("TreadmillData"))

local player = Players.LocalPlayer

-- Wait for remotes
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
local TreadmillClickEvent = Remotes:WaitForChild("TreadmillClick")
local PurchaseTreadmillEvent = Remotes:WaitForChild("PurchaseTreadmill")
local PlayerDataUpdateEvent = Remotes:WaitForChild("PlayerDataUpdate")
local BrainrotNotificationEvent = Remotes:WaitForChild("BrainrotNotification")
local PurchaseResultEvent = Remotes:WaitForChild("PurchaseResult")
local RequestDataEvent = Remotes:WaitForChild("RequestData")

-- Local player data cache
local playerData = nil

-- Shared module for GUI to access
local ClientState = {}
ClientState.PlayerData = nil
ClientState.CarryingBrainrot = nil -- { name = string, rarity = string } or nil
ClientState.OnDataUpdated = Instance.new("BindableEvent")
ClientState.OnBrainrotEarned = Instance.new("BindableEvent")
ClientState.OnPurchaseResult = Instance.new("BindableEvent")
ClientState.OnCarryUpdated = Instance.new("BindableEvent")

-- Make accessible to GUI scripts
_G.ClientState = ClientState

-- Handle data updates from server
PlayerDataUpdateEvent.OnClientEvent:Connect(function(data)
	playerData = data
	ClientState.PlayerData = data
	ClientState.OnDataUpdated:Fire(data)
end)

-- Handle brainrot notification
BrainrotNotificationEvent.OnClientEvent:Connect(function(awardedNames, tier)
	ClientState.OnBrainrotEarned:Fire(awardedNames, tier)
end)

-- Handle purchase result
PurchaseResultEvent.OnClientEvent:Connect(function(success, treadmillName)
	ClientState.OnPurchaseResult:Fire(success, treadmillName)
end)

-- Handle carry update
local CarryUpdateEvent = Remotes:WaitForChild("CarryUpdate")
CarryUpdateEvent.OnClientEvent:Connect(function(brainrotName, rarity)
	if brainrotName then
		ClientState.CarryingBrainrot = { name = brainrotName, rarity = rarity }
	else
		ClientState.CarryingBrainrot = nil
	end
	ClientState.OnCarryUpdated:Fire(ClientState.CarryingBrainrot)
end)

-- Functions exposed for GUI
function ClientState.ClickTreadmill()
	TreadmillClickEvent:FireServer()
end

function ClientState.PurchaseTreadmill(name: string)
	PurchaseTreadmillEvent:FireServer(name)
end

function ClientState.GetIncomePerSecond(): number
	if not playerData then return 0 end
	local total = 0
	-- Only placed brainrots earn money
	for brainrotName, count in pairs(playerData.placedBrainrots or {}) do
		local info = BrainrotData.GetByName(brainrotName)
		if info then
			total = total + (info.income * count)
		end
	end
	return total
end

function ClientState.DropBrainrot()
	local DropEvent = Remotes:FindFirstChild("DropBrainrot")
	if DropEvent then
		DropEvent:FireServer()
	end
end

function ClientState.PlaceBrainrots()
	local PlaceEvent = Remotes:FindFirstChild("PlaceBrainrots")
	if PlaceEvent then
		PlaceEvent:FireServer()
	end
end

function ClientState.FormatNumber(n: number): string
	if n >= 1000000000 then
		return string.format("%.1fB", n / 1000000000)
	elseif n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fK", n / 1000)
	else
		return tostring(math.floor(n))
	end
end

-- Request initial data
task.wait(2)
RequestDataEvent:FireServer()
