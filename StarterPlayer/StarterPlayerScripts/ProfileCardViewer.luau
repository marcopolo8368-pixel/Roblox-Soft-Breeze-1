--[[
    ProfileCardViewer.luau  (LocalScript)
    Viewer overlay, rep display, hover glow, double-click-to-view,
    studio debug button, and profile update listener.
    Publishes via _G._ProfileCardViewer so ProfileCardGui can access it.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Wait for config to be ready
while not _G._ProfileCardConfig do task.wait(0.05) end
local Config = _G._ProfileCardConfig

local COLORS = Config.COLORS
local EMOJI = Config.EMOJI
local MOOD_SYMBOLS = Config.MOOD_SYMBOLS
local IS_SMALL_SCREEN = Config.IS_SMALL_SCREEN
local DOUBLE_CLICK_TIME = Config.DOUBLE_CLICK_TIME
local GLOW_TRANSPARENCY = Config.GLOW_TRANSPARENCY
local tween = Config.tween

-- Sound helpers
local actionToSound = {
	thumbsUp = "ThumbsUp",
	thumbsDown = "ThumbsDown",
	love = "Love",
}

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

local function playRepSound(RepSounds, soundName, volume)
	local sound = RepSounds:FindFirstChild(soundName)
	if sound and sound:IsA("Sound") then
		sound.Volume = volume or 0.6
		sound:Play()
	end
end

-- No-op: text shadow removed for cleaner look
local function addTextShadow(_label) end

local module = {}

function module.init(deps)
	local screenGui = deps.screenGui
	local player = deps.player
	local updateCardDisplay = deps.updateCardDisplay
	local glowTargets = deps.glowTargets
	local RequestProfileCardFunc = deps.RequestProfileCardFunc
	local RequestReputationFunc = deps.RequestReputationFunc
	local RequestRepCooldownFunc = deps.RequestRepCooldownFunc
	local GiveReputationEvent = deps.GiveReputationEvent
	local ReputationUpdatedEvent = deps.ReputationUpdatedEvent
	local ProfileCardUpdatedEvent = deps.ProfileCardUpdatedEvent
	local RepSounds = deps.RepSounds
	local isEditorOpen = deps.isEditorOpen

	-- ===================================================================
	-- PANEL METRICS
	-- ===================================================================
	local PNLW, AVTR, BTN_H, CORNER
	do
		local _vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
			or Vector2.new(1920, 1080)
		PNLW = IS_SMALL_SCREEN
			and math.clamp(math.floor(_vp.X * 0.62), 240, 300)
			or 340
		AVTR   = IS_SMALL_SCREEN and 78 or 96
		BTN_H  = IS_SMALL_SCREEN and 38 or 42
		CORNER = 18
	end

	-- Vertical layout positions
	local _BNR_H = IS_SMALL_SCREEN and 110 or 135
	local _AVY   = _BNR_H - math.floor(AVTR / 2)
	local _CTY   = _BNR_H + math.floor(AVTR / 2) + 10
	local _NMH   = IS_SMALL_SCREEN and 22 or 26
	local _TSH   = 14
	local _MOH   = IS_SMALL_SCREEN and 24 or 28
	local _BIOH  = IS_SMALL_SCREEN and 40 or 50
	local _QTH   = 16
	local _NMY   = _CTY
	local _TSY   = _NMY + _NMH + 2
	local _MOY   = _TSY + _TSH + 8
	local _DVY   = _MOY + _MOH + 12
	local _BIOY  = _DVY + 12
	local _QTY   = _BIOY + _BIOH + 4
	local _RSEPY = IS_SMALL_SCREEN and (_BIOY + _BIOH + 12) or (_QTY + _QTH + 14)
	local _RTIY  = _RSEPY + 16
	local _RTIH  = IS_SMALL_SCREEN and 14 or 16
	local _BARY  = _RTIY + _RTIH + 8
	local _BARH  = IS_SMALL_SCREEN and 5 or 6
	local _NTLY  = _BARY + _BARH + 6
	local _NTLH  = 12
	local _BTHY  = _NTLY + _NTLH + 12
	local _STSY  = _BTHY + BTN_H + 8
	local _STSH  = IS_SMALL_SCREEN and 13 or 14
	local _PNLH  = _STSY + _STSH + 18

	-- ===================================================================
	-- OVERLAY (fully transparent container)
	-- ===================================================================
	local viewerOverlay = Instance.new("Frame")
	viewerOverlay.Name                   = "ViewerOverlay"
	viewerOverlay.Size                   = UDim2.new(1, 0, 1, 0)
	viewerOverlay.BackgroundTransparency = 1
	viewerOverlay.Visible                = false
	viewerOverlay.ZIndex                 = 50
	viewerOverlay.Parent                 = screenGui

	-- ===================================================================
	-- DROP SHADOW (small, centered behind card)
	-- ===================================================================
	local _shadow = Instance.new("Frame")
	_shadow.Name                   = "DropShadow"
	_shadow.Size                   = UDim2.fromOffset(PNLW + 4, _PNLH + 4)
	_shadow.Position               = UDim2.new(0.5, 0, 0.5, 0)
	_shadow.AnchorPoint            = Vector2.new(0.5, 0.5)
	_shadow.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	_shadow.BackgroundTransparency = 0.75
	_shadow.ZIndex                 = 50
	_shadow.Parent                 = viewerOverlay
	Instance.new("UICorner", _shadow).CornerRadius = UDim.new(0, CORNER + 1)

	-- ===================================================================
	-- MAIN PANEL (centered on screen)
	-- ===================================================================
	local profilePanel = Instance.new("Frame")
	profilePanel.Name              = "ProfilePanel"
	profilePanel.Size              = UDim2.fromOffset(PNLW, _PNLH)
	profilePanel.Position          = UDim2.new(0.5, 0, 0.5, 0)
	profilePanel.AnchorPoint       = Vector2.new(0.5, 0.5)
	profilePanel.BackgroundColor3     = Color3.fromRGB(12, 10, 22)
	profilePanel.ClipsDescendants     = true
	profilePanel.ZIndex               = 51
	profilePanel.Parent               = viewerOverlay

	local panelScale = Instance.new("UIScale")
	panelScale.Scale  = 0
	panelScale.Parent = profilePanel

	Instance.new("UICorner", profilePanel).CornerRadius = UDim.new(0, CORNER)

	-- ===== BASE GRADIENT (fallback when no bg image) =====
	local _bgGrad = Instance.new("UIGradient")
	_bgGrad.Name     = "BgGradient"
	_bgGrad.Rotation = 155
	_bgGrad.Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(22, 18, 45)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 22, 58)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(16, 12, 32)),
	})
	_bgGrad.Parent = profilePanel

	-- ===== BACKGROUND IMAGE (full card background) =====
	local _bgImage = Instance.new("ImageLabel")
	_bgImage.Name                   = "BgImage"
	_bgImage.Size                   = UDim2.new(1, 0, 1, 0)
	_bgImage.BackgroundTransparency = 1
	_bgImage.ImageTransparency      = 1
	_bgImage.ScaleType              = Enum.ScaleType.Crop
	_bgImage.ZIndex                 = 52
	_bgImage.Parent                 = profilePanel
	Instance.new("UICorner", _bgImage).CornerRadius = UDim.new(0, CORNER)

	-- ===== STYLE OVERLAY (compat element — hidden, used by updateCardDisplay) =====
	local _styleOverlay = Instance.new("Frame")
	_styleOverlay.Name                   = "StyleOverlay"
	_styleOverlay.Size                   = UDim2.fromOffset(0, 0)
	_styleOverlay.BackgroundTransparency = 1
	_styleOverlay.ZIndex                 = 50
	_styleOverlay.Parent                 = profilePanel
	do
		local _styleGrad = Instance.new("UIGradient")
		_styleGrad.Name   = "StyleGradient"
		_styleGrad.Parent = _styleOverlay
	end

	-- (glass panels removed — clean look, no boxes)

	-- ===== CARD BORDER (cursor-tracking theme-colored glow) =====
	local _stroke = Instance.new("UIStroke")
	_stroke.Name         = "CardStroke"
	_stroke.Thickness    = 4
	_stroke.Transparency = 0
	_stroke.Color        = Color3.new(1, 1, 1)
	_stroke.Parent       = profilePanel

	-- Visible all around (0.45 base) with bright cursor hotspot (0.0)
	local _cardGlowTransparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0,    0.55),
		NumberSequenceKeypoint.new(0.25, 0.4),
		NumberSequenceKeypoint.new(0.5,  0.0),
		NumberSequenceKeypoint.new(0.75, 0.4),
		NumberSequenceKeypoint.new(1,    0.55),
	})

	local _strokeGrad = Instance.new("UIGradient")
	_strokeGrad.Transparency = _cardGlowTransparency
	_strokeGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   COLORS.accentLight),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1,   COLORS.accentLight),
	})
	_strokeGrad.Rotation = 0
	_strokeGrad.Parent   = _stroke

	table.insert(glowTargets, { strokeGrad = _strokeGrad, element = profilePanel })

	-- ===== HIDDEN COMPAT ELEMENTS =====
	do
		local _ab = Instance.new("Frame")
		_ab.Name = "AccentBar"; _ab.Size = UDim2.fromOffset(0, 0)
		_ab.BackgroundTransparency = 1; _ab.ZIndex = 50; _ab.Parent = profilePanel

		local _fd = Instance.new("Frame")
		_fd.Name = "FavColorDot"; _fd.Size = UDim2.fromOffset(0, 0)
		_fd.BackgroundTransparency = 1; _fd.ZIndex = 50; _fd.Parent = profilePanel
	end

	-- ===== CLOSE (X) BUTTON =====
	local _xBtn
	do
		_xBtn = Instance.new("TextButton")
		_xBtn.Name                   = "XClose"
		_xBtn.Size                   = UDim2.fromOffset(28, 28)
		_xBtn.Position               = UDim2.new(1, -10, 0, 10)
		_xBtn.AnchorPoint            = Vector2.new(1, 0)
		_xBtn.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
		_xBtn.BackgroundTransparency = 0.4
		_xBtn.BorderSizePixel        = 0
		_xBtn.AutoButtonColor        = false
		_xBtn.Text                   = ""
		_xBtn.ZIndex                 = 58
		_xBtn.Parent                 = profilePanel
		Instance.new("UICorner", _xBtn).CornerRadius = UDim.new(1, 0)

		local xs = Instance.new("UIStroke")
		xs.Color = Color3.fromRGB(255, 255, 255)
		xs.Transparency = 0.7; xs.Thickness = 1
		xs.Parent = _xBtn

		for _, rot in ipairs({45, -45}) do
			local bar = Instance.new("Frame")
			bar.Size            = UDim2.new(0, 11, 0, 1.5)
			bar.Position        = UDim2.new(0.5, 0, 0.5, 0)
			bar.AnchorPoint     = Vector2.new(0.5, 0.5)
			bar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			bar.Rotation        = rot
			bar.BorderSizePixel = 0
			bar.ZIndex          = 59
			bar.Parent          = _xBtn
			Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
		end
	end

	-- ===================================================================
	-- AVATAR (clean circle, thin white stroke, no colored rings)
	-- ===================================================================
	local tierSubtitleLabel

	-- AvatarOuter — simple container, transparent background
	local _avatarOuter = Instance.new("Frame")
	_avatarOuter.Name                   = "AvatarOuter"
	_avatarOuter.Size                   = UDim2.fromOffset(AVTR + 4, AVTR + 4)
	_avatarOuter.Position               = UDim2.new(0.5, 0, 0, _AVY)
	_avatarOuter.AnchorPoint            = Vector2.new(0.5, 0)
	_avatarOuter.BackgroundTransparency = 1
	_avatarOuter.ZIndex                 = 55
	_avatarOuter.Parent                 = profilePanel
	Instance.new("UICorner", _avatarOuter).CornerRadius = UDim.new(1, 0)

	-- Thin clean stroke around avatar
	local _avatarGlow = Instance.new("UIStroke")
	_avatarGlow.Name         = "AvatarGlow"
	_avatarGlow.Color        = Color3.fromRGB(255, 255, 255)
	_avatarGlow.Thickness    = 2
	_avatarGlow.Transparency = 0.4
	_avatarGlow.Parent       = _avatarOuter

	-- Hidden compat element for updateCardDisplay (expects AvatarRing)
	do
		local ring = Instance.new("Frame")
		ring.Name = "AvatarRing"; ring.Size = UDim2.fromOffset(0, 0)
		ring.BackgroundTransparency = 1; ring.ZIndex = 50; ring.Parent = profilePanel
	end

	local _avatarImg = Instance.new("ImageLabel")
	_avatarImg.Name             = "Avatar"
	_avatarImg.Size             = UDim2.fromOffset(AVTR, AVTR)
	_avatarImg.Position         = UDim2.new(0.5, 0, 0.5, 0)
	_avatarImg.AnchorPoint      = Vector2.new(0.5, 0.5)
	_avatarImg.BackgroundColor3 = Color3.fromRGB(18, 14, 32)
	_avatarImg.Image            = ""
	_avatarImg.ZIndex           = 56
	_avatarImg.Parent           = _avatarOuter
	Instance.new("UICorner", _avatarImg).CornerRadius = UDim.new(1, 0)

	-- ===================================================================
	-- CONTENT: Name, Tier, Mood, Divider, Bio, Quote
	-- ===================================================================

	-- Display Name (white + dark stroke)
	local _nameLabel = Instance.new("TextLabel")
	_nameLabel.Name                   = "DisplayName"
	_nameLabel.Size                   = UDim2.new(1, -40, 0, _NMH)
	_nameLabel.Position               = UDim2.new(0.5, 0, 0, _NMY)
	_nameLabel.AnchorPoint            = Vector2.new(0.5, 0)
	_nameLabel.BackgroundTransparency = 1
	_nameLabel.Text                   = "Player"
	_nameLabel.TextColor3             = Color3.new(1, 1, 1)
	_nameLabel.TextSize               = IS_SMALL_SCREEN and 20 or 24
	_nameLabel.Font                   = Enum.Font.GothamBold
	_nameLabel.ZIndex                 = 55
	_nameLabel.Parent                 = profilePanel
	addTextShadow(_nameLabel)

	-- Tier Subtitle
	tierSubtitleLabel = Instance.new("TextLabel")
	tierSubtitleLabel.Name                   = "TierSubtitle"
	tierSubtitleLabel.Size                   = UDim2.new(1, -40, 0, _TSH)
	tierSubtitleLabel.Position               = UDim2.new(0.5, 0, 0, _TSY)
	tierSubtitleLabel.AnchorPoint            = Vector2.new(0.5, 0)
	tierSubtitleLabel.BackgroundTransparency = 1
	tierSubtitleLabel.Text                   = ""
	tierSubtitleLabel.TextColor3             = COLORS.textDim
	tierSubtitleLabel.TextSize               = IS_SMALL_SCREEN and 11 or 13
	tierSubtitleLabel.Font                   = Enum.Font.GothamMedium
	tierSubtitleLabel.TextXAlignment         = Enum.TextXAlignment.Center
	tierSubtitleLabel.ZIndex                 = 55
	tierSubtitleLabel.Parent                 = profilePanel
	addTextShadow(tierSubtitleLabel)

	-- Mood Badge (frosted glass pill)
	local _moodBadge, _moodLabel
	do
		_moodBadge = Instance.new("Frame")
		_moodBadge.Name                   = "MoodBadge"
		_moodBadge.Size                   = UDim2.fromOffset(IS_SMALL_SCREEN and 115 or 136, _MOH)
		_moodBadge.Position               = UDim2.new(0.5, 0, 0, _MOY)
		_moodBadge.AnchorPoint            = Vector2.new(0.5, 0)
		_moodBadge.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
		_moodBadge.BackgroundTransparency = 0.35
		_moodBadge.ZIndex                 = 55
		_moodBadge.Parent                 = profilePanel
		Instance.new("UICorner", _moodBadge).CornerRadius = UDim.new(1, 0)

		local ms = Instance.new("UIStroke")
		ms.Color = Color3.fromRGB(255, 255, 255); ms.Transparency = 0.7; ms.Thickness = 1
		ms.Parent = _moodBadge

		_moodLabel = Instance.new("TextLabel")
		_moodLabel.Name                   = "MoodText"
		_moodLabel.Size                   = UDim2.new(1, -12, 1, 0)
		_moodLabel.Position               = UDim2.new(0.5, 0, 0, 0)
		_moodLabel.AnchorPoint            = Vector2.new(0.5, 0)
		_moodLabel.BackgroundTransparency = 1
		_moodLabel.Text                   = EMOJI.chill .. "  Chill"
		_moodLabel.TextColor3             = Color3.new(1, 1, 1)
		_moodLabel.TextSize               = IS_SMALL_SCREEN and 12 or 14
		_moodLabel.Font                   = Enum.Font.GothamBold
		_moodLabel.ZIndex                 = 56
		_moodLabel.Parent                 = _moodBadge
		addTextShadow(_moodLabel)
	end

	-- Gradient Divider
	do
		local div = Instance.new("Frame")
		div.Name                   = "Divider"
		div.Size                   = UDim2.new(0.65, 0, 0, 1)
		div.Position               = UDim2.new(0.5, 0, 0, _DVY)
		div.AnchorPoint            = Vector2.new(0.5, 0)
		div.BackgroundColor3       = Color3.new(1, 1, 1)
		div.BackgroundTransparency = 0.4
		div.BorderSizePixel        = 0
		div.ZIndex                 = 55
		div.Parent                 = profilePanel

		local dg = Instance.new("UIGradient")
		dg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   1),
			NumberSequenceKeypoint.new(0.2, 0.3),
			NumberSequenceKeypoint.new(0.5, 0),
			NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1,   1),
		})
		dg.Parent = div
	end

	-- Bio
	local _bio = Instance.new("TextLabel")
	_bio.Name                   = "Bio"
	_bio.Size                   = UDim2.new(1, -36, 0, _BIOH)
	_bio.Position               = UDim2.new(0.5, 0, 0, _BIOY)
	_bio.AnchorPoint            = Vector2.new(0.5, 0)
	_bio.BackgroundTransparency = 1
	_bio.Text                   = ""
	_bio.TextColor3             = Color3.new(1, 1, 1)
	_bio.TextSize               = IS_SMALL_SCREEN and 12 or 14
	_bio.Font                   = Enum.Font.Gotham
	_bio.TextWrapped            = true
	_bio.TextYAlignment         = Enum.TextYAlignment.Top
	_bio.ZIndex                 = 55
	_bio.Parent                 = profilePanel
	addTextShadow(_bio)

	-- Quote (PC only)
	if not IS_SMALL_SCREEN then
		local _quote = Instance.new("TextLabel")
		_quote.Name                   = "Quote"
		_quote.Size                   = UDim2.new(1, -36, 0, _QTH)
		_quote.Position               = UDim2.new(0.5, 0, 0, _QTY)
		_quote.AnchorPoint            = Vector2.new(0.5, 0)
		_quote.BackgroundTransparency = 1
		_quote.Text                   = ""
		_quote.TextColor3             = Color3.fromRGB(220, 210, 240)
		_quote.TextSize               = 10
		_quote.Font                   = Enum.Font.GothamMedium
		_quote.TextWrapped            = true
		_quote.ZIndex                 = 55
		_quote.Parent                 = profilePanel
		addTextShadow(_quote)
	end

	-- Rep Title (centered)
	local repTitleLabel = Instance.new("TextLabel")
	repTitleLabel.Name                   = "RepTitle"
	repTitleLabel.Size                   = UDim2.new(1, -36, 0, _RTIH)
	repTitleLabel.Position               = UDim2.new(0.5, 0, 0, _RTIY)
	repTitleLabel.AnchorPoint            = Vector2.new(0.5, 0)
	repTitleLabel.BackgroundTransparency = 1
	repTitleLabel.Text                   = "Visitor  |  0 rep"
	repTitleLabel.TextColor3             = Color3.new(1, 1, 1)
	repTitleLabel.TextSize               = IS_SMALL_SCREEN and 13 or 15
	repTitleLabel.Font                   = Enum.Font.GothamBold
	repTitleLabel.TextXAlignment         = Enum.TextXAlignment.Center
	repTitleLabel.ZIndex                 = 56
	repTitleLabel.Parent                 = profilePanel
	addTextShadow(repTitleLabel)

	-- Progress Bar
	local repBarFill
	do
		local repBarBg = Instance.new("Frame")
		repBarBg.Name                   = "RepBarBg"
		repBarBg.Size                   = UDim2.new(1, -40, 0, _BARH)
		repBarBg.Position               = UDim2.new(0.5, 0, 0, _BARY)
		repBarBg.AnchorPoint            = Vector2.new(0.5, 0)
		repBarBg.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
		repBarBg.BackgroundTransparency = 0.4
		repBarBg.ZIndex                 = 56
		repBarBg.Parent                 = profilePanel
		Instance.new("UICorner", repBarBg).CornerRadius = UDim.new(1, 0)

		repBarFill = Instance.new("Frame")
		repBarFill.Name             = "RepBarFill"
		repBarFill.Size             = UDim2.new(0, 0, 1, 0)
		repBarFill.BackgroundColor3 = COLORS.accent
		repBarFill.ZIndex           = 57
		repBarFill.Parent           = repBarBg
		Instance.new("UICorner", repBarFill).CornerRadius = UDim.new(1, 0)

		local shimmer = Instance.new("UIGradient")
		shimmer.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0,   Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 225, 255)),
			ColorSequenceKeypoint.new(1,   Color3.new(1, 1, 1)),
		})
		shimmer.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,   0.85),
			NumberSequenceKeypoint.new(0.5, 0.6),
			NumberSequenceKeypoint.new(1,   0.85),
		})
		shimmer.Parent = repBarFill
	end

	-- Next Tier
	local nextTierLabel = Instance.new("TextLabel")
	nextTierLabel.Name                   = "NextTier"
	nextTierLabel.Size                   = UDim2.new(1, -40, 0, _NTLH)
	nextTierLabel.Position               = UDim2.new(0.5, 0, 0, _NTLY)
	nextTierLabel.AnchorPoint            = Vector2.new(0.5, 0)
	nextTierLabel.BackgroundTransparency = 1
	nextTierLabel.Text                   = "Next tier at 25 rep"
	nextTierLabel.TextColor3             = Color3.fromRGB(200, 200, 210)
	nextTierLabel.TextSize               = IS_SMALL_SCREEN and 9 or 10
	nextTierLabel.Font                   = Enum.Font.Gotham
	nextTierLabel.TextXAlignment         = Enum.TextXAlignment.Center
	nextTierLabel.ZIndex                 = 56
	nextTierLabel.Parent                 = profilePanel
	addTextShadow(nextTierLabel)

	-- ===== VOTE BUTTONS (solid, clearly visible) =====
	local thumbsUpBtn, loveBtn, thumbsDownBtn
	do
		local repButtonRow = Instance.new("Frame")
		repButtonRow.Name                   = "RepButtons"
		repButtonRow.Size                   = UDim2.new(1, -36, 0, BTN_H)
		repButtonRow.Position               = UDim2.new(0.5, 0, 0, _BTHY)
		repButtonRow.AnchorPoint            = Vector2.new(0.5, 0)
		repButtonRow.BackgroundTransparency = 1
		repButtonRow.ZIndex                 = 56
		repButtonRow.Parent                 = profilePanel

		local layout = Instance.new("UIListLayout")
		layout.FillDirection       = Enum.FillDirection.Horizontal
		layout.SortOrder           = Enum.SortOrder.LayoutOrder
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.Padding             = UDim.new(0, 8)
		layout.Parent              = repButtonRow

		local function makeBtn(emojiStr, label, baseColor, hoverColor, order)
			local w = IS_SMALL_SCREEN and 72 or 84
			local btn = Instance.new("TextButton")
			btn.Size                   = UDim2.new(0, w, 1, 0)
			btn.BackgroundColor3       = baseColor
			btn.BackgroundTransparency = 0
			btn.Text                   = emojiStr .. " " .. label
			btn.TextSize               = IS_SMALL_SCREEN and 13 or 14
			btn.TextColor3             = Color3.new(1, 1, 1)
			btn.Font                   = Enum.Font.GothamBold
			btn.LayoutOrder            = order
			btn.ZIndex                 = 57
			btn.AutoButtonColor        = false
			btn.Parent                 = repButtonRow
			Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
			addTextShadow(btn)

			local bs = Instance.new("UIStroke")
			bs.Color = Color3.new(1, 1, 1)
			bs.Transparency = 0.7; bs.Thickness = 1
			bs.Parent = btn

			-- Hover effects
			btn.MouseEnter:Connect(function()
				tween(btn, { BackgroundColor3 = hoverColor }, 0.15)
				tween(bs, { Transparency = 0.4 }, 0.15)
			end)
			btn.MouseLeave:Connect(function()
				tween(btn, { BackgroundColor3 = baseColor }, 0.2)
				tween(bs, { Transparency = 0.7 }, 0.2)
			end)

			return btn
		end

		thumbsUpBtn   = makeBtn(EMOJI.thumbsUp,   "+1", Color3.fromRGB(32, 130, 65),  Color3.fromRGB(45, 170, 85),  1)
		loveBtn       = makeBtn(EMOJI.love,        "+2", Color3.fromRGB(160, 30, 95),  Color3.fromRGB(200, 45, 120), 2)
		thumbsDownBtn = makeBtn(EMOJI.thumbsDown,  "-1", Color3.fromRGB(120, 35, 35),  Color3.fromRGB(160, 50, 50),  3)
	end

	-- Status Label
	local repStatusLabel = Instance.new("TextLabel")
	repStatusLabel.Name                   = "RepStatus"
	repStatusLabel.Size                   = UDim2.new(1, -36, 0, _STSH)
	repStatusLabel.Position               = UDim2.new(0.5, 0, 0, _STSY)
	repStatusLabel.AnchorPoint            = Vector2.new(0.5, 0)
	repStatusLabel.BackgroundTransparency = 1
	repStatusLabel.Text                   = "Select a player"
	repStatusLabel.TextColor3             = Color3.fromRGB(200, 200, 210)
	repStatusLabel.TextSize               = IS_SMALL_SCREEN and 10 or 11
	repStatusLabel.Font                   = Enum.Font.Gotham
	repStatusLabel.TextXAlignment         = Enum.TextXAlignment.Center
	repStatusLabel.ZIndex                 = 56
	repStatusLabel.Parent                 = profilePanel
	addTextShadow(repStatusLabel)

	-- ===================================================================
	-- OPEN / CLOSE ANIMATIONS
	-- ===================================================================
	local SCALE_OPEN
	do
		if IS_SMALL_SCREEN then
			local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 1080
			-- Scale so the card fits within 90% of the viewport height
			local maxScale = (vpH * 0.88) / _PNLH
			SCALE_OPEN = math.clamp(maxScale, 0.55, 0.88)
		else
			SCALE_OPEN = 0.95
		end
	end

	local function openViewerAnimation()
		panelScale.Scale = 0.85
		viewerOverlay.Visible = true
		TweenService:Create(
			panelScale,
			TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = SCALE_OPEN }
		):Play()
	end

	local function closeViewerAnimation()
		TweenService:Create(
			panelScale,
			TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Scale = 0.85 }
		):Play()
		task.delay(0.22, function()
			viewerOverlay.Visible = false
		end)
	end

	-- ===================================================================
	-- REP FUNCTIONS
	-- ===================================================================
	local viewerCard             = profilePanel
	local currentViewTargetUserId = nil
	local pendingRepAction        = nil

	local _repBtnSizes = {}
	_repBtnSizes[thumbsUpBtn]   = thumbsUpBtn.Size
	_repBtnSizes[loveBtn]       = loveBtn.Size
	_repBtnSizes[thumbsDownBtn] = thumbsDownBtn.Size

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
			btn.BackgroundTransparency = active and 0 or 0.5
		end
	end

	local function pulseRepButton(btn)
		local base = _repBtnSizes[btn] or btn.Size
		tween(btn, { Size = UDim2.new(base.X.Scale, base.X.Offset + 6, base.Y.Scale, base.Y.Offset + 4) }, 0.08)
		task.delay(0.09, function()
			tween(btn, { Size = base }, 0.12)
		end)
	end

	local function flashRepPanel(color)
		tween(_stroke, { Color = color, Transparency = 0 }, 0.1)
		task.delay(0.15, function()
			tween(_stroke, { Color = COLORS.accent, Transparency = 0 }, 0.25)
		end)
	end

	local function refreshRepCooldownStatus()
		if not currentViewTargetUserId then
			setRepButtonsEnabled(false)
			return
		end

		if currentViewTargetUserId == player.UserId then
			if RunService:IsStudio() then
				repStatusLabel.Text = EMOJI.studio .. " Studio test - vote freely"
				repStatusLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
				setRepButtonsEnabled(true)
				return
			end
			repStatusLabel.Text = "You can't rep yourself"
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			setRepButtonsEnabled(false)
			return
		end

		local ok, cooldownData = pcall(function()
			return RequestRepCooldownFunc:InvokeServer(currentViewTargetUserId)
		end)

		if not ok or type(cooldownData) ~= "table" then
			repStatusLabel.Text = "Rep unavailable"
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			setRepButtonsEnabled(false)
			return
		end

		if cooldownData.canVote then
			repStatusLabel.Text = "React to this player"
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			setRepButtonsEnabled(pendingRepAction == nil)
		else
			local remaining = cooldownData.remainingSeconds or 0
			repStatusLabel.Text = "Next rep in " .. formatCooldown(remaining)
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			setRepButtonsEnabled(false)
		end
	end

	setRepButtonsEnabled(false)
	repStatusLabel.Text = "Select a player"

	local function updateRepDisplay(repData)
		if not repData then
			repTitleLabel.Text = "Visitor  |  0 rep"
			repBarFill.Size = UDim2.new(0, 0, 1, 0)
			nextTierLabel.Text = ""
			repStatusLabel.Text = "React to this player"
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
			tierSubtitleLabel.Text = ""
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

		tierSubtitleLabel.Text = title
		if tierColor and type(tierColor) == "table" then
			tierSubtitleLabel.TextColor3 = Color3.fromRGB(tierColor[1] or 138, tierColor[2] or 100, tierColor[3] or 214)
		else
			tierSubtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
		end

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
		repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)
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
					playRepSound(RepSounds, soundName, 0.6)
				end
				if payload.titleUpgraded then
					playRepSound(RepSounds, "Love", 0.8)
				end
				repStatusLabel.Text = (payload.delta and payload.delta > 0) and "Reputation boosted!" or "Reaction sent"
				repStatusLabel.TextColor3 = COLORS.success
				flashRepPanel(COLORS.success)
				refreshRepCooldownStatus()
				if currentViewTargetUserId then
					task.spawn(function()
						local ok2, repData = pcall(function()
							return RequestReputationFunc:InvokeServer(currentViewTargetUserId)
						end)
						if ok2 and repData then
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
				repStatusLabel.TextColor3 = Color3.fromRGB(255, 130, 130)
				flashRepPanel(Color3.fromRGB(220, 120, 120))
				refreshRepCooldownStatus()
			end
			return
		end

		if payload.kind == "receivedRep" then
			local soundName = getSoundNameFromPayload(payload)
			if soundName then
				playRepSound(RepSounds, soundName, 0.3)
			end
			if payload.titleUpgraded then
				playRepSound(RepSounds, "Love", 0.8)
				flashRepPanel(COLORS.accentLight)
			end

			do
				local repAction = payload.action
				local notifText, notifIcon

				if repAction == "love" then
					notifText = "You received a Heart!"
					notifIcon = "rbxassetid://78535750077522"
				elseif repAction == "thumbsUp" then
					notifText = "You received a Like!"
					notifIcon = "rbxassetid://139196160808779"
				elseif repAction == "thumbsDown" then
					notifText = "You received a Dislike."
					notifIcon = "rbxassetid://78164082975923"
				end

				if notifText then
					game:GetService("StarterGui"):SetCore("SendNotification", {
						Title = "Reputation",
						Text = notifText,
						Icon = notifIcon,
						Duration = 5,
					})
				end
			end
			return
		end

		if currentViewTargetUserId and payload.userId == currentViewTargetUserId then
			updateRepDisplay(payload)
			refreshRepCooldownStatus()
		end
	end)

	-- ===== CLOSE HANDLERS =====
	_xBtn.MouseButton1Click:Connect(function()
		currentViewTargetUserId = nil
		closeViewerAnimation()
	end)
	_xBtn.MouseEnter:Connect(function()
		tween(_xBtn, { BackgroundColor3 = Color3.fromRGB(160, 40, 48), BackgroundTransparency = 0.1 })
	end)
	_xBtn.MouseLeave:Connect(function()
		tween(_xBtn, { BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.4 })
	end)

	-- ===================================================================
	-- SHOW CARD FUNCTION
	-- ===================================================================
	local function showCard(targetUserId)
		task.spawn(function()
			local cardData = RequestProfileCardFunc:InvokeServer(targetUserId)
			if not cardData then
				cardData = {
					displayName     = Players:GetNameFromUserIdAsync(targetUserId) or "Player",
					bio             = "",
					mood            = "Chill",
					quote           = "",
					favoriteColor   = { 138, 100, 214 },
					bgGradientStart = { 16, 16, 30 },
					bgGradientEnd   = { 30, 22, 50 },
				}
			end
			currentViewTargetUserId = targetUserId
			pendingRepAction = nil
			updateCardDisplay(viewerCard, cardData, targetUserId)

			-- Update card border glow to match theme colors
			local gs = cardData.bgGradientStart
			local ge = cardData.bgGradientEnd
			local themeStart = (gs and type(gs) == "table") and Color3.fromRGB(gs[1] or 138, gs[2] or 100, gs[3] or 214) or COLORS.accent
			local themeEnd = (ge and type(ge) == "table") and Color3.fromRGB(ge[1] or 180, ge[2] or 140, ge[3] or 255) or COLORS.accentLight

			-- Card border glow = theme colors
			_strokeGrad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0,   themeEnd),
				ColorSequenceKeypoint.new(0.5, themeStart),
				ColorSequenceKeypoint.new(1,   themeEnd),
			})

			setRepButtonsEnabled(false)
			repStatusLabel.Text = "Loading reputation..."
			repStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 210)

			local ok, repData = pcall(function()
				return RequestReputationFunc:InvokeServer(targetUserId)
			end)
			if ok and repData then
				updateRepDisplay(repData)
			else
				updateRepDisplay(nil)
			end
			refreshRepCooldownStatus()
			openViewerAnimation()
		end)
	end

	-- ===================================================================
	-- HOVER GLOW ON PLAYER CHARACTERS
	-- ===================================================================
	local mouse = player:GetMouse()
	local currentHighlight = nil
	local currentHighlightChar = nil

	RunService.RenderStepped:Connect(function()
		if isEditorOpen() then return end

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

	-- ===================================================================
	-- DOUBLE-CLICK TO VIEW CARD
	-- ===================================================================
	local lastClickTime = 0
	local lastClickTarget = nil

	mouse.Button1Down:Connect(function()
		if isEditorOpen() then return end

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
			showCard(targetPlayer.UserId)
		else
			lastClickTime = now
			lastClickTarget = character
		end
	end)

	-- ===================================================================
	-- PROFILE UPDATE LISTENER
	-- ===================================================================
	ProfileCardUpdatedEvent.OnClientEvent:Connect(function(userId, data)
		if viewerOverlay.Visible and currentViewTargetUserId == userId then
			updateCardDisplay(viewerCard, data, userId)
		end
	end)

	-- ===================================================================
	-- STUDIO DEBUG BUTTON
	-- ===================================================================
	if RunService:IsStudio() then
		local dbgBtn = Instance.new("TextButton")
		dbgBtn.Name             = "StudioDebugCard"
		dbgBtn.Size             = UDim2.fromOffset(180, 38)
		dbgBtn.Position         = UDim2.new(0, 12, 1, -12)
		dbgBtn.AnchorPoint      = Vector2.new(0, 1)
		dbgBtn.BackgroundColor3 = Color3.fromRGB(48, 36, 80)
		dbgBtn.BorderSizePixel  = 0
		dbgBtn.AutoButtonColor  = false
		dbgBtn.Text             = EMOJI.studio .. "  View My Card (Studio)"
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
			showCard(player.UserId)
		end)

		dbgBtn.MouseEnter:Connect(function()
			tween(dbgBtn, { BackgroundColor3 = Color3.fromRGB(72, 52, 120) })
		end)
		dbgBtn.MouseLeave:Connect(function()
			tween(dbgBtn, { BackgroundColor3 = Color3.fromRGB(48, 36, 80) })
		end)
	end

	-- (No avatar ring animation — clean static look)

	-- ===================================================================
	-- PUBLISH PUBLIC API via _G
	-- ===================================================================
	local api = {
		viewerOverlay = viewerOverlay,
		viewerCard    = profilePanel,
		showCard      = showCard,
		isViewerOpen  = function() return viewerOverlay.Visible end,
		getCurrentTarget = function() return currentViewTargetUserId end,
	}
	_G._ProfileCardViewer = api
	print("[ProfileCardViewer] Viewer ready.")
	return api
end

_G._ProfileCardViewerInit = module.init
