--[[
    SettingsGui.lua  (Redesigned — Mobile-First)
    Clean scrollable list. Each row is full-width, 68 px tall.
    Toggle: 56 × 32 track, slides + colour-tweens. All tap targets = 44 px.

    FIXES:
    - Mobile uses UDim2 SCALE (not offset) so panel never overflows screen
    - Shadow toggle works (delta-only writes)
    - All effects only applied on state change (no per-frame spam)
]]

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local RunService   = game:GetService("RunService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ------------------------------------------
-- COLOURS
-- ------------------------------------------
local C = {
	bg        = Color3.fromRGB(10, 10, 18),
	panel     = Color3.fromRGB(20, 20, 35),
	row       = Color3.fromRGB(26, 26, 42),
	accent    = Color3.fromRGB(138, 100, 214),
	text      = Color3.fromRGB(220, 220, 240),
	textDim   = Color3.fromRGB(100, 100, 130),
	toggleOff = Color3.fromRGB(50, 50, 68),
	toggleOn  = Color3.fromRGB(138, 100, 214),
	knob      = Color3.fromRGB(255, 255, 255),
}

-- ------------------------------------------
-- TWEEN HELPER
-- ------------------------------------------
local function tw(inst, props, dur)
	TweenService:Create(
		inst,
		TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

-- ------------------------------------------
-- RESPONSIVE HELPERS
-- ------------------------------------------
local cam = workspace.CurrentCamera
local vp  = cam and cam.ViewportSize or Vector2.new(1920, 1080)
local IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500

--[[
    KEY FIX: On mobile, use SCALE-based UDim2 so the panel
    is always 92% of screen width and 70% of screen height,
    perfectly centred, no matter the device or safe area insets.
    Desktop keeps pixel offsets for a tighter look on big screens.
]]
local PANEL_OPEN_SIZE, PANEL_CLOSED_SIZE

if IS_SMALL_SCREEN then
	-- Bottom of panel lands ~75% down screen, leaving 25% gap to purple button
	-- Purple button sits at Y=1 offset -20px, so panel bottom ˜ 0.82 of screen
	PANEL_OPEN_SIZE   = UDim2.new(0.97, 0, 1, 0)
	PANEL_CLOSED_SIZE = UDim2.new(0.97, 0, 0,   10)
else
	local w = math.min(820, math.floor(vp.X * 0.72))
	local h = math.min(560, math.floor(vp.Y * 0.76))
	PANEL_OPEN_SIZE   = UDim2.fromOffset(w, h)
	PANEL_CLOSED_SIZE = UDim2.fromOffset(w, 10)
end

-- ------------------------------------------
-- SCREEN GUI
-- ------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name                  = "SettingsGui"
screenGui.ResetOnSpawn          = false
screenGui.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder          = 15
-- Respect notch / home bar safe areas
screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
screenGui.Parent                = playerGui

-- ------------------------------------------
-- PANEL — dead-centred via AnchorPoint 0.5,0.5
-- ------------------------------------------
local panel = Instance.new("Frame")
panel.Name                   = "SettingsPanel"
panel.Size                   = PANEL_OPEN_SIZE
panel.Position               = UDim2.new(0.5, 0, IS_SMALL_SCREEN and 0.38 or 0.5, 0)
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

-- ------------------------------------------
-- HEADER BAR
-- ------------------------------------------
local headerBar = Instance.new("Frame")
headerBar.Name                   = "HeaderBar"
headerBar.Size                   = UDim2.new(1, 0, 0, 64)
headerBar.BackgroundColor3       = C.panel
headerBar.BackgroundTransparency = 0.3
headerBar.BorderSizePixel        = 0
headerBar.Parent                 = panel
Instance.new("UICorner", headerBar).CornerRadius = UDim.new(0, 20)

local headerMask = Instance.new("Frame")
headerMask.Size                   = UDim2.new(1, 0, 0, 10)
headerMask.Position               = UDim2.new(0, 0, 1, -10)
headerMask.BackgroundColor3       = C.panel
headerMask.BackgroundTransparency = 0.3
headerMask.BorderSizePixel        = 0
headerMask.Parent                 = headerBar

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft  = UDim.new(0, 20)
headerPad.PaddingRight = UDim.new(0, 20)
headerPad.Parent       = headerBar

local headerTitle = Instance.new("TextLabel")
headerTitle.Size               = UDim2.new(1, -56, 1, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text               = "Settings"
headerTitle.TextColor3         = C.text
headerTitle.TextSize           = 18
headerTitle.Font               = Enum.Font.GothamBold
headerTitle.TextXAlignment     = Enum.TextXAlignment.Left
headerTitle.Parent             = headerBar

local headerSub = Instance.new("TextLabel")
headerSub.Size               = UDim2.new(1, -56, 0, 16)
headerSub.Position           = UDim2.new(0, 0, 1, -18)
headerSub.BackgroundTransparency = 1
headerSub.Text               = "Visual effects (only you see these)"
headerSub.TextColor3         = C.textDim
headerSub.TextSize           = 12
headerSub.Font               = Enum.Font.Gotham
headerSub.TextXAlignment     = Enum.TextXAlignment.Left
headerSub.Parent             = headerBar

local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "Close"
closeBtn.Size             = UDim2.new(0, 44, 0, 44)
closeBtn.Position         = UDim2.new(1, 0, 0.5, 0)
closeBtn.AnchorPoint      = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = C.row
closeBtn.Text             = ""
closeBtn.Parent           = headerBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 12)

for _, rot in ipairs({ 45, -45 }) do
	local bar = Instance.new("Frame")
	bar.Size        = UDim2.new(0, 14, 0, 2)
	bar.Position    = UDim2.new(0.5, 0, 0.5, 0)
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.BackgroundColor3 = C.textDim
	bar.Rotation    = rot
	bar.BorderSizePixel = 0
	bar.Parent      = closeBtn
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end

-- ------------------------------------------
-- SCROLLING LIST
-- ------------------------------------------
local scroll = Instance.new("ScrollingFrame")
scroll.Name                   = "SettingsList"
scroll.Size                   = UDim2.new(1, 0, 1, -64)
scroll.Position               = UDim2.new(0, 0, 0, 64)
scroll.BackgroundTransparency = 1
scroll.CanvasSize             = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize    = Enum.AutomaticSize.Y
scroll.ScrollBarThickness     = 3
scroll.ScrollBarImageColor3   = C.accent
scroll.BorderSizePixel        = 0
scroll.ClipsDescendants       = true
scroll.Parent                 = panel

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding   = UDim.new(0, 0)
listLayout.Parent    = scroll

local listPad = Instance.new("UIPadding")
listPad.PaddingLeft   = UDim.new(0, 14)
listPad.PaddingRight  = UDim.new(0, 14)
listPad.PaddingTop    = UDim.new(0, 10)
listPad.PaddingBottom = UDim.new(0, 16)
listPad.Parent        = scroll

-- ------------------------------------------
-- REUSABLE TOGGLE ROW
-- ------------------------------------------
local settingsState  = {}
local rowLayoutOrder = 0

local function createToggleRow(label, description, key, default)
	rowLayoutOrder += 2
	settingsState[key] = default == true

	local row = Instance.new("Frame")
	row.Name                   = key
	row.Size                   = UDim2.new(1, 0, 0, 68)
	row.BackgroundColor3       = C.row
	row.BackgroundTransparency = 0.25
	row.LayoutOrder            = rowLayoutOrder
	row.Parent                 = scroll
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 14)

	local rPad = Instance.new("UIPadding")
	rPad.PaddingLeft  = UDim.new(0, 18)
	rPad.PaddingRight = UDim.new(0, 18)
	rPad.Parent       = row

	local spacer = Instance.new("Frame")
	spacer.Name                   = "Spacer"
	spacer.Size                   = UDim2.new(1, 0, 0, 8)
	spacer.BackgroundTransparency = 1
	spacer.LayoutOrder            = rowLayoutOrder + 1
	spacer.Parent                 = scroll

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size               = UDim2.new(1, -90, 0, 22)
	nameLabel.Position           = UDim2.new(0, 0, 0, 14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text               = label
	nameLabel.TextColor3         = C.text
	nameLabel.TextSize           = 15
	nameLabel.Font               = Enum.Font.GothamBold
	nameLabel.TextXAlignment     = Enum.TextXAlignment.Left
	nameLabel.Parent             = row

	local descLabel = Instance.new("TextLabel")
	descLabel.Size               = UDim2.new(1, -90, 0, 16)
	descLabel.Position           = UDim2.new(0, 0, 0, 38)
	descLabel.BackgroundTransparency = 1
	descLabel.Text               = description
	descLabel.TextColor3         = C.textDim
	descLabel.TextSize           = 11
	descLabel.Font               = Enum.Font.Gotham
	descLabel.TextXAlignment     = Enum.TextXAlignment.Left
	descLabel.Parent             = row

	-- Toggle track (56 × 32)
	local track = Instance.new("Frame")
	track.Name             = "Track"
	track.Size             = UDim2.new(0, 56, 0, 32)
	track.Position         = UDim2.new(1, 0, 0.5, 0)
	track.AnchorPoint      = Vector2.new(1, 0.5)
	track.BackgroundColor3 = settingsState[key] and C.toggleOn or C.toggleOff
	track.Parent           = row
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	-- Knob (28 × 28)
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

	-- Full-row invisible tap target
	local hitArea = Instance.new("TextButton")
	hitArea.Size                   = UDim2.new(1, 0, 1, 0)
	hitArea.BackgroundTransparency = 1
	hitArea.Text                   = ""
	hitArea.ZIndex                 = 4
	hitArea.Parent                 = row

	hitArea.MouseButton1Click:Connect(function()
		settingsState[key] = not settingsState[key]
		local on = settingsState[key]
		tw(track, { BackgroundColor3 = on and C.toggleOn or C.toggleOff }, 0.22)
		tw(knob,  { Position = on
			and UDim2.new(1, -30, 0.5, 0)
			or  UDim2.new(0,   2, 0.5, 0) }, 0.22)
	end)

	hitArea.MouseEnter:Connect(function() tw(row, { BackgroundTransparency = 0.08 }, 0.15) end)
	hitArea.MouseLeave:Connect(function() tw(row, { BackgroundTransparency = 0.25 }, 0.15) end)

	return key
end

-- ------------------------------------------
-- EFFECT SETUP
-- ------------------------------------------
local originalClockTime = Lighting.ClockTime

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Name       = "SettingsBW"
colorCorrection.Saturation = 0
colorCorrection.Enabled    = false
colorCorrection.Parent     = Lighting

local fogAtmosphere = Instance.new("Atmosphere")
fogAtmosphere.Name    = "SettingsFog"
fogAtmosphere.Density = 0.5
fogAtmosphere.Offset  = 0.25
fogAtmosphere.Color   = Color3.fromRGB(180, 180, 200)
fogAtmosphere.Decay   = Color3.fromRGB(150, 150, 170)
fogAtmosphere.Glare   = 0
fogAtmosphere.Haze    = 8
fogAtmosphere.Parent  = nil

-- -- Create rows --
createToggleRow("Wind",          "Toggle wind effects",   "wind",         false)
createToggleRow("Black & White", "Desaturate all colors", "blackAndWhite",false)
createToggleRow("Night Mode",    "Switch to nighttime",   "nightMode",    false)
createToggleRow("Shadows",       "Toggle global shadows", "shadows",      true)
createToggleRow("Fog",           "Atmospheric fog",       "fog",          false)

-- Apply shadow default immediately so Lighting matches the UI on load
Lighting.GlobalShadows = settingsState.shadows

-- -- Wind helper --
local function getWindController()
	local ps = player:FindFirstChild("PlayerScripts")
	return ps and ps:FindFirstChild("WindController")
end
local function setWindEnabled(en)
	local wc = getWindController()
	if wc then wc:SetAttribute("WindEnabled", en) end
end

-- -- Delta tracking — only write to Lighting when state actually changes --
local lastWind   = false
local lastBW     = false
local lastNight  = false
local lastShadow = true   -- matches default above
local lastFog    = false

player.CharacterAdded:Connect(function()
	setWindEnabled(settingsState.wind == true)
	lastWind = settingsState.wind == true
end)
setWindEnabled(false)

RunService.RenderStepped:Connect(function()
	if settingsState.wind ~= lastWind then
		setWindEnabled(settingsState.wind)
		lastWind = settingsState.wind
	end
	if settingsState.blackAndWhite ~= lastBW then
		colorCorrection.Enabled    = settingsState.blackAndWhite
		colorCorrection.Saturation = settingsState.blackAndWhite and -1 or 0
		lastBW = settingsState.blackAndWhite
	end
	if settingsState.nightMode ~= lastNight then
		Lighting.ClockTime = settingsState.nightMode and 0 or originalClockTime
		lastNight = settingsState.nightMode
	end
	if settingsState.shadows ~= lastShadow then
		Lighting.GlobalShadows = settingsState.shadows
		lastShadow = settingsState.shadows
	end
	if settingsState.fog ~= lastFog then
		fogAtmosphere.Parent = settingsState.fog and Lighting or nil
		lastFog = settingsState.fog
	end
end)

-- ------------------------------------------
-- OPEN / CLOSE
-- ------------------------------------------
local isSettingsOpen = false

local function openSettings()
	if isSettingsOpen then return end
	isSettingsOpen = true
	panel.Visible  = true
	panel.Size     = PANEL_CLOSED_SIZE
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

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
_G.OpenSettingsPanel  = openSettings
_G.CloseSettingsPanel = closeSettings

print("[SettingsGui] Ready — mobile scale-based layout active.")