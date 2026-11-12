--!strict
--[[
	Dresses a character in its class's armour set (`Config/ClassOutfits`,
	Outfit C: owner, 2026-11-12).

	One module for every place a class is seen: the server dresses the
	character for a run (`Main`, beside the weapon in hand), and the client
	dresses the copies it draws on the class select cards and the Gear
	portrait (`GearScreen.portrait`). So it lives in Shared and touches only
	the model it is given.

	Dressing a character:
	- hides the avatar's own accessories, hair and layered clothing with
	  them, so only the face shows; each remembers how it looked and is put
	  back when the set comes off;
	- with `standardise`, sets the avatar's scale values to the standard
	  proportions the sets are sized for (`ClassOutfits.scales`);
	- welds every piece to its R15 body part: massless, never colliding,
	  answering a raycast or touching, like the weapon in hand, so the set
	  cannot change how the body moves or what hits it. A piece is stretched
	  to a body part larger than the standard one, and again whenever its
	  size changes, so the body never pokes through; it is never shrunk.

	A piece is its imported mesh when the server has made its template
	(`ReplicatedStorage.ClassOutfitMeshes/<Class>/<Piece>`,
	`Server/Combat/OutfitMeshes`), its blocks until then.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassOutfits = require(ReplicatedStorage.Shared.Config.ClassOutfits)

local ClassOutfit = {}

--[[ The model in the character that holds the pieces; its `Class`
     attribute is the set worn. ]]
ClassOutfit.NAME = "ClassOutfit"
--[[ The folder of mesh templates in ReplicatedStorage. ]]
ClassOutfit.MESHES = "ClassOutfitMeshes"

--[[ On anything of the avatar's this hid: how it was before. ]]
local HID = "OutfitHid"
--[[ On a scale value this changed: what it was before. ]]
local WAS = "OutfitWas"

--[[ How much a piece made for a body part of `standard` size is stretched
     to sit on one of `size`, per axis, kept inside `ClassOutfits.stretch`. ]]
function ClassOutfit.ratio(size: Vector3, standard: Vector3): Vector3
	local limit = ClassOutfits.stretch
	local function axis(now: number, usual: number): number
		if usual <= 0 then
			return 1
		end
		return math.clamp(now / usual, limit.min, limit.max)
	end
	return Vector3.new(axis(size.X, standard.X), axis(size.Y, standard.Y), axis(size.Z, standard.Z))
end

--[[ The set `character` wears, if any. ]]
function ClassOutfit.worn(character: Model): string?
	local outfit = character:FindFirstChild(ClassOutfit.NAME)
	local class = outfit and outfit:GetAttribute("Class")
	return if type(class) == "string" then class else nil
end

local function hideAccessory(accessory: Instance)
	for _, item in accessory:GetDescendants() do
		if item:IsA("BasePart") or item:IsA("Decal") then
			if item:GetAttribute(HID) == nil then
				item:SetAttribute(HID, item.Transparency)
			end
			(item :: any).Transparency = 1
		elseif
			item:IsA("ParticleEmitter")
			or item:IsA("Trail")
			or item:IsA("Beam")
			or item:IsA("Light")
			or item:IsA("Fire")
			or item:IsA("Smoke")
			or item:IsA("Sparkles")
		then
			local effect = item :: any
			if item:GetAttribute(HID) == nil then
				item:SetAttribute(HID, effect.Enabled == true)
			end
			effect.Enabled = false
		end
	end
end

--[[ Everything `hideAccessory` hid, as it was. ]]
local function showAccessories(character: Model)
	for _, item in character:GetDescendants() do
		local was = item:GetAttribute(HID)
		if was == nil then
			continue
		end
		if type(was) == "number" and (item:IsA("BasePart") or item:IsA("Decal")) then
			(item :: any).Transparency = was
		elseif type(was) == "boolean" then
			(item :: any).Enabled = was
		end
		item:SetAttribute(HID, nil)
	end
end

local function standardise(humanoid: Humanoid)
	for name, value in ClassOutfits.scales do
		local scale = humanoid:FindFirstChild(name)
		if scale and scale:IsA("NumberValue") then
			if scale:GetAttribute(WAS) == nil then
				scale:SetAttribute(WAS, scale.Value)
			end
			scale.Value = value
		end
	end
end

local function restoreScales(humanoid: Humanoid)
	for name in ClassOutfits.scales do
		local scale = humanoid:FindFirstChild(name)
		local was = scale and scale:GetAttribute(WAS)
		if scale and scale:IsA("NumberValue") and type(was) == "number" then
			scale.Value = was
			scale:SetAttribute(WAS, nil)
		end
	end
end

--[[ The server's template for a piece's mesh, when it has loaded. ]]
local function meshFor(class: string, piece: ClassOutfits.Piece): MeshPart?
	if not piece.meshId or piece.meshId == "" or not piece.size or not piece.at then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(ClassOutfit.MESHES)
	local set = folder and folder:FindFirstChild(class)
	local template = set and set:FindFirstChild(piece.name)
	return if template and template:IsA("MeshPart") then template else nil
end

--[[ One solid of a piece: the part, and its size and place on the standard
     body. ]]
type Solid = { part: BasePart, weld: Weld, size: Vector3, at: Vector3, turn: CFrame }

local function prepare(part: BasePart, body: BasePart)
	part.Anchored = body.Anchored
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

--[[ Puts the set on `character`, replacing any it wore. `standardise` also
     sets the avatar to the standard proportions: for a character in the
     world, on the server. A class with no set, or a character that is not
     R15, is left as its own avatar. ]]
function ClassOutfit.dress(character: Model, class: string, toStandard: boolean?)
	local set = ClassOutfits.sets[class]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not set or not character:FindFirstChild("UpperTorso") then
		ClassOutfit.undress(character)
		return
	end
	if ClassOutfit.worn(character) == class then
		if toStandard and humanoid then
			standardise(humanoid)
		end
		return
	end
	--[[ Only the pieces go: what the last set hid stays hidden, and the
	     proportions stay as they are, so a change of class never flashes
	     the avatar's own hair. ]]
	local last = character:FindFirstChild(ClassOutfit.NAME)
	if last then
		last:Destroy()
	end
	if toStandard and humanoid then
		standardise(humanoid)
	end
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") then
			hideAccessory(child)
		end
	end

	local model = Instance.new("Model")
	model.Name = ClassOutfit.NAME
	model:SetAttribute("Class", class)

	local solids: { [BasePart]: { Solid } } = {}
	--[[ Sizes and seats a body part's solids for the size it is now. Only
	     the weld moves a solid once it is on a body in the world: writing
	     its CFrame there would move the whole character with it, and from
	     the server that is a teleport back to where the server last saw the
	     player. `place` is the first seating, before the set is parented,
	     and an anchored copy (a portrait) has no weld to do it. ]]
	local function fit(body: BasePart, place: boolean)
		local standard = ClassOutfits.standard[body.Name]
		local list = solids[body]
		if not standard or not list then
			return
		end
		local ratio = ClassOutfit.ratio(body.Size, standard.size)
		for _, solid in list do
			solid.part.Size = solid.size * ratio
			solid.weld.C0 = CFrame.new(solid.at * ratio) * solid.turn
			if place or solid.part.Anchored then
				solid.part.CFrame = body.CFrame * solid.weld.C0
			end
		end
	end
	local function add(body: BasePart, part: BasePart, size: Vector3, at: Vector3, turn: CFrame)
		prepare(part, body)
		local weld = Instance.new("Weld")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		local list = solids[body]
		if not list then
			list = {}
			solids[body] = list
		end
		table.insert(list, { part = part, weld = weld, size = size, at = at, turn = turn })
		part.Parent = model
	end

	for _, piece in set.pieces do
		local body = character:FindFirstChild(piece.part)
		if not body or not body:IsA("BasePart") then
			continue
		end
		local template = meshFor(class, piece)
		if template and piece.size and piece.at then
			local part = template:Clone()
			part.Name = piece.name
			-- white, so the model's own vertex colours show
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			local turn = if piece.turned then CFrame.Angles(0, math.pi, 0) else CFrame.new()
			add(body, part, piece.size, piece.at, turn)
		else
			for _, block in piece.blocks do
				local part = Instance.new("Part")
				part.Name = piece.name
				part.Color = block.colour
				part.Material = if block.glow
					then Enum.Material.Neon
					else Enum.Material.SmoothPlastic
				part.TopSurface = Enum.SurfaceType.Smooth
				part.BottomSurface = Enum.SurfaceType.Smooth
				add(body, part, block.size, block.at, CFrame.new())
			end
		end
	end

	local connections: { RBXScriptConnection } = {}
	for body in solids do
		fit(body, true)
		table.insert(
			connections,
			body:GetPropertyChangedSignal("Size"):Connect(function()
				fit(body, false)
			end)
		)
	end
	--[[ The avatar can still be arriving: an accessory that turns up late is
	     hidden like the rest, and a body part that is swapped under the set
	     gets the set put on again. ]]
	local again = false
	table.insert(
		connections,
		character.ChildAdded:Connect(function(child)
			if child:IsA("Accessory") then
				hideAccessory(child)
			elseif child:IsA("BasePart") and ClassOutfits.standard[child.Name] and not again then
				again = true
				task.defer(function()
					if model.Parent == character then
						model:Destroy()
						ClassOutfit.dress(character, class, toStandard)
					end
				end)
			end
		end)
	)
	model.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end)
	model.Parent = character
end

--[[ Takes the set off: the avatar's own accessories and proportions come
     back. ]]
function ClassOutfit.undress(character: Model)
	local outfit = character:FindFirstChild(ClassOutfit.NAME)
	if outfit then
		outfit:Destroy()
	end
	showAccessories(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		restoreScales(humanoid)
	end
end

return ClassOutfit
