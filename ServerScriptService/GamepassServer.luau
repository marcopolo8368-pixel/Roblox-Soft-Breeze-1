--[[
    GamepassServer.lua
    Location: ServerScriptService

    Handles all gamepass ownership checks and effects:
      - VIP:              [VIP] chat tag + instant +250 rep (one-time, on first purchase)
      - Rep Boost:        All rep RECEIVED is x2 (checked live in ReputationServer)
      - Card Customization: Unlocks full gradient color picker in profile card
      - Custom Title:     Lets player pick an animated gradient title for their overhead label

    SETUP:
      Fill in the GAMEPASS_IDS table below with your real gamepass IDs from Creator Hub.
      Everything else is automatic.
]]

local Players           = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================================================
-- GAMEPASS IDs — FILL THESE IN AFTER CREATING IN CREATOR HUB
-- ============================================================
local GAMEPASS_IDS = {
	VIP             = 1760183288,   -- [VIP] chat tag + 250 rep bonus
	RepBoost        = 1759481294,   -- All rep received x2
	CardCustomization = 1760699290, -- Full gradient card customization
	CustomTitle     = 1760843277,   -- Animated gradient overhead title
}

-- Available custom titles (pass-exclusive, animated gradient overhead)
-- Empty string ("") is also accepted to revert to the player's rep tier
local CUSTOM_TITLES = { "Legend", "Islander" }

-- DataStore: tracks whether the VIP +250 rep bonus was already granted (one-time)
local VipBonusStore = DataStoreService:GetDataStore("VipBonusGranted_v1")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CheckPassOwnershipFunc  = Remotes:WaitForChild("CheckPassOwnership")
local SetCustomTitleEvent     = Remotes:WaitForChild("SetCustomTitle")
local AdminSimulatePassEvent  = Remotes:WaitForChild("AdminSimulatePass")

-- ============================================================
-- OWNERSHIP CACHE
-- ============================================================
local passCache = {} -- [userId] = { VIP = bool, RepBoost = bool, ... }

local function checkOwns(userId, passId)
	if passId == 0 then return false end -- not configured yet
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(userId, passId)
	end)
	return ok and result == true
end

local function loadPassesForPlayer(player)
	local uid = player.UserId
	local cache = {
		VIP             = checkOwns(uid, GAMEPASS_IDS.VIP),
		RepBoost        = checkOwns(uid, GAMEPASS_IDS.RepBoost),
		CardCustomization = checkOwns(uid, GAMEPASS_IDS.CardCustomization),
		CustomTitle     = checkOwns(uid, GAMEPASS_IDS.CustomTitle),
	}
	passCache[uid] = cache

	-- Stamp player attributes so other scripts can read them cheaply
	player:SetAttribute("OwnsVIP",              cache.VIP)
	player:SetAttribute("OwnsRepBoost",          cache.RepBoost)
	player:SetAttribute("OwnsCardCustomization", cache.CardCustomization)
	player:SetAttribute("OwnsCustomTitle",       cache.CustomTitle)

	-- VIP: grant +250 rep one-time bonus if never granted before
	if cache.VIP then
		task.spawn(function()
			local key = "vipbonus_" .. tostring(uid)
			local ok, already = pcall(function()
				return VipBonusStore:GetAsync(key)
			end)
			if ok and not already then
				-- Wait for ReputationServer to expose GrantBonusRep
				local waited = 0
				while not _G.GrantBonusRep and waited < 15 do
					task.wait(0.5)
					waited += 0.5
				end
				if _G.GrantBonusRep then
					_G.GrantBonusRep(uid, 250)
					pcall(function()
						VipBonusStore:SetAsync(key, true)
					end)
					print("[GamepassServer] VIP bonus granted to", player.Name)
				end
			end
		end)
	end
end

-- ============================================================
-- PLAYER LIFECYCLE
-- ============================================================
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		loadPassesForPlayer(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	passCache[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadPassesForPlayer(player)
	end)
end

-- ============================================================
-- PURCHASE DETECTION
-- Updates attributes and grants VIP bonus immediately after purchase
-- ============================================================
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if not wasPurchased then return end
	local uid = player.UserId

	if passId == GAMEPASS_IDS.VIP then
		passCache[uid] = passCache[uid] or {}
		passCache[uid].VIP = true
		player:SetAttribute("OwnsVIP", true)
		-- Grant +250 rep bonus (one-time check handled inside)
		task.spawn(function()
			local key = "vipbonus_" .. tostring(uid)
			local ok, already = pcall(function() return VipBonusStore:GetAsync(key) end)
			if ok and not already and _G.GrantBonusRep then
				_G.GrantBonusRep(uid, 250)
				pcall(function() VipBonusStore:SetAsync(key, true) end)
				print("[GamepassServer] VIP bonus granted on purchase to", player.Name)
			end
		end)

	elseif passId == GAMEPASS_IDS.RepBoost then
		passCache[uid] = passCache[uid] or {}
		passCache[uid].RepBoost = true
		player:SetAttribute("OwnsRepBoost", true)

	elseif passId == GAMEPASS_IDS.CardCustomization then
		passCache[uid] = passCache[uid] or {}
		passCache[uid].CardCustomization = true
		player:SetAttribute("OwnsCardCustomization", true)

	elseif passId == GAMEPASS_IDS.CustomTitle then
		passCache[uid] = passCache[uid] or {}
		passCache[uid].CustomTitle = true
		player:SetAttribute("OwnsCustomTitle", true)
	end
end)

-- ============================================================
-- REMOTE: client asks server if they own a specific pass
-- Returns table: { VIP, RepBoost, CardCustomization, CustomTitle }
-- ============================================================
CheckPassOwnershipFunc.OnServerInvoke = function(player)
	local uid = player.UserId
	local cache = passCache[uid]
	if not cache then
		-- Not loaded yet — load synchronously (rare, usually ready by join)
		loadPassesForPlayer(player)
		cache = passCache[uid] or {}
	end
	return {
		VIP              = cache.VIP             == true,
		RepBoost         = cache.RepBoost        == true,
		CardCustomization = cache.CardCustomization == true,
		CustomTitle      = cache.CustomTitle     == true,
		titles           = CUSTOM_TITLES,
	}
end

-- ============================================================
-- REMOTE: player sets their custom title (Custom Title pass required)
-- ============================================================
SetCustomTitleEvent.OnServerEvent:Connect(function(player, chosenTitle)
	local uid = player.UserId
	local cache = passCache[uid]
	if not cache or not cache.CustomTitle then return end -- must own pass

	-- Empty string = "Use Tier" (revert to rep tier title)
	if chosenTitle == "" then
		player:SetAttribute("CustomTitle", "")
		print("[GamepassServer] Custom title cleared (Use Tier):", player.Name)
		return
	end

	-- Validate the chosen title is one of the allowed ones
	local valid = false
	for _, t in ipairs(CUSTOM_TITLES) do
		if t == chosenTitle then valid = true; break end
	end
	if not valid then return end

	-- Stamp on player so OverheadLabel + animator can read it
	player:SetAttribute("CustomTitle", chosenTitle)
	print("[GamepassServer] Custom title set:", player.Name, "->", chosenTitle)
end)

-- ============================================================
-- ADMIN: Simulate pass ownership for testing (game owner only)
-- ============================================================
local VALID_PASSES = { VIP = true, RepBoost = true, CardCustomization = true, CustomTitle = true }

local function isAdminPlayer(player)
	-- Accepts the game owner OR any player with IsAdmin attribute set server-side
	return player.UserId == game.CreatorId
		or player:GetAttribute("IsAdmin") == true
end

AdminSimulatePassEvent.OnServerEvent:Connect(function(player, passName, enabled)
	if not isAdminPlayer(player) then return end
	if not VALID_PASSES[passName] then return end

	local uid = player.UserId
	passCache[uid] = passCache[uid] or {}
	passCache[uid][passName] = (enabled == true)
	player:SetAttribute("Owns" .. passName, enabled == true)
	print("[GamepassServer] Admin simulated", passName, "=", tostring(enabled), "for", player.Name)
end)

print("[GamepassServer] Gamepass system initialized. Fill in GAMEPASS_IDS to activate.")
