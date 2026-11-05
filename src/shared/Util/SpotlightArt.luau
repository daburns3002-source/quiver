--!strict
--[[
	Draws a picture larger than Roblox keeps from its tiles: the loading
	screen's spotlights and the upright class select (owner, 2026-11-05: "i
	need the loading thumbnails higher resolution").

	Roblox shrinks every uploaded image to 1024 pixels on its longest side, so
	a 1672x941 spotlight uploaded whole was shown at 1024x576, about 61% of
	its pixels. Each is uploaded instead as a grid of tiles of equal share,
	`columns` across (all of them, if not given) and read row by row, each
	under that limit, and laid here to fill `parent`, so the picture reaches
	the screen at full size.

	Each tile carries `overlap` pixels of its neighbours past every inner edge
	and shows only its own share through `ImageRect`. Cut flush, the GPU
	blended each tile's edge pixel with nothing and a faint light line ran
	down the seam; with real picture beyond the edge it blends into that.
]]

local SpotlightArt = {}

function SpotlightArt.draw(
	parent: GuiObject,
	tiles: { string },
	zIndex: number,
	size: Vector2,
	overlap: number,
	columns: number?
)
	local across = columns or #tiles
	local down = math.ceil(#tiles / across)
	local share = Vector2.new(size.X / across, size.Y / down)
	for k, id in tiles do
		local column = (k - 1) % across
		local row = (k - 1) // across
		local tile = Instance.new("ImageLabel")
		tile.Name = "Art" .. k
		tile.BackgroundTransparency = 1
		tile.BorderSizePixel = 0
		tile.Image = id
		tile.ImageRectOffset =
			Vector2.new(if column > 0 then overlap else 0, if row > 0 then overlap else 0)
		tile.ImageRectSize = share
		tile.Position = UDim2.fromScale(column / across, row / down)
		tile.Size = UDim2.fromScale(1 / across, 1 / down)
		tile.ZIndex = zIndex
		tile.Parent = parent
	end
end

return SpotlightArt
