--!strict
--[[
	The weapon shop's pictures (`UI/ShopScreen`), 2D Codex art (CLAUDE.md
	rules 9 and 14), uploaded through Studio's MCP, keyed by a weapon's
	`Config/WeaponStats` name. Each weapon is the THREE-QUARTER view of the
	reference sheet its 3D model was built from (owner, 2026-10-25), cut out by
	`assets/ui/shop/three_quarter.py` and turned to one angle, the Acorn Bow's
	(owner, 2026-10-26); the Acorn Bow, which has no sheet, and
	the crate, coins, gems and boss items are Codex's shop sheets cut out by
	`assets/ui/shop/cutout.py`. Areas without
	art of their own show the Mossy Glade crate as a black silhouette.
]]

local ShopAssets = {
	crates = {
		MossyGlade = "rbxassetid://103986301765766",
	} :: { [string]: string },
	--[[ The game's ONE coin and ONE diamond (owner, 2026-11-12: "make sure
	     that the coin and diamond icons are universal across the game"; "i
	     like the blue diamond"). Every screen, the run HUD, the coins a kill
	     throws and the lobby's price signs draw these two; no other file
	     holds a coin or gem picture (CLAUDE.md rule 15, and
	     `tools/check.sh` fails on one). ]]
	coin = "rbxassetid://118507342118817",
	gem = "rbxassetid://97625421794441",
	lock = "rbxassetid://111797935148821",
	items = {
		RoyalJelly = "rbxassetid://123248195151113",
		BroodSilk = "rbxassetid://91967702339012",
	} :: { [string]: string },
	weapons = {
		TwigBow = "rbxassetid://138984353895385",
		AcornBow = "rbxassetid://122135876273149",
		FireflyBow = "rbxassetid://123828841079142",
		MossSlimeBow = "rbxassetid://126601435061582",
		EmberFangBow = "rbxassetid://82494217234921",
		GladeSpiritBow = "rbxassetid://105167572507879",
		BranchStaff = "rbxassetid://119564183560294",
		ToadstoolStaff = "rbxassetid://104008117690219",
		LanternStaff = "rbxassetid://93870761746567",
		HootmossStaff = "rbxassetid://85808863931085",
		SlimeCrownStaff = "rbxassetid://123948487950469",
		WorldrootStaff = "rbxassetid://95895311884783",
		TimberBlade = "rbxassetid://72977638132961",
		MossstoneBlade = "rbxassetid://124173705228424",
		ThornBlade = "rbxassetid://98582430776536",
		BroodsplitBlade = "rbxassetid://130245213339331",
		EmberfangBlade = "rbxassetid://71572756742642",
		GladeheartBlade = "rbxassetid://116184146223044",
		--[[ Drowned Village (area 3). Their sheets never reached `main` -- they
		     were written on `phase-3/gear-and-shops` and lost when it did not
		     merge, which is why all fourteen had no picture at all
		     (`docs/BALANCE-REPORT.md` S5). Recovered from bfe0227 and cut by
		     the same `three_quarter.py` as the rest, to the same angle. ]]
		SlatefinBow = "rbxassetid://116241747271084",
		EelcrestBow = "rbxassetid://94554601626369",
		TollstringBow = "rbxassetid://127068128813093",
		EventideBow = "rbxassetid://120169084002514",
		ReedStaff = "rbxassetid://140683927923354",
		BuoyStaff = "rbxassetid://80964701949956",
		WellpearlStaff = "rbxassetid://92260554016203",
		TollkeeperStaff = "rbxassetid://132633383981014",
		MaelstromStaff = "rbxassetid://75434230443845",
		TidewoodBlade = "rbxassetid://105800660381375",
		TidehookBlade = "rbxassetid://97395990899488",
		CausewayBlade = "rbxassetid://123649896710338",
		TollguardBlade = "rbxassetid://90176624824473",
		StormglassBlade = "rbxassetid://70674096466544",
		--[[ Bogheart Caverns (area 4): Codex's single-view art each Tripo
		     model was made from, keyed out and leaned to the shop's angle by
		     `assets/ui/shop/bogheart_icons.py`. ]]
		PeatwoodBow = "rbxassetid://77854642596986",
		SporestringBow = "rbxassetid://85942075348140",
		GlowcapLongbow = "rbxassetid://98507755464460",
		GulpstringBow = "rbxassetid://89535313974914",
		LumenveilBow = "rbxassetid://131652720826461",
		LichenStaff = "rbxassetid://126008663286801",
		PuffballStaff = "rbxassetid://91819748629431",
		VentstoneStaff = "rbxassetid://100584963113720",
		GrandmothersStaff = "rbxassetid://101948393345443",
		MyceliadStaff = "rbxassetid://116161176804002",
		BogironBlade = "rbxassetid://103649482550008",
		ShellbackCleaver = "rbxassetid://72217408196003",
		CaplightBlade = "rbxassetid://84960466576463",
		GulpfangBlade = "rbxassetid://96938087300130",
		DeepglowBlade = "rbxassetid://99421700524406",
	} :: { [string]: string },
}

return table.freeze(ShopAssets)
