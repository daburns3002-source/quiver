--!strict
--[[
	The story cutscene after BEGIN ADVENTURE (owner, 2026-10-25), drawn by
	`UI/StoryCutscene` and posed by `Util/StoryTimeline`: King Bloblin sits in
	the middle of Mossy Glade, his slime-covered chest behind him; a Slime
	Soldier brings him a WANTED poster (his face, his chest as the reward, the
	Ranger's, Arcanist's and Warden's icons signed under it); he gets mad and
	roars; the view pans to the three heroes, who react and run into the
	forest; black; then the run (no tutorial yet).

	Frame by frame: every picture is a Codex frame drawn from the owner's
	approved storyboard (`assets/concepts/blocky/ui/story/storyboard_b1.png`,
	`_b2.png`) by `assets/concepts/blocky/ui/story/frames.py`, its middle 16:9
	band cut into two halves under Roblox's 1024 px limit by
	`assets/ui/story/cut.py` and uploaded through Studio's MCP.

	The run holds until the black has held: the server keeps the player on the
	title (`RunSession.anyAtTitle`) until `Remotes.IntroBegin`, which now fires
	at the cutscene's end, not on the button. SKIP fades to black at once.
]]

local StoryTimeline = require(script.Parent.Parent.Util.StoryTimeline)

type Frame = StoryTimeline.Frame

local function frames(list: { { any } }): { Frame }
	local out = {}
	for _, pair in list do
		table.insert(out, { picture = pair[1] :: string, hold = pair[2] :: number })
	end
	return out
end

local Story = {
	--[[ The longest the black waits for the frames to load before the clock
	     starts anyway (seconds). ]]
	loadWait = 5,
	--[[ And the longest the clock holds on any one frame still loading. ]]
	stall = 2,
	--[[ Black under the title fading away (`Config/Intro.leave`), before the
	     first shot. ]]
	lead = 0.9,
	fadeOut = 1.2,
	blackHold = 0.8,
	skipFade = 0.4,
	--[[ SKIP shows after this long, so a double press on BEGIN ADVENTURE
	     cannot skip it by accident. ]]
	skipAt = 1.0,
	skip = "SKIP",

	--[[ Every frame's source size (the 16:9 band) and its halves: each half
	     `half` px wide, the right one from `rightFrom`. ]]
	picture = { width = 1536, height = 864, half = 772, rightFrom = 764 },

	--[[ Uploaded halves, by frame. ]]
	pictures = {
		f01 = { left = "rbxassetid://125170278545123", right = "rbxassetid://91156477263467" },
		f02a = { left = "rbxassetid://101547021081746", right = "rbxassetid://132913325476510" },
		f02b = { left = "rbxassetid://132286921012247", right = "rbxassetid://101606781974638" },
		f02c = { left = "rbxassetid://102287079229675", right = "rbxassetid://129632498701385" },
		f02d = { left = "rbxassetid://78961652037969", right = "rbxassetid://108680605904758" },
		f03a = { left = "rbxassetid://84721591279504", right = "rbxassetid://133985850692584" },
		f03b = { left = "rbxassetid://109011983255612", right = "rbxassetid://75670537465063" },
		f04a = { left = "rbxassetid://108425466358381", right = "rbxassetid://72388372180877" },
		f04b = { left = "rbxassetid://90467286703057", right = "rbxassetid://114470749953818" },
		f04c = { left = "rbxassetid://135712225372828", right = "rbxassetid://105861391477674" },
		f05a = { left = "rbxassetid://110046565155641", right = "rbxassetid://94495813419394" },
		f05b = { left = "rbxassetid://135073650322487", right = "rbxassetid://140228070030849" },
		f05c = { left = "rbxassetid://121621833750236", right = "rbxassetid://82832646887001" },
		f06a = { left = "rbxassetid://129325403476386", right = "rbxassetid://114632987290726" },
		f06b = { left = "rbxassetid://122839018943210", right = "rbxassetid://125435379985404" },
		f06c = { left = "rbxassetid://102988637504521", right = "rbxassetid://89483485745995" },
		f07a = { left = "rbxassetid://82096265582403", right = "rbxassetid://78944244231881" },
		f07b = { left = "rbxassetid://122307713267867", right = "rbxassetid://117070180051512" },
		f08a = { left = "rbxassetid://78134049531450", right = "rbxassetid://79935694281626" },
		f08b = { left = "rbxassetid://71629387928792", right = "rbxassetid://74767320126468" },
		f09 = { left = "rbxassetid://107763056656333", right = "rbxassetid://114792604463170" },
		f10a = { left = "rbxassetid://104803557003190", right = "rbxassetid://86295192774904" },
		f10b = { left = "rbxassetid://124508283903550", right = "rbxassetid://76921109325019" },
		f11 = { left = "rbxassetid://126885169982769", right = "rbxassetid://74408688229356" },
		f12a = { left = "rbxassetid://76466891335371", right = "rbxassetid://127847486047302" },
		f12b = { left = "rbxassetid://76500795975569", right = "rbxassetid://105635391948843" },
		f13a = { left = "rbxassetid://112507565948968", right = "rbxassetid://80898348212663" },
		f13b = { left = "rbxassetid://105542375688329", right = "rbxassetid://135919910827983" },
		f14a = { left = "rbxassetid://82239279752698", right = "rbxassetid://117544585739082" },
		f14b = { left = "rbxassetid://138650498158975", right = "rbxassetid://74175810301776" },
		f15a = { left = "rbxassetid://98319018567609", right = "rbxassetid://93028621417556" },
		f15b = { left = "rbxassetid://93991345096180", right = "rbxassetid://78260911206792" },
		f16a = { left = "rbxassetid://71824135046764", right = "rbxassetid://138816860440945" },
		f16b = { left = "rbxassetid://116376713188734", right = "rbxassetid://85115703032291" },
		f17a = { left = "rbxassetid://95346223206847", right = "rbxassetid://124112690031007" },
		f17b = { left = "rbxassetid://90551027014820", right = "rbxassetid://79825116630099" },
		f18a = { left = "rbxassetid://128023703645476", right = "rbxassetid://106296695867714" },
		f18b = { left = "rbxassetid://85976848586749", right = "rbxassetid://115898928165880" },
		f19 = { left = "rbxassetid://74535897109269", right = "rbxassetid://106884608705894" },
		f20a = { left = "rbxassetid://117769228163375", right = "rbxassetid://113710746117504" },
		f20b = { left = "rbxassetid://116384178104033", right = "rbxassetid://108601667956637" },
		f21a = { left = "rbxassetid://120320591600411", right = "rbxassetid://71961708207331" },
		f21b = { left = "rbxassetid://92346184971460", right = "rbxassetid://98966547257839" },
		f22a = { left = "rbxassetid://138015779853930", right = "rbxassetid://133733734553095" },
		f22b = { left = "rbxassetid://91225138490115", right = "rbxassetid://72213481969508" },
		f23a = { left = "rbxassetid://101185847274765", right = "rbxassetid://118400051838706" },
		f23b = { left = "rbxassetid://78415436353721", right = "rbxassetid://83414050617953" },
		f23c = { left = "rbxassetid://101855997114676", right = "rbxassetid://107388334134792" },
		f24 = { left = "rbxassetid://72643754561590", right = "rbxassetid://105737281641186" },
	} :: { [string]: { left: string, right: string } },

	--[[ Game sounds on beats (`Config/Sounds`), at seconds into a shot. ]]
	sounds = {
		{ shot = "Skid", at = 0, sound = "boss_king_goo" },
		{ shot = "Rise", at = 0.7, sound = "boss_king_chest_bump" },
		{ shot = "Roar", at = 0, sound = "boss_king_bounce_slam" },
		{ shot = "Shockwave", at = 0, sound = "boss_king_bounce_launch" },
	},

	shots = {
		{
			name = "Sky",
			length = 2.6,
			frames = frames({ { "f01", 2.6 } }),
			zoom = { from = 1, to = 1.15 },
			fadeIn = 0.8,
		},
		{
			name = "Glade",
			length = 2.6,
			frames = frames({ { "f02a", 0.5 }, { "f02b", 0.5 } }),
			loop = true,
			zoom = { from = 1, to = 1.08 },
		},
		{
			name = "Chest",
			length = 2.6,
			frames = frames({ { "f02c", 0.35 }, { "f02d", 0.35 } }),
			loop = true,
			zoom = { from = 1.08, to = 1 },
		},
		{
			name = "Lounge",
			length = 2.4,
			frames = frames({ { "f03a", 0.8 }, { "f03b", 0.8 } }),
			loop = true,
		},
		{
			name = "Yawn",
			length = 2.65,
			frames = frames({ { "f04b", 0.4 }, { "f04a", 0.9 }, { "f04c", 1.35 } }),
		},
		{
			name = "Bushes",
			length = 2.3,
			frames = frames({
				{ "f05a", 0.7 },
				{ "f05b", 0.25 },
				{ "f05a", 0.2 },
				{ "f05b", 0.25 },
				{ "f05c", 0.9 },
			}),
		},
		{
			name = "Run",
			length = 1.0,
			frames = frames({ { "f06a", 0.33 }, { "f06b", 0.33 }, { "f06c", 0.34 } }),
		},
		{
			name = "Skid",
			length = 1.5,
			frames = frames({ { "f07a", 0.5 }, { "f07b", 1.0 } }),
		},
		{
			name = "Offer",
			length = 1.8,
			frames = frames({ { "f08a", 0.9 }, { "f08b", 0.9 } }),
		},
		{
			name = "Take",
			length = 1.0,
			frames = frames({ { "f09", 1.0 } }),
		},
		{
			name = "Unroll",
			length = 1.6,
			frames = frames({ { "f10a", 0.6 }, { "f10b", 1.0 } }),
		},
		{
			name = "Poster",
			length = 2.8,
			frames = frames({ { "f11", 2.8 } }),
			zoom = { from = 1, to = 1.05 },
		},
		{
			name = "Eyes",
			length = 1.7,
			frames = frames({ { "f12a", 0.7 }, { "f12b", 1.0 } }),
			shake = { at = 0.7, time = 0.3, size = 0.006 },
		},
		{
			name = "Steam",
			length = 1.8,
			frames = frames({ { "f13a", 0.18 }, { "f13b", 0.18 } }),
			loop = true,
			shake = { at = 0, time = 1.8, size = 0.005 },
		},
		{
			name = "Crumple",
			length = 1.5,
			frames = frames({ { "f14a", 0.5 }, { "f14b", 1.0 } }),
		},
		{
			name = "Rise",
			length = 1.7,
			frames = frames({ { "f15a", 0.7 }, { "f15b", 1.0 } }),
			shake = { at = 0.7, time = 0.4, size = 0.012 },
		},
		{
			name = "Breath",
			length = 1.4,
			frames = frames({ { "f16a", 0.6 }, { "f16b", 0.8 } }),
			zoom = { from = 1, to = 1.06 },
		},
		{
			name = "Roar",
			length = 2.0,
			frames = frames({ { "f17a", 0.12 }, { "f17b", 0.12 } }),
			loop = true,
			shake = { at = 0, time = 2.0, size = 0.03 },
		},
		{
			name = "Shockwave",
			length = 1.6,
			frames = frames({ { "f18a", 0.6 }, { "f18b", 1.0 } }),
			shake = { at = 0, time = 1.2, size = 0.015 },
		},
		{
			--[[ The pan to the heroes: across the forest panorama, pushed in so
			     a window of it travels from the glade to the heroes. ]]
			name = "Pan",
			length = 3.0,
			frames = frames({ { "f19", 3.0 } }),
			zoom = { from = 1.6, to = 1.6 },
			pan = { from = 0, to = 1 },
		},
		{
			name = "Startled",
			length = 1.8,
			frames = frames({ { "f20a", 0.6 }, { "f20b", 1.2 } }),
		},
		{
			name = "Faces",
			length = 2.0,
			frames = frames({ { "f21a", 1.0 }, { "f21b", 1.0 } }),
		},
		{
			name = "Ready",
			length = 2.0,
			frames = frames({ { "f22a", 0.8 }, { "f22b", 1.2 } }),
		},
		{
			name = "Away",
			length = 1.05,
			frames = frames({ { "f23a", 0.35 }, { "f23b", 0.35 }, { "f23c", 0.35 } }),
		},
		{
			name = "Gone",
			length = 1.8,
			frames = frames({ { "f24", 1.8 } }),
			zoom = { from = 1, to = 1.06 },
		},
	} :: { StoryTimeline.Shot },
}

return table.freeze(Story)
