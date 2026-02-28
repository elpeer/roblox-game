--[[
	Workspace init - Sets up basic world properties
]]

local Lighting = game:GetService("Lighting")

-- Sky settings
Lighting.ClockTime = 14 -- Afternoon lighting
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(40, 40, 60)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 80, 100)
Lighting.FogEnd = 10000

-- Create sky
local sky = Instance.new("Sky")
sky.SkyboxBk = "rbxassetid://1012890"
sky.SkyboxDn = "rbxassetid://1012891"
sky.SkyboxFt = "rbxassetid://1012887"
sky.SkyboxLf = "rbxassetid://1012889"
sky.SkyboxRt = "rbxassetid://1012886"
sky.SkyboxUp = "rbxassetid://1012888"
sky.Parent = Lighting

-- Atmosphere
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.25
atmosphere.Color = Color3.fromRGB(199, 199, 199)
atmosphere.Decay = Color3.fromRGB(92, 60, 13)
atmosphere.Glare = 0
atmosphere.Haze = 1
atmosphere.Parent = Lighting

-- Remove default baseplate if exists
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then
	baseplate:Destroy()
end

-- Create a void (no floor - players rely on their bases)
-- The only ground is the player bases created by GameManager
