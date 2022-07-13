------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CloneTrooper1019, 2020 
-- FPS Camera
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Logic
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FpsCamera = 
{
	HeadMirrors = {};
	
	HeadAttachments = 
	{
		FaceCenterAttachment = true;
		FaceFrontAttachment = true;
		HairAttachment = true;
		HatAttachment = true;
	};

	InvalidRotationStates =
	{
		Swimming = true; 
		Climbing = true;
		Dead = true;
	};
}

-- Writes a warning to the output
-- in context of the FpsCamera.

function FpsCamera:Warn(...)
	warn("[FpsCamera]", ...)
end

-- Connects a self-function by  
-- name to the provided event.

function FpsCamera:Connect(funcName, event)
	return event:Connect(function (...)
		self[funcName](self, ...)
	end)
end

-- Returns true if the client is
-- currently in first person.

function FpsCamera:IsInFirstPerson()
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

-- Returns the subject position the FpsCamera
-- wants Roblox's camera to be using right now.

function FpsCamera:GetSubjectPosition()
	if self:IsInFirstPerson() then
		local camera = workspace.CurrentCamera
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
	
	return self:GetBaseSubjectPosition()
end

-- This is an overload function for TransparencyController:IsValidPartToModify(part)
-- You may call it directly if you'd like, as it does not have any external dependencies.

function FpsCamera:IsValidPartToModify(part)
	if part:FindFirstAncestorOfClass("Tool") then
		return false
	end
	
	if part:IsA("Decal") then
		part = part.Parent
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
			
			for _,child in pairs(part:GetChildren()) do
				if child:IsA("Attachment") then
					if self.HeadAttachments[child.Name] then
						return true
					end
				end
			end
		elseif part.Name == "Head" then
			local model = part.Parent
			local camera = workspace.CurrentCamera
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")

			if humanoid and camera.CameraSubject == humanoid then
				return true
			end
		end
	end
	
	return false
end

-- Overloads BaseCamera:GetSubjectPosition() with
-- the GetSubjectPosition function of the FpsCamera.

function FpsCamera:MountBaseCamera(BaseCamera)
	local base = BaseCamera.GetSubjectPosition
	self.GetBaseSubjectPosition = base
	
	if base then
		BaseCamera.GetBaseSubjectPosition = base
		BaseCamera.GetSubjectPosition = self.GetSubjectPosition
	else
		self:Warn("MountBaseCamera - Could not find BaseCamera:GetSubjectPosition()!")
	end
end

-- This is an overload function for TransparencyController:Update()
-- Do not call directly, or it will throw an assertion!

function FpsCamera:UpdateTransparency(...)
	assert(self ~= FpsCamera)
	self:BaseUpdate(...)
	
	if self.ForceRefresh then
		self.ForceRefresh = false
		
		if self.SetSubject then
			local camera = workspace.CurrentCamera
			self:SetSubject(camera.CameraSubject)
		end
	end
end

-- This is an overloaded function for TransparencyController:SetupTransparency(character)
-- Do not call directly, or it will throw an assertion!

function FpsCamera:SetupTransparency(character, ...)
	assert(self ~= FpsCamera)
	self:BaseSetupTransparency(character, ...)
	
	if self.AttachmentListener then
		self.AttachmentListener:Disconnect()
	end
	
	self.AttachmentListener = character.DescendantAdded:Connect(function (obj)
		if obj:IsA("Attachment") and self.HeadAttachments[obj.Name] then
			if typeof(self.cachedParts) == "table" then
				self.cachedParts[obj.Parent] = true
			end

			if self.transparencyDirty ~= nil then
				self.transparencyDirty = true
			end
		end
	end)
end


-- Overloads functions in Roblox's TransparencyController 
-- module with replacement functions in the FpsCamera.

function FpsCamera:MountTransparency(Transparency)
	local baseUpdate = Transparency.Update
	
	if baseUpdate then
		Transparency.BaseUpdate = baseUpdate
		Transparency.Update = self.UpdateTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:Update()!")
	end
	
	if Transparency.IsValidPartToModify then
		Transparency.IsValidPartToModify = self.IsValidPartToModify
		Transparency.HeadAttachments = self.HeadAttachments
		Transparency.ForceRefresh = true
	else
		self:Warn("MountTransparency - Could not find Transparency:IsValidPartToModify(part)!")
	end
	
	if Transparency.SetupTransparency then
		Transparency.BaseSetupTransparency = Transparency.SetupTransparency
		Transparency.SetupTransparency = self.SetupTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:SetupTransparency(character)!")
	end
end

-- Returns the current angle being used
-- by Roblox's shadow mapping system.

function FpsCamera:GetShadowAngle()
	local angle = Lighting:GetSunDirection()
	
	if angle.Y < -0.3 then
		-- Use the moon's angle instead.
		angle = Lighting:GetMoonDirection()
	end
	
	return angle
end

-- Forces a copy object to mirror the value of
-- a property on the provided base object.

function FpsCamera:MirrorProperty(base, copy, prop)
	base:GetPropertyChangedSignal(prop):Connect(function ()
		copy[prop] = base[prop]
	end)
end

-- Creates a lazy object-mirror for the provided part.
-- This is used to make the Head visible in first person.

function FpsCamera:AddHeadMirror(desc)
	if desc:IsA("BasePart") and self:IsValidPartToModify(desc) then
		local mirror = desc:Clone()
		mirror:ClearAllChildren()
		
		mirror.Locked = true
		mirror.Anchored = true
		mirror.CanCollide = false
		mirror.Parent = self.MirrorBin
		
		local function onChildAdded(child)
			local prop
			
			if child:IsA("DataModelMesh") then
				prop = "Scale"
			elseif child:IsA("Decal") then
				prop = "Transparency"
			end
			
			if prop then
				local copy = child:Clone()
				copy.Parent = mirror
				
				self:MirrorProperty(child, copy, prop)
			end
		end
		
		for _,child in pairs(desc:GetChildren()) do
			onChildAdded(child)
		end
		
		self.HeadMirrors[desc] = mirror
		self:MirrorProperty(desc, mirror, "Transparency")
		
		desc.ChildAdded:Connect(onChildAdded)
	end
end

-- Removes the mirror copy of the provided
-- object from the HeadMirrors table, if it
-- is defined in there presently.

function FpsCamera:RemoveHeadMirror(desc)
	local mirror = self.HeadMirrors[desc]
	
	if mirror then
		mirror:Destroy()
		self.HeadMirrors[desc] = nil
	end
end

-- Called when the user's rotation type is changed.
-- This is a strong indication the user is in first person
-- and needs to have its first person movement smoothened out.

function FpsCamera:OnRotationTypeChanged()
	local camera = workspace.CurrentCamera
	local subject = camera and camera.CameraSubject
	
	if subject and subject:IsA("Humanoid") then
		local rotationType = UserGameSettings.RotationType
	
		if rotationType == Enum.RotationType.CameraRelative then
			subject.AutoRotate = false
			
			RunService:BindToRenderStep("FpsCamera", 1000, function (delta)
				if subject.AutoRotate or not subject:IsDescendantOf(game) or (subject.SeatPart and subject.SeatPart:IsA("VehicleSeat")) then
					RunService:UnbindFromRenderStep("FpsCamera")
					return
				end

				if camera.CameraType.Name == "Scriptable" then
					return
				end
				
				local rootPart = subject.RootPart
				local isGrounded = rootPart and rootPart:IsGrounded()
				
				if rootPart and not isGrounded then
					local state = subject:GetState()
					local canRotate = true

					if self.InvalidRotationStates[state.Name] then
						canRotate = false
					end

					if subject.Sit and subject.SeatPart then
						local root = rootPart:GetRootPart()

						if root ~= rootPart then
							canRotate = false
						end
					end

					if canRotate then
						local pos = rootPart.Position
						local step = math.min(0.2, (delta * 40) / 3)

						local look = camera.CFrame.LookVector
						look = (look * XZ_VECTOR3).Unit
						
						local cf = CFrame.new(pos, pos + look)
						rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
					end
				end

				if self:IsInFirstPerson() then
					local cf = camera.CFrame
					local headPos, headLook = self:GetSubjectPosition(subject)

					if headPos then
						local offset = (headPos - cf.Position)
						cf += offset

						camera.CFrame = cf
						camera.Focus += offset
					end

					local shadowAngle = self:GetShadowAngle()
					local inView = cf.LookVector:Dot(shadowAngle)

					if inView < 0 then
						for real, mirror in pairs(self.HeadMirrors) do
							mirror.CFrame = real.CFrame + (shadowAngle * 9)
						end
					end

					self.MirrorBin.Parent = (inView < 0 and camera or nil)
				else
					self.MirrorBin.Parent = nil
				end
			end)
		else
			subject.AutoRotate = true
			self.MirrorBin.Parent = nil
		end
	end
end

-- Called when the player's character is added.
-- Sets up mirroring of the player's head for first person.

function FpsCamera:OnCharacterAdded(character)
	local mirrorBin = self.MirrorBin
	
	if mirrorBin then
		mirrorBin:ClearAllChildren()
		mirrorBin.Parent = nil
	end
	
	self.HeadMirrors = {}
	
	for _,desc in pairs(character:GetDescendants()) do
		self:AddHeadMirror(desc)
	end
	
	self:Connect("AddHeadMirror", character.DescendantAdded)
	self:Connect("RemoveHeadMirror", character.DescendantRemoving)
end

-- Called once to start the FpsCamera logic.
-- Binds and overloads everything necessary.

local started = false

function FpsCamera:Start()
	if started then
		return
	else
		started = true
	end
	
	local player = Players.LocalPlayer
	local character = player.Character
	
	local PlayerScripts = player:WaitForChild("PlayerScripts")
	local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")
	
	local baseCamera = PlayerModule:FindFirstChild("BaseCamera", true)
	local transparency = PlayerModule:FindFirstChild("TransparencyController", true)
	
	if baseCamera and baseCamera:IsA("ModuleScript") then
		local module = require(baseCamera)
		self:MountBaseCamera(module)
	else
		self:Warn("Start - Could not find BaseCamera module!")
	end
	
	if transparency and transparency:IsA("ModuleScript") then
		local module = require(transparency)
		self:MountTransparency(module)
	else
		self:Warn("Start - Cound not find TransparencyController module!")
	end
	
	local rotListener = UserGameSettings:GetPropertyChangedSignal("RotationType")
	self:Connect("OnRotationTypeChanged", rotListener)
	
	self.MirrorBin = Instance.new("Folder")
	self.MirrorBin.Name = "HeadMirrors"
	
	if character then
		self:OnCharacterAdded(character)
	end
	
	self:Connect("OnCharacterAdded", player.CharacterAdded)
end

return FpsCamera
