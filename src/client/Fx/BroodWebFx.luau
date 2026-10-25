--!strict
--[[
	The Broodmother's web (owner, 2026-10-25: "make the web with codex and
	then have another design agent create it"): her lash drawn as silk.
	The strand is the Claude Design pieces in `assets/models/effects/
	fx_brood_web_*.glb`, played through `UpgradeFx`'s pools:

	- `strand`: on a `WebLane` telegraph, segments of silk (each one
	  `FxBroodWebStrand`, laid end to end) shoot down the lane as her strike
	  lands, hold, then reel back in, with the glowing glob
	  (`FxBroodWebTip`) on the end;
	- `splat`: on a `WebSplat`, the flat web (`FxBroodWebSplat`) where the
	  glob hit the floor, spreading out and fading.

	Timing is the boss's lash (`Balance` Broodmother `boss.lash`): the lane
	telegraph lasts until the strike lands, the strand flies over `strike`,
	is held over `hold` and reels in over `retract`. Until the pieces are
	imported, nothing is drawn: the red lane stays the tell.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local UpgradeFx = require(script.Parent.Upgrades.UpgradeFx)

local BroodWebFx = {}

--[[ The pieces are about a stud (the strand segment one long), drawn this
     many times bigger in the room. ]]
local SCALE = 2
--[[ Studs a segment covers at `SCALE`, and the height of the strand over
     the floor (her spinnerets). ]]
local SEGMENT = 1 * SCALE
local HEIGHT = 1.6

local function lash(): Balance.BossLash
	local config = (Balance.Enemies :: any).Broodmother :: Balance.EnemyConfig
	return (config.boss :: Balance.EnemyBoss).lash
end

--[[ How far the strand reaches `t` seconds after it is thrown: out over
     the strike, held, then back in. ]]
local function reach(t: number, length: number, l: Balance.BossLash): number
	if t < l.strike then
		return length * t / l.strike
	elseif t < l.strike + l.hold then
		return length
	end
	return length * math.max(0, 1 - (t - l.strike - l.hold) / l.retract)
end

function BroodWebFx.strand(origin: Vector3, direction: Vector3, delay: number, length: number)
	if not UpgradeFx.ready("FxBroodWebStrand") then
		return
	end
	local l = lash()
	local ahead = UpgradeFx.flat(direction)
	local start = UpgradeFx.floor(origin, HEIGHT)
	local life = l.strike + l.hold + l.retract
	local count = math.max(1, math.ceil(length / SEGMENT))
	task.delay(math.max(0, delay - l.strike), function()
		for i = 0, count - 1 do
			UpgradeFx.play("FxBroodWebStrand", {
				at = CFrame.lookAt(start, start + ahead),
				life = life,
				scale = SCALE,
				clip = "Wiggle",
				motion = function(model: Model, t: number)
					--[[ Each segment rides out to its place on the strand,
					     the last one butting up to the glob. ]]
					local out = reach(t, length, l)
					local along = math.max(0, math.min(i * SEGMENT, out - SEGMENT))
					local at = start + ahead * along
					model:PivotTo(CFrame.lookAt(at, at + ahead))
				end,
			})
		end
		UpgradeFx.play("FxBroodWebTip", {
			at = CFrame.lookAt(start, start + ahead),
			life = life,
			scale = SCALE,
			clip = "Pulse",
			motion = function(model: Model, t: number)
				local at = start + ahead * reach(t, length, l)
				model:PivotTo(CFrame.lookAt(at, at + ahead))
			end,
		})
	end)
end

function BroodWebFx.splat(origin: Vector3, direction: Vector3, duration: number, radius: number)
	--[[ The piece is three studs across; drawn to the splat's width. ]]
	local model = UpgradeFx.play("FxBroodWebSplat", {
		at = CFrame.lookAt(
			UpgradeFx.floor(origin),
			UpgradeFx.floor(origin) + UpgradeFx.flat(direction)
		),
		life = duration + 0.4,
		scale = math.max(1, radius * 2 / 3),
		clip = "Spread",
	})
	if model then
		task.delay(duration, function()
			UpgradeFx.clip(model, "Fade")
		end)
	end
end

return BroodWebFx
