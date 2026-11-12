--!strict
--[[
	What the UI's palette (`Config/UiPalette`) needs worked out: how well
	words read on a ground (WCAG contrast), the face a piece gets when its
	colour is not one of the kit's own, and the list of every words-on-ground
	pair the kit draws with the contrast it must keep (owner, 2026-11-12:
	"nice soft colors but still have everything be readable").

	Pure: no instances, so `tests/UiPalette.spec` runs it anywhere.
]]

local UiPalette = require(script.Parent.Parent.Config.UiPalette)

local UiContrast = {}

type Face = UiPalette.Face

local WHITE = UiPalette.white

local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

--[[ A colour's relative luminance, 0 (black) to 1 (white), as WCAG has it. ]]
function UiContrast.luminance(colour: Color3): number
	return 0.2126 * channel(colour.R) + 0.7152 * channel(colour.G) + 0.0722 * channel(colour.B)
end

--[[ The contrast between two colours, 1 (none) to 21. ]]
function UiContrast.contrast(a: Color3, b: Color3): number
	local la, lb = UiContrast.luminance(a), UiContrast.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

--[[ Every shade a striped, lit face shows under its words: both ends of
     its light, with and without a stripe over them. ]]
function UiContrast.shades(top: Color3, bottom: Color3): { Color3 }
	local wash, strength = UiPalette.stripe, UiPalette.stripeStrength
	return { top, bottom, top:Lerp(wash, strength), bottom:Lerp(wash, strength) }
end

--[[ The lowest contrast `text` has against any of `grounds`. ]]
function UiContrast.worst(text: Color3, grounds: { Color3 }): number
	local low = math.huge
	for _, ground in grounds do
		low = math.min(low, UiContrast.contrast(text, ground))
	end
	return low
end

--[[ The face for a colour that is none of the kit's own (a rarity's frame,
     a class's colour): lit a touch, never towards white, with white words
     where they stand 3:1 on every shade of it and ink where they do not. ]]
function UiContrast.faceFor(colour: Color3): Face
	local bottom = colour:Lerp(Color3.new(0, 0, 0), 0.08)
	local dark = colour:Lerp(Color3.new(0, 0, 0), 0.62)
	local bright = UiContrast.worst(WHITE, UiContrast.shades(colour, bottom)) >= 3
	return {
		top = colour,
		bottom = bottom,
		text = if bright then WHITE else UiPalette.ink,
		stroke = if bright then dark else nil,
		edge = dark,
	}
end

--[[ `colour` darkened just far enough that white words stand `need` to 1
     on it (itself, when they already do): the ground under small white
     words on a piece that is not one of the kit's own. ]]
function UiContrast.deepFor(colour: Color3, need: number): Color3
	local black = Color3.new(0, 0, 0)
	for step = 0, 20 do
		local shade = colour:Lerp(black, step * 0.04)
		if UiContrast.contrast(WHITE, shade) >= need then
			return shade
		end
	end
	return colour:Lerp(black, 0.8)
end

local OWN: { Face } = {
	UiPalette.go,
	UiPalette.primary,
	UiPalette.secondary,
	UiPalette.action,
	UiPalette.danger,
	UiPalette.gems,
	UiPalette.off,
	UiPalette.header,
}

--[[ How a piece in `colour` is drawn. One of the kit's own colours (the
     `top` of a face above) has it all listed; any other gets `faceFor`. ]]
function UiContrast.faceOf(colour: Color3): Face
	for _, own in OWN do
		if own.top == colour then
			return own
		end
	end
	return UiContrast.faceFor(colour)
end

export type Pair = { what: string, text: Color3, grounds: { Color3 }, need: number }

--[[ Every words-on-ground pair the kit draws, with the contrast it must
     keep: 4.5 for small words, 3 for big ones. ]]
function UiContrast.pairs(): { Pair }
	local p = UiPalette
	local panel = { p.panelTop, p.panelBottom }
	local function on(f: Face): { Color3 }
		return UiContrast.shades(f.top, f.bottom)
	end
	local out: { Pair } = {
		{ what = "Words on a panel", text = p.ink, grounds = panel, need = 4.5 },
		{ what = "Small grey words on a panel", text = p.inkSoft, grounds = panel, need = 4.5 },
		{ what = "Words on a white card", text = p.ink, grounds = { p.card }, need = 4.5 },
		{ what = "Header title", text = p.header.text, grounds = on(p.header), need = 3 },
		{ what = "PLAY and EQUIP words", text = p.go.text, grounds = on(p.go), need = 3 },
		{ what = "Main button words", text = p.primary.text, grounds = on(p.primary), need = 3 },
		{
			what = "Second button words",
			text = p.secondary.text,
			grounds = on(p.secondary),
			need = 3,
		},
		{ what = "Station button words", text = p.action.text, grounds = on(p.action), need = 3 },
		{
			what = "Close X and the badge number",
			text = p.danger.text,
			grounds = on(p.danger),
			need = 3,
		},
		{ what = "Gem button words", text = p.gems.text, grounds = on(p.gems), need = 3 },
		{ what = "Greyed button words", text = p.off.text, grounds = on(p.off), need = 3 },
		{ what = "Chosen tab words", text = p.tabOnText, grounds = { p.tabOn }, need = 4.5 },
		{ what = "Other tab words", text = p.tabOffText, grounds = { p.tabOff }, need = 4.5 },
		{ what = "Coin and gem amounts", text = p.pillText, grounds = { p.pill }, need = 4.5 },
		{ what = "Tile caption on its chip", text = p.chipText, grounds = { p.chip }, need = 4.5 },
		{ what = "Tip: the thing to press", text = p.tipControl, grounds = panel, need = 4.5 },
		{ what = "Tip: what it does", text = p.tipAction, grounds = panel, need = 4.5 },
		{ what = "TIP tag on the loading tip", text = p.tagText, grounds = { p.tag }, need = 4.5 },
		{ what = "Loading tip words", text = p.ink, grounds = { p.card }, need = 4.5 },
		{ what = "Bar fill in its trough", text = p.barFill, grounds = { p.trough }, need = 3 },
	}
	for name, colours in p.rarity do
		local made = UiContrast.faceFor(colours.frame)
		table.insert(out, {
			what = name .. " button words",
			text = made.text,
			grounds = UiContrast.shades(made.top, made.bottom),
			need = 3,
		})
	end
	return out
end

return UiContrast
