--!strict
--[[
	The upgrade card design's tokens: colours, fonts, sizes and timings
	(design_handoff_upgrade_cards, README "Design tokens", "The card" and
	"Motion spec"). Sizes are design pixels; the card is built at these and
	scaled as a whole per device.
]]

local rgb = Color3.fromRGB

local CardTheme = {
	colors = {
		--[[ Every outline, shadow and pill. ]]
		ink = rgb(27, 27, 43),
		panel = rgb(58, 123, 213),
		detailPanel = rgb(42, 95, 181),
		titleYellow = rgb(255, 225, 77),
		gold = rgb(255, 210, 63),
		legendGold = rgb(255, 207, 58),
		paleGold = rgb(255, 241, 179),
		choose = rgb(76, 209, 55),
		reroll = rgb(255, 176, 46),
		disabled = rgb(154, 163, 173),
		danger = rgb(255, 61, 61),
		mythicTitle = rgb(255, 59, 71),
		lightning = rgb(255, 42, 54),
		lightningCore = rgb(255, 214, 214),
		white = rgb(255, 255, 255),
	},

	--[[ The rarity word on each card's banner plate, in the colours the
	     Glow Toy set printed it (sampled from its banners). ]]
	bannerRarity = {
		Common = rgb(72, 80, 96),
		Uncommon = rgb(24, 128, 48),
		Rare = rgb(24, 72, 176),
		Epic = rgb(88, 32, 168),
		Legendary = rgb(184, 104, 0),
		Mythic = rgb(152, 8, 40),
	},

	--[[ Both blocky: Press Start 2P (CLAUDE.md rule 11, owner 2026-10-24). ]]
	fonts = {
		--[[ Headings, rarity labels, names, badges, buttons. ]]
		display = Enum.Font.Arcade,
		--[[ Descriptions, stat pills, other copy. ]]
		body = Enum.Font.Arcade,
	},

	card = {
		--[[ The design's 134 x 330 made a quarter larger, then 30% larger
		     again (owner, 2026-10-24, twice: "the upgrade cards themselves
		     need to be bigger", "make the upgrade cards themselves bigger").
		     Everything on
		     a card is derived from this — the art scales by `SIZE.X`, and the
		     panel's width and height are measured from it in `layoutPanel` —
		     so this is the only number to change. The panel still shrinks to
		     fit a small screen, so on a phone the gain shows as less empty
		     frame rather than bigger cards. ]]
		size = Vector2.new(218, 536),
		--[[ No crystals along the card's left and right edges (owner,
		     2026-10-22: "delete the crystals coming off of the sides of all
		     of the cards"). A shard whose base sits further than this from
		     both the top and the bottom edge is a side crystal and is not
		     drawn; the crowns at the top and bottom stay. `CardFrames` is
		     generated from the design and keeps them all. ]]
		sideCrystalMargin = 20,
		corner = 18,
		stroke = 4,
		shadowOffset = 7,
		paddingTop = 18,
		paddingBottom = 20,
		paddingSide = 8,
		medallion = 76,
		medallionStroke = 4,
		rarityText = 15,
		rarityStroke = 4,
		nameText = 18,
		nameStroke = 5,
		--[[ The stat pill and the description, larger than the design's 13
		     and 11.5 so the description fills the card's lower half (owner,
		     2026-10-24: "make the card description text bigger still so it
		     fills more of the card"). The description wraps at `descWrap`
		     inside a `descBox`; `CardText.spec` keeps every card's text
		     inside it. All in the face's 168-wide units. ]]
		statText = 14,
		-- a long stat line steps its own size down to fit across the card, to
		-- no less than this (the blocky font is wide; CLAUDE.md rule 11)
		statTextMin = 9,
		-- the name on the banner, as large as fits its ribbon on one line or
		-- two, up to the first and no smaller than the second
		bannerNameMax = 24,
		bannerNameMin = 7,
		statHeight = 26,
		descText = 20,
		descStroke = 4,
		descWrap = 144,
		descBox = Vector2.new(150, 156),
		pip = Vector2.new(14, 9),
		pipStroke = 2.5,
		pipGap = 4,
	},

	--[[ The whole card's scale per input layout. ]]
	scale = {
		desktop = 1,
		phone = 0.746,
		controller = 1,
	},

	timing = {
		dealStagger = 0.095,
		dealDuration = 0.56,
		rerollDuration = 0.4,
		holdToOpen = 0.48,
		tooltipTime = 1.3,
		pickApplyAt = 1.56,
		slotPop = 0.65,
		mythicShake = 1.0,
		mythicFlip = 0.6,
		mythicTitleAt = 1.65,
		lightningStart = 1.3,
		lightningRun = 2.95,
		lightningFade = 0.75,
		lightningSpeed = 420,
		lightningBolts = 3,
		lightningLength = 130,
	},
}

return table.freeze(CardTheme)
