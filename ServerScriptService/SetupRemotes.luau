--[[
    SetupRemotes.lua
    Location: ServerScriptService
    
    Creates all RemoteEvents and RemoteFunctions used across features.
    Runs once on server start before any client scripts need them.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Create a folder to organize all remotes
local RemotesFolder = Instance.new("Folder")
RemotesFolder.Name = "Remotes"
RemotesFolder.Parent = ReplicatedStorage

-- -------------------------------------------
-- PROFILE CARD SYSTEM
-- -------------------------------------------
local SaveProfileCard = Instance.new("RemoteEvent")
SaveProfileCard.Name = "SaveProfileCard"
SaveProfileCard.Parent = RemotesFolder

local RequestProfileCard = Instance.new("RemoteFunction")
RequestProfileCard.Name = "RequestProfileCard"
RequestProfileCard.Parent = RemotesFolder

local ProfileCardUpdated = Instance.new("RemoteEvent")
ProfileCardUpdated.Name = "ProfileCardUpdated"
ProfileCardUpdated.Parent = RemotesFolder

-- -------------------------------------------
-- OVERHEAD LABEL / PLATFORM SYSTEM
-- -------------------------------------------
local ReportPlatform = Instance.new("RemoteEvent")
ReportPlatform.Name = "ReportPlatform"
ReportPlatform.Parent = RemotesFolder

-- -------------------------------------------
-- REPUTATION SYSTEM
-- -------------------------------------------
local GiveReputation = Instance.new("RemoteEvent")
GiveReputation.Name = "GiveReputation"
GiveReputation.Parent = RemotesFolder

local RequestReputation = Instance.new("RemoteFunction")
RequestReputation.Name = "RequestReputation"
RequestReputation.Parent = RemotesFolder

local ReputationUpdated = Instance.new("RemoteEvent")
ReputationUpdated.Name = "ReputationUpdated"
ReputationUpdated.Parent = RemotesFolder

local RequestLeaderboard = Instance.new("RemoteFunction")
RequestLeaderboard.Name = "RequestLeaderboard"
RequestLeaderboard.Parent = RemotesFolder

local LeaderboardUpdated = Instance.new("RemoteEvent")
LeaderboardUpdated.Name = "LeaderboardUpdated"
LeaderboardUpdated.Parent = RemotesFolder

local RequestRepCooldown = Instance.new("RemoteFunction")
RequestRepCooldown.Name = "RequestRepCooldown"
RequestRepCooldown.Parent = RemotesFolder

-- -------------------------------------------
-- EMOTE SYSTEM
-- -------------------------------------------
local PlayEmote = Instance.new("RemoteEvent")
PlayEmote.Name = "PlayEmote"
PlayEmote.Parent = RemotesFolder

local StopEmote = Instance.new("RemoteEvent")
StopEmote.Name = "StopEmote"
StopEmote.Parent = RemotesFolder

print("[SetupRemotes] All remote events created successfully.")
