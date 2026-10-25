--!nocheck
--[[
	Run with execute_luau in the Client datamodel while playing: jumps the run
	to ROOM (Studio only), lets it build and its enemies arrive, then samples
	what the frame costs for SECONDS. Studio only renders while its window has
	focus, so focus it first, or every number reads zero.

	Returns the triangles and draw calls drawn (Stats.RenderBreakdown), the
	GPU and render-thread milliseconds, the visible parts in the arena, on
	enemies and elsewhere, and, with PROFILE on, the client scripts' busiest
	functions (ScriptProfilerService; its numbers are only for comparing two
	runs of the same scene, not milliseconds).

	To measure a phone's budgets on a computer, set the Workspace attribute
	`DevTier` to "Low" in Edit before Play (`client/Device`). Keep each call short
	and yielding: a long call that never yields fails with "Target is not
	reachable". docs/PERFORMANCE.md has the numbers and how they were taken.
]]

local ROOM = 7
local SETTLE = 5.5 -- seconds for the room to build and its enemies to arrive
local SECONDS = 3
local PROFILE = true

local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local Players = game:GetService("Players")
local SPS = game:GetService("ScriptProfilerService")
local R = game:GetService("ReplicatedStorage").Remotes

local function str(path)
	local item = Stats
	for name in string.gmatch(path, "[^/]+") do
		item = item and item:FindFirstChild(name)
	end
	return item and item:GetValueString()
end
local function num(s, pattern)
	return s and tonumber(string.match(s, pattern)) or 0
end

pcall(function()
	R.AbilityChosen:FireServer(1)
end)
if ROOM then
	R.DebugRoom:FireServer(ROOM)
	task.wait(SETTLE)
	pcall(function()
		R.AbilityChosen:FireServer(1)
	end)
end

local acc = { gpu = 0, tris = 0, draws = 0, render = 0, frames = 0 }
local profile
local dataConnection
if PROFILE then
	dataConnection = SPS.OnNewData:Connect(function(_, json)
		profile = json
	end)
	SPS:ClientStart(Players.LocalPlayer, 1000)
end
local connection = RunService.RenderStepped:Connect(function()
	acc.frames += 1
	acc.gpu += num(str("PerformanceStats/GPU"), "^([%d%.]+)")
	for _, kind in { "Opaque", "Transparent" } do
		local s = str("RenderBreakdown/" .. kind)
		acc.tris += num(s, "^(%d+) tris")
		acc.draws += num(s, "(%d+) draws")
	end
	acc.render += num(str("FrameRateManager/RenderThreadAverage"), "^([%d%.]+)")
end)
task.wait(SECONDS)
connection:Disconnect()

local top = {}
if PROFILE then
	SPS:ClientRequestData(Players.LocalPlayer)
	for _ = 1, 50 do
		if profile then
			break
		end
		task.wait(0.1)
	end
	SPS:ClientStop(Players.LocalPlayer)
	dataConnection:Disconnect()
	if profile then
		local rows = {}
		for _, f in SPS:DeserializeJSON(profile).Functions do
			table.insert(rows, { f.TotalDuration or 0, (f.Source or "?"):gsub("^.*%.", "") .. ":" .. (f.Name or "?") })
		end
		table.sort(rows, function(a, b)
			return a[1] > b[1]
		end)
		for i = 1, math.min(12, #rows) do
			top[i] = string.format("%.3f %s", rows[i][1], rows[i][2])
		end
	end
end

local parts = { arena = 0, enemies = 0, other = 0 }
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 1 then
		local root = d
		while root.Parent and root.Parent ~= workspace do
			root = root.Parent
		end
		local key = if root.Name == "Arena" then "arena" elseif root.Name == "Enemies" then "enemies" else "other"
		parts[key] += 1
	end
end
local n = math.max(acc.frames, 1)
local enemies = workspace:FindFirstChild("Enemies")
return {
	room = ROOM,
	frames = acc.frames,
	tris = acc.tris // n,
	draws = acc.draws // n,
	gpuMs = math.floor(acc.gpu / n * 100) / 100,
	renderThreadMs = math.floor(acc.render / n * 100) / 100,
	enemies = enemies and #enemies:GetChildren() or 0,
	visibleParts = parts,
	scripts = top,
}
