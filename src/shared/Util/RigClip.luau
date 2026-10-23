--!strict
--[[
	Plays a rigged enemy's clips (`Config/EnemyRigs`): each bone's
	Transform at any time, Linear between baked keys, as the owner's
	KeyframeSequences ease them; and where a lunge's dash is, fitted to
	the server's timings. Pure, so `tests/RigClip.spec` can pin both;
	`Fx/EnemyRig` draws them.
]]

local EnemyRigs = require(script.Parent.Parent.Config.EnemyRigs)

local RigClip = {}

local function transform(v: { number }, scale: number): CFrame
	return CFrame.new(v[1] * scale, v[2] * scale, v[3] * scale, v[4], v[5], v[6], v[7])
end

--[[ Each bone's Transform `time` seconds into `clip`, its moves shrunk by
     `scale` with the body. A looping clip wraps; one that does not holds
     its ends. ]]
function RigClip.sample(clip: EnemyRigs.Clip, time: number, scale: number): { [string]: CFrame }
	local times = clip.times
	local t = if clip.loop and clip.length > 0
		then time % clip.length
		else math.clamp(time, 0, clip.length)
	local i = 1
	while i < #times - 1 and t > times[i + 1] do
		i += 1
	end
	local span = times[i + 1] - times[i]
	local u = if span > 0 then math.clamp((t - times[i]) / span, 0, 1) else 0
	local out: { [string]: CFrame } = {}
	for bone, keys in clip.bones do
		out[bone] = transform(keys[i], scale):Lerp(transform(keys[i + 1], scale), u)
	end
	return out
end

--[[
	Where a dash is in its clip. The crouch runs from the start to its
	`Launch` marker over the lunge's wind-up (`windup` seconds, of which
	`sinceStart` have passed); once launched (`sinceLaunch`, nil until the
	server clears the wind-up) the leap runs to `Land` over the bolt's
	`travel` seconds, and the skid after it at the clip's own pace.
]]
function RigClip.dashTime(
	clip: EnemyRigs.Clip,
	windup: number,
	travel: number,
	sinceStart: number,
	sinceLaunch: number?
): number
	local launch = clip.markers.Launch or 0
	local land = clip.markers.Land or clip.length
	if sinceLaunch == nil then
		return launch * math.clamp(sinceStart / math.max(windup, 1e-3), 0, 1)
	end
	if sinceLaunch < travel then
		return launch + (land - launch) * (sinceLaunch / math.max(travel, 1e-3))
	end
	return math.min(clip.length, land + (sinceLaunch - travel))
end

return RigClip
