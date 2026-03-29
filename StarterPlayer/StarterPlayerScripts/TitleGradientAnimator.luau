--[[
    TitleGradientAnimator.lua
    Location: StarterPlayerScripts

    Runs on every client. For each player in the server who has a CustomTitle
    attribute set, finds their overhead label's TitleLabel and animates a
    UIGradient on it to create a continuously shifting colour effect.

    Title styles:
      Legend   -- gold / orange / red  (warm fiery gradient)
      Islander -- teal / sky / seafoam (cool tropical gradient)

    The animation uses tick() as a shared clock so all clients stay
    roughly in sync without any network communication.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

-- ============================================================
-- TITLE GRADIENT DEFINITIONS
-- Each entry is a list of Color3 keypoints that cycle over time.
-- ============================================================
local TITLE_STYLES = {
	Legend = {
		Color3.fromRGB(255, 220,  60),   -- gold
		Color3.fromRGB(255, 140,  30),   -- orange
		Color3.fromRGB(255,  60,  60),   -- red-orange
		Color3.fromRGB(255, 140,  30),   -- orange (mirror for smooth loop)
	},
	Islander = {
		Color3.fromRGB( 50, 220, 255),   -- sky blue
		Color3.fromRGB(  0, 190, 200),   -- teal
		Color3.fromRGB( 30, 235, 160),   -- seafoam
		Color3.fromRGB(  0, 190, 200),   -- teal (mirror for smooth loop)
	},

	-- Rep tier gradients (all except Visitor get animated gradients)
	Shady = {
		Color3.fromRGB(140, 50, 65),     -- muted red
		Color3.fromRGB(90, 40, 90),      -- dark purple
		Color3.fromRGB(60, 30, 50),      -- near black-purple
		Color3.fromRGB(90, 40, 90),      -- dark purple (mirror)
	},
	Rising = {
		Color3.fromRGB(80, 160, 255),    -- sky blue
		Color3.fromRGB(120, 200, 255),   -- light blue
		Color3.fromRGB(60, 130, 220),    -- deeper blue
		Color3.fromRGB(120, 200, 255),   -- light blue (mirror)
	},
	Famous = {
		Color3.fromRGB(255, 200, 60),    -- gold
		Color3.fromRGB(255, 170, 40),    -- amber
		Color3.fromRGB(255, 220, 100),   -- light gold
		Color3.fromRGB(255, 170, 40),    -- amber (mirror)
	},
	Trendsetter = {
		Color3.fromRGB(200, 130, 255),   -- lavender
		Color3.fromRGB(255, 100, 200),   -- pink
		Color3.fromRGB(160, 100, 255),   -- purple
		Color3.fromRGB(255, 100, 200),   -- pink (mirror)
	},
	Influencer = {
		Color3.fromRGB(255, 120, 200),   -- hot pink
		Color3.fromRGB(255, 80, 160),    -- deep pink
		Color3.fromRGB(255, 160, 220),   -- soft pink
		Color3.fromRGB(255, 80, 160),    -- deep pink (mirror)
	},
	Celebrity = {
		Color3.fromRGB(255, 225, 60),    -- bright gold
		Color3.fromRGB(255, 180, 40),    -- warm gold
		Color3.fromRGB(255, 255, 140),   -- pale gold/white
		Color3.fromRGB(255, 180, 40),    -- warm gold (mirror)
	},
}

local ANIM_PERIOD  = 3.0   -- seconds for one full gradient cycle
local GRAD_ROTATION_SPEED = 60  -- degrees per second on the gradient rotation

-- ============================================================
-- HELPERS
-- ============================================================
local function lerpColor(a, b, t)
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

-- Sample a looping colour palette at position t [0, 1]
local function samplePalette(palette, t)
	local n    = #palette
	local pos  = t * n
	local idx  = math.floor(pos) % n + 1
	local next = idx % n + 1
	local frac = pos - math.floor(pos)
	return lerpColor(palette[idx], palette[next], frac)
end

-- Build an animated ColorSequence from a palette at a given time offset
local function buildColorSequence(palette, timeOffset)
	local t     = ((tick() + timeOffset) % ANIM_PERIOD) / ANIM_PERIOD
	local c1    = samplePalette(palette, t)
	local c2    = samplePalette(palette, (t + 0.5) % 1)
	return ColorSequence.new(c1, c2)
end

-- ============================================================
-- FIND THE TITLE LABEL INSIDE A PLAYER'S OVERHEAD LABEL
-- ============================================================
local function getTitleLabel(player)
	local character = player.Character
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	local bb = head:FindFirstChild("OverheadLabel")
	if not bb then return nil end
	local main = bb:FindFirstChild("Main")
	if not main then return nil end
	local titleRow = main:FindFirstChild("TitleRow")
	if not titleRow then return nil end
	return titleRow:FindFirstChild("TitleLabel")
end

-- Cache of UIGradient instances keyed by player
local gradCache = {}

local function getOrCreateGradient(titleLabel, player)
	local cached = gradCache[player]
	-- Validate cached gradient still lives in the label
	if cached and cached.Parent == titleLabel then
		return cached
	end
	-- Remove stale
	if cached then
		pcall(function() cached:Destroy() end)
	end
	-- Create new
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Parent   = titleLabel
	gradCache[player] = grad
	return grad
end

-- ============================================================
-- MAIN ANIMATION LOOP
-- ============================================================
local localPlayer = Players.LocalPlayer

-- Time offset per player so each player's gradient isn't identical
local function getTimeOffset(player)
	return (player.UserId % 1000) / 1000 * ANIM_PERIOD
end

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		local titleLabel = getTitleLabel(player)
		if not titleLabel then continue end

		-- 1. Check for custom title (Legend / Islander gamepass titles)
		local customTitle = player:GetAttribute("CustomTitle")
		local styleKey = nil

		if customTitle and customTitle ~= "" then
			styleKey = customTitle
		else
			-- 2. Fall back to reading the overhead label text (rep tier titles)
			local labelText = titleLabel.Text
			if labelText and labelText ~= "" and labelText ~= "Visitor" then
				styleKey = labelText
			end
		end

		-- 3. If no style or title is "Visitor"/empty/unrecognised, clear gradient
		local palette = styleKey and TITLE_STYLES[styleKey]
		if not palette then
			if gradCache[player] then
				pcall(function() gradCache[player]:Destroy() end)
				gradCache[player] = nil
			end
			continue
		end

		-- Ensure white base colour so gradient shows through
		if titleLabel.TextColor3 ~= Color3.new(1, 1, 1) then
			titleLabel.TextColor3 = Color3.new(1, 1, 1)
		end

		local grad = getOrCreateGradient(titleLabel, player)

		-- Update the colour sequence and rotate
		local offset = getTimeOffset(player)
		grad.Color    = buildColorSequence(palette, offset)
		grad.Rotation = (tick() * GRAD_ROTATION_SPEED) % 360
	end
end)

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(player)
	if gradCache[player] then
		pcall(function() gradCache[player]:Destroy() end)
		gradCache[player] = nil
	end
end)

print("[TitleGradientAnimator] Custom title gradient animation active.")
