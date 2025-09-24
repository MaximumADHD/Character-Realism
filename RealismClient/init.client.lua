------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MaximumADHD, 2020
-- Realism Client
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Dependencies
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = assert(Players.LocalPlayer)
local FirstPerson = require(script.FirstPerson)
local XZ_VECTOR3 = Vector3.new(1, 0, 1)

local Config = require(script.Config) :: {
	Sounds: {
		[string]: number,
	},

	MaterialMap: {
		[string]: string,
	},

	RotationFactors: {
		[string]: {
			Pitch: number,
			Yaw: number,
		},
	},

	SkipLookAngle: boolean?,
	SkipMaterialSounds: boolean?,
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Main Logic
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local setLookAngles = ReplicatedStorage:WaitForChild("SetLookAngles")
assert(setLookAngles:IsA("RemoteEvent"), "bad SetLookAngles")

local module = {
	Started = false,

	Rotators = {} :: {
		[Model]: JointRotator,
	},

	DropQueue = {} :: { Model },
	LastUpdate = 0,

	Pitch = 0 / 0,
	Yaw = 0 / 0,
}

type AngleState = {
	Value: number?,
	Current: number,
	Goal: number,
}

type MotorState = {
	Motor: Motor6D | AnimationConstraint,
	LastTransform: CFrame?,
}

type JointRotator = {
	LastStep: number?,
	Pitch: AngleState,
	Yaw: AngleState,

	Motors: {
		[string]: MotorState,
	},

	-- TODO: Replace with maid
	Listener: RBXScriptConnection?,
}

local function round(n: number, factor: number?): number
	local mult = 10 ^ (factor or 0)
	return math.floor((n * mult) + 0.5) / mult
end

local function roundNearestInterval(n: number, factor: number): number
	return round(n / factor) * factor
end

local function stepTowards(value: number, goal: number, rate: number): number
	local result = value

	if math.abs(value - goal) < rate then
		result = goal
	elseif value > goal then
		result = value - rate
	elseif value < goal then
		result = value + rate
	end

	return result
end

local function awaitValue<T, Args...>(object: any, prop: string, andThen: (T, Args...) -> (), ...: Args...): thread
	return task.spawn(function(...)
		local timeOut = os.clock() + 10

		while not object[prop] do
			local now = os.clock()

			if (timeOut - now) < 0 then
				return
			end

			RunService.Heartbeat:Wait()
		end

		andThen(object[prop], ...)
	end, ...)
end

-- Register's a newly added Motor6D
-- into the provided joint rotator.

local function addMotor(rotator, motor: Motor6D | AnimationConstraint)
	-- Wait until this motor is marked as active
	-- before attempting to use it in the rotator.

	awaitValue(motor, "Active", function()
		local part1 = assert(motor:IsA("AnimationConstraint") and motor.Attachment1 or motor.Part1)
		
		if part1:IsA("Attachment") then
			part1 = part1.Parent ~= nil and part1.Parent or part1
		end

		local data: MotorState = {
			Motor = motor,
		}

		local id = part1.Name
		rotator.Motors[id] = data
	end)
end

-- Called when the client receives a new look-angle
-- value from the server. This is also called continuously
-- on the client to update the player's view with no latency.

local function onLookReceive(player: Player, pitch: number, yaw: number)
	local character = player.Character
	local rotator = character and module.Rotators[character]

	if rotator then
		rotator.Pitch.Goal = pitch
		rotator.Yaw.Goal = yaw
	end
end

-- Computes the look-angle to be used by the client.
-- If no lookVector is provided, the camera's lookVector is used instead.
-- useDir (-1 or 1) can be given to force whether the direction is flipped or not.

local function computeLookAngle(lookVector: Vector3?, useDir: number?)
	local inFirstPerson = FirstPerson.IsInFirstPerson()
	local pitch, yaw, dir = 0, 0, 1

	if not lookVector then
		local camera = workspace.CurrentCamera :: Camera
		lookVector = camera.CFrame.LookVector
	end

	if lookVector then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			local cf = rootPart.CFrame
			pitch = -cf.RightVector:Dot(lookVector)

			if not inFirstPerson then
				dir = math.clamp(cf.LookVector:Dot(lookVector) * 10, -1, 1)
			end
		end

		yaw = lookVector.Y
	end

	if useDir then
		dir = useDir
	end

	pitch *= dir
	yaw *= dir

	return pitch, yaw
end

-- Interpolates the current value of a rotator
-- state (pitch/yaw) towards its goal value.

local function stepValue(state: AngleState, dt: number)
	local current = state.Current or 0
	local goal = state.Goal

	local pan = 5 / (dt * 60)
	local rate = math.min(1, (dt * 20) / 3)

	local step = math.min(rate, math.abs(goal - current) / pan)
	state.Current = stepTowards(current, goal, step)

	return state.Current
end

-- Called to update all of the look-angles being tracked
-- on the client, as well as our own client look-angles.
-- This is called during every RunService Heartbeat.

local function updateLookAngles(dt: number)
	-- Update our own look-angles with no latency
	local pitch, yaw = computeLookAngle()
	onLookReceive(player, pitch, yaw)

	-- Submit our look-angles if they have changed enough.
	local now = os.clock()

	if (now - module.LastUpdate) > 0.05 then
		local dirty = false
		yaw = roundNearestInterval(yaw, 0.01)
		pitch = roundNearestInterval(pitch, 0.01)

		if pitch ~= module.Pitch then
			module.Pitch = pitch
			dirty = true
		end

		if yaw ~= module.Yaw then
			module.Yaw = yaw
			dirty = true
		end

		if dirty then
			module.LastUpdate = now
			setLookAngles:FireServer(pitch, yaw)
		end
	end

	-- Update all of the character look-angles
	local camera = workspace.CurrentCamera :: Camera
	local camPos = camera.CFrame.Position

	for character, rotator in module.Rotators do
		if not character.Parent then
			table.insert(module.DropQueue, character)
			continue
		end

		local owner = Players:GetPlayerFromCharacter(character)
		local dist = owner and owner:DistanceFromCharacter(camPos) or 0

		if owner ~= player and dist > 30 then
			continue
		end

		local lastStep = rotator.LastStep or 0
		local stepDelta = now - lastStep

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = humanoid and humanoid.RootPart

		if not rootPart then
			continue
		end

		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
		local numTracks = animator and #animator:GetPlayingAnimationTracks() or 0

		local pitchState = rotator.Pitch
		stepValue(pitchState, stepDelta)

		local yawState = rotator.Yaw
		stepValue(yawState, stepDelta)

		local motors = rotator.Motors
		rotator.LastStep = now

		if not motors then
			continue
		end

		for name, factors in Config.RotationFactors do
			local data = motors and motors[name]
			local motor = data and data.Motor

			if not motor then
				continue
			end

			local myPitch = pitchState.Current or 0
			local myYaw = yawState.Current or 0

			local fPitch = myPitch * factors.Pitch
			local fYaw = myYaw * factors.Yaw

			-- HACK: Make the arms rotate with a tool.
			if name:sub(-4) == " Arm" or name:sub(-8) == "UpperArm" then
				local tool = character:FindFirstChildOfClass("Tool")

				if tool and not tool:HasTag("NoArmRotation") then
					if rootPart and name:sub(1, 5) == "Right" and rootPart.AssemblyRootPart ~= rootPart then
						fPitch = pitch * 1.3
						fYaw = yaw * 1.3
					else
						fYaw = yaw * 0.8
					end
				end
			end

			local dirty = false

			if fPitch ~= pitchState.Value then
				pitchState.Value = fPitch
				dirty = true
			end

			if fYaw ~= yawState.Value then
				yawState.Value = fYaw
				dirty = true
			end

			if dirty then
				-- stylua: ignore
				local cf = CFrame.Angles(0, fPitch, 0)
					* CFrame.Angles(fYaw, 0, 0)

				-- TODO: What's the correct way to handle this?
				if numTracks > 0 then
					motor.Transform *= cf
				else
					motor.Transform = cf
				end
			end
		end
	end

	while true do
		local character = table.remove(module.DropQueue)

		if character then
			local rotator = module.Rotators[character]
			local listener = rotator and rotator.Listener

			if listener then
				listener:Disconnect()
			end

			module.Rotators[character] = nil
		else
			break
		end
	end
end

-- Mounts the provided humanoid into the look-angle
-- update system, binding all of its current and
-- future Motor6D joints into the rotator.

function module.MountLookAngle(humanoid: Humanoid)
	local character = humanoid.Parent
	assert(character and character:IsA("Model"), "Invalid parent for Humanoid!")

	if module.Rotators[character] == nil then
		-- Create a rotator for this character.
		local rotator: JointRotator = {
			Motors = {},

			Pitch = {
				Goal = 0,
				Current = 0,
			},

			Yaw = {
				Goal = 0,
				Current = 0,
			},
		}

		-- Register this rotator for the character.
		module.Rotators[character] = rotator

		-- Record all existing Motor6D joints
		-- and begin recording newly added ones.

		local function onDescendantAdded(desc: Instance)
			if desc:IsA("Motor6D") or desc:IsA("AnimationConstraint") then
				addMotor(rotator, desc)
			end
		end

		for _, desc in pairs(character:GetDescendants()) do
			onDescendantAdded(desc)
		end

		rotator.Listener = character.DescendantAdded:Connect(onDescendantAdded)
	end

	return module.Rotators[character]
end

-- Mounts the custom material walking
-- sounds into the provided humanoid.

function module.MountMaterialSounds(humanoid: Instance)
	if not humanoid:IsA("Humanoid") then
		return
	end

	local character = assert(humanoid.Parent)
	local running: Sound?

	local function updateRunningSoundId()
		local soundId = Config.Sounds.Concrete
		local material = humanoid.FloorMaterial.Name

		if not Config.Sounds[material] then
			material = Config.MaterialMap[material]
		end

		if Config.Sounds[material] then
			soundId = Config.Sounds[material]
		end

		if running then
			running.SoundId = `rbxassetid://{soundId or 0}`
		end
	end

	local function onDescendantAdded(desc: Instance)
		if desc:IsA("Sound") and desc.Name == "Running" then
			running = desc
			updateRunningSoundId()
		end
	end

	local function onStateChanged(_: any, new: Enum.HumanoidStateType)
		if not new.Name:find("Running") then
			return
		end

		while humanoid:GetState() == new do
			local hipHeight = humanoid.HipHeight
			local rootPart = humanoid.RootPart

			if rootPart then
				if humanoid.RigType.Name == "R6" then
					hipHeight = 2.8
				end

				local scale = hipHeight / 3
				local speed = (rootPart.AssemblyLinearVelocity * XZ_VECTOR3).Magnitude

				local volume = ((speed - 4) / 12) * scale
				if running then
					running.Volume = math.clamp(volume, 0, 1)
					running.PlaybackSpeed = 1 / ((scale * 15) / speed)
				end
			end

			RunService.Heartbeat:Wait()
		end
	end

	-- TODO: Tie these to a maid!
	local floorChanged = humanoid:GetPropertyChangedSignal("FloorMaterial")
	task.spawn(onStateChanged, nil, humanoid:GetState())

	character.DescendantAdded:Connect(onDescendantAdded)
	humanoid.StateChanged:Connect(onStateChanged)
	floorChanged:Connect(updateRunningSoundId)
end

-- Called when the RealismHook tag is added to a
-- humanoid in the DataModel. Mounts the look-angle
-- and material walking sounds into this humanoid.

local function onHumanoidAdded(humanoid: Instance)
	if humanoid:IsA("Humanoid") then
		if not Config.SkipLookAngle then
			task.spawn(module.MountLookAngle, humanoid)
		end

		if not Config.SkipMaterialSounds then
			task.spawn(module.MountMaterialSounds, humanoid)
		end
	end
end

-- Call this once when the
-- realism client is starting.

function module.Start()
	if module.Started then
		return
	end

	local humanoidAdded = CollectionService:GetInstanceAddedSignal("RealismHook")
	module.Started = true

	for _, humanoid in CollectionService:GetTagged("RealismHook") do
		task.spawn(onHumanoidAdded, humanoid)
	end

	-- TODO: Tie these to a maid!
	task.spawn(FirstPerson.Start)
	humanoidAdded:Connect(onHumanoidAdded)
	RunService.Stepped:Connect(updateLookAngles)
	setLookAngles.OnClientEvent:Connect(onLookReceive)
end

if not script:IsA("ModuleScript") then
	assert(Players.LocalPlayer, "RealismClient expects a Player on the client to automatically start!")
	task.spawn(module.Start)
end

return module
