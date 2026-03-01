--[[
    SetupRepSounds.lua
    Location: ServerScriptService

    Ensures ReplicatedStorage.RepSounds exists with required non-3D UI sounds.
    Runs on server start and is idempotent.
]]

local RS = game:GetService("ReplicatedStorage")

local SOUND_IDS = {
	ThumbsUp = "rbxassetid://119581104818728",
	ThumbsDown = "rbxassetid://99815606397964",
	Love = "rbxassetid://138952089702570",
}

local folder = RS:FindFirstChild("RepSounds")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "RepSounds"
	folder.Parent = RS
end

for soundName, soundId in pairs(SOUND_IDS) do
	local sound = folder:FindFirstChild(soundName)
	if not sound or not sound:IsA("Sound") then
		if sound then
			sound:Destroy()
		end
		sound = Instance.new("Sound")
		sound.Name = soundName
		sound.Parent = folder
	end

	sound.SoundId = soundId
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 0
	sound.RollOffMinDistance = 0
	sound.Looped = false
end

print("[SetupRepSounds] RepSounds folder ready.")
