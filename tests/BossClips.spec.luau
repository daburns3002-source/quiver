--!strict
--[[
	King Bloblin's clips on the beats of his moves (`Balance` boss `clips`,
	`BossMoves.clip`, played by `Fx/ModelAnimator`) and his lash chain
	stretched to its lane (`BossMoves.chainScale`).

	What is pinned: every phase plays a clip his rig has, in the order the
	design draws the fight; each clip's run of phases lasts as long as the
	clip was drawn (so the beats line up without being sped up); only the
	resting loops repeat; and the chain, played from the clip data through
	the same fit and build the game uses, puts the fist at the lane's end
	for every length a lane can be.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossMoves = require(ServerScriptService.Server.Enemies.BossMoves)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local EnemyModel = require(ServerScriptService.Server.Enemies.EnemyModel)
local ModelClip = require(ReplicatedStorage.Shared.Util.ModelClip)
local TestRunner = require(script.Parent.TestRunner)

local config = Balance.Enemies.SlimeKing :: Balance.EnemyConfig
local boss = config.boss :: Balance.EnemyBoss
local imported = (EnemyDesigns.Imported :: any).SlimeKing :: EnemyDesigns.ImportedDesign
local data = (require :: any)(
		ReplicatedStorage.Shared.Config.ModelClips[imported.clips]
	) :: ModelClip.Model

local FRAME = 1 / 60

local function identity(point: Vector3): Vector3
	return point
end

type Run = { clip: string, at: number, span: number }

--[[ Plays a move to its end and returns each clip as it began. `grabFirst`
     catches the player on the first lash. ]]
local function clips(kind: BossMoves.Kind, target: Vector3, grabFirst: boolean): { Run }
	local move = BossMoves.start(kind, 0, Vector3.zero, 0)
	local runs: { Run } = {}
	local grabbed = false
	local now = 0
	for _ = 1, 100000 do
		now += FRAME
		local _, events, done = BossMoves.step(move, boss, now, target, identity)
		if done then
			return runs
		end
		for _, e in events do
			if grabFirst and not grabbed and e.kind == "LaneHit" then
				grabbed = true
				BossMoves.grab(move, boss, now, target, identity)
			end
		end
		local clip, at, span = BossMoves.clip(move, boss)
		local last = runs[#runs]
		if not last or last.clip ~= clip or last.at ~= at then
			table.insert(runs, { clip = clip, at = at, span = span })
		end
	end
	error("the move never ended")
end

local function names(runs: { Run }): string
	local out = {}
	for _, run in runs do
		table.insert(out, run.clip)
	end
	return table.concat(out, " ")
end

--[[ Where LashFist sits `time` into `clip`, as studs ahead of his feet,
     with the chain stretched by `stretch`: the design built as the game
     builds it, fitted as the client fits it, posed as the client poses it. ]]
local function fistReach(clip: string, time: number, stretch: number): number
	local parts = EnemyModel.designFor(config) :: { EnemyDesigns.DesignPart }
	local observed: { [string]: { position: Vector3, size: Vector3 } } = {}
	local count: { [string]: number } = {}
	for _, part in parts do
		count[part.name] = (count[part.name] or 0) + 1
	end
	local fist: EnemyDesigns.DesignPart? = nil
	for _, part in parts do
		if count[part.name] == 1 and data.parts[part.name] then
			observed[part.name] = { position = part.offset, size = part.size }
		end
		if part.name == "LashFist" and not fist then
			fist = part
		end
	end
	local fit = ModelClip.fit(data, observed)
	assert(fit and fist, "no fit or no fist")
	local stretches: ModelClip.Stretch = {}
	local keep = imported.stretch
	if keep then
		stretches[keep.joint] = Vector3.new(1, 1, stretch)
		for _, name in keep.keep do
			stretches[name] = Vector3.new(1, 1, 1 / stretch)
		end
	end
	local deltas =
		ModelClip.deltas(data, data.clips[clip], time, ModelClip.restInverse(data), stretches)
	local placed =
		ModelClip.place(EnemyModel.localCFrame(fist), deltas[data.parts.LashFist.joint], fit)
	-- forward is -Z; his feet are under the hitbox's centre
	return -placed.Position.Z
end

return function(t: TestRunner.Helper)
	local clipsConfig = boss.clips
	t.notNil(clipsConfig, "the Slime King has no clips")

	t.test("every phase plays a clip his rig has", function()
		for _, arm in boss.lash.arms do
			t.notNil((clipsConfig :: any).Lash[arm], `no clips for {arm}`)
		end
		local all = {}
		for _, runs in
			{
				clips("Bounce", Vector3.new(10, 0, 0), false),
				clips("Lash", Vector3.new(0, 0, -12), false),
				clips("Lash", Vector3.new(0, 0, -12), true),
			}
		do
			for _, run in runs do
				table.insert(all, run)
			end
		end
		for _, run in all do
			t.notNil(data.clips[run.clip], `{run.clip} is not one of his clips`)
		end
		t.notNil(data.clips[(clipsConfig :: any).idle], "no idle clip")
	end)

	t.test("the bounce plays wind-up, launch, air and land three times, then winded", function()
		local beat = "Bounce_Windup Bounce_Launch Bounce_Air Bounce_Land"
		local expected = table.concat(table.create(boss.bounce.bounces, beat), " ") .. " Winded"
		t.equal(names(clips("Bounce", Vector3.new(10, 0, 0), false)), expected)
	end)

	t.test("a lash winds, strikes, holds and retracts, the right arm then the left", function()
		t.equal(
			names(clips("Lash", Vector3.new(0, 0, -12), false)),
			"Lash_Wind_R Lash_Strike Lash_Hold Lash_Retract "
				.. "Lash_Wind_L Lash_Strike_L Lash_Hold_L Lash_Retract_L"
		)
	end)

	--[[ The server pulls the moment the fist lands on someone (the grab is
	     resolved as the slap begins), so a hit goes from the strike
	     straight to the pull; only a miss holds the fist on the floor. ]]
	t.test("a lash that grabs pulls, chest-bumps and recovers", function()
		t.equal(
			names(clips("Lash", Vector3.new(0, 0, -12), true)),
			"Lash_Wind_R Lash_Strike Lash_Pull Lash_ChestBump Lash_Recover "
				.. "Lash_Wind_L Lash_Strike_L Lash_Hold_L Lash_Retract_L"
		)
	end)

	--[[ The clips were drawn at the fight's own timing: a clip played over
	     its phases needs no speeding up. A retuned timing still plays (the
	     client paces the clip to its span), but should be redrawn. ]]
	t.test("each clip lasts as long as the phases it plays over", function()
		for _, runs in
			{
				clips("Bounce", Vector3.new(10, 0, 0), false),
				clips("Lash", Vector3.new(0, 0, -12), true),
			}
		do
			for _, run in runs do
				local clip = data.clips[run.clip]
				if clip and clip.loops == false then
					t.near(run.span, clip.length, 0.05, `{run.clip} spans {run.span}`)
				end
			end
		end
	end)

	t.test("only his resting loops repeat; every beat holds its last frame", function()
		for name, clip in data.clips do
			local loops = clip.loops ~= false
			local resting = name == "Idle" or name == "Winded" or name == "Move" or name == "Attack"
			t.equal(loops, resting, `{name} loops = {loops}`)
		end
		local land = data.clips.Bounce_Land
		t.near(ModelClip.clipTime(land, land.length * 3), land.length, 1e-9)
		t.near(
			ModelClip.clipTime(data.clips.Idle, data.clips.Idle.length * 1.5),
			data.clips.Idle.length * 0.5,
			1e-6
		)
	end)

	t.test("a longer lane stretches the chain further, never past full", function()
		local l = boss.lash
		local last = 0
		for length = l.minReach, l.reach, 2 do
			local stretch = BossMoves.chainScale(length, l)
			t.isTrue(stretch > last, "a longer lane did not stretch the chain further")
			t.isTrue(stretch <= 1 + 1e-9, "a lane within reach over-stretched the chain")
			last = stretch
		end
		t.near(BossMoves.chainScale(l.reach, l), 1, 1e-9)
	end)

	--[[ Played from the data as the game plays it: the fist lands at the
	     lane's end, never past it and no further short of it than a stud
	     and a quarter, for every length a lane can be. ]]
	t.test("the fist lands at the lane's end, however long the lane", function()
		local l = boss.lash
		local hold = data.clips.Lash_Hold
		for _, clip in { "Lash_Hold", "Lash_Hold_L" } do
			for _, length in { l.minReach, 10, 14, l.reach } do
				local stretch = BossMoves.chainScale(length, l)
				for _, share in { 0, 0.5, 1 } do
					local reach = fistReach(clip, hold.length * share, stretch)
					t.isTrue(
						reach <= length + 0.25 and reach >= length - 1.25,
						`{clip} at {share} of the hold, lane {length}: fist {reach}`
					)
				end
			end
		end
	end)

	t.test("his chain rests tucked away, too small to see", function()
		for _, part in EnemyModel.designFor(config) :: { EnemyDesigns.DesignPart } do
			if string.match(part.name, "^Lash") then
				local size = part.restSize or part.size
				t.isTrue(size.Magnitude < 0.05, `{part.name} rests {size} big`)
			end
		end
	end)
end
