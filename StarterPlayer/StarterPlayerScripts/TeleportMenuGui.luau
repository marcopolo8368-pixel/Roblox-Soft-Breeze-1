--[[
    TeleportMenuGui.lua
    Location: StarterGui (as a LocalScript inside a ScreenGui)

    Reads locations from ReplicatedStorage.LocationsConfig (a ModuleScript).
    No workspace scanning — immune to streaming distance issues.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local LocationsConfig = {}
local ok, result = pcall(function()
	return require(ReplicatedStorage:WaitForChild("LocationsConfig", 5))
end)
if ok and type(result) == "table" then
	LocationsConfig = result
else
	warn("[TeleportMenuGui] Could not load LocationsConfig from ReplicatedStorage. Did you create the ModuleScript?")
end

-- -------------------------------------------
-- CONFIGURATION
-- -------------------------------------------
local ANIMATION_TIME = 0.25
local BUTTON_HEIGHT = 48

local COLORS = {
	bg = Color3.fromRGB(10, 10, 18),
	card = Color3.fromRGB(20, 20, 35),
	cardHover = Color3.fromRGB(35, 35, 58),
	accent = Color3.fromRGB(79, 172, 254),
	accentDim = Color3.fromRGB(50, 120, 200),
	text = Color3.fromRGB(220, 220, 240),
	textDim = Color3.fromRGB(100, 100, 130),
	overlay = Color3.fromRGB(255, 255, 255),
}

-- -------------------------------------------
-- HELPERS
-- -------------------------------------------
local function tween(instance, props, duration, style)
	TweenService:Create(
		instance,
		TweenInfo.new(duration or ANIMATION_TIME, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

local IS_SMALL_SCREEN
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
end

local PANEL_SIZE_OPEN   = IS_SMALL_SCREEN and UDim2.new(0.92, 0, 0.7, 0) or UDim2.new(0, 340, 0, 420)
local PANEL_SIZE_CLOSED = IS_SMALL_SCREEN and UDim2.new(0.92, 0, 0, 10) or UDim2.new(0, 340, 0, 10)

-- -------------------------------------------
-- SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportMenuGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 6
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Fade overlay (covers everything during teleport)
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name = "TeleportFadeGui"
fadeGui.ResetOnSpawn = false
fadeGui.DisplayOrder = 100
fadeGui.IgnoreGuiInset = true
fadeGui.Parent = playerGui

local fadeOverlay = Instance.new("Frame")
fadeOverlay.Name = "FadeOverlay"
fadeOverlay.Size = UDim2.new(1, 0, 1, 0)
fadeOverlay.BackgroundColor3 = COLORS.overlay
fadeOverlay.BackgroundTransparency = 1
fadeOverlay.ZIndex = 100
fadeOverlay.Visible = false
fadeOverlay.Parent = fadeGui

-- -------------------------------------------
-- PANEL
-- -------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "TeleportPanel"
panel.Size = PANEL_SIZE_OPEN
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = COLORS.bg
panel.BackgroundTransparency = 0.05
panel.ClipsDescendants = true
panel.Visible = false
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.88
panelStroke.Thickness = 1
panelStroke.Parent = panel

local panelGradient = Instance.new("UIGradient")
panelGradient.Rotation = 160
panelGradient.Color = ColorSequence.new(Color3.fromRGB(10, 10, 18), Color3.fromRGB(16, 14, 28))
panelGradient.Parent = panel

-- Header
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -32, 0, 22)
titleLabel.Position = UDim2.new(0, 20, 0, 18)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "TELEPORT"
titleLabel.TextColor3 = COLORS.accent
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = panel

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(1, -32, 0, 14)
subtitleLabel.Position = UDim2.new(0, 20, 0, 42)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "Choose a destination"
subtitleLabel.TextColor3 = COLORS.textDim
subtitleLabel.TextSize = 10
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = panel

local separator = Instance.new("Frame")
separator.Size = UDim2.new(1, -40, 0, 1)
separator.Position = UDim2.new(0, 20, 0, 64)
separator.BackgroundColor3 = COLORS.accent
separator.BackgroundTransparency = 0.6
separator.BorderSizePixel = 0
separator.Parent = panel

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = IS_SMALL_SCREEN and UDim2.new(0, 44, 0, 44) or UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -14, 0, 14)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.BackgroundColor3 = COLORS.card
closeBtn.Text = ""
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)

local xLine1 = Instance.new("Frame")
xLine1.Size = UDim2.new(0, 12, 0, 2)
xLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
xLine1.AnchorPoint = Vector2.new(0.5, 0.5)
xLine1.BackgroundColor3 = COLORS.textDim
xLine1.Rotation = 45
xLine1.BorderSizePixel = 0
xLine1.Parent = closeBtn

local xLine2 = Instance.new("Frame")
xLine2.Size = UDim2.new(0, 12, 0, 2)
xLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
xLine2.AnchorPoint = Vector2.new(0.5, 0.5)
xLine2.BackgroundColor3 = COLORS.textDim
xLine2.Rotation = -45
xLine2.BorderSizePixel = 0
xLine2.Parent = closeBtn

-- Scroll list
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "LocationList"
scrollFrame.Size = UDim2.new(1, -24, 1, -80)
scrollFrame.Position = UDim2.new(0, 12, 0, 74)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 3
scrollFrame.ScrollBarImageColor3 = COLORS.accent
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- -------------------------------------------
-- CLOSE MENU (declared early so buttons can reference it)
-- -------------------------------------------
local isOpen = false
local function closeMenu()
	if not isOpen then return end
	isOpen = false
	tween(panel, {
		Size = PANEL_SIZE_CLOSED,
		BackgroundTransparency = 1,
	}, ANIMATION_TIME * 0.7)
	task.delay(0.2, function()
		if not isOpen then
			panel.Visible = false
		end
	end)
end

-- -------------------------------------------
-- POPULATE LOCATIONS FROM CONFIG
-- -------------------------------------------
local isTeleporting = false

local function populateLocations()
	-- Clear any old buttons
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local index = 0
	for _, location in ipairs(LocationsConfig) do
		index += 1

		local btnFrame = Instance.new("TextButton")
		btnFrame.Name = location.name
		btnFrame.LayoutOrder = index
		btnFrame.Size = UDim2.new(1, -4, 0, BUTTON_HEIGHT)
		btnFrame.BackgroundColor3 = COLORS.card
		btnFrame.BackgroundTransparency = 0.15
		btnFrame.Text = ""
		btnFrame.AutoButtonColor = false
		btnFrame.Parent = scrollFrame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = btnFrame

		-- Arrow indicator on right side
		local arrowFrame = Instance.new("Frame")
		arrowFrame.Size = UDim2.new(0, 16, 1, 0)
		arrowFrame.Position = UDim2.new(1, -24, 0, 0)
		arrowFrame.BackgroundTransparency = 1
		arrowFrame.Parent = btnFrame

		local aTop = Instance.new("Frame")
		aTop.Size = UDim2.new(0, 8, 0, 2)
		aTop.Position = UDim2.new(0, 0, 0.5, -5)
		aTop.Rotation = 45
		aTop.BackgroundColor3 = COLORS.textDim
		aTop.BorderSizePixel = 0
		aTop.Parent = arrowFrame

		local aBot = Instance.new("Frame")
		aBot.Size = UDim2.new(0, 8, 0, 2)
		aBot.Position = UDim2.new(0, 0, 0.5, -1)
		aBot.Rotation = -45
		aBot.BackgroundColor3 = COLORS.textDim
		aBot.BorderSizePixel = 0
		aBot.Parent = arrowFrame

		-- Location name label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -48, 1, 0)
		nameLabel.Position = UDim2.new(0, 16, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = location.name
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamSemibold
		nameLabel.TextColor3 = COLORS.text
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = btnFrame

		-- Click: teleport with fade
		btnFrame.MouseButton1Click:Connect(function()
			if isTeleporting then return end
			local character = player.Character
			if not character then return end
			local root = character:FindFirstChild("HumanoidRootPart")
			if not root then return end

			isTeleporting = true
			closeMenu()

			task.delay(0.15, function()
				fadeOverlay.Visible = true
				fadeOverlay.BackgroundTransparency = 1
				tween(fadeOverlay, { BackgroundTransparency = 0 }, 0.4)
				task.wait(0.45)
				root.CFrame = CFrame.new(location.position)
				task.wait(0.2)
				tween(fadeOverlay, { BackgroundTransparency = 1 }, 0.5)
				task.delay(0.55, function()
					fadeOverlay.Visible = false
					isTeleporting = false
				end)
			end)
		end)

		-- Hover effects
		btnFrame.MouseEnter:Connect(function()
			tween(btnFrame, { BackgroundColor3 = COLORS.cardHover }, 0.15)
			tween(aTop, { BackgroundColor3 = COLORS.accent }, 0.15)
			tween(aBot, { BackgroundColor3 = COLORS.accent }, 0.15)
		end)
		btnFrame.MouseLeave:Connect(function()
			tween(btnFrame, { BackgroundColor3 = COLORS.card }, 0.15)
			tween(aTop, { BackgroundColor3 = COLORS.textDim }, 0.15)
			tween(aBot, { BackgroundColor3 = COLORS.textDim }, 0.15)
		end)
	end

	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, index * (BUTTON_HEIGHT + 6) + 10)
	subtitleLabel.Text = index .. " location" .. (index ~= 1 and "s" or "") .. " available"
end

-- -------------------------------------------
-- OPEN / CLOSE
-- -------------------------------------------
local function openMenu()
	if isOpen then return end
	isOpen = true
	populateLocations()
	panel.Visible = true
	panel.BackgroundTransparency = 1
	panel.Size = PANEL_SIZE_CLOSED
	tween(panel, {
		Size = PANEL_SIZE_OPEN,
		BackgroundTransparency = 0.05,
	}, ANIMATION_TIME, Enum.EasingStyle.Back)
end

closeBtn.MouseButton1Click:Connect(closeMenu)
closeBtn.MouseEnter:Connect(function()
	tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(180, 50, 50) })
end)
closeBtn.MouseLeave:Connect(function()
	tween(closeBtn, { BackgroundColor3 = COLORS.card })
end)

-- -------------------------------------------
-- PUBLIC API
-- -------------------------------------------
_G.OpenTeleportMenu = openMenu
_G.CloseTeleportMenu = closeMenu

print("[TeleportMenuGui] Teleport menu initialized.")
