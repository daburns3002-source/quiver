--!strict
--[[
	The CODES box on the server (`Config/Codes`, `Util/CodeRules`, the list
	in `Data/CodeList`): the client sends what was typed, this decides.

	- `Remotes.CodeRedeem(text)`: read as a code word, checked against the
	  server's list, the player's used codes and today's date; a good one is
	  marked used and saved first, then paid (coins and gems here, eggs and
	  crates as a quest chest's are, `Rewards.givePrize`, which shows what
	  came out). Answers `CodeAnswer(ok, words)`.

	Its own rate limit on top of `Net/Inbound`'s: `Config/Codes.tries`, so
	nobody can guess codes faster than four a minute. The typed text is never
	logged or said back, only whether it was a code.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CodeRules = require(ReplicatedStorage.Shared.Util.CodeRules)
local Config = require(ReplicatedStorage.Shared.Config.Codes)
local Inbound = require(script.Parent.Parent.Net.Inbound)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Throttle = require(ReplicatedStorage.Shared.Util.Throttle)

local CodeList = require(script.Parent.CodeList)
local PlayerData = require(script.Parent.PlayerData)
local Rewards = require(script.Parent.Rewards)
local Wallet = require(script.Parent.Wallet)

local log = Log.forTag("Codes")

local Codes = {}

local answer = Remotes.event(Remotes.CodeAnswer)
local buckets: { [Player]: Throttle.Bucket } = {}

local function tryAllowed(player: Player): boolean
	local now = os.clock()
	local tries = Config.tries
	local bucket = buckets[player]
	if not bucket then
		bucket = Throttle.new(tries.burst, now)
		buckets[player] = bucket
	end
	return Throttle.take(bucket, now, 1 / tries.every, tries.burst)
end

--[[ Redeems `text` for `player`: the result and the words to show. Its own
     function so the in-Roblox spec can drive it without a remote. ]]
function Codes.redeem(
	player: Player,
	text: unknown,
	list: { [string]: CodeRules.Code }?
): (string, string)
	local profile = PlayerData.get(player)
	if not profile then
		return "Unknown", CodeRules.answer("Unknown")
	end
	local word = CodeRules.normalise(text)
	if not word then
		local result = if type(text) == "string" and not string.find(text, "%S")
			then "Empty"
			else "Unknown"
		return result, CodeRules.answer(result)
	end
	local result, code =
		CodeRules.check(list or CodeList, profile.codesUsed, word, Rewards.today(player))
	if result ~= "Ok" or not code then
		log.info("%s tried a code: %s", player.Name, result)
		return result, CodeRules.answer(result)
	end
	-- marked and saved before anything is given, so it can never pay twice
	profile.codesUsed[word] = true
	PlayerData.touch(player)
	local prize = code.prize
	Wallet.addCoins(player, prize.coins or 0)
	Wallet.addGems(player, prize.gems or 0)
	local eggs, crates = prize.eggs or 0, prize.crates or 0
	local give = Rewards.givePrize
	if give and eggs + crates > 0 then
		give(player, eggs, crates)
	end
	Wallet.send(player)
	log.info("%s redeemed a code: %s", player.Name, CodeRules.prizeWords(prize))
	return "Ok", CodeRules.answer("Ok", prize)
end

local function onRedeem(player: Player, text: unknown)
	if not tryAllowed(player) then
		answer:FireClient(player, false, CodeRules.answer("Slow"))
		return
	end
	local result, words = Codes.redeem(player, text)
	answer:FireClient(player, result == "Ok", words)
end

function Codes.start()
	Inbound.on(Remotes.CodeRedeem, onRedeem)
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Codes
