--!strict
--[[
	The choose-one-of-three card screen.

	Renders an offer the server sent and reports back an index. It decides
	nothing: it does not know what an ability does, cannot tell whether one is
	available, and sends no ability id — only "the nth card". The server
	validates even that against the offer it holds. See CLAUDE.md,
	non-negotiable 2.

	Built to be read in about a second. The run is paused behind it, but a
	paused run still has a fan of projectiles frozen on screen behind the
	cards, and the player's attention is still partly on that. So: three
	cards, one line of name, one line of what it does, and a colour per
	category so a repeat offer is recognisable before it is read.

	Portrait-first. The cards stack vertically and fill the width, because on
	a phone three side-by-side cards are three columns of unreadable text.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)

local AbilityCards = {}

--[[ One per category. Not decoration: a player who has seen Front Arrow twice
     should recognise it by colour before reading the name, which is most of
     what makes a draft fast after the first few. ]]
local CATEGORY_COLOURS: { [string]: Color3 } = {
	Count = Color3.fromRGB(255, 196, 92),
	Pattern = Color3.fromRGB(140, 190, 255),
	Flight = Color3.fromRGB(150, 230, 180),
	OnHit = Color3.fromRGB(255, 130, 120),
	Stats = Color3.fromRGB(226, 182, 255),
	Defensive = Color3.fromRGB(120, 230, 230),
}

local gui: ScreenGui? = nil
local cardHolder: Frame? = nil
local connections: { RBXScriptConnection } = {}

--[[ Set by `start`. Called with the index the player tapped. ]]
local onChosen: ((number) -> ())? = nil

--[[ Guards against a double tap sending two choices for one offer. The server
     would reject the second, but the screen would already have closed and the
     player would see their second choice vanish. ]]
local resolved = false

local function clearCards()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	--[[
		Only the cards.

		`ClearAllChildren` took the UIListLayout with them, so every offer
		after the first — and the first one too, since `show` clears before it
		builds — laid all three cards at the same position, one on top of
		another. The player saw a single card and two invisible ones stacked
		behind it.
	]]
	if cardHolder then
		for _, child in cardHolder:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end
end

function AbilityCards.stop()
	clearCards()

	if gui then
		gui:Destroy()
		gui = nil
	end

	cardHolder = nil
	onChosen = nil
end

function AbilityCards.start(chosen: (number) -> ())
	AbilityCards.stop()
	onChosen = chosen

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local created = Instance.new("ScreenGui")
	created.Name = "AbilityCards"
	created.IgnoreGuiInset = true
	created.ResetOnSpawn = false
	--[[ Above everything, including the hit vignette: nothing behind this is
	     actionable while it is up. ]]
	created.DisplayOrder = 100
	created.Enabled = false
	created.Parent = playerGui
	gui = created

	--[[ A dimmer rather than a solid backdrop. The frozen room behind is worth
	     seeing — what is about to kill you is context for which card to
	     take. ]]
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 8, 14)
	shade.BackgroundTransparency = 0.35
	shade.BorderSizePixel = 0
	shade.Parent = created

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 54)
	title.Position = UDim2.new(0, 20, 0.06, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 244, 214)
	title.TextStrokeTransparency = 0.6
	title.Text = "Level Up"
	title.Parent = created

	local holder = Instance.new("Frame")
	holder.Name = "Cards"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.55)
	holder.Size = UDim2.new(1, -48, 0.66, 0)
	holder.BackgroundTransparency = 1
	holder.Parent = created
	cardHolder = holder

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 14)
	layout.Parent = holder
end

local function buildCard(index: number, id: string, holder: Frame)
	--[[ An unknown id is a client reading a newer server, or a stripped
	     Config. Draw a usable card anyway: refusing to render would strand the
	     player behind a screen they cannot dismiss. ]]
	local ability = Abilities.byId[id]
	local colour = if ability then CATEGORY_COLOURS[ability.category] else nil

	local card = Instance.new("TextButton")
	card.Name = `Card{index}`
	card.LayoutOrder = index
	card.Size = UDim2.new(1, 0, 0, 108)
	card.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	card.BackgroundTransparency = 0.08
	card.AutoButtonColor = false
	card.Text = ""
	card.Parent = holder

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = colour or Color3.fromRGB(150, 150, 150)
	stroke.Transparency = 0.15
	stroke.Parent = card

	--[[ A colour bar down the leading edge, which survives being glanced at
	     from the corner of the eye in a way a tinted border does not. ]]
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(0, 6, 1, -20)
	flash.Position = UDim2.fromOffset(10, 10)
	flash.BackgroundColor3 = colour or Color3.fromRGB(150, 150, 150)
	flash.BorderSizePixel = 0
	flash.Parent = card

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(1, 0)
	flashCorner.Parent = flash

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -40, 0, 34)
	name.Position = UDim2.fromOffset(28, 16)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Color3.fromRGB(255, 250, 240)
	name.Text = if ability then ability.name else id
	name.Parent = card

	local description = Instance.new("TextLabel")
	description.Size = UDim2.new(1, -48, 0, 44)
	description.Position = UDim2.fromOffset(28, 52)
	description.BackgroundTransparency = 1
	description.Font = Enum.Font.Gotham
	description.TextScaled = true
	description.TextWrapped = true
	description.TextXAlignment = Enum.TextXAlignment.Left
	description.TextColor3 = Color3.fromRGB(198, 206, 220)
	description.Text = if ability then ability.description else "Unknown ability."
	description.Parent = card

	local descriptionSize = Instance.new("UITextSizeConstraint")
	descriptionSize.MaxTextSize = 18
	descriptionSize.Parent = description

	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MaxTextSize = 26
	nameSize.Parent = name

	table.insert(
		connections,
		card.MouseButton1Down:Connect(function()
			--[[ One choice per offer, whatever the player's fingers do. ]]
			if resolved then
				return
			end
			resolved = true

			local handler = onChosen
			if handler then
				handler(index)
			end
		end)
	)
end

--[[ Shows an offer. `level` is the level just reached, purely as a heading. ]]
function AbilityCards.show(offer: { string }, level: number)
	local created = gui
	local holder = cardHolder

	if not created or not holder then
		return
	end

	clearCards()
	resolved = false

	local title = created:FindFirstChild("Title")
	if title and title:IsA("TextLabel") then
		title.Text = `Level {level}`
	end

	for index, id in offer do
		buildCard(index, id, holder)
	end

	--[[ Shown fully formed, with no entrance animation. Dealing the cards in
	     one at a time looks better and costs the player the first third of a
	     second of reading time — which they are paying for with a paused run,
	     so it is not mine to spend. ]]
	created.Enabled = true
end

--[[ Hides the screen. Called when the server confirms a grant, and on death,
     so a card screen can never outlive the run that owed it. ]]
function AbilityCards.hide()
	resolved = true

	if gui then
		gui.Enabled = false
	end

	clearCards()
end

return AbilityCards
