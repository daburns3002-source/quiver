--!strict
--[[
	Hatch shout-outs' rules (`Config/Shoutouts`): which rolls are shouted,
	here and in other servers, how the line reads, and what a message from
	another server must look like before it is shown. Pure, so
	`tests/ShoutoutRules.spec` drives it.
]]

local Config = require(script.Parent.Parent.Config.Shoutouts)

local ShoutoutRules = {}

export type Kind = "Pet" | "Weapon"
--[[ One shout as it travels: who rolled it, a pet or a weapon, the item's
     config key and its rarity. Names are looked up where it is shown, so a
     server on another build drops what it does not know. ]]
export type Shout = { who: string, kind: Kind, item: string, rarity: string }

--[[ Longest name and key a message may carry (a Roblox display name is at
     most 20 characters, keys are shorter than this). ]]
local LONGEST = 40

--[[ Whether a roll of this rarity is shouted in its own server. ]]
function ShoutoutRules.loud(rarity: unknown): boolean
	return type(rarity) == "string" and table.find(Config.rarities, rarity) ~= nil
end

--[[ Whether it also goes to every other server. ]]
function ShoutoutRules.far(rarity: unknown): boolean
	return type(rarity) == "string" and table.find(Config.far.rarities, rarity) ~= nil
end

--[[ "A" or "AN" before a word. ]]
function ShoutoutRules.article(word: string): string
	return if string.find(string.upper(word), "^[AEIOU]") then "AN" else "A"
end

--[[ "NAME HATCHED A MYTHIC GLIMMERHORN!", with `suffix` before the "!"
     (" IN ANOTHER SERVER"). ]]
function ShoutoutRules.line(
	who: string,
	kind: Kind,
	rarity: string,
	name: string,
	suffix: string?
): string
	local caps = string.upper(rarity)
	return `{who} {Config.verbs[kind]} {ShoutoutRules.article(caps)} {caps} {string.upper(name)}{suffix or ""}!`
end

--[[ A message from another server as a shout, or nil if it is not one we
     would send: every field a short string, a known kind, a far rarity. ]]
function ShoutoutRules.read(message: unknown): Shout?
	if type(message) ~= "table" then
		return nil
	end
	local m = message :: any
	for _, field in { "who", "kind", "item", "rarity" } do
		local value = m[field]
		if type(value) ~= "string" or #value == 0 or #value > LONGEST then
			return nil
		end
	end
	if Config.verbs[m.kind] == nil or not ShoutoutRules.far(m.rarity) then
		return nil
	end
	return { who = m.who, kind = m.kind, item = m.item, rarity = m.rarity }
end

--[[ Whether something kept to a gap may happen at `now`, the last time
     being `last`; the new last time if so. ]]
function ShoutoutRules.spaced(last: number?, now: number, gap: number): (boolean, number?)
	if last and now - last < gap then
		return false, last
	end
	return true, now
end

return ShoutoutRules
