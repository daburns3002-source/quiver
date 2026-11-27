--!strict
--[[
	The lobby HUD on a phone (`Config/LobbyHud`): its buttons are a finger's
	size, and PLAY with the station button over it stays under JUMP, which
	stands where the fight's dash button lifts to (`UI/HudLayout`), on every
	phone width.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)
local LobbyHud = require(ReplicatedStorage.Shared.Config.LobbyHud)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("PLAY and the station button are a finger's target", function()
		t.isTrue(LobbyHud.minTouch >= 56)
		t.isTrue(LobbyHud.playHeight >= LobbyHud.minTouch)
		t.isTrue(LobbyHud.stationHeight >= LobbyHud.minTouch)
	end)

	t.test("the stack stays under the phone's JUMP button", function()
		local u = Hud.phone
		local top = LobbyHud.gutter
			+ LobbyHud.playHeight
			+ LobbyHud.stackGap
			+ LobbyHud.stationHeight
		for width = 320, 440, 10 do
			-- `HudLayout.current`'s lifted dash corner, upright
			local scale = math.min(u.skillBarScale, (width - u.edge * 2) / Hud.touchTray.X)
			local stackTop = u.skillBarBottom
				+ Hud.touchTray.Y * scale
				+ u.barsGap
				+ u.healthHeight
				+ u.barsGap
				+ u.dashHeight
			local jumpBottom = stackTop + u.dashButtonAboveStack
			t.isTrue(top <= jumpBottom, `{width} points wide: {top} against {jumpBottom}`)
		end
	end)
end
