--!strict
--[[
	The FARTHEST ADVENTURERS board (owner, 2026-10-25: "add a leaderboard for
	farthest story completion"): each player's best `Util/StoryProgress`
	score, kept in one OrderedDataStore (`Config/Leaderboard.storeName`, key
	`tostring(userId)`, value the score), and the top ten drawn on a part in
	the lobby. `docs/LEADERBOARD.md` describes the store.

	The server decides every score (non-negotiable 2): `RoomController`
	records one as a room of the campaign is cleared; nothing a client sends
	reaches this module.

	**Saved data is sacred** (non-negotiable 7), and the store is written so
	a score can only ever go up: `UpdateAsync` keeps the larger of what is
	stored and what is offered, and writes nothing when the stored one is
	already as large. That is also why it needs no session lock. A lock
	exists so two servers cannot each read a value, change it, and have the
	second write undo the first. Here the change is `max`, which gives the
	same answer whatever order the writes land in and however often one is
	repeated, and `UpdateAsync` applies it to the value actually stored at
	the time. Two servers recording the same player can only both raise it,
	and the larger wins. The key holds nothing else, so there is nothing for
	a stale server to clobber. The future player save is a different store
	with its own lock and schema; this one is not it.

	Writes are budgeted: a player's best is kept in memory, marked dirty when
	it improves, and written at most every `flushEvery` seconds per player,
	when they leave, and as the server closes. The top is read every
	`refreshEvery` seconds.

	Every DataStore call is in a pcall. In Studio without API access, or
	when a call fails, the board shows what this server knows: the last top
	it read (if any) with its own players' bests folded in. That is logged
	once. Studio never writes the store unless `Leaderboard.writeFromStudio`
	says so, because a playtest's debug keys (room jumps, granted cards) make
	runs that are not real.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local StoryProgress = require(ReplicatedStorage.Shared.Util.StoryProgress)

local log = Log.forTag("Leaderboard")

local StoryLeaderboard = {}

export type Entry = {
	userId: number,
	name: string,
	score: number,
}

type Row = {
	frame: Frame,
	rank: TextLabel,
	name: TextLabel,
	area: TextLabel,
	room: TextLabel,
}

type Board = {
	gui: SurfaceGui,
	rows: { Row },
	names: { [number]: string },
}

local started = false
--[[ Nil when there is no store to use: Studio without API access, or the
     store could not be opened. ]]
local store: OrderedDataStore? = nil
--[[ Whether this server writes the store (not Studio, unless allowed). ]]
local writes = false
local warned = false

--[[ Each player's best that this server knows of, by user id: recorded
     here, or read back from the store. ]]
local best: { [number]: number } = {}
local dirty: { [number]: boolean } = {}
local lastFlush: { [number]: number } = {}
local names: { [number]: string } = {}
--[[ Writes under way, which closing waits for. ]]
local inFlight = 0

--[[ The last top read from the store. ]]
local fetched: { Entry } = {}
local current: { Entry } = {}
local signature = ""
local boards: { Board } = {}

local function fallBack(reason: string)
	if warned then
		return
	end
	warned = true
	log.warn("the board shows this server's players only: %s", reason)
end

--[[ Studio with "Enable Studio Access to API Services" off fails every
     call the same way; there is no point trying again. ]]
local function noteFailure(err: any)
	local message = tostring(err)
	if
		string.find(message, "StudioAccessToApisNotAllowed", 1, true)
		or string.find(message, "API Services", 1, true)
	then
		store = nil
	end
	fallBack(message)
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(result) == "string" then
		names[userId] = result
		return result
	end
	return `#{userId}`
end

--[[ The store's top with this server's bests folded in, best first. Ties
     go to the lower user id, so the order is stable between redraws. ]]
local function merge(): { Entry }
	local scores: { [number]: number } = {}
	for _, entry in fetched do
		scores[entry.userId] = entry.score
	end
	for userId, score in best do
		if score > (scores[userId] or 0) then
			scores[userId] = score
		end
	end
	local list: { Entry } = {}
	for userId, score in scores do
		if score > 0 then
			table.insert(
				list,
				{ userId = userId, name = names[userId] or `#{userId}`, score = score }
			)
		end
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.userId < b.userId
	end)
	while #list > Leaderboard.rows do
		table.remove(list)
	end
	return list
end

local function medal(rank: number): Color3?
	local colors = Leaderboard.colors
	if rank == 1 then
		return colors.gold
	elseif rank == 2 then
		return colors.silver
	elseif rank == 3 then
		return colors.bronze
	end
	return nil
end

local function draw(board: Board)
	local colors = Leaderboard.colors
	for rank, row in board.rows do
		local entry = current[rank]
		row.rank.Text = `{rank}.`
		if entry then
			local d =
				StoryProgress.describe(entry.score, Balance.campaign, Balance.Stages, board.names)
			local color = medal(rank) or colors.text
			row.rank.TextColor3 = color
			row.name.TextColor3 = color
			row.name.Text = entry.name
			row.area.Text = d.area
			row.room.Text = `{d.room}/{d.total}`
		else
			row.rank.TextColor3 = colors.empty
			row.name.TextColor3 = colors.empty
			row.name.Text = Leaderboard.emptyName
			row.area.Text = ""
			row.room.Text = ""
		end
	end
end

--[[ Recomputes the top and redraws every board if it changed. ]]
local function refreshBoards()
	local top = merge()
	local parts = {}
	for _, entry in top do
		table.insert(parts, `{entry.userId}:{entry.score}:{entry.name}`)
	end
	local now = table.concat(parts, ",")
	if now == signature then
		return
	end
	signature = now
	current = top
	for index = #boards, 1, -1 do
		local board = boards[index]
		if board.gui.Parent then
			draw(board)
		else
			table.remove(boards, index)
		end
	end
end

--[[ Writes one player's best, keeping the larger of it and what is stored. ]]
local function flush(userId: number)
	dirty[userId] = nil
	lastFlush[userId] = os.clock()
	local value = best[userId]
	local target = store
	if not value or not target or not writes then
		return
	end
	local stored = 0
	inFlight += 1
	local ok, err = pcall(function()
		-- returning nil cancels the write, which the engine's type omits
		local keepMax: any = function(old: any): number?
			stored = if type(old) == "number" then old else 0
			if value <= stored then
				-- already as far or further: write nothing
				return nil
			end
			return value
		end
		target:UpdateAsync(tostring(userId), keepMax)
	end)
	inFlight -= 1
	if not ok then
		dirty[userId] = true
		noteFailure(err)
		return
	end
	-- the store knew of a better run (from another server): keep it
	if stored > (best[userId] or 0) then
		best[userId] = stored
	end
end

local function readTop()
	local target = store
	if not target then
		return
	end
	local ok, result = pcall(function()
		local pages = target:GetSortedAsync(false, Leaderboard.rows)
		return pages:GetCurrentPage()
	end)
	if not ok then
		noteFailure(result)
		return
	end
	local list: { Entry } = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		local score = tonumber(item.value)
		if userId and score then
			table.insert(list, { userId = userId, name = nameOf(userId), score = score })
		end
	end
	fetched = list
end

--[[ Opens the store and starts the write and read loops. Once. ]]
function StoryLeaderboard.start()
	if started then
		return
	end
	started = true

	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Leaderboard.storeName)
	end)
	if ok then
		store = result
	else
		noteFailure(result)
	end
	writes = not RunService:IsStudio() or Leaderboard.writeFromStudio
	if not writes then
		log.info("Studio: scores are kept in memory, not written to %s", Leaderboard.storeName)
	end

	-- writes: each dirty player at most every `flushEvery` seconds
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for userId in dirty do
				if now - (lastFlush[userId] or -math.huge) >= Leaderboard.flushEvery then
					task.spawn(flush, userId)
				end
			end
		end
	end)

	-- reads: the top, now and every `refreshEvery` seconds
	task.spawn(function()
		while true do
			readTop()
			refreshBoards()
			task.wait(Leaderboard.refreshEvery)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		if dirty[userId] then
			task.spawn(flush, userId)
		end
		lastFlush[userId] = nil
	end)

	--[[ Everything still dirty is written, and closing waits for every
	     write under way (those `PlayerRemoving` started too). ]]
	game:BindToClose(function()
		for userId in dirty do
			task.spawn(flush, userId)
		end
		local deadline = os.clock() + Leaderboard.closeWait
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

--[[ This player has reached `score` (`StoryProgress.score`). Only ever
     raises their best; a lower or missing score changes nothing. ]]
function StoryLeaderboard.record(player: Player, score: number?)
	if type(score) ~= "number" or score ~= score or score <= 0 then
		return
	end
	local value = math.floor(score)
	local userId = player.UserId
	names[userId] = player.Name
	if value <= (best[userId] or 0) then
		return
	end
	best[userId] = value
	dirty[userId] = true
	refreshBoards()
end

--[[ The board as it stands: up to `Leaderboard.rows` entries, best first. ]]
function StoryLeaderboard.top(): { Entry }
	return table.clone(current)
end

local function label(
	parent: Instance,
	x: number,
	width: number,
	align: Enum.TextXAlignment
): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(x, 0.12)
	text.Size = UDim2.fromScale(width, 0.76)
	text.Font = Enum.Font.Arcade
	text.TextScaled = true
	text.TextXAlignment = align
	text.TextColor3 = Leaderboard.colors.text
	text.Text = ""
	text.Parent = parent
	return text
end

--[[ Draws the board on `face`'s front: `Leaderboard.rows` rows of rank,
     name, area and room, kept up to date. `names` maps a stage index to
     its area's name (5 = "Mossy Glade", 4 = "Thornwood"). ]]
function StoryLeaderboard.attach(face: BasePart, areaNames: { [number]: string })
	local existing = face:FindFirstChild("FarthestAdventurers")
	if existing then
		existing:Destroy()
	end

	local colors = Leaderboard.colors
	local gui = Instance.new("SurfaceGui")
	gui.Name = "FarthestAdventurers"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = Leaderboard.pixelsPerStud
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local back = Instance.new("Frame")
	back.Name = "Board"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = colors.board
	back.BorderSizePixel = 0
	back.Parent = gui

	local count = Leaderboard.rows
	local pad = Leaderboard.padding
	local gap = Leaderboard.gap
	local height = (1 - pad * 2 - gap * (count - 1)) / count
	local columns = Leaderboard.columns
	local rows: { Row } = {}
	for rank = 1, count do
		local frame = Instance.new("Frame")
		frame.Name = `Row{rank}`
		frame.Position = UDim2.fromScale(pad, pad + (rank - 1) * (height + gap))
		frame.Size = UDim2.fromScale(1 - pad * 2, height)
		frame.BackgroundColor3 = colors.row
		frame.BorderSizePixel = 0
		frame.Parent = back
		local stroke = Instance.new("UIStroke")
		stroke.Color = colors.rowOutline
		stroke.Thickness = 2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame

		local x = 0.02
		local inner = 0.96
		local rankLabel = label(frame, x, columns.rank * inner, Enum.TextXAlignment.Left)
		x += columns.rank * inner
		local nameLabel = label(frame, x, columns.name * inner, Enum.TextXAlignment.Left)
		x += columns.name * inner
		local areaLabel = label(frame, x, columns.area * inner, Enum.TextXAlignment.Left)
		areaLabel.TextColor3 = colors.area
		x += columns.area * inner
		local roomLabel = label(frame, x, columns.room * inner, Enum.TextXAlignment.Right)
		roomLabel.TextColor3 = colors.room

		rows[rank] = {
			frame = frame,
			rank = rankLabel,
			name = nameLabel,
			area = areaLabel,
			room = roomLabel,
		}
	end

	local board: Board = { gui = gui, rows = rows, names = areaNames }
	table.insert(boards, board)
	draw(board)
	gui.Parent = face
end

return StoryLeaderboard
