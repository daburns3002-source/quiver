--!strict
--[[
	The gold "go here" pointer, drawn: a stepped gold arrow pointing down that
	bobs and turns over a place, words under it if given, and a row of gold
	tiles on the floor from the player toward it (where they sit:
	`Util/WayPointer`). Made for the lobby's way to the first egg
	(`Fx/HatcheryPointer`) and shared with the open exit gate
	(`Fx/DoorPointer`), so the two look and move alike. Only on this client,
	a look only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WayPointer = require(ReplicatedStorage.Shared.Util.WayPointer)

local GoldPointer = {}

local GOLD = Color3.fromRGB(255, 214, 72)
-- how far the arrow bobs, in studs at scale 1
local BOB = 2.5

export type Options = {
	name: string,
	--[[ under the arrow, or none ]]
	words: string?,
	--[[ the arrow's size and bob against the lobby's, 1 ]]
	scale: number?,
	--[[ the tiles' height: a fixed floor, or nil for under the player's
	     root, as in the lobby ]]
	tileY: number?,
}

export type Pointer = {
	--[[ Poses it over `target` (the arrow's tip) for `root`'s player. ]]
	pose: (self: Pointer, target: Vector3, root: BasePart?, now: number) -> (),
	destroy: (self: Pointer) -> (),
}

local function block(name: string, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = GOLD
	p.Size = size
	p.Parent = parent
	return p
end

function GoldPointer.new(options: Options): Pointer
	local scale = options.scale or 1
	local folder = Instance.new("Folder")
	folder.Name = options.name
	-- a stepped arrow pointing down: a stem, then rows narrowing to a tip
	local arrow = {
		block("Stem", Vector3.new(3, 5, 3) * scale, folder),
		block("Row1", Vector3.new(9, 1.6, 3) * scale, folder),
		block("Row2", Vector3.new(6, 1.6, 3) * scale, folder),
		block("Tip", Vector3.new(3, 1.6, 3) * scale, folder),
	}
	-- each piece's height over the tip's centre
	local rise = { 6.5 * scale, 3.2 * scale, 1.6 * scale, 0 }
	if options.words then
		local label = Instance.new("BillboardGui")
		label.Name = "Words"
		label.Size = UDim2.fromOffset(320, 50)
		label.StudsOffsetWorldSpace = Vector3.new(0, -3 * scale - 2, 0)
		label.AlwaysOnTop = true
		label.Adornee = arrow[4]
		label.Parent = arrow[4]
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
		text.Text = options.words
		text.TextScaled = true
		text.TextColor3 = GOLD
		text.TextStrokeTransparency = 0
		text.Parent = label
	end
	local tiles: { Part } = {}
	for i = 1, WayPointer.TILES do
		local tile = block("Tile" .. i, Vector3.new(1.4, 0.3, 1.4), folder)
		tile.Transparency = 0.2
		table.insert(tiles, tile)
	end
	folder.Parent = Workspace

	local pointer = {} :: Pointer

	function pointer.pose(_self: Pointer, target: Vector3, root: BasePart?, now: number)
		local tip = target + Vector3.new(0, math.sin(now * 3) * BOB * scale, 0)
		local spin = CFrame.Angles(0, now * 1.2, 0)
		for i, part in arrow do
			part.CFrame = CFrame.new(tip + Vector3.new(0, rise[i], 0)) * spin
		end
		local spots: { Vector3 } = if root then WayPointer.tiles(root.Position, target) else {}
		for i, tile in tiles do
			local at = spots[i]
			if root and at then
				-- a wave runs out along the row, toward the target
				local lift = math.max(0, math.sin(now * 5 - i * 0.9)) * 0.6
				local y = (options.tileY or root.Position.Y - 2.8) + lift
				tile.Transparency = 0.2
				tile.CFrame =
					CFrame.lookAt(Vector3.new(at.X, y, at.Z), Vector3.new(target.X, y, target.Z))
			else
				tile.Transparency = 1
			end
		end
	end

	function pointer.destroy(_self: Pointer)
		folder:Destroy()
	end

	return pointer
end

return GoldPointer
