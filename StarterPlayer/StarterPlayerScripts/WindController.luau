local RunService = game:GetService("RunService")

if not RunService:IsClient() then
	return
end

local WIND_DIRECTION = Vector3.new(1, 0, 0.3)
local WIND_SPEED = 20
local WIND_POWER = 0.5

local WindLines = require(script:WaitForChild("WindLines"))
local WindShake = require(script:WaitForChild("WindShake"))

local initialized = false
local windEnabled = script:GetAttribute("WindEnabled") == true

local function updateWindShakeSettings(speed, power, direction)
	WindShake:UpdateAllObjectSettings({
		Speed = speed,
		Power = power,
		Direction = direction,
		WindSpeed = speed,
		WindPower = power,
		WindDirection = direction,
	})
	WindShake:SetDefaultSettings({
		Speed = speed,
		Power = power,
		Direction = direction,
		WindSpeed = speed,
		WindPower = power,
		WindDirection = direction,
	})
end

local function applyWindState(enabled)
	if not initialized and enabled then
		WindLines:Init({
			Direction = WIND_DIRECTION,
			Speed = WIND_SPEED,
			Lifetime = 2,
			SpawnRate = 15,
		})

		updateWindShakeSettings(WIND_SPEED, WIND_POWER, WIND_DIRECTION)
		WindShake:Init()
		initialized = true
	end

	if not initialized then
		return
	end

	if enabled then
		WindLines.SpawnRate = 15
		WindLines.Speed = WIND_SPEED
		WindLines.Direction = WIND_DIRECTION
		updateWindShakeSettings(WIND_SPEED, WIND_POWER, WIND_DIRECTION)
	else
		WindLines.SpawnRate = 0
		WindLines.Speed = 0
		updateWindShakeSettings(0, 0, WIND_DIRECTION)
	end
end

script:GetAttributeChangedSignal("WindEnabled"):Connect(function()
	windEnabled = script:GetAttribute("WindEnabled") == true
	applyWindState(windEnabled)
end)

applyWindState(windEnabled)
