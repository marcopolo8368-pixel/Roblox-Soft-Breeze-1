-- Script Made By Graham_1126
     --Graham_1126#6228--
         --Discord--


local settingsDir = script.Settings
local lighting = game.Lighting
local tweenService = game:GetService("TweenService")
local Clouds = game.Workspace.Terrain.Clouds
local clone = script.RainEffects:Clone()

game.Players.PlayerAdded:Connect(function()
	for _, v in pairs(game.Players:GetDescendants()) do if v.Name == "PlayerGui" then clone.Parent = v 			
		end
	end
end)

function getSetting (name)
	return settingsDir and settingsDir:FindFirstChild(name) and settingsDir[name].Value
end
function tween (l, p)
	tweenService:Create(Clouds, TweenInfo.new( l, Enum.EasingStyle.Quad, Enum.EasingDirection.In), p):Play()
end
function tween2 (l, p)
	tweenService:Create(lighting, TweenInfo.new(l, Enum.EasingStyle.Quad, Enum.EasingDirection.In), p):Play()
end



local random = math.random(getSetting("Min") * 60, getSetting("Max") * 60)

while wait() do
	
	
	
	local WeatherType = math.random(1,3)
	if WeatherType == 1 then                                                                --RAIN
	
		
	wait(random)
		
	tween(random, {Cover = 0.77, Density = 1, Color = Color3.new(0.141176, 0.172549, 0.207843)})
	tween2(random, {ExposureCompensation = -1.5})
	wait(random)
	for _, v in pairs(game.Players:GetDescendants()) do
		if v.Name == "RainEffects" then
			v.Rain2.Disabled = false
			v.RainScript.ENABLED.Value = true
			
		end
	end
	
	wait(random)

	for _, v in pairs(game.Players:GetDescendants()) do
		if v.Name == "RainEffects" then
			v.Rain2.Disabled = true
			v.RainScript.ENABLED.Value = false
			
		end
	end
	for _, v in pairs(workspace:GetDescendants()) do
		if v.Name == "__RainOccludedAttachment" then
			v:Destroy()
		end
	end
	for _, v in pairs(workspace:GetDescendants()) do
		if v.Name == "__RainSplashAttachment" then
			v:Destroy()
		end
	end

	tween(25, {Cover = 0, Density = 0 })
	tween2(random, {ExposureCompensation = 0})
	wait(10)
	end
	
	
	
	
	if WeatherType == 2 then                                                              --CLOUDY 

		wait(random)
		tween(random, {Cover = 0.6, Density = 1, Color = Color3.new(1, 1, 1)})
		tween2(random, {ExposureCompensation = -0.5})
		wait(random)
		

		wait(random)


		tween(25, {Cover = 0, Density = 0 })
		tween2(random, {ExposureCompensation = 0})
		wait(10)
	end
	
	
	if WeatherType == 3 then                                                                      --FOG


		wait(random)
		local OriginalDes = game.Lighting.Atmosphere.Density
		tween(random, {Cover = 0.85, Density = 1, Color = Color3.new(0.678431, 0.835294, 1)})
		tween2(random, {ExposureCompensation = -0.15})
		wait(random)
		
		local TweenService = game:GetService("TweenService")
		local Atmos = game.Lighting.Atmosphere


		local Info = TweenInfo.new(
			15, -- Length
			Enum.EasingStyle.Quad, -- Easing Style
			Enum.EasingDirection.Out, -- Easing Direction
			0, -- Times repeated
			false, -- Reverse
			0 -- Delay
		)
		local Goals =
			{
				Density = 0.747
			}
		local tween3 = TweenService:Create(Atmos,Info,Goals)
		tween3:Play()

		

		wait(random)


		local Atmos = game.Lighting.Atmosphere


		local Info = TweenInfo.new(
			15, -- Length
			Enum.EasingStyle.Quad, -- Easing Style
			Enum.EasingDirection.Out, -- Easing Direction
			0, -- Times repeated
			false, -- Reverse
			0 -- Delay
		)
		local Goals =
			{
				Density = OriginalDes
			}
		local tween3 = TweenService:Create(Atmos,Info,Goals)
		tween3:Play()
		

		tween(25, {Cover = 0, Density = 0 })
		tween2(random, {ExposureCompensation = 0})
		wait(10)
	end	

end

