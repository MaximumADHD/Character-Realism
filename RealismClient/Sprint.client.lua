----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Hedreon, 2021
-- Realism Sprint
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local TweenData = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera

script.Parent = Character

UserInputService.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Keyboard then
		if Input.KeyCode == Enum.KeyCode.LeftShift then
			TweenService:Create(Camera, TweenData, {FieldOfView = 80}):Play()
			Character.Humanoid.WalkSpeed = 25
		end
	end
end)

UserInputService.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.Keyboard then
		if Input.KeyCode == Enum.KeyCode.LeftShift then
			TweenService:Create(Camera, TweenData, {FieldOfView = 70}):Play()
			Character.Humanoid.WalkSpeed = 16
		end
	end
end)