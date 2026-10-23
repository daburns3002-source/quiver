--!strict
--[[
	The upgrade card design's images, uploaded to Roblox on 2026-10-22 from
	design_handoff_upgrade_cards/assets.

	`icons` is keyed by the icon name each ability carries (`Ability.icon`).
	The shard, facet, glow and rays images are white, and are tinted where
	they are used with ImageColor3 and ImageTransparency.
]]

local CardAssets = {
	shard = "rbxassetid://111433682589407",
	shardFacet = "rbxassetid://115515204434571",
	glow = "rbxassetid://81560671340801",
	rays = "rbxassetid://75907649628934",

	icons = {
		["agility"] = "rbxassetid://130306890775824",
		["blast-arrows"] = "rbxassetid://92217609782714",
		["blaze"] = "rbxassetid://129752617591071",
		["bloodthirst"] = "rbxassetid://72323076876851",
		["bouncy-wall"] = "rbxassetid://124235290071443",
		["deadly-strike"] = "rbxassetid://136635183894768",
		["diagonal-arrows"] = "rbxassetid://75750858380966",
		["double-shot"] = "rbxassetid://95394550766211",
		["front-arrow"] = "rbxassetid://131308630574668",
		["lightfoot"] = "rbxassetid://88473340062737",
		["long-shot"] = "rbxassetid://110720908717621",
		["mending"] = "rbxassetid://76234451129387",
		["momentum"] = "rbxassetid://136272270092316",
		["multishot"] = "rbxassetid://118005285646335",
		["overdraw"] = "rbxassetid://133947945210490",
		["piercing-shot"] = "rbxassetid://98135372261474",
		["precision"] = "rbxassetid://130089664511347",
		["rear-arrow"] = "rbxassetid://106314374585662",
		["ricochet"] = "rbxassetid://94232811678310",
		["second-wind"] = "rbxassetid://128097971502628",
		["side-arrow"] = "rbxassetid://89953251510910",
		["soul-chain"] = "rbxassetid://130066067401756",
		["strength"] = "rbxassetid://119080746415552",
		["swift-arrows"] = "rbxassetid://78284342672182",
		["tracking-eye"] = "rbxassetid://126521418656928",
		-- Made with ChatGPT Codex, 2026-10-22, in the set's style.
		["dual-bows"] = "rbxassetid://96411221480106",
		["vitality"] = "rbxassetid://105469716205818",
		-- The Warden's and the Arcanist's (docs/CLASS-CARDS.md), made with
		-- ChatGPT Codex, 2026-10-23; wave 2's are uploaded ahead of their cards.
		["arcane-echo"] = "rbxassetid://90588307285736",
		["arcane-shield"] = "rbxassetid://85692218732116",
		["bigger-orbs"] = "rbxassetid://116872321095051",
		["bloodletting"] = "rbxassetid://128956614203627",
		["chain-lightning"] = "rbxassetid://112742787905269",
		["cleave"] = "rbxassetid://127068859568378",
		["echo-slash"] = "rbxassetid://95427916516058",
		["execute"] = "rbxassetid://109941305433406",
		["frost-orb"] = "rbxassetid://72901595082363",
		["gravity-well"] = "rbxassetid://118320781003408",
		["heavy-blade"] = "rbxassetid://128237282788788",
		["homing-orbs"] = "rbxassetid://114694066346379",
		["iron-skin"] = "rbxassetid://93001041210721",
		["long-reach"] = "rbxassetid://97359475363028",
		["mana-flow"] = "rbxassetid://136541389511713",
		["orbiting-orb"] = "rbxassetid://119377800870931",
		["quick-hands"] = "rbxassetid://98957508570560",
		["riposte"] = "rbxassetid://128707586600529",
		["shockwave"] = "rbxassetid://83761779681549",
		["spell-pierce"] = "rbxassetid://112032922952756",
		["split-orb"] = "rbxassetid://139036184880574",
		["steadfast"] = "rbxassetid://112892799886425",
		["sunder"] = "rbxassetid://77038560427871",
		["twin-cast"] = "rbxassetid://97768121123027",
		["whirlwind"] = "rbxassetid://113837535310183",
	},
}

return table.freeze(CardAssets)
