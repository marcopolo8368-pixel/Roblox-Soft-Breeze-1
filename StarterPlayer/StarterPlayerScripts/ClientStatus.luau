--[[
    ClientStatus.lua
    Location: StarterPlayer / StarterPlayerScripts

    Detects whether the player is on PC, Mobile, or Console
    and reports it to the server via ReportPlatform remote
    so the overhead label can show the correct icon.
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReportPlatformEvent = Remotes:WaitForChild("ReportPlatform")

-- -------------------------------------------
-- PLATFORM DETECTION
-- -------------------------------------------
local function detectPlatform()
	-- Console check (Xbox, PlayStation)
	if GuiService:IsTenFootInterface() then
		return "Console"
	end

	-- Mobile check (touch-enabled, no mouse/keyboard)
	if UserInputService.TouchEnabled
		and not UserInputService.KeyboardEnabled
		and not UserInputService.MouseEnabled then
		return "Mobile"
	end

	-- Default to PC
	return "PC"
end

-- Report platform to server after a brief delay (let remotes load)
task.spawn(function()
	task.wait(1)
	local platform = detectPlatform()
	ReportPlatformEvent:FireServer(platform)
end)