	--[[
		ShopGui.lua  (v6 — no scroll, mobile responsive, UIStroke cursor glow)
		Location: StarterPlayerScripts
	]]

	local Players            = game:GetService("Players")
	local MarketplaceService = game:GetService("MarketplaceService")
	local TweenService       = game:GetService("TweenService")
	local ReplicatedStorage  = game:GetService("ReplicatedStorage")
	local UserInputService   = game:GetService("UserInputService")
	local RunService         = game:GetService("RunService")

	local player    = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local Remotes            = ReplicatedStorage:WaitForChild("Remotes")
	local CheckPassOwnership = Remotes:WaitForChild("CheckPassOwnership")

	-- ============================================================
	-- GAMEPASS IDs — must match GamepassServer.lua
	-- ============================================================
	local GAMEPASS_IDS = {
		VIP               = 1760183288,
		RepBoost          = 1759481294,
		CardCustomization = 1760699290,
		CustomTitle       = 1760843277,
	}

	-- ============================================================
	-- RESPONSIVE SIZING
	-- ============================================================
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local IS_MOBILE = vp.X < 700 or vp.Y < 500

	local CARD_H = IS_MOBILE and 78 or 96
	local CARD_GAP = IS_MOBILE and 8 or 10
	local HEADER_H = IS_MOBILE and 50 or 58
	local PAD_TOP = IS_MOBILE and 10 or 14
	local PAD_BOTTOM = IS_MOBILE and 12 or 16
	local PAD_SIDE = IS_MOBILE and 12 or 16

	-- Calculate exact panel height to fit 4 cards without scrolling
	local PANEL_W = IS_MOBILE and math.clamp(math.floor(vp.X * 0.92), 300, 460) or 480
	local PANEL_H = HEADER_H + PAD_TOP + (4 * CARD_H) + (3 * CARD_GAP) + PAD_BOTTOM

	local C = {
		bg       = Color3.fromRGB(10, 10, 18),
		panel    = Color3.fromRGB(16, 16, 28),
		header   = Color3.fromRGB(20, 18, 34),
		card     = Color3.fromRGB(18, 16, 32),
		row      = Color3.fromRGB(26, 24, 42),
		text     = Color3.fromRGB(220, 220, 240),
		textDim  = Color3.fromRGB(110, 110, 140),
		owned    = Color3.fromRGB(80,  200, 120),
		glow     = Color3.fromRGB(138, 100, 214),
		vip      = Color3.fromRGB(255, 200,  55),
		boost    = Color3.fromRGB( 80, 210, 130),
		cardCust = Color3.fromRGB(180, 110, 255),
		titleAcc = Color3.fromRGB( 80, 210, 255),
	}

	local function tw(inst, props, t, style)
		TweenService:Create(inst,
			TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			props):Play()
	end

	-- ============================================================
	-- SCREEN GUI  (no overlay — matches other menus)
	-- ============================================================
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name                  = "ShopGui"
	screenGui.ResetOnSpawn          = false
	screenGui.ZIndexBehavior        = Enum.ZIndexBehavior.Sibling
	screenGui.DisplayOrder          = 25
	screenGui.Enabled               = false
	screenGui.SafeAreaCompatibility = Enum.SafeAreaCompatibility.FullscreenExtension
	screenGui.Parent                = playerGui

	-- ============================================================
	-- MAIN PANEL (dark, matches admin/settings style)
	-- ============================================================
	local panel = Instance.new("Frame")
	panel.Name                   = "ShopPanel"
	panel.Size                   = UDim2.fromOffset(PANEL_W, PANEL_H)
	panel.Position               = UDim2.new(0.5, 0, 0.5, 0)
	panel.AnchorPoint            = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3       = C.bg
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel        = 0
	panel.ClipsDescendants       = true
	panel.Parent                 = screenGui

	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 20)

	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color        = C.glow
	panelStroke.Transparency = 0.6
	panelStroke.Thickness    = 1.5
	panelStroke.Parent       = panel

	local panelGrad = Instance.new("UIGradient")
	panelGrad.Rotation = 135
	panelGrad.Color    = ColorSequence.new(
		Color3.fromRGB(10, 10, 20),
		Color3.fromRGB(18, 14, 30)
	)
	panelGrad.Parent = panel

	-- ============================================================
	-- HEADER
	-- ============================================================
	local header = Instance.new("Frame")
	header.Name                   = "Header"
	header.Size                   = UDim2.new(1, 0, 0, HEADER_H)
	header.BackgroundColor3       = C.header
	header.BackgroundTransparency = 0.3
	header.BorderSizePixel        = 0
	header.Parent                 = panel
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 20)

	local headerMask = Instance.new("Frame")
	headerMask.Size                   = UDim2.new(1, 0, 0, 10)
	headerMask.Position               = UDim2.new(0, 0, 1, -10)
	headerMask.BackgroundColor3       = C.header
	headerMask.BackgroundTransparency = 0.3
	headerMask.BorderSizePixel        = 0
	headerMask.Parent                 = header

	local headerPad = Instance.new("UIPadding")
	headerPad.PaddingLeft  = UDim.new(0, 20)
	headerPad.PaddingRight = UDim.new(0, 20)
	headerPad.Parent       = header

	local shopTitle = Instance.new("TextLabel")
	shopTitle.Size                   = UDim2.new(1, -50, 1, 0)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text                   = "Shop"
	shopTitle.TextColor3             = C.text
	shopTitle.TextSize               = IS_MOBILE and 16 or 18
	shopTitle.Font                   = Enum.Font.GothamBold
	shopTitle.TextXAlignment         = Enum.TextXAlignment.Left
	shopTitle.Parent                 = header

	-- Close button (drawn X — identical to admin panel)
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name             = "Close"
	closeBtn.Size             = UDim2.new(0, IS_MOBILE and 36 or 40, 0, IS_MOBILE and 36 or 40)
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

	closeBtn.MouseEnter:Connect(function()
		tw(closeBtn, { BackgroundColor3 = Color3.fromRGB(180, 48, 55) }, 0.12)
	end)
	closeBtn.MouseLeave:Connect(function()
		tw(closeBtn, { BackgroundColor3 = C.row }, 0.12)
	end)

	-- ============================================================
	-- CARD CONTAINER (Frame, no scrolling)
	-- ============================================================
	local cardContainer = Instance.new("Frame")
	cardContainer.Name                 = "Cards"
	cardContainer.Size                 = UDim2.new(1, 0, 1, -HEADER_H)
	cardContainer.Position             = UDim2.new(0, 0, 0, HEADER_H)
	cardContainer.BackgroundTransparency = 1
	cardContainer.BorderSizePixel      = 0
	cardContainer.ZIndex               = 10
	cardContainer.Parent               = panel

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding   = UDim.new(0, CARD_GAP)
	listLayout.Parent    = cardContainer

	local listPad = Instance.new("UIPadding")
	listPad.PaddingTop    = UDim.new(0, PAD_TOP)
	listPad.PaddingBottom = UDim.new(0, PAD_BOTTOM)
	listPad.PaddingLeft   = UDim.new(0, PAD_SIDE)
	listPad.PaddingRight  = UDim.new(0, PAD_SIDE)
	listPad.Parent        = cardContainer

	-- ============================================================
	-- PASS DATA
	-- ============================================================
	local PASSES = {
		{ key="VIP",              name="VIP",          icon="👑",  accent=C.vip,      perks={"[VIP] gold chat tag","One-time +250 rep bonus"},   passId="VIP",              order=1, price=299 },
		{ key="RepBoost",         name="Rep Boost",     icon="x2", accent=C.boost,    perks={"All rep received doubled","Active forever"},          passId="RepBoost",         order=2, price=49 },
		{ key="CardCustomization",name="Card Styles",   icon="🎨",  accent=C.cardCust, perks={"Unique card style backgrounds","Stand out from the crowd"},  passId="CardCustomization",order=3, price=149 },
		{ key="CustomTitle",      name="Custom Title",  icon="T",  accent=C.titleAcc, perks={"Animated gradient title","Legend or Islander"},       passId="CustomTitle",      order=4, price=199 },
	}

	local owned      = { VIP=false, RepBoost=false, CardCustomization=false, CustomTitle=false }
	local buyButtons = {}

	local function refreshOwnership()
		local ok, data = pcall(function() return CheckPassOwnership:InvokeServer() end)
		if not ok or not data then return end
		owned.VIP               = data.VIP             == true
		owned.RepBoost          = data.RepBoost         == true
		owned.CardCustomization = data.CardCustomization == true
		owned.CustomTitle       = data.CustomTitle      == true

		for key, btn in pairs(buyButtons) do
			if owned[key] then
				btn.Text             = "Owned ✓"
				btn.BackgroundColor3 = C.owned
				btn.Active           = false
			end
		end
	end

	-- ============================================================
	-- PER-CARD CURSOR GLOW (UIGradient on UIStroke)
	-- ============================================================
	local cardGlowData = {} -- { strokeGrad = UIGradient, card = Frame }

	-- ============================================================
	-- BUILD CARDS
	-- ============================================================
	local function buildCard(p)
		local card = Instance.new("Frame")
		card.Name                   = p.key
		card.Size                   = UDim2.new(1, 0, 0, CARD_H)
		card.BackgroundColor3       = C.card
		card.BackgroundTransparency = 0.08
		card.BorderSizePixel        = 0
		card.LayoutOrder            = p.order
		card.ZIndex                 = 10
		card.Parent                 = cardContainer
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)

		-- Main UIStroke with UIGradient for cursor glow
		local stroke = Instance.new("UIStroke")
		stroke.Color        = p.accent
		stroke.Transparency = 0
		stroke.Thickness    = 1.5
		stroke.Parent       = card

		local strokeGrad = Instance.new("UIGradient")
		strokeGrad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0,    0.88),
			NumberSequenceKeypoint.new(0.3,  0.82),
			NumberSequenceKeypoint.new(0.5,  0.15),
			NumberSequenceKeypoint.new(0.7,  0.82),
			NumberSequenceKeypoint.new(1,    0.88),
		})
		strokeGrad.Color    = ColorSequence.new(p.accent)
		strokeGrad.Rotation = 0
		strokeGrad.Offset   = Vector2.new(0, 0)
		strokeGrad.Parent   = stroke

		table.insert(cardGlowData, { strokeGrad = strokeGrad, card = card })

		-- Icon bubble
		local iconSize = IS_MOBILE and 40 or 48
		local iconBg = Instance.new("Frame")
		iconBg.Size                   = UDim2.fromOffset(iconSize, iconSize)
		iconBg.Position               = UDim2.new(0, IS_MOBILE and 10 or 14, 0.5, 0)
		iconBg.AnchorPoint            = Vector2.new(0, 0.5)
		iconBg.BackgroundColor3       = p.accent
		iconBg.BackgroundTransparency = 0.82
		iconBg.BorderSizePixel        = 0
		iconBg.ZIndex                 = 11
		iconBg.Parent                 = card
		Instance.new("UICorner", iconBg).CornerRadius = UDim.new(0, 12)

		local iconS = Instance.new("UIStroke")
		iconS.Color        = p.accent
		iconS.Transparency = 0.5
		iconS.Thickness    = 1
		iconS.Parent       = iconBg

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Size                   = UDim2.new(1, 0, 1, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.Text                   = p.icon
		iconLbl.TextColor3             = p.accent
		iconLbl.TextSize               = IS_MOBILE and 16 or 20
		iconLbl.Font                   = Enum.Font.GothamBold
		iconLbl.ZIndex                 = 12
		iconLbl.Parent                 = iconBg

		-- Text X position (after icon)
		local textX = IS_MOBILE and 60 or 76

		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size                   = UDim2.new(0.5, -10, 0, IS_MOBILE and 18 or 22)
		nameLbl.Position               = UDim2.new(0, textX, 0, IS_MOBILE and 10 or 14)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text                   = p.name
		nameLbl.TextColor3             = C.text
		nameLbl.TextSize               = IS_MOBILE and 13 or 15
		nameLbl.Font                   = Enum.Font.GothamBold
		nameLbl.TextXAlignment         = Enum.TextXAlignment.Left
		nameLbl.ZIndex                 = 11
		nameLbl.Parent                 = card

		-- Perks
		local perksLbl = Instance.new("TextLabel")
		perksLbl.Size                   = UDim2.new(0.55, -textX, 0, IS_MOBILE and 30 or 38)
		perksLbl.Position               = UDim2.new(0, textX, 0, IS_MOBILE and 30 or 40)
		perksLbl.BackgroundTransparency = 1
		perksLbl.Text                   = "• " .. table.concat(p.perks, "\n• ")
		perksLbl.TextColor3             = C.textDim
		perksLbl.TextSize               = IS_MOBILE and 9 or 11
		perksLbl.Font                   = Enum.Font.Gotham
		perksLbl.TextXAlignment         = Enum.TextXAlignment.Left
		perksLbl.TextYAlignment         = Enum.TextYAlignment.Top
		perksLbl.TextWrapped            = true
		perksLbl.ZIndex                 = 11
		perksLbl.Parent                 = card

		-- Buy button
		local btnW = IS_MOBILE and 90 or 122
		local btnH = IS_MOBILE and 28 or 34
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size                   = UDim2.fromOffset(btnW, btnH)
		buyBtn.Position               = UDim2.new(1, -12, 0.5, 0)
		buyBtn.AnchorPoint            = Vector2.new(1, 0.5)
		buyBtn.BackgroundColor3       = p.accent
		buyBtn.BackgroundTransparency = 0.1
		buyBtn.Text                   = (GAMEPASS_IDS[p.passId] == 0) and "Coming Soon" or ("R$ " .. tostring(p.price or ""))
		buyBtn.TextColor3             = Color3.fromRGB(12, 12, 22)
		buyBtn.TextSize               = IS_MOBILE and 9 or 11
		buyBtn.Font                   = Enum.Font.GothamBold
		buyBtn.BorderSizePixel        = 0
		buyBtn.Active                 = (GAMEPASS_IDS[p.passId] ~= 0)
		buyBtn.ZIndex                 = 12
		buyBtn.Parent                 = card
		Instance.new("UICorner", buyBtn).CornerRadius = UDim.new(0, 10)

		buyButtons[p.key] = buyBtn

		-- Hover & click
		card.MouseEnter:Connect(function()
			tw(card, { BackgroundTransparency = 0 }, 0.15)
		end)
		card.MouseLeave:Connect(function()
			tw(card, { BackgroundTransparency = 0.08 }, 0.15)
		end)
		buyBtn.MouseEnter:Connect(function()
			if not owned[p.key] then tw(buyBtn, { BackgroundTransparency = 0 }, 0.12) end
		end)
		buyBtn.MouseLeave:Connect(function()
			if not owned[p.key] then tw(buyBtn, { BackgroundTransparency = 0.1 }, 0.12) end
		end)
		buyBtn.MouseButton1Click:Connect(function()
			if owned[p.key] or GAMEPASS_IDS[p.passId] == 0 then return end
			MarketplaceService:PromptGamePassPurchase(player, GAMEPASS_IDS[p.passId])
		end)
	end

	for _, pi in ipairs(PASSES) do buildCard(pi) end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(_, passId, wasPurchased)
		if not wasPurchased then return end
		for _, pi in ipairs(PASSES) do
			if passId == GAMEPASS_IDS[pi.passId] then
				owned[pi.key] = true
				refreshOwnership()
				break
			end
		end
	end)

	-- ============================================================
	-- CURSOR GLOW — RenderStepped
	-- ============================================================
	RunService.RenderStepped:Connect(function()
		if not screenGui.Enabled then return end
		local mPos = UserInputService:GetMouseLocation()

		for _, entry in ipairs(cardGlowData) do
			local card = entry.card
			local sg   = entry.strokeGrad
			local ap   = card.AbsolutePosition
			local as   = card.AbsoluteSize

			local cx   = ap.X + as.X * 0.5
			local cy   = ap.Y + as.Y * 0.5
			local relX = (mPos.X - cx) / (as.X * 0.5)
			local relY = (mPos.Y - cy) / (as.Y * 0.5)

			local angle = math.deg(math.atan2(relY, relX))
			sg.Rotation = angle

			sg.Offset = Vector2.new(
				math.clamp(relX * 0.3, -0.5, 0.5),
				math.clamp(relY * 0.3, -0.5, 0.5)
			)
		end
	end)

	-- ============================================================
	-- OPEN / CLOSE
	-- ============================================================
	local isOpen = false

	local function openShop()
		if isOpen then return end
		isOpen = true
		screenGui.Enabled            = true
		panel.Size                   = UDim2.fromOffset(PANEL_W, 10)
		panel.BackgroundTransparency = 1
		tw(panel, { Size = UDim2.fromOffset(PANEL_W, PANEL_H), BackgroundTransparency = 0.05 }, 0.28, Enum.EasingStyle.Back)
		task.spawn(refreshOwnership)
	end

	local function closeShop()
		if not isOpen then return end
		isOpen = false
		tw(panel, { Size = UDim2.fromOffset(PANEL_W, 10), BackgroundTransparency = 1 }, 0.2)
		task.delay(0.22, function()
			if not isOpen then screenGui.Enabled = false end
		end)
	end

	closeBtn.MouseButton1Click:Connect(closeShop)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == Enum.KeyCode.Escape and isOpen then closeShop() end
	end)

	_G.OpenShopGui = openShop
	print("[ShopGui] Shop initialized.")
