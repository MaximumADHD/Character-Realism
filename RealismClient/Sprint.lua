------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Hedreon, 2022 
-- Sprint
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ContextActionService = game:GetService("ContextActionService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local CurrentCamera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Character	= LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local ACTION_SPRINT = "Sprint"

local Gamepads = {
	Enum.UserInputType.Gamepad1,
	Enum.UserInputType.Gamepad2,
	Enum.UserInputType.Gamepad3,
	Enum.UserInputType.Gamepad4,
	Enum.UserInputType.Gamepad5,
	Enum.UserInputType.Gamepad6,
	Enum.UserInputType.Gamepad7,
	Enum.UserInputType.Gamepad8
}

local Sprinting = false
local Started = false

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Logic
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Sprint = {
	DefaultFOV = 70; -- Normal FOV (Not sprinting)
	DefaultSpeed = StarterPlayer.CharacterWalkSpeed; -- Normal WalkSpeed (Not sprinting)

	SprintingSpeed = 24; -- WalkSpeed when sprinting
	SprintingFOV = 80; -- FOV when sprinting

	TweenSpeed = 0.25; -- Tweening speed (In seconds)
	TweenStyle = Enum.EasingStyle.Sine; -- Tweening Style
	TweenDirection = Enum.EasingDirection.InOut; -- Tweening Direction

	Keycodes = { -- The keys and buttons that can be used to start sprinting
		--// PC
		Enum.KeyCode.LeftShift,

		--// Xbox
		Enum.KeyCode.ButtonY
	};

	MobilePosition = UDim2.new(0.4, 0, 0.2, 0); -- Button position for mobile
	MobileSprintTitle = "Run"; -- Normal button title (Not sprinting)
	MobileWalkTitle = "Walk"; -- Button title when sprinting
}

local TweenInformation = TweenInfo.new(Sprint.TweenSpeed, Sprint.TweenStyle, Sprint.TweenDirection, 0, false, 0)

local function StartSprinting()
	if Character then
		if Humanoid then
			Sprinting = not Sprinting
			
			if Sprinting then
				Humanoid.WalkSpeed = Sprint.SprintingSpeed
				TweenService:Create(CurrentCamera, TweenInformation, {FieldOfView = Sprint.SprintingFOV}):Play()
				ContextActionService:SetTitle(ACTION_SPRINT, Sprint.MobileWalkTitle)
			else
				Humanoid.WalkSpeed = Sprint.DefaultSpeed
				TweenService:Create(CurrentCamera, TweenInformation, {FieldOfView = Sprint.DefaultFOV}):Play()
				ContextActionService:SetTitle(ACTION_SPRINT, Sprint.MobileSprintTitle)
			end
		end
	end
end

function Sprint:Start()
	if Started then
		return
	else
		Started = true
	end

	ContextActionService:BindAction(ACTION_SPRINT, function(Action, State, Input)
		if Input.UserInputType == Enum.UserInputType.Keyboard then
			StartSprinting()
		elseif Input.UserInputType == Enum.UserInputType.Touch and State == Enum.UserInputState.Begin then
			StartSprinting()
		elseif Input.UserInputType == Gamepads and State == Enum.UserInputState.Begin then
			StartSprinting()
		end
	end, true, unpack(Sprint.Keycodes))
	
	ContextActionService:SetPosition(ACTION_SPRINT, Sprint.MobilePosition)
	ContextActionService:SetTitle(ACTION_SPRINT, Sprint.MobileSprintTitle)

	-- Small snippet of code to unbind the action when chatting
	LocalPlayer.Chatted:Connect(function(Chatting)
		if Chatting then
			ContextActionService:UnbindAction(ACTION_SPRINT)
		else
			ContextActionService:BindAction(ACTION_SPRINT)
		end
	end)
end

return Sprint

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
