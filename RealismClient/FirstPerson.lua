------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MaximumADHD, 2020
-- First Person Camera
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings().GameSettings

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Logic
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FirstPerson = {
	Started = false,
}

local HEAD_ATTACHMENTS = {
	FaceCenterAttachment = true,
	FaceFrontAttachment = true,
	HairAttachment = true,
	HatAttachment = true,
}

local INVALID_ROTATION_STATES = {
	Swimming = true,
	Climbing = true,
	Dead = true,
}

type IBaseCamera = typeof(FirstPerson) | {
	[string]: any,
	IsInFirstPerson: () -> boolean,
	GetSubjectPosition: (<T>(self: T) -> (Vector3, Vector3?))?,
	GetBaseSubjectPosition: (<T>(self: T) -> (Vector3, Vector3?))?,
}

type ITransparencyController = {
	[string]: any,
	ForceRefresh: boolean?,
	AttachmentListener: RBXScriptConnection?,

	Update: (...any) -> (),
	BaseUpdate: (...any) -> (),
	SetSubject: (self: any, subject: Instance?) -> (),

	SetupTransparency: (self: any, character: Model, ...any) -> (),
	BaseSetupTransparency: (self: any, character: Model, ...any) -> (),
}

function FirstPerson.IsInFirstPerson(_self: any)
	local camera = workspace.CurrentCamera

	if camera then
		if camera.CameraType.Name == "Scriptable" then
			return false
		end

		local focus = camera.Focus.Position
		local origin = camera.CFrame.Position

		return (focus - origin).Magnitude <= 1
	end

	return false
end

function FirstPerson.GetSubjectPosition(self: IBaseCamera)
	if FirstPerson.IsInFirstPerson() then
		local camera = workspace.CurrentCamera :: Camera
		local subject = camera.CameraSubject

		if subject and subject:IsA("Humanoid") and subject.Health > 0 then
			local character = subject.Parent
			local head = character and character:FindFirstChild("Head")

			if head and head:IsA("BasePart") then
				local cf = head.CFrame
				local offset = cf * CFrame.new(0, head.Size.Y / 3, 0)

				return offset.Position, cf.LookVector
			end
		end
	end

	local getBase: any = assert(self.GetBaseSubjectPosition)
	return getBase(self)
end

function FirstPerson.GetBaseSubjectPosition()
	-- STUB! Overwritten at run-time
	return Vector3.zero
end

function FirstPerson.IsValidPartToModify(_self: any, part: Instance?)
	if part then
		if part:FindFirstAncestorOfClass("Tool") then
			return false
		elseif part:IsA("Decal") then
			part = part.Parent
		end
	end

	if part and part:IsA("BasePart") then
		local accessory = part:FindFirstAncestorWhichIsA("Accoutrement")

		if accessory then
			if part.Name ~= "Handle" then
				local handle = accessory:FindFirstChild("Handle", true)

				if handle and handle:IsA("BasePart") then
					part = handle
				end
			end

			for _, child in pairs(part and part:GetChildren() or {}) do
				if child:IsA("Attachment") then
					if HEAD_ATTACHMENTS[child.Name] then
						return true
					end
				end
			end
		elseif part.Name == "Head" then
			local model = part.Parent
			local camera = assert(workspace.CurrentCamera)
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")

			if humanoid and camera.CameraSubject == humanoid then
				return true
			end
		end
	end

	return false
end

-- Tries to overload BaseCamera:GetSubjectPosition() with
-- the GetSubjectPosition function of FirstPerson.

local function mountBaseCamera(unsafe_BaseCamera: any)
	-- stylua: ignore
	local base = if type(unsafe_BaseCamera) == "table"
		then rawget(unsafe_BaseCamera, "GetSubjectPosition")
		else nil

	if type(base) == "function" then
		FirstPerson.GetBaseSubjectPosition = base
		unsafe_BaseCamera.GetBaseSubjectPosition = base
		unsafe_BaseCamera.GetSubjectPosition = FirstPerson.GetSubjectPosition
	else
		warn("Could not find BaseCamera:GetSubjectPosition()!")
	end
end

-- This is the overloaded function
-- for TransparencyController:Update(...)

local function updateTransparency(self: ITransparencyController, ...)
	self:BaseUpdate(...)

	if self.ForceRefresh then
		self.ForceRefresh = false

		if type(self.SetSubject) == "function" then
			local camera = workspace.CurrentCamera :: Camera
			self:SetSubject(camera.CameraSubject)
		end
	end
end

-- This is an overloaded function for
-- TransparencyController:SetupTransparency(character, ...)

local function setupTransparency(self: ITransparencyController, character: Model, ...)
	self:BaseSetupTransparency(character, ...)

	if self.AttachmentListener then
		self.AttachmentListener:Disconnect()
	end

	self.AttachmentListener = character.DescendantAdded:Connect(function(obj)
		if obj:IsA("Attachment") and HEAD_ATTACHMENTS[obj.Name] then
			if type(self.cachedParts) == "table" then
				self.cachedParts[obj.Parent] = true
			end

			if self.transparencyDirty ~= nil then
				self.transparencyDirty = true
			end
		end
	end)
end

-- Overloads functions in Roblox's TransparencyController
-- module with replacement functions in the FirstPerson.

local function mountTransparency(Transparency: ITransparencyController)
	local baseUpdate = Transparency.Update

	if type(baseUpdate) == "function" then
		Transparency.BaseUpdate = baseUpdate
		Transparency.Update = updateTransparency
	else
		warn("MountTransparency - Could not find Transparency:Update()!")
	end

	if type(Transparency.IsValidPartToModify) == "function" then
		Transparency.IsValidPartToModify = FirstPerson.IsValidPartToModify
		Transparency.ForceRefresh = true
	else
		warn("MountTransparency - Could not find Transparency:IsValidPartToModify(part)!")
	end

	if type(Transparency.SetupTransparency) == "function" then
		Transparency.BaseSetupTransparency = Transparency.SetupTransparency
		Transparency.SetupTransparency = setupTransparency
	else
		warn("MountTransparency - Could not find Transparency:SetupTransparency(character)!")
	end
end

-- Called when the user's rotation type is changed.
-- This is a strong indication the user is in first person
-- and needs to have its first person movement smoothened out.

local function onRotationTypeChanged()
	local camera = workspace.CurrentCamera :: Camera
	local subject = camera and camera.CameraSubject

	if subject and subject:IsA("Humanoid") then
		local rotationType = UserGameSettings.RotationType

		if rotationType ~= Enum.RotationType.CameraRelative then
			subject.AutoRotate = true
			return
		end

		subject.AutoRotate = false

		RunService:BindToRenderStep("FirstPersonCamera", 1000, function(dt: number)
			local cancel = subject.AutoRotate
				or not subject:IsDescendantOf(game)
				or (subject.SeatPart and subject.SeatPart:IsA("VehicleSeat"))

			if cancel then
				RunService:UnbindFromRenderStep("FirstPersonCamera")
				return
			end

			-- Keep on standby, but ignore if we're in scriptable mode.
			if camera.CameraType.Name == "Scriptable" then
				return
			end

			local rootPart = subject.RootPart
			local isGrounded = rootPart and rootPart:IsGrounded()

			if rootPart and not isGrounded then
				local state = subject:GetState()
				local canRotate = true

				if INVALID_ROTATION_STATES[state.Name] then
					canRotate = false
				end

				if subject.Sit and subject.SeatPart then
					local root = rootPart.AssemblyRootPart --:GetRootPart()

					if root ~= rootPart then
						canRotate = false
					end
				end

				if canRotate then
					local pos = rootPart.Position
					local step = math.min(0.2, (dt * 40) / 3)

					local look = camera.CFrame.LookVector
					look = (look * XZ_VECTOR3).Unit

					local cf = CFrame.new(pos, pos + look)
					rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
				end
			end

			if FirstPerson.IsInFirstPerson() then
				local cf = camera.CFrame
				local headPos = FirstPerson:GetSubjectPosition()

				if headPos then
					local offset = (headPos - cf.Position)
					cf += offset

					camera.CFrame = cf
					camera.Focus += offset
				end
			end
		end)
	end
end

-- Called once to start the FirstPerson logic.
-- Binds and overloads everything necessary.

function FirstPerson.Start()
	if FirstPerson.Started then
		return
	end

	local player = assert(Players.LocalPlayer)
	FirstPerson.Started = true

	task.spawn(function()
		local requireUnsafe = require :: any
		local playerScripts = player:WaitForChild("PlayerScripts")
		local playerModule = playerScripts:WaitForChild("PlayerModule")

		local baseCamera = playerModule:FindFirstChild("BaseCamera", true)
		local transparency = playerModule:FindFirstChild("TransparencyController", true)

		if baseCamera and baseCamera:IsA("ModuleScript") then
			local module = requireUnsafe(baseCamera)
			task.spawn(mountBaseCamera, module)
		else
			warn("Start - Could not find BaseCamera module!")
		end

		if transparency and transparency:IsA("ModuleScript") then
			local module = requireUnsafe(transparency)
			task.spawn(mountTransparency, module)
		else
			warn("Start - Cound not find TransparencyController module!")
		end
	end)

	local rotListener = UserGameSettings:GetPropertyChangedSignal("RotationType")
	rotListener:Connect(onRotationTypeChanged)
end

return FirstPerson
