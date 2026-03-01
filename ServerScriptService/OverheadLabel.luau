--[[
    OverheadLabel.lua
    Location: ServerScriptService

    Custom overhead BillboardGui nametag for every player.
    Uses stud-based Size so tags naturally shrink with camera distance.

    Layout (top to bottom):
      Row 1: Tier Title  (colored by reputation tier)
      Row 2: DisplayName  (color reflects rep score)
      Row 3: Platform icon  +  @username

    Visual rep effects:
      - High rep (>=100) -> warm tint on name
      - Very high rep (>=300) -> gold tint
      - Negative rep -> grey name; very negative -> red tint
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ReportPlatformEvent = Remotes:WaitForChild("ReportPlatform")

-- -------------------------------------------
-- CONFIGURATION
-- -------------------------------------------
local MAX_DISTANCE = 60
local BILLBOARD_WIDTH = 6
local BILLBOARD_HEIGHT = 1.8
local STUDS_OFFSET = Vector3.new(0, 2.6, 0)

local PLATFORM_SYMBOLS = {
	PC      = "[PC]",
	Mobile  = "[M]",
	Console = "[C]",
	Unknown = "[?]",
}

local TIERS_COLORS = {
	-- maps tier title to a clean readable nametag color
	Shady       = Color3.fromRGB(200, 75, 85),
	Visitor     = Color3.fromRGB(175, 160, 215),
	Rising      = Color3.fromRGB(100, 180, 255),
	Famous      = Color3.fromRGB(255, 195, 65),
	Trendsetter = Color3.fromRGB(190, 140, 255),
	Influencer  = Color3.fromRGB(255, 130, 220),
	Celebrity   = Color3.fromRGB(255, 215, 60),
}

local COLORS = {
	bg          = Color3.fromRGB(12, 10, 22),
	stroke      = Color3.fromRGB(138, 100, 214),
	name        = Color3.fromRGB(255, 255, 255),
	username    = Color3.fromRGB(175, 160, 210),
	goldName    = Color3.fromRGB(255, 220, 50),
	greyName    = Color3.fromRGB(160, 155, 175),
	redName     = Color3.fromRGB(220, 80, 100),
	textStroke  = Color3.fromRGB(20, 12, 40),
}

-- -------------------------------------------
-- PER-PLAYER STATE
-- -------------------------------------------
local platforms    = {} -- [Player] = "PC" | "Mobile" | "Console"
local repTitles    = {} -- [Player] = { title, color{R,G,B}, score }

-- -------------------------------------------
-- HELPER: color from table {R,G,B}
-- -------------------------------------------
local function tblColor(t)
	if type(t) == "table" and #t >= 3 then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return Color3.fromRGB(100, 100, 135)
end

-- -------------------------------------------
-- APPLY REP VISUALS TO EXISTING BILLBOARD
-- (forward-declared so createOverheadLabel can reference it)
-- -------------------------------------------
local function applyRepVisuals(billboard, repInfo)
	if not billboard or not repInfo then return end
	local main = billboard:FindFirstChild("Main")
	if not main then return end

	local titleRow = main:FindFirstChild("TitleRow")
	local nameRow  = main:FindFirstChild("NameRow")
	if not titleRow or not nameRow then return end

	local titleLabel   = titleRow:FindFirstChild("TitleLabel")
	local nameLabel    = nameRow:FindFirstChild("DisplayName")
	local repSymbol    = nameRow:FindFirstChild("RepSymbol")

	local score    = repInfo.score or 0
	local title    = repInfo.title or "Visitor"
	local color    = repInfo.color or {100, 100, 135}

	-- Title text
	if titleLabel then
		titleLabel.Text = title
		-- Use curated tier color if available, fall back to server-sent color
		titleLabel.TextColor3 = TIERS_COLORS[title] or tblColor(color)
	end

	-- Name color based on rep tier
	if nameLabel then
		if score >= 1000 then
			nameLabel.TextColor3 = COLORS.goldName
		elseif score >= 500 then
			nameLabel.TextColor3 = Color3.fromRGB(255, 230, 150)
		elseif score >= 250 then
			nameLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
		elseif score >= 100 then
			nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
		elseif score <= -30 then
			nameLabel.TextColor3 = COLORS.redName
		elseif score < 0 then
			nameLabel.TextColor3 = COLORS.greyName
		else
			nameLabel.TextColor3 = COLORS.name
		end
	end

	-- Rep symbol removed — stars only appear in the title row now
	if repSymbol then
		repSymbol.Text = ""
		repSymbol.Visible = false
	end
end

local function playTitleUpgradeEffect(billboard, tierColor)
	if not billboard then return end
	local main = billboard:FindFirstChild("Main")
	if not main then return end

	local titleRow = main:FindFirstChild("TitleRow")
	local nameRow = main:FindFirstChild("NameRow")
	if not titleRow or not nameRow then return end

	local titleLabel = titleRow:FindFirstChild("TitleLabel")
	local nameLabel = nameRow:FindFirstChild("DisplayName")
	if not titleLabel or not nameLabel then return end

	local fxColor = tblColor(tierColor)

	local titleGlow = Instance.new("UIStroke")
	titleGlow.Color = fxColor
	titleGlow.Thickness = 2.2
	titleGlow.Transparency = 1
	titleGlow.Parent = titleLabel

	local nameGlow = Instance.new("UIStroke")
	nameGlow.Color = fxColor
	nameGlow.Thickness = 2
	nameGlow.Transparency = 1
	nameGlow.Parent = nameLabel

	local oldBg = main.BackgroundTransparency
	TweenService:Create(main, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = math.max(0.68, oldBg - 0.2),
	}):Play()

	TweenService:Create(titleGlow, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.08,
	}):Play()
	TweenService:Create(nameGlow, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.12,
	}):Play()

	task.delay(0.2, function()
		if not main.Parent then return end
		TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = oldBg,
		}):Play()
		TweenService:Create(titleGlow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
		TweenService:Create(nameGlow, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		}):Play()
		task.delay(0.4, function()
			titleGlow:Destroy()
			nameGlow:Destroy()
		end)
	end)
end

-- -------------------------------------------
-- BUILD OVERHEAD LABEL
-- -------------------------------------------
local function createOverheadLabel(character, player)
	local head = character:WaitForChild("Head", 5)
	if not head then return end

	-- Hide default Roblox nametag
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	-- Remove previous
	local old = head:FindFirstChild("OverheadLabel")
	if old then old:Destroy() end

	-- BillboardGui (stud-based = scales with distance)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "OverheadLabel"
	billboard.Size = UDim2.new(BILLBOARD_WIDTH, 0, BILLBOARD_HEIGHT, 0)
	billboard.StudsOffset = STUDS_OFFSET
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Adornee = head
	billboard.Parent = head

	-- Main container
	local main = Instance.new("Frame")
	main.Name = "Main"
	main.Size = UDim2.new(1, 0, 1, 0)
	main.BackgroundColor3 = COLORS.bg
	main.BackgroundTransparency = 0.85
	main.Parent = billboard

	Instance.new("UICorner", main).CornerRadius = UDim.new(0.1, 0)

	-- No border stroke (removed for cleaner look)

	-- subtle gradient overlay
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(180, 160, 220))
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Rotation = 90
	grad.Parent = main

	local padding = Instance.new("UIPadding")
	padding.PaddingTop    = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.PaddingLeft   = UDim.new(0.03, 0)
	padding.PaddingRight  = UDim.new(0.03, 0)
	padding.Parent = main

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = main

	-- ---------------------------------------
	-- ROW 1: Title (+ optional streak badge)
	-- ---------------------------------------
	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.Size = UDim2.new(1, 0, 0.22, 0)
	titleRow.BackgroundTransparency = 1
	titleRow.LayoutOrder = 1
	titleRow.Parent = main

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Visitor"
	titleLabel.TextColor3 = Color3.fromRGB(170, 155, 210)
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamMedium
	titleLabel.Parent = titleRow

	-- Text stroke for better readability (dark purple, thin)
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = COLORS.textStroke
	titleStroke.Transparency = 0.35
	titleStroke.Thickness = 0.8
	titleStroke.Parent = titleLabel

	-- ---------------------------------------
	-- ROW 2: Name row (rep symbol + name)
	-- ---------------------------------------
	local nameRow = Instance.new("Frame")
	nameRow.Name = "NameRow"
	nameRow.Size = UDim2.new(1, 0, 0.34, 0)
	nameRow.BackgroundTransparency = 1
	nameRow.LayoutOrder = 2
	nameRow.Parent = main

	local nameRowLayout = Instance.new("UIListLayout")
	nameRowLayout.FillDirection = Enum.FillDirection.Horizontal
	nameRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	nameRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	nameRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	nameRowLayout.Padding = UDim.new(0.012, 0)
	nameRowLayout.Parent = nameRow

	-- Rep symbol (crown/star for high rep)
	local repSymbol = Instance.new("TextLabel")
	repSymbol.Name = "RepSymbol"
	repSymbol.Size = UDim2.new(0.08, 0, 0.9, 0)
	repSymbol.BackgroundTransparency = 1
	repSymbol.Text = ""
	repSymbol.TextScaled = true
	repSymbol.Font = Enum.Font.GothamBold
	repSymbol.TextColor3 = COLORS.goldName
	repSymbol.LayoutOrder = 1
	repSymbol.Visible = false
	repSymbol.Parent = nameRow

	-- Text stroke for rep symbol (dark purple, thin)
	local repSymbolStroke = Instance.new("UIStroke")
	repSymbolStroke.Color = COLORS.textStroke
	repSymbolStroke.Transparency = 0.35
	repSymbolStroke.Thickness = 0.8
	repSymbolStroke.Parent = repSymbol

	-- Display name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "DisplayName"
	nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = COLORS.name
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.LayoutOrder = 2
	nameLabel.Parent = nameRow

	-- Text stroke for better readability (dark purple, thin)
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = COLORS.textStroke
	nameStroke.Transparency = 0.25
	nameStroke.Thickness = 1
	nameStroke.Parent = nameLabel

	-- ---------------------------------------
	-- ROW 3: @username (platform icon removed for cleanliness)
	-- ---------------------------------------
	local bottomRow = Instance.new("Frame")
	bottomRow.Name = "BottomRow"
	bottomRow.Size = UDim2.new(0.85, 0, 0.2, 0)
	bottomRow.BackgroundTransparency = 1
	bottomRow.LayoutOrder = 3
	bottomRow.Parent = main

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Name = "Username"
	usernameLabel.Size = UDim2.new(1, 0, 1, 0)
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.Text = "@" .. player.Name
	usernameLabel.TextColor3 = COLORS.username
	usernameLabel.TextScaled = true
	usernameLabel.Font = Enum.Font.Gotham
	usernameLabel.Parent = bottomRow

	-- Text stroke for better readability (dark purple, thin)
	local usernameStroke = Instance.new("UIStroke")
	usernameStroke.Color = COLORS.textStroke
	usernameStroke.Transparency = 0.4
	usernameStroke.Thickness = 0.6
	usernameStroke.Parent = usernameLabel

	-- Apply initial rep visuals if available
	local repInfo = repTitles[player]
	if repInfo then
		applyRepVisuals(billboard, repInfo)
	end

	return billboard
end

-- -------------------------------------------
-- FIND BILLBOARD FOR PLAYER
-- -------------------------------------------
local function getBillboard(player)
	local character = player.Character
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	return head:FindFirstChild("OverheadLabel")
end

-- -------------------------------------------
-- SET PLATFORM ICON
-- -------------------------------------------
local function setPlatformIcon(player, platform)
	local bb = getBillboard(player)
	if not bb then return end
	local main = bb:FindFirstChild("Main")
	if not main then return end
	local row = main:FindFirstChild("BottomRow")
	if not row then return end
	local icon = row:FindFirstChild("PlatformIcon")
	if icon then
		icon.Text = PLATFORM_SYMBOLS[platform] or PLATFORM_SYMBOLS.Unknown
	end
end

-- -------------------------------------------
-- REMOTE HANDLERS
-- -------------------------------------------
ReportPlatformEvent.OnServerEvent:Connect(function(player, platform)
	if type(platform) ~= "string" then return end
	local valid = { PC = true, Mobile = true, Console = true }
	if not valid[platform] then return end
	platforms[player] = platform
	setPlatformIcon(player, platform)
end)

-- -------------------------------------------
-- SERVER-SIDE REP UPDATE HOOK
-- ReputationServer calls _G.FireRepUpdateForNametag(payload)
-- to push rep changes into the nametag without client round-trips.
-- -------------------------------------------
local repBindable = Instance.new("BindableEvent")
repBindable.Name = "RepUpdateInternal"
repBindable.Parent = script

_G.FireRepUpdateForNametag = function(payload)
	repBindable:Fire(payload)
end

repBindable.Event:Connect(function(payload)
	if not payload or not payload.userId then return end
	local targetPlayer = Players:GetPlayerByUserId(payload.userId)
	if not targetPlayer then return end

	repTitles[targetPlayer] = {
		score = payload.score,
		title = payload.title,
		color = payload.tierColor,
	}

	local bb = getBillboard(targetPlayer)
	if bb then
		applyRepVisuals(bb, repTitles[targetPlayer])
		if payload.titleUpgraded then
			playTitleUpgradeEffect(bb, payload.tierColor)
		end
	end
end)

-- -------------------------------------------
-- PLAYER CONNECTIONS
-- -------------------------------------------
local function onCharacterAdded(player, character)
	task.wait(0.5)
	createOverheadLabel(character, player)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	-- Load initial rep data for nametag via shared _G function
	task.spawn(function()
		task.wait(2) -- let ReputationServer load first
		if _G.GetRepDataForPlayer then
			local data = _G.GetRepDataForPlayer(player.UserId)
			if data then
				repTitles[player] = {
					score = data.score,
					title = data.title,
					color = data.tierColor,
				}
				local bb = getBillboard(player)
				if bb then
					applyRepVisuals(bb, repTitles[player])
				end
			end
		end
	end)

	if player.Character then
		task.spawn(function()
			onCharacterAdded(player, player.Character)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() onPlayerAdded(p) end)
end

Players.PlayerRemoving:Connect(function(player)
	platforms[player] = nil
	repTitles[player] = nil
end)

print("[OverheadLabel] Overhead label system initialized.")