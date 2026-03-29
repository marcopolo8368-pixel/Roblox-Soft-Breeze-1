--[[
    ChatTagsClient.lua
    Location: StarterPlayerScripts

    Applies short colored rank abbreviations before player names in chat.
    VIP gamepass owners show [VIP] in gold instead of their tier tag.

    Tag abbreviations:
      VIP         -> [VIP]  (gold, gamepass)
      Shady       -> [SHD]
      Visitor     -> no tag (starting rank, keep chat clean)
      Rising      -> [RSG]
      Famous      -> [FAM]
      Trendsetter -> [TRD]
      Influencer  -> [INF]
      Celebrity   -> [CEL]
]]

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GetChatTagFunc = Remotes:WaitForChild("GetChatTag")

-- Short tags per tier. Visitor is intentionally blank.
local TIER_ABBR = {
	["Shady"]       = "SHD",
	["Visitor"]     = "",
	["Rising"]      = "RSG",
	["Famous"]      = "FAM",
	["Trendsetter"] = "TRD",
	["Influencer"]  = "INF",
	["Celebrity"]   = "CEL",
	["VIP"]         = "VIP",
}

TextChatService.OnIncomingMessage = function(message)
	local props = Instance.new("TextChatMessageProperties")

	local sender = message.TextSource
	if not sender then return props end

	local ok, tag = pcall(function()
		return GetChatTagFunc:InvokeServer(sender.UserId)
	end)

	if not ok or not tag then return props end

	-- VIP: gold tag with slightly different styling
	if tag.isVip then
		props.PrefixText = string.format(
			'<font color="#FFD700"><b>[VIP]</b></font> %s',
			message.PrefixText
		)
		return props
	end

	local abbr = TIER_ABBR[tag.title] or ""

	-- Visitors get no tag at all
	if abbr == "" then return props end

	local hex = tag.hex or "#AAA0D2"

	props.PrefixText = string.format(
		'<font color="%s"><b>[%s]</b></font> %s',
		hex, abbr, message.PrefixText
	)

	return props
end
