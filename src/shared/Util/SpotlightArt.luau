--!strict
--[[
	Draws one of the loading screen's spotlights from its tiles (owner,
	2026-11-05: "i need the loading thumbnails higher resolution").

	Roblox shrinks every uploaded image to 1024 pixels on its longest side, so
	a 1672x941 spotlight uploaded whole was shown at 1024x576, about 61% of
	its pixels. Each is uploaded instead as tiles of equal share, left to
	right, each under that limit, and laid side by side here to fill
	`parent`, so the picture reaches the screen at its full size.

	Each tile carries `overlap` pixels of its neighbour past every inner edge
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
	overlap: number
)
	local count = #tiles
	local share = Vector2.new(size.X / count, size.Y)
	for k, id in tiles do
		local tile = Instance.new("ImageLabel")
		tile.Name = "Art" .. k
		tile.BackgroundTransparency = 1
		tile.BorderSizePixel = 0
		tile.Image = id
		tile.ImageRectOffset = Vector2.new(if k > 1 then overlap else 0, 0)
		tile.ImageRectSize = share
		tile.Position = UDim2.fromScale((k - 1) / count, 0)
		tile.Size = UDim2.fromScale(1 / count, 1)
		tile.ZIndex = zIndex
		tile.Parent = parent
	end
end

return SpotlightArt
