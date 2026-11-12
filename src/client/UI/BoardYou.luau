--!strict
--[[
	Writes this player's own place into the "YOU: #N" row under each lobby
	leaderboard (the loop review's item 13). The server builds the row and
	publishes the place (`Run/BoardYou`: the `BoardYou` tag, and the
	`<Board>YouRank` / `<Board>YouBest` attributes on the Player); a board
	is one SurfaceGui for everyone, so the two texts are set here, where
	they stay on this client.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local BoardYou = {}

local TAG = "BoardYou"
local player = Players.LocalPlayer
local started = false

local function fill(row: Instance)
	local kind = row:GetAttribute("Board")
	if type(kind) ~= "string" then
		return
	end
	local rank = player:GetAttribute(kind .. "YouRank")
	local best = player:GetAttribute(kind .. "YouBest")
	local words = row:FindFirstChild("Words")
	local bestLabel = row:FindFirstChild("Best")
	if words and words:IsA("TextLabel") then
		words.Text = if type(rank) == "string" then rank else "YOU: ---"
	end
	if bestLabel and bestLabel:IsA("TextLabel") then
		bestLabel.Text = if type(best) == "string" then string.upper(best) else ""
	end
end

local function fillAll()
	for _, row in CollectionService:GetTagged(TAG) do
		fill(row)
	end
end

function BoardYou.start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(row)
		-- its labels arrive with it, or a moment after
		task.defer(fill, row)
		row.ChildAdded:Connect(function()
			fill(row)
		end)
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, -7) == "YouRank" or string.sub(name, -7) == "YouBest" then
			fillAll()
		end
	end)
	fillAll()
end

return BoardYou
