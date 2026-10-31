--!strict
--[[
	The DEEPEST DELVERS board: each player's best Endless floor
	(`SaveSchema.endlessBest`), kept in one OrderedDataStore
	(`Config/Leaderboard.endlessStoreName`, key `tostring(userId)`, value the
	floor), and the top ten drawn on a part in the lobby.

	Written the same way as the FARTHEST ADVENTURERS board
	(`Run/StoryLeaderboard`, `docs/LEADERBOARD.md`), and for the same
	reasons, so the two read alike:

	- The server decides every floor (non-negotiable 2). `RoomController`
	  records one as a floor is cleared; **nothing a client sends reaches
	  this module** — the floor is what the board and the milestones pay on,
	  so a client that could claim a floor could claim a Mythic.
	- A value can only ever go **up**: `UpdateAsync` keeps the larger of
	  what is stored and what is offered, and writes nothing when the stored
	  one is already as large (non-negotiable 7). That is also why it needs
	  no session lock — `max` gives the same answer in any order and however
	  often it is repeated, two servers recording the same player can only
	  both raise it, and the key holds nothing else. The player save is a
	  different store with its own lock and schema; this one is not it.
	- Writes are budgeted: a best is kept in memory, marked dirty when it
	  improves, and written at most every `flushEvery` seconds per player,
	  when they leave, and as the server closes. The top is read every
	  `refreshEvery` seconds.
	- Every DataStore call is in a pcall. In Studio without API access, or
	  when a call fails, the board shows what this server knows, logged once.
	  Studio never writes unless `Leaderboard.writeFromStudio` says so.

	It is a **separate store** from the story's rather than a column added to
	it, because its score means something else: the story board's value is a
	place in `Balance.campaign`, which moves whenever an area is inserted,
	and a floor never does. Nothing here needs rewriting when the campaign
	grows.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.forTag("Leaderboard")

local EndlessLeaderboard = {}

export type Entry = {
	userId: number,
	name: string,
	floor: number,
}

type Row = {
	frame: Frame,
	rank: TextLabel,
	name: TextLabel,
	floor: TextLabel,
}

local started = false
--[[ Nil when there is no store to use: Studio without API access, or the
     store could not be opened. ]]
local store: OrderedDataStore? = nil
--[[ Whether this server writes the store (not Studio, unless allowed). ]]
local writes = false
local warned = false

local best: { [number]: number } = {}
local dirty: { [number]: boolean } = {}
local lastFlush: { [number]: number } = {}
local names: { [number]: string } = {}
--[[ Writes under way, which closing waits for. ]]
local inFlight = 0

local fetched: { Entry } = {}
local current: { Entry } = {}
local signature = ""
local boards: { { gui: SurfaceGui, rows: { Row } } } = {}

local function fallBack(reason: string)
	if warned then
		return
	end
	warned = true
	log.warn("the Endless board shows this server's players only: %s", reason)
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

--[[ The store's top with this server's bests folded in, deepest first.
     Ties go to the lower user id, so the order is stable between
     redraws. ]]
local function merge(): { Entry }
	local floors: { [number]: number } = {}
	for _, entry in fetched do
		floors[entry.userId] = entry.floor
	end
	for userId, floor in best do
		if floor > (floors[userId] or 0) then
			floors[userId] = floor
		end
	end
	local list: { Entry } = {}
	for userId, floor in floors do
		if floor > 0 then
			table.insert(
				list,
				{ userId = userId, name = names[userId] or `#{userId}`, floor = floor }
			)
		end
	end
	table.sort(list, function(a, b)
		if a.floor ~= b.floor then
			return a.floor > b.floor
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

local function draw(board: { gui: SurfaceGui, rows: { Row } })
	local colors = Leaderboard.colors
	for rank, row in board.rows do
		local entry = current[rank]
		row.rank.Text = `{rank}.`
		if entry then
			local color = medal(rank) or colors.text
			row.rank.TextColor3 = color
			row.name.TextColor3 = color
			row.name.Text = entry.name
			row.floor.Text = `FLOOR {entry.floor}`
		else
			row.rank.TextColor3 = colors.empty
			row.name.TextColor3 = colors.empty
			row.name.Text = Leaderboard.emptyName
			row.floor.Text = ""
		end
	end
end

--[[ Recomputes the top and redraws every board if it changed. ]]
local function refreshBoards()
	local top = merge()
	local parts = {}
	for _, entry in top do
		table.insert(parts, `{entry.userId}:{entry.floor}:{entry.name}`)
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

--[[ Writes one player's best, keeping the deeper of it and what is
     stored. ]]
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
				-- already as deep or deeper: write nothing
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
	-- the store knew of a deeper run (from another server): keep it
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
		local floor = tonumber(item.value)
		if userId and floor then
			table.insert(list, { userId = userId, name = nameOf(userId), floor = floor })
		end
	end
	fetched = list
end

--[[ Opens the store and starts the write and read loops. Once. ]]
function EndlessLeaderboard.start()
	if started then
		return
	end
	started = true

	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Leaderboard.endlessStoreName)
	end)
	if ok then
		store = result
	else
		noteFailure(result)
	end
	writes = not RunService:IsStudio() or Leaderboard.writeFromStudio
	if not writes then
		log.info(
			"Studio: Endless floors are kept in memory, not written to %s",
			Leaderboard.endlessStoreName
		)
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

	local function load(player: Player)
		local userId = player.UserId
		if not store then
			return
		end
		local loaded, stored = pcall(function(): any
			return (store :: OrderedDataStore):GetAsync(tostring(userId))
		end)
		if not loaded then
			noteFailure(stored)
		elseif type(stored) == "number" and stored > (best[userId] or 0) then
			best[userId] = stored
		end
	end
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

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

--[[ This player has reached `floor`. Only ever raises their best; a
     shallower floor, a fraction, or one past the hard cap changes nothing
     (the cap keeps the board bounded, `docs/ENDLESS.md`). ]]
function EndlessLeaderboard.record(player: Player, floor: number)
	if type(floor) ~= "number" or floor ~= floor then
		return
	end
	local value = math.floor(floor)
	if value <= 0 or value > Balance.Endless.maxFloor then
		return
	end
	local userId = player.UserId
	names[userId] = player.Name
	if value <= (best[userId] or 0) then
		return
	end
	best[userId] = value
	dirty[userId] = true
	refreshBoards()
end

--[[ The board as it stands: up to `Leaderboard.rows` entries, deepest
     first. ]]
function EndlessLeaderboard.top(): { Entry }
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
     name and floor, kept up to date. ]]
function EndlessLeaderboard.attach(face: BasePart)
	local existing = face:FindFirstChild("DeepestDelvers")
	if existing then
		existing:Destroy()
	end

	local colors = Leaderboard.colors
	local gui = Instance.new("SurfaceGui")
	gui.Name = "DeepestDelvers"
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
	local columns = Leaderboard.endlessColumns
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
		local floorLabel = label(frame, x, columns.floor * inner, Enum.TextXAlignment.Right)
		floorLabel.TextColor3 = colors.area

		rows[rank] = {
			frame = frame,
			rank = rankLabel,
			name = nameLabel,
			floor = floorLabel,
		}
	end

	local board = { gui = gui, rows = rows }
	table.insert(boards, board)
	draw(board)
	gui.Parent = face
end

return EndlessLeaderboard
