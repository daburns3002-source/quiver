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
	coin = "rbxassetid://118507342118817",
	gem = "rbxassetid://97625421794441",
	lock = "rbxassetid://111797935148821",
	items = {
		RoyalJelly = "rbxassetid://123248195151113",
		BroodSilk = "rbxassetid://91967702339012",
	} :: { [string]: string },
	weapons = {
		TwigBow = "rbxassetid://138984353895385",
		AcornBow = "rbxassetid://90453772215579",
		FireflyBow = "rbxassetid://123828841079142",
		MossSlimeBow = "rbxassetid://112090320658439",
		EmberFangBow = "rbxassetid://114946127588121",
		GladeSpiritBow = "rbxassetid://124461716691460",
		BranchStaff = "rbxassetid://77612272068019",
		ToadstoolStaff = "rbxassetid://127251274901482",
		LanternStaff = "rbxassetid://105723217995423",
		HootmossStaff = "rbxassetid://110060045731761",
		SlimeCrownStaff = "rbxassetid://123948487950469",
		WorldrootStaff = "rbxassetid://109446824605098",
		TimberBlade = "rbxassetid://125018236999573",
		MossstoneBlade = "rbxassetid://80933185041566",
		ThornBlade = "rbxassetid://124361900306270",
		BroodsplitBlade = "rbxassetid://80210413001940",
		EmberfangBlade = "rbxassetid://84444894674818",
		GladeheartBlade = "rbxassetid://76868549241879",
	} :: { [string]: string },
}

return table.freeze(ShopAssets)
