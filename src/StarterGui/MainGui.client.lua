--[[
	MainGui - Creates and manages all GUI elements:
	  - Main HUD (coins, speed, abyss, income)
	  - Inventory (treadmill click button + brainrot list)
	  - Shop (buy treadmills)
	  - Notifications (brainrot earned popups)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local TreadmillData = require(Modules:WaitForChild("TreadmillData"))
local BrainrotData = require(Modules:WaitForChild("BrainrotData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for ClientState
while not _G.ClientState do task.wait(0.1) end
local ClientState = _G.ClientState

------------------------------------------------------------
-- UTILITY FUNCTIONS
------------------------------------------------------------
local function createCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 8)
	corner.Parent = parent
	return corner
end

local function createStroke(parent, color, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(60, 60, 60)
	stroke.Thickness = thickness or 2
	stroke.Parent = parent
	return stroke
end

local function formatNum(n)
	return ClientState.FormatNumber(n)
end

------------------------------------------------------------
-- SCREEN GUI
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotSimulatorGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

------------------------------------------------------------
-- 1. MAIN HUD (top bar)
------------------------------------------------------------
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUD"
hudFrame.Size = UDim2.new(0, 600, 0, 55)
hudFrame.Position = UDim2.new(0.5, -300, 0, 10)
hudFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
hudFrame.BackgroundTransparency = 0.15
hudFrame.Parent = screenGui
createCorner(hudFrame, 12)
createStroke(hudFrame, Color3.fromRGB(80, 80, 120), 2)

local hudLayout = Instance.new("UIListLayout")
hudLayout.FillDirection = Enum.FillDirection.Horizontal
hudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hudLayout.Padding = UDim.new(0, 15)
hudLayout.Parent = hudFrame

local function createHudStat(name, icon, color)
	local container = Instance.new("Frame")
	container.Name = name
	container.Size = UDim2.new(0, 130, 0, 40)
	container.BackgroundTransparency = 1
	container.Parent = hudFrame

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(0, 25, 1, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextScaled = true
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextColor3 = color
	iconLabel.Parent = container

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(1, -30, 1, 0)
	valueLabel.Position = UDim2.new(0, 30, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = "0"
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextColor3 = Color3.new(1, 1, 1)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.Parent = container

	return valueLabel
end

local coinsLabel = createHudStat("Coins", "$", Color3.fromRGB(255, 215, 0))
local speedLabel = createHudStat("Speed", ">", Color3.fromRGB(0, 200, 255))
local abyssLabel = createHudStat("Abyss", "#", Color3.fromRGB(255, 100, 100))
local incomeLabel = createHudStat("Income", "+", Color3.fromRGB(100, 255, 100))

------------------------------------------------------------
-- 2. BOTTOM BUTTONS (Inventory, Shop)
------------------------------------------------------------
local buttonBar = Instance.new("Frame")
buttonBar.Name = "ButtonBar"
buttonBar.Size = UDim2.new(0, 250, 0, 50)
buttonBar.Position = UDim2.new(0.5, -125, 1, -60)
buttonBar.BackgroundTransparency = 1
buttonBar.Parent = screenGui

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Horizontal
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 10)
buttonLayout.Parent = buttonBar

local function createMenuButton(name, text, color)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 115, 0, 45)
	btn.BackgroundColor3 = color
	btn.Text = text
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextScaled = true
	btn.Font = Enum.Font.GothamBold
	btn.Parent = buttonBar
	createCorner(btn, 10)
	createStroke(btn, Color3.fromRGB(255, 255, 255), 1)
	return btn
end

local inventoryBtn = createMenuButton("InventoryBtn", "Inventory", Color3.fromRGB(60, 60, 150))
local shopBtn = createMenuButton("ShopBtn", "Shop", Color3.fromRGB(60, 150, 60))

------------------------------------------------------------
-- 3. INVENTORY PANEL
------------------------------------------------------------
local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "InventoryPanel"
inventoryPanel.Size = UDim2.new(0, 400, 0, 500)
inventoryPanel.Position = UDim2.new(0.5, -200, 0.5, -250)
inventoryPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
inventoryPanel.Visible = false
inventoryPanel.Parent = screenGui
createCorner(inventoryPanel, 12)
createStroke(inventoryPanel, Color3.fromRGB(100, 100, 200), 2)

-- Title
local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, 0, 0, 40)
invTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
invTitle.Text = "INVENTORY"
invTitle.TextColor3 = Color3.new(1, 1, 1)
invTitle.TextScaled = true
invTitle.Font = Enum.Font.GothamBold
invTitle.Parent = inventoryPanel
createCorner(invTitle, 12)

-- Close button
local invClose = Instance.new("TextButton")
invClose.Size = UDim2.new(0, 30, 0, 30)
invClose.Position = UDim2.new(1, -35, 0, 5)
invClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
invClose.Text = "X"
invClose.TextColor3 = Color3.new(1, 1, 1)
invClose.TextScaled = true
invClose.Font = Enum.Font.GothamBold
invClose.Parent = inventoryPanel
createCorner(invClose, 6)

-- Treadmill section
local treadmillSection = Instance.new("Frame")
treadmillSection.Size = UDim2.new(1, -20, 0, 120)
treadmillSection.Position = UDim2.new(0, 10, 0, 50)
treadmillSection.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
treadmillSection.Parent = inventoryPanel
createCorner(treadmillSection, 8)

local treadmillTitle = Instance.new("TextLabel")
treadmillTitle.Size = UDim2.new(1, 0, 0, 25)
treadmillTitle.BackgroundTransparency = 1
treadmillTitle.Text = "Current Treadmill"
treadmillTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
treadmillTitle.TextScaled = true
treadmillTitle.Font = Enum.Font.GothamBold
treadmillTitle.Parent = treadmillSection

local treadmillNameLabel = Instance.new("TextLabel")
treadmillNameLabel.Name = "TreadmillName"
treadmillNameLabel.Size = UDim2.new(1, 0, 0, 20)
treadmillNameLabel.Position = UDim2.new(0, 0, 0, 25)
treadmillNameLabel.BackgroundTransparency = 1
treadmillNameLabel.Text = "Basic Treadmill"
treadmillNameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
treadmillNameLabel.TextScaled = true
treadmillNameLabel.Font = Enum.Font.Gotham
treadmillNameLabel.Parent = treadmillSection

-- CLICK TREADMILL BUTTON
local clickButton = Instance.new("TextButton")
clickButton.Name = "ClickTreadmill"
clickButton.Size = UDim2.new(0.8, 0, 0, 50)
clickButton.Position = UDim2.new(0.1, 0, 0, 55)
clickButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
clickButton.Text = "CLICK TREADMILL (+1 Speed)"
clickButton.TextColor3 = Color3.new(1, 1, 1)
clickButton.TextScaled = true
clickButton.Font = Enum.Font.GothamBold
clickButton.Parent = treadmillSection
createCorner(clickButton, 10)

-- Brainrot collection section
local brainrotSection = Instance.new("Frame")
brainrotSection.Size = UDim2.new(1, -20, 1, -185)
brainrotSection.Position = UDim2.new(0, 10, 0, 175)
brainrotSection.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
brainrotSection.ClipsDescendants = true
brainrotSection.Parent = inventoryPanel
createCorner(brainrotSection, 8)

local brainrotTitle = Instance.new("TextLabel")
brainrotTitle.Size = UDim2.new(1, 0, 0, 25)
brainrotTitle.BackgroundTransparency = 1
brainrotTitle.Text = "Collected Brainrots"
brainrotTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
brainrotTitle.TextScaled = true
brainrotTitle.Font = Enum.Font.GothamBold
brainrotTitle.Parent = brainrotSection

local brainrotScroll = Instance.new("ScrollingFrame")
brainrotScroll.Name = "BrainrotList"
brainrotScroll.Size = UDim2.new(1, -10, 1, -30)
brainrotScroll.Position = UDim2.new(0, 5, 0, 28)
brainrotScroll.BackgroundTransparency = 1
brainrotScroll.ScrollBarThickness = 6
brainrotScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 200)
brainrotScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
brainrotScroll.Parent = brainrotSection

local brainrotListLayout = Instance.new("UIListLayout")
brainrotListLayout.Padding = UDim.new(0, 4)
brainrotListLayout.Parent = brainrotScroll

------------------------------------------------------------
-- 4. SHOP PANEL
------------------------------------------------------------
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Size = UDim2.new(0, 400, 0, 420)
shopPanel.Position = UDim2.new(0.5, -200, 0.5, -210)
shopPanel.BackgroundColor3 = Color3.fromRGB(30, 45, 30)
shopPanel.Visible = false
shopPanel.Parent = screenGui
createCorner(shopPanel, 12)
createStroke(shopPanel, Color3.fromRGB(100, 200, 100), 2)

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0, 40)
shopTitle.BackgroundColor3 = Color3.fromRGB(50, 100, 50)
shopTitle.Text = "TREADMILL SHOP"
shopTitle.TextColor3 = Color3.new(1, 1, 1)
shopTitle.TextScaled = true
shopTitle.Font = Enum.Font.GothamBold
shopTitle.Parent = shopPanel
createCorner(shopTitle, 12)

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.new(0, 30, 0, 30)
shopClose.Position = UDim2.new(1, -35, 0, 5)
shopClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
shopClose.Text = "X"
shopClose.TextColor3 = Color3.new(1, 1, 1)
shopClose.TextScaled = true
shopClose.Font = Enum.Font.GothamBold
shopClose.Parent = shopPanel
createCorner(shopClose, 6)

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Name = "ShopList"
shopScroll.Size = UDim2.new(1, -20, 1, -55)
shopScroll.Position = UDim2.new(0, 10, 0, 48)
shopScroll.BackgroundTransparency = 1
shopScroll.ScrollBarThickness = 6
shopScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
shopScroll.Parent = shopPanel

local shopListLayout = Instance.new("UIListLayout")
shopListLayout.Padding = UDim.new(0, 6)
shopListLayout.Parent = shopScroll

-- Create shop items
for _, treadmill in ipairs(TreadmillData.Treadmills) do
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = treadmill.name
	itemFrame.Size = UDim2.new(1, -10, 0, 65)
	itemFrame.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
	itemFrame.Parent = shopScroll
	createCorner(itemFrame, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.5, 0, 0, 25)
	nameLabel.Position = UDim2.new(0, 10, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = treadmill.name
	nameLabel.TextColor3 = treadmill.color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = itemFrame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(0.5, 0, 0, 20)
	statsLabel.Position = UDim2.new(0, 10, 0, 30)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "+" .. treadmill.speedPerClick .. " speed/click"
	statsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Parent = itemFrame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyBtn"
	buyButton.Size = UDim2.new(0, 100, 0, 35)
	buyButton.Position = UDim2.new(1, -110, 0, 15)
	buyButton.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
	buyButton.TextColor3 = Color3.new(1, 1, 1)
	buyButton.TextScaled = true
	buyButton.Font = Enum.Font.GothamBold
	buyButton.Parent = itemFrame
	createCorner(buyButton, 8)

	if treadmill.price == 0 then
		buyButton.Text = "FREE"
		buyButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	else
		buyButton.Text = "$" .. formatNum(treadmill.price)
	end

	buyButton.MouseButton1Click:Connect(function()
		ClientState.PurchaseTreadmill(treadmill.name)
	end)
end

-- Update shop canvas size
shopListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	shopScroll.CanvasSize = UDim2.new(0, 0, 0, shopListLayout.AbsoluteContentSize.Y + 10)
end)

------------------------------------------------------------
-- 5. NOTIFICATION SYSTEM
------------------------------------------------------------
local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.Size = UDim2.new(0, 350, 0, 400)
notifContainer.Position = UDim2.new(1, -360, 0, 80)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 5)
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Parent = notifContainer

local function showNotification(text, color, duration)
	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 40)
	notif.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	notif.BackgroundTransparency = 0.2
	notif.Parent = notifContainer
	createCorner(notif, 8)
	createStroke(notif, color or Color3.new(1, 1, 1), 2)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 1, 0)
	label.Position = UDim2.new(0, 5, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = notif

	task.delay(duration or 4, function()
		local tween = TweenService:Create(notif, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		local textTween = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 })
		tween:Play()
		textTween:Play()
		tween.Completed:Wait()
		notif:Destroy()
	end)
end

------------------------------------------------------------
-- 6. MISSION INFO (left side)
------------------------------------------------------------
local missionFrame = Instance.new("Frame")
missionFrame.Name = "MissionInfo"
missionFrame.Size = UDim2.new(0, 220, 0, 100)
missionFrame.Position = UDim2.new(0, 10, 0.5, -50)
missionFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
missionFrame.BackgroundTransparency = 0.2
missionFrame.Parent = screenGui
createCorner(missionFrame, 10)
createStroke(missionFrame, Color3.fromRGB(255, 100, 100), 2)

local missionTitle = Instance.new("TextLabel")
missionTitle.Size = UDim2.new(1, 0, 0, 22)
missionTitle.BackgroundTransparency = 1
missionTitle.Text = "CURRENT MISSION"
missionTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
missionTitle.TextScaled = true
missionTitle.Font = Enum.Font.GothamBold
missionTitle.Parent = missionFrame

local missionAbyssLabel = Instance.new("TextLabel")
missionAbyssLabel.Name = "AbyssNum"
missionAbyssLabel.Size = UDim2.new(1, -10, 0, 20)
missionAbyssLabel.Position = UDim2.new(0, 5, 0, 24)
missionAbyssLabel.BackgroundTransparency = 1
missionAbyssLabel.Text = "Abyss #1"
missionAbyssLabel.TextColor3 = Color3.new(1, 1, 1)
missionAbyssLabel.TextScaled = true
missionAbyssLabel.Font = Enum.Font.Gotham
missionAbyssLabel.TextXAlignment = Enum.TextXAlignment.Left
missionAbyssLabel.Parent = missionFrame

local missionTierLabel = Instance.new("TextLabel")
missionTierLabel.Name = "TierName"
missionTierLabel.Size = UDim2.new(1, -10, 0, 20)
missionTierLabel.Position = UDim2.new(0, 5, 0, 46)
missionTierLabel.BackgroundTransparency = 1
missionTierLabel.Text = "Tier: Common"
missionTierLabel.TextColor3 = GameConfig.RARITY_COLORS.Common
missionTierLabel.TextScaled = true
missionTierLabel.Font = Enum.Font.GothamBold
missionTierLabel.TextXAlignment = Enum.TextXAlignment.Left
missionTierLabel.Parent = missionFrame

local missionProgressLabel = Instance.new("TextLabel")
missionProgressLabel.Name = "Progress"
missionProgressLabel.Size = UDim2.new(1, -10, 0, 20)
missionProgressLabel.Position = UDim2.new(0, 5, 0, 68)
missionProgressLabel.BackgroundTransparency = 1
missionProgressLabel.Text = "Next tier in: 5 abysses"
missionProgressLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
missionProgressLabel.TextScaled = true
missionProgressLabel.Font = Enum.Font.Gotham
missionProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
missionProgressLabel.Parent = missionFrame

------------------------------------------------------------
-- EVENT HANDLERS
------------------------------------------------------------

-- Toggle panels
local function togglePanel(panel)
	panel.Visible = not panel.Visible
	-- Close other panels
	if panel == inventoryPanel and shopPanel.Visible then
		shopPanel.Visible = false
	elseif panel == shopPanel and inventoryPanel.Visible then
		inventoryPanel.Visible = false
	end
end

inventoryBtn.MouseButton1Click:Connect(function()
	togglePanel(inventoryPanel)
end)

shopBtn.MouseButton1Click:Connect(function()
	togglePanel(shopPanel)
end)

invClose.MouseButton1Click:Connect(function()
	inventoryPanel.Visible = false
end)

shopClose.MouseButton1Click:Connect(function()
	shopPanel.Visible = false
end)

-- Treadmill click
clickButton.MouseButton1Click:Connect(function()
	ClientState.ClickTreadmill()

	-- Visual feedback
	local origColor = clickButton.BackgroundColor3
	clickButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	task.delay(0.1, function()
		clickButton.BackgroundColor3 = origColor
	end)
end)

-- Update GUI when data changes
local function updateGui(data)
	if not data then return end

	-- HUD
	coinsLabel.Text = formatNum(data.coins)
	speedLabel.Text = formatNum(data.speed)
	abyssLabel.Text = tostring(data.currentAbyss)
	incomeLabel.Text = formatNum(ClientState.GetIncomePerSecond()) .. "/s"

	-- Treadmill info
	local treadmill = TreadmillData.GetByName(data.currentTreadmill)
	if treadmill then
		treadmillNameLabel.Text = data.currentTreadmill
		clickButton.Text = "CLICK TREADMILL (+" .. treadmill.speedPerClick .. " Speed)"
	end

	-- Mission info
	local currentAbyss = data.currentAbyss
	local tier = GameConfig.GetTierForAbyss(currentAbyss)
	local abyssInTier = ((currentAbyss - 1) % GameConfig.ABYSSES_PER_TIER) + 1
	local remaining = GameConfig.ABYSSES_PER_TIER - abyssInTier + 1

	missionAbyssLabel.Text = "Abyss #" .. currentAbyss
	missionTierLabel.Text = "Tier: " .. tier
	missionTierLabel.TextColor3 = GameConfig.RARITY_COLORS[tier] or Color3.new(1, 1, 1)

	-- Check if at max tier
	local tierIndex = 1
	for i, t in ipairs(GameConfig.RARITY_ORDER) do
		if t == tier then tierIndex = i break end
	end
	if tierIndex >= #GameConfig.RARITY_ORDER then
		missionProgressLabel.Text = "MAX TIER!"
	else
		missionProgressLabel.Text = "Next tier in: " .. remaining .. " abysses"
	end

	-- Update brainrot list in inventory
	for _, child in ipairs(brainrotScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Sort brainrots by income (highest first)
	local sortedBrainrots = {}
	for brainrotName, count in pairs(data.collectedBrainrots or {}) do
		local info = BrainrotData.GetByName(brainrotName)
		if info then
			table.insert(sortedBrainrots, { name = brainrotName, count = count, info = info })
		end
	end
	table.sort(sortedBrainrots, function(a, b) return a.info.income > b.info.income end)

	for _, entry in ipairs(sortedBrainrots) do
		local itemFrame = Instance.new("Frame")
		itemFrame.Size = UDim2.new(1, -10, 0, 35)
		itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
		itemFrame.Parent = brainrotScroll
		createCorner(itemFrame, 6)

		local rarityDot = Instance.new("Frame")
		rarityDot.Size = UDim2.new(0, 8, 0, 8)
		rarityDot.Position = UDim2.new(0, 8, 0.5, -4)
		rarityDot.BackgroundColor3 = GameConfig.RARITY_COLORS[entry.info.rarity] or Color3.new(1,1,1)
		rarityDot.Parent = itemFrame
		createCorner(rarityDot, 4)

		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0.55, -25, 1, 0)
		nameL.Position = UDim2.new(0, 22, 0, 0)
		nameL.BackgroundTransparency = 1
		nameL.Text = entry.name
		nameL.TextColor3 = GameConfig.RARITY_COLORS[entry.info.rarity] or Color3.new(1,1,1)
		nameL.TextScaled = true
		nameL.Font = Enum.Font.GothamBold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Parent = itemFrame

		local countL = Instance.new("TextLabel")
		countL.Size = UDim2.new(0, 35, 1, 0)
		countL.Position = UDim2.new(0.55, 0, 0, 0)
		countL.BackgroundTransparency = 1
		countL.Text = "x" .. entry.count
		countL.TextColor3 = Color3.fromRGB(180, 180, 180)
		countL.TextScaled = true
		countL.Font = Enum.Font.Gotham
		countL.Parent = itemFrame

		local incomeL = Instance.new("TextLabel")
		incomeL.Size = UDim2.new(0.25, 0, 1, 0)
		incomeL.Position = UDim2.new(0.75, 0, 0, 0)
		incomeL.BackgroundTransparency = 1
		incomeL.Text = formatNum(entry.info.income * entry.count) .. "/s"
		incomeL.TextColor3 = Color3.fromRGB(100, 255, 100)
		incomeL.TextScaled = true
		incomeL.Font = Enum.Font.Gotham
		incomeL.Parent = itemFrame
	end

	brainrotScroll.CanvasSize = UDim2.new(0, 0, 0, brainrotListLayout.AbsoluteContentSize.Y + 10)

	-- Update shop buttons (mark owned)
	for _, itemFrame in ipairs(shopScroll:GetChildren()) do
		if itemFrame:IsA("Frame") then
			local buyBtn = itemFrame:FindFirstChild("BuyBtn")
			if buyBtn then
				if itemFrame.Name == data.currentTreadmill then
					buyBtn.Text = "EQUIPPED"
					buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				else
					local treadmill = TreadmillData.GetByName(itemFrame.Name)
					if treadmill then
						if treadmill.price == 0 then
							buyBtn.Text = "FREE"
							buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
						elseif data.coins >= treadmill.price then
							buyBtn.Text = "$" .. formatNum(treadmill.price)
							buyBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
						else
							buyBtn.Text = "$" .. formatNum(treadmill.price)
							buyBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
						end
					end
				end
			end
		end
	end
end

ClientState.OnDataUpdated.Event:Connect(updateGui)

-- Brainrot earned notifications
ClientState.OnBrainrotEarned.Event:Connect(function(awardedNames, tier)
	local color = GameConfig.RARITY_COLORS[tier] or Color3.new(1, 1, 1)
	for _, name in ipairs(awardedNames) do
		showNotification("NEW: " .. name .. " [" .. tier .. "]", color, 5)
		task.wait(0.3)
	end
end)

-- Purchase result
ClientState.OnPurchaseResult.Event:Connect(function(success, treadmillName)
	if success then
		showNotification("Purchased: " .. treadmillName, Color3.fromRGB(100, 255, 100), 3)
	else
		showNotification("Cannot purchase " .. treadmillName, Color3.fromRGB(255, 100, 100), 3)
	end
end)

-- Initial update if data already available
if ClientState.PlayerData then
	updateGui(ClientState.PlayerData)
end
