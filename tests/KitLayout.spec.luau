--!strict
--[[
	Rooms built from an arena kit (`Shared/Util/KitLayout`, the owner's
	blocky Mossy Glade). For every room that asks for a kit: every cover box
	is drawn by a piece; the path and the plants never stand in cover, on
	the start or in the gate; and the walls leave the gate's gap open. What
	stops movement and arrows is still the room's invisible boxes, so what
	is drawn must sit on them and nowhere else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaModels = require(ReplicatedStorage.Shared.Config.ArenaModels)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local KitLayout = require(ReplicatedStorage.Shared.Util.KitLayout)
local TestRunner = require(script.Parent.TestRunner)

type Room = { name: string, arena: string?, obstacles: { KitLayout.Obstacle } }

local function kitRooms(): { { room: Room, model: ArenaModels.ArenaModel } }
	local out = {}
	for _, room in (Balance.Rooms :: any) :: { Room } do
		local model = if room.arena then (ArenaModels :: any)[room.arena] else nil
		if model and model.kit then
			table.insert(out, { room = room, model = model })
		end
	end
	return out
end

local function layoutFor(
	room: Room,
	model: ArenaModels.ArenaModel
): (KitLayout.Layout, KitLayout.Room)
	local config = Balance.Arena
	local shape: KitLayout.Room = {
		size = config.size,
		wallThickness = config.wallThickness,
		spawn = config.spawnPosition,
		gateWidth = Balance.Run.gate.width + Balance.Run.gate.pillarWidth * 2,
	}
	return KitLayout.build(
		model.kit :: string,
		shape,
		room.obstacles,
		model.lowCover or "Thicket",
		KitLayout.seed(room.arena :: string)
	),
		shape
end

return function(t: TestRunner.Helper)
	t.test("some rooms are built from a kit", function()
		t.isTrue(#kitRooms() > 0, "no room asks for a kit")
	end)

	t.test("every cover box is drawn", function()
		for _, entry in kitRooms() do
			local layout = layoutFor(entry.room, entry.model)
			for _, box in entry.room.obstacles do
				local drawn = false
				for _, p in layout.pieces do
					if
						p.cover
						and math.abs(p.base.X - box.offset.X) <= box.size.X / 2
						and math.abs(p.base.Z - box.offset.Y) <= box.size.Z / 2
					then
						drawn = true
					end
				end
				for _, patch in layout.patches do
					if
						patch.kind == "Water"
						and math.abs(patch.centre.X - box.offset.X) < 0.01
						and math.abs(patch.centre.Z - box.offset.Y) < 0.01
					then
						drawn = true
					end
				end
				t.isTrue(drawn, `{entry.room.name}: a cover box at {box.offset} is not drawn`)
			end
		end
	end)

	t.test("path and plants keep out of cover, the start and the gate", function()
		for _, entry in kitRooms() do
			local layout, shape = layoutFor(entry.room, entry.model)
			local hz = shape.size.Z / 2
			for _, p in layout.pieces do
				if p.cover or p.piece == "WallBlock" or p.piece == "CornerPillar" then
					continue
				end
				for _, box in entry.room.obstacles do
					local inside = math.abs(p.base.X - box.offset.X) < box.size.X / 2
						and math.abs(p.base.Z - box.offset.Y) < box.size.Z / 2
					t.isTrue(not inside, `{entry.room.name}: a {p.piece} stands in cover`)
				end
				local start = Vector3.new(shape.spawn.X, 0, shape.spawn.Z)
				t.isTrue(
					(p.base - start).Magnitude >= 2,
					`{entry.room.name}: a {p.piece} stands on the start`
				)
				local inGate = p.base.Z < -hz + 2 and math.abs(p.base.X) < shape.gateWidth / 2
				t.isTrue(not inGate, `{entry.room.name}: a {p.piece} stands in the gate`)
			end
		end
	end)

	t.test("the walls leave the gate's gap open", function()
		for _, entry in kitRooms() do
			local layout, shape = layoutFor(entry.room, entry.model)
			local hz = shape.size.Z / 2
			for _, p in layout.pieces do
				if p.piece == "WallBlock" and p.base.Z < -hz then
					local reach = p.size.X / 2
					t.isTrue(
						math.abs(p.base.X) - reach >= shape.gateWidth / 2 - 1e-6,
						`{entry.room.name}: a wall block stands in the gate`
					)
				end
			end
		end
	end)
end
