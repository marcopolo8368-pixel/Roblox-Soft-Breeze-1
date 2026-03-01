--[[
    ProfileCardServer.lua
    Location: ServerScriptService
    
    Handles profile card data persistence using DataStoreService.
    Stores/loads player profile cards and relays data between players.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SaveProfileCardEvent = Remotes:WaitForChild("SaveProfileCard")
local RequestProfileCardFunc = Remotes:WaitForChild("RequestProfileCard")
local ProfileCardUpdatedEvent = Remotes:WaitForChild("ProfileCardUpdated")

-- DataStore
local ProfileStore = DataStoreService:GetDataStore("PlayerProfileCards_v1")

-- -------------------------------------------
-- IN-MEMORY CACHE
-- -------------------------------------------
local profileCache = {} -- [userId] = profileData

local DEFAULT_PROFILE = {
	displayName = "",
	bio = "Hey, I'm chilling here! ??",
	mood = "Chill",
	quote = "",
	favoriteColor = { 138, 100, 214 },     -- Purple accent
	bgGradientStart = { 20, 20, 35 },       -- Dark navy
	bgGradientEnd = { 40, 30, 60 },          -- Deep purple
	cardStyle = "default",
}

-- -------------------------------------------
-- LOAD / SAVE
-- -------------------------------------------
local function loadProfile(player)
	local userId = tostring(player.UserId)
	local success, data = pcall(function()
		return ProfileStore:GetAsync("profile_" .. userId)
	end)

	if success and data then
		profileCache[player.UserId] = data
	else
		-- Create default profile
		local defaultData = table.clone(DEFAULT_PROFILE)
		defaultData.displayName = player.DisplayName
		profileCache[player.UserId] = defaultData
	end

	return profileCache[player.UserId]
end

local function saveProfile(player)
	local userId = tostring(player.UserId)
	local data = profileCache[player.UserId]
	if not data then return end

	local success, err = pcall(function()
		ProfileStore:SetAsync("profile_" .. userId, data)
	end)

	if not success then
		warn("[ProfileCardServer] Failed to save profile for " .. player.Name .. ": " .. tostring(err))
	end
end

-- -------------------------------------------
-- EVENTS
-- -------------------------------------------

-- Player joins: load their profile
Players.PlayerAdded:Connect(function(player)
	loadProfile(player)
end)

-- Player leaves: save their profile
Players.PlayerRemoving:Connect(function(player)
	saveProfile(player)
	-- Don't remove from cache immediately (other players might still be viewing)
	task.delay(30, function()
		profileCache[player.UserId] = nil
	end)
end)

-- Save profile card data from client
SaveProfileCardEvent.OnServerEvent:Connect(function(player, profileData)
	-- Validate incoming data
	if type(profileData) ~= "table" then return end

	-- Sanitize fields
	local sanitized = {
		displayName = type(profileData.displayName) == "string" 
			and string.sub(profileData.displayName, 1, 30) or player.DisplayName,
		bio = type(profileData.bio) == "string" 
			and string.sub(profileData.bio, 1, 100) or "",
		mood = type(profileData.mood) == "string" 
			and string.sub(profileData.mood, 1, 20) or "Chill",
		quote = type(profileData.quote) == "string" 
			and string.sub(profileData.quote, 1, 60) or "",
		favoriteColor = type(profileData.favoriteColor) == "table" 
			and profileData.favoriteColor or { 138, 100, 214 },
		bgGradientStart = type(profileData.bgGradientStart) == "table" 
			and profileData.bgGradientStart or { 20, 20, 35 },
		bgGradientEnd = type(profileData.bgGradientEnd) == "table" 
			and profileData.bgGradientEnd or { 40, 30, 60 },
		cardStyle = type(profileData.cardStyle) == "string" 
			and profileData.cardStyle or "default",
	}

	profileCache[player.UserId] = sanitized

	-- Notify all other players that this player's card updated
	ProfileCardUpdatedEvent:FireAllClients(player.UserId, sanitized)

	-- Save to DataStore (async, don't block)
	task.spawn(function()
		saveProfile(player)
	end)
end)

-- Request another player's profile card
RequestProfileCardFunc.OnServerInvoke = function(requestingPlayer, targetUserId)
	if type(targetUserId) ~= "number" then return nil end

	local data = profileCache[targetUserId]
	if data then
		return data
	end

	-- Try to load from DataStore if not in cache
	local success, storedData = pcall(function()
		return ProfileStore:GetAsync("profile_" .. tostring(targetUserId))
	end)

	if success and storedData then
		profileCache[targetUserId] = storedData
		return storedData
	end

	return nil
end

-- Load profiles for players already in game (in case script loads late)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadProfile(player)
	end)
end

print("[ProfileCardServer] Profile card server initialized.")
