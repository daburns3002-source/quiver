--!strict
--[[
	The like goal (`Config/Codes.likeGoal`, `Util/CodeRules.likeGoal`; owner,
	2026-11-20: "there should be a like goal for new codes"). A code in
	`Data/CodeList` with `likes` works once the game has that many likes.

	**Where the count comes from.** A game server cannot read its own likes:
	Roblox's votes endpoint (games.roblox.com/v1/games/votes) takes only a
	signed-in user's cookie, and HttpService may not call roblox.com. Only
	third-party proxies can, and we do not send anything through those. So
	the owner sets the count: the ConfigService key `likes` (Creator Hub,
	the experience's Configs page), which reaches running servers within
	minutes with no republish. Missing, or not a number, is 0: no like-goal
	code works and the box shows the first goal.

	What the CODES box shows is put on Workspace's attributes: `LikeGoalNext`
	(the next goal, nil when none is left) and `LikeGoalCode` (the newest
	code reached, nil before the first). A code reached is public by design;
	a goal not reached keeps its word on the server. When a goal is reached
	on a running server, everyone there hears the new code on the rewards'
	toast.
]]

local ConfigService = game:GetService("ConfigService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CodeRules = require(ReplicatedStorage.Shared.Util.CodeRules)
local Config = require(ReplicatedStorage.Shared.Config.Codes)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local RewardRules = require(ReplicatedStorage.Shared.Util.RewardRules)

local CodeList = require(script.Parent.CodeList)
local Rewards = require(script.Parent.Rewards)

local log = Log.forTag("LikeGoal")

local LikeGoal = {}

LikeGoal.NEXT = "LikeGoalNext"
LikeGoal.CODE = "LikeGoalCode"

--[[ Seconds between looks at the goal for a code that has expired. ]]
local RECHECK = 600

local likes = 0

--[[ The game's likes, as the owner last set them. ]]
function LikeGoal.count(): number
	return likes
end

--[[ The goal at `count` likes onto Workspace's attributes. Unless `quiet`,
     a goal just reached is said to everyone in the server. ]]
function LikeGoal.set(count: number, quiet: boolean?)
	local today = RewardRules.day(os.time())
	local _, before = CodeRules.likeGoal(CodeList, likes, today)
	likes = count
	local nextGoal, newest = CodeRules.likeGoal(CodeList, likes, today)
	Workspace:SetAttribute(LikeGoal.NEXT, nextGoal)
	Workspace:SetAttribute(LikeGoal.CODE, newest)
	if newest and newest ~= before and not quiet then
		local line = string.format(Config.likeGoal.toast, newest)
		for _, player in Players:GetPlayers() do
			Rewards.say(player, line)
		end
		log.info("like goal reached at %d likes", likes)
	end
end

local function read(snapshot: ConfigSnapshot): number
	local ok, value = pcall(function()
		return snapshot:GetValue(Config.likeGoal.key)
	end)
	if ok and type(value) == "number" and value == value and value >= 0 then
		return math.floor(value)
	end
	return 0
end

function LikeGoal.start()
	LikeGoal.set(0, true)
	task.spawn(function()
		local ok, snapshot = pcall(function()
			return ConfigService:GetConfigAsync()
		end)
		if ok and snapshot then
			LikeGoal.set(read(snapshot), true)
			snapshot.UpdateAvailable:Connect(function()
				snapshot:Refresh()
				LikeGoal.set(read(snapshot))
			end)
		else
			log.warn("no configs, so the like goal counts 0: %s", tostring(snapshot))
		end
		while true do
			task.wait(RECHECK)
			LikeGoal.set(likes, true)
		end
	end)
end

return LikeGoal
