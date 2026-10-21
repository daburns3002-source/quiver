--!strict
--[[
	Remote accessor.

	The server creates the remotes; the client waits for them. Both sides name
	them through this module so a typo is a missing key rather than a silent
	`WaitForChild` that hangs forever.

	Nothing here grants authority. Every remote listed below is server→client
	except RequestRespawn, and that one carries no payload the server trusts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local WAIT_TIMEOUT = 10

local Remotes = {}

--[[
	Server → clients. One packet per volley, carrying the whole shot description
	so clients can simulate the flight locally. See Types.ShotEvent.
]]
Remotes.ShotFired = "ShotFired"

--[[
	Server → clients. An enemy took damage: enough for a flash and a damage
	number. The client is told what happened, never asked to decide it.
]]
Remotes.EnemyHit = "EnemyHit"

--[[ Server → clients. An enemy died, for the death effect. ]]
Remotes.EnemyDied = "EnemyDied"

--[[ Server → one client. The local player took damage, for shake and vignette. ]]
Remotes.PlayerDamaged = "PlayerDamaged"

--[[ Server → one client. Health changed for any reason, including spawn. ]]
Remotes.HealthChanged = "HealthChanged"

local function getFolder(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing :: Folder
		end

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT)
	assert(folder, `Remotes folder never replicated after {WAIT_TIMEOUT}s`)
	return folder :: Folder
end

--[[
	Returns the named RemoteEvent, creating it on the server and waiting for it
	on the client.
]]
function Remotes.event(name: string): RemoteEvent
	local folder = getFolder()

	if RunService:IsServer() then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end

		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	assert(remote, `Remote "{name}" never replicated after {WAIT_TIMEOUT}s`)
	return remote :: RemoteEvent
end

return Remotes
