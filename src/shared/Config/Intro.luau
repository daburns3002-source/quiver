--!strict
--[[
	The intro cutscene as the game starts (owner, 2026-10-25), drawn by
	`UI/IntroCutscene` and posed by `Util/IntroTimeline`, after Pixel
	Lineage's intro: a black screen where DYL.DEVS PRESENTS fades in in
	dark gold, then a cut to the title screen, "The World Tree at night"
	(owner, 2026-11-12; `Config/TitleScene`, `UI/TitleScene`), and a BEGIN
	ADVENTURE button that plays the story cutscene (`UI/StoryCutscene`,
	`Config/Story`), whose end starts the run.

	The times are the shared contract with the intro music (side-session
	note `intro-cutscene-contract.md`): the music (`Config/Music.intro`)
	starts on the cutscene's first frame and its grandiose theme hits at
	`revealAt`. Change one only with the music.

	The run holds still until the player presses the button: the server
	skips its step while anyone is still on the title (`RunSession.anyAtTitle`).
	In Studio, a `SkipIntro` attribute on Workspace, set in Edit before Play,
	skips the intro on both sides, for probes that need the run going.
]]

local Intro = {
	--[[ The longest the black screen waits for the music to load before
	     the clock starts anyway (seconds), so the hit lands on the cut. ]]
	musicWait = 3,
	--[[ And the longest it waits for the title's one picture, the soft glow
	     behind the tree (owner, 2026-10-27, of the painted title this
	     replaced: "the title screen does not load on mobile"; its cut landed
	     while its tiles were still coming down). Waiting here rather than
	     moving the cut is what keeps the music's hit on it: the clock and the
	     track start on the same frame, so holding one holds both. The rest of
	     the title is Frames, which need no loading. ]]
	artWait = 3,
	--[[ Seconds from the cutscene starting. ]]
	presentsIn = 0.6,
	--[[ How long the words take to fade (and pop) in, and out. ]]
	presentsFadeIn = 0.5,
	presentsOut = 3.8,
	presentsFadeOut = 0.6,
	--[[ The cut to the picture, on the music's hit. ]]
	revealAt = 5.0,
	--[[ A white flash on the cut, fading over this long. ]]
	flash = 0.35,
	--[[ The button rises in after the cut. ]]
	buttonAt = 5.8,
	buttonIn = 0.45,
	--[[ After the press, the title fades off over this long. ]]
	leave = 0.7,

	--[[ DYL.DEVS in dark gold, PRESENTS smaller and white under it (owner,
	     2026-10-25). ]]
	presents = "DYL.DEVS",
	presentsSub = "PRESENTS",
	presentsSubColour = Color3.fromRGB(255, 255, 255),
	--[[ Dark gold (owner's brief), on black. ]]
	presentsColour = Color3.fromRGB(176, 132, 36),
	--[[ The words start this much larger and settle to 1 as they fade in. ]]
	presentsPop = 1.18,

	--[[ The button's words (owner, 2026-11-12, of the new title: "begin
	     adventure still instead of play"). Its look is the kit's green "go"
	     button (`UI/TitleScene.button`); it pulses gently until pressed. ]]
	button = "BEGIN ADVENTURE",
}

return table.freeze(Intro)
