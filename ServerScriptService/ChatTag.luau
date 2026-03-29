--[[
    ChatTags.lua
    Location: ServerScriptService (Script)

    Adds a colored rank tag in front of each player's name in chat.
    e.g.  [CEL] PlayerName: hello

    Uses the TextChatService (modern Roblox chat).
    Works alongside ReputationServer — reads rep via _G globals
    and updates whenever a player's tier changes.

    Exposes GetChatTag RemoteFunction so client can query tag data.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetChatTagFunc = Remotes:WaitForChild("GetChatTag")

-- Match these exactly to ReputationServer TIERS
local TIERS = {
	{ min = -10,  title = "Shady",       color = Color3.fromRGB(220, 90,  105) },
	{ min = 0,    title = "Visitor",     color = Color3.fromRGB(170, 155, 210) },
	{ min = 25,   title = "Rising",      color = Color3.fromRGB(120, 190, 255) },
	{ min = 100,  title = "Famous",      color = Color3.fromRGB(255, 210, 120) },
	{ min = 250,  title = "Trendsetter", color = Color3.fromRGB(215, 170, 255) },
	{ min = 500,  title = "Influencer",  color = Color3.fromRGB(255, 160, 235) },
	{ min = 1000, title = "Celebrity",   color = Color3.fromRGB(255, 225, 90)  },
}

local function getTierInfo(score)
	local info = TIERS[1]
	for _, tier in ipairs(TIERS) do
		if score >= tier.min then
			info = tier
		end
	end
	return info
end

local function colorToHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
end

-- Cache of userId -> { title, hex }
local playerTags = {}

local function getTag(userId)
	return playerTags[userId] or { title = "Visitor", hex = "#AAA0D2" }
end

local function setTag(userId, score)
	local tier = getTierInfo(score)
	playerTags[userId] = {
		title = tier.title,
		hex   = colorToHex(tier.color),
	}
end

-- -- SERVER: store tag when player joins + when rep updates ------------------

Players.PlayerAdded:Connect(function(player)
	-- Wait for rep to be ready
	local waited = 0
	while not (_G.IsRepReadyForPlayer and _G.IsRepReadyForPlayer(player.UserId)) do
		task.wait(0.5)
		waited += 0.5
		if waited >= 10 then break end
	end

	-- Get initial score from cache
	if _G.GetRepDataForLeaderboard then
		local data = _G.GetRepDataForLeaderboard(player.UserId)
		setTag(player.UserId, data and data.score or 0)
	else
		setTag(player.UserId, 0)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerTags[player.UserId] = nil
end)

-- Also handle players already in game (in case this script loads after some join)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local waited = 0
		while not (_G.IsRepReadyForPlayer and _G.IsRepReadyForPlayer(p.UserId)) do
			task.wait(0.5)
			waited += 0.5
			if waited >= 10 then break end
		end
		if _G.GetRepDataForLeaderboard then
			local data = _G.GetRepDataForLeaderboard(p.UserId)
			setTag(p.UserId, data and data.score or 0)
		else
			setTag(p.UserId, 0)
		end
	end)
end

-- Expose tag lookup globally (for other server scripts if needed)
_G.GetChatTagForUser = function(userId)
	return getTag(userId)
end

-- ============================================================
-- REMOTE: Client asks for a player's chat tag
-- Returns { title, hex, isVip }
-- ============================================================
GetChatTagFunc.OnServerInvoke = function(requestingPlayer, targetUserId)
	-- If no targetUserId provided, use the requesting player's own ID
	local uid = targetUserId or requestingPlayer.UserId
	local tag = getTag(uid)

	-- Check VIP ownership (wait briefly if attribute hasn't been stamped yet)
	local targetPlayer = Players:GetPlayerByUserId(uid)
	local isVip = false
	if targetPlayer then
		if targetPlayer:GetAttribute("OwnsVIP") == nil then
			local waited = 0
			while targetPlayer:GetAttribute("OwnsVIP") == nil and waited < 5 do
				task.wait(0.5)
				waited += 0.5
			end
		end
		isVip = targetPlayer:GetAttribute("OwnsVIP") == true
	end

	return {
		title = tag.title,
		hex   = tag.hex,
		isVip = isVip,
	}
end

-- ============================================================
-- Listen for rep score changes to update tags in real-time
-- We use a polling approach via _G since ReputationUpdated is
-- a server->client event, not usable server-to-server.
-- Instead, we hook into _G.OnRepChanged if available, or
-- just refresh periodically.
-- ============================================================

-- Hook: ReputationServer can call _G.OnRepScoreChanged(userId, newScore)
_G.OnRepScoreChanged = function(userId, newScore)
	if type(newScore) == "number" then
		setTag(userId, newScore)
	end
end

print("[ChatTags] Chat tag server initialized.")
