--!strict
--[[
	The "YOU: #N" row under each lobby leaderboard (the loop review's item
	13), shared by `Run/StoryLeaderboard` and `Run/EndlessLeaderboard`.

	A board is one SurfaceGui every player sees, so it cannot say "you" by
	itself. The server builds one empty row under the top ten, tagged
	`BoardYou`, and publishes each player's own place as two attributes on
	their Player (`<Board>YouRank`, the words; `<Board>YouBest`, their best
	as the board writes it). Each client writes its own two into the row
	(`UI/BoardYou`); a text set on the client stays on that client.

	The place is the server's (`Util/BoardRank`), from the same list the
	board is drawn from. Nothing a client sends reaches this.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoardRank = require(ReplicatedStorage.Shared.Util.BoardRank)
local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)

local BoardYou = {}

BoardYou.TAG = "BoardYou"

--[[ The row, at `y` of `back` and `height` tall (both as shares of the
     board), for the board called `kind` ("Story", "Endless"). ]]
function BoardYou.row(back: Frame, kind: string, y: number, height: number)
	local colors = Leaderboard.colors
	local pad = Leaderboard.padding
	local frame = Instance.new("Frame")
	frame.Name = "You"
	frame.Position = UDim2.fromScale(pad, y)
	frame.Size = UDim2.fromScale(1 - pad * 2, height)
	frame.BackgroundColor3 = colors.you
	frame.BorderSizePixel = 0
	frame:SetAttribute("Board", kind)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.youOutline
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local labels: { { name: string, x: number, w: number, right: boolean, color: Color3 } } = {
		{ name = "Words", x = 0.02, w = 0.44, right = false, color = colors.gold },
		{ name = "Best", x = 0.46, w = 0.52, right = true, color = colors.text },
	}
	for _, spec in labels do
		local text = Instance.new("TextLabel")
		text.Name = spec.name
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromScale(spec.x, 0.12)
		text.Size = UDim2.fromScale(spec.w, 0.76)
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.TextXAlignment = if spec.right
			then Enum.TextXAlignment.Right
			else Enum.TextXAlignment.Left
		text.TextColor3 = spec.color
		text.Text = ""
		text.Parent = frame
	end
	frame.Parent = back
	CollectionService:AddTag(frame, BoardYou.TAG)
end

--[[ Tells every player here their place on the board `kind`. `sorted` is
     the board's whole known list, best first; `cutoff` is
     `BoardRank.cutoff` of the store's read; `describe` writes a score as
     the board does. ]]
function BoardYou.publish(
	kind: string,
	sorted: { BoardRank.Scored },
	cutoff: number?,
	describe: (score: number) -> string
)
	local scores: { [number]: number } = {}
	for _, entry in sorted do
		scores[entry.userId] = entry.score
	end
	for _, player in Players:GetPlayers() do
		local place = BoardRank.place(sorted, player.UserId, cutoff)
		local score = scores[player.UserId]
		player:SetAttribute(kind .. "YouRank", BoardRank.words(place, Leaderboard.rankDepth))
		player:SetAttribute(
			kind .. "YouBest",
			if score and score > 0 then describe(score) else Leaderboard.youEmpty
		)
	end
end

return BoardYou
