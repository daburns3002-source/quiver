--!strict
--[[
	Hatch shout-outs (`Data/Shoutouts`, `UI/Shoutout`, `Util/ShoutoutRules`;
	owner, 2026-11-18): when anyone in the server hatches a Legendary or
	Mythic pet, or pulls one from a weapon crate, everyone here sees a short
	banner in the rarity's colour and a line in chat. A Mythic also reaches
	every other server of the game, as a chat line only (no banner: a banner
	is for somebody you can see), through MessagingService, held to `far`'s
	gaps so a busy game cannot fill anyone's chat.
]]

return table.freeze({
	--[[ The rarities that are shouted in this server. ]]
	rarities = table.freeze({ "Legendary", "Mythic" }),
	--[[ How each line reads: who, then "A" or "AN", the rarity and the
	     item's name. ]]
	verbs = table.freeze({ Pet = "HATCHED", Weapon = "PULLED" }),
	--[[ The banner: seconds on screen, and the gap before the next one. A
	     banner waits while the player's own reveal (`UI/Reveal`) is up, so
	     the hatcher sees their own pet first. ]]
	hold = 4,
	gap = 0.4,
	--[[ At most this many banners wait; any more are only chat lines. ]]
	queue = 3,
	far = table.freeze({
		rarities = table.freeze({ "Mythic" }),
		topic = "Shoutouts",
		--[[ Seconds between two shouts this server sends, and between two
		     it shows from elsewhere; one inside the gap is dropped. ]]
		sendGap = 10,
		showGap = 20,
		suffix = " IN ANOTHER SERVER",
	}),
})
