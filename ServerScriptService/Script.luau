local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local ENABLE_LEGACY_CYCLE = script:GetAttribute("EnableLegacyCycle") == true
if not ENABLE_LEGACY_CYCLE then
	return
end

local timeStep = 0.003
local timeChange = 0.003

while true do
	if not RunService:IsRunning() then
		task.wait(0.5)
	else
		Lighting.ClockTime = Lighting.ClockTime + timeChange
		task.wait(timeStep)
	end
end