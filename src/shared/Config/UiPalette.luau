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
	their ground and big ones (headers, button words, the X) 3:1.
	`Util/UiContrast` lists every words-on-ground pair the kit draws and
	`tests/UiPalette.spec` holds each to its number. Three things follow
	from that and must stay:

	- a button's face is lit only between its two listed colours and striped
	  with a faint *dark* wash (`stripe`, `stripeStrength`); a lighter top or
	  a white stripe drops white words under 3:1;
	- tabs are pale pieces with dark words, a tile's caption sits on a white
	  chip, and coin and gem amounts are dark, not gold and blue;
	- the two tip highlights differ by hue, not brightness.

	Data only: what a colour needs worked out (a face for a colour that is
	not the kit's own, a contrast) is `Util/UiContrast`'s.
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

return table.freeze(UiPalette)
