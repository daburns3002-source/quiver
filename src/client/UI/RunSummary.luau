--!strict
--[[
	What you built, shown when the run ends.

	The draft only means something if the player can see what it added up to.
	Mid-run they are reading cards one at a time under pressure and never see
	the whole shape of the thing; this is the one moment they can, and it is
	also the moment they are deciding whether to go again.

	So it answers three questions in that order: how far did I get, what did I
	end up with, and is that a build I want to try differently. Nothing here
	is interactive — the run restarts on its own timer, and a button the
	player had to find would just delay that.

	Art is a placeholder. Shape and content first.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)

local RunSummary = {}

export type Entry = { id: string, count: number }

export type Summary = {
	won: boolean,
	reached: number,
	total: number,
	--[[ "Room" or "Wave", after the stage's mode. ]]
	unit: string,
	level: number,
	abilities: { Entry },
}

local gui: ScreenGui? = nil
local heading: TextLabel? = nil
local subheading: TextLabel? = nil
local list: Frame? = nil

local WON_COLOUR = Color3.fromRGB(150, 230, 180)
local DIED_COLOUR = Color3.fromRGB(236, 120, 110)

function RunSummary.stop()
	if gui then
		gui:Destroy()
		gui = nil
	end

	heading = nil
	subheading = nil
	list = nil
end

function RunSummary.start()
	RunSummary.stop()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local created = Instance.new("ScreenGui")
	created.Name = "RunSummary"
	created.IgnoreGuiInset = true
	created.ResetOnSpawn = false
	--[[ Above the HUD but below the card screen, which can never be open at
	     the same time: a run that has ended owes no more cards. ]]
	created.DisplayOrder = 80
	created.Enabled = false
	created.Parent = playerGui
	gui = created

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
	shade.BackgroundTransparency = 0.3
	shade.BorderSizePixel = 0
	shade.Parent = created

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -56, 0.62, 0)
	panel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = created

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 16)
	panelCorner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Heading"
	title.Size = UDim2.new(1, -32, 0, 52)
	title.Position = UDim2.fromOffset(16, 18)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Text = ""
	title.Parent = panel
	heading = title

	local sub = Instance.new("TextLabel")
	sub.Name = "Subheading"
	sub.Size = UDim2.new(1, -32, 0, 26)
	sub.Position = UDim2.fromOffset(16, 74)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(198, 206, 220)
	sub.Text = ""
	sub.Parent = panel
	subheading = sub

	local holder = Instance.new("Frame")
	holder.Name = "Abilities"
	holder.Position = UDim2.fromOffset(16, 112)
	holder.Size = UDim2.new(1, -32, 1, -128)
	holder.BackgroundTransparency = 1
	holder.Parent = panel
	list = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = holder
end

--[[ Only the rows, never the layout. `ClearAllChildren` here would take the
     UIListLayout with them and stack every line in one place — which is
     exactly what it did to the card screen. See docs/FIXES.md. ]]
local function clearRows()
	local holder = list
	if not holder then
		return
	end

	for _, child in holder:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
end

local function addRow(index: number, entry: Entry, holder: Frame)
	local ability = Abilities.byId[entry.id]

	local row = Instance.new("TextLabel")
	row.Name = `Row{index}`
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.Font = Enum.Font.GothamMedium
	row.TextScaled = true
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.TextColor3 = Color3.fromRGB(236, 240, 248)
	--[[ The count only when it is more than one. "Front Arrow x1" reads as a
	     database row; "Front Arrow" reads as something you have. ]]
	row.Text = if entry.count > 1
		then `{if ability then ability.name else entry.id}   ×{entry.count}`
		else (if ability then ability.name else entry.id)
	row.Parent = holder

	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 20
	size.Parent = row
end

function RunSummary.show(summary: Summary)
	local created, title, sub, holder = gui, heading, subheading, list
	if not created or not title or not sub or not holder then
		return
	end

	clearRows()

	title.Text = if summary.won then "Run Complete" else "Run Over"
	title.TextColor3 = if summary.won then WON_COLOUR else DIED_COLOUR
	sub.Text = `{summary.unit} {summary.reached} of {summary.total}   ·   Level {summary.level}`

	if #summary.abilities == 0 then
		--[[ A run that ended before its first card still gets a summary. Left
		     blank it reads as the screen having failed. ]]
		addRow(1, { id = "", count = 1 }, holder)
		local only = holder:FindFirstChild("Row1") :: TextLabel?
		if only then
			only.Text = "No abilities drafted"
			only.TextColor3 = Color3.fromRGB(150, 158, 172)
		end
	else
		for index, entry in summary.abilities do
			addRow(index, entry, holder)
		end
	end

	created.Enabled = true
end

function RunSummary.hide()
	if gui then
		gui.Enabled = false
	end

	clearRows()
end

return RunSummary
