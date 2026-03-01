--[[
    TeleportMenuGui.lua
    Location: StarterGui (as a LocalScript inside a ScreenGui)
    
    Creates a centered teleport panel that auto-populates from
    ALL children in Workspace.IslandSpawns (any type: Part, Model, Folder, etc.).
    Opened via FeaturesHubGui or the _G.OpenTeleportMenu global.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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
-- HELPER
-- -------------------------------------------
local function tween(instance, props, duration, style)
	TweenService:Create(instance, TweenInfo.new(duration or ANIMATION_TIME, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ─── RESPONSIVE HELPERS ───
local IS_SMALL_SCREEN
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
end

local PANEL_SIZE_OPEN = IS_SMALL_SCREEN and UDim2.new(0.92, 0, 0.7, 0) or UDim2.new(0, 340, 0, 420)
local PANEL_SIZE_CLOSED = IS_SMALL_SCREEN and UDim2.new(0.92, 0, 0, 10) or UDim2.new(0, 340, 0, 10)

-- Get a valid teleport position from ANY instance type
-- Get a valid teleport position from ANY instance type
local function getTeleportPosition(instance)
	if instance:IsA("BasePart") then
		return instance.Position + Vector3.new(0, 5, 0)
	end
	if instance:IsA("Model") then
		-- Priority 1: Pivot (should work even if parts are streaming in, if set correctly)
		local pivot = instance:GetPivot()
		if pivot and pivot.Position ~= Vector3.new(0, 0, 0) then
			return pivot.Position + Vector3.new(0, 5, 0)
		end
		-- Priority 2: PrimaryPart
		if instance.PrimaryPart then
			return instance.PrimaryPart.Position + Vector3.new(0, 5, 0)
		end
		-- Priority 3: First child part
		local part = instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position + Vector3.new(0, 5, 0)
		end
	end
	if instance:IsA("Folder") or instance:IsA("Configuration") then
		-- Look for a part inside
		local part = instance:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.Position + Vector3.new(0, 5, 0)
		end
	end
	if instance:IsA("Attachment") then
		return instance.WorldPosition + Vector3.new(0, 5, 0)
	end
	return nil
end

-- -------------------------------------------
-- CREATE SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TeleportMenuGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 6
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Teleport fade overlay (separate ScreenGui to cover EVERYTHING)
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
-- CENTERED PANEL (matches Profile/Settings style)
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

-- Close button (drawn X)
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

-- -------------------------------------------
-- SCROLLING LIST
-- -------------------------------------------
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
listLayout.SortOrder = Enum.SortOrder.Name
listLayout.Parent = scrollFrame

-- -------------------------------------------
-- TELEPORT FUNCTION
-- -------------------------------------------
local isTeleporting = false

local function teleportTo(targetInstance)
	if isTeleporting then return end

	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local targetPos = getTeleportPosition(targetInstance)
	if not targetPos then
		warn("[TeleportMenu] Could not find teleport position for: " .. targetInstance.Name)
		return
	end

	isTeleporting = true

	fadeOverlay.Visible = true
	fadeOverlay.BackgroundTransparency = 1
	tween(fadeOverlay, { BackgroundTransparency = 0 }, 0.4)

	task.wait(0.45)
	rootPart.CFrame = CFrame.new(targetPos)
	task.wait(0.2)

	tween(fadeOverlay, { BackgroundTransparency = 1 }, 0.5)
	task.delay(0.55, function()
		fadeOverlay.Visible = false
		isTeleporting = false
	end)
end

-- -------------------------------------------
-- POPULATE LOCATIONS
-- -------------------------------------------
local function createLocationButton(locationInstance, index)
	local btnFrame = Instance.new("TextButton")
	btnFrame.Name = locationInstance.Name
	btnFrame.Size = UDim2.new(1, -4, 0, BUTTON_HEIGHT)
	btnFrame.BackgroundColor3 = COLORS.card
	btnFrame.BackgroundTransparency = 0.15
	btnFrame.Text = ""
	btnFrame.AutoButtonColor = false
	btnFrame.Parent = scrollFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btnFrame

	local btnGrad = Instance.new("UIGradient")
	btnGrad.Rotation = 90
	btnGrad.Color = ColorSequence.new(Color3.fromRGB(24, 24, 40), Color3.fromRGB(18, 18, 30))
	btnGrad.Parent = btnFrame

	-- Location icon
	local icon = Instance.new("Frame")
	icon.Size = UDim2.new(0, 32, 0, 32)
	icon.Position = UDim2.new(0, 10, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundColor3 = COLORS.accent
	icon.BackgroundTransparency = 0.5
	icon.Parent = btnFrame
	Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

	-- Map pin image inside icon
	local pinImg = Instance.new("ImageLabel")
	pinImg.Size = UDim2.new(0, 16, 0, 16)
	pinImg.Position = UDim2.new(0.5, 0, 0.5, 0)
	pinImg.AnchorPoint = Vector2.new(0.5, 0.5)
	pinImg.BackgroundTransparency = 1
	pinImg.Image = "rbxassetid://6034287594"
	pinImg.ImageColor3 = Color3.new(1, 1, 1)
	pinImg.ScaleType = Enum.ScaleType.Fit
	pinImg.Parent = icon

	-- Location name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -90, 0, 18)
	nameLabel.Position = UDim2.new(0, 52, 0.5, 0)
	nameLabel.AnchorPoint = Vector2.new(0, 0.5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = locationInstance.Name
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Interactable = false
	nameLabel.Parent = btnFrame

	-- Arrow chevron
	local arrowFrame = Instance.new("Frame")
	arrowFrame.Name = "Arrow"
	arrowFrame.Size = UDim2.new(0, 14, 0, 14)
	arrowFrame.Position = UDim2.new(1, -16, 0.5, 0)
	arrowFrame.AnchorPoint = Vector2.new(1, 0.5)
	arrowFrame.BackgroundTransparency = 1
	arrowFrame.Interactable = false
	arrowFrame.Parent = btnFrame

	local aTop = Instance.new("Frame")
	aTop.Size = UDim2.new(0, 8, 0, 2)
	aTop.Position = UDim2.new(0.5, 0, 0.5, -2)
	aTop.AnchorPoint = Vector2.new(0.5, 0.5)
	aTop.BackgroundColor3 = COLORS.textDim
	aTop.Rotation = 35
	aTop.BorderSizePixel = 0
	aTop.Parent = arrowFrame

	local aBot = Instance.new("Frame")
	aBot.Size = UDim2.new(0, 8, 0, 2)
	aBot.Position = UDim2.new(0.5, 0, 0.5, 2)
	aBot.AnchorPoint = Vector2.new(0.5, 0.5)
	aBot.BackgroundColor3 = COLORS.textDim
	aBot.Rotation = -35
	aBot.BorderSizePixel = 0
	aBot.Parent = arrowFrame

	-- Click handler
	btnFrame.MouseButton1Click:Connect(function()
		tween(btnFrame, { BackgroundTransparency = 0 }, 0.08)
		tween(icon, { BackgroundTransparency = 0.1 }, 0.08)
		task.delay(0.12, function()
			tween(btnFrame, { BackgroundTransparency = 0.15 }, 0.15)
			tween(icon, { BackgroundTransparency = 0.5 }, 0.15)
		end)

		closeMenu()
		task.delay(0.15, function()
			teleportTo(locationInstance)
		end)
	end)

	btnFrame.MouseEnter:Connect(function()
		tween(btnFrame, { BackgroundColor3 = COLORS.cardHover }, 0.15)
		for _, c in ipairs(arrowFrame:GetChildren()) do
			if c:IsA("Frame") then tween(c, { BackgroundColor3 = COLORS.accent }, 0.15) end
		end
		tween(icon, { BackgroundTransparency = 0.2 }, 0.15)
	end)

	btnFrame.MouseLeave:Connect(function()
		tween(btnFrame, { BackgroundColor3 = COLORS.card }, 0.15)
		for _, c in ipairs(arrowFrame:GetChildren()) do
			if c:IsA("Frame") then tween(c, { BackgroundColor3 = COLORS.textDim }, 0.15) end
		end
		tween(icon, { BackgroundTransparency = 0.5 }, 0.15)
	end)
end

local function populateLocations()
	-- Retry loop for streaming/replication lag
	local attempts = 0
	local islandSpawns = nil

	while attempts < 10 do
		islandSpawns = workspace:FindFirstChild("IslandSpawns")
		if islandSpawns and #islandSpawns:GetChildren() > 0 then
			break
		end
		attempts += 1
		if attempts == 1 then
			-- Only clear list on first attempt to avoid flicker if we're just waiting
			for _, child in ipairs(scrollFrame:GetChildren()) do
				if child:IsA("TextButton") then child:Destroy() end
			end
			local loading = Instance.new("TextLabel")
			loading.Name = "LoadingLabel"
			loading.Size = UDim2.new(1, 0, 0, 40)
			loading.BackgroundTransparency = 1
			loading.Text = "Searching for locations..."
			loading.TextColor3 = COLORS.textDim
			loading.Parent = scrollFrame
		end
		task.wait(1)
	end

	-- Clear loading text
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") or child.Name == "LoadingLabel" then child:Destroy() end
	end

	if not islandSpawns then
		warn("[TeleportMenu] No 'IslandSpawns' folder found in Workspace after 10s!")
		local errorLabel = Instance.new("TextLabel")
		errorLabel.Size = UDim2.new(1, -16, 0, 60)
		errorLabel.BackgroundTransparency = 1
		errorLabel.Text = "No locations found.\n\nCreate an 'IslandSpawns'\nfolder in Workspace."
		errorLabel.TextColor3 = COLORS.textDim
		errorLabel.TextSize = 11
		errorLabel.Font = Enum.Font.Gotham
		errorLabel.TextWrapped = true
		errorLabel.Parent = scrollFrame
		return
	end

	local index = 0
	for _, child in ipairs(islandSpawns:GetChildren()) do
		local pos = getTeleportPosition(child)
		if pos then
			index += 1
			createLocationButton(child, index)
			print("[TeleportMenu] Added:", child.Name) 
		else
			warn("[TeleportMenu] SKIPPED LOCATION: '" .. child.Name .. "' (Class: " .. child.ClassName .. ")")
			warn("   Reason: getTeleportPosition returned nil. (Is it a Model with no PrimaryPart and no parts loaded?)")
		end
	end

	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, index * (BUTTON_HEIGHT + 6) + 10)
	subtitleLabel.Text = index .. " location" .. (index ~= 1 and "s" or "") .. " available"
end

-- -------------------------------------------
-- OPEN / CLOSE (centered popup, matches Profile/Settings)
-- -------------------------------------------
local isOpen = false

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

function closeMenu()
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

-- Close button
closeBtn.MouseButton1Click:Connect(closeMenu)
closeBtn.MouseEnter:Connect(function()
	tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(180, 50, 50) })
end)
closeBtn.MouseLeave:Connect(function()
	tween(closeBtn, { BackgroundColor3 = COLORS.card })
end)

-- -------------------------------------------
-- PUBLIC API (via _G globals for FeaturesHubGui)
-- -------------------------------------------
_G.OpenTeleportMenu = openMenu
_G.CloseTeleportMenu = closeMenu

print("[TeleportMenuGui] Teleport menu initialized.")
