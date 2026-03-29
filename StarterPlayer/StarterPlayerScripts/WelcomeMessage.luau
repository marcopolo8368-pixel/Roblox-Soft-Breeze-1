--[[
	WelcomeMessage.luau (LocalScript)
	Location: StarterPlayerScripts

	Shows a local "[Server] Welcome to Soft Breeze!" message in chat on join.
]]

local TextChatService = game:GetService("TextChatService")

task.defer(function()
	-- Wait for the chat system to initialize
	task.wait(3)

	local generalChannel = nil

	-- Try to find the general/system channel
	local channels = TextChatService:FindFirstChild("TextChannels")
	if channels then
		generalChannel = channels:FindFirstChild("RBXGeneral")
	end

	if generalChannel then
		generalChannel:DisplaySystemMessage(
			'<font color="#B89EFF"><b>[Server]</b></font> <font color="#E0DCF0">Welcome to Soft Breeze!</font>'
		)
	end
end)
