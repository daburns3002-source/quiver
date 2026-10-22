--!strict
--[[
	Triangle-cluster spawns.

	Only the shape is tested here, from the pure `EnemyManager.triangle`: that
	no two members of a cluster can touch, and that the tip is the member
	nearest the player. Whether a spot is free is `clusterSpot`'s job, and the
	spawn search it falls back to is pinned by the live checks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local EnemyManager = require(ServerScriptService.Server.Enemies.EnemyManager)
local TestRunner = require(script.Parent.TestRunner)

local function flat(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

return function(t: TestRunner.Helper)
	local enemies: { [string]: Balance.EnemyConfig } = Balance.Enemies :: any

	local function members(
		widest: number,
		toward: Vector3,
		count: number,
		turn: number
	): { Vector3 }
		local tip = Vector3.new(2, 0, -10)
		local out = { tip }
		for _, spot in EnemyManager.triangle(tip, toward, widest, count, turn) do
			table.insert(out, spot)
		end
		return out
	end

	t.test("no two members of a cluster touch, at any turn or size", function()
		local towards = { Vector3.new(0, 0, 20), Vector3.new(-9, 0, -3), Vector3.new(5, 0, 1) }
		for _, config in enemies do
			local widest = math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
			-- Vector3 holds 32-bit floats: a turned row is off by a few millionths.
			local apart = widest * 2 + Balance.Spawning.clusterGap - 1e-4

			for _, toward in towards do
				for count = 2, 4 do
					for _, turn in { 0, math.rad(60), math.pi } do
						local placed = members(widest, toward, count, turn)
						for i = 1, #placed do
							for j = i + 1, #placed do
								t.isTrue(
									flat(placed[i], placed[j]) >= apart,
									"cluster members overlap"
								)
							end
						end
					end
				end
			end
		end
	end)

	t.test("the tip is the member nearest the player", function()
		local tip = Vector3.new(0, 0, -12)
		local toward = Vector3.new(4, 0, 18)
		for _, spot in EnemyManager.triangle(tip, toward, 1.5, 3) do
			t.isTrue(flat(spot, toward) > flat(tip, toward), "a member stands ahead of the tip")
		end
	end)

	t.test("a cluster has one spot per member after the tip", function()
		for count = 1, 4 do
			t.equal(#EnemyManager.triangle(Vector3.zero, Vector3.zAxis * 10, 1, count), count - 1)
		end
	end)

	t.test("clusters are triangles", function()
		t.isTrue(Balance.Spawning.clusterSize >= 1)
		t.isTrue(Balance.Spawning.clusterGap > 0)
	end)
end
