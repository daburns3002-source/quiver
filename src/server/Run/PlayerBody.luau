--!strict
--[[
	Dresses each player as their class and look: the Tripo bodies
	(`Config/PlayerModels`, the class select screen's eight figures as R15
	rigs) in place of their own Roblox avatar. Until a body's meshes are
	uploaded (`uploaded = false`) the player keeps their own avatar.

	The body is built on a copy of the character, never on the live one, and
	the copy then becomes the player's character: every client script
	(Animate, the camera, weapon poses) starts on the finished R15 rig rather
	than watching its joints be torn out and rebuilt. That fires
	`CharacterAdded` a second time; the copy carries `Body`, so it is left
	alone, and the game binds it as any new body.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Config.Classes)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MeshTemplates = require(script.Parent.Parent.Util.MeshTemplates)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local PlayerModelSpec = require(ReplicatedStorage.Shared.Util.PlayerModelSpec)
local RunSession = require(script.Parent.RunSession)

local log = Log.forTag("PlayerBody")

local PlayerBody = {}

--[[ The attribute naming the body a character wears (`PlayerModels` key). ]]
PlayerBody.ATTRIBUTE = "Body"

--[[ Seconds to wait for Roblox to finish putting the player's own avatar
     on, so its accessories do not arrive on the body after it is dressed. ]]
local APPEARANCE_WAIT = 6

local templates: { [string]: MeshPart } = {}
local busy: { [Player]: boolean } = {}

--[[ Loads every uploaded body mesh. Once, at server start. ]]
function PlayerBody.preload()
	templates = MeshTemplates.load(PlayerModelSpec.meshIds())
end

--[[ The body key the player should wear now, or nil to keep their own
     avatar (no look picked yet, or the body not uploaded). ]]
local function wanted(player: Player): string?
	local session = RunSession.get(player)
	local profile = PlayerData.get(player)
	local class = session and session.loadout.class
	local look = profile and profile.look
	if not class or not Classes[class] or type(look) ~= "string" then
		return nil
	end
	local key = PlayerModelSpec.key(class, look)
	local spec = PlayerModelSpec.get(key)
	if not spec or not spec.uploaded then
		return nil
	end
	for _, piece in PlayerModelSpec.pieces(spec) do
		if not templates[piece.meshId] then
			return nil
		end
	end
	return key
end

local function vec(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local KEEP = { Humanoid = true, Script = true, LocalScript = true, ModuleScript = true }

local function meshPart(piece: PlayerModelSpec.Piece, like: BasePart?): MeshPart
	local part = templates[piece.meshId]:Clone()
	part.Name = piece.name
	part.Size = vec(piece.size)
	part.TextureID = piece.textureId
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = false
	part.Material = Enum.Material.Plastic
	part.Color = Color3.new(1, 1, 1)
	if like then
		part.CanCollide = like.CanCollide
		part.CanQuery = like.CanQuery
		part.CanTouch = like.CanTouch
		part.Massless = like.Massless
		part.CollisionGroup = like.CollisionGroup
		part.CastShadow = like.CastShadow
	end
	return part
end

local function attach(part: BasePart, name: string, at: Vector3, rotation: CFrame?)
	local existing = part:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.CFrame = CFrame.new(at) * (rotation or CFrame.identity)
	attachment.Parent = part
end

--[[ The body built on a copy of `character`, not yet anyone's. ]]
local function build(character: Model, key: string): Model?
	local spec = PlayerModelSpec.get(key) :: PlayerModelSpec.Spec
	character.Archivable = true
	local copy = character:Clone()
	character.Archivable = false
	if not copy then
		return nil
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid")
	local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		copy:Destroy()
		return nil
	end
	-- the body's own sizes, not the avatar's body scales
	humanoid.AutomaticScalingEnabled = false

	local old: { [string]: BasePart } = {}
	for _, child in copy:GetChildren() do
		if child == root then
			continue
		end
		if child:IsA("BasePart") then
			old[child.Name] = child
			child.Parent = nil
		elseif not KEEP[child.ClassName] then
			-- accessories, clothes, body colours, a held weapon
			child:Destroy()
		end
	end

	local rootFrame = root.CFrame
	local made: { [string]: BasePart } = { HumanoidRootPart = root }
	for _, piece in spec.parts do
		local part = meshPart(piece, old[piece.name])
		part.CFrame = rootFrame * CFrame.new(vec(piece.position))
		made[piece.name] = part
	end
	for _, part in old do
		part:Destroy()
	end

	-- R15 rig attachments: each joint's place in both parts it joins
	for joint, place in spec.joints do
		local pair = PlayerModelSpec.JOINTS[joint]
		for _, name in pair do
			local part = made[name]
			local centre = if name == "HumanoidRootPart"
				then Vector3.zero
				else vec((PlayerModelSpec.part(spec, name) :: PlayerModelSpec.Piece).position)
			attach(part, joint .. "RigAttachment", vec(place) - centre)
		end
	end
	-- the usual accessory places, for anything that looks for them
	local head = PlayerModelSpec.part(spec, "Head") :: PlayerModelSpec.Piece
	attach(made.Head, "HatAttachment", Vector3.new(0, head.size[2] / 2, 0))
	attach(made.Head, "FaceFrontAttachment", Vector3.new(0, 0, -head.size[3] / 2))
	local torso = PlayerModelSpec.part(spec, "UpperTorso") :: PlayerModelSpec.Piece
	attach(made.UpperTorso, "NeckAttachment", vec(spec.joints.Neck) - vec(torso.position))
	attach(made.UpperTorso, "BodyBackAttachment", Vector3.new(0, 0, torso.size[3] / 2))
	for _, side in { "Left", "Right" } do
		local hand = PlayerModelSpec.part(spec, side .. "Hand") :: PlayerModelSpec.Piece
		attach(
			made[side .. "Hand"],
			side .. "GripAttachment",
			Vector3.new(0, -hand.size[2] / 4, 0),
			CFrame.Angles(-math.pi / 2, 0, 0)
		)
	end

	for _, piece in spec.parts do
		made[piece.name].Parent = copy
	end

	for _, piece in spec.accessories do
		local parentPiece =
			PlayerModelSpec.part(spec, piece.parent :: string) :: PlayerModelSpec.Piece
		local parent = made[piece.parent :: string]
		local accessory = Instance.new("Accessory")
		accessory.Name = piece.name
		local handle = meshPart(piece, nil)
		handle.Name = "Handle"
		handle.Massless = true
		handle.CanQuery = false
		local offset = CFrame.new(vec(piece.position) - vec(parentPiece.position))
		handle.CFrame = parent.CFrame * offset
		handle.Parent = accessory
		local weld = Instance.new("Weld")
		weld.Name = "AccessoryWeld"
		weld.Part0 = handle
		weld.Part1 = parent
		weld.C1 = offset
		weld.Parent = handle
		accessory.Parent = copy
	end

	humanoid.HipHeight = spec.hipHeight
	copy:SetAttribute(PlayerBody.ATTRIBUTE, key)
	return copy
end

local function dress(player: Player)
	while true do
		local character = player.Character
		local key = wanted(player)
		if not character or not key or character:GetAttribute(PlayerBody.ATTRIBUTE) == key then
			return
		end
		if not player:HasAppearanceLoaded() then
			local loaded = false
			local connection = player.CharacterAppearanceLoaded:Connect(function()
				loaded = true
			end)
			local start = os.clock()
			while not loaded and os.clock() - start < APPEARANCE_WAIT and player.Parent do
				task.wait(0.1)
			end
			connection:Disconnect()
			continue -- the character or the wish may have changed meanwhile
		end
		local oldHumanoid = character:FindFirstChildOfClass("Humanoid")
		if not oldHumanoid or oldHumanoid.Health <= 0 then
			return
		end
		local ok, body = pcall(build, character, key)
		if not ok or not body then
			log.warn("could not dress %s as %s: %s", player.Name, key, tostring(body))
			return
		end
		if player.Character ~= character or wanted(player) ~= key then
			body:Destroy()
			continue
		end
		local humanoid = body:FindFirstChildOfClass("Humanoid") :: Humanoid
		body:PivotTo(character:GetPivot())
		body.Parent = Workspace
		humanoid:BuildRigFromAttachments()
		humanoid.Health = math.min(oldHumanoid.Health, humanoid.MaxHealth)
		player.Character = body
		character:Destroy()
		log.info("%s wears %s", player.Name, key)
	end
end

--[[ Puts the player in the body for their class and look, if it differs
     from what they wear. Safe to call often: on every new character and
     whenever the class or look may have changed. ]]
function PlayerBody.refresh(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	task.defer(function()
		xpcall(dress, function(err)
			log.warn("dressing %s failed: %s", player.Name, tostring(err))
		end, player)
		busy[player] = nil
	end)
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

return PlayerBody
