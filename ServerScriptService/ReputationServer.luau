--[[
    ReputationServer.lua
    Location: ServerScriptService

    Authoritative reputation backend:
    - Vote actions: thumbsUp(+1), thumbsDown(-1), love(+2)
    - Cooldown: 1 vote per target per 24h
    - Title tiers from score thresholds
    - DataStore persistence
    - Pushes updates to profile UI + overhead nametag
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local DEBUG_REP_LOGS = true

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GiveReputationEvent = Remotes:WaitForChild("GiveReputation")
local RequestReputationFunc = Remotes:WaitForChild("RequestReputation")
local ReputationUpdatedEvent = Remotes:WaitForChild("ReputationUpdated")
local RequestRepCooldownFunc = Remotes:WaitForChild("RequestRepCooldown")
local RequestLeaderboardFunc = Remotes:WaitForChild("RequestLeaderboard")
local AdminRepEvent = Remotes:WaitForChild("AdminRepEvent")
local AdminRepResponse = Remotes:WaitForChild("AdminRepResponse")
local AdminRepCanUse = Remotes:WaitForChild("AdminRepCanUse")

local RepStore = DataStoreService:GetDataStore("PlayerReputation_v1")

local function dlog(...)
	if DEBUG_REP_LOGS then
		print("[ReputationServerDBG]", ...)
	end
end

-- Forward declarations (defined further below)
local fireRepSubscribers

local COOLDOWN_SECONDS = 24 * 60 * 60
local cooldownsEnabled = true  -- admin can toggle this off server-wide
local ACTION_VALUES = {
	thumbsUp = 1,
	thumbsDown = -1,
	love = 2,
}

local REACTION_TEXTURES = {
	thumbsUp = "rbxassetid://91121509552328",
	thumbsDown = "rbxassetid://132991258217907",
	love = "rbxassetid://78729481165822",
}

local TIERS = {
	{ min = -10, title = "Shady", color = { 220, 90, 105 } },
	{ min = 0, title = "Visitor", color = { 170, 155, 210 } },
	{ min = 25, title = "Rising", color = { 120, 190, 255 } },
	{ min = 100, title = "Famous", color = { 255, 210, 120 } },
	{ min = 250, title = "Trendsetter", color = { 215, 170, 255 } },
	{ min = 500, title = "Influencer", color = { 255, 160, 235 } },
	{ min = 1000, title = "Celebrity", color = { 255, 225, 90 } },
}

local DEFAULT_REP = {
	score = 0,
	totalGiven = 0,
	totalReceived = 0,
	cooldownByTarget = {},
	firstJoinTime = 0,       -- unix timestamp of very first join (0 = not set)
	generousTargets = {},    -- tracks unique targets who received positive rep (for badge)
}

local repCache = {} -- [userId] = rep data
local dirtyRepUsers = {} -- [userId] = true
local pendingSaveTasks = {} -- [userId] = true

local SAVE_DEBOUNCE_SECONDS = 8
local SAVE_SCAN_INTERVAL_SECONDS = 30

-- -- ADMIN LIST ---------------------------------------------------------------
local ADMIN_IDS = {
	[6163688260] = true,        -- ? replace with your UserId
	-- [987654321] = true, -- add more admins like this
}

local function cloneDefaultRep()
	return {
		score = DEFAULT_REP.score,
		totalGiven = DEFAULT_REP.totalGiven,
		totalReceived = DEFAULT_REP.totalReceived,
		cooldownByTarget = {},
		firstJoinTime = 0,
		generousTargets = {},
	}
end

local function getTierIndex(score)
	local idx = 1
	for i, tier in ipairs(TIERS) do
		if score >= tier.min then
			idx = i
		end
	end
	return idx
end

local function getTierInfo(score)
	local idx = getTierIndex(score)
	local tier = TIERS[idx]
	local prevThreshold = tier.min
	local nextTier = TIERS[idx + 1]
	local nextThreshold = nextTier and nextTier.min or tier.min

	return {
		index = idx,
		title = tier.title,
		tierColor = tier.color,
		prevThreshold = prevThreshold,
		nextThreshold = nextThreshold,
	}
end

local function pruneCooldowns(repData)
	local now = os.time()
	local map = repData.cooldownByTarget or {}
	for targetId, expiresAt in pairs(map) do
		if type(expiresAt) ~= "number" or expiresAt <= now then
			map[targetId] = nil
		end
	end
	repData.cooldownByTarget = map
end

local function sanitizeLoadedData(data)
	if type(data) ~= "table" then
		return cloneDefaultRep()
	end

	local sanitized = cloneDefaultRep()
	sanitized.score = tonumber(data.score) or 0
	sanitized.totalGiven = math.max(0, tonumber(data.totalGiven) or 0)
	sanitized.totalReceived = math.max(0, tonumber(data.totalReceived) or 0)

	if type(data.cooldownByTarget) == "table" then
		sanitized.cooldownByTarget = {}
		for k, v in pairs(data.cooldownByTarget) do
			local key = tostring(k)
			local expiresAt = tonumber(v)
			if expiresAt then
				sanitized.cooldownByTarget[key] = expiresAt
			end
		end
	end

	sanitized.firstJoinTime = tonumber(data.firstJoinTime) or 0

	if type(data.generousTargets) == "table" then
		sanitized.generousTargets = {}
		for k in pairs(data.generousTargets) do
			sanitized.generousTargets[tostring(k)] = true
		end
	end

	pruneCooldowns(sanitized)
	return sanitized
end

local function buildRepPayload(userId, repData)
	local tierInfo = getTierInfo(repData.score)
	return {
		userId = userId,
		score = repData.score,
		title = tierInfo.title,
		tierColor = tierInfo.tierColor,
		prevThreshold = tierInfo.prevThreshold,
		nextThreshold = tierInfo.nextThreshold,
	}
end

local loadRepForUserId

local function getCachedOrDefault(userId)
	if not repCache[userId] then
		loadRepForUserId(userId)
		if not repCache[userId] then
			repCache[userId] = cloneDefaultRep()
		end
	end
	return repCache[userId]
end

loadRepForUserId = function(userId)
	local key = "rep_" .. tostring(userId)
	local success, data = pcall(function()
		return RepStore:GetAsync(key)
	end)

	if success then
		repCache[userId] = sanitizeLoadedData(data)
	else
		warn("[ReputationServer] Failed loading rep for userId " .. tostring(userId))
		repCache[userId] = cloneDefaultRep()
	end

	return repCache[userId]
end

local function saveRepForUserId(userId)
	local data = repCache[userId]
	if not data then return false end

	pruneCooldowns(data)
	local key = "rep_" .. tostring(userId)
	local success, err = pcall(function()
		RepStore:SetAsync(key, data)
	end)

	if not success then
		warn("[ReputationServer] Failed saving rep for userId " .. tostring(userId) .. ": " .. tostring(err))
		return false
	end

	return true
end

local function saveRepNow(userId)
	if not userId then return end
	pendingSaveTasks[userId] = nil
	if not dirtyRepUsers[userId] then return end
	if saveRepForUserId(userId) then
		dirtyRepUsers[userId] = nil
	else
		dirtyRepUsers[userId] = true
	end
end

local function markRepDirty(userId, saveDelaySeconds)
	if not userId then return end
	dirtyRepUsers[userId] = true

	if pendingSaveTasks[userId] then
		return
	end

	pendingSaveTasks[userId] = true
	local delaySeconds = math.max(0, tonumber(saveDelaySeconds) or SAVE_DEBOUNCE_SECONDS)
	task.delay(delaySeconds, function()
		saveRepNow(userId)
	end)
end

local function loadRepForPlayer(player)
	local repData = loadRepForUserId(player.UserId)

	-- First-ever join: stamp the time and signal badge server
	if repData.firstJoinTime == 0 then
		repData.firstJoinTime = os.time()
		markRepDirty(player.UserId)
		task.spawn(function()
			task.wait(1) -- give BadgeServer a moment to register its callback
			if _G.OnFirstJoin then
				_G.OnFirstJoin(player)
			end
		end)
	end

	local payload = buildRepPayload(player.UserId, repData)
	if _G.FireRepUpdateForNametag then
		_G.FireRepUpdateForNametag(payload)
	end
end

local function getRepDataForUserId(userId)
	if type(userId) ~= "number" then return nil end
	local repData = repCache[userId] or loadRepForUserId(userId)
	if not repData then return nil end
	return buildRepPayload(userId, repData)
end

_G.GetRepDataForPlayer = function(userId)
	return getRepDataForUserId(userId)
end

local function getCooldownRemaining(voterUserId, targetUserId)
	local voterData = getCachedOrDefault(voterUserId)
	pruneCooldowns(voterData)
	local expiresAt = voterData.cooldownByTarget[tostring(targetUserId)]
	if not expiresAt then
		return 0
	end
	return math.max(0, expiresAt - os.time())
end

local function fireVoteResult(player, result)
	result.kind = "voteResult"
	ReputationUpdatedEvent:FireClient(player, result)
end

local function pushRepUpdate(userId, repData, titleUpgraded)
	local payload = buildRepPayload(userId, repData)
	payload.titleUpgraded = titleUpgraded == true
	dlog("pushRepUpdate", "userId=", userId, "score=", payload.score, "title=", payload.title, "titleUpgraded=", payload.titleUpgraded)

	ReputationUpdatedEvent:FireAllClients(payload)
	if _G.FireRepUpdateForNametag then
		dlog("firing nametag update", userId)
		_G.FireRepUpdateForNametag(payload)
	else
		dlog("nametag update skipped: _G.FireRepUpdateForNametag missing")
	end
	-- Update chat tag when rep changes
	if _G.OnRepScoreChanged then
		_G.OnRepScoreChanged(userId, repData.score)
	end
	fireRepSubscribers(userId, repData.score)
end

local function playTitleParticleBurst(player, tierColor)
	local character = player.Character
	if not character then return end
	local head = character:FindFirstChild("Head")
	if not head then return end

	local attachment = Instance.new("Attachment")
	attachment.Name = "RepTierBurst"
	attachment.Parent = head

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://243660364"
	emitter.Color = ColorSequence.new(Color3.fromRGB(tierColor[1], tierColor[2], tierColor[3]), Color3.new(1, 1, 1))
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(4, 8)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Enabled = true
	emitter.Parent = attachment

	-- :Emit() does NOT replicate to clients; use brief high Rate instead
	emitter.Rate = 140
	task.delay(0.2, function()
		if emitter and emitter.Parent then
			emitter.Rate = 0
			emitter.Enabled = false
		end
	end)
	Debris:AddItem(attachment, 2)
end

-- playReactionBurst removed: OverheadLabel owns all reaction visuals
-- via _G.FireRepReactionForNametag to avoid race-condition double-destroy

GiveReputationEvent.OnServerEvent:Connect(function(voter, targetUserId, action)
	if type(targetUserId) ~= "number" then
		fireVoteResult(voter, {
			ok = false,
			reason = "Invalid target",
		})
		return
	end

	if voter.UserId == targetUserId and not IS_STUDIO then
		fireVoteResult(voter, {
			ok = false,
			reason = "You can't rep yourself",
		})
		return
	end

	local delta = ACTION_VALUES[action]
	if not delta then
		fireVoteResult(voter, {
			ok = false,
			reason = "Invalid action",
		})
		return
	end

	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		fireVoteResult(voter, {
			ok = false,
			reason = "Player left",
		})
		return
	end

	local remaining = getCooldownRemaining(voter.UserId, targetUserId)
	if remaining > 0 and cooldownsEnabled and not IS_STUDIO then
		fireVoteResult(voter, {
			ok = false,
			reason = "Cooldown active",
			remainingSeconds = remaining,
		})
		return
	end

	-- REP SHIELD: silently block thumbsDown for the first 30 minutes of a new player's life
	if action == "thumbsDown" then
		local shieldData = getCachedOrDefault(targetUserId)
		local firstJoin = shieldData.firstJoinTime or 0
		if firstJoin > 0 and (os.time() - firstJoin) < 1800 then
			fireVoteResult(voter, { ok = false }) -- silent: no reason shown
			return
		end
	end

	local voterData = getCachedOrDefault(voter.UserId)
	local targetData = getCachedOrDefault(targetUserId)
	pruneCooldowns(voterData)

	-- REP BOOST: double positive rep if target owns the RepBoost gamepass
	if delta > 0 and targetPlayer:GetAttribute("OwnsRepBoost") then
		delta = delta * 2
	end

	local beforeTier = getTierIndex(targetData.score)
	targetData.score += delta
	targetData.totalReceived += 1
	local isFirstRepGiven = voterData.totalGiven == 0
	voterData.totalGiven += 1
	voterData.cooldownByTarget[tostring(targetUserId)] = os.time() + COOLDOWN_SECONDS

	-- BADGE: first rep given
	if isFirstRepGiven and _G.OnFirstRepGiven then
		task.spawn(_G.OnFirstRepGiven, voter)
	end

	-- BADGE: Shady tier reached
	if targetData.score <= -10 and (targetData.score - delta) > -10 then
		local targetPlayer = Players:GetPlayerByUserId(targetUserId)
		if targetPlayer and _G.OnShadyTierReached then
			task.spawn(_G.OnShadyTierReached, targetPlayer)
		end
	end

	-- BADGE: Generous Soul — track unique targets who received positive rep
	if action == "thumbsUp" or action == "love" then
		local gt = voterData.generousTargets
		local targetKey = tostring(targetUserId)
		if not gt[targetKey] then
			local count = 0
			for _ in pairs(gt) do count += 1 end
			if count < 10 then
				gt[targetKey] = true
				count += 1
				if count >= 10 and _G.OnGenerousSoul then
					task.spawn(_G.OnGenerousSoul, voter)
				end
			end
		end
	end

	local afterTier = getTierIndex(targetData.score)
	local titleUpgraded = afterTier > beforeTier

	pushRepUpdate(targetUserId, targetData, titleUpgraded)
	if titleUpgraded then
		local payload = buildRepPayload(targetUserId, targetData)
		playTitleParticleBurst(targetPlayer, payload.tierColor)
	end

	fireVoteResult(voter, {
		ok = true,
		action = action,
		delta = delta,
		targetUserId = targetUserId,
		remainingSeconds = COOLDOWN_SECONDS,
		titleUpgraded = titleUpgraded,
	})

	ReputationUpdatedEvent:FireClient(targetPlayer, {
		kind = "receivedRep",
		fromUserId = voter.UserId,
		action = action,
		delta = delta,
		score = targetData.score,
		titleUpgraded = titleUpgraded,
	})

	if _G.FireRepReactionForNametag then
		dlog("firing reaction aura", action, "for", targetUserId)
		_G.FireRepReactionForNametag(targetUserId, action)
	else
		warn("[ReputationServer] _G.FireRepReactionForNametag not ready � reaction skipped")
	end

	task.spawn(function()
		markRepDirty(voter.UserId)
		markRepDirty(targetUserId)
	end)
end)

RequestReputationFunc.OnServerInvoke = function(_, targetUserId)
	if type(targetUserId) ~= "number" then return nil end
	return getRepDataForUserId(targetUserId)
end

RequestRepCooldownFunc.OnServerInvoke = function(voter, targetUserId)
	if type(targetUserId) ~= "number" then
		return { canVote = false, remainingSeconds = 0 }
	end

	if voter.UserId == targetUserId then
		return { canVote = false, remainingSeconds = 0, self = true }
	end

	local remaining = getCooldownRemaining(voter.UserId, targetUserId)
	local cooldownActive = cooldownsEnabled and not IS_STUDIO
	return {
		canVote = (not cooldownActive) or remaining <= 0,
		remainingSeconds = cooldownActive and remaining or 0,
	}
end

RequestLeaderboardFunc.OnServerInvoke = function()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local repData = getCachedOrDefault(player.UserId)
		table.insert(rows, {
			userId = player.UserId,
			name = player.DisplayName,
			score = repData.score,
		})
	end

	table.sort(rows, function(a, b)
		return a.score > b.score
	end)

	return rows
end

-- Track which players have had their rep fully loaded
local repReadyPlayers = {}
_G.IsRepReadyForPlayer = function(userId)
	return repReadyPlayers[userId] == true
end

Players.PlayerAdded:Connect(function(player)
	loadRepForPlayer(player)
	repReadyPlayers[player.UserId] = true
	-- Re-fire the update now that we know OverheadLabel may be listening
	local repData = repCache[player.UserId]
	if repData and _G.FireRepUpdateForNametag then
		dlog("PlayerAdded refire", player.Name, player.UserId)
		_G.FireRepUpdateForNametag(buildRepPayload(player.UserId, repData))
	else
		dlog("PlayerAdded refire skipped", player.Name, "hasRepData=", repData ~= nil, "hasNametagFn=", _G.FireRepUpdateForNametag ~= nil)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	repReadyPlayers[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(SAVE_SCAN_INTERVAL_SECONDS)
		for userId in pairs(dirtyRepUsers) do
			if not pendingSaveTasks[userId] then
				saveRepNow(userId)
			end
		end
	end
end)


Players.PlayerRemoving:Connect(function(player)
	saveRepNow(player.UserId)
	task.delay(45, function()
		repCache[player.UserId] = nil
		dirtyRepUsers[player.UserId] = nil
		pendingSaveTasks[player.UserId] = nil
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadRepForPlayer(player)
	end)
end

print("[ReputationServer] Reputation backend initialized.")

AdminRepCanUse.OnServerInvoke = function(requester)
	return requester and ADMIN_IDS[requester.UserId] == true or false
end

-- -- HANDLER ------------------------------------------------------------------
AdminRepEvent.OnServerEvent:Connect(function(admin, payload)

	-- Hard security check � reject anyone not in the list
	if not ADMIN_IDS[admin.UserId] then
		warn("[AdminRep] Unauthorized request from " .. admin.Name .. " (" .. admin.UserId .. ")")
		AdminRepResponse:FireClient(admin, { ok = false, msg = "Admin only" })
		return
	end

	if type(payload) ~= "table" then
		AdminRepResponse:FireClient(admin, { ok = false, msg = "Bad payload" })
		return
	end

	local action       = payload.action
	local targetUserId = tonumber(payload.targetUserId)
	local value        = tonumber(payload.value)

	local targetPlayer = targetUserId and Players:GetPlayerByUserId(targetUserId)

	-- toggleCooldowns is a server-wide toggle, handle it early
	if action == "toggleCooldowns" then
		cooldownsEnabled = not cooldownsEnabled
		AdminRepResponse:FireClient(admin, {
			ok = true,
			kind = "cooldownToggle",
			cooldownsEnabled = cooldownsEnabled,
			msg = "Cooldowns " .. (cooldownsEnabled and "enabled" or "disabled") .. " for this server.",
		})
		print("[AdminRep] " .. admin.Name .. " toggled cooldowns: " .. tostring(cooldownsEnabled))
		return
	end

	-- getCooldownState returns current toggle value
	if action == "getCooldownState" then
		AdminRepResponse:FireClient(admin, {
			ok = true,
			kind = "cooldownToggle",
			cooldownsEnabled = cooldownsEnabled,
		})
		return
	end

	if not targetPlayer then
		AdminRepResponse:FireClient(admin, { ok = false, msg = "Player not in server" })
		return
	end

	local data = getCachedOrDefault(targetUserId)
	local beforeTier = getTierIndex(data.score)
	local newScore

	if action == "set" then
		if not value then
			AdminRepResponse:FireClient(admin, { ok = false, msg = "No value given" })
			return
		end
		newScore = math.clamp(math.floor(value), -9999, 99999)

	elseif action == "add" then
		if not value then
			AdminRepResponse:FireClient(admin, { ok = false, msg = "No value given" })
			return
		end
		newScore = math.clamp(math.floor(data.score + value), -9999, 99999)

	elseif action == "reset" then
		newScore = 0

	else
		AdminRepResponse:FireClient(admin, { ok = false, msg = "Unknown action" })
		return
	end

	-- Apply the change
	local oldScore = data.score
	data.score = newScore

	local afterTier     = getTierIndex(newScore)
	local tierUpgraded  = afterTier > beforeTier

	-- Push live update to nametag + all clients
	pushRepUpdate(targetUserId, data, tierUpgraded)

	-- Save to DataStore
	task.spawn(function()
		markRepDirty(targetUserId, 0)
	end)

	-- Fire burst effect if tier upgraded
	if tierUpgraded then
		local burstPayload = buildRepPayload(targetUserId, data)
		playTitleParticleBurst(targetPlayer, burstPayload.tierColor)
	end

	-- Reply to admin
	local newTitle = buildRepPayload(targetUserId, data).title
	AdminRepResponse:FireClient(admin, {
		ok  = true,
		msg = targetPlayer.DisplayName .. ": " .. oldScore .. " ? " .. newScore .. "  (" .. newTitle .. ")",
	})

	print("[AdminRep] " .. admin.Name .. " set " .. targetPlayer.Name .. " rep: " .. oldScore .. " ? " .. newScore)
end)

--[[
    ReputationServer PATCH v2  (FIXED)
    ==================================
    REPLACE your previous patch block at the bottom of ReputationServer.lua
    with this one entirely.

    Fixes:
      - Shady tier now correctly matches scores below 0
      - Adds _G.SubscribeToRepUpdates so LeaderStats updates live
      - Keeps GetRepDataForLeaderboard and GetChatTag working
]]

-- -- Expose rep cache for LeaderStats ----------------------------------------
_G.GetRepDataForLeaderboard = function(userId)
	return repCache[userId]
end

-- -- Live update subscriptions for LeaderStats -------------------------------
local repSubscribers = {} -- [userId] = { callback, ... }

_G.SubscribeToRepUpdates = function(userId, callback)
	if not repSubscribers[userId] then
		repSubscribers[userId] = {}
	end
	table.insert(repSubscribers[userId], callback)
end

-- Fill forward declaration from top of file
fireRepSubscribers = function(userId, score)
	local subs = repSubscribers[userId]
	if not subs then return end
	for _, cb in ipairs(subs) do
		task.spawn(cb, score)
	end
end

-- -- GetChatTag remote --------------------------------------------------------
local GetChatTag = Remotes:FindFirstChild("GetChatTag")
if not GetChatTag then
	GetChatTag = Instance.new("RemoteFunction")
	GetChatTag.Name = "GetChatTag"
	GetChatTag.Parent = Remotes
end

-- FIXED: use -math.huge as the floor so Shady always matches negative scores
local CHAT_TIERS = {
	{ min = -math.huge, title = "Shady",       color = { 220, 90,  105 } },
	{ min = 0,          title = "Visitor",     color = { 170, 155, 210 } },
	{ min = 25,         title = "Rising",      color = { 120, 190, 255 } },
	{ min = 100,        title = "Famous",      color = { 255, 210, 120 } },
	{ min = 250,        title = "Trendsetter", color = { 215, 170, 255 } },
	{ min = 500,        title = "Influencer",  color = { 255, 160, 235 } },
	{ min = 1000,       title = "Celebrity",   color = { 255, 225, 90  } },
}

local function getChatTierInfo(score)
	local info = CHAT_TIERS[1]
	for _, tier in ipairs(CHAT_TIERS) do
		if score >= tier.min then
			info = tier
		end
	end
	return info
end

GetChatTag.OnServerInvoke = function(_, targetUserId)
	if type(targetUserId) ~= "number" then return nil end

	-- VIP overrides tier tag: show [VIP] in gold
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if targetPlayer and targetPlayer:GetAttribute("OwnsVIP") then
		return { title = "VIP", hex = "#FFD700", isVip = true }
	end

	local data = repCache[targetUserId] or { score = 0 }
	local score = data.score or 0
	local tier = getChatTierInfo(score)
	local hex = string.format("#%02X%02X%02X",
		tier.color[1], tier.color[2], tier.color[3]
	)
	return { title = tier.title, hex = hex }
end

print("[AdminRep] Admin reputation commands active.")

-- -- Exposed for GamepassServer: grant bonus rep without a voter cooldown -------
_G.GrantBonusRep = function(userId, amount)
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	local data = getCachedOrDefault(userId)
	local beforeTier = getTierIndex(data.score)
	data.score = math.clamp(data.score + amount, -9999, 99999)
	local afterTier = getTierIndex(data.score)
	local upgraded = afterTier > beforeTier
	pushRepUpdate(userId, data, upgraded)
	if upgraded then
		local burstPayload = buildRepPayload(userId, data)
		playTitleParticleBurst(player, burstPayload.tierColor)
	end
	markRepDirty(userId)
	dlog("GrantBonusRep:", userId, "+", amount, "-> new score:", data.score)
end

-- Badge callbacks (registered by BadgeServer)
_G.OnFirstJoin = nil
_G.OnFirstRepGiven = nil
_G.OnGenerousSoul = nil
_G.OnShadyTierReached = nil