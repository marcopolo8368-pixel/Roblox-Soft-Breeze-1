--[[
    BadgeServer.lua
    Location: ServerScriptService

    Awards badges based on game events:
      1. First Join    — very first time a player ever joins the game
      2. Social        — first time a player gives rep to someone
      3. Explorer      — player touches the "AreaBadgeTrigger" part in workspace
      4. Generous Soul — player gives positive rep (thumbsUp or love) to 10 different people

    SETUP:
      1. Fill in the BADGE_IDS table below with real IDs from Creator Hub.
      2. For the Explorer badge: add a Part named "AreaBadgeTrigger" anywhere in your map
         (make it Transparent + CanCollide false so it's invisible to players).
         Place it in the area you want to reward reaching.
]]

local Players      = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

-- ============================================================
-- BADGE IDs — FILL THESE IN FROM CREATOR HUB
-- ============================================================
local BADGE_IDS = {
	FirstJoin    = 0,   -- "Welcome to the island" or similar
	Social       = 0,   -- "Social" — first rep given
	Explorer     = 0,   -- Area badge — reach a specific location
	GenerousSoul = 0,   -- "Generous Soul" — positive rep to 10 different people
	ShadyTier  = 0,   -- "Shady" — reach the Shady reputation tier
	Dedicated  = 0,   -- "Dedicated" — spend 1 hour in the game
}

-- ============================================================
-- HELPERS
-- ============================================================
local function awardBadge(player, badgeId, badgeName)
	if badgeId == 0 then
		return -- not configured yet
	end
	task.spawn(function()
		local ok, alreadyHas = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
		end)
		if not ok or alreadyHas then return end

		local success, err = pcall(function()
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if success then
			print("[BadgeServer] Awarded", badgeName, "to", player.Name)
		else
			warn("[BadgeServer] Failed to award", badgeName, ":", tostring(err))
		end
	end)
end

-- ============================================================
-- BADGE 1: FIRST JOIN
-- Triggered by ReputationServer when firstJoinTime is freshly stamped
-- ============================================================
_G.OnFirstJoin = function(player)
	awardBadge(player, BADGE_IDS.FirstJoin, "FirstJoin")
end

-- ============================================================
-- BADGE 2: SOCIAL (first rep given)
-- Triggered by ReputationServer after totalGiven goes 0 → 1
-- ============================================================
_G.OnFirstRepGiven = function(player)
	awardBadge(player, BADGE_IDS.Social, "Social")
end

-- ============================================================
-- BADGE 3: EXPLORER (reach a specific area)
-- Detected via a Part named "AreaBadgeTrigger" in workspace.
-- Add a transparent, non-collidable Part with that name to your map.
-- ============================================================
local function setupAreaBadge()
	-- Create the trigger part at the lamphouse area if it doesn't exist
	if not workspace:FindFirstChild("AreaBadgeTrigger") then
		local trigger = Instance.new("Part")
		trigger.Name = "AreaBadgeTrigger"
		trigger.Size = Vector3.new(80, 40, 80)
		trigger.Position = Vector3.new(1311.877, 19.495, -676.232)
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.Transparency = 1
		trigger.Parent = workspace
	end

	local trigger = workspace:FindFirstChild("AreaBadgeTrigger")
	if not trigger then
		task.spawn(function()
			local waited = 0
			while not workspace:FindFirstChild("AreaBadgeTrigger") and waited < 30 do
				task.wait(1)
				waited += 1
			end
			trigger = workspace:FindFirstChild("AreaBadgeTrigger")
			if trigger then
				connectAreaTrigger(trigger)
			else
				warn("[BadgeServer] 'AreaBadgeTrigger' part not found in workspace. Explorer badge inactive.")
			end
		end)
		return
	end
	connectAreaTrigger(trigger)
end

local awardedExplorer = {} -- [userId] = true (session cache to avoid repeat award calls)

function connectAreaTrigger(part)
	part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = Players:GetPlayerFromCharacter(character)
		if not player then return end
		if awardedExplorer[player.UserId] then return end
		awardedExplorer[player.UserId] = true
		awardBadge(player, BADGE_IDS.Explorer, "Explorer")
	end)
	print("[BadgeServer] Explorer badge trigger connected to part:", part:GetFullName())
end

Players.PlayerRemoving:Connect(function(player)
	awardedExplorer[player.UserId] = nil
end)

setupAreaBadge()

-- ============================================================
-- BADGE 4: GENEROUS SOUL (10 unique positive rep given)
-- Triggered by ReputationServer after the 10th unique positive target
-- ============================================================
_G.OnGenerousSoul = function(player)
	awardBadge(player, BADGE_IDS.GenerousSoul, "GenerousSoul")
end

-- ============================================================
-- BADGE 5: SHADY TIER (reach Shady tier at -10 rep)
-- Triggered by ReputationServer when score drops to -10
-- ============================================================
_G.OnShadyTierReached = function(player)
	awardBadge(player, BADGE_IDS.ShadyTier, "ShadyTier")
end

-- ============================================================
-- BADGE 6: DEDICATED (1 hour in-game)
-- Tracks time since join and awards after 3600 seconds
-- ============================================================
local dedicatedAwarded = {}

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		-- Wait 3600 seconds (1 hour)
		task.wait(3600)
		-- Check player is still in game
		if not player.Parent then return end
		if dedicatedAwarded[player.UserId] then return end
		dedicatedAwarded[player.UserId] = true
		awardBadge(player, BADGE_IDS.Dedicated, "Dedicated")
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	dedicatedAwarded[player.UserId] = nil
end)

print("[BadgeServer] Badge system initialized. Fill in BADGE_IDS to activate.")
