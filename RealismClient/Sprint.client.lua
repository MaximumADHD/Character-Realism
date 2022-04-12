------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Hedreon, 2022
-- Realism Sprint
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local Players          = game:GetService("Players")

local TweenInformation = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
local CurrentCamera    = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer
local Character        = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

script.Parent = Character

UserInputService.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Keyboard then
		if Input.KeyCode == Enum.KeyCode.LeftShift then
			TweenService:Create(CurrentCamera, TweenInformation, {FieldOfView = 80}):Play()
			Character.Humanoid.WalkSpeed = 25
		end
	end
end)

UserInputService.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Keyboard then
		if Input.KeyCode == Enum.KeyCode.LeftShift then
			TweenService:Create(CurrentCamera, TweenInformation, {FieldOfView = 70}):Play()
			Character.Humanoid.WalkSpeed = 16
		end
	end
end)
