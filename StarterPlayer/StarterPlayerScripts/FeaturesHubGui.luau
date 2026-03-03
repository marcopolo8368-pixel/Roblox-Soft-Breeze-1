--[[
    FeaturesHubGui.lua
    Location: StarterGui (as a LocalScript inside a ScreenGui)
    
    Central hub UI that provides access to all game features:
    - Teleport (opens the teleport panel)
    - Profile Card (opens the profile editor)
    - Settings (opens the settings panel)
    
    Replaces individual toggle buttons for each feature.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Check admin status directly via remote (fast, no yielding for other scripts)
local isAdmin = false
do
	local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local adminFunc = Remotes and Remotes:FindFirstChild("AdminRepCanUse")
	if adminFunc and adminFunc:IsA("RemoteFunction") then
		local ok, result = pcall(function()
			return adminFunc:InvokeServer()
		end)
		if ok and result == true then
			isAdmin = true
		end
	end
end

-- -------------------------------------------
-- CONFIGURATION
-- -------------------------------------------
local TOGGLE_KEY = Enum.KeyCode.Tab
local ANIMATION_TIME = 0.25

local COLORS = {
	bg = Color3.fromRGB(10, 10, 18),
	bgPanel = Color3.fromRGB(14, 14, 24),
	card = Color3.fromRGB(24, 24, 40),
	cardHover = Color3.fromRGB(35, 35, 58),
	accent = Color3.fromRGB(138, 100, 214),
	accentGlow = Color3.fromRGB(170, 130, 255),
	accentDim = Color3.fromRGB(90, 60, 160),
	text = Color3.fromRGB(220, 220, 240),
	textDim = Color3.fromRGB(100, 100, 130),
	teleportAccent = Color3.fromRGB(79, 172, 254),
	profileAccent = Color3.fromRGB(138, 100, 214),
	settingsAccent = Color3.fromRGB(100, 200, 160),
	adminAccent = Color3.fromRGB(220, 80, 100),
}

local function tween(instance, props, duration, style)
	TweenService:Create(instance, TweenInfo.new(duration or ANIMATION_TIME, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- --- RESPONSIVE HELPERS ---
local IS_SMALL_SCREEN, VP_WIDTH
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
	VP_WIDTH = vp.X
end

local HUB_BUTTON_SIZE = IS_SMALL_SCREEN and 48 or 56
local HUB_BUTTON_HOVER_SIZE = IS_SMALL_SCREEN and 52 or 60
local HUB_PANEL_WIDTH = IS_SMALL_SCREEN and 240 or 280
local HUB_PANEL_HEIGHT = IS_SMALL_SCREEN and 88 or 100
local HUB_PANEL_OFFSET_Y = IS_SMALL_SCREEN and -76 or -86
local FEATURE_BTN_SIZE = IS_SMALL_SCREEN and 66 or 78
local FEATURE_BTN_START_X = IS_SMALL_SCREEN and 10 or 14
local FEATURE_BTN_STEP_X = IS_SMALL_SCREEN and 76 or 88
local FEATURE_ICON_SIZE = IS_SMALL_SCREEN and 28 or 32
local FEATURE_ICON_IMAGE_SIZE = IS_SMALL_SCREEN and 18 or 20
local FEATURE_LABEL_SIZE = IS_SMALL_SCREEN and 9 or 10

-- -------------------------------------------
-- SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FeaturesHubGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 5
screenGui.Parent = playerGui

-- -------------------------------------------
-- HUB TOGGLE BUTTON (pill at bottom-center)
-- -------------------------------------------
local hubButton = Instance.new("TextButton")
hubButton.Name = "HubToggle"
hubButton.Size = UDim2.new(0, HUB_BUTTON_SIZE, 0, HUB_BUTTON_SIZE)
hubButton.Position = UDim2.new(0.5, 0, 1, -20)
hubButton.AnchorPoint = Vector2.new(0.5, 1)
hubButton.BackgroundColor3 = COLORS.accent
hubButton.BackgroundTransparency = 0.1
hubButton.Text = ""
hubButton.Parent = screenGui

local hubCorner = Instance.new("UICorner")
hubCorner.CornerRadius = UDim.new(0, 16)
hubCorner.Parent = hubButton

local hubStroke = Instance.new("UIStroke")
hubStroke.Color = COLORS.accentGlow
hubStroke.Transparency = 0.4
hubStroke.Thickness = 2
hubStroke.Parent = hubButton

-- Draw a 3x3 grid icon (menu dots)
for row = 0, 2 do
	for col = 0, 2 do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 5, 0, 5)
		dot.Position = UDim2.new(0.5, -8 + col * 8, 0.5, -8 + row * 8)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = Color3.new(1, 1, 1)
		dot.BackgroundTransparency = 0.1
		dot.Parent = hubButton
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
	end
end

-- -------------------------------------------
-- HUB PANEL (slides up from button)
-- -------------------------------------------
local hubPanel = Instance.new("Frame")
hubPanel.Name = "HubPanel"
hubPanel.Size = UDim2.new(0, HUB_PANEL_WIDTH, 0, HUB_PANEL_HEIGHT)
hubPanel.Position = UDim2.new(0.5, 0, 1, HUB_PANEL_OFFSET_Y)
hubPanel.AnchorPoint = Vector2.new(0.5, 1)
hubPanel.BackgroundColor3 = COLORS.bg
hubPanel.BackgroundTransparency = 0.05
hubPanel.ClipsDescendants = true
hubPanel.Visible = false
hubPanel.Parent = screenGui
if IS_SMALL_SCREEN then
	local hubScale = math.clamp(VP_WIDTH * 0.92 / HUB_PANEL_WIDTH, 0.85, 1)
	Instance.new("UIScale", hubPanel).Scale = hubScale
end

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = hubPanel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.88
panelStroke.Thickness = 1
panelStroke.Parent = hubPanel

local panelGradient = Instance.new("UIGradient")
panelGradient.Rotation = 180
panelGradient.Color = ColorSequence.new(Color3.fromRGB(10, 10, 18), Color3.fromRGB(18, 14, 28))
panelGradient.Parent = hubPanel

-- -------------------------------------------
-- FEATURE BUTTONS
-- -------------------------------------------
local FEATURES = {
	{
		name = "Teleport",
		key = "teleport",
		color = COLORS.teleportAccent,
		iconType = "pin",
	},
	{
		name = "Profile",
		key = "profile",
		color = COLORS.profileAccent,
		iconType = "person",
	},
	{
		name = "Settings",
		key = "settings",
		color = COLORS.settingsAccent,
		iconType = "gear",
	},
	{
		name = "Admin",
		key = "admin",
		color = COLORS.adminAccent,
		iconType = "shield",
		adminOnly = true,
	},
}

-- Calculate panel width based on admin status
local visibleCount = 3  -- always at least 3 (Teleport, Profile, Settings)
-- Admin button is added later once we know admin status

local featureButtons = {}

local visibleIndex = 0
for _, feature in ipairs(FEATURES) do
	-- Skip admin-only features for non-admins
	if feature.adminOnly and not isAdmin then
		continue
	end
	visibleIndex += 1

	-- Use TextButton directly so it receives clicks natively
	local btnFrame = Instance.new("TextButton")
	btnFrame.Name = feature.key
	btnFrame.Size = UDim2.new(0, FEATURE_BTN_SIZE, 0, FEATURE_BTN_SIZE)
	btnFrame.Position = UDim2.new(0, FEATURE_BTN_START_X + (visibleIndex - 1) * FEATURE_BTN_STEP_X, 0.5, 0)
	btnFrame.AnchorPoint = Vector2.new(0, 0.5)
	btnFrame.BackgroundColor3 = COLORS.card
	btnFrame.BackgroundTransparency = 0.15
	btnFrame.Text = ""
	btnFrame.AutoButtonColor = false
	btnFrame.Parent = hubPanel
	Instance.new("UICorner", btnFrame).CornerRadius = UDim.new(0, 12)

	-- Icon container (non-interactive so clicks pass through)
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, FEATURE_ICON_SIZE, 0, FEATURE_ICON_SIZE)
	iconFrame.Position = UDim2.new(0.5, 0, 0, 12)
	iconFrame.AnchorPoint = Vector2.new(0.5, 0)
	iconFrame.BackgroundColor3 = feature.color
	iconFrame.BackgroundTransparency = 0.3
	iconFrame.Parent = btnFrame
	iconFrame.Interactable = false
	Instance.new("UICorner", iconFrame).CornerRadius = UDim.new(0, 8)

	-- Icon image (proper ImageLabel)
	local iconImage = Instance.new("ImageLabel")
	iconImage.Name = "Icon"
	iconImage.Size = UDim2.new(0, FEATURE_ICON_IMAGE_SIZE, 0, FEATURE_ICON_IMAGE_SIZE)
	iconImage.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
	iconImage.BackgroundTransparency = 1
	iconImage.ImageColor3 = Color3.new(1, 1, 1)
	iconImage.ScaleType = Enum.ScaleType.Fit
	iconImage.Interactable = false
	iconImage.Parent = iconFrame

	if feature.iconType == "pin" then
		iconImage.Image = "rbxassetid://111411414093265" -- Map/compass icon
	elseif feature.iconType == "person" then
		iconImage.Image = "rbxassetid://6034287594" -- Person/user icon
	elseif feature.iconType == "gear" then
		iconImage.Image = "rbxassetid://6031280882" -- Gear/settings icon
	elseif feature.iconType == "shield" then
		iconImage.Image = "rbxassetid://6031075938" -- Shield/admin icon
	end

	-- Label (non-interactive)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Position = UDim2.new(0, 0, 1, -16)
	label.BackgroundTransparency = 1
	label.Text = feature.name
	label.TextColor3 = COLORS.textDim
	label.TextSize = FEATURE_LABEL_SIZE
	label.Font = Enum.Font.GothamBold
	label.Interactable = false
	label.Parent = btnFrame

	-- Hover effects directly on the TextButton
	btnFrame.MouseEnter:Connect(function()
		tween(btnFrame, { BackgroundColor3 = COLORS.cardHover, BackgroundTransparency = 0 }, 0.15)
		tween(label, { TextColor3 = COLORS.text }, 0.15)
		tween(iconFrame, { BackgroundTransparency = 0.1 }, 0.15)
	end)

	btnFrame.MouseLeave:Connect(function()
		tween(btnFrame, { BackgroundColor3 = COLORS.card, BackgroundTransparency = 0.15 }, 0.15)
		tween(label, { TextColor3 = COLORS.textDim }, 0.15)
		tween(iconFrame, { BackgroundTransparency = 0.3 }, 0.15)
	end)

	featureButtons[feature.key] = btnFrame
end

-- Calculate panel width based on visible button count
local actualVisibleCount = visibleIndex
local ACTUAL_HUB_PANEL_WIDTH = IS_SMALL_SCREEN
	and (10 + actualVisibleCount * 76 + 10)
	or  (14 + actualVisibleCount * 88 + 14)

hubPanel.Size = UDim2.new(0, ACTUAL_HUB_PANEL_WIDTH, 0, HUB_PANEL_HEIGHT)

-- -------------------------------------------
-- HUB OPEN / CLOSE
-- -------------------------------------------
local isHubOpen = false

local function openHub()
	if isHubOpen then return end
	isHubOpen = true
	hubPanel.Visible = true
	hubPanel.BackgroundTransparency = 1
	hubPanel.Size = UDim2.new(0, ACTUAL_HUB_PANEL_WIDTH, 0, 10)
	tween(hubPanel, {
		Size = UDim2.new(0, ACTUAL_HUB_PANEL_WIDTH, 0, HUB_PANEL_HEIGHT),
		BackgroundTransparency = 0.05,
	}, ANIMATION_TIME, Enum.EasingStyle.Back)
	-- Rotate hub button to indicate open
	tween(hubButton, { Rotation = 45 }, ANIMATION_TIME)
	tween(hubStroke, { Color = Color3.fromRGB(255, 255, 255), Transparency = 0.3 }, 0.15)
end

local function closeHub()
	if not isHubOpen then return end
	isHubOpen = false
	tween(hubPanel, {
		Size = UDim2.new(0, ACTUAL_HUB_PANEL_WIDTH, 0, 10),
		BackgroundTransparency = 1,
	}, ANIMATION_TIME * 0.7)
	tween(hubButton, { Rotation = 0 }, ANIMATION_TIME * 0.7)
	tween(hubStroke, { Color = COLORS.accentGlow, Transparency = 0.4 }, 0.15)
	task.delay(0.2, function()
		if not isHubOpen then
			hubPanel.Visible = false
		end
	end)
end

local function toggleHub()
	if isHubOpen then closeHub() else openHub() end
end

-- Hub button click
hubButton.MouseButton1Click:Connect(toggleHub)

hubButton.MouseEnter:Connect(function()
	tween(hubButton, { BackgroundTransparency = 0, Size = UDim2.new(0, HUB_BUTTON_HOVER_SIZE, 0, HUB_BUTTON_HOVER_SIZE) }, 0.15)
end)
hubButton.MouseLeave:Connect(function()
	tween(hubButton, { BackgroundTransparency = 0.1, Size = UDim2.new(0, HUB_BUTTON_SIZE, 0, HUB_BUTTON_SIZE) }, 0.15)
end)

-- Keyboard toggle
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == TOGGLE_KEY then
		toggleHub()
	end
end)

-- -------------------------------------------
-- CONNECT FEATURE BUTTONS TO THEIR GUIS
-- Uses _G globals registered by each GUI script
-- -------------------------------------------

-- TELEPORT
featureButtons.teleport.MouseButton1Click:Connect(function()
	closeHub()
	task.wait(0.15)
	if _G.OpenTeleportMenu then
		_G.OpenTeleportMenu()
	else
		warn("[FeaturesHubGui] Teleport not ready - _G.OpenTeleportMenu is nil")
	end
end)

-- PROFILE
featureButtons.profile.MouseButton1Click:Connect(function()
	closeHub()
	task.wait(0.15)
	if _G.OpenProfileEditor then
		_G.OpenProfileEditor()
	else
		warn("[FeaturesHubGui] Profile not ready - _G.OpenProfileEditor is nil")
	end
end)

-- SETTINGS
local function fallbackOpenSettingsPanel()
	local settingsGui = playerGui:FindFirstChild("SettingsGui") or playerGui:WaitForChild("SettingsGui", 3)
	if not settingsGui then return false end

	local settingsPanel = settingsGui:FindFirstChild("SettingsPanel")
	if not settingsPanel or not settingsPanel:IsA("Frame") then return false end

	settingsPanel.Visible = true
	if settingsPanel.BackgroundTransparency > 0.1 then
		settingsPanel.BackgroundTransparency = 1
		tween(settingsPanel, { BackgroundTransparency = 0.05 }, 0.22)
	end
	return true
end

featureButtons.settings.MouseButton1Click:Connect(function()
	closeHub()
	task.wait(0.15)

	for _ = 1, 20 do
		if type(_G.OpenSettingsPanel) == "function" then
			local ok, err = pcall(_G.OpenSettingsPanel)
			if ok then
				return
			else
				warn("[FeaturesHubGui] OpenSettingsPanel failed:", err)
				break
			end
		end
		task.wait(0.05)
	end

	if fallbackOpenSettingsPanel() then
		warn("[FeaturesHubGui] Opened Settings via fallback (global API unavailable).")
	else
		warn("[FeaturesHubGui] Settings not ready - global API missing and fallback panel not found")
	end
end)

-- ADMIN PANEL
if featureButtons.admin then
	featureButtons.admin.MouseButton1Click:Connect(function()
		closeHub()
		task.wait(0.15)
		if _G.OpenAdminPanel then
			_G.OpenAdminPanel()
		else
			warn("[FeaturesHubGui] Admin panel not ready - _G.OpenAdminPanel is nil")
		end
	end)
end

print("[FeaturesHubGui] Features hub initialized. Press Tab or tap the hub button.")

print("[FeaturesHubGui] Features hub initialized. Press Tab or tap the hub button.")

