local TreadmillData = {}

TreadmillData.Treadmills = {
	{
		name = "Basic Treadmill",
		price = 0,
		speedPerClick = 1,
		color = Color3.fromRGB(150, 150, 150),
		order = 1,
	},
	{
		name = "Fast Treadmill",
		price = 100,
		speedPerClick = 3,
		color = Color3.fromRGB(50, 150, 255),
		order = 2,
	},
	{
		name = "Super Treadmill",
		price = 500,
		speedPerClick = 8,
		color = Color3.fromRGB(163, 53, 238),
		order = 3,
	},
	{
		name = "Ultra Treadmill",
		price = 2000,
		speedPerClick = 20,
		color = Color3.fromRGB(255, 215, 0),
		order = 4,
	},
	{
		name = "Mega Treadmill",
		price = 10000,
		speedPerClick = 50,
		color = Color3.fromRGB(255, 50, 50),
		order = 5,
	},
}

function TreadmillData.GetByName(name: string)
	for _, treadmill in ipairs(TreadmillData.Treadmills) do
		if treadmill.name == name then
			return treadmill
		end
	end
	return nil
end

function TreadmillData.GetNextTreadmill(currentName: string)
	local currentOrder = 0
	for _, treadmill in ipairs(TreadmillData.Treadmills) do
		if treadmill.name == currentName then
			currentOrder = treadmill.order
			break
		end
	end
	for _, treadmill in ipairs(TreadmillData.Treadmills) do
		if treadmill.order == currentOrder + 1 then
			return treadmill
		end
	end
	return nil
end

return TreadmillData
