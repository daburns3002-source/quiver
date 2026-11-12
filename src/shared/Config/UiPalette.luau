--!strict
--[[
	The UI's colours: **Lagoon** (owner, 2026-11-12: "the ui for everything
	in the lobby right now and the tips is awful bland colors. make it have
	nice soft colors but still have everything be readable", and, of three
	palettes drawn with a contrast check, "Lagoon colors").

	Mint-white panels, deep-sea outlines, a sea-blue header, leaf-green PLAY,
	sunny, teal and coral buttons, chunky white words with a dark outline.
	`UI/Chunky` and `UI/Kit` draw from this file, so every screen built on
	them moves together; a screen takes its colours from the kit, never from
	a hex of its own.

	**Readable is a rule, not a taste**: small words stand 4.5:1 against
	their ground and big ones (headers, button words, the X) 3:1. `pairs`
	lists every words-on-ground pair the kit draws and `tests/UiPalette.spec`
	holds each to its number. Three things follow from that and must stay:

	- a button's face is lit only between its two listed colours and striped
	  with a faint *dark* wash (`stripe`, `stripeStrength`); a lighter top or
	  a white stripe drops white words under 3:1;
	- tabs are pale pieces with dark words, a tile's caption sits on a white
	  chip, and coin and gem amounts are dark, not gold and blue;
	- the two tip highlights differ by hue, not brightness.

	Pure: no instances, so the spec runs outside Studio.
]]

local UiPalette = {}

--[[ A coloured piece with words on it: lit from `top` to `bottom`, the
     words in `text` with `stroke` round them (none when nil), the piece
     itself outlined in `edge`. ]]
export type Face = {
	top: Color3,
	bottom: Color3,
	text: Color3,
	stroke: Color3?,
	edge: Color3,
}

--[[ A rarity's tile: a pale wash from `top` to `bottom` in a `frame`. ]]
export type Tile = { top: Color3, bottom: Color3, frame: Color3 }

local function hex(code: string): Color3
	return Color3.fromRGB(
		tonumber(string.sub(code, 2, 3), 16) :: number,
		tonumber(string.sub(code, 4, 5), 16) :: number,
		tonumber(string.sub(code, 6, 7), 16) :: number
	)
end

local WHITE = hex("#FFFFFF")

--[[ Outlines, and the stroke round the kit's white words. ]]
UiPalette.edge = hex("#17405C")
--[[ Words on a panel or a card, unstroked; `inkSoft` for the small grey ones. ]]
UiPalette.ink = hex("#123A52")
UiPalette.inkSoft = hex("#3D6378")
UiPalette.white = WHITE
UiPalette.panelTop = hex("#F7FFFD")
UiPalette.panelBottom = hex("#DFF6EF")
UiPalette.card = WHITE
--[[ The diagonal stripes on a header or a button: this colour, this solid
     at a band's middle. ]]
UiPalette.stripe = hex("#17405C")
UiPalette.stripeStrength = 0.10

local function face(top: string, bottom: string, text: Color3, stroke: string?): Face
	return {
		top = hex(top),
		bottom = hex(bottom),
		text = text,
		stroke = if stroke then hex(stroke) else nil,
		edge = if stroke then hex(stroke) else UiPalette.edge,
	}
end

UiPalette.header = face("#2A93C9", "#1F7FB8", WHITE, "#0E3F63")
--[[ Green means go: PLAY, EQUIP, CLAIM. ]]
UiPalette.go = face("#35A345", "#2A8F3B", WHITE, "#114A1C")
--[[ A screen's main action: sunny, with dark words and no stroke. ]]
UiPalette.primary = face("#FFD95E", "#FFC53A", UiPalette.ink, nil)
--[[ The second button (CLOSE, an arrow): teal. ]]
UiPalette.secondary = face("#1C9A93", "#16808F", WHITE, "#0A4448")
--[[ A station's button: coral. ]]
UiPalette.action = face("#EB6652", "#DB5242", WHITE, "#6E1F16")
--[[ The X, a badge's number, a way out. ]]
UiPalette.danger = face("#E5536B", "#D03F5A", WHITE, "#6E1426")
--[[ Gems and Soulstones (not on the owner's sheet; made to the same rules). ]]
UiPalette.gems = face("#8B6FD6", "#7A5CC8", WHITE, "#33206E")
--[[ A button that cannot be pressed yet (the same). ]]
UiPalette.off = face("#7F93A2", "#6F8596", WHITE, "#2F4656")

UiPalette.tabOn = hex("#A9E6DA")
UiPalette.tabOnText = UiPalette.ink
UiPalette.tabOff = hex("#D3EAE6")
UiPalette.tabOffText = UiPalette.inkSoft
UiPalette.pill = WHITE
UiPalette.pillText = UiPalette.ink
UiPalette.chip = WHITE
UiPalette.chipText = UiPalette.ink
--[[ A tip's two highlights on a panel: the thing to press, and what it does. ]]
UiPalette.tipControl = hex("#B3400F")
UiPalette.tipAction = hex("#6B2FC0")
--[[ The TIP tag on the loading screen's plate. ]]
UiPalette.tag = hex("#FFC53A")
UiPalette.tagText = UiPalette.ink
--[[ The dark inside of a bar, and the bright fill that reads on it. ]]
UiPalette.trough = hex("#17405C")
UiPalette.barFill = hex("#7BE08A")

local function tile(top: string, bottom: string, frame: string): Tile
	return { top = hex(top), bottom = hex(bottom), frame = hex(frame) }
end

UiPalette.rarity = {
	Common = tile("#EEF3F6", "#D8E2E8", "#72889A"),
	Uncommon = tile("#DDF7DD", "#B2EAB8", "#3A9C52"),
	Rare = tile("#D9EEFF", "#AFD8FC", "#2F86D2"),
	Epic = tile("#E8DEFF", "#CDBBFA", "#7C58D2"),
	Legendary = tile("#FFF4C6", "#FFE28A", "#D29A14"),
	Mythic = tile("#FFDDEA", "#FFB8D4", "#DC5294"),
} :: { [string]: Tile }

local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

--[[ A colour's relative luminance, 0 (black) to 1 (white), as WCAG has it. ]]
function UiPalette.luminance(colour: Color3): number
	return 0.2126 * channel(colour.R) + 0.7152 * channel(colour.G) + 0.0722 * channel(colour.B)
end

--[[ The contrast between two colours, 1 (none) to 21. ]]
function UiPalette.contrast(a: Color3, b: Color3): number
	local la, lb = UiPalette.luminance(a), UiPalette.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

--[[ Every shade a striped, lit face shows under its words: both ends of
     its light, with and without a stripe over them. ]]
function UiPalette.shades(top: Color3, bottom: Color3): { Color3 }
	local wash, strength = UiPalette.stripe, UiPalette.stripeStrength
	return { top, bottom, top:Lerp(wash, strength), bottom:Lerp(wash, strength) }
end

--[[ The lowest contrast `text` has against any of `grounds`. ]]
function UiPalette.worst(text: Color3, grounds: { Color3 }): number
	local low = math.huge
	for _, ground in grounds do
		low = math.min(low, UiPalette.contrast(text, ground))
	end
	return low
end

--[[ The face for a colour that is none of the kit's own (a rarity's frame,
     a class's colour): lit a touch, never towards white, with white words
     where they stand 3:1 on every shade of it and ink where they do not. ]]
function UiPalette.faceFor(colour: Color3): Face
	local bottom = colour:Lerp(Color3.new(0, 0, 0), 0.08)
	local dark = colour:Lerp(Color3.new(0, 0, 0), 0.62)
	local bright = UiPalette.worst(WHITE, UiPalette.shades(colour, bottom)) >= 3
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
function UiPalette.deepFor(colour: Color3, need: number): Color3
	local black = Color3.new(0, 0, 0)
	for step = 0, 20 do
		local shade = colour:Lerp(black, step * 0.04)
		if UiPalette.contrast(WHITE, shade) >= need then
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
function UiPalette.faceOf(colour: Color3): Face
	for _, own in OWN do
		if own.top == colour then
			return own
		end
	end
	return UiPalette.faceFor(colour)
end

export type Pair = { what: string, text: Color3, grounds: { Color3 }, need: number }

--[[ Every words-on-ground pair the kit draws, with the contrast it must
     keep: 4.5 for small words, 3 for big ones. ]]
function UiPalette.pairs(): { Pair }
	local p = UiPalette
	local panel = { p.panelTop, p.panelBottom }
	local function on(f: Face): { Color3 }
		return p.shades(f.top, f.bottom)
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
		local made = p.faceFor(colours.frame)
		table.insert(out, {
			what = name .. " button words",
			text = made.text,
			grounds = p.shades(made.top, made.bottom),
			need = 3,
		})
	end
	return out
end

return table.freeze(UiPalette)
