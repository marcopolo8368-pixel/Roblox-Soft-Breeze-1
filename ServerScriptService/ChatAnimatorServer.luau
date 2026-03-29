--[[
    ChatAnimatorServer.luau
    Location: ServerScriptService

    Spawns a keyboard model in front of the player when they chat.
    Handles cleanup on death, respawn, and disconnect.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local chattingRE = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Chatting")
local keyboardModel = ReplicatedStorage:WaitForChild("Storage"):WaitForChild("Keyboard")

local keyboards = {}
local playerConnections = {}

local KEYBOARD_FORWARD = 1.8
local KEYBOARD_HEIGHT = -0.6

local function destroyKeyboard(player)
    local keyboard = keyboards[player]
    if not keyboard then return end
    pcall(function() keyboard:Destroy() end)
    keyboards[player] = nil
end

local function createKeyboard(player)
    -- Always clean up old keyboard first
    destroyKeyboard(player)

    local character = player.Character
    if not character then return end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Verify character is alive
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return end

    local keyboard = keyboardModel:Clone()
    keyboard:PivotTo(root.CFrame * CFrame.new(0, KEYBOARD_HEIGHT, -KEYBOARD_FORWARD))
    keyboard.Parent = workspace
    keyboards[player] = keyboard

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = keyboard.PrimaryPart
    weld.Parent = root
end

chattingRE.OnServerEvent:Connect(function(player, isChatting)
    if type(isChatting) ~= "boolean" then return end
    if isChatting then
        createKeyboard(player)
    else
        destroyKeyboard(player)
    end
end)

-- Clean up keyboard when character dies or is removed
local function setupCharacterCleanup(player, character)
    -- Disconnect old connections
    if playerConnections[player] then
        for _, conn in ipairs(playerConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
    end
    playerConnections[player] = {}

    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        local conn = humanoid.Died:Connect(function()
            destroyKeyboard(player)
        end)
        table.insert(playerConnections[player], conn)
    end
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(character)
        destroyKeyboard(player) -- clean up from previous life
        task.spawn(function()
            setupCharacterCleanup(player, character)
        end)
    end)

    if player.Character then
        task.spawn(function()
            setupCharacterCleanup(player, player.Character)
        end)
    end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
    task.spawn(function() onPlayerAdded(p) end)
end

Players.PlayerRemoving:Connect(function(player)
    destroyKeyboard(player)
    if playerConnections[player] then
        for _, conn in ipairs(playerConnections[player]) do
            pcall(function() conn:Disconnect() end)
        end
        playerConnections[player] = nil
    end
end)
