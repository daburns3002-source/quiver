--!strict
--[[
	The tutorial's words (`Config/Tutorial.prompts`, owner, 2026-11-11: "make
	sure to highlight the important words"). A prompt is written with two
	marks: `[SPACE]` is a control, the thing to press, drag or look for, and
	`*DASH*` is the action, the thing it does. `rich` turns the marks into
	RichText colours; `plain` drops them. Pure, so `tests/TutorialPrompts.spec`
	can hold every prompt to the rules.

	The two highlight colours depend on the ground they are read on
	(`palette`): the chunky panel is being re-skinned from blue to cream, and
	a colour that is strong on one is lost on the other.
]]

local PromptText = {}

export type Palette = {
	--[[ The plain words. ]]
	words: Color3,
	--[[ `[..]`, a control. ]]
	control: Color3,
	--[[ `*..*`, an action. ]]
	action: Color3,
}

--[[ On a light ground (the cream panel): brown-black words, the control in
     a strong orange-red and the action in a strong blue. On a dark one (the
     blue panel): white words, gold and a light green. `words` is only the
     fallback: the panel passes its own ink. ]]
local LIGHT: Palette = {
	words = Color3.fromRGB(58, 36, 20),
	control = Color3.fromRGB(204, 62, 8),
	action = Color3.fromRGB(16, 92, 196),
}
local DARK: Palette = {
	words = Color3.fromRGB(250, 251, 255),
	control = Color3.fromRGB(255, 208, 60),
	action = Color3.fromRGB(150, 255, 130),
}

local function channel(c: number): number
	return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
end

--[[ A colour's relative luminance, 0 (black) to 1 (white), as WCAG has it. ]]
function PromptText.luminance(colour: Color3): number
	return 0.2126 * channel(colour.R) + 0.7152 * channel(colour.G) + 0.0722 * channel(colour.B)
end

--[[ The contrast between two colours, 1 (none) to 21. ]]
function PromptText.contrast(a: Color3, b: Color3): number
	local la, lb = PromptText.luminance(a), PromptText.luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

--[[ Whether a ground is light enough to want dark words. ]]
function PromptText.isLight(ground: Color3): boolean
	return PromptText.luminance(ground) > 0.4
end

--[[ The colours to write in on this ground. ]]
function PromptText.palette(ground: Color3): Palette
	return if PromptText.isLight(ground) then LIGHT else DARK
end

--[[ Splits a prompt into its runs: plain words, controls and actions, in
     order. A mark left open runs to the end as plain words. ]]
function PromptText.runs(text: string): { { kind: "plain" | "control" | "action", text: string } }
	local out: { { kind: "plain" | "control" | "action", text: string } } = {}
	local at = 1
	while at <= #text do
		local open = string.find(text, "[%[%*]", at)
		if not open then
			table.insert(out, { kind = "plain", text = string.sub(text, at) })
			break
		end
		local closer = if string.sub(text, open, open) == "[" then "]" else "*"
		local close = string.find(text, closer, open + 1, true)
		if not close then
			table.insert(out, { kind = "plain", text = string.sub(text, at) })
			break
		end
		if open > at then
			table.insert(out, { kind = "plain", text = string.sub(text, at, open - 1) })
		end
		table.insert(out, {
			kind = if closer == "]" then "control" else "action",
			text = string.sub(text, open + 1, close - 1),
		})
		at = close + 1
	end
	return out
end

--[[ Whether every mark in a prompt is closed, and none is empty. ]]
function PromptText.valid(text: string): boolean
	for _, run in PromptText.runs(text) do
		if run.kind == "plain" then
			if string.find(run.text, "[%[%]%*]") then
				return false
			end
		elseif #run.text == 0 then
			return false
		end
	end
	return true
end

--[[ The prompt with its marks dropped: what is read. ]]
function PromptText.plain(text: string): string
	local parts = {}
	for _, run in PromptText.runs(text) do
		table.insert(parts, run.text)
	end
	return table.concat(parts)
end

local function escape(text: string): string
	local out = string.gsub(text, "&", "&amp;")
	out = string.gsub(out, "<", "&lt;")
	out = string.gsub(out, ">", "&gt;")
	return out
end

local function hex(colour: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(colour.R * 255 + 0.5),
		math.floor(colour.G * 255 + 0.5),
		math.floor(colour.B * 255 + 0.5)
	)
end

--[[ The prompt as RichText: its controls and actions in the palette's two
     colours, the rest left to the label's own. ]]
function PromptText.rich(text: string, palette: Palette): string
	local parts = {}
	for _, run in PromptText.runs(text) do
		if run.kind == "plain" then
			table.insert(parts, escape(run.text))
		else
			local colour = if run.kind == "control" then palette.control else palette.action
			table.insert(
				parts,
				string.format('<font color="%s">%s</font>', hex(colour), escape(run.text))
			)
		end
	end
	return table.concat(parts)
end

return PromptText
