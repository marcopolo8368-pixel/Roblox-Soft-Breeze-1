--[[
    LeaderStats.lua  (Rep + Title)
    Location: ServerScriptService

    Shows Rep score and Tier title on the leaderboard.
]]

local Players = game:GetService("Players")

local TIERS = {
	{ min = 1000, title = "Celebrity" },
	{ min = 500,  title = "Influencer" },
	{ min = 250,  title = "Trendsetter" },
	{ min = 100,  title = "Famous" },
	{ min = 25,   title = "Rising" },
	{ min = 0,    title = "Visitor" },
	{ min = -10,  title = "Shady" },
}

local function getTitleFromScore(score)
	for _, tier in ipairs(TIERS) do
		if score >= tier.min then
			return tier.title
		end
	end
	return "Shady"
end

local function setupLeaderstats(player)
	-- Wait for rep data to be ready (max 15 seconds)
	local waited = 0
	while not (_G.GetRepDataForLeaderboard and _G.GetRepDataForLeaderboard(player.UserId)) do
		task.wait(0.5)
		waited += 0.5
		if waited >= 15 then break end
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local repStat = Instance.new("IntValue")
	repStat.Name = "Rep"
	repStat.Value = 0
	repStat.Parent = leaderstats

	local titleStat = Instance.new("StringValue")
	titleStat.Name = "Title"
	titleStat.Value = "Visitor"
	titleStat.Parent = leaderstats

	-- Set initial value
	local data = _G.GetRepDataForLeaderboard and _G.GetRepDataForLeaderboard(player.UserId)
	if data then
		repStat.Value = data.score or 0
		titleStat.Value = getTitleFromScore(data.score or 0)
	end

	-- Live updates
	if _G.SubscribeToRepUpdates then
		_G.SubscribeToRepUpdates(player.UserId, function(score)
			repStat.Value = score
			titleStat.Value = getTitleFromScore(score)
		end)
	end
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		setupLeaderstats(player)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		setupLeaderstats(player)
	end)
end

print("[LeaderStats] Leaderstats initialized.")
