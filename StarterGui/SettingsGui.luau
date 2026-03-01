--[[
    SettingsGui.lua  (Redesigned — Mobile-First)
    Clean scrollable list. Each row is full-width, 68 px tall.
    Toggle: 56 × 32 track, slides + colour-tweens. All tap targets ≥ 44 px.
    Game-logic effects (wind, B&W, night, shadows, fog) unchanged.
]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local RunService   = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ──────────────────────────────────────────
-- COLOURS
-- ──────────────────────────────────────────
local C = {
	bg        = Color3.fromRGB(10, 10, 18),
	panel     = Color3.fromRGB(20, 20, 35),
	row       = Color3.fromRGB(26, 26, 42),
	rowHover  = Color3.fromRGB(32, 32, 52),
	accent    = Color3.fromRGB(138, 100, 214),
	text      = Color3.fromRGB(220, 220, 240),
	textDim   = Color3.fromRGB(100, 100, 130),
	toggleOff = Color3.fromRGB(50, 50, 68),
	toggleOn  = Color3.fromRGB(138, 100, 214),
	knob      = Color3.fromRGB(255, 255, 255),
}

-- ──────────────────────────────────────────
-- TWEEN HELPER
-- ──────────────────────────────────────────
local function tw(inst, props, dur)
	TweenService:Create(
		inst,
		TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

-- ──────────────────────────────────────────
-- RESPONSIVE HELPERS
-- ──────────────────────────────────────────
local IS_SMALL_SCREEN, SETTINGS_HEIGHT, PANEL_WIDTH
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
	PANEL_WIDTH = IS_SMALL_SCREEN and math.floor(vp.X * 0.94) or math.min(820, math.floor(vp.X * 0.72))
	SETTINGS_HEIGHT = IS_SMALL_SCREEN and math.min(520, math.floor(vp.Y * 0.82)) or math.min(560, math.floor(vp.Y * 0.76))
end

local PANEL_OPEN_SIZE = UDim2.fromOffset(PANEL_WIDTH, SETTINGS_HEIGHT)
local PANEL_CLOSED_SIZE = UDim2.fromOffset(PANEL_WIDTH, 10)

-- ──────────────────────────────────────────
-- SCREEN GUI
-- ──────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SettingsGui"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder   = 8
screenGui.Parent         = playerGui

-- ──────────────────────────────────────────
-- PANEL  (92% wide, centred, hidden by default)
-- ──────────────────────────────────────────
local panel = Instance.new("Frame")
panel.Name                   = "SettingsPanel"
panel.Size                   = PANEL_OPEN_SIZE
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.BackgroundColor3       = C.bg
panel.BackgroundTransparency = 0.05
panel.ClipsDescendants       = true
panel.Visible                = false
panel.Parent                 = screenGui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color        = Color3.new(1, 1, 1)
panelStroke.Transparency = 0.88
panelStroke.Thickness    = 1
panelStroke.Parent       = panel

local panelGrad = Instance.new("UIGradient")
panelGrad.Rotation = 160
panelGrad.Color    = ColorSequence.new(Color3.fromRGB(10, 10, 18), Color3.fromRGB(18, 14, 28))
panelGrad.Parent   = panel

-- ──────────────────────────────────────────
-- HEADER BAR
-- ──────────────────────────────────────────
local headerBar = Instance.new("Frame")
headerBar.Name             = "HeaderBar"
headerBar.Size             = UDim2.new(1, 0, 0, 64)
headerBar.BackgroundColor3 = C.panel
headerBar.BackgroundTransparency = 0.3
headerBar.BorderSizePixel  = 0
headerBar.Parent           = panel
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 20)

-- Fix bottom corners of headerBar (so it looks like a flush top section)
local headerMask = Instance.new("Frame")
headerMask.Size             = UDim2.new(1, 0, 0, 10)
headerMask.Position         = UDim2.new(0, 0, 1, -10)
headerMask.BackgroundColor3 = C.panel
headerMask.BackgroundTransparency = 0.3
headerMask.BorderSizePixel  = 0
headerMask.Parent           = headerBar

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft  = UDim.new(0, 20)
headerPad.PaddingRight = UDim.new(0, 20)
headerPad.Parent       = headerBar

local headerTitle = Instance.new("TextLabel")
headerTitle.Size             = UDim2.new(1, -56, 1, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text             = "Settings"
headerTitle.TextColor3       = C.text
headerTitle.TextSize         = 18
headerTitle.Font             = Enum.Font.GothamBold
headerTitle.TextXAlignment   = Enum.TextXAlignment.Left
headerTitle.Parent           = headerBar

local headerSub = Instance.new("TextLabel")
headerSub.Size             = UDim2.new(1, -56, 0, 16)
headerSub.Position         = UDim2.new(0, 0, 1, -18)
headerSub.BackgroundTransparency = 1
headerSub.Text             = "Visual effects (only you see these)"
headerSub.TextColor3       = C.textDim
headerSub.TextSize         = 12
headerSub.Font             = Enum.Font.Gotham
headerSub.TextXAlignment   = Enum.TextXAlignment.Left
headerSub.Parent           = headerBar

-- Close button  (44 × 44)
local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "Close"
closeBtn.Size             = UDim2.new(0, 44, 0, 44)
closeBtn.Position         = UDim2.new(1, 0, 0.5, 0)
closeBtn.AnchorPoint      = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = C.row
closeBtn.Text             = ""
closeBtn.Parent           = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 12)

-- X drawn from two lines
for _, rot in ipairs({ 45, -45 }) do
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 14, 0, 2); bar.Position = UDim2.new(0.5, 0, 0.5, 0)
	bar.AnchorPoint = Vector2.new(0.5, 0.5); bar.BackgroundColor3 = C.textDim
	bar.Rotation = rot; bar.BorderSizePixel = 0; bar.Parent = closeBtn
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end

-- ──────────────────────────────────────────
-- SCROLLING LIST
-- ──────────────────────────────────────────
local scroll = Instance.new("ScrollingFrame")
scroll.Name             = "SettingsList"
scroll.Size             = UDim2.new(1, 0, 1, -64)
scroll.Position         = UDim2.new(0, 0, 0, 64)
scroll.BackgroundTransparency = 1
scroll.CanvasSize       = UDim2.new(0, 0, 0, 0)  -- auto-set below
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.ScrollBarThickness = 3
scroll.ScrollBarImageColor3 = C.accent
scroll.BorderSizePixel  = 0
scroll.ClipsDescendants = true
scroll.Parent           = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder          = Enum.SortOrder.LayoutOrder
listLayout.Padding            = UDim.new(0, 0)   -- rows handle their own spacing via padding
listLayout.Parent             = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft   = UDim.new(0, 14)
listPad.PaddingRight  = UDim.new(0, 14)
listPad.PaddingTop    = UDim.new(0, 10)
listPad.PaddingBottom = UDim.new(0, 16)
listPad.Parent        = scroll

-- ──────────────────────────────────────────
-- REUSABLE TOGGLE ROW
-- ──────────────────────────────────────────
local settingsState  = {}
local rowLayoutOrder = 0

--[[
createToggleRow(label, description, key, default) → settingKey
Returns the key so callers can read settingsState[key].
]]
local function createToggleRow(label, description, key, default)
	rowLayoutOrder += 2
	settingsState[key] = default == true

	-- Row container  (full width, 68 px tall)
	local row = Instance.new("Frame")
	row.Name             = key
	row.Size             = UDim2.new(1, 0, 0, 68)
	row.BackgroundColor3 = C.row
	row.BackgroundTransparency = 0.25
	row.LayoutOrder      = rowLayoutOrder
	row.Parent           = scroll
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 14)

	-- Inner padding so text doesn't touch edges
	local rPad = Instance.new("UIPadding")
	rPad.PaddingLeft   = UDim.new(0, 18)
	rPad.PaddingRight  = UDim.new(0, 18)
	rPad.Parent        = row

	-- Spacer frame between rows (8 px gap)
	local spacer = Instance.new("Frame")
	spacer.Name             = "Spacer"
	spacer.Size             = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder      = rowLayoutOrder + 1
	spacer.Parent           = scroll

	-- Setting name  (left, 16 px)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size             = UDim2.new(1, -110, 0, 22)
	nameLabel.Position         = UDim2.new(0, 0, 0, 14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text             = label
	nameLabel.TextColor3       = C.text
	nameLabel.TextSize         = 16
	nameLabel.Font             = Enum.Font.GothamBold
	nameLabel.TextXAlignment   = Enum.TextXAlignment.Left
	nameLabel.Parent           = row

	-- Description  (left, 12 px)
	local descLabel = Instance.new("TextLabel")
	descLabel.Size             = UDim2.new(1, -110, 0, 16)
	descLabel.Position         = UDim2.new(0, 0, 0, 38)
	descLabel.BackgroundTransparency = 1
	descLabel.Text             = description
	descLabel.TextColor3       = C.textDim
	descLabel.TextSize         = 12
	descLabel.Font             = Enum.Font.Gotham
	descLabel.TextXAlignment   = Enum.TextXAlignment.Left
	descLabel.Parent           = row

	-- ── TOGGLE SWITCH ──
	-- Track  (56 × 32)
	local track = Instance.new("Frame")
	track.Name             = "Track"
	track.Size             = UDim2.new(0, 56, 0, 32)
	track.Position         = UDim2.new(1, 0, 0.5, 0)
	track.AnchorPoint      = Vector2.new(1, 0.5)
	track.BackgroundColor3 = settingsState[key] and C.toggleOn or C.toggleOff
	track.Parent           = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	-- Knob  (28 × 28)
	local knob = Instance.new("Frame")
	knob.Name             = "Knob"
	knob.Size             = UDim2.new(0, 28, 0, 28)
	knob.Position         = settingsState[key]
		and UDim2.new(1, -30, 0.5, 0)
		or  UDim2.new(0,   2, 0.5, 0)
	knob.AnchorPoint      = Vector2.new(0, 0.5)
	knob.BackgroundColor3 = C.knob
	knob.Parent           = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	-- Invisible tap area covering the full row  (≥ 44 px = the whole 68 px row)
	local hitArea = Instance.new("TextButton")
	hitArea.Size                   = UDim2.new(1, 0, 1, 0)
	hitArea.BackgroundTransparency = 1
	hitArea.Text                   = ""
	hitArea.ZIndex                 = 4
	hitArea.Parent                 = row

	-- Toggle logic
	hitArea.MouseButton1Click:Connect(function()
		settingsState[key] = not settingsState[key]
		local on = settingsState[key]
		tw(track, { BackgroundColor3 = on and C.toggleOn or C.toggleOff }, 0.22)
		tw(knob,  { Position = on
			and UDim2.new(1, -30, 0.5, 0)
			or  UDim2.new(0,   2, 0.5, 0) }, 0.22)
	end)

	-- Hover tint
	hitArea.MouseEnter:Connect(function()
		tw(row, { BackgroundTransparency = 0.08 }, 0.15)
	end)
	hitArea.MouseLeave:Connect(function()
		tw(row, { BackgroundTransparency = 0.25 }, 0.15)
	end)

	return key
end

-- ──────────────────────────────────────────
-- EFFECT IMPLEMENTATIONS  (unchanged logic)
-- ──────────────────────────────────────────
local originalClockTime   = Lighting.ClockTime
local originalGlobalShadows = Lighting.GlobalShadows

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name      = "SettingsBW"
colorCorrection.Saturation = 0
colorCorrection.Enabled   = false
colorCorrection.Parent    = Lighting

local fogAtmosphere = Instance.new("Atmosphere")
fogAtmosphere.Name    = "SettingsFog"
fogAtmosphere.Density = 0.5
fogAtmosphere.Offset  = 0.25
fogAtmosphere.Color   = Color3.fromRGB(180, 180, 200)
fogAtmosphere.Decay   = Color3.fromRGB(150, 150, 170)
fogAtmosphere.Glare   = 0
fogAtmosphere.Haze    = 8
fogAtmosphere.Parent  = nil

-- ── Create rows ──
createToggleRow("Wind",          "Toggle wind effects",     "wind",         false)
createToggleRow("Black & White", "Desaturate all colors",   "blackAndWhite",false)
createToggleRow("Night Mode",    "Switch to nighttime",     "nightMode",    false)
createToggleRow("Shadows",       "Toggle global shadows",   "shadows",      originalGlobalShadows)
createToggleRow("Fog",           "Atmospheric fog",         "fog",          false)

-- Wind helper
local function getWindController()
	local ps = player:FindFirstChild("PlayerScripts")
	return ps and ps:FindFirstChild("WindController")
end
local function setWindEnabled(en)
	local wc = getWindController()
	if wc then wc:SetAttribute("WindEnabled", en) end
end

local lastWindState = false
player.CharacterAdded:Connect(function()
	setWindEnabled(settingsState.wind == true)
	lastWindState = settingsState.wind == true
end)
setWindEnabled(false); lastWindState = false

-- Per-frame effect application
RunService.RenderStepped:Connect(function()
	-- Wind
	if settingsState.wind and not lastWindState then
		setWindEnabled(true); lastWindState = true
	elseif not settingsState.wind and lastWindState then
		setWindEnabled(false); lastWindState = false
	end
	-- B&W
	colorCorrection.Enabled    = settingsState.blackAndWhite
	colorCorrection.Saturation = settingsState.blackAndWhite and -1 or 0
	-- Night
	if settingsState.nightMode then
		Lighting.ClockTime = 0
	elseif Lighting.ClockTime == 0 then
		Lighting.ClockTime = originalClockTime
	end
	-- Shadows
	Lighting.GlobalShadows = settingsState.shadows
	-- Fog
	if settingsState.fog then
		if not fogAtmosphere.Parent then fogAtmosphere.Parent = Lighting end
	else
		if fogAtmosphere.Parent then fogAtmosphere.Parent = nil end
	end
end)

-- ──────────────────────────────────────────
-- OPEN / CLOSE
-- ──────────────────────────────────────────
local isSettingsOpen = false

local function openSettings()
	if isSettingsOpen then return end
	isSettingsOpen  = true
	panel.Visible   = true
	panel.Size      = PANEL_CLOSED_SIZE
	panel.BackgroundTransparency = 1
	tw(panel, { Size = PANEL_OPEN_SIZE, BackgroundTransparency = 0.05 }, 0.28)
end

local function closeSettings()
	if not isSettingsOpen then return end
	isSettingsOpen = false
	tw(panel, { Size = PANEL_CLOSED_SIZE, BackgroundTransparency = 1 }, 0.22)
	task.delay(0.25, function()
		if not isSettingsOpen then panel.Visible = false end
	end)
end

closeBtn.MouseButton1Click:Connect(closeSettings)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(180,50,50) }) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, { BackgroundColor3 = C.row }) end)

-- ──────────────────────────────────────────
-- PUBLIC API
-- ──────────────────────────────────────────
_G.OpenSettingsPanel  = openSettings
_G.CloseSettingsPanel = closeSettings

print("[SettingsGui] Mobile-first settings panel ready.")
