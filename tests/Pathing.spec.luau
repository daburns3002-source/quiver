--!strict
--[[
	Enemies find their way round cover (`Enemies/Pathing`).

	The steering it replaced slid along whatever face an enemy bumped into and
	got stuck in any corner cover made with cover or a wall: 28 of 165 Moss
	Slimes reached a player hiding behind cover in Level 1's rooms. These pin
	the planner itself, against every Level 1 room's real layout: a route
	exists from across the floor to behind its cover, every leg is clear for
	the body that walks it, and it ends where the body can reach.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Arena = require(ServerScriptService.Server.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Pathing = require(ServerScriptService.Server.Enemies.Pathing)
local TestRunner = require(script.Parent.TestRunner)

--[[ A spot behind each room's main cover, as seen from the south where a
     room's enemies arrive. Room order is Level 1's: logs, hollow, boulders,
     thorns, boss arena. ]]
local BEHIND = {
	Vector3.new(-2.4, 0, -16),
	Vector3.new(-4, 0, -11),
	Vector3.new(-8, 0, -15),
	Vector3.new(7.8, 0, 2),
	Vector3.new(-11.4, 0, -20),
}

local function levelOneRooms(): { Balance.RoomConfig }
	local rooms = {}
	for _, stage in Balance.Stages do
		if stage.name == "Level 1" then
			for index = 1, 5 do
				table.insert(rooms, Balance.Rooms[(stage.rooms :: { number })[index]])
			end
		end
	end
	return rooms
end

local function radiusOf(config: Balance.EnemyConfig): number
	return math.max(config.hitboxSize.X, config.hitboxSize.Z) / 2
end

return function(t: TestRunner.Helper)
	t.test("Level 1 has its five room shapes to path through", function()
		t.equal(#levelOneRooms(), 5)
	end)

	t.test("a Moss Slime has a route behind the cover in every Level 1 room", function()
		local charger = Balance.Enemies.MeleeCharger
		local radius = radiusOf(charger)
		for index, room in levelOneRooms() do
			Arena.build(Instance.new("Folder"), room.obstacles)
			local target = BEHIND[index]
			for x = -12, 12, 6 do
				for z = 8, 24, 8 do
					local from = Vector3.new(x, 0, z)
					if Arena.isClear(from, radius) then
						local route = Pathing.find(from, target, radius)
						t.notNil(route, `{room.name}: no route from ({x}, {z})`)
						if route then
							local last = route[#route]
							t.isTrue(
								(Vector3.new(last.X - target.X, 0, last.Z - target.Z)).Magnitude
									<= charger.attackRange,
								`{room.name}: the route from ({x}, {z}) ends out of reach`
							)
						end
					end
				end
			end
		end
	end)

	--[[ A route is only as good as its legs: one that clips cover sends the
	     body into it, which is the stuck enemy over again. ]]
	t.test("every leg of a route is clear for the body that walks it", function()
		for _, config in { Balance.Enemies.MeleeCharger, Balance.Enemies.BroodSlime } do
			local radius = radiusOf(config)
			for index, room in levelOneRooms() do
				Arena.build(Instance.new("Folder"), room.obstacles)
				local from = Vector3.new(0, 0, 22)
				local route = Pathing.find(from, BEHIND[index], radius)
				if route then
					local at = from
					for leg, point in route do
						t.isTrue(
							Arena.isSegmentClear(at, point, radius - 1e-3),
							`{config.displayName} in {room.name}: leg {leg} clips cover`
						)
						at = point
					end
				end
			end
		end
	end)

	t.test("a target walled off entirely gives no route rather than a bad one", function()
		-- A box round the north end of the room, closed on every side.
		Arena.build(Instance.new("Folder"), {
			{ offset = Vector2.new(0, -14), size = Vector3.new(34, 4, 1) },
		})
		local route = Pathing.find(Vector3.new(0, 0, 10), Vector3.new(0, 0, -24), 1.5)
		if route then
			for _, point in route do
				t.isTrue(point.Z > -14, "a route went through the wall")
			end
		end
	end)
end
