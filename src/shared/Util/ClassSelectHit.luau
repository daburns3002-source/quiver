--!strict
--[[ Slanted class-panel ownership on the approved 1920 x 1080 canvas. ]]
local borders = table.freeze({ 87, 313, 538, 768, 993, 1221, 1460, 1686, 1914 })
local ClassSelectHit = {}
function ClassSelectHit.section(x: number, y: number): number?
	if x < 0 or x > 1920 or y < 0 or y > 1080 then
		return nil
	end
	local projected = x + 0.245 * (y - 300)
	for i = 1, 8 do
		if projected >= borders[i] and projected < borders[i + 1] then
			return i
		end
	end
	return nil
end
--[[ The section under (`x`, `y`) on the upright picture `layout`: its band
     picks the class and its side the look, male left of `split`. ]]
function ClassSelectHit.upright(
	layout: {
		size: Vector2,
		split: number,
		bands: { { top: number, bottom: number } },
	},
	x: number,
	y: number
): number?
	if x < 0 or x > layout.size.X then
		return nil
	end
	for band, edges in layout.bands do
		if y >= edges.top and y < edges.bottom then
			return (band - 1) * 2 + (if x < layout.split then 1 else 2)
		end
	end
	return nil
end
return table.freeze(ClassSelectHit)
