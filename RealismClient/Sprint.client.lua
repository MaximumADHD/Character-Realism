script.Parent = game.StarterPlayer.StarterCharacterScripts

local uis = game:GetService("UserInputService")
local ts = game:GetService("TweenService")
local ti = TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0)
local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local cam = workspace.CurrentCamera

uis.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			ts:Create(cam, ti, {FieldOfView = 80}):Play()
			char.Humanoid.WalkSpeed = 25
		end
	end
end)

uis.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.LeftShift then
			ts:Create(cam, ti, {FieldOfView = 70}):Play()
			char.Humanoid.WalkSpeed = 16
		end
	end
end)