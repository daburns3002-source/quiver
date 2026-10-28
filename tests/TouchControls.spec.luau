--!strict
--[[
	The on-screen controls a phone is played with: the dash button in a run,
	and the lobby's JUMP and SPRINT standing in its place
	(`Input/DashButton`, `Input/LobbyButtons`, sized from `Config/Hud.phone`).

	These exist because the sizes are individually legal numbers whose problem
	is in relation to each other and to the screen: the lobby pair were the
	dash button's own 92 and 76, which is defensible for one button and came
	to 182 points of a phone's height for two stacked (owner, 2026-10-27: "the
	lobby sprint and jump buttons are too big"). Tuning any of them should
	never fail a test here; tuning one into a shape a thumb cannot use, or
	back into a stack that eats the screen, should.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hud = require(ReplicatedStorage.Shared.Config.Hud)
local TestRunner = require(script.Parent.TestRunner)

--[[ The smallest a touch target may be, in screen points. Roblox's own
     guidance and Apple's and Google's all land here, and below it a thumb
     misses often enough to be read as the game dropping the input. ]]
local THUMB = 44

--[[ The shortest side of the phones this game is aimed at, in points. The
     smallest common one is 320; the stack is measured against that, because
     that is where it runs out of room first. ]]
local SHORT_SIDE = 320

return function(t: TestRunner.Helper)
	local phone = Hud.phone

	t.test("every touch control is big enough for a thumb", function()
		t.isTrue(phone.dashButtonSize >= THUMB, "the dash button")
		t.isTrue(phone.lobbyJumpSize >= THUMB, "JUMP")
		t.isTrue(phone.lobbySprintSize >= THUMB, "SPRINT")
	end)

	--[[ JUMP stands exactly where the dash button does, so it may match it
	     but never exceed it; SPRINT is pressed between fights rather than in
	     one, so it is the smaller of the two. ]]
	t.test("the lobby buttons are no larger than the dash button they replace", function()
		t.isTrue(phone.lobbyJumpSize <= phone.dashButtonSize, "JUMP against the dash button")
		t.isTrue(phone.lobbySprintSize <= phone.lobbyJumpSize, "SPRINT against JUMP")
	end)

	--[[ The two are stacked in the corner, so what matters is the whole
	     column against the screen's short side — the dimension it is read
	     against when the phone is held either way. A third is already
	     generous for a pair of buttons in one corner. ]]
	t.test("the lobby stack leaves most of a small phone's screen alone", function()
		local stack = phone.lobbyJumpSize + phone.lobbyGap + phone.lobbySprintSize
		t.isTrue(
			stack <= SHORT_SIDE / 3,
			`the JUMP and SPRINT column is {stack} of {SHORT_SIDE} points`
		)
		--[[ And it is smaller than it was, which is the complaint this
		     answers: two of the dash button's own sizes with its gap. ]]
		t.isTrue(stack < 92 + 14 + 76, "smaller than the stack the owner called too big")
	end)

	--[[ A gap, or the two read as one tall button and a thumb aiming at the
	     join hits whichever Roblox decides. It need not be large, but it has
	     to be there. ]]
	t.test("the lobby buttons do not touch", function()
		t.isTrue(phone.lobbyGap > 0, "a gap between JUMP and SPRINT")
	end)

	--[[ The stack sits where the dash button does, clear of the screen's
	     edge, and the margin has to leave room for the wider of the two. ]]
	t.test("the stack fits beside its margin on a small phone", function()
		local widest = math.max(phone.lobbyJumpSize, phone.lobbySprintSize)
		t.isTrue(widest + phone.dashButtonMargin * 2 <= SHORT_SIDE, "across a short side")
	end)
end
