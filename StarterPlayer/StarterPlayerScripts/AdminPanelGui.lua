--[[
    AdminPanelGui.lua
    Location: StarterPlayerScripts

    Admin-only panel with server management tools.
    Currently supports:
      - Toggle rep cooldowns on/off for the entire server

    Only visible to authorized admins (checked via AdminRepCanUse remote).
    Opens from the Admin button in the FeaturesHub.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local AdminRepEvent    = Remotes:WaitForChild("AdminRepEvent")
local AdminRepResponse = Remotes:WaitForChild("AdminRepResponse")

-- ─── Wait for admin auth from ProfileCardGui ───
local isAdmin = false
for _ = 1, 60 do
	if _G.IsAuthorizedAdmin ~= nil then break end
	task.wait(0.1)
end
isAdmin = _G.IsAuthorizedAdmin == true
if not isAdmin then return end

-- ─── COLORS ───
local C = {
	bg        = Color3.fromRGB(10, 10, 18),
	panel     = Color3.fromRGB(20, 20, 35),
	row       = Color3.fromRGB(26, 26, 42),
	accent    = Color3.fromRGB(220, 80, 100),
	accentDim = Color3.fromRGB(160, 50, 70),
	text      = Color3.fromRGB(220, 220, 240),
	textDim   = Color3.fromRGB(100, 100, 130),
	success   = Color3.fromRGB(80, 200, 120),
	error     = Color3.fromRGB(220, 80, 80),
	toggleOn  = Color3.fromRGB(138, 100, 214),
	toggleOff = Color3.fromRGB(50, 50, 68),
	knob      = Color3.fromRGB(255, 255, 255),
}

local function tw(inst, props, dur)
	TweenService:Create(
		inst,
		TweenInfo.new(dur or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		props
	):Play()
end

-- ─── RESPONSIVE ───
local cam = workspace.CurrentCamera
local vp  = cam and cam.ViewportSize or Vector2.new(1920, 1080)
local IS_SMALL = vp.X < 700 or vp.Y < 500

local PANEL_W = IS_SMALL and math.floor(vp.X * 0.92) or math.min(460, math.floor(vp.X * 0.5))
local PANEL_H = IS_SMALL and math.floor(vp.Y * 0.78) or math.min(520, math.floor(vp.Y * 0.7))

-- ─── SCREEN GUI ───
local screenGui = Instance.new("ScreenGui")
screenGui.Name                  = "AdminPanelGui"
screenGui.ResetOnSpawn          = false
screenGui.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder          = 20
screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
screenGui.Parent                = playerGui

-- ─── PANEL ───
local panel = Instance.new("Frame")
panel.Name                   = "AdminPanel"
panel.Size                   = UDim2.fromOffset(PANEL_W, PANEL_H)
panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
panel.AnchorPoint            = Vector2.new(0.5, 0.5)
panel.BackgroundColor3       = C.bg
panel.BackgroundTransparency = 0.05
panel.ClipsDescendants       = true
panel.Visible                = false
panel.Parent                 = screenGui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color        = C.accent
panelStroke.Transparency = 0.6
panelStroke.Thickness    = 1.5
panelStroke.Parent       = panel

-- ─── HEADER ───
local header = Instance.new("Frame")
header.Size                   = UDim2.new(1, 0, 0, 58)
header.BackgroundColor3       = C.panel
header.BackgroundTransparency = 0.3
header.BorderSizePixel        = 0
header.Parent                 = panel
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 20)

local headerMask = Instance.new("Frame")
headerMask.Size                   = UDim2.new(1, 0, 0, 10)
headerMask.Position               = UDim2.new(0, 0, 1, -10)
headerMask.BackgroundColor3       = C.panel
headerMask.BackgroundTransparency = 0.3
headerMask.BorderSizePixel        = 0
headerMask.Parent                 = header

local headerPad = Instance.new("UIPadding")
headerPad.PaddingLeft  = UDim.new(0, 20)
headerPad.PaddingRight = UDim.new(0, 20)
headerPad.Parent       = header

local headerTitle = Instance.new("TextLabel")
headerTitle.Size                   = UDim2.new(1, -50, 1, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text                   = "Admin Panel"
headerTitle.TextColor3             = C.accent
headerTitle.TextSize               = 18
headerTitle.Font                   = Enum.Font.GothamBold
headerTitle.TextXAlignment         = Enum.TextXAlignment.Left
headerTitle.Parent                 = header

local closeBtn = Instance.new("TextButton")
closeBtn.Name             = "Close"
closeBtn.Size             = UDim2.new(0, 40, 0, 40)
closeBtn.Position         = UDim2.new(1, 0, 0.5, 0)
closeBtn.AnchorPoint      = Vector2.new(1, 0.5)
closeBtn.BackgroundColor3 = C.row
closeBtn.Text             = ""
closeBtn.Parent           = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 10)

for _, rot in ipairs({ 45, -45 }) do
	local bar = Instance.new("Frame")
	bar.Size             = UDim2.new(0, 14, 0, 2)
	bar.Position         = UDim2.new(0.5, 0, 0.5, 0)
	bar.AnchorPoint      = Vector2.new(0.5, 0.5)
	bar.BackgroundColor3 = C.textDim
	bar.Rotation         = rot
	bar.BorderSizePixel  = 0
	bar.Parent           = closeBtn
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
end

-- ─── CONTENT AREA ───
local content = Instance.new("ScrollingFrame")
content.Size                   = UDim2.new(1, 0, 1, -58)
content.Position               = UDim2.new(0, 0, 0, 58)
content.BackgroundTransparency = 1
content.CanvasSize             = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize    = Enum.AutomaticSize.Y
content.ScrollBarThickness     = 3
content.ScrollBarImageColor3   = C.accent
content.BorderSizePixel        = 0
content.Parent                 = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Padding   = UDim.new(0, 10)
contentLayout.Parent    = content

local contentPad = Instance.new("UIPadding")
contentPad.PaddingLeft   = UDim.new(0, 16)
contentPad.PaddingRight  = UDim.new(0, 16)
contentPad.PaddingTop    = UDim.new(0, 12)
contentPad.PaddingBottom = UDim.new(0, 16)
contentPad.Parent        = content

-- ─────────────────────────────────────────────
-- SECTION: Reputation
-- ─────────────────────────────────────────────
local sectionLabel = Instance.new("TextLabel")
sectionLabel.Size                   = UDim2.new(1, 0, 0, 20)
sectionLabel.BackgroundTransparency = 1
sectionLabel.Text                   = "REPUTATION"
sectionLabel.TextColor3             = C.textDim
sectionLabel.TextSize               = 11
sectionLabel.Font                   = Enum.Font.GothamBold
sectionLabel.TextXAlignment         = Enum.TextXAlignment.Left
sectionLabel.LayoutOrder            = 1
sectionLabel.Parent                 = content

-- Cooldowns Toggle Row (same style as SettingsGui toggles)
local cooldownRow = Instance.new("Frame")
cooldownRow.Name                   = "CooldownToggleRow"
cooldownRow.Size                   = UDim2.new(1, 0, 0, 68)
cooldownRow.BackgroundColor3       = C.row
cooldownRow.BackgroundTransparency = 0.15
cooldownRow.LayoutOrder            = 2
cooldownRow.Parent                 = content
Instance.new("UICorner", cooldownRow).CornerRadius = UDim.new(0, 14)

local rowPad = Instance.new("UIPadding")
rowPad.PaddingLeft  = UDim.new(0, 18)
rowPad.PaddingRight = UDim.new(0, 18)
rowPad.Parent       = cooldownRow

local rowTitle = Instance.new("TextLabel")
rowTitle.Size                   = UDim2.new(1, -90, 0, 22)
rowTitle.Position               = UDim2.new(0, 0, 0, 14)
rowTitle.BackgroundTransparency = 1
rowTitle.Text                   = "Rep Cooldowns"
rowTitle.TextColor3             = C.text
rowTitle.TextSize               = 15
rowTitle.Font                   = Enum.Font.GothamBold
rowTitle.TextXAlignment         = Enum.TextXAlignment.Left
rowTitle.Parent                 = cooldownRow

local rowDesc = Instance.new("TextLabel")
rowDesc.Size                   = UDim2.new(1, -90, 0, 16)
rowDesc.Position               = UDim2.new(0, 0, 0, 38)
rowDesc.BackgroundTransparency = 1
rowDesc.Text                   = "24h cooldown on likes/dislikes/hearts"
rowDesc.TextColor3             = C.textDim
rowDesc.TextSize               = 11
rowDesc.Font                   = Enum.Font.Gotham
rowDesc.TextXAlignment         = Enum.TextXAlignment.Left
rowDesc.Parent                 = cooldownRow

-- Toggle track (56 × 32) — starts ON (cooldowns enabled by default)
local cooldownToggleOn = true

local toggleTrack = Instance.new("Frame")
toggleTrack.Name             = "Track"
toggleTrack.Size             = UDim2.new(0, 56, 0, 32)
toggleTrack.Position         = UDim2.new(1, 0, 0.5, 0)
toggleTrack.AnchorPoint      = Vector2.new(1, 0.5)
toggleTrack.BackgroundColor3 = C.toggleOn
toggleTrack.Parent           = cooldownRow
Instance.new("UICorner", toggleTrack).CornerRadius = UDim.new(1, 0)

local toggleKnob = Instance.new("Frame")
toggleKnob.Name             = "Knob"
toggleKnob.Size             = UDim2.new(0, 28, 0, 28)
toggleKnob.Position         = UDim2.new(1, -30, 0.5, 0)
toggleKnob.AnchorPoint      = Vector2.new(0, 0.5)
toggleKnob.BackgroundColor3 = C.knob
toggleKnob.Parent           = toggleTrack
Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(1, 0)

local function updateToggleVisual(on)
	tw(toggleTrack, { BackgroundColor3 = on and C.toggleOn or C.toggleOff }, 0.22)
	tw(toggleKnob, { Position = on
		and UDim2.new(1, -30, 0.5, 0)
		or  UDim2.new(0,   2, 0.5, 0) }, 0.22)
end

-- Full-row tap target
local hitArea = Instance.new("TextButton")
hitArea.Size                   = UDim2.new(1, 0, 1, 0)
hitArea.BackgroundTransparency = 1
hitArea.Text                   = ""
hitArea.ZIndex                 = 4
hitArea.Parent                 = cooldownRow

local toggleDebounce = false

hitArea.MouseButton1Click:Connect(function()
	if toggleDebounce then return end
	toggleDebounce = true
	AdminRepEvent:FireServer({ action = "toggleCooldowns" })
end)

hitArea.MouseEnter:Connect(function() tw(cooldownRow, { BackgroundTransparency = 0.08 }, 0.15) end)
hitArea.MouseLeave:Connect(function() tw(cooldownRow, { BackgroundTransparency = 0.15 }, 0.15) end)

-- Fetch initial state from server
task.spawn(function()
	AdminRepEvent:FireServer({ action = "getCooldownState" })
end)

-- ─────────────────────────────────────────────
-- SECTION: Rep Manager
-- ─────────────────────────────────────────────
local repManagerCard = Instance.new("Frame")
repManagerCard.Name                   = "RepManagerCard"
repManagerCard.Size                   = UDim2.new(1, 0, 0, 220)
repManagerCard.BackgroundColor3       = C.row
repManagerCard.BackgroundTransparency = 0.15
repManagerCard.LayoutOrder            = 3
repManagerCard.Parent                 = content
Instance.new("UICorner", repManagerCard).CornerRadius = UDim.new(0, 14)

local rmPad = Instance.new("UIPadding")
rmPad.PaddingLeft   = UDim.new(0, 16)
rmPad.PaddingRight  = UDim.new(0, 16)
rmPad.PaddingTop    = UDim.new(0, 14)
rmPad.PaddingBottom = UDim.new(0, 14)
rmPad.Parent        = repManagerCard

local rmTitle = Instance.new("TextLabel")
rmTitle.Size                   = UDim2.new(1, 0, 0, 20)
rmTitle.BackgroundTransparency = 1
rmTitle.Text                   = "Rep Manager"
rmTitle.TextColor3             = C.text
rmTitle.TextSize               = 15
rmTitle.Font                   = Enum.Font.GothamBold
rmTitle.TextXAlignment         = Enum.TextXAlignment.Left
rmTitle.Parent                 = repManagerCard

local rmDesc = Instance.new("TextLabel")
rmDesc.Size                   = UDim2.new(1, 0, 0, 14)
rmDesc.Position               = UDim2.new(0, 0, 0, 22)
rmDesc.BackgroundTransparency = 1
rmDesc.Text                   = "Set, add, or reset a player's reputation"
rmDesc.TextColor3             = C.textDim
rmDesc.TextSize               = 11
rmDesc.Font                   = Enum.Font.Gotham
rmDesc.TextXAlignment         = Enum.TextXAlignment.Left
rmDesc.Parent                 = repManagerCard

-- Player name input
local playerNameInput = Instance.new("TextBox")
playerNameInput.Name                   = "PlayerNameInput"
playerNameInput.Size                   = UDim2.new(1, 0, 0, 34)
playerNameInput.Position               = UDim2.new(0, 0, 0, 46)
playerNameInput.BackgroundColor3       = C.panel
playerNameInput.PlaceholderText        = "Enter player name or display name"
playerNameInput.PlaceholderColor3      = C.textDim
playerNameInput.Text                   = ""
playerNameInput.TextColor3             = C.text
playerNameInput.TextSize               = 12
playerNameInput.Font                   = Enum.Font.Gotham
playerNameInput.ClearTextOnFocus       = false
playerNameInput.Parent                 = repManagerCard
Instance.new("UICorner", playerNameInput).CornerRadius = UDim.new(0, 8)

local nameInputStroke = Instance.new("UIStroke")
nameInputStroke.Color        = C.toggleOff
nameInputStroke.Transparency = 0.5
nameInputStroke.Thickness    = 1
nameInputStroke.Parent       = playerNameInput

local nameInputPad = Instance.new("UIPadding")
nameInputPad.PaddingLeft  = UDim.new(0, 10)
nameInputPad.PaddingRight = UDim.new(0, 10)
nameInputPad.Parent       = playerNameInput

-- Resolve typed name to a Player object
local function resolvePlayer(name)
	local lower = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == lower or string.lower(p.DisplayName) == lower then
			return p
		end
	end
	-- Partial match fallback
	for _, p in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(p.Name), lower, 1, true)
			or string.find(string.lower(p.DisplayName), lower, 1, true) then
			return p
		end
	end
	return nil
end

-- Rep value input
local valueLabel = Instance.new("TextLabel")
valueLabel.Size                   = UDim2.new(0.3, 0, 0, 14)
valueLabel.Position               = UDim2.new(0, 0, 0, 86)
valueLabel.BackgroundTransparency = 1
valueLabel.Text                   = "Value"
valueLabel.TextColor3             = C.textDim
valueLabel.TextSize               = 11
valueLabel.Font                   = Enum.Font.Gotham
valueLabel.TextXAlignment         = Enum.TextXAlignment.Left
valueLabel.Parent                 = repManagerCard

local valueInput = Instance.new("TextBox")
valueInput.Name                   = "ValueInput"
valueInput.Size                   = UDim2.new(1, 0, 0, 34)
valueInput.Position               = UDim2.new(0, 0, 0, 102)
valueInput.BackgroundColor3       = C.panel
valueInput.PlaceholderText        = "Enter rep amount (e.g. 100, -50)"
valueInput.PlaceholderColor3      = C.textDim
valueInput.Text                   = ""
valueInput.TextColor3             = C.text
valueInput.TextSize               = 12
valueInput.Font                   = Enum.Font.Gotham
valueInput.ClearTextOnFocus       = false
valueInput.Parent                 = repManagerCard
Instance.new("UICorner", valueInput).CornerRadius = UDim.new(0, 8)

local inputStroke = Instance.new("UIStroke")
inputStroke.Color        = C.toggleOff
inputStroke.Transparency = 0.5
inputStroke.Thickness    = 1
inputStroke.Parent       = valueInput

local inputPad = Instance.new("UIPadding")
inputPad.PaddingLeft  = UDim.new(0, 10)
inputPad.PaddingRight = UDim.new(0, 10)
inputPad.Parent       = valueInput

-- Action buttons row
local btnRow = Instance.new("Frame")
btnRow.Size                   = UDim2.new(1, 0, 0, 34)
btnRow.Position               = UDim2.new(0, 0, 0, 146)
btnRow.BackgroundTransparency = 1
btnRow.Parent                 = repManagerCard

local btnRowLayout = Instance.new("UIListLayout")
btnRowLayout.FillDirection = Enum.FillDirection.Horizontal
btnRowLayout.SortOrder     = Enum.SortOrder.LayoutOrder
btnRowLayout.Padding       = UDim.new(0, 8)
btnRowLayout.Parent        = btnRow

local function createActionBtn(text, color, order)
	local btn = Instance.new("TextButton")
	btn.Name             = text
	btn.Size             = UDim2.new(0.31, 0, 1, 0)
	btn.BackgroundColor3 = color
	btn.Text             = text
	btn.TextColor3       = Color3.new(1, 1, 1)
	btn.TextSize         = 12
	btn.Font             = Enum.Font.GothamBold
	btn.AutoButtonColor  = false
	btn.LayoutOrder      = order
	btn.Parent           = btnRow
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	return btn
end

local setBtn   = createActionBtn("Set",   C.accent,    1)
local addBtn   = createActionBtn("Add",   Color3.fromRGB(80, 160, 220), 2)
local resetBtn = createActionBtn("Reset", Color3.fromRGB(180, 80, 80),  3)

-- Status label
local repStatusLabel = Instance.new("TextLabel")
repStatusLabel.Size                   = UDim2.new(1, 0, 0, 16)
repStatusLabel.Position               = UDim2.new(0, 0, 0, 186)
repStatusLabel.BackgroundTransparency = 1
repStatusLabel.Text                   = ""
repStatusLabel.TextColor3             = C.textDim
repStatusLabel.TextSize               = 11
repStatusLabel.Font                   = Enum.Font.Gotham
repStatusLabel.TextXAlignment         = Enum.TextXAlignment.Center
repStatusLabel.Parent                 = repManagerCard

-- Action handler
local repDebounce = false

local function sendRepAction(action)
	if repDebounce then return end

	local name = playerNameInput.Text
	if name == "" then
		repStatusLabel.Text       = "Enter a player name"
		repStatusLabel.TextColor3 = C.error
		return
	end

	local target = resolvePlayer(name)
	if not target then
		repStatusLabel.Text       = "Player not found in server"
		repStatusLabel.TextColor3 = C.error
		return
	end

	if action ~= "reset" then
		local val = tonumber(valueInput.Text)
		if not val then
			repStatusLabel.Text       = "Enter a valid number"
			repStatusLabel.TextColor3 = C.error
			return
		end
	end

	repDebounce = true
	repStatusLabel.Text       = "Sending..."
	repStatusLabel.TextColor3 = C.textDim

	local payload = {
		action       = action,
		targetUserId = target.UserId,
	}
	if action ~= "reset" then
		payload.value = tonumber(valueInput.Text)
	end

	AdminRepEvent:FireServer(payload)
end

setBtn.MouseButton1Click:Connect(function() sendRepAction("set") end)
addBtn.MouseButton1Click:Connect(function() sendRepAction("add") end)
resetBtn.MouseButton1Click:Connect(function() sendRepAction("reset") end)

-- Hover effects
for _, btn in ipairs({ setBtn, addBtn, resetBtn }) do
	local origColor = btn.BackgroundColor3
	btn.MouseEnter:Connect(function()
		tw(btn, { BackgroundColor3 = origColor:Lerp(Color3.new(0, 0, 0), 0.2) }, 0.12)
	end)
	btn.MouseLeave:Connect(function()
		tw(btn, { BackgroundColor3 = origColor }, 0.12)
	end)
end

-- ─── UNIFIED RESPONSE HANDLER ───
AdminRepResponse.OnClientEvent:Connect(function(response)
	if not response or type(response) ~= "table" then return end

	if response.kind == "cooldownToggle" then
		cooldownToggleOn = response.cooldownsEnabled
		updateToggleVisual(cooldownToggleOn)
		toggleDebounce = false
		return
	end

	-- Rep manager response
	if response.ok then
		repStatusLabel.Text       = response.msg or "Done"
		repStatusLabel.TextColor3 = C.success
	else
		repStatusLabel.Text       = response.msg or "Failed"
		repStatusLabel.TextColor3 = C.error
	end

	repDebounce = false
	task.delay(4, function()
		if repStatusLabel.Text == (response.msg or "") then
			repStatusLabel.Text = ""
		end
	end)
end)

-- ─── OPEN / CLOSE ───
local isPanelOpen = false

local function openPanel()
	if isPanelOpen then return end
	isPanelOpen = true
	panel.Visible = true
	panel.Size = UDim2.fromOffset(PANEL_W, 10)
	panel.BackgroundTransparency = 1
	tw(panel, { Size = UDim2.fromOffset(PANEL_W, PANEL_H), BackgroundTransparency = 0.05 }, 0.28)
end

local function closePanel()
	if not isPanelOpen then return end
	isPanelOpen = false
	tw(panel, { Size = UDim2.fromOffset(PANEL_W, 10), BackgroundTransparency = 1 }, 0.22)
	task.delay(0.25, function()
		if not isPanelOpen then panel.Visible = false end
	end)
end

closeBtn.MouseButton1Click:Connect(closePanel)
closeBtn.MouseEnter:Connect(function() tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(180, 50, 50) }) end)
closeBtn.MouseLeave:Connect(function() tw(closeBtn, { BackgroundColor3 = C.row }) end)

-- ─── PUBLIC API ───
_G.OpenAdminPanel  = openPanel
_G.CloseAdminPanel = closePanel

print("[AdminPanelGui] Admin panel ready.")
