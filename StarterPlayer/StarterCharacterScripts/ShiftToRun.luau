-- || Made by @a2x4440 || --

local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

local camera = workspace.CurrentCamera

local RunConfig = require(game.ReplicatedStorage.RunConfig)

local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")

local runAnimation = Instance.new("Animation")
runAnimation.Name = "RunAnimation"
runAnimation.AnimationId = RunConfig.RunAnimationId

local sprintAnimation = Instance.new("Animation")
sprintAnimation.Name = "SprintAnimation"
sprintAnimation.AnimationId = RunConfig.SprintAnimationId
local runTrack = animator:LoadAnimation(runAnimation)
local sprintTrack = animator:LoadAnimation(sprintAnimation)
local sprintTask

runTrack.Priority = Enum.AnimationPriority.Action
sprintTrack.Priority = Enum.AnimationPriority.Action

local mobileGui = player:WaitForChild("PlayerGui").MobileGui


local function Run()
	if RunConfig.Walking and RunConfig.CanRun then
		RunConfig.Running = true

		local runTween = tweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.RunSpeed})
		local FovTween = tweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.RunFov})
		runTween:Play()
		FovTween:Play()
		runTrack:Play()
	end
end

local function Walk()
	RunConfig.Running = false
	RunConfig.Sprinting = false

	local walkTween = tweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.WalkSpeed})
	local fovTween = tweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.WalkFov})
	walkTween:Play()
	fovTween:Play()
	runTrack:Stop()
	sprintTrack:Stop()
	if sprintTask then
		task.cancel(sprintTask)
		sprintTask = nil
	end
end

local function Sprint()
	if RunConfig.Walking and RunConfig.Running and RunConfig.CanSprint then
		RunConfig.Sprinting = true

		local sprintTween = tweenService:Create(humanoid, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {WalkSpeed = RunConfig.SprintSpeed})
		local fovTween = tweenService:Create(camera, TweenInfo.new(RunConfig.TransitionSpeed, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {FieldOfView = RunConfig.SprintFov})
		sprintTween:Play()
		fovTween:Play()
		sprintTrack:Play()
	end
end


UIS.InputBegan:Connect(function(input)
	if input.KeyCode == RunConfig.RunKey then
		Run()

		sprintTask = task.spawn(function()
			wait(RunConfig.SprintTransitionSpeed)
			if RunConfig.Running then
				Sprint()
			end
		end)
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.KeyCode == RunConfig.RunKey then
		Walk()
	end
end)

mobileGui.RunButton.MouseButton1Down:Connect(function()
	Run()
end)

mobileGui.RunButton.MouseButton1Up:Connect(function()
	Walk()
end)


runService.RenderStepped:Connect(function()
	if humanoid.MoveDirection.Magnitude > 0 then
		RunConfig.Walking = true
	else
		RunConfig.Walking = false

		if RunConfig.Running then
			Walk()
		end
	end
end)

if UIS.TouchEnabled and not UIS.KeyboardEnabled and not UIS.MouseEnabled then
	mobileGui.Enabled = true
end