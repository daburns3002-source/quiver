--!strict
--[[
	Every weapon's and pet's ONE picture (owner, 2026-11-19: "MAKE SURE THE
	ICONS IN THE CHESTS, EGGS, GEAR SCREEN, AND DEX ARE ALL THE SAME").
	Every screen that shows an item asks here, never `Config/ShopAssets` or
	`Config/GearAssets` itself, so no two screens can pick different art
	again (`tests/ItemIcons.spec` holds that, and `tools/check.sh` fails on
	a screen that reads them directly).

	- A weapon is its 2D shop art (CLAUDE.md rules 9 and 14):
	  `ShopAssets.weapons`, the three-quarter view every screen already drew.
	  The outlined copies the old gear screen used were dropped on
	  2026-11-19; Chunky's tiles draw their own thick rarity frame.
	- A pet is its picture in `GearAssets.pets`.

	An item with no picture gets "", which a tile leaves empty.
]]
-- by path from here, as `Util/LoadingPick` is: the loading screen asks too
local GearAssets = require(script.Parent.Parent.Config.GearAssets)
local ShopAssets = require(script.Parent.Parent.Config.ShopAssets)

export type Kind = "weapon" | "pet"

local ItemIcons = {}

function ItemIcons.weapon(key: string): string
	return (ShopAssets.weapons :: { [string]: string })[key] or ""
end

function ItemIcons.pet(key: string): string
	return (GearAssets.pets :: { [string]: string })[key] or ""
end

function ItemIcons.of(kind: Kind, key: string): string
	return if kind == "pet" then ItemIcons.pet(key) else ItemIcons.weapon(key)
end

return table.freeze(ItemIcons)
