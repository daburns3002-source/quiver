--!strict
--[[
	Lobby parties (owner, 2026-11-19: "make co-op work from the PLAY button
	too", then "have there be a party system where you can invite someone in
	the server"; `docs/COOP.md`, "Parties"). The rules are
	`Shared/Util/PartyRules`; this keeps the server's one state and talks to
	the players.

	- **Invites** (`Remotes.PartyInvite`, `PartyAsked`, `PartyAnswer`) go
	  only between players in this server who are free in its lobby
	  (`free`): arrived, off the title, not choosing a class, not on their
	  way to a run, and never on a run server. Nothing the client sends is
	  more than a user id the server looks up and checks.
	- **What the clients see** is set on each Player: `PartyLeader` (the
	  leader's user id, on every member) and `PartyInviting` (the user id of
	  the one player they have an invite out to). Lines to show come as
	  `Remotes.PartyNews`.
	- **A run's start** (`Run/Party.start`) asks `plan` who goes, then
	  `depart` tells whoever stays behind why, and takes a member who goes
	  without the whole party out of it.
	- **The round trip**: a party that travels whole is written into the
	  teleport's data (`groups`), to the run server and from it back to a
	  lobby (`groups`), and forms again where it lands once every member is
	  there and each one's data names the same party (`PartyRules.regroup`,
	  within `PartyRules.regroupSeconds`).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local PartyRules = require(ReplicatedStorage.Shared.Util.PartyRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local RoomController = require(script.Parent.RoomController)
local RunSession = require(script.Parent.RunSession)

local log = Log.forTag("Parties")

local Parties = {}

--[[ On every member of a party: the leader's user id. ]]
Parties.LEADER = "PartyLeader"
--[[ On a player with an invite out: the user id it is to. ]]
Parties.INVITING = "PartyInviting"

local state = PartyRules.new()
--[[ Parties read from arriving players' teleport data, by user id, and
     when each arrived. ]]
local claims: { [number]: PartyRules.Party } = {}
local claimedAt: { [number]: number } = {}
--[[ Players on their way to a run: they are not free, and are not told
     about a party they are leaving with. ]]
local travelling: { [number]: boolean } = {}
local runServer = false

local asked = Remotes.event(Remotes.PartyAsked)
local newsEvent = Remotes.event(Remotes.PartyNews)

local function nameOf(id: number): string
	local player = Players:GetPlayerByUserId(id)
	return if player then player.DisplayName else "SOMEONE"
end

--[[ Shows `player` the words for `what`, about `name`. ]]
local function news(player: Player?, what: string, name: string?)
	if not player or not player.Parent or travelling[player.UserId] then
		return
	end
	local words = PartyRules.say(what, name)
	if words then
		newsEvent:FireClient(player, words)
	end
end

local function newsTo(id: number, what: string, name: string?)
	news(Players:GetPlayerByUserId(id), what, name)
end

--[[ Writes what every client sees onto the Players. ]]
local function publish()
	for _, player in Players:GetPlayers() do
		local party = PartyRules.partyOf(state, player.UserId)
		local out = PartyRules.outgoing(state, player.UserId)
		local leader = if party then party.leader else nil
		if player:GetAttribute(Parties.LEADER) ~= leader then
			player:SetAttribute(Parties.LEADER, leader)
		end
		local to = if out then out.to else nil
		if player:GetAttribute(Parties.INVITING) ~= to then
			player:SetAttribute(Parties.INVITING, to)
		end
	end
end

--[[ Whether `player` is free in this lobby to be asked, to ask, or to
     join. ]]
function Parties.free(player: Player): boolean
	local session = RunSession.get(player)
	return not runServer
		and RoomController.inLobby()
		and session ~= nil
		and not session.atTitle
		and session.character ~= nil
		and player:GetAttribute(RunSession.ARRIVED) == true
		and player:GetAttribute("ClassSelecting") ~= true
		and not travelling[player.UserId]
end

--[[ Tells everyone whose invite went, and the rest of a party someone
     left. ]]
local function tidy()
	for _, gone in PartyRules.tidy(state, os.clock()) do
		local invite = gone.invite
		local to = Players:GetPlayerByUserId(invite.to)
		if to then
			asked:FireClient(to, invite.from, 0)
		end
		if gone.why == "EXPIRED" then
			newsTo(invite.from, "EXPIRED", nameOf(invite.to))
		end
	end
end

local function toldLeft(party: PartyRules.Party?, over: boolean, leaverName: string, leader: number)
	if not party then
		return
	end
	for _, id in party.members do
		newsTo(id, if over then "OVER" else "LEFT", leaverName)
		if not over and party.leader ~= leader then
			newsTo(id, "LEADS", nameOf(party.leader))
		end
	end
end

--[[ Takes `id` out of their party and tells the others. ]]
local function leave(id: number, leaverName: string)
	local before = PartyRules.partyOf(state, id)
	local leader = if before then before.leader else id
	local party, over = PartyRules.leave(state, id)
	toldLeft(party, over, leaverName, leader)
end

local function onInvite(player: Player, target: unknown)
	if type(target) ~= "number" or target ~= math.floor(target) then
		return
	end
	local other = Players:GetPlayerByUserId(target)
	if not other or other == player or not Parties.free(player) then
		return
	end
	if not Parties.free(other) then
		news(player, "AWAY", other.DisplayName)
		return
	end
	local why = PartyRules.invite(state, player.UserId, other.UserId, os.clock())
	if why then
		news(player, why, other.DisplayName)
		return
	end
	asked:FireClient(other, player.UserId, PartyRules.inviteSeconds)
	news(player, "SENT", other.DisplayName)
	publish()
end

local function onAnswer(player: Player, from: unknown, accept: unknown)
	if type(from) ~= "number" then
		return
	end
	-- joining needs this player free in the lobby; a NO is always taken
	local yes = accept == true and Parties.free(player)
	local outcome = PartyRules.answer(state, player.UserId, from, yes, os.clock())
	local sender = Players:GetPlayerByUserId(from)
	if outcome == "JOINED" then
		news(player, "YOU_JOINED", nameOf(from))
		news(sender, "JOINED_YOU", player.DisplayName)
		log.info("%s joined %s's party", player.Name, nameOf(from))
	elseif outcome == "DECLINED" then
		news(sender, "DECLINED", player.DisplayName)
	elseif outcome == "EXPIRED" then
		news(sender, "EXPIRED", player.DisplayName)
	elseif outcome ~= "GONE" then
		-- the sender's party can no longer take them
		news(player, "CANT_JOIN", nameOf(from))
	end
	tidy()
	publish()
end

local function onLeave(player: Player)
	if not PartyRules.partyOf(state, player.UserId) then
		return
	end
	leave(player.UserId, player.DisplayName)
	news(player, "YOU_LEFT")
	tidy()
	publish()
end

local function onAdded(player: Player)
	local ok, data = pcall(function()
		return player:GetJoinData().TeleportData
	end)
	local claim = if ok then PartyRules.claim(data, player.UserId) else nil
	if claim then
		claims[player.UserId] = claim
		claimedAt[player.UserId] = os.clock()
	end
end

local function onRemoving(player: Player)
	local id = player.UserId
	local before = PartyRules.partyOf(state, id)
	local leader = if before then before.leader else id
	local party, over, taken = PartyRules.drop(state, id)
	toldLeft(party, over, player.DisplayName, leader)
	for _, invite in taken do
		if invite.from == id then
			local to = Players:GetPlayerByUserId(invite.to)
			if to then
				asked:FireClient(to, id, 0)
			end
		end
	end
	claims[id] = nil
	claimedAt[id] = nil
	travelling[id] = nil
	tidy()
	publish()
end

--[[ Parties travelling back from a run, formed once all are here. ]]
local function regroup()
	local now = os.clock()
	for id, at in claimedAt do
		if now - at > PartyRules.regroupSeconds then
			claims[id] = nil
			claimedAt[id] = nil
		end
	end
	if not next(claims) then
		return
	end
	local formed = PartyRules.regroup(state, claims, function(id)
		return Players:GetPlayerByUserId(id) ~= nil
	end)
	for _, party in formed do
		for _, id in party.members do
			claimedAt[id] = nil
			newsTo(id, "BACK")
		end
		log.info("party of %d formed again, led by %s", #party.members, nameOf(party.leader))
	end
	if #formed > 0 then
		publish()
	end
end

--[[ Who goes when `starter` starts a run (`PartyRules.plan`). ]]
function Parties.plan(
	starter: Player,
	standing: { number },
	why: (number) -> string?
): PartyRules.Plan
	return PartyRules.plan(state, starter.UserId, standing, why)
end

--[[ The run `plan` describes is leaving: whoever stays behind is told why,
     a member going without the whole party leaves it, and the ones going
     are marked travelling until `stay` (a failed teleport) or they leave. ]]
function Parties.depart(starter: Player, plan: PartyRules.Plan)
	for _, stays in plan.left do
		newsTo(stays.id, stays.why, starter.DisplayName)
	end
	if plan.quits then
		local party = PartyRules.partyOf(state, starter.UserId)
		local party2, over = PartyRules.leave(state, starter.UserId)
		if party2 then
			for _, id in party2.members do
				newsTo(id, "QUIT", starter.DisplayName)
				if not over and party and party2.leader ~= party.leader then
					newsTo(id, "LEADS", nameOf(party2.leader))
				end
			end
		end
	end
	for _, id in plan.going do
		travelling[id] = true
	end
	tidy()
	publish()
end

--[[ A teleport that failed: they are back in the lobby. ]]
function Parties.stay(members: { Player })
	for _, member in members do
		travelling[member.UserId] = nil
	end
end

--[[ Every party here, as a teleport carries it back to a lobby. ]]
function Parties.groups(): { PartyRules.Party }
	local list = {}
	for _, party in state.parties do
		table.insert(list, PartyRules.carry(party))
	end
	return list
end

function Parties.init(isRunServer: boolean)
	runServer = isRunServer
	Inbound.on(Remotes.PartyInvite, onInvite)
	Inbound.on(Remotes.PartyAnswer, onAnswer)
	Inbound.on(Remotes.PartyLeave, onLeave)
	for _, player in Players:GetPlayers() do
		onAdded(player)
	end
	Players.PlayerAdded:Connect(onAdded)
	Players.PlayerRemoving:Connect(onRemoving)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, problem = pcall(function()
				tidy()
				regroup()
				publish()
			end)
			if not ok then
				log.warn("party step failed: %s", tostring(problem))
			end
		end
	end)
end

return Parties
