--!strict
--[[
	Shared lobby station lifetime (owner, 2026-10-26: "E opens it").
	One nearest prompt owns E. Profiles and purchase outcomes stay server-owned.
]]
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Chunky = require(script.Parent.Chunky)
local Device = require(script.Parent.Parent.Device)
local GearAssets = require(ReplicatedStorage.Shared.Config.GearAssets)
local Kit = require(script.Parent.Kit)
local Lobby = require(ReplicatedStorage.Shared.Config.Lobby)
local LobbyHud = require(ReplicatedStorage.Shared.Config.LobbyHud)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Reveal = require(script.Parent.Reveal)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StationScreen = {}
export type Screen = {
	gui: ScreenGui,
	canvas: Frame,
	profile: SaveSchema.Profile?,
	draw: () -> (),
	open: () -> (),
	close: () -> (),
	isOpen: () -> boolean,
	connect: (RBXScriptSignal, (...any) -> ()) -> (),
	wallet: (Instance, number, number) -> (),
}
local active: Screen? = nil
local openingShortcut = false
-- A menu shortcut uses the existing public open API without changing station proximity prompts.
function StationScreen.openShortcut(open: () -> ())
	openingShortcut = true
	open()
	openingShortcut = false
end

--[[ The player's latest profile, shared by every station screen: one
     listener, so each screen has it however late it was made, and asked for
     afresh as the screens start (the one sent on join may already be gone). ]]
local latest: SaveSchema.Profile? = nil
local profileArrived = Instance.new("BindableEvent")
Remotes.event(Remotes.ProfileChanged).OnClientEvent:Connect(function(nextProfile)
	if type(nextProfile) == "table" then
		latest = nextProfile
		profileArrived:Fire(nextProfile)
	end
end)
task.spawn(function()
	-- until the server has the profile loaded, it answers nothing: keep asking
	for _ = 1, 20 do
		if latest then
			return
		end
		Remotes.event(Remotes.ProfileRequest):FireServer()
		task.wait(1)
	end
end)
--[[ `callback(profile)` now if the profile has come, and on every change:
     for the lobby's own wallet (`UI/LobbyHud`). ]]
function StationScreen.onProfile(callback: (SaveSchema.Profile) -> ()): RBXScriptConnection
	if latest then
		task.spawn(callback, latest)
	end
	return profileArrived.Event:Connect(callback)
end

--[[ Whether this screen is laid out for touch: held upright, or a phone. ]]
function StationScreen.touchLayout(gui: GuiBase2d): boolean
	return gui.AbsoluteSize.Y > gui.AbsoluteSize.X or Device.isPhone()
end

function StationScreen.new(name: string, stationName: string, promptWords: string): Screen
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 115
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	-- clear: nothing darkens the screen behind (owner, 2026-10-26)
	dim.BackgroundTransparency = 1
	dim.Size = UDim2.fromScale(1, 1)
	dim.Active = true
	dim.Visible = false
	dim.Parent = gui
	local canvas = Kit.canvas(dim)
	local promptCanvas = Kit.canvas(gui)
	local connections: { RBXScriptConnection } = {}
	local dirty = false
	local fromShortcut = false
	local self: Screen
	self = {
		gui = gui,
		canvas = canvas,
		profile = nil,
		wallet = Kit.wallet,
		draw = function() end,
		open = function() end,
		close = function() end,
		isOpen = function()
			return dim.Visible
		end,
		connect = function(signal, callback)
			table.insert(connections, signal:Connect(callback))
		end,
	}
	self.close = function()
		if Reveal.busy() then
			return
		end
		dim.Visible = false
		fromShortcut = false
		player:SetAttribute(
			"InStation",
			if player:GetAttribute("ClassSelecting") == true then true else nil
		)
		canvas:ClearAllChildren()
		-- The aspect belongs to the canvas, so rebuild it after clearing content.
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 16 / 9
		aspect.Parent = canvas
		if active == self then
			active = nil
		end
	end
	local function draw()
		dirty = false
		for _, child in canvas:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local back = Kit.imageButton(canvas, GearAssets.buttons.back, self.close)
		Kit.put(back, 24, 24, 136, 104)
		self.wallet(
			canvas,
			if self.profile then self.profile.coins else 0,
			if self.profile then self.profile.gems else 0
		)
		self.draw()
	end
	self.open = function()
		if player:GetAttribute("ClassSelecting") == true then
			return
		end
		if Reveal.busy() then
			return
		end
		if active and active ~= self then
			active.close()
		end
		fromShortcut = openingShortcut or (active == self and fromShortcut)
		active = self
		dim.Visible = true
		-- the lobby music ducks while a station screen is open (`Fx/MusicFx`)
		player:SetAttribute("InStation", true)
		draw()
	end
	--[[ The station button. On a touch layout there is no E key and the
	     button is the way in: full width, 60 points tall, above the lobby's
	     PLAY (Fable's loop review item 3, 2026-11-11). Otherwise it stays on
	     the 16:9 sheet where it always was. Built again when the screen
	     changes shape. ]]
	local promptLayer = Instance.new("Frame")
	promptLayer.Name = "PromptLayer"
	promptLayer.BackgroundTransparency = 1
	promptLayer.Size = UDim2.fromScale(1, 1)
	promptLayer.Parent = gui
	local prompt: GuiObject? = nil
	local promptShown = false
	local function buildPrompt()
		if prompt then
			prompt:Destroy()
		end
		local made: GuiObject
		if StationScreen.touchLayout(gui) then
			local size = gui.AbsoluteSize
			local sheet = Chunky.pointSheet(promptLayer, math.max(size.X, 1), math.max(size.Y, 1))
			-- sheet pixels to a point (`Chunky.pointSheet`)
			local k = 2
			local g = LobbyHud.gutter
			local w = math.min(sheet.w - g * 2 * k, LobbyHud.barWidth * k)
			local h = LobbyHud.stationHeight * k
			local above = (g + LobbyHud.playHeight + LobbyHud.stackGap) * k
			made = Chunky.button(
				sheet,
				promptWords,
				Chunky.gold,
				(sheet.w - w) / 2,
				sheet.h - above - h,
				w,
				h,
				self.open
			)
		else
			made = Kit.button(
				promptCanvas,
				promptWords .. (if UserInputService.KeyboardEnabled then " [E]" else ""),
				Kit.gold,
				self.open
			)
			Kit.put(made, 720, 952, 480, 104)
		end
		made.Name = "Prompt"
		made.Visible = promptShown
		prompt = made
	end
	self.connect(gui:GetPropertyChangedSignal("AbsoluteSize"), buildPrompt)
	buildPrompt()
	self.connect(player.CharacterAppearanceLoaded, function()
		dirty = true
	end)
	local characterConnections: { RBXScriptConnection } = {}
	local function watchCharacter(character: Model)
		for _, connection in characterConnections do
			connection:Disconnect()
		end
		table.clear(characterConnections)
		dirty = true
		local function changed(child: Instance)
			if child.Name == "HeldWeapon" or child:IsA("Accessory") then
				dirty = true
			end
		end
		table.insert(characterConnections, character.ChildAdded:Connect(changed))
		table.insert(characterConnections, character.ChildRemoved:Connect(changed))
	end
	self.connect(player.CharacterAdded, watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
	gui.Destroying:Once(function()
		for _, connection in characterConnections do
			connection:Disconnect()
		end
	end)
	self.connect(player:GetAttributeChangedSignal("Class"), function()
		dirty = true
	end)
	local station: Vector3? = nil
	for _, entry in Lobby.stations do
		if entry.piece == stationName then
			station = Lobby.origin + Vector3.new(entry.at.X, 0, entry.at.Y)
		end
	end
	local function nearby(): boolean
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if
			not root
			or player:GetAttribute("ClassSelecting") == true
			or Workspace:GetAttribute("InLobby") ~= true
			or player.PlayerGui:FindFirstChild("StoryCutscene")
			or player.PlayerGui:FindFirstChild("IntroCutscene")
		then
			return false
		end
		local delta = root.Position - Lobby.origin
		if math.abs(delta.X) > Lobby.size.X / 2 + 8 or math.abs(delta.Z) > Lobby.size.Y / 2 + 8 then
			return false
		end
		local flat = Vector3.new(root.Position.X, 0, root.Position.Z)
		if not station or (flat - station).Magnitude > 34 then
			return false
		end
		--[[ Every station that opens a screen, so the nearest one wins
		     whichever it is. The Dex Hall joined them on 2026-11-01; while
		     it was missing, its own prompt gave way to the others but
		     theirs never gave way to it. ]]
		for _, other in Lobby.stations do
			if
				other.piece == "Blacksmith"
				or other.piece == "EggHatchery"
				or other.piece == "GearStation"
				or other.piece == "DexHall"
			then
				local position = Lobby.origin + Vector3.new(other.at.X, 0, other.at.Y)
				if
					other.piece ~= stationName
					and (flat - position).Magnitude < (flat - station).Magnitude
				then
					return false
				end
			end
		end
		return true
	end
	local function received(nextProfile: SaveSchema.Profile)
		self.profile = nextProfile
		for _, child in canvas:GetChildren() do
			if child.Name == "Wallet" then
				child:Destroy()
			end
		end
		self.wallet(canvas, nextProfile.coins, nextProfile.gems)
		dirty = true
	end
	self.connect(profileArrived.Event, received)
	if latest then
		received(latest)
	end
	self.connect(UserInputService.InputBegan, function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E and promptShown then
			self.open()
		elseif input.KeyCode == Enum.KeyCode.Escape and active == self then
			self.close()
		end
	end)
	local wasNear = false
	self.connect(RunService.RenderStepped, function()
		if dirty and dim.Visible and not Reveal.busy() then
			draw()
		end
		local near = nearby()
		promptShown = near and active == nil
		if prompt then
			prompt.Visible = promptShown
		end
		-- the Blacksmith opens by itself as the player walks up to him
		-- (owner, 2026-10-26); closed, it waits until they walk away and back
		if near and not wasNear and stationName == "Blacksmith" and active == nil then
			self.open()
		end
		wasNear = near
		if dim.Visible and not near and not fromShortcut then
			self.close()
		end
		-- DeviceSafeInsets handles the notch; Roblox's top bar remains outside the sheet.
		local inset = GuiService:GetGuiInset()
		dim.Position = UDim2.fromScale(0, inset.Y / math.max(gui.AbsoluteSize.Y, 1))
		dim.Size = UDim2.fromScale(1, 1 - inset.Y / math.max(gui.AbsoluteSize.Y, 1))
	end)
	gui.Destroying:Once(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		if active == self then
			active = nil
		end
	end)
	return self
end
return StationScreen
