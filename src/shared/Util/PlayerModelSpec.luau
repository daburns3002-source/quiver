--!strict
--[[
	Reads the player bodies (`Config/PlayerModels`, one module per class and
	look, e.g. `RangerFemale`) for `Run/PlayerBody` and the spec test.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Piece = {
	name: string,
	--[[ Accessories only: the body part it hangs off. ]]
	parent: string?,
	meshId: string,
	textureId: string,
	size: { number },
	position: { number },
}

export type Spec = {
	class: string,
	look: string,
	uploaded: boolean,
	hipHeight: number,
	height: number,
	parts: { Piece },
	accessories: { Piece },
	joints: { [string]: { number } },
}

local PlayerModelSpec = {}

--[[ The 15 R15 body parts. ]]
PlayerModelSpec.R15 = table.freeze({
	"LowerTorso",
	"UpperTorso",
	"Head",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
})

--[[ Each R15 joint: the part it hangs from and the part it moves. Its
     attachments are `<joint>RigAttachment` in both. ]]
local JOINTS: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "LowerTorso" },
	Waist = { "LowerTorso", "UpperTorso" },
	Neck = { "UpperTorso", "Head" },
}
for _, side in { "Left", "Right" } do
	JOINTS[side .. "Shoulder"] = { "UpperTorso", side .. "UpperArm" }
	JOINTS[side .. "Elbow"] = { side .. "UpperArm", side .. "LowerArm" }
	JOINTS[side .. "Wrist"] = { side .. "LowerArm", side .. "Hand" }
	JOINTS[side .. "Hip"] = { "LowerTorso", side .. "UpperLeg" }
	JOINTS[side .. "Knee"] = { side .. "UpperLeg", side .. "LowerLeg" }
	JOINTS[side .. "Ankle"] = { side .. "LowerLeg", side .. "Foot" }
end
PlayerModelSpec.JOINTS = table.freeze(JOINTS)

--[[ The module name for a class and a look ("male" / "female"). ]]
function PlayerModelSpec.key(class: string, look: string): string
	return class .. string.upper(string.sub(look, 1, 1)) .. string.sub(look, 2)
end

local cache: { [string]: Spec } = {}
local missing: { [string]: boolean } = {}

function PlayerModelSpec.get(key: string): Spec?
	if cache[key] or missing[key] then
		return cache[key]
	end
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PlayerModels")
	local module = folder and folder:FindFirstChild(key)
	if module and module:IsA("ModuleScript") then
		cache[key] = (require :: any)(module) :: Spec
	else
		missing[key] = true
	end
	return cache[key]
end

--[[ Every body, by key. ]]
function PlayerModelSpec.all(): { [string]: Spec }
	local out: { [string]: Spec } = {}
	local folder = ReplicatedStorage.Shared.Config:FindFirstChild("PlayerModels")
	if folder then
		for _, module in folder:GetChildren() do
			local spec = PlayerModelSpec.get(module.Name)
			if spec then
				out[module.Name] = spec
			end
		end
	end
	return out
end

--[[ The body parts and accessories together. ]]
function PlayerModelSpec.pieces(spec: Spec): { Piece }
	local out = table.clone(spec.parts)
	for _, piece in spec.accessories do
		table.insert(out, piece)
	end
	return out
end

function PlayerModelSpec.part(spec: Spec, name: string): Piece?
	for _, piece in spec.parts do
		if piece.name == name then
			return piece
		end
	end
	return nil
end

--[[ The mesh ids of every uploaded body, to preload. ]]
function PlayerModelSpec.meshIds(): { string }
	local ids = {}
	for _, spec in PlayerModelSpec.all() do
		if spec.uploaded then
			for _, piece in PlayerModelSpec.pieces(spec) do
				table.insert(ids, piece.meshId)
			end
		end
	end
	return ids
end

return PlayerModelSpec
