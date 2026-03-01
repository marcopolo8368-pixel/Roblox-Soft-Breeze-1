--[[
    MusicPlayerGui.lua
    Location: StarterGui (as a LocalScript inside a ScreenGui)
    
    Creates a sleek floating music player widget with play/pause,
    skip, volume control, and track info display.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- -------------------------------------------
-- PLAYLIST CONFIGURATION
-- -------------------------------------------
-- Licensed APM Music tracks � free for all Roblox developers
local PLAYLIST = {
	{ name = "Lo-Fi Chill A",          id = "rbxassetid://9043887091" },
	{ name = "Lo-Fi Chill B",          id = "rbxassetid://9043887320" },
	{ name = "Sunset Chill",           id = "rbxassetid://9046862738" },
	{ name = "Glowing Light",          id = "rbxassetid://9046865270" },
	{ name = "Chilling Vibes",         id = "rbxassetid://9043990074" },
	{ name = "Relaxation Flow",        id = "rbxassetid://9047963510" },
	{ name = "Lo-Fi Dreams",           id = "rbxassetid://9047050075" },
}

local DEFAULT_VOLUME = 0.3

-- -------------------------------------------
-- COLOR PALETTE
-- -------------------------------------------
local COLORS = {
	bg = Color3.fromRGB(18, 18, 28),
	bgLight = Color3.fromRGB(30, 30, 45),
	accent = Color3.fromRGB(138, 100, 214),
	accentGlow = Color3.fromRGB(170, 130, 255),
	text = Color3.fromRGB(220, 220, 240),
	textDim = Color3.fromRGB(120, 120, 150),
	slider = Color3.fromRGB(60, 60, 80),
}

-- -------------------------------------------
-- HELPER
-- -------------------------------------------
local function tween(instance, props, duration)
	TweenService:Create(instance, TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- ─── RESPONSIVE HELPERS ───
local IS_SMALL_SCREEN
do
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	IS_SMALL_SCREEN = vp.X < 700 or vp.Y < 500
end

-- -------------------------------------------
-- CREATE SCREEN GUI
-- -------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MusicPlayerGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 4
screenGui.Parent = playerGui

-- Main Container (bottom-right)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MusicPlayer"
mainFrame.Size = UDim2.new(0, 260, 0, 90)
mainFrame.Position = IS_SMALL_SCREEN and UDim2.new(1, -8, 0, 8) or UDim2.new(1, -20, 0, 20)
mainFrame.AnchorPoint = Vector2.new(1, 0)
mainFrame.BackgroundColor3 = COLORS.bg
mainFrame.BackgroundTransparency = 0.15
mainFrame.Parent = screenGui
if IS_SMALL_SCREEN then
	Instance.new("UIScale", mainFrame).Scale = 0.78
end

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(255, 255, 255)
mainStroke.Transparency = 0.85
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- -------------------------------------------
-- MUSIC ICON (proper music note image)
-- -------------------------------------------
local musicIcon = Instance.new("Frame")
musicIcon.Name = "MusicIcon"
musicIcon.Size = UDim2.new(0, 36, 0, 36)
musicIcon.Position = UDim2.new(0, 10, 0, 10)
musicIcon.BackgroundColor3 = COLORS.accent
musicIcon.BackgroundTransparency = 0.15
musicIcon.Parent = mainFrame

local iconCorner = Instance.new("UICorner")
iconCorner.CornerRadius = UDim.new(0, 10)
iconCorner.Parent = musicIcon

-- Subtle glow stroke on the icon
local iconStroke = Instance.new("UIStroke")
iconStroke.Color = COLORS.accentGlow
iconStroke.Transparency = 0.5
iconStroke.Thickness = 1.5
iconStroke.Parent = musicIcon

-- Actual music note ImageLabel
local noteImage = Instance.new("ImageLabel")
noteImage.Name = "NoteIcon"
noteImage.Size = UDim2.new(0, 22, 0, 22)
noteImage.Position = UDim2.new(0.5, 0, 0.5, 0)
noteImage.AnchorPoint = Vector2.new(0.5, 0.5)
noteImage.BackgroundTransparency = 1
noteImage.Image = "rbxassetid://6026568198" -- Music note icon
noteImage.ImageColor3 = Color3.new(1, 1, 1)
noteImage.ScaleType = Enum.ScaleType.Fit
noteImage.Parent = musicIcon

-- -------------------------------------------
-- TRACK NAME
-- -------------------------------------------
local trackLabel = Instance.new("TextLabel")
trackLabel.Name = "TrackName"
trackLabel.Size = UDim2.new(0, 155, 0, 18)
trackLabel.Position = UDim2.new(0, 52, 0, 12)
trackLabel.BackgroundTransparency = 1
trackLabel.Text = "Loading..."
trackLabel.TextColor3 = COLORS.text
trackLabel.TextSize = 13
trackLabel.Font = Enum.Font.GothamBold
trackLabel.TextXAlignment = Enum.TextXAlignment.Left
trackLabel.TextTruncate = Enum.TextTruncate.AtEnd
trackLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(0, 155, 0, 14)
statusLabel.Position = UDim2.new(0, 52, 0, 30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Now Playing"
statusLabel.TextColor3 = COLORS.textDim
statusLabel.TextSize = 10
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

-- -------------------------------------------
-- CONTROLS ROW
-- -------------------------------------------
local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "Controls"
controlsFrame.Size = UDim2.new(1, -24, 0, 30)
controlsFrame.Position = UDim2.new(0, 12, 1, -38)
controlsFrame.BackgroundTransparency = 1
controlsFrame.Parent = mainFrame

-- Previous button
local prevBtn = Instance.new("TextButton")
prevBtn.Name = "Prev"
prevBtn.Size = UDim2.new(0, 28, 0, 28)
prevBtn.Position = UDim2.new(0, 0, 0.5, 0)
prevBtn.AnchorPoint = Vector2.new(0, 0.5)
prevBtn.BackgroundColor3 = COLORS.bgLight
prevBtn.Text = ""
prevBtn.Parent = controlsFrame

local prevCorner = Instance.new("UICorner")
prevCorner.CornerRadius = UDim.new(0, 7)
prevCorner.Parent = prevBtn

-- Skip back icon (image)
local prevIcon = Instance.new("ImageLabel")
prevIcon.Name = "Icon"
prevIcon.Size = UDim2.new(0, 16, 0, 16)
prevIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
prevIcon.AnchorPoint = Vector2.new(0.5, 0.5)
prevIcon.BackgroundTransparency = 1
prevIcon.Image = "rbxassetid://6034818372" -- Rewind/skip back
prevIcon.ImageColor3 = COLORS.text
prevIcon.ScaleType = Enum.ScaleType.Fit
prevIcon.Parent = prevBtn

-- Play/Pause button
local playBtn = Instance.new("TextButton")
playBtn.Name = "PlayPause"
playBtn.Size = UDim2.new(0, 34, 0, 28)
playBtn.Position = UDim2.new(0, 34, 0.5, 0)
playBtn.AnchorPoint = Vector2.new(0, 0.5)
playBtn.BackgroundColor3 = COLORS.accent
playBtn.Text = ""
playBtn.Parent = controlsFrame

local playCorner = Instance.new("UICorner")
playCorner.CornerRadius = UDim.new(0, 7)
playCorner.Parent = playBtn

-- Pause icon (two vertical bars) - shown by default
local pauseBar1 = Instance.new("Frame")
pauseBar1.Name = "PauseBar1"
pauseBar1.Size = UDim2.new(0, 3, 0, 12)
pauseBar1.Position = UDim2.new(0.5, -4, 0.5, 0)
pauseBar1.AnchorPoint = Vector2.new(0.5, 0.5)
pauseBar1.BackgroundColor3 = Color3.new(1, 1, 1)
pauseBar1.BorderSizePixel = 0
pauseBar1.Parent = playBtn
Instance.new("UICorner", pauseBar1).CornerRadius = UDim.new(0, 1)

local pauseBar2 = Instance.new("Frame")
pauseBar2.Name = "PauseBar2"
pauseBar2.Size = UDim2.new(0, 3, 0, 12)
pauseBar2.Position = UDim2.new(0.5, 4, 0.5, 0)
pauseBar2.AnchorPoint = Vector2.new(0.5, 0.5)
pauseBar2.BackgroundColor3 = Color3.new(1, 1, 1)
pauseBar2.BorderSizePixel = 0
pauseBar2.Parent = playBtn
Instance.new("UICorner", pauseBar2).CornerRadius = UDim.new(0, 1)

-- Play icon (triangle) - hidden by default
local playTriangle = Instance.new("ImageLabel")
playTriangle.Name = "PlayTriangle"
playTriangle.Size = UDim2.new(0, 12, 0, 14)
playTriangle.Position = UDim2.new(0.5, 1, 0.5, 0)
playTriangle.AnchorPoint = Vector2.new(0.5, 0.5)
playTriangle.BackgroundTransparency = 1
playTriangle.Image = "rbxasset://textures/triangle.png"
playTriangle.ImageColor3 = Color3.new(1, 1, 1)
playTriangle.Rotation = 90
playTriangle.Visible = false
playTriangle.Parent = playBtn

-- Next button
local nextBtn = Instance.new("TextButton")
nextBtn.Name = "Next"
nextBtn.Size = UDim2.new(0, 28, 0, 28)
nextBtn.Position = UDim2.new(0, 74, 0.5, 0)
nextBtn.AnchorPoint = Vector2.new(0, 0.5)
nextBtn.BackgroundColor3 = COLORS.bgLight
nextBtn.Text = ""
nextBtn.Parent = controlsFrame

local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(0, 7)
nextCorner.Parent = nextBtn

-- Skip forward icon (image)
local nextIcon = Instance.new("ImageLabel")
nextIcon.Name = "Icon"
nextIcon.Size = UDim2.new(0, 16, 0, 16)
nextIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
nextIcon.AnchorPoint = Vector2.new(0.5, 0.5)
nextIcon.BackgroundTransparency = 1
nextIcon.Image = "rbxassetid://6034818379" -- Fast forward/skip
nextIcon.ImageColor3 = COLORS.text
nextIcon.ScaleType = Enum.ScaleType.Fit
nextIcon.Parent = nextBtn

-- -------------------------------------------
-- VOLUME SLIDER
-- -------------------------------------------

-- Speaker icon with sound waves (using proper image)
local volIcon = Instance.new("ImageLabel")
volIcon.Name = "VolIcon"
volIcon.Size = UDim2.new(0, 18, 0, 18)
volIcon.Position = UDim2.new(0, 113, 0.5, 0)
volIcon.AnchorPoint = Vector2.new(0, 0.5)
volIcon.BackgroundTransparency = 1
volIcon.Image = "rbxassetid://6031090994" -- Volume / speaker icon
volIcon.ImageColor3 = COLORS.textDim
volIcon.ScaleType = Enum.ScaleType.Fit
volIcon.Parent = controlsFrame

local sliderBg = Instance.new("Frame")
sliderBg.Name = "SliderBg"
sliderBg.Size = UDim2.new(0, 90, 0, 6)
sliderBg.Position = UDim2.new(0, 134, 0.5, 0)
sliderBg.AnchorPoint = Vector2.new(0, 0.5)
sliderBg.BackgroundColor3 = COLORS.slider
sliderBg.Parent = controlsFrame

local sliderCorner = Instance.new("UICorner")
sliderCorner.CornerRadius = UDim.new(1, 0)
sliderCorner.Parent = sliderBg

local sliderFill = Instance.new("Frame")
sliderFill.Name = "Fill"
sliderFill.Size = UDim2.new(DEFAULT_VOLUME, 0, 1, 0)
sliderFill.BackgroundColor3 = COLORS.accent
sliderFill.Parent = sliderBg

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = sliderFill

-- Slider knob
local sliderKnob = Instance.new("Frame")
sliderKnob.Name = "Knob"
sliderKnob.Size = UDim2.new(0, 12, 0, 12)
sliderKnob.Position = UDim2.new(DEFAULT_VOLUME, 0, 0.5, 0)
sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sliderKnob.BackgroundColor3 = COLORS.accentGlow
sliderKnob.ZIndex = 2
sliderKnob.Parent = sliderBg

local knobCorner = Instance.new("UICorner")
knobCorner.CornerRadius = UDim.new(1, 0)
knobCorner.Parent = sliderKnob

-- Slider click area (invisible, larger hit area)
local sliderClickArea = Instance.new("TextButton")
sliderClickArea.Name = "ClickArea"
sliderClickArea.Size = UDim2.new(1, 0, 1, 16)
sliderClickArea.Position = UDim2.new(0, 0, 0.5, 0)
sliderClickArea.AnchorPoint = Vector2.new(0, 0.5)
sliderClickArea.BackgroundTransparency = 1
sliderClickArea.Text = ""
sliderClickArea.ZIndex = 3
sliderClickArea.Parent = sliderBg

-- -------------------------------------------
-- COLLAPSE/EXPAND TOGGLE
-- -------------------------------------------
local collapseBtn = Instance.new("TextButton")
collapseBtn.Name = "Collapse"
collapseBtn.Size = UDim2.new(0, 22, 0, 22)
collapseBtn.Position = UDim2.new(1, -8, 0, 8)
collapseBtn.AnchorPoint = Vector2.new(1, 0)
collapseBtn.BackgroundTransparency = 1
collapseBtn.Text = ""
collapseBtn.Parent = mainFrame

-- Drawn minus icon (collapse indicator)
local collapseMinus = Instance.new("Frame")
collapseMinus.Name = "MinusIcon"
collapseMinus.Size = UDim2.new(0, 12, 0, 2)
collapseMinus.Position = UDim2.new(0.5, 0, 0.5, 0)
collapseMinus.AnchorPoint = Vector2.new(0.5, 0.5)
collapseMinus.BackgroundColor3 = COLORS.textDim
collapseMinus.BorderSizePixel = 0
collapseMinus.Parent = collapseBtn

-- -------------------------------------------
-- AUDIO ENGINE
-- -------------------------------------------
local currentIndex = 1
local isPlaying = true
local currentVolume = DEFAULT_VOLUME
local isCollapsed = false

-- Create sound object
local sound = Instance.new("Sound")
sound.Name = "BackgroundMusic"
sound.Volume = currentVolume
sound.Looped = false
sound.Parent = SoundService

local function showPauseIcon()
	pauseBar1.Visible = true
	pauseBar2.Visible = true
	playTriangle.Visible = false
end

local function showPlayIcon()
	pauseBar1.Visible = false
	pauseBar2.Visible = false
	playTriangle.Visible = true
end

local function loadTrack(index)
	currentIndex = ((index - 1) % #PLAYLIST) + 1
	local track = PLAYLIST[currentIndex]
	sound:Stop()
	sound.SoundId = track.id
	trackLabel.Text = track.name
	if isPlaying then
		sound:Play()
		statusLabel.Text = "Now Playing"
		showPauseIcon()
	else
		statusLabel.Text = "Paused"
	end
end

local function togglePlayPause()
	if isPlaying then
		sound:Pause()
		isPlaying = false
		showPlayIcon()
		statusLabel.Text = "Paused"
	else
		sound:Resume()
		isPlaying = true
		showPauseIcon()
		statusLabel.Text = "Now Playing"
	end
end

local function nextTrack()
	loadTrack(currentIndex + 1)
end

local function prevTrack()
	loadTrack(currentIndex - 1)
end

local function setVolume(vol)
	currentVolume = math.clamp(vol, 0, 1)
	sound.Volume = currentVolume
	tween(sliderFill, { Size = UDim2.new(currentVolume, 0, 1, 0) }, 0.1)
	tween(sliderKnob, { Position = UDim2.new(currentVolume, 0, 0.5, 0) }, 0.1)

	if currentVolume == 0 then
		volIcon.ImageTransparency = 0.55
	elseif currentVolume < 0.5 then
		volIcon.ImageTransparency = 0.28
	else
		volIcon.ImageTransparency = 0.08
	end
end

-- Auto-advance to next track when current ends
sound.Ended:Connect(function()
	nextTrack()
end)

-- -------------------------------------------
-- BUTTON EVENTS
-- -------------------------------------------
playBtn.MouseButton1Click:Connect(togglePlayPause)
nextBtn.MouseButton1Click:Connect(nextTrack)
prevBtn.MouseButton1Click:Connect(prevTrack)

-- Volume slider drag
local isDraggingVolume = false

sliderClickArea.MouseButton1Down:Connect(function()
	isDraggingVolume = true
end)

game:GetService("UserInputService").InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		isDraggingVolume = false
	end
end)

game:GetService("RunService").RenderStepped:Connect(function()
	if isDraggingVolume then
		local mouse = player:GetMouse()
		local absPos = sliderBg.AbsolutePosition.X
		local absSize = sliderBg.AbsoluteSize.X
		local relX = (mouse.X - absPos) / absSize
		setVolume(relX)
	end
end)

-- Also handle single click on slider
sliderClickArea.MouseButton1Click:Connect(function()
	local mouse = player:GetMouse()
	local absPos = sliderBg.AbsolutePosition.X
	local absSize = sliderBg.AbsoluteSize.X
	local relX = (mouse.X - absPos) / absSize
	setVolume(relX)
end)

-- Collapse / Expand
collapseBtn.MouseButton1Click:Connect(function()
	isCollapsed = not isCollapsed
	if isCollapsed then
		tween(mainFrame, { Size = UDim2.new(0, 50, 0, 50) }, 0.2)
		-- Show a small note icon when collapsed
		controlsFrame.Visible = false
		trackLabel.Visible = false
		statusLabel.Visible = false
		musicIcon.Visible = false
		collapseBtn.Text = ""
		collapseBtn.Size = UDim2.new(0, 40, 0, 40)
		collapseBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
		collapseBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	else
		tween(mainFrame, { Size = UDim2.new(0, 260, 0, 90) }, 0.2)
		collapseBtn.Text = ""
		collapseBtn.Size = UDim2.new(0, 22, 0, 22)
		collapseBtn.Position = UDim2.new(1, -8, 0, 8)
		collapseBtn.AnchorPoint = Vector2.new(1, 0)
		task.delay(0.15, function()
			controlsFrame.Visible = true
			trackLabel.Visible = true
			statusLabel.Visible = true
			musicIcon.Visible = true
		end)
	end
end)

-- Hover effects on buttons
for _, btn in ipairs({playBtn, nextBtn, prevBtn}) do
	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundTransparency = 0.2 }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundTransparency = 0 }, 0.1)
	end)
end

-- -------------------------------------------
-- INITIALIZE
-- -------------------------------------------
loadTrack(1)
print("[MusicPlayerGui] Music player initialized.")
