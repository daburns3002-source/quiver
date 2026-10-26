--!strict
--[[
	The loading screen's tips (owner, 2026-10-26: "make a list of 20 tips
	for the game"), one shown at random each time (`first/Loading`), beside a
	picture of an enemy or weapon the player has already met. Each is true of
	the game as built; change one when what it says changes.
]]

local LoadingTips = {
	"Stand still to shoot. Your archer fires on its own at the nearest enemy.",
	"Move to dodge, stop to fire. Timing the two is the whole game.",
	"Press SPACE (or A on a controller) to dash through danger.",
	"A red marker on the floor shows where an attack will land. Get out of it!",
	"Fallen enemies drop crystals. Collect them to level up and pick an upgrade.",
	"Upgrades stack: take the same one again and it gets stronger.",
	"Legendary and Mythic upgrades are rare, and they glow. Grab them!",
	"A Brood Slime bursts into four Baby Slimes. Clear the little ones fast.",
	"The Splitter Spitter spits two seeds. Slip through the gap between them.",
	"When an Ember Wilf's eyes flash red, it's about to charge. Get off its line!",
	"A Bramble Boar paws the ground before it charges. Step aside!",
	"A Bramble Lurker bursts up on a marked spot. Don't stand on the mark.",
	"Every kill pays coins, and clearing an area pays a bonus.",
	"Spend coins on weapon crates at the Blacksmith in the lobby.",
	"Beating a boss always drops its item. Legendary weapons need one.",
	"Bosses pay gems, and more the first time you beat them.",
	"Your weapon and your pets are your real power. Upgrade them!",
	"Legendary weapons carry an extra effect, like the Ember Fang Bow's fire.",
	"Clear more rooms to climb the FARTHEST ADVENTURERS board in the lobby.",
	"Thornwood counts on the leaderboard once you've finished Mossy Glade.",
}

return table.freeze(LoadingTips)
