-- ============================================
--         SCRIPT DEFENDER v1.1
--       Place in ServerScriptService
--     Scans Workspace for malicious scripts
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================
-- CONFIGURATION
-- ============================================
local CONFIG = {
	ScanInterval       = 5,    -- How often to re-scan (seconds)
	NotifyAdmins       = true, -- Notify admins in-game
	AdminUserIds       = {
		6163688260,            -- Your user ID
	},
	LogToOutput        = true,
	BlockMaliciousGuis = true,
	NotifyOnly         = true, -- TRUE = just warn you, never auto-delete
	-- FALSE = auto-delete threats (use with caution!)
}

-- ============================================
-- VIRUS SIGNATURES
-- Patterns found in malicious scripts
-- ============================================
local MALICIOUS_PATTERNS = {
	-- Code execution tricks
	"loadstring",
	"HttpGet",
	"HttpEnabled",
	"GetObjects.*rbxassetid",
	"require%(%d+%)",           -- require(assetId) - loads remote modules
	"pcall%(loadstring",

	-- Obfuscation tricks
	":sub%(.-%).%.%.",          -- string reversal loops like your virus used
	"GetAttribute.*:sub",       -- reading + reversing attributes
	"PlaneConstraint",          -- your specific virus's hiding spot

	-- Social engineering GUIs
	"Error 501",
	"Ctrl %+ C",
	"command bar",
	"paste it into",
	"Shift %+ F5",
	"copy the text",

	-- Known virus asset IDs
	"114706280708394",
	"rbxassetid://6044579[0-9]+",

	-- Self-replication
	"StarterGui.*Clone",
	"Credits.*Clone",
	":Clone%(%):.*Parent.*StarterGui",
}

-- GUI elements that are suspicious (checked by text content)
local MALICIOUS_GUI_TEXT = {
	"Error 501",
	"command bar",
	"Ctrl + C",
	"Shift + F5",
	"paste it into",
	"copy the text in textbox",
	"rejoin the game",
}

-- ============================================
-- NOTIFICATION SYSTEM
-- ============================================
local function notifyPlayer(player, message)
	-- Send a hint message to the player
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "DefenderAlert"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 999

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 420, 0, 90)
	frame.Position = UDim2.new(0.5, -210, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 60, 60)
	stroke.Thickness = 2
	stroke.Parent = frame

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(0, 50, 1, 0)
	icon.Position = UDim2.new(0, 0, 0, 0)
	icon.BackgroundTransparency = 1
	icon.Text = "???"
	icon.TextSize = 28
	icon.Font = Enum.Font.GothamBold
	icon.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -60, 0.5, 0)
	label.Position = UDim2.new(0, 50, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = "SCRIPT DEFENDER"
	label.TextColor3 = Color3.fromRGB(255, 60, 60)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local msg = Instance.new("TextLabel")
	msg.Size = UDim2.new(1, -60, 0.5, 0)
	msg.Position = UDim2.new(0, 50, 0.5, -4)
	msg.BackgroundTransparency = 1
	msg.Text = message
	msg.TextColor3 = Color3.fromRGB(220, 220, 220)
	msg.TextSize = 13
	msg.Font = Enum.Font.Gotham
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextWrapped = true
	msg.Parent = frame

	screenGui.Parent = player.PlayerGui

	-- Auto dismiss after 6 seconds
	task.delay(6, function()
		if screenGui and screenGui.Parent then
			screenGui:Destroy()
		end
	end)
end

local function alertAdmins(message)
	if not CONFIG.NotifyAdmins then return end
	for _, player in ipairs(Players:GetPlayers()) do
		if table.find(CONFIG.AdminUserIds, player.UserId) then
			notifyPlayer(player, message)
		end
	end
end

local function log(message)
	if CONFIG.LogToOutput then
		warn("[ScriptDefender] " .. message)
	end
end

-- ============================================
-- SCAN ENGINE
-- ============================================
local function getScriptSource(script)
	-- We can read the source in Studio; in live games we check name/tags/attributes
	local success, source = pcall(function()
		return script.Source
	end)
	return success and source or ""
end

local function checkSourceForPatterns(source, name)
	for _, pattern in ipairs(MALICIOUS_PATTERNS) do
		if source:lower():find(pattern:lower()) then
			return true, pattern
		end
		if name:lower():find(pattern:lower()) then
			return true, "name:" .. pattern
		end
	end
	return false, nil
end

local function checkAttributes(instance)
	-- Check if attributes contain reversed/encoded strings (like your PlaneConstraint virus)
	local success, attrs = pcall(function()
		return instance:GetAttributes()
	end)
	if not success then return false end

	for key, value in pairs(attrs) do
		if type(value) == "string" and #value > 30 then
			-- Check if it looks like obfuscated code
			local lv = value:lower()
			if lv:find("getservice") or lv:find("workspace") or lv:find("instance")
				or lv:find("script") or lv:find("require") or lv:find("loadstring") then
				return true
			end
		end
	end
	return false
end

local function destroyThreat(instance, reason)
	local path = instance:GetFullName()
	if CONFIG.NotifyOnly then
		log("THREAT DETECTED (not deleted): " .. path .. " | Reason: " .. reason)
		alertAdmins("?? Suspicious script found!\nName: " .. instance.Name .. "\nLocation: " .. path .. "\nReason: " .. reason .. "\n\nNotifyOnly is ON — nothing was deleted.\nCheck it manually in Explorer!")
	else
		log("THREAT REMOVED: " .. path .. " | Reason: " .. reason)
		alertAdmins("??? Removed threat: " .. instance.Name .. "\n(" .. reason .. ")")
		pcall(function() instance:Destroy() end)
	end
end

-- ============================================
-- GUI SCANNER
-- Blocks fake error popups
-- ============================================
local function scanGuiForMaliciousText(gui)
	if not CONFIG.BlockMaliciousGuis then return end

	for _, descendant in ipairs(gui:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			local text = descendant.Text:lower()
			for _, badText in ipairs(MALICIOUS_GUI_TEXT) do
				if text:find(badText:lower()) then
					destroyThreat(gui, "Malicious GUI: contains '" .. badText .. "'")
					return
				end
			end
		end
	end
end

local function watchPlayerGuis(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then return end

		-- Scan existing GUIs
		for _, gui in ipairs(playerGui:GetChildren()) do
			scanGuiForMaliciousText(gui)
		end

		-- Watch for new GUIs being added
		playerGui.ChildAdded:Connect(function(child)
			task.wait(0.1)
			scanGuiForMaliciousText(child)
		end)
	end)

	-- Also scan StarterGui
	local starterGui = game:GetService("StarterGui")
	starterGui.ChildAdded:Connect(function(child)
		task.wait(0.1)
		scanGuiForMaliciousText(child)
	end)
end

-- ============================================
-- MAIN SCANNER
-- Scans Workspace and all descendants
-- ============================================
local scannedInstances = {} -- track already-scanned to avoid repeat alerts

local function scanInstance(instance)
	local id = instance:GetDebugId()
	if scannedInstances[id] then return end
	scannedInstances[id] = true

	-- Scan scripts
	if instance:IsA("BaseScript") or instance:IsA("ModuleScript") then
		local source = getScriptSource(instance)
		local isMalicious, pattern = checkSourceForPatterns(source, instance.Name)
		if isMalicious then
			destroyThreat(instance, "Pattern match: " .. pattern)
			return
		end
	end

	-- Scan ALL instances for suspicious attributes (like PlaneConstraint hiding code)
	if checkAttributes(instance) then
		destroyThreat(instance, "Encoded payload in attributes")
		return
	end

	-- Check for suspicious children combos (script hidden inside a constraint/value)
	local hasScript = instance:FindFirstChildOfClass("LocalScript") or instance:FindFirstChildOfClass("Script")
	local isHidingSpot = instance:IsA("PlaneConstraint") or instance:IsA("StringValue")
		or instance:IsA("NumberValue") or instance:IsA("BoolValue")
		or instance:IsA("IntValue") or instance:IsA("ObjectValue")
		or instance:IsA("BillboardGui") or instance:IsA("SurfaceGui")

	if hasScript and isHidingSpot then
		destroyThreat(instance, "Script hidden inside " .. instance.ClassName)
		return
	end
end

local function fullScan(root)
	root = root or game.Workspace
	local count = 0

	for _, descendant in ipairs(root:GetDescendants()) do
		local ok, err = pcall(scanInstance, descendant)
		if not ok then
			log("Scan error on " .. descendant:GetFullName() .. ": " .. tostring(err))
		end
		count += 1
	end

	log("Scan complete. Checked " .. count .. " instances in " .. root:GetFullName())
end

-- ============================================
-- LIVE WATCHER
-- Catches viruses the moment they're added
-- ============================================
local function startLiveWatcher()
	-- Watch Workspace for anything newly added
	game.Workspace.DescendantAdded:Connect(function(instance)
		task.wait(0.05) -- tiny delay so instance is fully loaded
		pcall(scanInstance, instance)
	end)

	-- Watch ReplicatedStorage and ReplicatedFirst too (viruses sometimes clone there)
	game:GetService("ReplicatedStorage").DescendantAdded:Connect(function(instance)
		task.wait(0.05)
		pcall(scanInstance, instance)
	end)

	game:GetService("ReplicatedFirst").DescendantAdded:Connect(function(instance)
		task.wait(0.05)
		pcall(scanInstance, instance)
	end)

	log("Live watcher active on Workspace, ReplicatedStorage, ReplicatedFirst")
end

-- ============================================
-- PLAYER PROTECTION
-- ============================================
Players.PlayerAdded:Connect(function(player)
	watchPlayerGuis(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	watchPlayerGuis(player)
end

-- ============================================
-- STARTUP
-- ============================================
log("Script Defender v1.1 starting — NotifyOnly mode: " .. tostring(CONFIG.NotifyOnly))

-- Initial full scan
fullScan(game.Workspace)
fullScan(game:GetService("ReplicatedStorage"))
fullScan(game:GetService("ReplicatedFirst"))

-- Also scan StarterGui for pre-planted viruses
fullScan(game:GetService("StarterGui"))

-- Periodic re-scan (catches anything that slipped through)
task.spawn(function()
	while true do
		task.wait(CONFIG.ScanInterval)
		-- Only rescan, don't log every time unless something is found
		for _, descendant in ipairs(game.Workspace:GetDescendants()) do
			pcall(scanInstance, descendant)
		end
	end
end)

-- Start live watching
startLiveWatcher()

log("Script Defender is active and protecting your game!")