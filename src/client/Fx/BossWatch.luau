--!strict
--[[
	Whether a boss is in the room, for everything that marks its arrival on
	this client: the boss music's battle intro (`Fx/MusicFx`) and the entry
	banner (`UI/BossBanner`). One poll for both, so the banner lands on the
	same tick as the intro.

	Presentation only: read from the enemies the server put in the
	Workspace (a model with the `Boss` attribute, which carries its title).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossWatch = {}

--[[ Seconds between looks; a boss's arrival is felt within this. ]]
local POLL = 0.5

local title: string? = nil
local listeners: { (title: string?) -> () } = {}
local started = false

local function find(): string?
	local enemies = Workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	for _, enemy in enemies:GetChildren() do
		local boss = enemy:GetAttribute("Boss")
		if boss ~= nil then
			return tostring(boss)
		end
	end
	return nil
end

--[[ The title of the boss in the room, or nil. ]]
function BossWatch.current(): string?
	return title
end

--[[ Called with the boss's title when one arrives, and with nil when the
     room has none again. ]]
function BossWatch.onChange(listener: (title: string?) -> ())
	table.insert(listeners, listener)
end

function BossWatch.start()
	if started then
		return
	end
	started = true
	local polled = 0
	RunService.Heartbeat:Connect(function(dt: number)
		polled += dt
		if polled < POLL then
			return
		end
		polled = 0
		local now = find()
		if now == title then
			return
		end
		title = now
		for _, listener in listeners do
			task.spawn(listener, now)
		end
	end)
end

return BossWatch
