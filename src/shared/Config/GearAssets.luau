--!strict
--[[
	The gear screen's and shops' pictures (owner, 2026-10-26), uploaded from
	`assets/ui/gear/` (cut by `assets/ui/gear/cutout.py` from Codex's sheets in
	`assets/concepts/blocky/ui/pixel/` and `reveal/`).

	- `weapons` and `pets`: the mini pixel icons ("i like the mini pixel
	  versions of the weapons and pets"), keyed by `Config/WeaponStats` and
	  `Config/Pets` names. A weapon or pet with none falls back to its shop
	  picture or a silhouette; `tests/GearAssets.spec` wants one for each.
	- `crates` (pixel art: `closed` with its two padlocks for the shop, `bare`
	  without them for the reveal, which draws its own to pop off, and `open`,
	  per `Config/Shop` area) and `eggs` (whole,
	  two cracked stages and the burst, per `Config/Eggs` key): the reveals'
	  frames.
	- `fx`: white shapes the reveals tint by rarity.
	  An empty id is not drawn.
]]

local GearAssets = {
	--[[ The crate's INSIDE tiles cut whole from the chosen mockup (owner,
	     2026-10-26: "make the icons actually from the option C";
	     `assets/ui/gear/optc/`), its chance band cleared for the game's own. ]]
	--[[ The back and arrow buttons, cut from the same mockup. ]]
	buttons = {
		back = "rbxassetid://108896071664277",
		left = "rbxassetid://83943438986636",
		right = "rbxassetid://118687850481288",
	},
	crateTiles = {
		HootmossStaff = "rbxassetid://80030543863014",
		ThornBlade = "rbxassetid://123784490682545",
		AcornBow = "rbxassetid://95876371507095",
		FireflyBow = "rbxassetid://133209449661927",
		MossSlimeBow = "rbxassetid://118564451999252",
		WorldrootStaff = "rbxassetid://140600630838336",
		BroodsplitBlade = "rbxassetid://80045144092728",
		GladeSpiritBow = "rbxassetid://122509292380004",
		LanternStaff = "rbxassetid://136857707110473",
		ToadstoolStaff = "rbxassetid://138209734091526",
		GladeheartBlade = "rbxassetid://82640059295910",
		MossstoneBlade = "rbxassetid://83971051827860",
	} :: { [string]: string },
	--[[ Full-screen backdrops behind the screens (Codex, 2026-10-26). ]]
	--[[ Small pixel icons for the gear screen's tabs and stats (drawn by
	     Claude, `assets/ui/gear/icons/`; owner, 2026-10-27: "the icon next
	     to classes should be a little pixel icon of the male archer classes
	     head ... pets should be a pixel icon of an egg ... ATK ... a pixel
	     sword icon and next to HP ... a pixel heart icon"; the three tab icons
	     then "should be black and white"). ]]
	uiIcons = {
		archerHead = "rbxassetid://107871767440196",
		egg = "rbxassetid://84843820706730",
		sword = "rbxassetid://126689397355795",
		heart = "rbxassetid://130873345081387",
		-- the WEAPON tab's, black and white like CLASSES and PETS (owner)
		swordTab = "rbxassetid://95308296178918",
	},
	backgrounds = {
		gear = "rbxassetid://123017599667033",
		blacksmith = "rbxassetid://77301261973067",
		hatchery = "rbxassetid://107014711671494",
	},
	--[[ The smith hammering at his anvil on the Blacksmith screen (owner,
	     2026-10-26): a 2 x 2 sheet of 512 px frames, raised, swinging,
	     striking, bouncing back, each held `holds` seconds. ]]
	smith = {
		sheet = "rbxassetid://94508718061923",
		holds = { 0.45, 0.08, 0.16, 0.14 },
	},
	-- with a bold dark outline round each (owner, 2026-10-26: "they need to
	-- have a border around them"; `assets/ui/gear/outlined/`)
	weapons = {
		TwigBow = "rbxassetid://132113785090505",
		AcornBow = "rbxassetid://96318150998975",
		FireflyBow = "rbxassetid://128990046825154",
		MossSlimeBow = "rbxassetid://92732102970465",
		EmberFangBow = "rbxassetid://125485507262589",
		GladeSpiritBow = "rbxassetid://95914330923781",
		BranchStaff = "rbxassetid://110028919919148",
		ToadstoolStaff = "rbxassetid://103846762012524",
		LanternStaff = "rbxassetid://87882166814803",
		HootmossStaff = "rbxassetid://77705980987654",
		SlimeCrownStaff = "rbxassetid://121120504602308",
		WorldrootStaff = "rbxassetid://78284498913317",
		TimberBlade = "rbxassetid://107410998322331",
		MossstoneBlade = "rbxassetid://76992176147383",
		ThornBlade = "rbxassetid://134376839588123",
		BroodsplitBlade = "rbxassetid://118527389116413",
		EmberfangBlade = "rbxassetid://81277734347197",
		GladeheartBlade = "rbxassetid://124288097242577",
	} :: { [string]: string },
	pets = {
		Mosslet = "rbxassetid://88216505031993",
		Babacorn = "rbxassetid://76501430507544",
		FernFrog = "rbxassetid://100347167089648",
		ToadstoolTot = "rbxassetid://110117240407269",
		MossbackSnail = "rbxassetid://136748884579366",
		FireflyBun = "rbxassetid://112201723878493",
		Stumpy = "rbxassetid://93282671939278",
		GladeFox = "rbxassetid://113054935053277",
		Hootmoss = "rbxassetid://133339489384185",
		SlimePrince = "rbxassetid://105364611490161",
		EmberWilfPet = "rbxassetid://84054404368414",
		Glimmerhorn = "rbxassetid://107274566383470",
		-- Thornwood
		BarkHoglet = "rbxassetid://85158712161429",
		Burrball = "rbxassetid://105030144351437",
		Budbulb = "rbxassetid://104866742117871",
		BerryMouse = "rbxassetid://125833278452238",
		ThistleMole = "rbxassetid://91789981690252",
		BriarBeetle = "rbxassetid://98768787211375",
		BerryBat = "rbxassetid://120671172614168",
		BrambleBear = "rbxassetid://124199226628429",
		BriarLynx = "rbxassetid://123457827044688",
		BrambleWilf = "rbxassetid://100817787910788",
		ThornPrincess = "rbxassetid://77091667536130",
		Thornwake = "rbxassetid://85430024402506",
	} :: { [string]: string },
	crates = {
		MossyGlade = {
			closed = "rbxassetid://115732608547127",
			bare = "rbxassetid://132518924413005",
			open = "rbxassetid://110805001270540",
		},
		Thornwood = {
			closed = "rbxassetid://139411907605270",
			bare = "rbxassetid://130462577945262",
			open = "rbxassetid://132986191598031",
		},
		DrownedVillage = {
			closed = "rbxassetid://129406927323412",
			bare = "rbxassetid://93374148317621",
			open = "rbxassetid://78736767331636",
		},
		BogheartCaverns = {
			closed = "rbxassetid://74264485531007",
			bare = "rbxassetid://88397231327506",
			open = "rbxassetid://100424663327388",
		},
		WindsweptCliffs = {
			closed = "rbxassetid://109820030254804",
			bare = "rbxassetid://123984843499980",
			open = "rbxassetid://126672295487581",
		},
		FrostpeakPass = {
			closed = "rbxassetid://84025185082724",
			bare = "rbxassetid://94739226508814",
			open = "rbxassetid://96625859132471",
		},
	} :: { [string]: { closed: string, bare: string, open: string } },
	eggs = {
		MossyEgg = {
			whole = "rbxassetid://106270870780677",
			crack1 = "rbxassetid://83969750477878",
			crack2 = "rbxassetid://71861915568555",
			burst = "rbxassetid://140609227414793",
		},
		ThornwoodEgg = {
			whole = "rbxassetid://104439505138184",
			crack1 = "rbxassetid://114936238157331",
			crack2 = "rbxassetid://116737796954527",
			burst = "rbxassetid://80786736493750",
		},
	} :: { [string]: { whole: string, crack1: string, crack2: string, burst: string } },
	--[[ The showcase behind a pulled prize (owner, 2026-10-26: option 4, "the
	     showcase pedestal with the rarity banner and confetti"): white, tinted
	     by rarity. The banner is 748 x 297, the pedestal 642 x 318. ]]
	showcase = {
		banner = "rbxassetid://77309143397049",
		pedestal = "rbxassetid://105357351623859",
		spotlight = "rbxassetid://107959114129330",
	},
	fx = {
		rays = "rbxassetid://123315883761316",
		glow = "rbxassetid://72053512669132",
		sparkle = "rbxassetid://140286080633760",
		ring = "rbxassetid://119651633511726",
		confetti = "rbxassetid://86883153796302",
		badge = "rbxassetid://108895879713593",
	},
}

return table.freeze(GearAssets)
