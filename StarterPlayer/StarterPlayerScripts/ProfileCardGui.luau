--[[
    ProfileCardGui.lua
    Location: StarterGui (as a LocalScript inside a ScreenGui)
    
    Creates a fully customizable trading-card style profile card system.
    - Press P to edit your own card
    - Hover over a player to see them glow
    - Double-click a player to view their card
    
    Improved card design with gradient backgrounds, glow borders,
    animated mood badges, and cleaner typography.
]]

print("[ProfileCardGui] Script starting...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Wait for config to be ready (published by ProfileCardConfig.luau)
while not _G._ProfileCardConfig do task.wait(0.05) end
local Config = _G._ProfileCardConfig

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SaveProfileCardEvent = Remotes:WaitForChild("SaveProfileCard")
local RequestProfileCardFunc = Remotes:WaitForChild("RequestProfileCard")
local ProfileCardUpdatedEvent = Remotes:WaitForChild("ProfileCardUpdated")
local GiveReputationEvent = Remotes:WaitForChild("GiveReputation")
local RequestReputationFunc = Remotes:WaitForChild("RequestReputation")
local ReputationUpdatedEvent = Remotes:WaitForChild("ReputationUpdated")
local RequestRepCooldownFunc = Remotes:WaitForChild("RequestRepCooldown")
local AdminRepCanUseFunc  = Remotes:FindFirstChild("AdminRepCanUse")
local CheckPassOwnershipFunc = Remotes:WaitForChild("CheckPassOwnership")
local SetCustomTitleEvent = Remotes:WaitForChild("SetCustomTitle")
local RepSounds = ReplicatedStorage:WaitForChild("RepSounds")

local isAuthorizedAdmin = false
if AdminRepCanUseFunc and AdminRepCanUseFunc:IsA("RemoteFunction") then
	local ok, result = pcall(function()
		return AdminRepCanUseFunc:InvokeServer()
	end)
	if ok and result == true then
		isAuthorizedAdmin = true
	end
end

_G.IsAuthorizedAdmin = isAuthorizedAdmin
print("[ProfileCardGui] Phase 1 OK - remotes loaded, admin:", isAuthorizedAdmin)

-- -------------------------------------------
-- CONFIGURATION (from Config module)
-- -------------------------------------------
local COLORS = Config.COLORS
local EMOJI = Config.EMOJI
local MOODS = Config.MOODS
local MOOD_SYMBOLS = Config.MOOD_SYMBOLS
local CARD_STYLES = Config.CARD_STYLES
local TITLE_OPTIONS = Config.TITLE_OPTIONS
local IS_SMALL_SCREEN = Config.IS_SMALL_SCREEN
local IS_MEDIUM_SCREEN = Config.IS_MEDIUM_SCREEN
local TOGGLE_KEY = Config.TOGGLE_KEY
local DOUBLE_CLICK_TIME = Config.DOUBLE_CLICK_TIME
local tween = Config.tween
local colorToTable = Config.colorToTable
local tableToColor = Config.tableToColor
local colorsMatch = Config.colorsMatch

-- -------------------------------------------
-- SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name                  = "ProfileCardGui"
screenGui.ResetOnSpawn          = false
screenGui.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder          = 15
screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
screenGui.Parent                = playerGui
print("[ProfileCardGui] Phase 2 OK - ScreenGui created")

-- -------------------------------------------
-- PROFILE CARD DISPLAY COMPONENT
-- -------------------------------------------
local function createCardDisplay(parent, size, position)
	local card = Instance.new("Frame")
	card.Name = "ProfileCard"
	card.Size = size or UDim2.new(0, 230, 0, 320)
	card.Position = position or UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = COLORS.cardBg1
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 18)
	cardCorner.Parent = card

	-- Glow border
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Name = "CardStroke"
	cardStroke.Thickness = 2
	cardStroke.Transparency = 0.5
	cardStroke.Parent = card

	local strokeGradient = Instance.new("UIGradient")
	strokeGradient.Rotation = 135
	strokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.accent),
		ColorSequenceKeypoint.new(0.5, COLORS.accentLight),
		ColorSequenceKeypoint.new(1, COLORS.accentDark),
	})
	strokeGradient.Parent = cardStroke

	-- Background gradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "BgGradient"
	gradient.Rotation = 155
	gradient.Color = ColorSequence.new(COLORS.cardBg1, COLORS.cardBg2)
	gradient.Parent = card

	-- Top accent bar
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(1, 0, 0, 4)
	accentBar.BackgroundColor3 = COLORS.accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card

	local accentBarCorner = Instance.new("UICorner")
	accentBarCorner.CornerRadius = UDim.new(0, 18)
	accentBarCorner.Parent = accentBar

	-- Avatar circle with glow ring
	local avatarOuter = Instance.new("Frame")
	avatarOuter.Name = "AvatarOuter"
	avatarOuter.Size = UDim2.new(0, 82, 0, 82)
	avatarOuter.Position = UDim2.new(0.5, 0, 0, 28)
	avatarOuter.AnchorPoint = Vector2.new(0.5, 0)
	avatarOuter.BackgroundTransparency = 1
	avatarOuter.Parent = card

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(1, 0)
	outerCorner.Parent = avatarOuter

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Name = "AvatarGlow"
	outerStroke.Color = COLORS.accent
	outerStroke.Thickness = 3
	outerStroke.Transparency = 0.3
	outerStroke.Parent = avatarOuter

	local avatarFrame = Instance.new("ImageLabel")
	avatarFrame.Name = "Avatar"
	avatarFrame.Size = UDim2.new(0, 76, 0, 76)
	avatarFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	avatarFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	avatarFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	avatarFrame.Image = ""
	avatarFrame.Parent = avatarOuter

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatarFrame

	-- Display name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DisplayName"
	nameLabel.Size = UDim2.new(1, -24, 0, 24)
	nameLabel.Position = UDim2.new(0.5, 0, 0, 118)
	nameLabel.AnchorPoint = Vector2.new(0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Player"
	nameLabel.TextColor3 = COLORS.text
	nameLabel.TextSize = 17
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = card

	-- Mood badge (pill-shaped)
	local moodBadge = Instance.new("Frame")
	moodBadge.Name = "MoodBadge"
	moodBadge.Size = UDim2.new(0, 100, 0, 24)
	moodBadge.Position = UDim2.new(0.5, 0, 0, 146)
	moodBadge.AnchorPoint = Vector2.new(0.5, 0)
	moodBadge.BackgroundColor3 = COLORS.accent
	moodBadge.BackgroundTransparency = 0.6
	moodBadge.Parent = card

	local moodCorner = Instance.new("UICorner")
	moodCorner.CornerRadius = UDim.new(1, 0)
	moodCorner.Parent = moodBadge

	local moodStroke = Instance.new("UIStroke")
	moodStroke.Color = COLORS.accent
	moodStroke.Transparency = 0.5
	moodStroke.Thickness = 1
	moodStroke.Parent = moodBadge

	local moodLabel = Instance.new("TextLabel")
	moodLabel.Name = "MoodText"
	moodLabel.Size = UDim2.new(1, 0, 1, 0)
	moodLabel.BackgroundTransparency = 1
	moodLabel.Text = "~ Chill"
	moodLabel.TextColor3 = COLORS.text
	moodLabel.TextSize = 11
	moodLabel.Font = Enum.Font.GothamBold
	moodLabel.Parent = moodBadge

	-- Divider with dots
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(0.6, 0, 0, 1)
	divider.Position = UDim2.new(0.5, 0, 0, 180)
	divider.AnchorPoint = Vector2.new(0.5, 0)
	divider.BackgroundColor3 = COLORS.accent
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = card

	-- Bio
	local bioLabel = Instance.new("TextLabel")
	bioLabel.Name = "Bio"
	bioLabel.Size = UDim2.new(1, -32, 0, 55)
	bioLabel.Position = UDim2.new(0.5, 0, 0, 192)
	bioLabel.AnchorPoint = Vector2.new(0.5, 0)
	bioLabel.BackgroundTransparency = 1
	bioLabel.Text = "Hey, I'm chilling here!"
	bioLabel.TextColor3 = COLORS.textDim
	bioLabel.TextSize = 11
	bioLabel.Font = Enum.Font.Gotham
	bioLabel.TextWrapped = true
	bioLabel.TextYAlignment = Enum.TextYAlignment.Top
	bioLabel.Parent = card

	-- Quote (italic style)
	if not IS_SMALL_SCREEN then
		local quoteLabel = Instance.new("TextLabel")
		quoteLabel.Name = "Quote"
		quoteLabel.Size = UDim2.new(1, -32, 0, 36)
		quoteLabel.Position = UDim2.new(0.5, 0, 0, 252)
		quoteLabel.AnchorPoint = Vector2.new(0.5, 0)
		quoteLabel.BackgroundTransparency = 1
		quoteLabel.Text = ""
		quoteLabel.TextColor3 = COLORS.accentLight
		quoteLabel.TextSize = 10
		quoteLabel.Font = Enum.Font.GothamMedium
		quoteLabel.TextWrapped = true
		quoteLabel.Parent = card
	end

	-- Favorite color dot at bottom
	local colorDot = Instance.new("Frame")
	colorDot.Name = "FavColorDot"
	colorDot.Size = UDim2.new(0, 16, 0, 16)
	colorDot.Position = UDim2.new(0.5, 0, 1, -16)
	colorDot.AnchorPoint = Vector2.new(0.5, 1)
	colorDot.BackgroundColor3 = COLORS.accent
	colorDot.Parent = card

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = colorDot

	local dotStroke = Instance.new("UIStroke")
	dotStroke.Color = Color3.new(1, 1, 1)
	dotStroke.Transparency = 0.7
	dotStroke.Thickness = 1
	dotStroke.Parent = colorDot

	return card
end

-- -------------------------------------------
-- UPDATE CARD WITH DATA
-- -------------------------------------------
local function updateCardDisplay(card, data, userId)
	if not data then return end

	card:FindFirstChild("DisplayName").Text = data.displayName or "Player"
	card:FindFirstChild("Bio").Text = data.bio or ""

	local mood = data.mood or "Chill"
	local symbol = MOOD_SYMBOLS[mood] or EMOJI.thoughtful
	card:FindFirstChild("MoodBadge"):FindFirstChild("MoodText").Text = symbol .. "  " .. mood

	local quoteLabel = card:FindFirstChild("Quote")
	if quoteLabel then
		if data.quote and data.quote ~= "" then
			quoteLabel.Text = '"' .. data.quote .. '"'
		else
			quoteLabel.Text = ""
		end
	end

	-- Colors
	local favColor = tableToColor(data.favoriteColor)
	card:FindFirstChild("FavColorDot").BackgroundColor3 = favColor

	local avatarOuter = card:FindFirstChild("AvatarOuter")
	if avatarOuter then
		local glow = avatarOuter:FindFirstChild("AvatarGlow")
		if glow then glow.Color = tableToColor(data.bgGradientStart) end
	end

	-- Accent bar color matches fav color
	local accentBar = card:FindFirstChild("AccentBar")
	if accentBar then accentBar.BackgroundColor3 = favColor end

	local gradStart = tableToColor(data.bgGradientStart)
	local gradEnd = tableToColor(data.bgGradientEnd)

	-- Card stroke color uses the style/theme gradient colors for cursor glow
	local cardStroke = card:FindFirstChild("CardStroke")
	if cardStroke then
		local sg = cardStroke:FindFirstChildOfClass("UIGradient")
		if sg then
			sg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,   gradEnd),
				ColorSequenceKeypoint.new(0.5, gradStart),
				ColorSequenceKeypoint.new(1,   gradEnd),
			})
		end
	end
	-- BgGradient uses the style colors as the card's base gradient
	local bgGrad = card:FindFirstChild("BgGradient")
	if bgGrad then bgGrad.Color = ColorSequence.new(gradStart, gradEnd) end

	-- StyleOverlay is a hidden compat element — just store colors for reference
	local styleOverlay = card:FindFirstChild("StyleOverlay")
	if styleOverlay then
		local styleGrad = styleOverlay:FindFirstChildOfClass("UIGradient")
		if styleGrad then
			styleGrad.Color = ColorSequence.new(gradStart, gradEnd)
		end
	end

	-- Update outer avatar ring gradient to match theme
	local avatarRing = card:FindFirstChild("AvatarRing")
	if avatarRing then
		local ringStroke = avatarRing:FindFirstChildOfClass("UIStroke")
		if ringStroke then
			local ringGrad = ringStroke:FindFirstChildOfClass("UIGradient")
			if ringGrad then
				ringGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0,   gradStart),
					ColorSequenceKeypoint.new(0.5, gradEnd),
					ColorSequenceKeypoint.new(1,   gradStart),
				})
			end
		end
	end

	-- Background image (theme)
	local bgImage = card:FindFirstChild("BgImage")
	if bgImage then
		if data.bgImageId and data.bgImageId ~= "" then
			local imgId = data.bgImageId
			if not string.find(imgId, "://") then
				imgId = "rbxassetid://" .. imgId
			end
			bgImage.Image = imgId
			bgImage.ImageTransparency = 0
		else
			bgImage.Image = ""
			bgImage.ImageTransparency = 1
		end
	end

	-- Avatar thumbnail
	if userId then
		task.spawn(function()
			local success, content = pcall(function()
				return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if success and content then
				local avatarOuter2 = card:FindFirstChild("AvatarOuter")
				if avatarOuter2 then
					local avatar = avatarOuter2:FindFirstChild("Avatar")
					if avatar then avatar.Image = content end
				end
			end
		end)
	end
end

-- -------------------------------------------
-- EDITOR PANEL
-- -------------------------------------------
local EDITOR_SIZE_OPEN = IS_SMALL_SCREEN and UDim2.new(0.96, 0, 0.9, 0) or UDim2.new(0, 500, 0, 580)
local EDITOR_SIZE_CLOSED = IS_SMALL_SCREEN and UDim2.new(0.96, 0, 0, 10) or UDim2.new(0, 500, 0, 10)

local editorFrame = Instance.new("Frame")
editorFrame.Name = "EditorPanel"
editorFrame.Size = EDITOR_SIZE_OPEN
editorFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
editorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
editorFrame.BackgroundColor3 = COLORS.bg
editorFrame.BackgroundTransparency = 0.02
editorFrame.ClipsDescendants = true
editorFrame.Visible = false
editorFrame.Parent = screenGui

do
	local editorCorner = Instance.new("UICorner")
	editorCorner.CornerRadius = UDim.new(0, 18)
	editorCorner.Parent = editorFrame

	local editorStroke = Instance.new("UIStroke")
	editorStroke.Color = Color3.fromRGB(255, 255, 255)
	editorStroke.Transparency = 0.88
	editorStroke.Thickness = 1
	editorStroke.Parent = editorFrame

	local editorGrad = Instance.new("UIGradient")
	editorGrad.Rotation = 135
	editorGrad.Color = ColorSequence.new(Color3.fromRGB(8, 8, 16), Color3.fromRGB(16, 12, 26))
	editorGrad.Parent = editorFrame
end

-- Editor header
do
	local editorTitle = Instance.new("TextLabel")
	editorTitle.Size = UDim2.new(0, 200, 0, 24)
	editorTitle.Position = UDim2.new(0, 24, 0, 18)
	editorTitle.BackgroundTransparency = 1
	editorTitle.Text = "EDIT YOUR CARD"
	editorTitle.TextColor3 = COLORS.text
	editorTitle.TextSize = 15
	editorTitle.Font = Enum.Font.GothamBold
	editorTitle.TextXAlignment = Enum.TextXAlignment.Left
	editorTitle.Parent = editorFrame
end

-- Close button (drawn X icon)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = IS_SMALL_SCREEN and UDim2.new(0, 44, 0, 44) or UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -16, 0, 14)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.BackgroundColor3 = COLORS.input
closeBtn.Text = ""
closeBtn.Parent = editorFrame

-- Eye button — view your own profile card
local eyeBtn = Instance.new("TextButton")
eyeBtn.Name             = "EyeBtn"
eyeBtn.Size             = IS_SMALL_SCREEN and UDim2.new(0, 44, 0, 44) or UDim2.new(0, 32, 0, 32)
eyeBtn.Position         = UDim2.new(1, IS_SMALL_SCREEN and -68 or -56, 0, 14)
eyeBtn.AnchorPoint      = Vector2.new(1, 0)
eyeBtn.BackgroundColor3 = COLORS.input
eyeBtn.Text             = "👁"
eyeBtn.TextSize         = IS_SMALL_SCREEN and 20 or 16
eyeBtn.Font             = Enum.Font.GothamBold
eyeBtn.TextColor3       = COLORS.textDim
eyeBtn.BorderSizePixel  = 0
eyeBtn.ZIndex           = 5
eyeBtn.Parent           = editorFrame
Instance.new("UICorner", eyeBtn).CornerRadius = UDim.new(0, 8)

eyeBtn.MouseEnter:Connect(function()
	TweenService:Create(eyeBtn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.inputFocus, TextColor3 = COLORS.accent }):Play()
end)
eyeBtn.MouseLeave:Connect(function()
	TweenService:Create(eyeBtn, TweenInfo.new(0.12), { BackgroundColor3 = COLORS.input, TextColor3 = COLORS.textDim }):Play()
end)

do
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeBtn

	-- Draw X from two rotated lines
	local xLine1 = Instance.new("Frame")
	xLine1.Size = UDim2.new(0, 14, 0, 2)
	xLine1.Position = UDim2.new(0.5, 0, 0.5, 0)
	xLine1.AnchorPoint = Vector2.new(0.5, 0.5)
	xLine1.BackgroundColor3 = COLORS.textDim
	xLine1.Rotation = 45
	xLine1.BorderSizePixel = 0
	xLine1.Parent = closeBtn

	local xLine2 = Instance.new("Frame")
	xLine2.Size = UDim2.new(0, 14, 0, 2)
	xLine2.Position = UDim2.new(0.5, 0, 0.5, 0)
	xLine2.AnchorPoint = Vector2.new(0.5, 0.5)
	xLine2.BackgroundColor3 = COLORS.textDim
	xLine2.Rotation = -45
	xLine2.BorderSizePixel = 0
	xLine2.Parent = closeBtn
end

-- Always use a ScrollingFrame so editor is fully scrollable on all screen sizes
local editorScroll = Instance.new("ScrollingFrame")
editorScroll.Name                = "EditorScroll"
editorScroll.Size                = UDim2.new(1, 0, 1, -60)
editorScroll.Position            = UDim2.new(0, 0, 0, 60)
editorScroll.BackgroundTransparency = 1
editorScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
editorScroll.ScrollBarThickness  = 3
editorScroll.ScrollBarImageColor3 = COLORS.accent
editorScroll.BorderSizePixel     = 0
editorScroll.ClipsDescendants    = true
editorScroll.Parent              = editorFrame

do
	local _edScrollPad = Instance.new("UIPadding")
	_edScrollPad.PaddingBottom = UDim.new(0, 60)  -- room for Save button
	_edScrollPad.Parent        = editorScroll
end

local editorContentParent = editorScroll

-- Form fields — full-width, no side preview card
local formFrame = Instance.new("Frame")
formFrame.Name                = "FormFields"
formFrame.BackgroundTransparency = 1
formFrame.Size                = UDim2.new(1, -24, 0, 900)  -- tall enough for all fields + pass section
formFrame.Position            = UDim2.new(0, 12, 0, 8)
formFrame.Parent              = editorContentParent

-- Hidden dummy card so updatePreview() never errors (not visible to user)
local previewCard = Instance.new("Frame")
previewCard.Name    = "ProfileCard"
previewCard.Visible = false
previewCard.Size    = UDim2.fromOffset(0, 0)
previewCard.BackgroundTransparency = 1
previewCard.Parent  = editorFrame

-- Properly-typed dummy children that updateCardDisplay expects
do
	local _dummyBg = Instance.new("UIGradient")
	_dummyBg.Name   = "BgGradient"
	_dummyBg.Parent = previewCard

	local _dummyStrokeFrame = Instance.new("Frame")
	_dummyStrokeFrame.Name               = "CardStroke"
	_dummyStrokeFrame.BackgroundTransparency = 1
	_dummyStrokeFrame.Size               = UDim2.fromOffset(0, 0)
	_dummyStrokeFrame.Parent             = previewCard
	local _dummySG = Instance.new("UIGradient")
	_dummySG.Parent = _dummyStrokeFrame

	local function _dummyLabel(name)
		local f = Instance.new("TextLabel")
		f.Name = name; f.Visible = false; f.BackgroundTransparency = 1
		f.Size = UDim2.fromOffset(0, 0); f.Parent = previewCard
	end
	_dummyLabel("DisplayName"); _dummyLabel("Bio"); _dummyLabel("Quote")

	local _dummyMoodBadge = Instance.new("Frame")
	_dummyMoodBadge.Name = "MoodBadge"; _dummyMoodBadge.Visible = false
	_dummyMoodBadge.Size = UDim2.fromOffset(0, 0); _dummyMoodBadge.BackgroundTransparency = 1
	_dummyMoodBadge.Parent = previewCard
	local _dummyMoodText = Instance.new("TextLabel")
	_dummyMoodText.Name = "MoodText"; _dummyMoodText.Visible = false
	_dummyMoodText.BackgroundTransparency = 1; _dummyMoodText.Size = UDim2.fromOffset(0, 0)
	_dummyMoodText.Parent = _dummyMoodBadge

	local _dummyDot = Instance.new("Frame")
	_dummyDot.Name = "FavColorDot"; _dummyDot.Visible = false
	_dummyDot.Size = UDim2.fromOffset(0, 0); _dummyDot.BackgroundTransparency = 1
	_dummyDot.Parent = previewCard

	local _dummyAvatarOuter = Instance.new("Frame")
	_dummyAvatarOuter.Name = "AvatarOuter"; _dummyAvatarOuter.Visible = false
	_dummyAvatarOuter.Size = UDim2.fromOffset(0, 0); _dummyAvatarOuter.BackgroundTransparency = 1
	_dummyAvatarOuter.Parent = previewCard
	local _dummyAvatar = Instance.new("ImageLabel")
	_dummyAvatar.Name = "Avatar"; _dummyAvatar.Visible = false
	_dummyAvatar.Size = UDim2.fromOffset(0, 0); _dummyAvatar.BackgroundTransparency = 1
	_dummyAvatar.Parent = _dummyAvatarOuter

	local _dummyAccentBar = Instance.new("Frame")
	_dummyAccentBar.Name = "AccentBar"; _dummyAccentBar.Visible = false
	_dummyAccentBar.Size = UDim2.fromOffset(0, 0); _dummyAccentBar.BackgroundTransparency = 1
	_dummyAccentBar.Parent = previewCard

	local _dummyStyleOverlay = Instance.new("Frame")
	_dummyStyleOverlay.Name = "StyleOverlay"
	_dummyStyleOverlay.Visible = false
	_dummyStyleOverlay.Size = UDim2.fromOffset(0, 0)
	_dummyStyleOverlay.BackgroundTransparency = 1
	_dummyStyleOverlay.Parent = previewCard
	local _dummyStyleGrad = Instance.new("UIGradient")
	_dummyStyleGrad.Name = "StyleGradient"
	_dummyStyleGrad.Parent = _dummyStyleOverlay

	local _dummyBgImage = Instance.new("ImageLabel")
	_dummyBgImage.Name = "BgImage"
	_dummyBgImage.Visible = false
	_dummyBgImage.Size = UDim2.fromOffset(0, 0)
	_dummyBgImage.BackgroundTransparency = 1
	_dummyBgImage.Parent = previewCard

	local _dummyAvatarRing = Instance.new("Frame")
	_dummyAvatarRing.Name = "AvatarRing"
	_dummyAvatarRing.Visible = false
	_dummyAvatarRing.Size = UDim2.fromOffset(0, 0)
	_dummyAvatarRing.BackgroundTransparency = 1
	_dummyAvatarRing.Parent = previewCard
	local _dummyRingStroke = Instance.new("UIStroke")
	_dummyRingStroke.Parent = _dummyAvatarRing
	local _dummyRingGrad = Instance.new("UIGradient")
	_dummyRingGrad.Parent = _dummyRingStroke
end

-- -------------------------------------------
-- FORM FIELD CREATOR
-- -------------------------------------------
local formInputs = {}
local yOffset = 0

local function createFormField(label, fieldName, placeholder, maxLength, multiline)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 14)
	lbl.Position = UDim2.new(0, 0, 0, yOffset)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.upper(label)
	lbl.TextColor3 = COLORS.textMuted
	lbl.TextSize = 10
	lbl.Font = Enum.Font.GothamBold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = formFrame
	yOffset += 18

	local inputHeight = multiline and 54 or 32

	local inputBg = Instance.new("Frame")
	inputBg.Size = UDim2.new(1, 0, 0, inputHeight)
	inputBg.Position = UDim2.new(0, 0, 0, yOffset)
	inputBg.BackgroundColor3 = COLORS.input
	inputBg.Parent = formFrame

	local inputCorner = Instance.new("UICorner")
	inputCorner.CornerRadius = UDim.new(0, 10)
	inputCorner.Parent = inputBg

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = COLORS.accent
	inputStroke.Transparency = 0.85
	inputStroke.Thickness = 1
	inputStroke.Parent = inputBg

	local textBox = Instance.new("TextBox")
	textBox.Name = fieldName
	textBox.Size = UDim2.new(1, -18, 1, -6)
	textBox.Position = UDim2.new(0, 9, 0, 3)
	textBox.BackgroundTransparency = 1
	textBox.Text = ""
	textBox.PlaceholderText = placeholder or ""
	textBox.TextColor3 = COLORS.text
	textBox.PlaceholderColor3 = COLORS.textDim
	textBox.TextSize = 12
	textBox.Font = Enum.Font.Gotham
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center
	textBox.TextWrapped = multiline or false
	textBox.MultiLine = multiline or false
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputBg

	formInputs[fieldName] = textBox
	yOffset += inputHeight + 12

	-- Focus effects
	textBox.Focused:Connect(function()
		tween(inputStroke, { Transparency = 0.3 })
		tween(inputBg, { BackgroundColor3 = COLORS.inputFocus })
	end)
	textBox.FocusLost:Connect(function()
		tween(inputStroke, { Transparency = 0.85 })
		tween(inputBg, { BackgroundColor3 = COLORS.input })
	end)

	-- Live preview update
	textBox:GetPropertyChangedSignal("Text"):Connect(function()
		local text = textBox.Text
		if maxLength and #text > maxLength then
			textBox.Text = string.sub(text, 1, maxLength)
		end
		updatePreview()
	end)

	return textBox
end

-- -------------------------------------------
-- CREATE FORM FIELDS
-- -------------------------------------------
createFormField("Bio", "bio", "Tell us about yourself...", 100, true)
createFormField("Favorite Quote", "quote", "Your favorite quote...", 60)

-- Mood selector
local moodButtons = {}
local selectedMood = "Chill"
do
	local moodLbl = Instance.new("TextLabel")
	moodLbl.Size = UDim2.new(1, 0, 0, 14)
	moodLbl.Position = UDim2.new(0, 0, 0, yOffset)
	moodLbl.BackgroundTransparency = 1
	moodLbl.Text = "MOOD"
	moodLbl.TextColor3 = COLORS.textMuted
	moodLbl.TextSize = 10
	moodLbl.Font = Enum.Font.GothamBold
	moodLbl.TextXAlignment = Enum.TextXAlignment.Left
	moodLbl.Parent = formFrame
	yOffset += 18

	local moodContainer = Instance.new("Frame")
	local moodColumns = IS_SMALL_SCREEN and 2 or 3
	local moodCellHeight = IS_SMALL_SCREEN and 34 or 30
	local moodGapX = IS_SMALL_SCREEN and 6 or 6
	local moodGapY = IS_SMALL_SCREEN and 6 or 6
	local moodRows = math.ceil(#MOODS / moodColumns)
	local moodContainerHeight = (moodRows * moodCellHeight) + ((moodRows - 1) * moodGapY)

	moodContainer.Size = UDim2.new(1, 0, 0, moodContainerHeight)
	moodContainer.Position = UDim2.new(0, 0, 0, yOffset)
	moodContainer.BackgroundTransparency = 1
	moodContainer.Parent = formFrame

	local moodGrid = Instance.new("UIGridLayout")
	moodGrid.CellPadding = UDim2.new(0, moodGapX, 0, moodGapY)
	-- Use FillDirection + proportional width so exactly moodColumns fit per row
	-- Subtract total gap space then divide evenly
	local totalGapX = moodGapX * (moodColumns - 1)
	moodGrid.CellSize = UDim2.new(1 / moodColumns, -totalGapX / moodColumns, 0, moodCellHeight)
	moodGrid.FillDirectionMaxCells = moodColumns
	moodGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	moodGrid.SortOrder = Enum.SortOrder.LayoutOrder
	moodGrid.Parent = moodContainer

	for i, mood in ipairs(MOODS) do
		local moodBtn = Instance.new("TextButton")
		moodBtn.Name = mood
		moodBtn.Size = UDim2.new(0, 70, 0, moodCellHeight)
		moodBtn.LayoutOrder = i
		moodBtn.BackgroundColor3 = COLORS.input
		moodBtn.Text = (MOOD_SYMBOLS[mood] or "") .. " " .. mood
		moodBtn.TextSize = IS_SMALL_SCREEN and 12 or 10
		moodBtn.TextColor3 = COLORS.text
		moodBtn.Font = Enum.Font.GothamBold
		moodBtn.Parent = moodContainer

		local mCorner = Instance.new("UICorner")
		mCorner.CornerRadius = UDim.new(0, 8)
		mCorner.Parent = moodBtn

		moodButtons[mood] = moodBtn

		moodBtn.MouseButton1Click:Connect(function()
			selectedMood = mood
			for m, btn in pairs(moodButtons) do
				if m == mood then
					tween(btn, { BackgroundColor3 = COLORS.accent })
				else
					tween(btn, { BackgroundColor3 = COLORS.input })
				end
			end
			updatePreview()
		end)
	end

	-- ===========================================================
	-- PASS FEATURES SECTION (gradient picker, title, VIP badge)
	-- Positioned after the mood grid; only shows owned features.
	-- ===========================================================
	yOffset += moodContainerHeight + 14
end

print("[ProfileCardGui] Phase 3 OK - form fields + mood grid created")
-- Gradient state (updated by picker, used in save + updatePreview)
local selectedGradientStart = Color3.fromRGB(16, 16, 30)
local selectedGradientEnd   = Color3.fromRGB(30, 22, 50)
local selectedBgImageId     = ""

local stylePresetBtns   = {}
local titleBtnRefs     = {}
local selectedTitleBtn = nil

-- Root section frame (AutomaticSize Y — hides cleanly when Visible = false)
local passSection = Instance.new("Frame")
passSection.Name                   = "PassSection"
passSection.Size                   = UDim2.new(1, 0, 0, 0)
passSection.Position               = UDim2.new(0, 0, 0, yOffset)
passSection.BackgroundTransparency = 1
passSection.AutomaticSize          = Enum.AutomaticSize.Y
passSection.Visible                = false
passSection.Parent                 = formFrame

do
	local psListLayout = Instance.new("UIListLayout")
	psListLayout.Padding   = UDim.new(0, 8)
	psListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	psListLayout.Parent    = passSection
end

-- "Unlock features" link (shown when no passes owned)
local shopLink
do
	shopLink = Instance.new("TextButton")
	shopLink.Name = "ShopLink"
	shopLink.Size = UDim2.new(1, 0, 0, 36)
	shopLink.Position = UDim2.new(0, 0, 0, yOffset)
	shopLink.BackgroundColor3 = Color3.fromRGB(24, 22, 40)
	shopLink.BackgroundTransparency = 0.3
	shopLink.Text = utf8.char(0x1F6D2) .. "  Unlock more features in the Shop"
	shopLink.TextColor3 = Color3.fromRGB(138, 100, 214)
	shopLink.TextSize = 11
	shopLink.Font = Enum.Font.GothamBold
	shopLink.BorderSizePixel = 0
	shopLink.AutoButtonColor = false
	shopLink.Parent = formFrame
	Instance.new("UICorner", shopLink).CornerRadius = UDim.new(0, 10)
	local shopLinkStroke = Instance.new("UIStroke")
	shopLinkStroke.Color = Color3.fromRGB(138, 100, 214)
	shopLinkStroke.Transparency = 0.7
	shopLinkStroke.Thickness = 1
	shopLinkStroke.Parent = shopLink

	shopLink.MouseEnter:Connect(function()
		TweenService:Create(shopLink, TweenInfo.new(0.12), { BackgroundTransparency = 0.1 }):Play()
		TweenService:Create(shopLinkStroke, TweenInfo.new(0.12), { Transparency = 0.3 }):Play()
	end)
	shopLink.MouseLeave:Connect(function()
		TweenService:Create(shopLink, TweenInfo.new(0.12), { BackgroundTransparency = 0.3 }):Play()
		TweenService:Create(shopLinkStroke, TweenInfo.new(0.12), { Transparency = 0.7 }):Play()
	end)
	shopLink.MouseButton1Click:Connect(function()
		if _G.OpenShopGui then
			_G.OpenShopGui()
		end
	end)
end

-- Section header + VIP badge row
local vipRow
do
	local psHeader = Instance.new("TextLabel")
	psHeader.Size                   = UDim2.new(1, 0, 0, 14)
	psHeader.BackgroundTransparency = 1
	psHeader.Text                   = "PASS FEATURES"
	psHeader.TextColor3             = COLORS.textMuted
	psHeader.TextSize               = 10
	psHeader.Font                   = Enum.Font.GothamBold
	psHeader.TextXAlignment         = Enum.TextXAlignment.Left
	psHeader.LayoutOrder            = 0
	psHeader.Parent                 = passSection

	-- --- VIP badge row ---
	vipRow = Instance.new("Frame")
	vipRow.Name                   = "VIPRow"
	vipRow.Size                   = UDim2.new(1, 0, 0, 32)
	vipRow.BackgroundColor3       = Color3.fromRGB(255, 200, 55)
	vipRow.BackgroundTransparency = 0.82
	vipRow.BorderSizePixel        = 0
	vipRow.Visible                = false
	vipRow.LayoutOrder            = 1
	vipRow.Parent                 = passSection
	Instance.new("UICorner", vipRow).CornerRadius = UDim.new(0, 8)
	local vipRowS = Instance.new("UIStroke")
	vipRowS.Color = Color3.fromRGB(255, 200, 55); vipRowS.Transparency = 0.6; vipRowS.Thickness = 1
	vipRowS.Parent = vipRow
	local vipRowLbl = Instance.new("TextLabel")
	vipRowLbl.Size = UDim2.new(1, -12, 1, 0); vipRowLbl.Position = UDim2.new(0, 10, 0, 0)
	vipRowLbl.BackgroundTransparency = 1; vipRowLbl.Text = "★  [VIP] Chat Tag  •  Active"
	vipRowLbl.TextColor3 = Color3.fromRGB(255, 200, 55); vipRowLbl.TextSize = 11
	vipRowLbl.Font = Enum.Font.GothamBold; vipRowLbl.TextXAlignment = Enum.TextXAlignment.Left
	vipRowLbl.Parent = vipRow
end

-- --- Card Gradient section ---
local gradSection = Instance.new("Frame")
gradSection.Name                   = "GradSection"
gradSection.Size                   = UDim2.new(1, 0, 0, 0)
gradSection.BackgroundTransparency = 1
gradSection.AutomaticSize          = Enum.AutomaticSize.Y
gradSection.Visible                = false
gradSection.LayoutOrder            = 2
gradSection.Parent                 = passSection

local gradGrid
do
	local gsLayout = Instance.new("UIListLayout")
	gsLayout.Padding = UDim.new(0, 6); gsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gsLayout.Parent  = gradSection

	local gradHdr = Instance.new("TextLabel")
	gradHdr.Size = UDim2.new(1, 0, 0, 14); gradHdr.BackgroundTransparency = 1
	gradHdr.Text = "CARD STYLE"; gradHdr.TextColor3 = COLORS.textMuted
	gradHdr.TextSize = 10; gradHdr.Font = Enum.Font.GothamBold
	gradHdr.TextXAlignment = Enum.TextXAlignment.Left; gradHdr.LayoutOrder = 0
	gradHdr.Parent = gradSection

	gradGrid = Instance.new("Frame")
	gradGrid.Name = "GradGrid"; gradGrid.Size = UDim2.new(1, 0, 0, 0)
	gradGrid.BackgroundTransparency = 1; gradGrid.LayoutOrder = 1
	gradGrid.AutomaticSize = Enum.AutomaticSize.Y
	gradGrid.Parent = gradSection

	local gradGridLayout = Instance.new("UIGridLayout")
	gradGridLayout.CellSize              = UDim2.new(0.5, -5, 0, 36)
	gradGridLayout.CellPadding           = UDim2.new(0, 8, 0, 8)
	gradGridLayout.FillDirectionMaxCells = 2
	gradGridLayout.SortOrder             = Enum.SortOrder.LayoutOrder
	gradGridLayout.Parent                = gradGrid
end

-- Tracks the currently selected gradient index for checkmark
local selectedStyleIndex = nil

local function highlightStylePreset(index)
	selectedStyleIndex = index
	for gi, g in ipairs(stylePresetBtns) do
		local isMatch = (gi == index)
		TweenService:Create(g.stroke, TweenInfo.new(0.12), {
			Transparency = isMatch and 0.15 or 0.82,
			Color = isMatch and COLORS.accent or Color3.new(1,1,1),
		}):Play()
		-- Update checkmark
		if g.checkmark then
			g.checkmark.Visible = isMatch
		end
	end
end

for i, preset in ipairs(CARD_STYLES) do
	local btn = Instance.new("TextButton")
	btn.Name = preset.n
	btn.Size = UDim2.new(0.5, -5, 0, 36)
	btn.LayoutOrder = i
	btn.BackgroundColor3 = preset.s
	btn.Text = ""
	btn.BorderSizePixel = 0
	btn.AutoButtonColor = false
	btn.Parent = gradGrid
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new(preset.s, preset.e)
	bg.Rotation = 90
	bg.Parent = btn

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = preset.n
	lbl.TextColor3 = Color3.new(1, 1, 1)
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamBold
	lbl.ZIndex = 2
	lbl.Parent = btn

	-- Checkmark indicator (hidden by default)
	local checkLbl = Instance.new("TextLabel")
	checkLbl.Name = "Checkmark"
	checkLbl.Size = UDim2.fromOffset(18, 18)
	checkLbl.Position = UDim2.new(1, -6, 0.5, 0)
	checkLbl.AnchorPoint = Vector2.new(1, 0.5)
	checkLbl.BackgroundTransparency = 1
	checkLbl.Text = "✓"
	checkLbl.TextColor3 = Color3.new(1, 1, 1)
	checkLbl.TextSize = 14
	checkLbl.Font = Enum.Font.GothamBold
	checkLbl.ZIndex = 3
	checkLbl.Visible = false
	checkLbl.Parent = btn

	local bs = Instance.new("UIStroke")
	bs.Color = Color3.new(1, 1, 1)
	bs.Transparency = 0.82
	bs.Thickness = 1.5
	bs.Parent = btn

	-- Cursor glow gradient on preset stroke
	local presetStrokeGrad = Instance.new("UIGradient")
	presetStrokeGrad.Transparency = Config.GLOW_TRANSPARENCY
	presetStrokeGrad.Color = ColorSequence.new(preset.e)
	presetStrokeGrad.Parent = bs

	local presetRef = preset
	local bsRef     = bs
	stylePresetBtns[i] = { btn = btn, stroke = bs, preset = preset, checkmark = checkLbl }

	btn.MouseEnter:Connect(function()
		if selectedStyleIndex ~= i then
			TweenService:Create(bsRef, TweenInfo.new(0.1), { Transparency = 0.4 }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		if selectedStyleIndex ~= i then
			TweenService:Create(bsRef, TweenInfo.new(0.1), { Transparency = 0.82, Color = Color3.new(1,1,1) }):Play()
		end
	end)

	btn.MouseButton1Click:Connect(function()
		selectedGradientStart = presetRef.s
		selectedGradientEnd   = presetRef.e
		selectedBgImageId     = presetRef.img
		highlightStylePreset(i)
		if updatePreview then updatePreview() end
	end)
end

-- --- Custom Title section ---
local titleSection = Instance.new("Frame")
titleSection.Name = "TitleSection"; titleSection.Size = UDim2.new(1, 0, 0, 0)
titleSection.BackgroundTransparency = 1; titleSection.AutomaticSize = Enum.AutomaticSize.Y
titleSection.Visible = false; titleSection.LayoutOrder = 3
titleSection.Parent = passSection

local tsLayout = Instance.new("UIListLayout")
tsLayout.Padding = UDim.new(0, 6); tsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tsLayout.Parent  = titleSection

local titleHdr = Instance.new("TextLabel")
titleHdr.Size = UDim2.new(1, 0, 0, 14); titleHdr.BackgroundTransparency = 1
titleHdr.Text = "CUSTOM TITLE"; titleHdr.TextColor3 = COLORS.textMuted
titleHdr.TextSize = 10; titleHdr.Font = Enum.Font.GothamBold
titleHdr.TextXAlignment = Enum.TextXAlignment.Left; titleHdr.LayoutOrder = 0
titleHdr.Parent = titleSection

-- Current-title display row with pencil toggle
local titlePickerRow = Instance.new("Frame")
titlePickerRow.Size                   = UDim2.new(1, 0, 0, 36)
titlePickerRow.BackgroundColor3       = COLORS.input
titlePickerRow.BackgroundTransparency = 0
titlePickerRow.BorderSizePixel        = 0
titlePickerRow.LayoutOrder            = 1
titlePickerRow.Parent                 = titleSection
Instance.new("UICorner", titlePickerRow).CornerRadius = UDim.new(0, 8)
local tprStroke = Instance.new("UIStroke")
tprStroke.Color = COLORS.accent; tprStroke.Transparency = 0.8; tprStroke.Thickness = 1
tprStroke.Parent = titlePickerRow

local titleCurrentLbl = Instance.new("TextLabel")
titleCurrentLbl.Size                   = UDim2.new(1, -40, 1, 0)
titleCurrentLbl.Position               = UDim2.new(0, 10, 0, 0)
titleCurrentLbl.BackgroundTransparency = 1
titleCurrentLbl.Text                   = "None"
titleCurrentLbl.TextColor3             = COLORS.textDim
titleCurrentLbl.TextSize               = 12
titleCurrentLbl.Font                   = Enum.Font.GothamBold
titleCurrentLbl.TextXAlignment         = Enum.TextXAlignment.Left
titleCurrentLbl.Parent                 = titlePickerRow

local pencilBtn = Instance.new("TextButton")
pencilBtn.Size             = UDim2.new(0, 30, 0, 30)
pencilBtn.Position         = UDim2.new(1, -3, 0.5, 0)
pencilBtn.AnchorPoint      = Vector2.new(1, 0.5)
pencilBtn.BackgroundColor3 = COLORS.inputFocus
pencilBtn.Text             = "✏"
pencilBtn.TextSize         = 13
pencilBtn.TextColor3       = COLORS.accent
pencilBtn.Font             = Enum.Font.GothamBold
pencilBtn.BorderSizePixel  = 0
pencilBtn.Parent           = titlePickerRow
Instance.new("UICorner", pencilBtn).CornerRadius = UDim.new(0, 6)

-- Dropdown scrolling frame (hidden by default, shown when pencil clicked)
local titleDropdown = Instance.new("Frame")
titleDropdown.Size                   = UDim2.new(1, 0, 0, 0)
titleDropdown.BackgroundColor3       = COLORS.panel
titleDropdown.BackgroundTransparency = 0.1
titleDropdown.BorderSizePixel        = 0
titleDropdown.Visible                = false
titleDropdown.LayoutOrder            = 2
titleDropdown.ClipsDescendants       = true
titleDropdown.AutomaticSize          = Enum.AutomaticSize.Y
titleDropdown.Parent                 = titleSection
Instance.new("UICorner", titleDropdown).CornerRadius = UDim.new(0, 8)
local ddStroke = Instance.new("UIStroke")
ddStroke.Color = COLORS.accent; ddStroke.Transparency = 0.7; ddStroke.Thickness = 1
ddStroke.Parent = titleDropdown

local ddLayout = Instance.new("UIListLayout")
ddLayout.SortOrder = Enum.SortOrder.LayoutOrder
ddLayout.Padding   = UDim.new(0, 0)
ddLayout.Parent    = titleDropdown

local titleDropdownOpen = false

local function setTitleCurrentLabel(optName)
	-- Remove any existing gradient on the label
	local existingGrad = titleCurrentLbl:FindFirstChildOfClass("UIGradient")
	if existingGrad then existingGrad:Destroy() end

	if optName == "Use Tier" or optName == "None" or optName == "" then
		titleCurrentLbl.Text       = "Use Tier (auto)"
		titleCurrentLbl.TextColor3 = COLORS.accent
	else
		titleCurrentLbl.Text       = optName
		for _, o in ipairs(TITLE_OPTIONS) do
			if o.n == optName then
				titleCurrentLbl.TextColor3 = o.c[1]
				-- Apply gradient if multiple colors
				if #o.c >= 2 then
					local keypoints = {}
					for ci, col in ipairs(o.c) do
						table.insert(keypoints, ColorSequenceKeypoint.new((ci - 1) / (#o.c - 1), col))
					end
					local grad = Instance.new("UIGradient")
					grad.Color = ColorSequence.new(keypoints)
					grad.Parent = titleCurrentLbl
				end
				break
			end
		end
	end
end

local function toggleTitleDropdown(force)
	local shouldOpen = (force ~= nil) and force or (not titleDropdownOpen)
	titleDropdownOpen = shouldOpen
	titleDropdown.Visible = shouldOpen
	TweenService:Create(tprStroke, TweenInfo.new(0.12), {
		Transparency = shouldOpen and 0.35 or 0.8
	}):Play()
	TweenService:Create(pencilBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = shouldOpen and COLORS.accent or COLORS.inputFocus,
		TextColor3       = shouldOpen and Color3.new(1,1,1) or COLORS.accent,
	}):Play()
end

pencilBtn.MouseButton1Click:Connect(function() toggleTitleDropdown() end)

for i, opt in ipairs(TITLE_OPTIONS) do
	local ddRow = Instance.new("TextButton")
	ddRow.Name             = opt.n
	ddRow.Size             = UDim2.new(1, 0, 0, 34)
	ddRow.BackgroundColor3 = COLORS.input
	ddRow.BackgroundTransparency = 0.4
	ddRow.Text             = ""  -- we'll use a label with gradient instead
	ddRow.BorderSizePixel  = 0
	ddRow.AutoButtonColor  = false
	ddRow.LayoutOrder      = i
	ddRow.Parent           = titleDropdown

	-- Gradient text label inside the button
	local ddTextLbl = Instance.new("TextLabel")
	ddTextLbl.Size                   = UDim2.new(1, -12, 1, 0)
	ddTextLbl.Position               = UDim2.new(0, 6, 0, 0)
	ddTextLbl.BackgroundTransparency = 1
	ddTextLbl.Text                   = opt.n
	ddTextLbl.TextColor3             = opt.c[1]
	ddTextLbl.TextSize               = 12
	ddTextLbl.Font                   = Enum.Font.GothamBold
	ddTextLbl.TextXAlignment         = Enum.TextXAlignment.Left
	ddTextLbl.Parent                 = ddRow

	-- Apply gradient if multiple colors
	if #opt.c >= 2 then
		local keypoints = {}
		for ci, col in ipairs(opt.c) do
			table.insert(keypoints, ColorSequenceKeypoint.new((ci - 1) / (#opt.c - 1), col))
		end
		local ddTextGrad = Instance.new("UIGradient")
		ddTextGrad.Color = ColorSequence.new(keypoints)
		ddTextGrad.Rotation = 0
		ddTextGrad.Parent = ddTextLbl
	end

	-- Only round top/bottom corners on first/last
	if i == 1 then
		Instance.new("UICorner", ddRow).CornerRadius = UDim.new(0, 8)
	end

	local ddRowStroke = Instance.new("UIStroke")
	ddRowStroke.Color = opt.c[1]; ddRowStroke.Transparency = 0.9; ddRowStroke.Thickness = 1
	ddRowStroke.Parent = ddRow

	local optRef    = opt
	local ddStrkRef = ddRowStroke
	titleBtnRefs[i] = { btn = ddRow, stroke = ddRowStroke, opt = opt }

	ddRow.MouseEnter:Connect(function()
		TweenService:Create(ddRow, TweenInfo.new(0.1), { BackgroundTransparency = 0.1 }):Play()
	end)
	ddRow.MouseLeave:Connect(function()
		TweenService:Create(ddRow, TweenInfo.new(0.1), { BackgroundTransparency = 0.4 }):Play()
	end)

	ddRow.MouseButton1Click:Connect(function()
		-- "Use Tier" and "None" both clear the custom title (reverts to rep tier)
		local val = (optRef.isTierDefault or optRef.n == "None" or optRef.n == "Use Tier") and "" or optRef.n
		SetCustomTitleEvent:FireServer(val)
		player:SetAttribute("CustomTitle", val)

		-- Highlight selected row
		if selectedTitleBtn then
			TweenService:Create(selectedTitleBtn.stroke, TweenInfo.new(0.12), { Transparency = 0.9 }):Play()
			TweenService:Create(selectedTitleBtn.btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.4 }):Play()
		end
		selectedTitleBtn = { btn = ddRow, stroke = ddStrkRef }
		TweenService:Create(ddStrkRef, TweenInfo.new(0.12), { Transparency = 0.2 }):Play()
		TweenService:Create(ddRow, TweenInfo.new(0.12), { BackgroundTransparency = 0.05 }):Play()

		setTitleCurrentLabel(optRef.n)
		toggleTitleDropdown(false)  -- close after pick
	end)
end

-- Refresh visibility based on current pass ownership
local function refreshPassSection()
	local hasVIP   = player:GetAttribute("OwnsVIP")              == true
	local hasCard  = player:GetAttribute("OwnsCardCustomization") == true
	local hasTitle = player:GetAttribute("OwnsCustomTitle")       == true
	passSection.Visible  = hasVIP or hasCard or hasTitle
	vipRow.Visible       = hasVIP
	gradSection.Visible  = hasCard
	titleSection.Visible = hasTitle
	shopLink.Visible     = not passSection.Visible  -- show link when no passes owned

	-- Highlight whichever title is currently active and update label
	if hasTitle then
		local cur = player:GetAttribute("CustomTitle") or ""
		setTitleCurrentLabel(cur == "" and "Use Tier" or cur)
		for _, ref in ipairs(titleBtnRefs) do
			local match = (ref.opt.isTierDefault and cur == "") or (ref.opt.n == cur)
			if match then
				TweenService:Create(ref.stroke, TweenInfo.new(0.12), { Transparency = 0.2 }):Play()
				TweenService:Create(ref.btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.05 }):Play()
				selectedTitleBtn = ref
			else
				TweenService:Create(ref.stroke, TweenInfo.new(0.12), { Transparency = 0.9 }):Play()
				TweenService:Create(ref.btn, TweenInfo.new(0.12), { BackgroundTransparency = 0.4 }):Play()
			end
		end
	end
end

-- -------------------------------------------
-- SAVE BUTTON
-- -------------------------------------------
-- Save button — fixed at the very bottom of the editor panel (outside scroll)
local saveBtn = Instance.new("TextButton")
saveBtn.Name        = "Save"
saveBtn.Size        = UDim2.new(1, -48, 0, 40)
saveBtn.Position    = UDim2.new(0, 24, 1, -54)
saveBtn.AnchorPoint = Vector2.new(0, 0)
saveBtn.BackgroundColor3 = COLORS.accent
saveBtn.Text        = "SAVE"
saveBtn.TextSize    = 13
saveBtn.TextColor3  = Color3.new(1, 1, 1)
saveBtn.Font        = Enum.Font.GothamBold
saveBtn.ZIndex      = 10
saveBtn.Parent      = editorFrame

do
	local saveCorner = Instance.new("UICorner")
	saveCorner.CornerRadius = UDim.new(0, 10)
	saveCorner.Parent = saveBtn
end

local saveStroke = Instance.new("UIStroke")
saveStroke.Color = COLORS.accentLight
saveStroke.Transparency = 0.5
saveStroke.Thickness = 1
saveStroke.Parent = saveBtn

-- -------------------------------------------
-- PREVIEW UPDATE
-- -------------------------------------------
function updatePreview()
	local quoteText = formInputs.quote and formInputs.quote.Text or ""
	local data = {
		displayName = player.DisplayName,
		bio = formInputs.bio and formInputs.bio.Text or "",
		mood = selectedMood,
		quote = quoteText,
		favoriteColor   = { 138, 100, 214 },
		bgGradientStart = colorToTable(selectedGradientStart),
		bgGradientEnd   = colorToTable(selectedGradientEnd),
		bgImageId       = selectedBgImageId,
	}
	updateCardDisplay(previewCard, data, player.UserId)
end

print("[ProfileCardGui] Phase 4 OK - pass section + card styles + title section built")
-- ===========================================================================
-- OPEN / CLOSE EDITOR
-- ===========================================================================
local isEditorOpen = false

local function openEditor()
	if isEditorOpen then return end
	isEditorOpen = true
	editorFrame.Visible = true
	editorFrame.Size = EDITOR_SIZE_CLOSED
	editorFrame.BackgroundTransparency = 1
	tween(editorFrame, {
		Size = EDITOR_SIZE_OPEN,
		BackgroundTransparency = 0.02,
	}, 0.3)

	-- Load current data
	task.spawn(function()
		local currentData = RequestProfileCardFunc:InvokeServer(player.UserId)
		if currentData then
			if formInputs.bio then
				formInputs.bio.Text = currentData.bio or ""
			end
			if formInputs.quote then
				formInputs.quote.Text = currentData.quote or ""
			end
			selectedMood = currentData.mood or "Chill"
			for m, btn in pairs(moodButtons) do
				btn.BackgroundColor3 = (m == selectedMood) and COLORS.accent or COLORS.input
			end
			-- Restore saved gradient
			if currentData.bgGradientStart then
				selectedGradientStart = tableToColor(currentData.bgGradientStart)
				selectedGradientEnd   = tableToColor(currentData.bgGradientEnd or { 30, 22, 50 })
				-- Find and highlight matching preset using RGB comparison
				local matchIndex = nil
				for gi, g in ipairs(stylePresetBtns) do
					if colorsMatch(g.preset.s, selectedGradientStart) and colorsMatch(g.preset.e, selectedGradientEnd) then
						matchIndex = gi
						-- Always grab the img from the matched preset
						-- (handles old saves that didn't have bgImageId)
						selectedBgImageId = g.preset.img or ""
						break
					end
				end
				highlightStylePreset(matchIndex)
			end
			-- If server had a bgImageId saved, use that (overrides preset match)
			if currentData.bgImageId and currentData.bgImageId ~= "" then
				selectedBgImageId = currentData.bgImageId
			end
		else
			-- No saved data, defaults are fine
		end
		refreshPassSection()
		updatePreview()
	end)
end

local function closeEditor()
	if not isEditorOpen then return end
	isEditorOpen = false
	tween(editorFrame, {
		Size = EDITOR_SIZE_CLOSED,
		BackgroundTransparency = 1,
	}, 0.2)
	task.delay(0.22, function()
		if not isEditorOpen then
			editorFrame.Visible = false
		end
	end)
end

closeBtn.MouseButton1Click:Connect(closeEditor)

closeBtn.MouseEnter:Connect(function()
	tween(closeBtn, { BackgroundColor3 = Color3.fromRGB(180, 50, 50) })
end)
closeBtn.MouseLeave:Connect(function()
	tween(closeBtn, { BackgroundColor3 = COLORS.input })
end)

-- Save handler
saveBtn.MouseButton1Click:Connect(function()
	local quoteText = formInputs.quote and formInputs.quote.Text or ""
	local profileData = {
		displayName = player.DisplayName,
		bio = formInputs.bio and formInputs.bio.Text or "",
		mood = selectedMood,
		quote = quoteText,
		favoriteColor   = { 138, 100, 214 },
		bgGradientStart = colorToTable(selectedGradientStart),
		bgGradientEnd   = colorToTable(selectedGradientEnd),
		bgImageId       = selectedBgImageId,
		cardStyle = "default",
	}
	SaveProfileCardEvent:FireServer(profileData)

	-- Visual feedback
	saveBtn.Text = "SAVED!"
	tween(saveBtn, { BackgroundColor3 = COLORS.success }, 0.15)
	task.delay(1.5, function()
		saveBtn.Text = "SAVE"
		tween(saveBtn, { BackgroundColor3 = COLORS.accent }, 0.15)
	end)
end)

saveBtn.MouseEnter:Connect(function()
	tween(saveBtn, { BackgroundTransparency = 0.15 })
	tween(saveStroke, { Transparency = 0.2 })
end)
saveBtn.MouseLeave:Connect(function()
	tween(saveBtn, { BackgroundTransparency = 0 })
	tween(saveStroke, { Transparency = 0.5 })
end)

-- ===========================================================================
-- INITIALIZE VIEWER MODULE
-- ===========================================================================
local glowTargets = {}

-- Register style preset button strokes into glowTargets
for _, entry in ipairs(stylePresetBtns) do
	local presetGrad = entry.btn:FindFirstChildWhichIsA("UIStroke") and entry.btn:FindFirstChildWhichIsA("UIStroke"):FindFirstChildWhichIsA("UIGradient")
	if presetGrad then
		table.insert(glowTargets, { strokeGrad = presetGrad, element = entry.btn })
	end
end

-- Wait for viewer init function to be ready (published by ProfileCardViewer.luau)
while not _G._ProfileCardViewerInit do task.wait(0.05) end
local Viewer = _G._ProfileCardViewerInit({
	screenGui = screenGui,
	player = player,
	updateCardDisplay = updateCardDisplay,
	glowTargets = glowTargets,
	RequestProfileCardFunc = RequestProfileCardFunc,
	RequestReputationFunc = RequestReputationFunc,
	RequestRepCooldownFunc = RequestRepCooldownFunc,
	GiveReputationEvent = GiveReputationEvent,
	ReputationUpdatedEvent = ReputationUpdatedEvent,
	ProfileCardUpdatedEvent = ProfileCardUpdatedEvent,
	RepSounds = RepSounds,
	isEditorOpen = function() return isEditorOpen end,
})

-- ===========================================================================
-- CURSOR GLOW (unified RenderStepped for all glow targets)
-- ===========================================================================
RunService.RenderStepped:Connect(function()
	local mPos = UserInputService:GetMouseLocation()
	for _, entry in ipairs(glowTargets) do
		local el = entry.element
		if el.AbsoluteSize.X < 1 then continue end
		local ap = el.AbsolutePosition
		local as = el.AbsoluteSize
		local cx = ap.X + as.X * 0.5
		local cy = ap.Y + as.Y * 0.5
		local relX = (mPos.X - cx) / (as.X * 0.5)
		local relY = (mPos.Y - cy) / (as.Y * 0.5)
		local angle = math.deg(math.atan2(relY, relX))
		entry.strokeGrad.Rotation = angle
		entry.strokeGrad.Offset = Vector2.new(
			math.clamp(relX * 0.3, -0.5, 0.5),
			math.clamp(relY * 0.3, -0.5, 0.5)
		)
	end
end)

-- ===========================================================================
-- EYE BUTTON -> Viewer
-- ===========================================================================
eyeBtn.MouseButton1Click:Connect(function()
	Viewer.showCard(player.UserId)
end)

-- ===========================================================================
-- KEYBOARD SHORTCUT (P key)
-- ===========================================================================
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == TOGGLE_KEY then
		if Viewer.isViewerOpen() then return end
		if isEditorOpen then closeEditor() else openEditor() end
	end
end)

-- -------------------------------------------
-- PUBLIC API (via _G globals for FeaturesHubGui)
-- -------------------------------------------
_G.OpenProfileEditor = openEditor
_G.CloseProfileEditor = closeEditor

print("[ProfileCardGui] Profile card system initialized.")