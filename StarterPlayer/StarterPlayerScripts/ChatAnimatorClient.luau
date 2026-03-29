--[[
    ChatAnimatorClient.luau
    Location: StarterPlayerScripts

    Plays a typing animation when the chat bar is focused.
    Handles respawns properly by re-acquiring character references.
]]

local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local chattingRE = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Chatting")
local inputBar = TextChatService:WaitForChild("ChatInputBarConfiguration")
local chattingAnimAsset = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ChatAnimator"):WaitForChild("ChattingAnim")

local player = Players.LocalPlayer
local track = nil
local isChatting = false

local function getAnimator()
    local character = player.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    return humanoid:FindFirstChildOfClass("Animator")
end

local function stopAnim()
    if track then
        pcall(function() track:Stop() end)
        track = nil
    end
end

local function playAnim()
    stopAnim()
    local animator = getAnimator()
    if not animator then return end
    local ok, newTrack = pcall(function()
        return animator:LoadAnimation(chattingAnimAsset)
    end)
    if ok and newTrack then
        track = newTrack
        track.Priority = Enum.AnimationPriority.Action4
        track.Looped = true
        track:Play()
    end
end

-- Chat bar focus/unfocus
inputBar:GetPropertyChangedSignal("IsFocused"):Connect(function()
    if inputBar.IsFocused then
        isChatting = true
        chattingRE:FireServer(true)
        playAnim()
    else
        isChatting = false
        chattingRE:FireServer(false)
        stopAnim()
    end
end)

-- On respawn: stop animation, tell server to clean up keyboard
player.CharacterAdded:Connect(function()
    -- If was chatting when died, clean up
    if isChatting then
        isChatting = false
        chattingRE:FireServer(false)
    end
    stopAnim()
end)

-- Also handle character removing (death)
player.CharacterRemoving:Connect(function()
    if isChatting then
        isChatting = false
        pcall(function() chattingRE:FireServer(false) end)
    end
    stopAnim()
end)
