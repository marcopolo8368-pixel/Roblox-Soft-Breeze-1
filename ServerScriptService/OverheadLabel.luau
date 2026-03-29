--[[
    OverheadLabel.lua  (with Particle Aura System)
    Location: ServerScriptService

    Layout (top to bottom):
      Row 1: Tier Title  (colored by reputation tier)
      Row 2: DisplayName  (color reflects rep score)
      Row 3: @username

    PARTICLE AURA SYSTEM:
      Each tier gets a unique ParticleEmitter attached to an invisible
      Part welded to the player's Head. Particles float around the head
      area where the nametag sits.

      HOW TO SWAP IN YOUR CUSTOM IMAGES:
        1. Upload your image to Roblox (Toolbox ? My Decals ? Get Asset ID)
        2. Find the TIER_PARTICLES table below
        3. Replace the `texture` value for the relevant tier with:
               "rbxassetid://YOUR_ASSET_ID_HERE"
        4. Each tier has a comment describing what style it should look like

    TIER PARTICLE STYLES:
      Visitor     ? NO particles (starting rank, particles are a reward)
      Shady       ? smoky red wisps flickering
      Rising      ? crisp blue upward sparks
      Famous      ? warm gold floating stars
      Trendsetter ? purple+pink swirling orbs
      Influencer  ? bright pink fast sparkle burst
      Celebrity   ? golden royal large sparkles + extra emitter
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Remotes             = ReplicatedStorage:WaitForChild("Remotes")
local ReportPlatformEvent = Remotes:WaitForChild("ReportPlatform")

-- -------------------------------------------------------------
-- CONFIGURATION
-- -------------------------------------------------------------
local MAX_DISTANCE     = 60
local BILLBOARD_WIDTH  = 6
local BILLBOARD_HEIGHT = 1.8
local STUDS_OFFSET     = Vector3.new(0, 2.6, 0)

local EMITTER_OFFSET    = Vector3.new(0, 2.2, 0)
local EMITTER_PART_SIZE = Vector3.new(3.2, 1.2, 1)
local DEBUG_AURA_LOGS   = true

-- Reaction burst icon textures (replace with your uploaded Image IDs)
local REACTION_TEXTURES = {
	thumbsUp   = "rbxassetid://102448280192630",
	thumbsDown = "rbxassetid://135116686850169",
	love       = "rbxassetid://95116013239453",
}

local PLATFORM_SYMBOLS = {
	PC = "[PC]", Mobile = "[M]", Console = "[C]", Unknown = "[?]",
}

local TIERS_COLORS = {
	Shady       = Color3.fromRGB(200, 75,  85),
	Visitor     = Color3.fromRGB(175, 160, 215),
	Rising      = Color3.fromRGB(100, 180, 255),
	Famous      = Color3.fromRGB(255, 195, 65),
	Trendsetter = Color3.fromRGB(190, 140, 255),
	Influencer  = Color3.fromRGB(255, 130, 220),
	Celebrity   = Color3.fromRGB(255, 215, 60),
}

local COLORS = {
	bg         = Color3.fromRGB(12,  10,  22),
	name       = Color3.fromRGB(255, 255, 255),
	username   = Color3.fromRGB(175, 160, 210),
	goldName   = Color3.fromRGB(255, 220, 50),
	greyName   = Color3.fromRGB(160, 155, 175),
	redName    = Color3.fromRGB(220, 80,  100),
	textStroke = Color3.fromRGB(20,  12,  40),
}

-- -------------------------------------------------------------
-- TIER PARTICLE DEFINITIONS
--
-- Each tier is a list of emitter configs (Celebrity gets 2).
-- Properties map 1:1 to ParticleEmitter properties.
--
-- texture      ? REPLACE with "rbxassetid://YOUR_ID"
--               Roblox built-in fallback textures are used by default so
--               you can see something in-game before swapping.
--
-- ??  IMPORTANT: Use the IMAGE asset ID, NOT the DECAL asset ID!
--     When you upload a Decal, Roblox gives you a Decal ID, but the
--     ParticleEmitter.Texture property needs the underlying IMAGE ID.
--     To find it: Insert a Decal into a Part in Studio, paste your
--     Decal ID into the Texture property, then look at what Studio
--     resolves it to in the Properties panel � that's the Image ID.
--     (They are different numbers!)
--
-- Built-in texture IDs you can use as placeholders:
--   Star/sparkle:  "rbxassetid://6101261905"
--   Soft circle:   "rbxassetid://243660364"
--   Smoke wisp:    "rbxassetid://1369397597"
-- -------------------------------------------------------------
local TIER_PARTICLES = {}

-- -------------------------------------------------------------
-- PER-PLAYER STATE
-- -------------------------------------------------------------
local platforms = {}
local repTitles = {}
local labelEffectsEnabled = {}

local function isLabelEffectsEnabled(player)
	if not player then return true end
	local explicit = labelEffectsEnabled[player]
	if explicit == nil then
		local attr = player:GetAttribute("LabelEffectsEnabled")
		if attr == nil then return true end
		return attr == true
	end
	return explicit == true
end

-- -------------------------------------------------------------
-- HELPERS
-- -------------------------------------------------------------
local function tblColor(t)
	if type(t) == "table" and #t >= 3 then
		return Color3.fromRGB(t[1], t[2], t[3])
	end
	return Color3.fromRGB(100, 100, 135)
end

local function dlog(...)
	if DEBUG_AURA_LOGS then
		print("[OverheadLabelDBG]", ...)
	end
end

local function clearParticleAura(character)
	if not character then return end
	local oldPart = character:FindFirstChild("TierAuraPart")
	if oldPart then oldPart:Destroy() end
	local head = character:FindFirstChild("Head")
	if head then
		local oldAttachment = head:FindFirstChild("TierAuraAttachment")
		if oldAttachment then oldAttachment:Destroy() end
	end
end

local function clearReactionAura(character)
	if not character then return end
	local old = character:FindFirstChild("ReactionAuraPart")
	if old then old:Destroy() end
end

local function playReactionAura(character, action)
	if type(action) ~= "string" then return end
	local head = character and character:FindFirstChild("Head")
	if not head then
		dlog("playReactionAura aborted: no head on", character and character.Name or "nil")
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player and not isLabelEffectsEnabled(player) then
		dlog("playReactionAura aborted: LabelEffects disabled for", player.Name)
		return
	end

	local texture = REACTION_TEXTURES[action]
	if not texture then
		dlog("playReactionAura aborted: unknown action", action)
		return
	end

	clearReactionAura(character)

	local root = character:FindFirstChild("HumanoidRootPart") or head
	dlog("playReactionAura CREATING burst", action, "on", character.Name, "texture=", texture, "anchor=", root.Name)

	local auraPart = Instance.new("Part")
	auraPart.Name = "ReactionAuraPart"
	auraPart.Size = Vector3.new(3.2, 3.2, 3.2)
	auraPart.Transparency = 1
	auraPart.CanCollide = false
	auraPart.CanTouch = false
	auraPart.CanQuery = false
	auraPart.Massless = true
	auraPart.Anchored = false
	auraPart.CastShadow = false
	auraPart.CFrame = root.CFrame
	auraPart.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = auraPart
	weld.Parent = auraPart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.LightEmission = 1
	emitter.LightInfluence = 0

	if action == "love" then
		emitter.Color = ColorSequence.new(
			Color3.fromRGB(255, 185, 225),
			Color3.fromRGB(255, 80, 170)
		)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.0),
			NumberSequenceKeypoint.new(0.5, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(0.3, 0.75),
			NumberSequenceKeypoint.new(1, 0.0),
		})
		emitter.Lifetime = NumberRange.new(1.0, 1.6)
		emitter.Speed = NumberRange.new(3.0, 6.0)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-90, 90)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 200
		emitter.Enabled = true
		emitter.Parent = auraPart
		dlog("love burst started (Rate=200 for 0.25s)")
	else
		local isDown = action == "thumbsDown"
		emitter.Color = isDown and ColorSequence.new(
			Color3.fromRGB(255, 165, 165),
			Color3.fromRGB(220, 85, 95)
		) or ColorSequence.new(
			Color3.fromRGB(180, 235, 255),
			Color3.fromRGB(110, 175, 255)
		)
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.0),
			NumberSequenceKeypoint.new(0.6, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.4, 0.65),
			NumberSequenceKeypoint.new(1, 0.0),
		})
		emitter.Lifetime = NumberRange.new(1.0, 1.4)
		emitter.Speed = NumberRange.new(2.0, 4.5)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-30, 30)
		emitter.SpreadAngle = Vector2.new(150, 150)
		emitter.Rate = 120
		emitter.Enabled = true
		emitter.Parent = auraPart
		dlog(action, "burst started (Rate=120 for 0.25s)")
	end

	task.delay(0.25, function()
		if emitter and emitter.Parent then
			emitter.Enabled = false
			emitter.Rate = 0
		end
	end)
	task.delay(2.5, function()
		if auraPart and auraPart.Parent then
			auraPart:Destroy()
		end
	end)
end

-- -------------------------------------------------------------
-- PARTICLE AURA BUILDER
-- -------------------------------------------------------------
local function applyParticleAura(character, title)
	local head = character:FindFirstChild("Head")
	if not head then
		dlog("applyParticleAura aborted: no head", character and character.Name or "nil", title)
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player and not isLabelEffectsEnabled(player) then
		clearParticleAura(character)
		dlog("applyParticleAura skipped: LabelEffects disabled", player.Name)
		return
	end

	clearParticleAura(character)

	local configs = TIER_PARTICLES[title]
	-- Empty table = Visitor (no particles by design), nil = unknown tier
	if not configs then
		dlog("applyParticleAura aborted: no configs for title", title)
		return
	end

	-- Visitor has an empty table � skip cleanly with no errors
	if #configs == 0 then
		dlog("applyParticleAura skipped: Visitor has no particles by design")
		return
	end

	dlog("applyParticleAura start", character.Name, "title=", title, "emitters=", #configs)

	local auraPart = Instance.new("Part")
	auraPart.Name          = "TierAuraPart"
	auraPart.Size          = EMITTER_PART_SIZE
	auraPart.Transparency  = 1
	auraPart.CanCollide    = false
	auraPart.CanTouch      = false
	auraPart.CanQuery      = false
	auraPart.Massless      = true
	auraPart.Anchored      = false
	auraPart.CastShadow    = false
	auraPart.CFrame        = head.CFrame * CFrame.new(EMITTER_OFFSET)
	auraPart.Parent        = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0  = head
	weld.Part1  = auraPart
	weld.Parent = auraPart

	dlog("aura part created", auraPart:GetFullName(), "size=", tostring(EMITTER_PART_SIZE))

	for _, cfg in ipairs(configs) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture        = cfg.texture
		emitter.Color          = cfg.color
		emitter.Transparency   = cfg.transparency
		emitter.Size           = cfg.size
		emitter.Rate           = cfg.rate
		emitter.Speed          = cfg.speed
		emitter.Lifetime       = cfg.lifetime
		emitter.Rotation       = cfg.rotation
		emitter.RotSpeed       = cfg.rotSpeed
		emitter.SpreadAngle    = Vector2.new(cfg.spread, cfg.spread)
		emitter.LightEmission  = cfg.lightEmission
		emitter.LightInfluence = cfg.lightInfluence
		emitter.Enabled        = true
		emitter.Parent         = auraPart
		dlog("emitter created", "texture=", cfg.texture, "rate=", cfg.rate)
	end

	dlog("applyParticleAura complete", character.Name, title)
end

-- -------------------------------------------------------------
-- TITLE UPGRADE BURST
-- -------------------------------------------------------------
local function playUpgradeBurst(character, tierColor)
	local head = character:FindFirstChild("Head")
	if not head then return end

	local burstAttachment = Instance.new("Attachment")
	burstAttachment.Name = "TierUpgradeBurst"
	burstAttachment.Position = EMITTER_OFFSET
	burstAttachment.Parent = head

	local fxColor = tblColor(tierColor)

	local burst = Instance.new("ParticleEmitter")
	burst.Texture        = "rbxassetid://6101261905"
	burst.Color          = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.2, fxColor),
		ColorSequenceKeypoint.new(1,   fxColor),
	})
	burst.Transparency   = NumberSequence.new({
		NumberSequenceKeypoint.new(0,   0),
		NumberSequenceKeypoint.new(0.6, 0.4),
		NumberSequenceKeypoint.new(1,   1),
	})
	burst.Size           = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Rate           = 0
	burst.Speed          = NumberRange.new(3, 6)
	burst.Lifetime       = NumberRange.new(0.6, 1.2)
	burst.Rotation       = NumberRange.new(0, 360)
	burst.RotSpeed       = NumberRange.new(-200, 200)
	burst.SpreadAngle    = Vector2.new(80, 80)
	burst.LightEmission  = 1
	burst.LightInfluence = 0
	burst.Parent         = burstAttachment

	burst:Emit(40)

	task.delay(2, function()
		if burstAttachment and burstAttachment.Parent then
			burstAttachment:Destroy()
		end
	end)
end

-- -------------------------------------------------------------
-- APPLY REP VISUALS
-- -------------------------------------------------------------
local function applyRepVisuals(billboard, repInfo, character)
	if not billboard or not repInfo then return end
	local main = billboard:FindFirstChild("Main")
	if not main then return end

	local titleRow = main:FindFirstChild("TitleRow")
	local nameRow  = main:FindFirstChild("NameRow")
	if not titleRow or not nameRow then return end

	local titleLabel = titleRow:FindFirstChild("TitleLabel")
	local nameLabel  = nameRow:FindFirstChild("DisplayName")
	local repSymbol  = nameRow:FindFirstChild("RepSymbol")

	local score = repInfo.score or 0
	local title = repInfo.title or "Visitor"
	local color = repInfo.color or {100, 100, 135}
	dlog("applyRepVisuals", "score=", score, "title=", title, "hasCharacter=", character ~= nil)

	if titleLabel then
		-- Custom title (from gamepass) overrides the tier title
		local player = Players:GetPlayerFromCharacter(character or (billboard and billboard.Parent and billboard.Parent.Parent))
		local customTitle = player and player:GetAttribute("CustomTitle")
		if customTitle and customTitle ~= "" then
			titleLabel.Text       = customTitle
			titleLabel.TextColor3 = Color3.new(1, 1, 1) -- animator handles gradient color
		else
			titleLabel.Text = title
			if title == "Visitor" then
				titleLabel.TextColor3 = TIERS_COLORS["Visitor"] or tblColor(color)
				titleLabel.Font = Enum.Font.GothamMedium
				-- Clear gradient for Visitor (no animated title)
				local oldGrad = titleLabel:FindFirstChildOfClass("UIGradient")
				if oldGrad then oldGrad:Destroy() end
			else
				-- Non-Visitor tiers: set white so client gradient animator can overlay
				titleLabel.TextColor3 = Color3.new(1, 1, 1)
				titleLabel.Font = Enum.Font.GothamBold
			end
		end
	end

	if nameLabel then
		if     score >= 1000 then nameLabel.TextColor3 = COLORS.goldName
		elseif score >= 500  then nameLabel.TextColor3 = Color3.fromRGB(255, 230, 150)
		elseif score >= 250  then nameLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
		elseif score >= 100  then nameLabel.TextColor3 = Color3.fromRGB(255, 235, 180)
		elseif score <= -30  then nameLabel.TextColor3 = COLORS.redName
		elseif score < 0     then nameLabel.TextColor3 = COLORS.greyName
		else                      nameLabel.TextColor3 = COLORS.name
		end
	end

	if repSymbol then
		repSymbol.Text    = ""
		repSymbol.Visible = false
	end

	if character then
		applyParticleAura(character, title)
	end
end

-- -------------------------------------------------------------
-- BUILD OVERHEAD LABEL
-- -------------------------------------------------------------
local function createOverheadLabel(character, player)
	local head = character:WaitForChild("Head", 5)
	if not head then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	local old = head:FindFirstChild("OverheadLabel")
	if old then old:Destroy() end

	local billboard = Instance.new("BillboardGui")
	billboard.Name           = "OverheadLabel"
	billboard.Size           = UDim2.new(BILLBOARD_WIDTH, 0, BILLBOARD_HEIGHT, 0)
	billboard.StudsOffset    = STUDS_OFFSET
	billboard.AlwaysOnTop    = false
	billboard.MaxDistance    = MAX_DISTANCE
	billboard.LightInfluence = 0
	billboard.Adornee        = head
	billboard.Parent         = head

	local main = Instance.new("Frame")
	main.Name                   = "Main"
	main.Size                   = UDim2.new(1, 0, 1, 0)
	main.BackgroundColor3       = COLORS.bg
	main.BackgroundTransparency = 0.85
	main.Parent                 = billboard
	Instance.new("UICorner", main).CornerRadius = UDim.new(0.1, 0)

	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.new(1,1,1), Color3.fromRGB(180, 160, 220))
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.92),
		NumberSequenceKeypoint.new(1, 1),
	})
	grad.Rotation = 90
	grad.Parent   = main

	local padding = Instance.new("UIPadding")
	padding.PaddingTop    = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.PaddingLeft   = UDim.new(0.03, 0)
	padding.PaddingRight  = UDim.new(0.03, 0)
	padding.Parent = main

	local layout = Instance.new("UIListLayout")
	layout.SortOrder           = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment   = Enum.VerticalAlignment.Center
	layout.Padding             = UDim.new(0.02, 0)
	layout.Parent              = main

	-- -- ROW 1: Title -------------------------------------------------
	local titleRow = Instance.new("Frame")
	titleRow.Name                   = "TitleRow"
	titleRow.Size                   = UDim2.new(1, 0, 0.22, 0)
	titleRow.BackgroundTransparency = 1
	titleRow.LayoutOrder            = 1
	titleRow.Parent                 = main

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name               = "TitleLabel"
	titleLabel.Size               = UDim2.new(1, 0, 1, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text               = "Visitor"
	titleLabel.TextColor3         = Color3.fromRGB(170, 155, 210)
	titleLabel.TextScaled         = true
	titleLabel.Font               = Enum.Font.GothamMedium
	titleLabel.Parent             = titleRow

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color        = COLORS.textStroke
	titleStroke.Transparency = 0.35
	titleStroke.Thickness    = 0.8
	titleStroke.Parent       = titleLabel

	-- -- ROW 2: Name --------------------------------------------------
	local nameRow = Instance.new("Frame")
	nameRow.Name                   = "NameRow"
	nameRow.Size                   = UDim2.new(1, 0, 0.34, 0)
	nameRow.BackgroundTransparency = 1
	nameRow.LayoutOrder            = 2
	nameRow.Parent                 = main

	local nameRowLayout = Instance.new("UIListLayout")
	nameRowLayout.FillDirection       = Enum.FillDirection.Horizontal
	nameRowLayout.SortOrder           = Enum.SortOrder.LayoutOrder
	nameRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	nameRowLayout.VerticalAlignment   = Enum.VerticalAlignment.Center
	nameRowLayout.Padding             = UDim.new(0.012, 0)
	nameRowLayout.Parent              = nameRow

	local repSymbol = Instance.new("TextLabel")
	repSymbol.Name               = "RepSymbol"
	repSymbol.Size               = UDim2.new(0.08, 0, 0.9, 0)
	repSymbol.BackgroundTransparency = 1
	repSymbol.Text               = ""
	repSymbol.TextScaled         = true
	repSymbol.Font               = Enum.Font.GothamBold
	repSymbol.TextColor3         = COLORS.goldName
	repSymbol.LayoutOrder        = 1
	repSymbol.Visible            = false
	repSymbol.Parent             = nameRow
	local rsStroke = Instance.new("UIStroke")
	rsStroke.Color = COLORS.textStroke; rsStroke.Transparency = 0.35
	rsStroke.Thickness = 0.8; rsStroke.Parent = repSymbol

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name               = "DisplayName"
	nameLabel.Size               = UDim2.new(0.6, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text               = player.DisplayName
	nameLabel.TextColor3         = COLORS.name
	nameLabel.TextScaled         = true
	nameLabel.Font               = Enum.Font.GothamBold
	nameLabel.LayoutOrder        = 2
	nameLabel.Parent             = nameRow
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = COLORS.textStroke; nameStroke.Transparency = 0.25
	nameStroke.Thickness = 1; nameStroke.Parent = nameLabel

	-- -- ROW 3: @username ---------------------------------------------
	local bottomRow = Instance.new("Frame")
	bottomRow.Name                   = "BottomRow"
	bottomRow.Size                   = UDim2.new(0.85, 0, 0.2, 0)
	bottomRow.BackgroundTransparency = 1
	bottomRow.LayoutOrder            = 3
	bottomRow.Parent                 = main

	local usernameLabel = Instance.new("TextLabel")
	usernameLabel.Name               = "Username"
	usernameLabel.Size               = UDim2.new(1, 0, 1, 0)
	usernameLabel.BackgroundTransparency = 1
	usernameLabel.Text               = "@" .. player.Name
	usernameLabel.TextColor3         = COLORS.username
	usernameLabel.TextScaled         = true
	usernameLabel.Font               = Enum.Font.Gotham
	usernameLabel.Parent             = bottomRow
	local usernameStroke = Instance.new("UIStroke")
	usernameStroke.Color = COLORS.textStroke; usernameStroke.Transparency = 0.4
	usernameStroke.Thickness = 0.6; usernameStroke.Parent = usernameLabel

	-- Apply initial rep + particles if data already loaded
	local repInfo = repTitles[player]
	if repInfo then
		applyRepVisuals(billboard, repInfo, character)
	end
	-- Visitors get no particles � nothing to apply on first join

	return billboard
end

-- -------------------------------------------------------------
-- UTILITY
-- -------------------------------------------------------------
local function getBillboard(player)
	local character = player.Character
	if not character then return nil end
	local head = character:FindFirstChild("Head")
	if not head then return nil end
	return head:FindFirstChild("OverheadLabel")
end

local function setPlatformIcon(player, platform)
	local bb = getBillboard(player)
	if not bb then return end
	local main = bb:FindFirstChild("Main")
	if not main then return end
	local row = main:FindFirstChild("BottomRow")
	if not row then return end
	local icon = row:FindFirstChild("PlatformIcon")
	if icon then icon.Text = PLATFORM_SYMBOLS[platform] or PLATFORM_SYMBOLS.Unknown end
end

-- -------------------------------------------------------------
-- REMOTES
-- -------------------------------------------------------------
ReportPlatformEvent.OnServerEvent:Connect(function(player, platform)
	if type(platform) ~= "string" then return end
	local valid = { PC = true, Mobile = true, Console = true }
	if not valid[platform] then return end
	platforms[player] = platform
	setPlatformIcon(player, platform)
end)

local repBindable = Instance.new("BindableEvent")
repBindable.Name   = "RepUpdateInternal"
repBindable.Parent = script

_G.FireRepUpdateForNametag = function(payload)
	repBindable:Fire(payload)
end

_G.FireRepReactionForNametag = function(targetUserId, action)
	local player = Players:GetPlayerByUserId(targetUserId)
	if not player then return end
	local character = player.Character
	if not character then return end
	playReactionAura(character, action)
end

repBindable.Event:Connect(function(payload)
	if not payload or not payload.userId then return end
	dlog("rep payload received", "userId=", payload.userId, "score=", payload.score, "title=", payload.title, "upgraded=", payload.titleUpgraded == true)
	local targetPlayer = Players:GetPlayerByUserId(payload.userId)
	if not targetPlayer then return end

	repTitles[targetPlayer] = {
		score = payload.score,
		title = payload.title,
		color = payload.tierColor,
	}

	local bb        = getBillboard(targetPlayer)
	local character = targetPlayer.Character
	if bb then
		applyRepVisuals(bb, repTitles[targetPlayer], character)
		if payload.titleUpgraded and character then
			playUpgradeBurst(character, payload.tierColor)
		end
	end
end)

-- -------------------------------------------------------------
-- PLAYER LIFECYCLE
-- -------------------------------------------------------------
local function onCharacterAdded(player, character)
	task.wait(0.5)
	dlog("onCharacterAdded", player.Name, character.Name)
	createOverheadLabel(character, player)
	local repInfo = repTitles[player]
	if repInfo then
		dlog("reapplying aura after respawn", player.Name, repInfo.title)
		applyParticleAura(character, repInfo.title or "Visitor")
	end
	-- Visitors get nothing on spawn � intentional
end

local function onPlayerAdded(player)
	local attr = player:GetAttribute("LabelEffectsEnabled")
	labelEffectsEnabled[player] = (attr ~= false)

	-- Refresh overhead label when player sets/changes their custom title
	player:GetAttributeChangedSignal("CustomTitle"):Connect(function()
		local repInfo = repTitles[player]
		if not repInfo then return end
		local bb = getBillboard(player)
		if bb then
			applyRepVisuals(bb, repInfo, player.Character)
		end
	end)

	player:GetAttributeChangedSignal("LabelEffectsEnabled"):Connect(function()
		local enabled = player:GetAttribute("LabelEffectsEnabled")
		labelEffectsEnabled[player] = (enabled ~= false)
		local character = player.Character
		if not character then return end

		if not labelEffectsEnabled[player] then
			clearParticleAura(character)
			dlog("label effects disabled", player.Name)
			return
		end

		local repInfo = repTitles[player]
		local title = repInfo and repInfo.title or "Visitor"
		applyParticleAura(character, title)
		dlog("label effects enabled", player.Name, "title=", title)
	end)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	task.spawn(function()
		task.wait(2)
		if _G.GetRepDataForPlayer then
			local data = _G.GetRepDataForPlayer(player.UserId)
			if data then
				dlog("initial rep pull", player.Name, "score=", data.score, "title=", data.title)
				repTitles[player] = {
					score = data.score,
					title = data.title,
					color = data.tierColor,
				}
				local bb = getBillboard(player)
				if bb then
					applyRepVisuals(bb, repTitles[player], player.Character)
				end
			end
		end
	end)

	if player.Character then
		task.spawn(function() onCharacterAdded(player, player.Character) end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(function() onPlayerAdded(p) end)
end

Players.PlayerRemoving:Connect(function(player)
	platforms[player] = nil
	repTitles[player] = nil
	labelEffectsEnabled[player] = nil
end)

print("[OverheadLabel] Particle aura system initialized.")
