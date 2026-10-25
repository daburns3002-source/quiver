--!strict
--[[
	The upgrade card design's images, uploaded to Roblox on 2026-10-22 from
	design_handoff_upgrade_cards/assets.

	`icons` is keyed by the icon name each ability carries
	(`Ability.icon`). Since 2026-10-24 the card itself is the owner's Glow
	Toy set (arrow-legends-upgrade-cards.zip): a crystal body per rarity,
	a name banner per rarity (the name written on it live) and each card's
	icon tile. The shard, facet, glow and
	rays images are white, and are tinted where they are used with
	ImageColor3 and ImageTransparency.
]]

local CardAssets = {
	shard = "rbxassetid://111433682589407",
	shardFacet = "rbxassetid://115515204434571",
	glow = "rbxassetid://81560671340801",
	rays = "rbxassetid://75907649628934",

	--[[ Each card's icon on its rarity tile, 512 x 512 (Glow Toy, 2026-10-24). ]]
	icons = {
		["agility"] = "rbxassetid://96642514352872",
		["arcane-echo"] = "rbxassetid://79387761516670",
		["bigger-orbs"] = "rbxassetid://118503372881228",
		["blast-arrows"] = "rbxassetid://96658056868426",
		["blaze"] = "rbxassetid://129563612152498",
		["bloodletting"] = "rbxassetid://92401439423216",
		["bloodthirst"] = "rbxassetid://137918730754311",
		["bouncy-wall"] = "rbxassetid://128263635948294",
		["chain-lightning"] = "rbxassetid://91334869881692",
		["cleave"] = "rbxassetid://126405252879108",
		["deadly-strike"] = "rbxassetid://109886729260851",
		["diagonal-arrows"] = "rbxassetid://72414029800170",
		["diagonal-orbs"] = "rbxassetid://101295594833463",
		["double-shot"] = "rbxassetid://72586410132544",
		["dual-bows"] = "rbxassetid://85351971323122",
		["earthbreaker"] = "rbxassetid://136469458369580",
		["execute"] = "rbxassetid://126714268955458",
		["front-arrow"] = "rbxassetid://117223700505956",
		["heal"] = "rbxassetid://108918575149841",
		["heavy-blade"] = "rbxassetid://126610347711267",
		["homing-orbs"] = "rbxassetid://137946268999702",
		["intellect"] = "rbxassetid://110492710524796",
		["iron-skin"] = "rbxassetid://123315460720986",
		["lightfoot"] = "rbxassetid://80811855978885",
		["long-reach"] = "rbxassetid://112791321249396",
		["long-shot"] = "rbxassetid://116059435175043",
		["mana-flow"] = "rbxassetid://78625178208879",
		["mending"] = "rbxassetid://81894259232672",
		["meteor"] = "rbxassetid://86229208774985",
		["momentum"] = "rbxassetid://128439107704421",
		["multishot"] = "rbxassetid://107158761217279",
		["overdraw"] = "rbxassetid://105567107886967",
		["piercing-shot"] = "rbxassetid://115949427937764",
		["precision"] = "rbxassetid://72501313460007",
		["quick-hands"] = "rbxassetid://88208778440439",
		["rear-arrow"] = "rbxassetid://71528451703395",
		["ricochet"] = "rbxassetid://106688429040344",
		["second-wind"] = "rbxassetid://92573249402334",
		["side-arrow"] = "rbxassetid://82400639958324",
		["soul-chain"] = "rbxassetid://101754170677017",
		["spell-pierce"] = "rbxassetid://77628850766293",
		["steadfast"] = "rbxassetid://127095803670027",
		["strength"] = "rbxassetid://88182838713955",
		["swift-arrows"] = "rbxassetid://97137683322480",
		["twin-cast"] = "rbxassetid://106576770239038",
		["vitality"] = "rbxassetid://110892185853892",
	},
	--[[ The name banner for each rarity, 984 x 558, its plate cleared
	     (`assets/ui/glow_toy_cards/clear_plates.py`): the card writes its name
	     and rarity on it in the blocky font (CLAUDE.md rule 11). ]]
	banners = {
		Common = "rbxassetid://99271147813779",
		Uncommon = "rbxassetid://107353888465461",
		Rare = "rbxassetid://80064908413457",
		Epic = "rbxassetid://116215851474604",
		Legendary = "rbxassetid://133356175427301",
		Mythic = "rbxassetid://90967751254037",
	},
	--[[ The Glow Toy crystal card body for each rarity, 398 x 960, and the
	     Mythic's face-down back. ]]
	bodies = {
		Common = "rbxassetid://90671762114902",
		Uncommon = "rbxassetid://70644942812690",
		Rare = "rbxassetid://74958973294571",
		Epic = "rbxassetid://97438859201247",
		Legendary = "rbxassetid://70692305125093",
		Mythic = "rbxassetid://89130069446957",
	},
	mythicBack = "rbxassetid://126477872051221",
	--[[ The draft screen's buttons in the Glow Toy set (804 x 324, the plate
	     inside 45..758 x 48..278; pressed, it sits 30 lower): its blank
	     plates, green, blue and grey for one that cannot be pressed, with
	     their words written live in the blocky font (CLAUDE.md rule 11); and
	     the dice the Reroll art carried, cut out by
	     `assets/ui/glow_toy_cards/cut_dice.py`. ]]
	buttons = {
		choose = "rbxassetid://135635811569518",
		choosePressed = "rbxassetid://103700544580820",
		chooseDisabled = "rbxassetid://101932680741168",
		reroll = "rbxassetid://88340391705752",
		rerollPressed = "rbxassetid://92158637372989",
		rerollDisabled = "rbxassetid://101932680741168",
		dice = "rbxassetid://80956788958430",
		diceDisabled = "rbxassetid://97779362416209",
	},
	--[[ The skill bar in the Glow Toy set: its frame (892 x 232, drawn
	     9-sliced so it fits any number of slots), an empty slot (256 x 256),
	     and the LV1 to LV5 badges (276 x 150). ]]
	skillBar = {
		frame = "rbxassetid://106145703765733",
		slotEmpty = "rbxassetid://118176482611632",
		levels = {
			"rbxassetid://97985655722472",
			"rbxassetid://124419960656980",
			"rbxassetid://107776677590024",
			"rbxassetid://85445061249362",
			"rbxassetid://84494525707261",
		},
	},
}

return table.freeze(CardAssets)
