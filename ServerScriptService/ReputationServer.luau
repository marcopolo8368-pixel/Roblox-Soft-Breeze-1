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

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GiveReputationEvent = Remotes:WaitForChild("GiveReputation")
local RequestReputationFunc = Remotes:WaitForChild("RequestReputation")
local ReputationUpdatedEvent = Remotes:WaitForChild("ReputationUpdated")
local RequestRepCooldownFunc = Remotes:WaitForChild("RequestRepCooldown")
local RequestLeaderboardFunc = Remotes:WaitForChild("RequestLeaderboard")

local RepStore = DataStoreService:GetDataStore("PlayerReputation_v1")

local COOLDOWN_SECONDS = 24 * 60 * 60
local ACTION_VALUES = {
	thumbsUp = 1,
	thumbsDown = -1,
	love = 2,
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
}

local repCache = {} -- [userId] = rep data

local function cloneDefaultRep()
	return {
		score = DEFAULT_REP.score,
		totalGiven = DEFAULT_REP.totalGiven,
		totalReceived = DEFAULT_REP.totalReceived,
		cooldownByTarget = {},
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
	if not data then return end

	pruneCooldowns(data)
	local key = "rep_" .. tostring(userId)
	local success, err = pcall(function()
		RepStore:SetAsync(key, data)
	end)

	if not success then
		warn("[ReputationServer] Failed saving rep for userId " .. tostring(userId) .. ": " .. tostring(err))
	end
end

local function loadRepForPlayer(player)
	local repData = loadRepForUserId(player.UserId)
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

	ReputationUpdatedEvent:FireAllClients(payload)
	if _G.FireRepUpdateForNametag then
		_G.FireRepUpdateForNametag(payload)
	end
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
	emitter.Parent = attachment

	emitter:Emit(28)
	Debris:AddItem(attachment, 2)
end

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
	if remaining > 0 and not IS_STUDIO then
		fireVoteResult(voter, {
			ok = false,
			reason = "Cooldown active",
			remainingSeconds = remaining,
		})
		return
	end

	local voterData = getCachedOrDefault(voter.UserId)
	local targetData = getCachedOrDefault(targetUserId)
	pruneCooldowns(voterData)

	local beforeTier = getTierIndex(targetData.score)
	targetData.score += delta
	targetData.totalReceived += 1
	voterData.totalGiven += 1
	voterData.cooldownByTarget[tostring(targetUserId)] = os.time() + COOLDOWN_SECONDS

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

	task.spawn(function()
		saveRepForUserId(voter.UserId)
		saveRepForUserId(targetUserId)
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
	return {
		canVote = remaining <= 0,
		remainingSeconds = remaining,
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

Players.PlayerAdded:Connect(function(player)
	loadRepForPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	saveRepForUserId(player.UserId)
	task.delay(45, function()
		repCache[player.UserId] = nil
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		loadRepForPlayer(player)
	end)
end

print("[ReputationServer] Reputation backend initialized.")