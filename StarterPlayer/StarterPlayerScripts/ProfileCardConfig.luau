--[[
    ProfileCardConfig.luau  (LocalScript)
    Shared constants, helpers, and configuration for the profile card system.
    Publishes via _G._ProfileCardConfig so other scripts can access it.
]]

local TweenService = game:GetService("TweenService")

-- --- RESPONSIVE HELPERS ---
local IS_SMALL_SCREEN, IS_MEDIUM_SCREEN
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
	IS_MEDIUM_SCREEN = not IS_SMALL_SCREEN and (vp.X < 1100 or vp.Y < 700)
end

local COLORS = {
	bg           = Color3.fromRGB(8, 8, 16),
	panel        = Color3.fromRGB(14, 14, 24),
	input        = Color3.fromRGB(24, 24, 42),
	inputFocus   = Color3.fromRGB(32, 32, 55),
	accent       = Color3.fromRGB(138, 100, 214),
	accentLight  = Color3.fromRGB(180, 140, 255),
	accentDark   = Color3.fromRGB(90, 60, 160),
	text         = Color3.fromRGB(230, 230, 245),
	textDim      = Color3.fromRGB(100, 100, 135),
	textMuted    = Color3.fromRGB(70, 70, 95),
	success      = Color3.fromRGB(80, 200, 120),
	cardBg1      = Color3.fromRGB(16, 16, 30),
	cardBg2      = Color3.fromRGB(30, 22, 50),
}

local EMOJI = {
	thumbsUp    = utf8.char(0x1F44D),
	thumbsDown  = utf8.char(0x1F44E),
	love        = utf8.char(0x2764, 0xFE0F),
	studio      = utf8.char(0x1F3AE),
	chill       = utf8.char(0x1F60C),
	happy       = utf8.char(0x1F604),
	vibing      = utf8.char(0x1F3B5),
	sad         = utf8.char(0x1F614),
	tired       = utf8.char(0x1F634),
	energetic   = utf8.char(0x26A1),
	creative    = utf8.char(0x1F3A8),
	thoughtful  = utf8.char(0x1F914),
}

local MOODS = { "Chill", "Happy", "Vibing", "Sad", "Tired", "Energetic", "Creative", "Thoughtful" }
local MOOD_SYMBOLS = {
	Chill = EMOJI.chill, Happy = EMOJI.happy, Vibing = EMOJI.vibing, Sad = EMOJI.sad,
	Tired = EMOJI.tired, Energetic = EMOJI.energetic, Creative = EMOJI.creative, Thoughtful = EMOJI.thoughtful,
}

-- Card styles (gradient presets) — 6 styles, each with optional background image
local CARD_STYLES = {
	{ n = "Void",   s = Color3.fromRGB(10, 8, 22),   e = Color3.fromRGB(40, 20, 80),    img = "72486776126702" },
	{ n = "Ocean",  s = Color3.fromRGB(0, 30, 100),   e = Color3.fromRGB(0, 160, 220),   img = "80807938474626" },
	{ n = "Forest", s = Color3.fromRGB(0, 80, 30),    e = Color3.fromRGB(20, 200, 80),   img = "89033182237933" },
	{ n = "Gold",   s = Color3.fromRGB(100, 55, 0),   e = Color3.fromRGB(255, 190, 30),  img = "139740145959309" },
	{ n = "Rose",   s = Color3.fromRGB(100, 0, 60),   e = Color3.fromRGB(255, 60, 150),  img = "115664620648461" },
	{ n = "Frost",  s = Color3.fromRGB(0, 80, 130),   e = Color3.fromRGB(160, 240, 255), img = "86521474332767" },
}

-- Custom title options (pass-exclusive + auto-tier)
local TITLE_OPTIONS = {
	{ n = "Use Tier",  c = { Color3.fromRGB(138, 100, 214), Color3.fromRGB(180, 140, 255) },  isTierDefault = true },
	{ n = "Legend",    c = { Color3.fromRGB(255, 200, 50),  Color3.fromRGB(255, 100, 30),  Color3.fromRGB(255, 60, 60) } },
	{ n = "Islander",  c = { Color3.fromRGB(50, 200, 255),  Color3.fromRGB(0, 180, 200),   Color3.fromRGB(30, 230, 160) } },
}

-- --- HELPERS ---
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

local function colorsMatch(a, b)
	return math.abs(a.R - b.R) < 0.02 and math.abs(a.G - b.G) < 0.02 and math.abs(a.B - b.B) < 0.02
end

-- Glow transparency sequence used for cursor-tracking UIStroke effects
local GLOW_TRANSPARENCY = NumberSequence.new({
	NumberSequenceKeypoint.new(0,    0.88),
	NumberSequenceKeypoint.new(0.3,  0.82),
	NumberSequenceKeypoint.new(0.5,  0.15),
	NumberSequenceKeypoint.new(0.7,  0.82),
	NumberSequenceKeypoint.new(1,    0.88),
})

_G._ProfileCardConfig = {
	IS_SMALL_SCREEN  = IS_SMALL_SCREEN,
	IS_MEDIUM_SCREEN = IS_MEDIUM_SCREEN,
	COLORS           = COLORS,
	EMOJI            = EMOJI,
	MOODS            = MOODS,
	MOOD_SYMBOLS     = MOOD_SYMBOLS,
	CARD_STYLES      = CARD_STYLES,
	TITLE_OPTIONS    = TITLE_OPTIONS,
	GLOW_TRANSPARENCY = GLOW_TRANSPARENCY,
	TOGGLE_KEY       = Enum.KeyCode.P,
	DOUBLE_CLICK_TIME = 0.35,
	tween            = tween,
	colorToTable     = colorToTable,
	tableToColor     = tableToColor,
	colorsMatch      = colorsMatch,
}

print("[ProfileCardConfig] Config ready.")
