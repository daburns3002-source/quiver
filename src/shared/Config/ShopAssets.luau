--!strict
--[[
	The weapon shop's pictures (`UI/ShopScreen`), 2D Codex art (CLAUDE.md
	rules 9 and 14): drawn on flat magenta (`assets/concepts/blocky/ui/shop/`),
	cut out by `assets/ui/shop/cutout.py`, uploaded through Studio's MCP. A
	weapon's icon is keyed by its `Config/WeaponStats` name. Areas without
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
		TwigBow = "rbxassetid://73229339328897",
		AcornBow = "rbxassetid://90453772215579",
		FireflyBow = "rbxassetid://74594558456148",
		MossSlimeBow = "rbxassetid://99150884477571",
		EmberFangBow = "rbxassetid://102850939948982",
		GladeSpiritBow = "rbxassetid://74556434518490",
		BranchStaff = "rbxassetid://134393826020972",
		ToadstoolStaff = "rbxassetid://122288728827219",
		LanternStaff = "rbxassetid://92304561213468",
		HootmossStaff = "rbxassetid://134275899851695",
		SlimeCrownStaff = "rbxassetid://75834552748140",
		WorldrootStaff = "rbxassetid://125840151468364",
		TimberBlade = "rbxassetid://75760084420625",
		MossstoneBlade = "rbxassetid://86828316517355",
		ThornBlade = "rbxassetid://98562639038674",
		BroodsplitBlade = "rbxassetid://71526877908980",
		EmberfangBlade = "rbxassetid://104813537114353",
		GladeheartBlade = "rbxassetid://93598278885075",
	} :: { [string]: string },
}

return table.freeze(ShopAssets)
