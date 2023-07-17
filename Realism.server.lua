------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- MaximumADHD, 2020
-- Realism Server
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local setLookAngles = Instance.new("RemoteEvent")
setLookAngles.Archivable = false
setLookAngles.Name = "SetLookAngles"
setLookAngles.Parent = ReplicatedStorage

local function onReceiveLookAngles(player: Player, pitch: number, yaw: number)
	if type(pitch) == "number" and pitch == pitch then
		pitch = math.clamp(pitch, -1, 1)

		if type(yaw) == "number" and yaw == yaw then
			yaw = math.clamp(yaw, -1, 1)
			setLookAngles:FireAllClients(player, pitch, yaw)
		end
	end
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)

	if humanoid and humanoid:IsA("Humanoid") then
		humanoid:AddTag("RealismHook")
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
setLookAngles.OnServerEvent:Connect(onReceiveLookAngles)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
