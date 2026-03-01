--[[
	LoadingScreen.lua
	Location: ReplicatedFirst (LocalScript)

	Custom loading screen for Soft Breeze.
	Shows the lighthouse logo, animated loading bar, and fades out
	once the game is fully loaded.
	
	Place this as a LocalScript inside ReplicatedFirst so it runs
	before anything else.
]]

local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local ContentProvider   = game:GetService("ContentProvider")
local ReplicatedFirst   = game:GetService("ReplicatedFirst")
local UserInputService  = game:GetService("UserInputService")

local player    = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -- CONFIG ----------------------------------------------
local LOGO_ASSET   = "rbxassetid://121377476760874"
local BG_COLOR     = Color3.fromRGB(255, 255, 255)
local BAR_BG_COLOR = Color3.fromRGB(210, 210, 220)
local BAR_COLOR    = Color3.fromRGB(138, 100, 214)   -- purple accent
local TEXT_COLOR   = Color3.fromRGB(80, 80, 100)
local MIN_DISPLAY  = 3          -- seconds minimum the screen stays up
local FADE_TIME    = 1.2        -- fade-out duration

local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local logoPx = math.clamp(math.floor(math.min(vp.X * (isTouch and 0.44 or 0.40), vp.Y * (isTouch and 0.44 or 0.40))), 185, 390)
local barWidth = math.clamp(math.floor(vp.X * (isTouch and 0.40 or 0.28)), 170, 320)
local logoY = isTouch and 0.40 or 0.44
local barY = isTouch and 0.60 or 0.56
local hintText = isTouch and "Tip: Tap the Features button to open the hub" or "Tip: Press Tab to open the features hub"

-- -- SCREEN GUI ------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "LoadingScreenGui"
screenGui.DisplayOrder     = 100          -- above everything
screenGui.IgnoreGuiInset   = true
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.ResetOnSpawn     = false
screenGui.Parent           = playerGui

-- Remove the default Roblox loading screen immediately
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- -- FULL-SCREEN BACKGROUND --
local bg = Instance.new("Frame")
bg.Name                  = "Background"
bg.Size                  = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3      = BG_COLOR
bg.BackgroundTransparency = 0
bg.BorderSizePixel       = 0
bg.ZIndex                = 1
bg.Parent                = screenGui

-- -- LOGO ------------------------------------------------
local logoHolder = Instance.new("Frame")
logoHolder.Name                  = "LogoHolder"
logoHolder.Size                  = UDim2.new(0, logoPx, 0, logoPx)
logoHolder.Position              = UDim2.new(0.5, 0, logoY, 0)
logoHolder.AnchorPoint           = Vector2.new(0.5, 0.5)
logoHolder.BackgroundTransparency = 1
logoHolder.ZIndex                = 2
logoHolder.Parent                = bg

local logo = Instance.new("ImageLabel")
logo.Name                  = "Logo"
logo.Size                  = UDim2.new(1, 0, 1, 0)
logo.BackgroundTransparency = 1
logo.Image                 = LOGO_ASSET
logo.ScaleType             = Enum.ScaleType.Fit
logo.ResampleMode          = Enum.ResamplerMode.Default
logo.ZIndex                = 2
logo.Parent                = logoHolder

-- -- LOADING BAR -----------------------------------------
local barOuter = Instance.new("Frame")
barOuter.Name                  = "BarOuter"
barOuter.Size                  = UDim2.new(0, barWidth, 0, 6)
barOuter.Position              = UDim2.new(0.5, 0, barY, 0)
barOuter.AnchorPoint           = Vector2.new(0.5, 0.5)
barOuter.BackgroundColor3      = BAR_BG_COLOR
barOuter.BackgroundTransparency = 0.3
barOuter.BorderSizePixel       = 0
barOuter.ZIndex                = 2
barOuter.Parent                = bg
Instance.new("UICorner", barOuter).CornerRadius = UDim.new(1, 0)

local barInner = Instance.new("Frame")
barInner.Name             = "BarInner"
barInner.Size             = UDim2.new(0, 0, 1, 0)
barInner.BackgroundColor3 = BAR_COLOR
barInner.BorderSizePixel  = 0
barInner.ZIndex           = 3
barInner.Parent           = barOuter
Instance.new("UICorner", barInner).CornerRadius = UDim.new(1, 0)

-- Glow on the bar
local barGlow = Instance.new("UIStroke")
barGlow.Color        = BAR_COLOR
barGlow.Transparency = 0.5
barGlow.Thickness    = 1.5
barGlow.Parent       = barInner

-- -- STATUS TEXT ------------------------------------------
local statusLabel = Instance.new("TextLabel")
statusLabel.Name                  = "Status"
statusLabel.Size                  = UDim2.new(0, barWidth, 0, 24)
statusLabel.Position              = UDim2.new(0.5, 0, barY, 18)
statusLabel.AnchorPoint           = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text                  = "Loading..."
statusLabel.TextColor3            = TEXT_COLOR
statusLabel.TextSize              = isTouch and 13 or 14
statusLabel.Font                  = Enum.Font.GothamMedium
statusLabel.TextTransparency      = 0.3
statusLabel.ZIndex                = 2
statusLabel.Parent                = bg

-- -- HINT TEXT (bottom) -----------------------------------
local hintLabel = Instance.new("TextLabel")
hintLabel.Name                  = "Hint"
hintLabel.Size                  = UDim2.new(1, -40, 0, 20)
hintLabel.Position              = UDim2.new(0.5, 0, 1, isTouch and -20 or -30)
hintLabel.AnchorPoint           = Vector2.new(0.5, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Text                  = hintText
hintLabel.TextColor3            = TEXT_COLOR
hintLabel.TextSize              = isTouch and 11 or 12
hintLabel.Font                  = Enum.Font.Gotham
hintLabel.TextTransparency      = 0.45
hintLabel.ZIndex                = 2
hintLabel.Parent                = bg

-- White overlay on top — fades in to cover everything as ONE entity (no per-element sync issues)
local fadeOverlay = Instance.new("Frame")
fadeOverlay.Name                  = "FadeOverlay"
fadeOverlay.Size                  = UDim2.new(1, 0, 1, 0)
fadeOverlay.Position               = UDim2.new(0, 0, 0, 0)
fadeOverlay.BackgroundColor3       = BG_COLOR
fadeOverlay.BackgroundTransparency = 1
fadeOverlay.BorderSizePixel        = 0
fadeOverlay.ZIndex                 = 999
fadeOverlay.Parent                 = screenGui

-- -- BREATHING ANIMATION ON LOGO -------------------------
local breatheUp = TweenService:Create(
	logoHolder,
	TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Position = UDim2.new(0.5, 0, logoY, -6) }
)
breatheUp:Play()

-- Dot animation on status text
local dotCount = 0
local dotConn
dotConn = task.spawn(function()
	while screenGui.Parent do
		dotCount = (dotCount % 3) + 1
		statusLabel.Text = "Loading" .. string.rep(".", dotCount)
		task.wait(0.45)
	end
end)

-- -- LOADING LOGIC ---------------------------------------
local startTime = tick()

-- Wait for the game to load
if not game:IsLoaded() then
	game.Loaded:Wait()
end

-- Pre-load critical assets (logo + any you add later)
local assetsToLoad = { LOGO_ASSET }
ContentProvider:PreloadAsync(assetsToLoad)

-- Animate bar to ~85% during load
TweenService:Create(
	barInner,
	TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Size = UDim2.new(0.85, 0, 1, 0) }
):Play()

-- Wait for player's character
local char = player.Character or player.CharacterAdded:Wait()

-- Ensure minimum display time so players actually see the logo
local elapsed = tick() - startTime
if elapsed < MIN_DISPLAY then
	task.wait(MIN_DISPLAY - elapsed)
end

-- Fill bar to 100%
TweenService:Create(
	barInner,
	TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Size = UDim2.new(1, 0, 1, 0) }
):Play()

statusLabel.Text = "Ready!"
task.wait(0.6)

-- -- FADE OUT (single overlay covers everything = one entity) ---
breatheUp:Cancel()
if dotConn then
	task.cancel(dotConn)
end

-- One white overlay fades in over the whole screen — logo, bar, text all covered together
local fadeStart = tick()
local fadeConn
fadeConn = RunService.RenderStepped:Connect(function()
	local elapsed = tick() - fadeStart
	local t = math.clamp(elapsed / FADE_TIME, 0, 1)
	local eased = t * t  -- Quad In
	fadeOverlay.BackgroundTransparency = 1 - eased
	if t >= 1 then
		fadeConn:Disconnect()
	end
end)

task.wait(FADE_TIME + 0.1)

-- Clean up
screenGui:Destroy()
print("[LoadingScreen] Loading complete — welcome to Soft Breeze!")
