--!strict
--[[
	The lobby's own HUD (Fable's loop review item 3, owner-approved
	2026-11-11): the coin and gem pills pinned to the top, a PLAY button that
	goes to the player's frontier portal, and the fight HUD (health, skill
	tray, XP bar and level) put away while in the lobby.

	Laid out in points, not on the 16:9 sheet, so an upright phone (the game
	is locked portrait) gets full-width buttons a finger can hit: PLAY across
	the bottom, the station button just above it (`UI/StationScreen`'s
	prompt). Sizes in `Config/LobbyHud`.

	PLAY asks the server (`Remotes.LobbyPlay`), which picks the portal
	(`Util/PlayPortal`) and walks the player into its mouth; its screen then
	opens as any portal's does, and START is still checked there.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Chunky = require(script.Parent.Chunky)
local Config = require(ReplicatedStorage.Shared.Config.LobbyHud)
local PortalScreen = require(script.Parent.PortalScreen)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SaveSchema = require(ReplicatedStorage.Shared.Util.SaveSchema)
local StationScreen = require(script.Parent.StationScreen)

local LobbyHud = {}

--[[ The fight HUD's screens, put away in the lobby and given back as it is
     left. Their own modules never hide them, so giving back is safe. ]]
local FIGHT_HUD = { "HealthBar", "RunBanner", "SkillBar" }

local started = false

function LobbyHud.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "LobbyHud"
	gui.ResetOnSpawn = false
	-- below Roblox's own top bar and inside the notch
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 110
	gui.Enabled = false
	gui.Parent = playerGui

	--[[ Chunky lays out in sheet pixels; these sheets are the whole screen
	     in points (`Chunky.pointSheet`, two sheet pixels to the point). ]]
	local canvas = Instance.new("Frame")
	canvas.Name = "Canvas"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.Parent = gui
	local wallet = Instance.new("Frame")
	wallet.Name = "Wallet"
	wallet.BackgroundTransparency = 1
	wallet.Size = UDim2.fromScale(1, 1)
	wallet.Parent = canvas

	local profile: SaveSchema.Profile? = nil
	local k = 2
	local g = Config.gutter
	local drawn = Vector2.zero
	local function sheetOn(frame: Frame): Chunky.Sheet
		local size = gui.AbsoluteSize
		return Chunky.pointSheet(frame, math.max(size.X, 1), math.max(size.Y, 1))
	end
	--[[ The pills: top right on a touch layout (the run HUD's MENU keeps the
	     left), top left on a wide one, where Roblox's player list has the
	     right and the station screens' own wallet stands. ]]
	local function drawWallet()
		wallet:ClearAllChildren()
		local sheet = sheetOn(wallet)
		local touch = StationScreen.touchLayout(gui)
		local h = (
			if touch then Config.pillHeight else math.clamp(gui.AbsoluteSize.Y * 0.055, 44, 60)
		) * k
		local x = if touch then sheet.w - g * k - h * 6.4 else g * k
		local p = profile
		Chunky.wallet(sheet, if p then p.coins else 0, if p then p.gems else 0, x, g * k / 2, h)
	end
	local function draw()
		drawn = gui.AbsoluteSize
		for _, child in canvas:GetChildren() do
			if child ~= wallet then
				child:Destroy()
			end
		end
		local sheet = sheetOn(canvas)
		local w, h
		if StationScreen.touchLayout(gui) then
			-- across the bottom, under the station button
			w = math.min(sheet.w - g * 2 * k, Config.barWidth * k)
			h = Config.playHeight * k
		else
			-- bottom left: a tablet's JUMP and SPRINT have the right corner
			h = math.clamp(gui.AbsoluteSize.Y * 0.09, 64, 96) * k
			w = h * 3.2
		end
		local x = if StationScreen.touchLayout(gui) then (sheet.w - w) / 2 else g * k
		local play = Chunky.button(
			sheet,
			"PLAY",
			Chunky.green,
			x,
			sheet.h - g * k - h,
			w,
			h,
			function()
				Remotes.event(Remotes.LobbyPlay):FireServer()
			end
		)
		play.Name = "Play"
		drawWallet()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(draw)
	draw()
	StationScreen.onProfile(function(next)
		profile = next
		drawWallet()
	end)

	local wasLobby = false
	RunService.RenderStepped:Connect(function()
		local inLobby = Workspace:GetAttribute("InLobby") == true
		local cutscene = playerGui:FindFirstChild("IntroCutscene") ~= nil
			or playerGui:FindFirstChild("StoryCutscene") ~= nil
		gui.Enabled = inLobby
			and not cutscene
			and player:GetAttribute("ClassSelecting") ~= true
			and player:GetAttribute("InStation") ~= true
			and not PortalScreen.isOpen()
		-- a hidden screen may not have known its size when it was drawn
		if gui.Enabled and gui.AbsoluteSize ~= drawn then
			draw()
		end
		local playButton = canvas:FindFirstChild("Play") :: GuiObject?
		if playButton then
			-- already standing in a portal: its own screen is the way on
			playButton.Visible = player:GetAttribute("Portal") == nil
		end
		if inLobby or wasLobby then
			for _, name in FIGHT_HUD do
				local screen = playerGui:FindFirstChild(name)
				if screen and screen:IsA("ScreenGui") then
					if inLobby then
						screen.Enabled = false
					elseif wasLobby then
						screen.Enabled = true
					end
				end
			end
		end
		wasLobby = inLobby
	end)
end

return LobbyHud
