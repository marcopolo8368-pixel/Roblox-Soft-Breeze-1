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

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
local RepSounds = ReplicatedStorage:WaitForChild("RepSounds")

local actionToSound = {
	thumbsUp = "ThumbsUp",
	thumbsDown = "ThumbsDown",
	love = "Love",
}

local function playRepSound(soundName, volume)
	local sound = RepSounds:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.Volume = volume or 0.6
		sound:Play()
	end
end

local function getSoundNameFromPayload(payload)
	if not payload then return nil end
	if type(payload.action) == "string" then
		return actionToSound[payload.action]
	end
	if payload.delta == 2 then return "Love" end
	if payload.delta == 1 then return "ThumbsUp" end
	if payload.delta == -1 then return "ThumbsDown" end
	return nil
end

-- -------------------------------------------
-- CONFIGURATION
-- -------------------------------------------
local TOGGLE_KEY = Enum.KeyCode.P
local DOUBLE_CLICK_TIME = 0.35

-- ─── RESPONSIVE HELPERS ───
local IS_SMALL_SCREEN, IS_MEDIUM_SCREEN
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
	IS_MEDIUM_SCREEN = not IS_SMALL_SCREEN and (vp.X < 1100 or vp.Y < 700)
end

local COLORS = {
	bg = Color3.fromRGB(8, 8, 16),
	panel = Color3.fromRGB(14, 14, 24),
	input = Color3.fromRGB(24, 24, 42),
	inputFocus = Color3.fromRGB(32, 32, 55),
	accent = Color3.fromRGB(138, 100, 214),
	accentLight = Color3.fromRGB(180, 140, 255),
	accentDark = Color3.fromRGB(90, 60, 160),
	text = Color3.fromRGB(230, 230, 245),
	textDim = Color3.fromRGB(100, 100, 135),
	textMuted = Color3.fromRGB(70, 70, 95),
	success = Color3.fromRGB(80, 200, 120),
	cardBg1 = Color3.fromRGB(16, 16, 30),
	cardBg2 = Color3.fromRGB(30, 22, 50),
}

local MOODS = { "Chill", "Happy", "Vibing", "Sad", "Tired", "Energetic", "Creative", "Thoughtful" }
local MOOD_SYMBOLS = {
	Chill = "😎", Happy = "😄", Vibing = "🎧", Sad = "😢",
	Tired = "😴", Energetic = "⚡", Creative = "🎨", Thoughtful = "🤔",
}

-- -------------------------------------------
-- HELPERS
-- -------------------------------------------
local function tween(instance, props, duration)
	TweenService:Create(instance, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function colorToTable(c3)
	return { math.floor(c3.R * 255), math.floor(c3.G * 255), math.floor(c3.B * 255) }
end

local function tableToColor(t)
	if type(t) == "table" and #t >= 3 then
		return Color3.fromRGB(t[1] or 138, t[2] or 100, t[3] or 214)
	end
	return Color3.fromRGB(138, 100, 214)
end

-- -------------------------------------------
-- SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProfileCardGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 7
screenGui.Parent = playerGui

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
	local symbol = MOOD_SYMBOLS[mood] or "🙂"
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
		if glow then glow.Color = favColor end
	end

	-- Accent bar color matches fav color
	local accentBar = card:FindFirstChild("AccentBar")
	if accentBar then accentBar.BackgroundColor3 = favColor end

	-- Card stroke color
	local cardStroke = card:FindFirstChild("CardStroke")
	if cardStroke then
		local sg = cardStroke:FindFirstChildOfClass("UIGradient")
		if sg then
			sg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, favColor),
				ColorSequenceKeypoint.new(0.5, COLORS.accentLight),
				ColorSequenceKeypoint.new(1, favColor),
			})
		end
	end

	local gradStart = tableToColor(data.bgGradientStart)
	local gradEnd = tableToColor(data.bgGradientEnd)
	card:FindFirstChild("BgGradient").Color = ColorSequence.new(gradStart, gradEnd)

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
local EDITOR_SIZE_OPEN = IS_SMALL_SCREEN and UDim2.new(0.96, 0, 0.9, 0) or UDim2.new(0, 580, 0, 400)
local EDITOR_SIZE_CLOSED = IS_SMALL_SCREEN and UDim2.new(0.96, 0, 0, 10) or UDim2.new(0, 580, 0, 10)

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

-- Editor header
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

-- Close button (drawn X icon)
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = IS_SMALL_SCREEN and UDim2.new(0, 44, 0, 44) or UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -16, 0, 14)
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.BackgroundColor3 = COLORS.input
closeBtn.Text = ""
closeBtn.Parent = editorFrame

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

-- Content parent (ScrollingFrame on mobile, editorFrame on desktop)
local editorContentParent = editorFrame
if IS_SMALL_SCREEN then
	local editorScroll = Instance.new("ScrollingFrame")
	editorScroll.Name = "EditorScroll"
	editorScroll.Size = UDim2.new(1, 0, 1, -100)
	editorScroll.Position = UDim2.new(0, 0, 0, 50)
	editorScroll.BackgroundTransparency = 1
	editorScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editorScroll.ScrollBarThickness = 3
	editorScroll.ScrollBarImageColor3 = COLORS.accent
	editorScroll.BorderSizePixel = 0
	editorScroll.ClipsDescendants = true
	editorScroll.Parent = editorFrame
	local scrollPad = Instance.new("UIPadding")
	scrollPad.PaddingBottom = UDim.new(0, 20)
	scrollPad.Parent = editorScroll
	editorContentParent = editorScroll
end

-- Form fields & card preview
local formFrame = Instance.new("Frame")
formFrame.Name = "FormFields"
formFrame.BackgroundTransparency = 1

local previewCard
if IS_SMALL_SCREEN then
	-- Mobile: single-column layout — preview card on top, form below
	local CARD_SCALE = 0.65
	local cardVisH = math.ceil(320 * CARD_SCALE)

	local cardWrapper = Instance.new("Frame")
	cardWrapper.Name = "CardPreviewWrapper"
	cardWrapper.Size = UDim2.new(1, 0, 0, cardVisH + 8)
	cardWrapper.Position = UDim2.new(0, 0, 0, 0)
	cardWrapper.BackgroundTransparency = 1
	cardWrapper.ClipsDescendants = false
	cardWrapper.Parent = editorContentParent

	previewCard = createCardDisplay(cardWrapper, UDim2.new(0, 230, 0, 320), UDim2.new(0.5, 0, 0.5, 0))
	Instance.new("UIScale", previewCard).Scale = CARD_SCALE

	formFrame.Size = UDim2.new(1, -24, 0, 420)
	formFrame.Position = UDim2.new(0, 12, 0, cardVisH + 16)
	formFrame.Parent = editorContentParent
else
	-- Desktop: side-by-side layout
	formFrame.Size = UDim2.new(0, 300, 0, 320)
	formFrame.Position = UDim2.new(0, 24, 0, 56)
	formFrame.Parent = editorFrame
	previewCard = createCardDisplay(editorFrame, UDim2.new(0, 210, 0, 300), UDim2.new(1, -135, 0.5, 14))
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
createFormField("Display Name", "displayName", "Your name...", 30)
createFormField("Bio", "bio", "Tell us about yourself...", 100, true)
if not IS_SMALL_SCREEN then
	createFormField("Favorite Quote", "quote", "Your favorite quote...", 60)
end

-- Mood selector
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
local moodColumns = IS_SMALL_SCREEN and 2 or 4
local moodRows = math.ceil(#MOODS / moodColumns)
local moodCellHeight = IS_SMALL_SCREEN and 34 or 26
local moodGapX = IS_SMALL_SCREEN and 8 or 5
local moodGapY = IS_SMALL_SCREEN and 8 or 4
local moodContainerHeight = (moodRows * moodCellHeight) + ((moodRows - 1) * moodGapY)

moodContainer.Size = UDim2.new(1, 0, 0, moodContainerHeight)
moodContainer.Position = UDim2.new(0, 0, 0, yOffset)
moodContainer.BackgroundTransparency = 1
moodContainer.Parent = formFrame

local moodGrid = Instance.new("UIGridLayout")
moodGrid.CellPadding = UDim2.new(0, moodGapX, 0, moodGapY)
if IS_SMALL_SCREEN then
	moodGrid.CellSize = UDim2.new(0.5, -(moodGapX / 2), 0, moodCellHeight)
else
	moodGrid.CellSize = UDim2.new(0, 70, 0, moodCellHeight)
end
moodGrid.FillDirectionMaxCells = moodColumns
moodGrid.HorizontalAlignment = Enum.HorizontalAlignment.Left
moodGrid.SortOrder = Enum.SortOrder.LayoutOrder
moodGrid.Parent = moodContainer

local moodButtons = {}
local selectedMood = "Chill"

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

-- -------------------------------------------
-- SAVE BUTTON
-- -------------------------------------------
local saveBtn = Instance.new("TextButton")
saveBtn.Name = "Save"
if IS_SMALL_SCREEN then
	saveBtn.Size = UDim2.new(0.5, 0, 0, 44)
	saveBtn.Position = UDim2.new(0.5, 0, 1, -6)
	saveBtn.AnchorPoint = Vector2.new(0.5, 1)
else
	saveBtn.Size = UDim2.new(0, 110, 0, 36)
	saveBtn.Position = UDim2.new(0, 24, 1, -22)
	saveBtn.AnchorPoint = Vector2.new(0, 1)
end
saveBtn.BackgroundColor3 = COLORS.accent
saveBtn.Text = "SAVE"
saveBtn.TextSize = 13
saveBtn.TextColor3 = Color3.new(1, 1, 1)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.Parent = editorFrame

local saveCorner = Instance.new("UICorner")
saveCorner.CornerRadius = UDim.new(0, 10)
saveCorner.Parent = saveBtn

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
		displayName = formInputs.displayName.Text ~= "" and formInputs.displayName.Text or player.DisplayName,
		bio = formInputs.bio.Text,
		mood = selectedMood,
		quote = quoteText,
		favoriteColor = { 138, 100, 214 },
		bgGradientStart = { 16, 16, 30 },
		bgGradientEnd = { 30, 22, 50 },
	}
	updateCardDisplay(previewCard, data, player.UserId)
end

-- ===========================================================================
-- VIEWER  –  single unified glass panel (complete redesign)
-- ===========================================================================
-- ── viewport metrics ───────────────────────────────────────────────────
local _vp  = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
	or Vector2.new(1920, 1080)
local _VW  = _vp.X
local _VH  = _vp.Y

-- ── panel dimensions ───────────────────────────────────────────────────
local PNLW   = IS_SMALL_SCREEN
	and math.clamp(math.floor(_VW * 0.56), 210, 280)
	or  292
local AVTR   = IS_SMALL_SCREEN and 72 or 86   -- avatar diameter px
local BTN_H  = IS_SMALL_SCREEN and 40 or 42

-- Y-positions computed top-down so nothing ever overlaps
local _AVY  = 22
local _NMY  = _AVY  + AVTR  + 8
local _NMH  = IS_SMALL_SCREEN and 20 or 22
local _MOY  = _NMY  + _NMH  + 4
local _MOH  = IS_SMALL_SCREEN and 24 or 26
local _D1Y  = _MOY  + _MOH  + 10        -- divider
local _BIOY = _D1Y  + 10                -- bio
local _BIOH = IS_SMALL_SCREEN and 44 or 52
local _SIGY = _BIOY + _BIOH + 8         -- rep separator
local _RTIY = _SIGY + 12                -- rep title
local _RTIH = IS_SMALL_SCREEN and 16 or 18
local _BARY = _RTIY + _RTIH + 8         -- progress bar
local _BARH = IS_SMALL_SCREEN and 7 or 8
local _NTLY = _BARY + _BARH + 5         -- next-tier label
local _NTLH = 12
local _BTHY = _NTLY + _NTLH + 10        -- buttons
local _STSY = _BTHY + BTN_H + 7         -- status
local _STSH = 16
local _PNLH = _STSY + _STSH + 14        -- total panel height

-- ── scrim (barely-there, keeps world visible) ──────────────────────────
local viewerOverlay = Instance.new("Frame")
viewerOverlay.Name              = "ViewerOverlay"
viewerOverlay.Size              = UDim2.new(1, 0, 1, 0)
viewerOverlay.BackgroundColor3  = Color3.fromRGB(4, 4, 10)
viewerOverlay.BackgroundTransparency = 1
viewerOverlay.Visible           = false
viewerOverlay.ZIndex            = 50
viewerOverlay.Parent            = screenGui

-- tapping anywhere outside the panel closes it
local viewerCloseBtn = Instance.new("TextButton")
viewerCloseBtn.Size                  = UDim2.new(1, 0, 1, 0)
viewerCloseBtn.BackgroundTransparency = 1
viewerCloseBtn.Text                  = ""
viewerCloseBtn.ZIndex                = 50
viewerCloseBtn.Parent                = viewerOverlay

-- ── main unified glass panel ───────────────────────────────────────────
-- PC  → anchored to the left edge, vertically centered
-- Mobile → centered, nudged slightly above mid for thumb reach
local profilePanel = Instance.new("Frame")
profilePanel.Name          = "ProfilePanel"
profilePanel.Size          = UDim2.fromOffset(PNLW, _PNLH)
if IS_SMALL_SCREEN then
	profilePanel.Position = UDim2.new(0, 14, 0.47, 0)
	profilePanel.AnchorPoint = Vector2.new(0, 0.5)
else
	profilePanel.Position = UDim2.new(0, 44, 0.5, 0)
	profilePanel.AnchorPoint = Vector2.new(0, 0.5)
end
profilePanel.BackgroundColor3 = Color3.fromRGB(10, 10, 19)
profilePanel.ClipsDescendants = false
profilePanel.ZIndex           = 51
profilePanel.Parent           = viewerOverlay

local profilePanelScale = Instance.new("UIScale")
profilePanelScale.Scale = IS_SMALL_SCREEN and 0.9 or 0.93
profilePanelScale.Parent = profilePanel

Instance.new("UICorner", profilePanel).CornerRadius = UDim.new(0, 22)

-- background gradient   (named BgGradient for updateCardDisplay compat)
local _grad = Instance.new("UIGradient")
_grad.Name     = "BgGradient"
_grad.Rotation = 162
_grad.Color    = ColorSequence.new(
	Color3.fromRGB(13, 13, 24),
	Color3.fromRGB(24, 14, 42)
)
_grad.Parent = profilePanel

-- border glow stroke   (named CardStroke for updateCardDisplay compat)
local _stroke = Instance.new("UIStroke")
_stroke.Name        = "CardStroke"
_stroke.Thickness   = 1.5
_stroke.Transparency = 0.5
_stroke.Color       = COLORS.accent
_stroke.Parent      = profilePanel

local _strokeGrad = Instance.new("UIGradient")
_strokeGrad.Rotation = 135
_strokeGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0,   COLORS.accent),
	ColorSequenceKeypoint.new(0.5, COLORS.accentLight),
	ColorSequenceKeypoint.new(1,   COLORS.accentDark),
})
_strokeGrad.Parent = _stroke

-- AccentBar: invisible, kept only so updateCardDisplay color sync still finds it
local _accentBar = Instance.new("Frame")
_accentBar.Name               = "AccentBar"
_accentBar.Size               = UDim2.fromOffset(0, 0)
_accentBar.BackgroundTransparency = 1
_accentBar.ZIndex             = 50
_accentBar.Parent             = profilePanel

-- ── X close button (top-right of panel) ───────────────────────────────
local _xBtn = Instance.new("TextButton")
_xBtn.Name              = "XClose"
_xBtn.Size              = UDim2.fromOffset(28, 28)
_xBtn.Position          = UDim2.new(1, -10, 0, 10)
_xBtn.AnchorPoint       = Vector2.new(1, 0)
_xBtn.BackgroundColor3  = Color3.fromRGB(38, 32, 58)
_xBtn.BorderSizePixel   = 0
_xBtn.AutoButtonColor   = false
_xBtn.Text              = "✕"
_xBtn.TextColor3        = Color3.fromRGB(180, 170, 210)
_xBtn.TextSize          = 13
_xBtn.Font              = Enum.Font.GothamBold
_xBtn.ZIndex            = 57
_xBtn.Parent            = profilePanel
Instance.new("UICorner", _xBtn).CornerRadius = UDim.new(0, 14)

-- ── avatar ─────────────────────────────────────────────────────────────
local _avatarOuter = Instance.new("Frame")
_avatarOuter.Name               = "AvatarOuter"
_avatarOuter.Size               = UDim2.fromOffset(AVTR + 6, AVTR + 6)
_avatarOuter.Position           = UDim2.new(0.5, 0, 0, _AVY)
_avatarOuter.AnchorPoint        = Vector2.new(0.5, 0)
_avatarOuter.BackgroundTransparency = 1
_avatarOuter.ZIndex             = 52
_avatarOuter.Parent             = profilePanel
Instance.new("UICorner", _avatarOuter).CornerRadius = UDim.new(1, 0)

local _avatarGlow = Instance.new("UIStroke")
_avatarGlow.Name        = "AvatarGlow"
_avatarGlow.Color       = COLORS.accent
_avatarGlow.Thickness   = 3
_avatarGlow.Transparency = 0.18
_avatarGlow.Parent      = _avatarOuter

local _avatarImg = Instance.new("ImageLabel")
_avatarImg.Name        = "Avatar"
_avatarImg.Size        = UDim2.fromOffset(AVTR, AVTR)
_avatarImg.Position    = UDim2.new(0.5, 0, 0.5, 0)
_avatarImg.AnchorPoint = Vector2.new(0.5, 0.5)
_avatarImg.BackgroundColor3 = Color3.fromRGB(22, 18, 35)
_avatarImg.Image       = ""
_avatarImg.ZIndex      = 53
_avatarImg.Parent      = _avatarOuter
Instance.new("UICorner", _avatarImg).CornerRadius = UDim.new(1, 0)

-- ── display name ───────────────────────────────────────────────────────
local _nameLabel = Instance.new("TextLabel")
_nameLabel.Name               = "DisplayName"
_nameLabel.Size               = UDim2.new(1, -32, 0, _NMH)
_nameLabel.Position           = UDim2.new(0.5, 0, 0, _NMY)
_nameLabel.AnchorPoint        = Vector2.new(0.5, 0)
_nameLabel.BackgroundTransparency = 1
_nameLabel.Text               = "Player"
_nameLabel.TextColor3         = COLORS.text
_nameLabel.TextSize           = IS_SMALL_SCREEN and 17 or 19
_nameLabel.Font               = Enum.Font.GothamBold
_nameLabel.ZIndex             = 52
_nameLabel.Parent             = profilePanel

-- ── mood badge ─────────────────────────────────────────────────────────
local _moodBadge = Instance.new("Frame")
_moodBadge.Name               = "MoodBadge"
_moodBadge.Size               = UDim2.fromOffset(IS_SMALL_SCREEN and 112 or 126, _MOH)
_moodBadge.Position           = UDim2.new(0.5, 0, 0, _MOY)
_moodBadge.AnchorPoint        = Vector2.new(0.5, 0)
_moodBadge.BackgroundColor3   = COLORS.accent
_moodBadge.BackgroundTransparency = 0.55
_moodBadge.ZIndex             = 52
_moodBadge.Parent             = profilePanel
Instance.new("UICorner", _moodBadge).CornerRadius = UDim.new(1, 0)
local _ms = Instance.new("UIStroke")
_ms.Color = COLORS.accent; _ms.Transparency = 0.5; _ms.Thickness = 1
_ms.Parent = _moodBadge

local _moodLabel = Instance.new("TextLabel")
_moodLabel.Name               = "MoodText"
_moodLabel.Size               = UDim2.new(1, -8, 1, 0)
_moodLabel.BackgroundTransparency = 1
_moodLabel.Text               = "😎  Chill"
_moodLabel.TextColor3         = COLORS.text
_moodLabel.TextSize           = IS_SMALL_SCREEN and 11 or 12
_moodLabel.Font               = Enum.Font.GothamBold
_moodLabel.ZIndex             = 53
_moodLabel.Parent             = _moodBadge

-- ── thin divider ───────────────────────────────────────────────────────
local _div1 = Instance.new("Frame")
_div1.Name               = "Divider"
_div1.Size               = UDim2.new(0.5, 0, 0, 1)
_div1.Position           = UDim2.new(0.5, 0, 0, _D1Y)
_div1.AnchorPoint        = Vector2.new(0.5, 0)
_div1.BackgroundColor3   = COLORS.accent
_div1.BackgroundTransparency = 0.65
_div1.BorderSizePixel    = 0
_div1.ZIndex             = 52
_div1.Parent             = profilePanel

-- ── bio ────────────────────────────────────────────────────────────────
local _bio = Instance.new("TextLabel")
_bio.Name               = "Bio"
_bio.Size               = UDim2.new(1, -28, 0, _BIOH)
_bio.Position           = UDim2.new(0.5, 0, 0, _BIOY)
_bio.AnchorPoint        = Vector2.new(0.5, 0)
_bio.BackgroundTransparency = 1
_bio.Text               = ""
_bio.TextColor3         = COLORS.textDim
_bio.TextSize           = IS_SMALL_SCREEN and 11 or 12
_bio.Font               = Enum.Font.Gotham
_bio.TextWrapped        = true
_bio.TextYAlignment     = Enum.TextYAlignment.Top
_bio.ZIndex             = 52
_bio.Parent             = profilePanel

-- quote (PC only, small italic, tucked at bottom of bio area)
if not IS_SMALL_SCREEN then
	local _q = Instance.new("TextLabel")
	_q.Name               = "Quote"
	_q.Size               = UDim2.new(1, -28, 0, 18)
	_q.Position           = UDim2.new(0.5, 0, 0, _BIOY + _BIOH - 2)
	_q.AnchorPoint        = Vector2.new(0.5, 0)
	_q.BackgroundTransparency = 1
	_q.Text               = ""
	_q.TextColor3         = COLORS.accentLight
	_q.TextSize           = 10
	_q.Font               = Enum.Font.GothamMedium
	_q.TextWrapped        = true
	_q.ZIndex             = 52
	_q.Parent             = profilePanel
end

-- hidden dot for updateCardDisplay fav-color compat
local _favDot = Instance.new("Frame")
_favDot.Name               = "FavColorDot"
_favDot.Size               = UDim2.fromOffset(0, 0)
_favDot.BackgroundTransparency = 1
_favDot.ZIndex             = 50
_favDot.Parent             = profilePanel

-- ── rep section ────────────────────────────────────────────────────────
-- separator line
local _repSep = Instance.new("Frame")
_repSep.Name          = "RepSep"
_repSep.Size          = UDim2.new(1, 0, 0, 1)
_repSep.Position      = UDim2.new(0, 0, 0, _SIGY)
_repSep.BackgroundColor3 = Color3.fromRGB(36, 30, 56)
_repSep.BorderSizePixel = 0
_repSep.ZIndex        = 52
_repSep.Parent        = profilePanel

-- darker frosted backing under rep content
local _repBg = Instance.new("Frame")
_repBg.Name               = "RepBg"
_repBg.Size               = UDim2.new(1, 0, 0, _PNLH - _SIGY - 1)
_repBg.Position           = UDim2.new(0, 0, 0, _SIGY + 1)
_repBg.BackgroundColor3   = Color3.fromRGB(6, 6, 13)
_repBg.BackgroundTransparency = 0.38
_repBg.BorderSizePixel    = 0
_repBg.ZIndex             = 51
_repBg.Parent             = profilePanel
Instance.new("UICorner", _repBg).CornerRadius = UDim.new(0, 22)

-- Rep title  (tier | score)
local repTitleLabel = Instance.new("TextLabel")
repTitleLabel.Name               = "RepTitle"
repTitleLabel.Size               = UDim2.new(0.6, -8, 0, _RTIH)
repTitleLabel.Position           = UDim2.new(0, 14, 0, _RTIY)
repTitleLabel.BackgroundTransparency = 1
repTitleLabel.Text               = "Visitor  |  0 rep"
repTitleLabel.TextColor3         = COLORS.accent
repTitleLabel.TextSize           = IS_SMALL_SCREEN and 11 or 12
repTitleLabel.Font               = Enum.Font.GothamBold
repTitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
repTitleLabel.ZIndex             = 53
repTitleLabel.Parent             = profilePanel

-- progress bar
local repBarBg = Instance.new("Frame")
repBarBg.Name               = "RepBarBg"
repBarBg.Size               = UDim2.new(1, -28, 0, _BARH)
repBarBg.Position           = UDim2.new(0, 14, 0, _BARY)
repBarBg.BackgroundColor3   = Color3.fromRGB(28, 24, 44)
repBarBg.ZIndex             = 53
repBarBg.Parent             = profilePanel
Instance.new("UICorner", repBarBg).CornerRadius = UDim.new(1, 0)

local repBarFill = Instance.new("Frame")
repBarFill.Name             = "RepBarFill"
repBarFill.Size             = UDim2.new(0, 0, 1, 0)
repBarFill.BackgroundColor3 = COLORS.accent
repBarFill.ZIndex           = 54
repBarFill.Parent           = repBarBg
Instance.new("UICorner", repBarFill).CornerRadius = UDim.new(1, 0)

-- next tier
local nextTierLabel = Instance.new("TextLabel")
nextTierLabel.Name               = "NextTier"
nextTierLabel.Size               = UDim2.new(1, -28, 0, _NTLH)
nextTierLabel.Position           = UDim2.new(0, 14, 0, _NTLY)
nextTierLabel.BackgroundTransparency = 1
nextTierLabel.Text               = "Next tier at 25 rep"
nextTierLabel.TextColor3         = COLORS.textMuted
nextTierLabel.TextSize           = IS_SMALL_SCREEN and 9 or 10
nextTierLabel.Font               = Enum.Font.Gotham
nextTierLabel.TextXAlignment     = Enum.TextXAlignment.Left
nextTierLabel.ZIndex             = 53
nextTierLabel.Parent             = profilePanel

-- ── vote buttons  👍  ❤️  👎  (heart in the middle) ───────────────────
local repButtonRow = Instance.new("Frame")
repButtonRow.Name               = "RepButtons"
repButtonRow.Size               = UDim2.new(1, -28, 0, BTN_H)
repButtonRow.Position           = UDim2.new(0, 14, 0, _BTHY)
repButtonRow.BackgroundTransparency = 1
repButtonRow.ZIndex             = 53
repButtonRow.Parent             = profilePanel

local repBtnLayout = Instance.new("UIListLayout")
repBtnLayout.FillDirection      = Enum.FillDirection.Horizontal
repBtnLayout.SortOrder          = Enum.SortOrder.LayoutOrder
repBtnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
repBtnLayout.Padding            = UDim.new(0, 8)
repBtnLayout.Parent             = repButtonRow

local function createRepButton(label, color, order, parent)
	local btn = Instance.new("TextButton")
	btn.Size               = UDim2.new(1/3, -6, 1, 0)
	btn.BackgroundColor3   = color
	btn.BackgroundTransparency = 0.08
	btn.Text               = label
	btn.TextSize           = IS_SMALL_SCREEN and 18 or 15
	btn.TextColor3         = Color3.new(1, 1, 1)
	btn.Font               = Enum.Font.GothamBold
	btn.LayoutOrder        = order
	btn.ZIndex             = 54
	btn.Parent             = parent
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)
	local bs = Instance.new("UIStroke")
	bs.Color = color; bs.Transparency = 0.62; bs.Thickness = 1
	bs.Parent = btn
	return btn
end

local THUMBS_UP_COLOR   = Color3.fromRGB(68, 178, 100)
local THUMBS_DOWN_COLOR = Color3.fromRGB(200, 62, 62)
local LOVE_COLOR        = Color3.fromRGB(218, 65, 148)

-- layout order: 1 = 👍,  2 = ❤️ (middle),  3 = 👎
local thumbsUpBtn   = createRepButton("👍 +1", THUMBS_UP_COLOR,   1, repButtonRow)
local loveBtn       = createRepButton("❤️ +2", LOVE_COLOR,         2, repButtonRow)
local thumbsDownBtn = createRepButton("👎 −1", THUMBS_DOWN_COLOR, 3, repButtonRow)

-- ── status label ───────────────────────────────────────────────────────
local repStatusLabel = Instance.new("TextLabel")
repStatusLabel.Name               = "RepStatus"
repStatusLabel.Size               = UDim2.new(1, -28, 0, _STSH)
repStatusLabel.Position           = UDim2.new(0, 14, 0, _STSY)
repStatusLabel.BackgroundTransparency = 1
repStatusLabel.Text               = "Select a player"
repStatusLabel.TextColor3         = COLORS.textDim
repStatusLabel.TextSize           = IS_SMALL_SCREEN and 10 or 11
repStatusLabel.Font               = Enum.Font.Gotham
repStatusLabel.TextXAlignment     = Enum.TextXAlignment.Center
repStatusLabel.ZIndex             = 53
repStatusLabel.Parent             = profilePanel

-- ── aliases required by the functions that follow ─────────────────────
local repPanel       = profilePanel   -- flashRepPanel references repPanelStroke
local repPanelStroke = _stroke        -- UIStroke on the panel
local viewerCard     = profilePanel   -- updateCardDisplay(viewerCard, …)

-- ── X button wiring (pendingRepAction handled by viewerCloseBtn below) ─
local currentViewTargetUserId = nil

_xBtn.MouseButton1Click:Connect(function()
	currentViewTargetUserId = nil
	viewerOverlay.Visible = false
end)
_xBtn.MouseEnter:Connect(function()
	tween(_xBtn, { BackgroundColor3 = Color3.fromRGB(180, 48, 55) })
end)
_xBtn.MouseLeave:Connect(function()
	tween(_xBtn, { BackgroundColor3 = Color3.fromRGB(30, 26, 46) })
end)

local pendingRepAction = nil

local function formatCooldown(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", minutes)
end

local function setRepButtonsEnabled(enabled)
	local active = enabled == true
	for _, btn in ipairs({ thumbsUpBtn, thumbsDownBtn, loveBtn }) do
		btn.Active = active
		btn.AutoButtonColor = active
		btn.BackgroundTransparency = active and 0.1 or 0.55
	end
end

-- Store canonical button sizes to prevent pulse accumulation
local _repBtnSizes = {}
_repBtnSizes[thumbsUpBtn]   = thumbsUpBtn.Size
_repBtnSizes[loveBtn]       = loveBtn.Size
_repBtnSizes[thumbsDownBtn] = thumbsDownBtn.Size

local function pulseRepButton(btn)
	local base = _repBtnSizes[btn] or btn.Size
	tween(btn, { Size = UDim2.new(base.X.Scale, base.X.Offset + 6, base.Y.Scale, base.Y.Offset + 4) }, 0.08)
	task.delay(0.09, function()
		tween(btn, { Size = base }, 0.12)
	end)
end

local function flashRepPanel(color)
	tween(repPanelStroke, { Color = color, Transparency = 0.2 }, 0.08)
	task.delay(0.12, function()
		tween(repPanelStroke, { Color = COLORS.accent, Transparency = 0.7 }, 0.2)
	end)
end

local function refreshRepCooldownStatus()
	if not currentViewTargetUserId then
		setRepButtonsEnabled(false)
		return
	end

	if currentViewTargetUserId == player.UserId then
		if RunService:IsStudio() then
			repStatusLabel.Text = "🛠 Studio test — vote freely"
			repStatusLabel.TextColor3 = Color3.fromRGB(255, 185, 55)
			setRepButtonsEnabled(true)
			return
		end
		repStatusLabel.Text = "You can't rep yourself"
		repStatusLabel.TextColor3 = COLORS.textDim
		setRepButtonsEnabled(false)
		return
	end

	local ok, cooldownData = pcall(function()
		return RequestRepCooldownFunc:InvokeServer(currentViewTargetUserId)
	end)

	if not ok or type(cooldownData) ~= "table" then
		repStatusLabel.Text = "Rep unavailable"
		repStatusLabel.TextColor3 = COLORS.textDim
		setRepButtonsEnabled(false)
		return
	end

	if cooldownData.canVote then
		repStatusLabel.Text = "React to this player"
		repStatusLabel.TextColor3 = COLORS.textDim
		setRepButtonsEnabled(pendingRepAction == nil)
	else
		local remaining = cooldownData.remainingSeconds or 0
		repStatusLabel.Text = "Next rep in " .. formatCooldown(remaining)
		repStatusLabel.TextColor3 = COLORS.textDim
		setRepButtonsEnabled(false)
	end
end

setRepButtonsEnabled(false)
repStatusLabel.Text = "Select a player"
repStatusLabel.TextColor3 = COLORS.textDim

-- Function to update the rep display
local function updateRepDisplay(repData)
	if not repData then
		repTitleLabel.Text = "Visitor  |  0 rep"
		repBarFill.Size = UDim2.new(0, 0, 1, 0)
		nextTierLabel.Text = ""
		repStatusLabel.Text = "React to this player"
		repStatusLabel.TextColor3 = COLORS.textDim
		return
	end

	local score = repData.score or 0
	local title = repData.title or "Visitor"
	local tierColor = repData.tierColor
	local nextThreshold = repData.nextThreshold or 10
	local prevThreshold = repData.prevThreshold or 0

	repTitleLabel.Text = title .. "  |  " .. tostring(score) .. " rep"
	if tierColor and type(tierColor) == "table" then
		repTitleLabel.TextColor3 = Color3.fromRGB(tierColor[1] or 138, tierColor[2] or 100, tierColor[3] or 214)
		repBarFill.BackgroundColor3 = Color3.fromRGB(tierColor[1] or 138, tierColor[2] or 100, tierColor[3] or 214)
	end

	-- Progress bar
	local range = math.max(nextThreshold - prevThreshold, 1)
	local progress = math.clamp((score - prevThreshold) / range, 0, 1)
	tween(repBarFill, { Size = UDim2.new(progress, 0, 1, 0) }, 0.3)

	nextTierLabel.Text = "Next tier at " .. tostring(nextThreshold) .. " rep"
end

-- Rep button handlers
local function handleRepAction(action)
	if not currentViewTargetUserId then return end
	if currentViewTargetUserId == player.UserId and not RunService:IsStudio() then
		repStatusLabel.Text = "You can't rep yourself!"
		return
	end
	-- Don't overwrite the cooldown label or fire the server if buttons are on cooldown
	if not thumbsUpBtn.Active then return end
	if pendingRepAction then return end

	if action == "thumbsUp" then
		pulseRepButton(thumbsUpBtn)
	elseif action == "thumbsDown" then
		pulseRepButton(thumbsDownBtn)
	else
		pulseRepButton(loveBtn)
	end

	pendingRepAction = action
	repStatusLabel.Text = "Sending reaction..."
	repStatusLabel.TextColor3 = COLORS.textDim
	setRepButtonsEnabled(false)
	GiveReputationEvent:FireServer(currentViewTargetUserId, action)
end

thumbsUpBtn.MouseButton1Click:Connect(function() handleRepAction("thumbsUp") end)
thumbsDownBtn.MouseButton1Click:Connect(function() handleRepAction("thumbsDown") end)
loveBtn.MouseButton1Click:Connect(function() handleRepAction("love") end)

-- Listen for real-time rep updates
ReputationUpdatedEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end

	if payload.kind == "voteResult" then
		pendingRepAction = nil
		if payload.ok then
			local soundName = getSoundNameFromPayload(payload)
			if soundName then
				playRepSound(soundName, 0.6)
			end
			if payload.titleUpgraded then
				playRepSound("Love", 0.8)
			end
			repStatusLabel.Text = (payload.delta and payload.delta > 0) and "Reputation boosted!" or "Reaction sent"
			repStatusLabel.TextColor3 = COLORS.success
			flashRepPanel(COLORS.success)
			refreshRepCooldownStatus()
			if currentViewTargetUserId then
				task.spawn(function()
					local ok, repData = pcall(function()
						return RequestReputationFunc:InvokeServer(currentViewTargetUserId)
					end)
					if ok and repData then
						updateRepDisplay(repData)
					end
				end)
			end
		else
			if payload.reason == "Cooldown active" then
				repStatusLabel.Text = "Next rep in " .. formatCooldown(payload.remainingSeconds or 0)
			else
				repStatusLabel.Text = payload.reason or "Couldn't send reaction"
			end
			repStatusLabel.TextColor3 = Color3.fromRGB(220, 120, 120)
			flashRepPanel(Color3.fromRGB(220, 120, 120))
			refreshRepCooldownStatus()
		end
		return
	end

	if payload.kind == "receivedRep" then
		local soundName = getSoundNameFromPayload(payload)
		if soundName then
			playRepSound(soundName, 0.3)
		end
		if payload.titleUpgraded then
			playRepSound("Love", 0.8)
			flashRepPanel(COLORS.accentLight)
		end
		return
	end

	if currentViewTargetUserId and payload.userId == currentViewTargetUserId then
		updateRepDisplay(payload)
		refreshRepCooldownStatus()
	end
end)

viewerCloseBtn.MouseButton1Click:Connect(function()
	currentViewTargetUserId = nil
	pendingRepAction = nil
	setRepButtonsEnabled(false)
	viewerOverlay.Visible = false
end)

-- -------------------------------------------
-- OPEN / CLOSE EDITOR
-- -------------------------------------------
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
			formInputs.displayName.Text = currentData.displayName or player.DisplayName
			formInputs.bio.Text = currentData.bio or ""
			if formInputs.quote then
				formInputs.quote.Text = currentData.quote or ""
			end
			selectedMood = currentData.mood or "Chill"
			for m, btn in pairs(moodButtons) do
				btn.BackgroundColor3 = (m == selectedMood) and COLORS.accent or COLORS.input
			end
		else
			formInputs.displayName.Text = player.DisplayName
		end
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
		displayName = formInputs.displayName.Text ~= "" and formInputs.displayName.Text or player.DisplayName,
		bio = formInputs.bio.Text,
		mood = selectedMood,
		quote = quoteText,
		favoriteColor = { 138, 100, 214 },
		bgGradientStart = { 16, 16, 30 },
		bgGradientEnd = { 30, 22, 50 },
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

-- -------------------------------------------
-- HOVER GLOW ON PLAYER CHARACTERS
-- -------------------------------------------
local mouse = player:GetMouse()
local currentHighlight = nil
local currentHighlightChar = nil

RunService.RenderStepped:Connect(function()
	if isEditorOpen then return end

	local target = mouse.Target
	if not target then
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
			currentHighlightChar = nil
		end
		return
	end

	local character = nil
	local current = target
	for _ = 1, 5 do
		if not current then break end
		if current:FindFirstChildOfClass("Humanoid") then
			character = current
			break
		end
		current = current.Parent
	end

	local targetPlayer = character and Players:GetPlayerFromCharacter(character)

	if targetPlayer and targetPlayer ~= player then
		if currentHighlightChar ~= character then
			if currentHighlight then
				currentHighlight:Destroy()
			end

			local highlight = Instance.new("Highlight")
			highlight.Name = "ProfileHoverGlow"
			highlight.Adornee = character
			highlight.FillColor = COLORS.accent
			highlight.FillTransparency = 0.85
			highlight.OutlineColor = COLORS.accentLight
			highlight.OutlineTransparency = 0.3
			highlight.DepthMode = Enum.HighlightDepthMode.Occluded
			highlight.Parent = character

			currentHighlight = highlight
			currentHighlightChar = character
		end
	else
		if currentHighlight then
			currentHighlight:Destroy()
			currentHighlight = nil
			currentHighlightChar = nil
		end
	end
end)

-- -------------------------------------------
-- DOUBLE-CLICK TO VIEW CARD
-- -------------------------------------------
local lastClickTime = 0
local lastClickTarget = nil

mouse.Button1Down:Connect(function()
	if isEditorOpen then return end

	local target = mouse.Target
	if not target then return end

	local character = nil
	local current = target
	for _ = 1, 5 do
		if not current then break end
		if current:FindFirstChildOfClass("Humanoid") then
			character = current
			break
		end
		current = current.Parent
	end

	if not character then return end

	local targetPlayer = Players:GetPlayerFromCharacter(character)
	if not targetPlayer or targetPlayer == player then return end

	local now = tick()
	if lastClickTarget == character and (now - lastClickTime) < DOUBLE_CLICK_TIME then
		lastClickTime = 0
		lastClickTarget = nil

		task.spawn(function()
			local cardData = RequestProfileCardFunc:InvokeServer(targetPlayer.UserId)
			if cardData then
				currentViewTargetUserId = targetPlayer.UserId
				pendingRepAction = nil
				updateCardDisplay(viewerCard, cardData, targetPlayer.UserId)
				setRepButtonsEnabled(false)
				repStatusLabel.Text = "Loading reputation..."
				repStatusLabel.TextColor3 = COLORS.textDim

				local ok, repData = pcall(function()
					return RequestReputationFunc:InvokeServer(targetPlayer.UserId)
				end)
				if ok and repData then
					updateRepDisplay(repData)
				else
					updateRepDisplay(nil)
				end
				refreshRepCooldownStatus()
				viewerOverlay.Visible = true
			end
		end)
	else
		lastClickTime = now
		lastClickTarget = character
	end
end)

-- Listen for real-time profile updates
ProfileCardUpdatedEvent.OnClientEvent:Connect(function(userId, data)
	if viewerOverlay.Visible and currentViewTargetUserId == userId then
		updateCardDisplay(viewerCard, data, userId)
	end
end)

-- -------------------------------------------
-- STUDIO DEBUG BUTTON  (only visible in Studio)
-- -------------------------------------------
if RunService:IsStudio() then
	local dbgBtn = Instance.new("TextButton")
	dbgBtn.Name             = "StudioDebugCard"
	dbgBtn.Size             = UDim2.fromOffset(180, 38)
	dbgBtn.Position         = UDim2.new(0, 12, 1, -12)
	dbgBtn.AnchorPoint      = Vector2.new(0, 1)
	dbgBtn.BackgroundColor3 = Color3.fromRGB(48, 36, 80)
	dbgBtn.BorderSizePixel  = 0
	dbgBtn.AutoButtonColor  = false
	dbgBtn.Text             = "🛠  View My Card (Studio)"
	dbgBtn.TextSize         = 12
	dbgBtn.TextColor3       = Color3.fromRGB(255, 210, 100)
	dbgBtn.Font             = Enum.Font.GothamBold
	dbgBtn.ZIndex           = 10
	dbgBtn.Parent           = screenGui
	Instance.new("UICorner", dbgBtn).CornerRadius = UDim.new(0, 10)

	local dbgStroke = Instance.new("UIStroke")
	dbgStroke.Color       = Color3.fromRGB(180, 130, 255)
	dbgStroke.Transparency = 0.55
	dbgStroke.Thickness   = 1
	dbgStroke.Parent      = dbgBtn

	dbgBtn.MouseButton1Click:Connect(function()
		task.spawn(function()
			local cardData = RequestProfileCardFunc:InvokeServer(player.UserId)
			if not cardData then
				-- build minimal fallback so the viewer still opens
				cardData = {
					displayName = player.DisplayName,
					bio = "(no card saved yet)",
					mood = "Chill",
					quote = "",
					favoriteColor = { 138, 100, 214 },
					bgGradientStart = { 16, 16, 30 },
					bgGradientEnd = { 30, 22, 50 },
				}
			end
			currentViewTargetUserId = player.UserId
			pendingRepAction = nil
			updateCardDisplay(viewerCard, cardData, player.UserId)
			setRepButtonsEnabled(false)
			repStatusLabel.Text = "Loading reputation..."
			repStatusLabel.TextColor3 = COLORS.textDim

			local ok, repData = pcall(function()
				return RequestReputationFunc:InvokeServer(player.UserId)
			end)
			if ok and repData then
				updateRepDisplay(repData)
			else
				updateRepDisplay(nil)
			end
			refreshRepCooldownStatus()
			viewerOverlay.Visible = true
		end)
	end)

	dbgBtn.MouseEnter:Connect(function()
		tween(dbgBtn, { BackgroundColor3 = Color3.fromRGB(72, 52, 120) })
	end)
	dbgBtn.MouseLeave:Connect(function()
		tween(dbgBtn, { BackgroundColor3 = Color3.fromRGB(48, 36, 80) })
	end)
end

-- -------------------------------------------
-- PUBLIC API (via _G globals for FeaturesHubGui)
-- -------------------------------------------
_G.OpenProfileEditor = openEditor
_G.CloseProfileEditor = closeEditor

print("[ProfileCardGui] Profile card system initialized. Double-click/tap players to view.")