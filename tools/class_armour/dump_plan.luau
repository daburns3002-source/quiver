local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local repo, out = process.args[1], process.args[2]
local env = setmetatable({ Vector3 = roblox.Vector3, Color3 = roblox.Color3 }, { __index = _G })
local config = luau.load(fs.readFile(repo .. "/src/shared/Config/ClassOutfits.luau"), { environment = env })()
local function v(x) return { x.X, x.Y, x.Z } end
local data = { floor = config.floor, body = {}, sets = {} }
for name, body in config.standard do
	table.insert(data.body, { part = name, min = v(body.at - body.size / 2), max = v(body.at + body.size / 2) })
end
for class, set in config.sets do
	local list = {}
	for _, piece in set.pieces do
		local body = config.standard[piece.part]
		for _, block in piece.blocks do
			local c = body.at + block.at
			table.insert(list, {
				piece = piece.name, part = piece.part,
				min = v(c - block.size / 2), max = v(c + block.size / 2),
				colour = { block.colour.R, block.colour.G, block.colour.B }, glow = block.glow == true,
			})
		end
	end
	data.sets[class] = list
end
fs.writeFile(out, serde.encode("json", data))
print("ok")
