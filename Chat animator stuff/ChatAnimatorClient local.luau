-- << services >>
local textChatS = game:GetService("TextChatService")
local repS = game:GetService("ReplicatedStorage")

-- << instances >>
local chattingRE = repS.Events:WaitForChild("Chatting")
local inputBar = textChatS:WaitForChild("ChatInputBarConfiguration")

-- << events >>
inputBar:GetPropertyChangedSignal("IsFocused"):Connect(function()
	-- check if chat input textbox is focused or not
	if inputBar.IsFocused then chattingRE:FireServer(true) else chattingRE:FireServer(false) end
end)