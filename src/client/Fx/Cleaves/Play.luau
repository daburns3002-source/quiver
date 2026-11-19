--!strict
--[[
	Plays the blade cleaves (owner, 2026-11-19, direction A: each blade's
	own streak on the ground, today's red cleave remade per blade; the
	swing itself, its box and its timing unchanged).

	`Fx/SwingTrail` hands over each blow as it starts: the blow's real
	shape (`SwingBox.shape`, grown by the cards), which way it sweeps and
	how long the blade takes. That becomes a live cleave with its own
	clock, drawn every frame by its blade's style (`Fx/Cleaves/Styles`,
	the Blade Cleaves page's code) and laid on the ground by
	`Fx/Cleaves/Painter`, from where the swinger stood, facing the way it
	faced, until its card's life is over. Blows overlap as on the cards:
	the last one's motes still falling as the next sweeps.

	A weaker device draws fewer segments and motes (`detail`). The clocks
	stand still while the run does (`RunPaused`).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Canvas = require(script.Parent.Canvas)
local Device = require(script.Parent.Parent.Parent.Device)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Painter = require(script.Parent.Painter)
local RunPaused = require(script.Parent.Parent.Parent.RunPaused)
local Styles = require(script.Parent.Styles)
local WeaponFx = require(ReplicatedStorage.Shared.Config.WeaponFx)

local log = Log.forTag("BladeCleaves")

local Play = {}

type Live = {
	I: Canvas.Inst,
	W: Canvas.Look,
	style: Styles.Style,
	origin: CFrame,
	s: number,
	t: number,
	life: number,
}

local live: { Live } = {}
local connection: RBXScriptConnection? = nil
local broken: { [string]: boolean } = {}

local function detail(): number
	local name = Device.tier().name
	return if name == "High" then 1 elseif name == "Medium" then 0.7 else 0.45
end

--[[ Whether `key` cuts its own cleave yet (its batch is ported). ]]
function Play.has(key: string): boolean
	local cleave = WeaponFx.cleaves[key]
	return Styles[key] ~= nil and cleave ~= nil and cleave.look ~= nil and not broken[key]
end

local function step(dt: number)
	if not RunPaused.get() then
		for _, cleave in live do
			cleave.t += dt
		end
	end
	local share = detail()
	Painter.begin(share)
	local keep: { Live } = {}
	--[[ Newest first, so a crowded moment drops the old cleave's last
	     motes and never the fresh swing; it is drawn over the older. ]]
	for index = #live, 1, -1 do
		local cleave = live[index]
		if cleave.t > cleave.life then
			continue
		end
		local c = Canvas.new(cleave.s, share)
		local ok, err = pcall(function()
			Canvas.run(cleave.style, c, cleave.I, cleave.t, cleave.W, cleave.life)
		end)
		if not ok then
			-- one broken drawing never stops the rest: it falls back to the ribbon
			broken[cleave.W.key] = true
			log.warn("%s's cleave failed: %s", cleave.W.key, tostring(err))
			continue
		end
		Painter.paint(c.items, cleave.origin, Canvas.PX, Canvas.PY, cleave.s, index * 0.06)
		table.insert(keep, 1, cleave)
	end
	Painter.finish()
	live = keep
	if #live == 0 and connection then
		connection:Disconnect()
		connection = nil
		Painter.begin(share)
		Painter.finish()
	end
end

--[[ Starts a blow's cleave. `origin` is the swinger's spot at the
     streak's height, facing the swing; `window` the blade's sweep in
     seconds; `glow` whether the blade is a Legendary or Mythic. ]]
function Play.start(
	key: string,
	shape: Canvas.Shape,
	sweep: string,
	origin: CFrame,
	window: number,
	glow: boolean
)
	local cleave = WeaponFx.cleaves[key]
	local look = cleave and cleave.look
	local style = Styles[key]
	if not (look and style) then
		return
	end
	local I, life = Canvas.inst(look.kind, shape, sweep, window, look.card, look.linger)
	local g = Canvas.GEO[look.kind] or Canvas.GEO.sword
	if #live == 0 then
		Painter.warm(math.floor(160 * detail()))
	end
	table.insert(live, {
		I = I,
		W = Canvas.look(key, look.colours, glow),
		style = style,
		origin = origin,
		s = g.s,
		t = 0,
		life = life,
	})
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return Play
