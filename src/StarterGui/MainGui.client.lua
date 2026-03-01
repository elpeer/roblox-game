--[[
	MainGui - Creates and manages all GUI elements:
	  - Main HUD (coins, speed, abyss, income)
	  - Inventory (treadmill click button + brainrot list with placed/unplaced)
	  - Shop (buy treadmills - with new high tiers)
	  - Notifications (brainrot earned popups)
	  - DROP button (when carrying brainrot)
	  - Mobile responsive panels
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
-- 1. MAIN HUD (top-left, bold floating stat labels)
------------------------------------------------------------
local hudFrame = Instance.new("Frame")
hudFrame.Name = "HUD"
hudFrame.Size = UDim2.new(0, 280, 0, 180)
hudFrame.Position = UDim2.new(0, 12, 0, 12)
hudFrame.BackgroundTransparency = 1
hudFrame.Parent = screenGui

local hudLayout = Instance.new("UIListLayout")
hudLayout.FillDirection = Enum.FillDirection.Vertical
hudLayout.Padding = UDim.new(0, 2)
hudLayout.Parent = hudFrame

local function createHudStat(name, prefix, color)
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = name
	valueLabel.Size = UDim2.new(1, 0, 0, 42)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = prefix .. "0"
	valueLabel.TextColor3 = color
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamBlack
	valueLabel.TextXAlignment = Enum.TextXAlignment.Left
	valueLabel.TextStrokeTransparency = 0
	valueLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	valueLabel.Parent = hudFrame

	return valueLabel
end

local coinsLabel = createHudStat("Coins", "$", Color3.fromRGB(80, 255, 80))
local speedLabel = createHudStat("Speed", "Speed: ", Color3.fromRGB(255, 220, 0))
local abyssLabel = createHudStat("Abyss", "Abyss #", Color3.fromRGB(255, 100, 100))
local incomeLabel = createHudStat("Income", "+", Color3.fromRGB(100, 255, 100))

------------------------------------------------------------
-- 2. SIDE BUTTONS (right side, vertical with icons)
------------------------------------------------------------
local buttonBar = Instance.new("Frame")
buttonBar.Name = "ButtonBar"
buttonBar.Size = UDim2.new(0, 70, 0, 155)
buttonBar.Position = UDim2.new(1, -82, 0.5, -77)
buttonBar.BackgroundTransparency = 1
buttonBar.Parent = screenGui

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.FillDirection = Enum.FillDirection.Vertical
buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.Parent = buttonBar

local function createMenuButton(name, icon, label, color)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.new(0, 65, 0, 65)
	btn.BackgroundColor3 = color
	btn.Text = ""
	btn.AutoButtonColor = true
	btn.Parent = buttonBar
	createCorner(btn, 16)
	createStroke(btn, Color3.fromRGB(255, 255, 255), 2)

	local iconLbl = Instance.new("TextLabel")
	iconLbl.Size = UDim2.new(1, 0, 0.55, 0)
	iconLbl.Position = UDim2.new(0, 0, 0.02, 0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text = icon
	iconLbl.TextScaled = true
	iconLbl.Font = Enum.Font.GothamBold
	iconLbl.TextColor3 = Color3.new(1, 1, 1)
	iconLbl.Parent = btn

	local textLbl = Instance.new("TextLabel")
	textLbl.Size = UDim2.new(1, 0, 0.35, 0)
	textLbl.Position = UDim2.new(0, 0, 0.62, 0)
	textLbl.BackgroundTransparency = 1
	textLbl.Text = label
	textLbl.TextScaled = true
	textLbl.Font = Enum.Font.GothamBold
	textLbl.TextColor3 = Color3.fromRGB(220, 220, 220)
	textLbl.Parent = btn

	return btn
end

local inventoryBtn = createMenuButton("InventoryBtn", "[]", "Bag", Color3.fromRGB(70, 70, 170))
local shopBtn = createMenuButton("ShopBtn", "$", "Shop", Color3.fromRGB(70, 170, 70))

------------------------------------------------------------
-- 3. INVENTORY PANEL - MOBILE RESPONSIVE
------------------------------------------------------------
local inventoryPanel = Instance.new("Frame")
inventoryPanel.Name = "InventoryPanel"
inventoryPanel.Size = UDim2.new(0.85, 0, 0.75, 0)
inventoryPanel.Position = UDim2.new(0.075, 0, 0.12, 0)
inventoryPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
inventoryPanel.Visible = false
inventoryPanel.ClipsDescendants = true
inventoryPanel.Parent = screenGui
createCorner(inventoryPanel, 12)
createStroke(inventoryPanel, Color3.fromRGB(100, 100, 200), 2)

-- Inventory Title
local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.new(1, 0, 0, 40)
invTitle.BackgroundColor3 = Color3.fromRGB(50, 50, 100)
invTitle.Text = "INVENTORY"
invTitle.TextColor3 = Color3.new(1, 1, 1)
invTitle.TextScaled = true
invTitle.Font = Enum.Font.GothamBold
invTitle.Parent = inventoryPanel
createCorner(invTitle, 12)

-- Close button (larger for mobile)
local invClose = Instance.new("TextButton")
invClose.Size = UDim2.new(0, 40, 0, 40)
invClose.Position = UDim2.new(1, -45, 0, 0)
invClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
invClose.Text = "X"
invClose.TextColor3 = Color3.new(1, 1, 1)
invClose.TextScaled = true
invClose.Font = Enum.Font.GothamBold
invClose.Parent = inventoryPanel
createCorner(invClose, 8)

-- Treadmill section
local treadmillSection = Instance.new("Frame")
treadmillSection.Size = UDim2.new(1, -20, 0, 100)
treadmillSection.Position = UDim2.new(0, 10, 0, 48)
treadmillSection.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
treadmillSection.Parent = inventoryPanel
createCorner(treadmillSection, 8)

local treadmillTitle = Instance.new("TextLabel")
treadmillTitle.Size = UDim2.new(1, 0, 0, 22)
treadmillTitle.BackgroundTransparency = 1
treadmillTitle.Text = "Current Treadmill"
treadmillTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
treadmillTitle.TextScaled = true
treadmillTitle.Font = Enum.Font.GothamBold
treadmillTitle.Parent = treadmillSection

local treadmillNameLabel = Instance.new("TextLabel")
treadmillNameLabel.Name = "TreadmillName"
treadmillNameLabel.Size = UDim2.new(1, 0, 0, 18)
treadmillNameLabel.Position = UDim2.new(0, 0, 0, 22)
treadmillNameLabel.BackgroundTransparency = 1
treadmillNameLabel.Text = "Basic Treadmill"
treadmillNameLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
treadmillNameLabel.TextScaled = true
treadmillNameLabel.Font = Enum.Font.Gotham
treadmillNameLabel.Parent = treadmillSection

local clickButton = Instance.new("TextButton")
clickButton.Name = "ClickTreadmill"
clickButton.Size = UDim2.new(0.8, 0, 0, 42)
clickButton.Position = UDim2.new(0.1, 0, 0, 48)
clickButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
clickButton.Text = "CLICK TREADMILL (+1 Speed)"
clickButton.TextColor3 = Color3.new(1, 1, 1)
clickButton.TextScaled = true
clickButton.Font = Enum.Font.GothamBold
clickButton.Parent = treadmillSection
createCorner(clickButton, 10)

-- Place Brainrots button
local placeButton = Instance.new("TextButton")
placeButton.Name = "PlaceBrainrots"
placeButton.Size = UDim2.new(1, -20, 0, 36)
placeButton.Position = UDim2.new(0, 10, 0, 155)
placeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
placeButton.Text = "PLACE ALL ON STAGE (at base, press E)"
placeButton.TextColor3 = Color3.new(1, 1, 1)
placeButton.TextScaled = true
placeButton.Font = Enum.Font.GothamBold
placeButton.Parent = inventoryPanel
createCorner(placeButton, 8)

placeButton.MouseButton1Click:Connect(function()
	ClientState.PlaceBrainrots()
end)

-- Brainrot collection section
local brainrotSection = Instance.new("Frame")
brainrotSection.Size = UDim2.new(1, -20, 1, -205)
brainrotSection.Position = UDim2.new(0, 10, 0, 198)
brainrotSection.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
brainrotSection.ClipsDescendants = true
brainrotSection.Parent = inventoryPanel
createCorner(brainrotSection, 8)

local brainrotTitle = Instance.new("TextLabel")
brainrotTitle.Size = UDim2.new(1, 0, 0, 22)
brainrotTitle.BackgroundTransparency = 1
brainrotTitle.Text = "My Brainrots"
brainrotTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
brainrotTitle.TextScaled = true
brainrotTitle.Font = Enum.Font.GothamBold
brainrotTitle.Parent = brainrotSection

local brainrotScroll = Instance.new("ScrollingFrame")
brainrotScroll.Name = "BrainrotList"
brainrotScroll.Size = UDim2.new(1, -10, 1, -28)
brainrotScroll.Position = UDim2.new(0, 5, 0, 26)
brainrotScroll.BackgroundTransparency = 1
brainrotScroll.ScrollBarThickness = 6
brainrotScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 200)
brainrotScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
brainrotScroll.Parent = brainrotSection

local brainrotListLayout = Instance.new("UIListLayout")
brainrotListLayout.Padding = UDim.new(0, 4)
brainrotListLayout.Parent = brainrotScroll

------------------------------------------------------------
-- 4. SHOP PANEL - MOBILE RESPONSIVE
------------------------------------------------------------
local shopPanel = Instance.new("Frame")
shopPanel.Name = "ShopPanel"
shopPanel.Size = UDim2.new(0.85, 0, 0.75, 0)
shopPanel.Position = UDim2.new(0.075, 0, 0.12, 0)
shopPanel.BackgroundColor3 = Color3.fromRGB(30, 45, 30)
shopPanel.Visible = false
shopPanel.ClipsDescendants = true
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
shopClose.Size = UDim2.new(0, 40, 0, 40)
shopClose.Position = UDim2.new(1, -45, 0, 0)
shopClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
shopClose.Text = "X"
shopClose.TextColor3 = Color3.new(1, 1, 1)
shopClose.TextScaled = true
shopClose.Font = Enum.Font.GothamBold
shopClose.Parent = shopPanel
createCorner(shopClose, 8)

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

-- Create shop items (all treadmills including new tiers)
for _, treadmill in ipairs(TreadmillData.Treadmills) do
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = treadmill.name
	itemFrame.Size = UDim2.new(1, -10, 0, 60)
	itemFrame.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
	itemFrame.Parent = shopScroll
	createCorner(itemFrame, 8)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.55, 0, 0, 22)
	nameLabel.Position = UDim2.new(0, 8, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = treadmill.name
	nameLabel.TextColor3 = treadmill.color
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = itemFrame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Size = UDim2.new(0.55, 0, 0, 18)
	statsLabel.Position = UDim2.new(0, 8, 0, 28)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "+" .. formatNum(treadmill.speedPerClick) .. " speed/click"
	statsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Parent = itemFrame

	local buyButton = Instance.new("TextButton")
	buyButton.Name = "BuyBtn"
	buyButton.Size = UDim2.new(0.35, -10, 0, 35)
	buyButton.Position = UDim2.new(0.65, 0, 0.5, -17)
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

shopListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	shopScroll.CanvasSize = UDim2.new(0, 0, 0, shopListLayout.AbsoluteContentSize.Y + 10)
end)

------------------------------------------------------------
-- 5. DROP BUTTON (visible when carrying brainrot)
------------------------------------------------------------
local dropButton = Instance.new("TextButton")
dropButton.Name = "DropButton"
dropButton.Size = UDim2.new(0, 180, 0, 55)
dropButton.Position = UDim2.new(0.5, -90, 1, -130)
dropButton.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
dropButton.Text = "DROP BRAINROT"
dropButton.TextColor3 = Color3.new(1, 1, 1)
dropButton.TextScaled = true
dropButton.Font = Enum.Font.GothamBold
dropButton.Visible = false
dropButton.ZIndex = 5
dropButton.Parent = screenGui
createCorner(dropButton, 12)
createStroke(dropButton, Color3.fromRGB(255, 100, 100), 3)

dropButton.MouseButton1Click:Connect(function()
	ClientState.DropBrainrot()
end)

-- Carry info label (shows what you're carrying)
local carryLabel = Instance.new("TextLabel")
carryLabel.Name = "CarryLabel"
carryLabel.Size = UDim2.new(0, 250, 0, 30)
carryLabel.Position = UDim2.new(0.5, -125, 1, -165)
carryLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
carryLabel.BackgroundTransparency = 0.3
carryLabel.Text = ""
carryLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
carryLabel.TextScaled = true
carryLabel.Font = Enum.Font.GothamBold
carryLabel.Visible = false
carryLabel.ZIndex = 5
carryLabel.Parent = screenGui
createCorner(carryLabel, 8)

------------------------------------------------------------
-- 6. NOTIFICATION SYSTEM
------------------------------------------------------------
local notifContainer = Instance.new("Frame")
notifContainer.Name = "Notifications"
notifContainer.Size = UDim2.new(0.4, 0, 0, 400)
notifContainer.Position = UDim2.new(0.58, 0, 0, 70)
notifContainer.BackgroundTransparency = 1
notifContainer.Parent = screenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.Padding = UDim.new(0, 5)
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
notifLayout.Parent = notifContainer

local function showNotification(text, color, duration)
	local notif = Instance.new("Frame")
	notif.Size = UDim2.new(1, 0, 0, 35)
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
-- 7. MISSION INFO (left side)
------------------------------------------------------------
local missionFrame = Instance.new("Frame")
missionFrame.Name = "MissionInfo"
missionFrame.Size = UDim2.new(0, 200, 0, 90)
missionFrame.Position = UDim2.new(0, 10, 0.5, -45)
missionFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
missionFrame.BackgroundTransparency = 0.2
missionFrame.Parent = screenGui
createCorner(missionFrame, 10)
createStroke(missionFrame, Color3.fromRGB(255, 100, 100), 2)

local missionTitle = Instance.new("TextLabel")
missionTitle.Size = UDim2.new(1, 0, 0, 20)
missionTitle.BackgroundTransparency = 1
missionTitle.Text = "CURRENT MISSION"
missionTitle.TextColor3 = Color3.fromRGB(255, 100, 100)
missionTitle.TextScaled = true
missionTitle.Font = Enum.Font.GothamBold
missionTitle.Parent = missionFrame

local missionAbyssLabel = Instance.new("TextLabel")
missionAbyssLabel.Name = "AbyssNum"
missionAbyssLabel.Size = UDim2.new(1, -10, 0, 18)
missionAbyssLabel.Position = UDim2.new(0, 5, 0, 22)
missionAbyssLabel.BackgroundTransparency = 1
missionAbyssLabel.Text = "Abyss #1"
missionAbyssLabel.TextColor3 = Color3.new(1, 1, 1)
missionAbyssLabel.TextScaled = true
missionAbyssLabel.Font = Enum.Font.Gotham
missionAbyssLabel.TextXAlignment = Enum.TextXAlignment.Left
missionAbyssLabel.Parent = missionFrame

local missionTierLabel = Instance.new("TextLabel")
missionTierLabel.Name = "TierName"
missionTierLabel.Size = UDim2.new(1, -10, 0, 18)
missionTierLabel.Position = UDim2.new(0, 5, 0, 42)
missionTierLabel.BackgroundTransparency = 1
missionTierLabel.Text = "Tier: Common"
missionTierLabel.TextColor3 = GameConfig.RARITY_COLORS.Common
missionTierLabel.TextScaled = true
missionTierLabel.Font = Enum.Font.GothamBold
missionTierLabel.TextXAlignment = Enum.TextXAlignment.Left
missionTierLabel.Parent = missionFrame

local missionProgressLabel = Instance.new("TextLabel")
missionProgressLabel.Name = "Progress"
missionProgressLabel.Size = UDim2.new(1, -10, 0, 18)
missionProgressLabel.Position = UDim2.new(0, 5, 0, 62)
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
local function togglePanel(panel)
	panel.Visible = not panel.Visible
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
	local origColor = clickButton.BackgroundColor3
	clickButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
	task.delay(0.1, function()
		clickButton.BackgroundColor3 = origColor
	end)
end)

-- Carry update handler (show/hide drop button)
ClientState.OnCarryUpdated.Event:Connect(function(carryData)
	if carryData then
		dropButton.Visible = true
		carryLabel.Visible = true
		carryLabel.Text = "Carrying: " .. carryData.name
		local rarityColor = GameConfig.RARITY_COLORS[carryData.rarity] or Color3.fromRGB(255, 215, 0)
		carryLabel.TextColor3 = rarityColor
	else
		dropButton.Visible = false
		carryLabel.Visible = false
	end
end)

-- Update GUI when data changes
local function updateGui(data)
	if not data then return end

	-- HUD
	coinsLabel.Text = "$" .. formatNum(data.coins)
	speedLabel.Text = "Speed: " .. formatNum(data.speed)
	abyssLabel.Text = "Abyss #" .. tostring(data.currentAbyss)
	incomeLabel.Text = "+" .. formatNum(ClientState.GetIncomePerSecond()) .. "/s"

	-- Treadmill info
	local treadmill = TreadmillData.GetByName(data.currentTreadmill)
	if treadmill then
		treadmillNameLabel.Text = data.currentTreadmill
		clickButton.Text = "CLICK TREADMILL (+" .. formatNum(treadmill.speedPerClick) .. " Speed)"
	end

	-- Mission info
	local currentAbyss = data.currentAbyss
	local tier = GameConfig.GetTierForAbyss(currentAbyss)
	local abyssInTier = ((currentAbyss - 1) % GameConfig.ABYSSES_PER_TIER) + 1
	local remaining = GameConfig.ABYSSES_PER_TIER - abyssInTier + 1

	missionAbyssLabel.Text = "Abyss #" .. currentAbyss
	missionTierLabel.Text = "Tier: " .. tier
	missionTierLabel.TextColor3 = GameConfig.RARITY_COLORS[tier] or Color3.new(1, 1, 1)

	local tierIndex = 1
	for i, t in ipairs(GameConfig.RARITY_ORDER) do
		if t == tier then tierIndex = i break end
	end
	if tierIndex >= #GameConfig.RARITY_ORDER then
		missionProgressLabel.Text = "MAX TIER!"
	else
		missionProgressLabel.Text = "Next tier in: " .. remaining .. " abysses"
	end

	-- Update Place button text
	local unplacedCount = 0
	for _, count in pairs(data.collectedBrainrots or {}) do
		unplacedCount = unplacedCount + count
	end
	if unplacedCount > 0 then
		placeButton.Text = "PLACE " .. unplacedCount .. " BRAINROT(S) ON STAGE"
		placeButton.BackgroundColor3 = Color3.fromRGB(200, 150, 0)
	else
		placeButton.Text = "No brainrots to place"
		placeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	end

	-- Update brainrot list in inventory
	for _, child in ipairs(brainrotScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	-- Merge collected + placed for display
	local allBrainrots = {}
	for brainrotName, count in pairs(data.placedBrainrots or {}) do
		local info = BrainrotData.GetByName(brainrotName)
		if info then
			allBrainrots[brainrotName] = {
				name = brainrotName,
				placed = count,
				collected = 0,
				info = info,
			}
		end
	end
	for brainrotName, count in pairs(data.collectedBrainrots or {}) do
		local info = BrainrotData.GetByName(brainrotName)
		if info then
			if not allBrainrots[brainrotName] then
				allBrainrots[brainrotName] = {
					name = brainrotName,
					placed = 0,
					collected = count,
					info = info,
				}
			else
				allBrainrots[brainrotName].collected = count
			end
		end
	end

	-- Sort by income (highest first)
	local sortedBrainrots = {}
	for _, entry in pairs(allBrainrots) do
		table.insert(sortedBrainrots, entry)
	end
	table.sort(sortedBrainrots, function(a, b) return a.info.income > b.info.income end)

	for _, entry in ipairs(sortedBrainrots) do
		local total = entry.placed + entry.collected
		local itemFrame = Instance.new("Frame")
		itemFrame.Size = UDim2.new(1, -10, 0, 60)
		itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
		itemFrame.Parent = brainrotScroll
		createCorner(itemFrame, 6)

		-- Rarity dot
		local rarityDot = Instance.new("Frame")
		rarityDot.Size = UDim2.new(0, 8, 0, 8)
		rarityDot.Position = UDim2.new(0, 6, 0, 8)
		rarityDot.BackgroundColor3 = GameConfig.RARITY_COLORS[entry.info.rarity] or Color3.new(1,1,1)
		rarityDot.Parent = itemFrame
		createCorner(rarityDot, 4)

		-- Name
		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0.5, -20, 0, 20)
		nameL.Position = UDim2.new(0, 18, 0, 2)
		nameL.BackgroundTransparency = 1
		nameL.Text = entry.name
		nameL.TextColor3 = GameConfig.RARITY_COLORS[entry.info.rarity] or Color3.new(1,1,1)
		nameL.TextScaled = true
		nameL.Font = Enum.Font.GothamBold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.Parent = itemFrame

		-- Count + Income on top row
		local infoL = Instance.new("TextLabel")
		infoL.Size = UDim2.new(0.45, 0, 0, 20)
		infoL.Position = UDim2.new(0.52, 0, 0, 2)
		infoL.BackgroundTransparency = 1
		local incomeText = entry.placed > 0 and ("  $" .. formatNum(entry.info.income * entry.placed) .. "/s") or ""
		infoL.Text = "x" .. total .. incomeText
		infoL.TextColor3 = entry.placed > 0 and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 180, 180)
		infoL.TextScaled = true
		infoL.Font = Enum.Font.Gotham
		infoL.TextXAlignment = Enum.TextXAlignment.Right
		infoL.Parent = itemFrame

		-- Bottom row: status + action buttons
		local statusL = Instance.new("TextLabel")
		statusL.Size = UDim2.new(0.35, 0, 0, 16)
		statusL.Position = UDim2.new(0, 18, 0, 24)
		statusL.BackgroundTransparency = 1
		statusL.Font = Enum.Font.Gotham
		statusL.TextScaled = true
		statusL.TextXAlignment = Enum.TextXAlignment.Left
		statusL.Parent = itemFrame

		if entry.placed > 0 and entry.collected > 0 then
			statusL.Text = entry.placed .. " placed, " .. entry.collected .. " in bag"
			statusL.TextColor3 = Color3.fromRGB(180, 200, 255)
		elseif entry.placed > 0 then
			statusL.Text = entry.placed .. " on stage"
			statusL.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			statusL.Text = entry.collected .. " in bag"
			statusL.TextColor3 = Color3.fromRGB(255, 200, 50)
		end

		-- Place button (if has collected/inventory brainrots)
		if entry.collected > 0 then
			local placeBtn = Instance.new("TextButton")
			placeBtn.Size = UDim2.new(0, 70, 0, 24)
			placeBtn.Position = UDim2.new(1, -150, 0, 30)
			placeBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
			placeBtn.Text = "PLACE"
			placeBtn.TextColor3 = Color3.new(1, 1, 1)
			placeBtn.TextScaled = true
			placeBtn.Font = Enum.Font.GothamBold
			placeBtn.Parent = itemFrame
			createCorner(placeBtn, 6)

			local brName = entry.name
			placeBtn.MouseButton1Click:Connect(function()
				ClientState.PlaceSingleBrainrot(brName)
			end)
		end

		-- Return button (if has placed brainrots)
		if entry.placed > 0 then
			local returnBtn = Instance.new("TextButton")
			returnBtn.Size = UDim2.new(0, 70, 0, 24)
			returnBtn.Position = UDim2.new(1, -75, 0, 30)
			returnBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 30)
			returnBtn.Text = "RETURN"
			returnBtn.TextColor3 = Color3.new(1, 1, 1)
			returnBtn.TextScaled = true
			returnBtn.Font = Enum.Font.GothamBold
			returnBtn.Parent = itemFrame
			createCorner(returnBtn, 6)

			local brName = entry.name
			returnBtn.MouseButton1Click:Connect(function()
				ClientState.ReturnBrainrot(brName)
			end)
		end
	end

	brainrotScroll.CanvasSize = UDim2.new(0, 0, 0, brainrotListLayout.AbsoluteContentSize.Y + 10)

	-- Update shop buttons
	for _, itemFrame in ipairs(shopScroll:GetChildren()) do
		if itemFrame:IsA("Frame") then
			local buyBtn = itemFrame:FindFirstChild("BuyBtn")
			if buyBtn then
				if itemFrame.Name == data.currentTreadmill then
					buyBtn.Text = "EQUIPPED"
					buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
				else
					local tmData = TreadmillData.GetByName(itemFrame.Name)
					if tmData then
						if tmData.price == 0 then
							buyBtn.Text = "FREE"
							buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
						elseif data.coins >= tmData.price then
							buyBtn.Text = "$" .. formatNum(tmData.price)
							buyBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
						else
							buyBtn.Text = "$" .. formatNum(tmData.price)
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
		showNotification("Press E to collect: " .. name .. " [" .. tier .. "]", color, 5)
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

-- Initial update
if ClientState.PlayerData then
	updateGui(ClientState.PlayerData)
end
