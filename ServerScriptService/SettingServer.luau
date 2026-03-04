local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

-- Create RemoteEvent FIRST (before any code that might fail)
local SettingsEvent = ReplicatedStorage:FindFirstChild("SettingsEvent")
if not SettingsEvent then
	SettingsEvent = Instance.new("RemoteEvent")
	SettingsEvent.Name = "SettingsEvent"
	SettingsEvent.Parent = ReplicatedStorage
end

-- Create folder for weather effects
local effectsFolder = Workspace:FindFirstChild("SettingsEffects")
if not effectsFolder then
	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "SettingsEffects"
	effectsFolder.Parent = Workspace
end

-- Store current settings (for new players joining)
local CurrentSettings = {}

-- Player Collision: CollisionGroupService exists in newer Roblox. Use pcall for compatibility.
local PhysicsService
local success, service = pcall(function()
	return game:GetService("PhysicsService")
end)
PhysicsService = success and service or nil

local function setupCollisionGroups()
	if not PhysicsService then return end
	pcall(function()
		PhysicsService:RegisterCollisionGroup("PlayersNormal")
		PhysicsService:RegisterCollisionGroup("PlayersNoCollide")
		PhysicsService:CollisionGroupSetCollidable("PlayersNormal", "PlayersNormal", true)
		PhysicsService:CollisionGroupSetCollidable("PlayersNoCollide", "PlayersNoCollide", false)
	end)
end
setupCollisionGroups()

local function setPlayerCollision(player, enabled)
	if not PhysicsService then return end
	local character = player.Character
	if not character then return end
	for _, part in pairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			PhysicsService:SetPartCollisionGroup(part, enabled and "PlayersNormal" or "PlayersNoCollide")
		end
	end
end

local function applyCollisionToAll(enabled)
	if not PhysicsService then return end
	for _, p in pairs(Players:GetPlayers()) do
		setPlayerCollision(p, enabled)
	end
end

if PhysicsService then
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if CurrentSettings["PlayerCollision"] == false then
				setPlayerCollision(player, false)
			end
		end)
	end)
	for _, player in pairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function()
			if CurrentSettings["PlayerCollision"] == false then
				setPlayerCollision(player, false)
			end
		end)
		if player.Character and CurrentSettings["PlayerCollision"] == false then
			setPlayerCollision(player, false)
		end
	end
end

-- Rain is now handled client-side via RainHandler in SettingsGui

-- Wind is now handled client-side via StarterPlayerScripts/WindController

-- Get or create ColorCorrection for black & white
local function getColorCorrection()
	local cc = Lighting:FindFirstChild("SettingsColorCorrection")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "SettingsColorCorrection"
		cc.Parent = Lighting
	end
	return cc
end

-- Get or create Music (use empty SoundId to avoid 404 - user sets real ID in SoundService)
local function getMusic()
	local music = SoundService:FindFirstChild("SettingsMusic")
	if not music then
		music = Instance.new("Sound")
		music.Name = "SettingsMusic"
		music.Volume = 0.5
		music.Looped = true
		music.SoundId = ""
		music.Parent = SoundService
	end
	return music
end

-- Apply a single setting
local function applySetting(name, value)
	CurrentSettings[name] = value

	if name == "Shadows" then
		Lighting.GlobalShadows = value

	elseif name == "DayNight" then
		Lighting.ClockTime = value and 14 or 0

	elseif name == "BlackWhite" then
		local cc = getColorCorrection()
		cc.Enabled = value
		cc.Saturation = value and -1 or 0

	elseif name == "Wind" then
		-- Wind handled client-side

	elseif name == "Fog" then
		if value then
			Lighting.FogEnd = 150
			Lighting.FogStart = 0
		else
			Lighting.FogEnd = 100000
			Lighting.FogStart = 100000
		end

	elseif name == "Music" then
		local music = getMusic()
		if value then
			if music.SoundId and music.SoundId ~= "" and music.SoundId ~= "rbxassetid://0" then
				music:Play()
			end
		else
			music:Stop()
		end

	elseif name == "PlayerCollision" then
		applyCollisionToAll(value)

	elseif name == "LabelEffects" then
		-- Handled per-player in the event handler below; nothing global here
	end
end

-- Receive settings from client
SettingsEvent.OnServerEvent:Connect(function(player, settingName, value)
	if type(settingName) ~= "string" or type(value) ~= "boolean" then return end

	-- LabelEffects is per-player (local only), not server-wide
	if settingName == "LabelEffects" then
		player:SetAttribute("LabelEffectsEnabled", value)
		return
	end

	local validSettings = {
		Shadows = true, DayNight = true, BlackWhite = true,
		Wind = true, Fog = true,
		Music = true, PlayerCollision = true,
	}
	if validSettings[settingName] then
		applySetting(settingName, value)
	end
end)

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("LabelEffectsEnabled", true)
end)

for _, player in pairs(Players:GetPlayers()) do
	if player:GetAttribute("LabelEffectsEnabled") == nil then
		player:SetAttribute("LabelEffectsEnabled", true)
	end
end

-- Send current settings to client when they request
local SettingsValuesEvent = ReplicatedStorage:FindFirstChild("SettingsValuesEvent")
if not SettingsValuesEvent then
	SettingsValuesEvent = Instance.new("RemoteFunction")
	SettingsValuesEvent.Name = "SettingsValuesEvent"
	SettingsValuesEvent.Parent = ReplicatedStorage
end
SettingsValuesEvent.OnServerInvoke = function(player)
	return CurrentSettings
end

-- Default settings
local defaults = {
	Shadows = true,
	DayNight = true,
	BlackWhite = false,
	Wind = true,
	Fog = false,
	Music = false,
	PlayerCollision = true,
	LabelEffects = true,
}
for k, v in pairs(defaults) do
	if CurrentSettings[k] == nil then
		applySetting(k, v)
	end
end

