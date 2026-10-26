--!strict
--[[
	The weapon shop's pictures (`UI/ShopScreen`), 2D Codex art (CLAUDE.md
	rules 9 and 14), uploaded through Studio's MCP, keyed by a weapon's
	`Config/WeaponStats` name. Each weapon is the THREE-QUARTER view of the
	reference sheet its 3D model was built from (owner, 2026-10-25), cut out by
	`assets/ui/shop/three_quarter.py`; the Acorn Bow, which has no sheet, and
	the crate, coins, gems and boss items are Codex's shop sheets cut out by
	`assets/ui/shop/cutout.py`. Areas without
	art of their own show the Mossy Glade crate as a black silhouette.
]]

local ShopAssets = {
	crates = {
		MossyGlade = "rbxassetid://103986301765766",
	} :: { [string]: string },
	coin = "rbxassetid://118507342118817",
	gem = "rbxassetid://97625421794441",
	lock = "rbxassetid://111797935148821",
	items = {
		RoyalJelly = "rbxassetid://123248195151113",
		BroodSilk = "rbxassetid://91967702339012",
	} :: { [string]: string },
	weapons = {
		TwigBow = "rbxassetid://89841540130312",
		AcornBow = "rbxassetid://90453772215579",
		FireflyBow = "rbxassetid://81768703457702",
		MossSlimeBow = "rbxassetid://121992307955241",
		EmberFangBow = "rbxassetid://127276672222487",
		GladeSpiritBow = "rbxassetid://110408798064101",
		BranchStaff = "rbxassetid://80085083687616",
		ToadstoolStaff = "rbxassetid://90146834069883",
		LanternStaff = "rbxassetid://128770184821460",
		HootmossStaff = "rbxassetid://131204888538377",
		SlimeCrownStaff = "rbxassetid://83423961366955",
		WorldrootStaff = "rbxassetid://86183620962587",
		TimberBlade = "rbxassetid://125162451128057",
		MossstoneBlade = "rbxassetid://91807471069914",
		ThornBlade = "rbxassetid://80040161215177",
		BroodsplitBlade = "rbxassetid://125493298765353",
		EmberfangBlade = "rbxassetid://124954085051996",
		GladeheartBlade = "rbxassetid://96121957703325",
	} :: { [string]: string },
}

return table.freeze(ShopAssets)
