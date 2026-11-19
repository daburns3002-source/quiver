--!strict
--[[
	The weekly Endless tournament (owner, 2026-11-18): each player's best
	Endless floor this week, the THIS WEEK'S DELVERS board in the lobby
	beside DEEPEST DELVERS, and the week's prizes, paid on the next join
	once the week is over. Rules in `Util/TournamentRules`, numbers in
	`Config/Tournament`, the store in `docs/LEADERBOARD.md`.

	Built like `Run/EndlessLeaderboard`, and for the same reasons:

	- **Server-decided.** `RoomController` records a floor as it is
	  cleared, with the seconds since the run began; nothing a client sends
	  reaches `record` (the Studio-only debug remote aside).
	- **One OrderedDataStore, a scope a week** (`Tournament.storeName`, the
	  week's Monday). The value is `TournamentRules.score`: deeper wins, and
	  on one floor the faster run. It only ever goes up: `UpdateAsync` keeps
	  the larger and **writes nothing** when the stored one is already as
	  good, and a best is marked for writing only when it improves, at most
	  every `Leaderboard.flushEvery` seconds per player.
	- **The week rolls over by itself** at Monday 00:00 UTC: the board
	  empties, the countdown starts again, and what this server knew of the
	  old week is kept to place its players.
	- **Prizes are the save's.** Each week a player sets a best in is noted
	  in their save (`SaveSchema.tournamentWeeks`); once the week is over
	  and `Tournament.grace` has passed, it is paid and taken out in one
	  step (`Wallet.payTournament`), so a week pays once. The place comes
	  from one read of that week's top 100; if the store cannot be read,
	  the week waits and is tried again, never paid a guessed place.
	- **Studio** never writes the store (`Leaderboard.writeFromStudio`), and
	  without API access places from what it knows. Its clock can be moved
	  on (`Remotes.DebugTournament`), so a rollover can be watched.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BoardRank = require(ReplicatedStorage.Shared.Util.BoardRank)
local Leaderboard = require(ReplicatedStorage.Shared.Config.Leaderboard)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Tournament = require(ReplicatedStorage.Shared.Config.Tournament)
local TournamentRules = require(ReplicatedStorage.Shared.Util.TournamentRules)

local BoardYou = require(script.Parent.BoardYou)
local Inbound = require(script.Parent.Parent.Net.Inbound)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Wallet = require(script.Parent.Parent.Data.Wallet)

local log = Log.forTag("Tournament")

local WeeklyTournament = {}

export type Entry = {
	userId: number,
	name: string,
	score: number,
}

type Row = {
	rank: TextLabel,
	name: TextLabel,
	floor: TextLabel,
	time: TextLabel,
}

type Board = { gui: SurfaceGui, rows: { Row }, countdown: TextLabel }

local started = false
--[[ No store calls at all: Studio without API access. ]]
local apiOff = false
local writes = false
local warned = false
--[[ Studio's fake clock: seconds added to the real one. ]]
local shift = 0

local stores: { [number]: OrderedDataStore } = {}
local week = 0
--[[ This week's bests, by user id. ]]
local best: { [number]: number } = {}
--[[ Weeks that are over: what this server held of each, to place its
     players (some of it perhaps never written). The last two are kept. ]]
local known: { [number]: { [number]: number } } = {}
--[[ Bests to write, by "week:userId". ]]
local dirty: { [string]: { week: number, userId: number } } = {}
local lastFlush: { [number]: number } = {}
local names: { [number]: string } = {}
local inFlight = 0

local fetched: { Entry } = {}
local current: { Entry } = {}
local signature = ""
local boards: { Board } = {}
local shownCountdown = ""

--[[ Reads of weeks that are over, once each. ]]
local finals: { [number]: { BoardRank.Scored } } = {}
local paying: { [Player]: boolean } = {}
--[[ When a week last failed to pay, by "userId:week". ]]
local failedAt: { [string]: number } = {}

local prizeEvent = Remotes.event(Remotes.TournamentPrize)

local function now(): number
	return os.time() + shift
end

local function fallBack(reason: string)
	if warned then
		return
	end
	warned = true
	log.warn("the weekly board shows this server's players only: %s", reason)
end

local function noteFailure(err: any)
	local message = tostring(err)
	if
		string.find(message, "StudioAccessToApisNotAllowed", 1, true)
		or string.find(message, "API Services", 1, true)
	then
		apiOff = true
	end
	fallBack(message)
end

--[[ The store of week `w`, or nil with none to use. ]]
local function storeFor(w: number): OrderedDataStore?
	if apiOff then
		return nil
	end
	local open = stores[w]
	if open then
		return open
	end
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore(Tournament.storeName, TournamentRules.scope(w))
	end)
	if not ok then
		noteFailure(result)
		return nil
	end
	stores[w] = result
	return result
end

local function nameOf(userId: number): string
	local found = names[userId]
	if found then
		return found
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.Name
		return player.Name
	end
	if userId <= 0 then
		return `#{userId}`
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

--[[ The store's top with this server's bests folded in, best first; ties
     to the lower user id, so the order holds still between redraws. ]]
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
		table.insert(list, { userId = userId, name = names[userId] or `#{userId}`, score = score })
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		return a.userId < b.userId
	end)
	return list
end

local function describe(score: number): string
	return `FLOOR {TournamentRules.floorOf(score)}  {TournamentRules.clock(
		TournamentRules.tenthsOf(score)
	)}`
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
	local place = 0
	for rank, row in board.rows do
		local entry = current[rank]
		if entry then
			-- a tie shares the better place
			local above = current[rank - 1]
			if not above or above.score ~= entry.score then
				place = rank
			end
			local color = medal(place) or colors.text
			row.rank.Text = `{place}.`
			row.rank.TextColor3 = color
			row.name.TextColor3 = color
			row.name.Text = entry.name
			row.floor.Text = `FLOOR {TournamentRules.floorOf(entry.score)}`
			row.time.Text = TournamentRules.clock(TournamentRules.tenthsOf(entry.score))
		else
			row.rank.Text = `{rank}.`
			row.rank.TextColor3 = colors.empty
			row.name.TextColor3 = colors.empty
			row.name.Text = Leaderboard.emptyName
			row.floor.Text = ""
			row.time.Text = ""
		end
	end
	board.countdown.Text = shownCountdown
end

local function eachBoard(action: (Board) -> ())
	for index = #boards, 1, -1 do
		local board = boards[index]
		if board.gui.Parent then
			action(board)
		else
			table.remove(boards, index)
		end
	end
end

local function refreshBoards()
	local all = merge()
	local scored: { BoardRank.Scored } = {}
	for _, entry in all do
		table.insert(scored, { userId = entry.userId, score = entry.score })
	end
	local read: { BoardRank.Scored } = {}
	for _, entry in fetched do
		table.insert(read, { userId = entry.userId, score = entry.score })
	end
	BoardYou.publish("Weekly", scored, BoardRank.cutoff(read, Leaderboard.rankDepth), describe)
	local top = table.move(all, 1, math.min(#all, Leaderboard.rows), 1, {})
	local parts = {}
	for _, entry in top do
		table.insert(parts, `{entry.userId}:{entry.score}:{entry.name}`)
	end
	local drawn = table.concat(parts, ",")
	if drawn == signature then
		return
	end
	signature = drawn
	current = top
	eachBoard(draw)
end

local function tickCountdown()
	local words = TournamentRules.countdown(TournamentRules.resetsIn(now()))
	if words == shownCountdown then
		return
	end
	shownCountdown = words
	eachBoard(function(board)
		board.countdown.Text = words
	end)
end

--[[ Writes one best, keeping the better of it and what is stored, and
     writing nothing when the stored one is as good. ]]
local function flush(key: string)
	local entry = dirty[key]
	if not entry then
		return
	end
	dirty[key] = nil
	lastFlush[entry.userId] = os.clock()
	local value = if entry.week == week
		then best[entry.userId]
		else (known[entry.week] or {})[entry.userId]
	local target = storeFor(entry.week)
	if not value or not target or not writes then
		return
	end
	local stored = 0
	inFlight += 1
	local ok, err = pcall(function()
		local keepBetter: any = function(old: any): number?
			stored = if TournamentRules.valid(old) then old else 0
			if value <= stored then
				return nil
			end
			return value
		end
		target:UpdateAsync(tostring(entry.userId), keepBetter)
	end)
	inFlight -= 1
	if not ok then
		dirty[key] = entry
		noteFailure(err)
		return
	end
	if entry.week == week and stored > (best[entry.userId] or 0) then
		best[entry.userId] = stored
	end
end

local function readTop()
	local w = week
	local target = storeFor(w)
	if not target then
		return
	end
	local ok, result = pcall(function()
		return target:GetSortedAsync(false, Leaderboard.rankDepth):GetCurrentPage()
	end)
	if not ok then
		noteFailure(result)
		return
	end
	local list: { Entry } = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		if userId and TournamentRules.valid(item.value) then
			local name = if #list < Leaderboard.rows
				then nameOf(userId)
				else names[userId] or `#{userId}`
			table.insert(list, { userId = userId, name = name, score = item.value })
		end
	end
	-- the week turned while the read was out: it belongs to the old one
	if w == week then
		fetched = list
	end
end

--[[ The week has turned: the board starts empty, and the old week's
     bests are kept to place this server's players when it pays. ]]
local function roll(to: number)
	log.info("week %s is over; %s begins", TournamentRules.scope(week), TournamentRules.scope(to))
	known[week] = best
	known[week - 2] = nil
	best = {}
	fetched = {}
	week = to
	signature = "-"
	refreshBoards()
	eachBoard(draw)
end

local function checkWeek()
	local w = TournamentRules.week(now())
	if w ~= week then
		roll(w)
	end
end

--[[ The store's top `rankDepth` of a week that is over, read once; nil
     when it could not be read (then the week waits). With no store at all
     (Studio without API access) it is empty, and places come from what
     this server knows. ]]
local function finalRead(w: number): { BoardRank.Scored }?
	local cached = finals[w]
	if cached then
		return cached
	end
	if apiOff then
		return {}
	end
	local target = storeFor(w)
	if not target then
		return nil
	end
	local ok, result = pcall(function()
		return target:GetSortedAsync(false, Leaderboard.rankDepth):GetCurrentPage()
	end)
	if not ok then
		noteFailure(result)
		return if apiOff then {} else nil
	end
	local list: { BoardRank.Scored } = {}
	for _, item in result :: { any } do
		local userId = tonumber(item.key)
		if userId and TournamentRules.valid(item.value) then
			table.insert(list, { userId = userId, score = item.value })
		end
	end
	finals[w] = list
	return list
end

local payWeeks: (player: Player, due: { number }) -> number

--[[ Pays every week of this player's that is over and past its grace;
     returns how many it paid. ]]
local function payDue(player: Player): number
	if paying[player] then
		return 0
	end
	local profile = PlayerData.get(player)
	if not profile then
		return 0
	end
	local due = TournamentRules.due(profile.tournamentWeeks, now())
	if #due == 0 then
		return 0
	end
	paying[player] = true
	local ok, result = pcall(payWeeks, player, due)
	paying[player] = nil
	if not ok then
		log.warn("paying %s's weeks failed: %s", player.Name, tostring(result))
		return 0
	end
	return result
end

--[[ Pays each of `due`, the weeks of this player's that are over, as
     `payDue` found them. ]]
function payWeeks(player: Player, due: { number }): number
	local paid = 0
	for _, w in due do
		local key = `{player.UserId}:{w}`
		local last = failedAt[key]
		if last and os.clock() - last < Tournament.retryEvery then
			continue
		end
		local read = finalRead(w)
		-- the read yields: the player may have gone, or the week been paid
		local still = PlayerData.get(player)
		local saved = if still then still.tournamentWeeks[tostring(w)] else nil
		if not read then
			failedAt[key] = os.clock()
			log.warn(
				"week %s waits to pay %s: the store could not be read",
				TournamentRules.scope(w),
				player.Name
			)
			continue
		end
		if not saved then
			continue
		end
		failedAt[key] = nil
		local place, score =
			TournamentRules.final(read, Leaderboard.rankDepth, known[w] or {}, player.UserId, saved)
		local prize = TournamentRules.prize(place, TournamentRules.floorOf(score))
		if Wallet.payTournament(player, w, prize) then
			paid += 1
			log.info(
				"week %s pays %s: place %s, floor %d (%d gems, %d coins, %d Soulstones%s)",
				TournamentRules.scope(w),
				player.Name,
				if place then tostring(place) else "100+",
				prize.floor,
				prize.gems,
				prize.coins,
				prize.soulstones,
				if prize.champion then ", the title" else ""
			)
			prizeEvent:FireClient(player, TournamentRules.scope(w), {
				place = prize.place,
				placeName = prize.placeName,
				floor = prize.floor,
				time = TournamentRules.clock(TournamentRules.tenthsOf(score)),
				gems = prize.gems,
				coins = prize.coins,
				soulstones = prize.soulstones,
				champion = prize.champion,
				picks = prize.picks,
			})
		end
	end
	return paid
end

--[[ A joined player's best this week (their save has it) and title. ]]
local function welcome(player: Player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	names[player.UserId] = player.Name
	player:SetAttribute(Tournament.winsAttribute, profile.tournamentWins)
	Wallet.settleTournamentPicks(player)
	local saved = profile.tournamentWeeks[tostring(week)]
	if saved and saved > (best[player.UserId] or 0) then
		best[player.UserId] = saved
	end
	refreshBoards()
	task.spawn(function()
		--[[ Set weapon picks left from an earlier week, offered again (a
		     week paid now offers its own on its panel). ]]
		local mine = PlayerData.get(player)
		if payDue(player) == 0 and mine and mine.tournamentPicks > 0 then
			prizeEvent:FireClient(player, nil, { owed = mine.tournamentPicks })
		end
	end)
end

local function debugHandler(player: Player, action: unknown, a: unknown, b: unknown)
	local n = if type(a) == "number" and a == a then a else nil
	if action == "shift" then
		shift += if n then math.floor(n) else TournamentRules.resetsIn(now()) + Tournament.grace + 1
		log.info(
			"Studio: the tournament's clock is now %s (shifted %d s)",
			os.date("!%c", now()),
			shift
		)
		checkWeek()
		tickCountdown()
		for _, someone in Players:GetPlayers() do
			task.spawn(payDue, someone)
		end
	elseif action == "floor" and n then
		WeeklyTournament.record(player, n, if type(b) == "number" and b == b then b else 60)
	elseif action == "rival" then
		for i = 1, math.clamp(if n then math.floor(n) else 9, 1, 120) do
			local id = -i
			names[id] = `RIVAL {i}`
			best[id] = TournamentRules.score(math.random(1, 60), math.random(60, 3600))
		end
		refreshBoards()
	end
end

--[[ Opens this week's store and starts the loops. Once. ]]
function WeeklyTournament.start()
	if started then
		return
	end
	started = true
	week = TournamentRules.week(now())
	writes = not RunService:IsStudio() or Leaderboard.writeFromStudio
	if not writes then
		log.info(
			"Studio: weekly floors are kept in memory, not written to %s",
			Tournament.storeName
		)
	end
	storeFor(week)
	tickCountdown()

	-- every second: the week, the countdown, writes due; every five, prizes due
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(1)
			beat += 1
			checkWeek()
			tickCountdown()
			local clock = os.clock()
			for key, entry in dirty do
				if clock - (lastFlush[entry.userId] or -math.huge) >= Leaderboard.flushEvery then
					task.spawn(flush, key)
				end
			end
			if beat % 5 == 0 then
				for _, player in Players:GetPlayers() do
					task.spawn(payDue, player)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			readTop()
			refreshBoards()
			task.wait(Leaderboard.refreshEvery)
		end
	end)

	PlayerData.onLoaded(welcome)

	Players.PlayerRemoving:Connect(function(player)
		local userId = player.UserId
		for key, entry in dirty do
			if entry.userId == userId then
				task.spawn(flush, key)
			end
		end
		lastFlush[userId] = nil
		paying[player] = nil
	end)

	game:BindToClose(function()
		for key in dirty do
			task.spawn(flush, key)
		end
		local deadline = os.clock() + Leaderboard.closeWait
		while inFlight > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)

	-- a top-ten week's set weapon picks: the player's ask, the server's check
	Inbound.on(Remotes.TournamentPick, function(player, weapon)
		Wallet.pickTournamentWeapon(player, weapon)
	end)

	if RunService:IsStudio() then
		Inbound.debug(Remotes.DebugTournament, debugHandler)
	end
end

--[[ This player has cleared `floor`, `seconds` into the run. Only a
     better score than this week's best changes anything: a floor that is
     not whole, or past the hard cap, never does. ]]
function WeeklyTournament.record(player: Player, floor: number, seconds: number)
	if type(floor) ~= "number" or floor ~= math.floor(floor) or type(seconds) ~= "number" then
		return
	end
	if floor < 1 or floor > Balance.Endless.maxFloor or seconds ~= seconds then
		return
	end
	checkWeek()
	local userId = player.UserId
	local score = TournamentRules.score(floor, seconds)
	names[userId] = player.Name
	if score <= (best[userId] or 0) then
		return
	end
	best[userId] = score
	dirty[`{week}:{userId}`] = { week = week, userId = userId }
	Wallet.noteTournament(player, week, score)
	refreshBoards()
end

--[[ The board as it stands, best first. ]]
function WeeklyTournament.top(): { Entry }
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
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextXAlignment = align
	text.TextColor3 = Leaderboard.colors.text
	text.Text = ""
	text.Parent = parent
	return text
end

--[[ Draws the board on `face`'s front: the heading and the countdown,
     `Leaderboard.rows` rows of rank, name, floor and time, and the YOU
     row, kept up to date. ]]
function WeeklyTournament.attach(face: BasePart)
	local existing = face:FindFirstChild("ThisWeek")
	if existing then
		existing:Destroy()
	end
	local colors = Leaderboard.colors
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ThisWeek"
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
	-- the heading, the rows, then the YOU row (`Run/BoardYou`)
	local height = (1 - pad * 2 - gap * (count + 1)) / (count + 2)

	local head = Instance.new("Frame")
	head.Name = "Heading"
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromScale(pad, pad)
	head.Size = UDim2.fromScale(1 - pad * 2, height)
	head.Parent = back
	local title = label(head, 0.02, 0.56, Enum.TextXAlignment.Left)
	title.Name = "Title"
	title.Text = Tournament.heading
	title.TextColor3 = Tournament.colors.heading
	local countdown = label(head, 0.58, 0.4, Enum.TextXAlignment.Right)
	countdown.Name = "Countdown"
	countdown.TextColor3 = Tournament.colors.countdown

	local columns = Tournament.columns
	local rows: { Row } = {}
	for rank = 1, count do
		local frame = Instance.new("Frame")
		frame.Name = `Row{rank}`
		frame.Position = UDim2.fromScale(pad, pad + rank * (height + gap))
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
		x += columns.floor * inner
		local timeLabel = label(frame, x, columns.time * inner, Enum.TextXAlignment.Right)
		timeLabel.TextColor3 = Tournament.colors.time
		rows[rank] = { rank = rankLabel, name = nameLabel, floor = floorLabel, time = timeLabel }
	end

	BoardYou.row(back, "Weekly", pad + (count + 1) * (height + gap), height)
	local board: Board = { gui = gui, rows = rows, countdown = countdown }
	table.insert(boards, board)
	draw(board)
	refreshBoards()
	gui.Parent = face
end

return WeeklyTournament
