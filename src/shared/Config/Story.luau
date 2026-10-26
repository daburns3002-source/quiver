--!strict
--[[
	The story cutscene after BEGIN ADVENTURE (owner, 2026-10-25), drawn by
	`UI/StoryCutscene` and timed by `Util/StoryTimeline`: King Bloblin sits in
	the middle of Mossy Glade, his slime-covered chest behind him; a Slime
	Soldier brings him a WANTED poster (WANTED: his icon, REWARD: the chest icon,
	the Ranger's, Arcanist's and Warden's icons signed under it); he gets mad and
	roars; the heroes react and run into the forest; black; then the lobby (no
	tutorial yet).

	One frame at a time (owner, 2026-10-25: "stop changing the frames and adding
	effects. it should be one frame at a time"): each frame shows once, whole,
	for its `hold`, then cuts to the next. No zoom, pan, shake, fade or looping.
	Every picture is a Codex frame drawn from the owner's approved storyboard
	(`assets/concepts/blocky/ui/story/storyboard_b1.png`, `_b2.png`) by
	`assets/concepts/blocky/ui/story/frames.py`, its middle 16:9 band cut into
	two halves under Roblox's 1024 px limit by `assets/ui/story/cut.py` and
	uploaded through Studio's MCP.

	The run holds until the black at the end has held: the server keeps the
	player on the title (`RunSession.anyAtTitle`) until `Remotes.IntroBegin`,
	which fires at the cutscene's end, not on the button. SKIP cuts to black.
]]

local StoryTimeline = require(script.Parent.Parent.Util.StoryTimeline)

local Story = {
	--[[ The longest the black waits for the frames to load before the clock
	     starts anyway (seconds). They load while the title is up
	     (`StoryCutscene.preload`), and one not in by its turn never shows:
	     the frame before it stays up, and the clock and music run on. ]]
	loadWait = 5,
	--[[ Black before the first frame (under the title fading away,
	     `Config/Intro.leave`), and after the last before the run is let go. ]]
	lead = 0.9,
	blackHold = 0.8,
	--[[ SKIP shows after this long, so a double press on BEGIN ADVENTURE
	     cannot skip it by accident. ]]
	skipAt = 1.0,
	skip = "SKIP",

	--[[ Every frame's source size (the 16:9 band) and its halves: each half
	     `half` px wide, the right one from `rightFrom`. ]]
	picture = { width = 1536, height = 864, half = 772, rightFrom = 764 },

	--[[ The portrait frames (owner, 2026-10-26: "make it mobile vertical
	     resolution"), shown while the screen is taller than wide: the same art
	     reframed by Codex (`assets/concepts/blocky/ui/story/portrait.py`),
	     1024 x 1536, cut into a top and a bottom half, the bottom from
	     `bottomFrom`, by `assets/ui/story/cut_portrait.py`. ]]
	portrait = { width = 1024, height = 1536, half = 772, bottomFrom = 764 },
	--[[ Their uploaded halves, by frame: every frame or none. ]]
	portraits = {
		f01 = { top = "rbxassetid://132826732996083", bottom = "rbxassetid://117063062234215" },
		f02a = { top = "rbxassetid://101268508257438", bottom = "rbxassetid://133941862753852" },
		f02b = { top = "rbxassetid://109328275108966", bottom = "rbxassetid://78365149488527" },
		f02c = { top = "rbxassetid://83761583730690", bottom = "rbxassetid://79013040459468" },
		f02d = { top = "rbxassetid://81205326337720", bottom = "rbxassetid://99161742976390" },
		f03b = { top = "rbxassetid://95082384819417", bottom = "rbxassetid://101383510895968" },
		f04a = { top = "rbxassetid://123579498845364", bottom = "rbxassetid://95148870832512" },
		f04b = { top = "rbxassetid://101441282069458", bottom = "rbxassetid://81369798406334" },
		f05a = { top = "rbxassetid://78748483578747", bottom = "rbxassetid://139245014331564" },
		f05b = { top = "rbxassetid://119524110870037", bottom = "rbxassetid://92302287295110" },
		f06a = { top = "rbxassetid://139755387155479", bottom = "rbxassetid://88706865068804" },
		f06b = { top = "rbxassetid://82345204204160", bottom = "rbxassetid://118462072009906" },
		f06c = { top = "rbxassetid://101719991081367", bottom = "rbxassetid://99186974746467" },
		f07a = { top = "rbxassetid://103529080375839", bottom = "rbxassetid://116216033036010" },
		f07b = { top = "rbxassetid://128483197005596", bottom = "rbxassetid://100379033094740" },
		f08a = { top = "rbxassetid://79199120519344", bottom = "rbxassetid://127418698135186" },
		f08b = { top = "rbxassetid://121276186452909", bottom = "rbxassetid://131734565832507" },
		f09 = { top = "rbxassetid://93949072850276", bottom = "rbxassetid://108683870764281" },
		f10a = { top = "rbxassetid://120626805426199", bottom = "rbxassetid://107316136789565" },
		f10b = { top = "rbxassetid://112486960951454", bottom = "rbxassetid://123607697806821" },
		f12a = { top = "rbxassetid://136398549398227", bottom = "rbxassetid://133341723369959" },
		f12b = { top = "rbxassetid://88851833180297", bottom = "rbxassetid://122022244852061" },
		f13a = { top = "rbxassetid://88927811723849", bottom = "rbxassetid://86822773890658" },
		f13b = { top = "rbxassetid://92891202903852", bottom = "rbxassetid://71422745834758" },
		f14a = { top = "rbxassetid://87804189535277", bottom = "rbxassetid://77670123258982" },
		f14b = { top = "rbxassetid://131269207075316", bottom = "rbxassetid://123844825671070" },
		f15a = { top = "rbxassetid://116614179050056", bottom = "rbxassetid://104227758174820" },
		f15b = { top = "rbxassetid://96946311376636", bottom = "rbxassetid://77138147550943" },
		f16a = { top = "rbxassetid://137774527825488", bottom = "rbxassetid://119747727623775" },
		f16b = { top = "rbxassetid://128260275576307", bottom = "rbxassetid://82127583907807" },
		f17a = { top = "rbxassetid://137657414429034", bottom = "rbxassetid://79499698371763" },
		f17b = { top = "rbxassetid://112476381105027", bottom = "rbxassetid://130715302251255" },
		f18a = { top = "rbxassetid://126290855165812", bottom = "rbxassetid://134621772921097" },
		f18b = { top = "rbxassetid://130547911902005", bottom = "rbxassetid://113971503281826" },
		f19 = { top = "rbxassetid://129219132254966", bottom = "rbxassetid://115315553633726" },
		f21a = { top = "rbxassetid://100823347085166", bottom = "rbxassetid://83618904886416" },
		f21b = { top = "rbxassetid://132200046609984", bottom = "rbxassetid://89619526239053" },
		f22b = { top = "rbxassetid://91335693090305", bottom = "rbxassetid://92103275517632" },
		f23a = { top = "rbxassetid://84030034214582", bottom = "rbxassetid://107518376125202" },
		f23c = { top = "rbxassetid://112309278207874", bottom = "rbxassetid://101686934765748" },
	} :: { [string]: { top: string, bottom: string } },

	--[[ Uploaded halves, by frame. ]]
	pictures = {
		f01 = { left = "rbxassetid://84266171488518", right = "rbxassetid://106530788926163" },
		f02a = { left = "rbxassetid://74990885156584", right = "rbxassetid://82723673255400" },
		f02b = { left = "rbxassetid://118778981199379", right = "rbxassetid://129194982914725" },
		f02c = { left = "rbxassetid://102287079229675", right = "rbxassetid://129632498701385" },
		f02d = { left = "rbxassetid://78961652037969", right = "rbxassetid://108680605904758" },
		f03b = { left = "rbxassetid://109011983255612", right = "rbxassetid://75670537465063" },
		f04a = { left = "rbxassetid://108425466358381", right = "rbxassetid://72388372180877" },
		f04b = { left = "rbxassetid://90467286703057", right = "rbxassetid://114470749953818" },
		f05a = { left = "rbxassetid://110046565155641", right = "rbxassetid://94495813419394" },
		f05b = { left = "rbxassetid://135073650322487", right = "rbxassetid://140228070030849" },
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
		f21a = { left = "rbxassetid://120320591600411", right = "rbxassetid://71961708207331" },
		f21b = { left = "rbxassetid://92346184971460", right = "rbxassetid://98966547257839" },
		f22b = { left = "rbxassetid://91225138490115", right = "rbxassetid://72213481969508" },
		f23a = { left = "rbxassetid://101185847274765", right = "rbxassetid://118400051838706" },
		f23c = { left = "rbxassetid://101855997114676", right = "rbxassetid://107388334134792" },
	} :: { [string]: { left: string, right: string } },

	--[[ Game sounds (`Config/Sounds`), at seconds into a shot. ]]
	sounds = {
		{ shot = "Skid", at = 0, sound = "boss_king_goo" },
		{ shot = "Rise", at = 0.8, sound = "boss_king_chest_bump" },
		{ shot = "Roar", at = 0, sound = "boss_king_bounce_slam" },
		{ shot = "Shockwave", at = 0, sound = "boss_king_bounce_launch" },
	},

	--[[ The shots in order, each its frames in order, each frame shown once. ]]
	shots = {
		{ name = "Sky", frames = { { picture = "f01", hold = 2.0 } } },
		{
			name = "Glade",
			frames = { { picture = "f02a", hold = 1.5 }, { picture = "f02b", hold = 1.5 } },
		},
		{
			name = "Chest",
			frames = { { picture = "f02c", hold = 1.3 }, { picture = "f02d", hold = 1.3 } },
		},
		{ name = "Lounge", frames = { { picture = "f03b", hold = 1.7 } } },
		{
			name = "Yawn",
			frames = { { picture = "f04b", hold = 0.6 }, { picture = "f04a", hold = 1.2 } },
		},
		{
			name = "Bushes",
			frames = { { picture = "f05a", hold = 1.0 }, { picture = "f05b", hold = 1.0 } },
		},
		{
			name = "Run",
			frames = {
				{ picture = "f06a", hold = 0.4 },
				{ picture = "f06b", hold = 0.4 },
				{ picture = "f06c", hold = 0.4 },
			},
		},
		{
			name = "Skid",
			frames = { { picture = "f07a", hold = 0.7 }, { picture = "f07b", hold = 1.0 } },
		},
		{
			name = "Offer",
			frames = { { picture = "f08a", hold = 1.0 }, { picture = "f08b", hold = 1.0 } },
		},
		{ name = "Take", frames = { { picture = "f09", hold = 1.2 } } },
		{
			name = "Unroll",
			frames = { { picture = "f10a", hold = 0.8 }, { picture = "f10b", hold = 1.0 } },
		},
		{
			name = "Eyes",
			frames = { { picture = "f12a", hold = 0.8 }, { picture = "f12b", hold = 1.0 } },
		},
		{
			name = "Steam",
			frames = { { picture = "f13a", hold = 1.2 }, { picture = "f13b", hold = 1.2 } },
		},
		{
			name = "Crumple",
			frames = { { picture = "f14a", hold = 0.7 }, { picture = "f14b", hold = 1.0 } },
		},
		{
			name = "Rise",
			frames = { { picture = "f15a", hold = 0.8 }, { picture = "f15b", hold = 1.0 } },
		},
		{
			name = "Breath",
			frames = { { picture = "f16a", hold = 0.7 }, { picture = "f16b", hold = 0.9 } },
		},
		{
			name = "Roar",
			frames = { { picture = "f17a", hold = 0.8 }, { picture = "f17b", hold = 1.0 } },
		},
		{
			name = "Shockwave",
			frames = { { picture = "f18a", hold = 0.8 }, { picture = "f18b", hold = 1.0 } },
		},
		{ name = "Pan", frames = { { picture = "f19", hold = 2.0 } } },
		{
			name = "Faces",
			frames = { { picture = "f21a", hold = 1.0 }, { picture = "f21b", hold = 1.0 } },
		},
		{ name = "Ready", frames = { { picture = "f22b", hold = 1.5 } } },
		{
			name = "Away",
			frames = { { picture = "f23a", hold = 0.8 }, { picture = "f23c", hold = 1.2 } },
		},
	} :: { StoryTimeline.Shot },
}

return table.freeze(Story)
