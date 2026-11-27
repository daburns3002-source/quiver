--!strict
--[[
	A player's settings (`Config/Settings`, `Util/SettingsRules`): what the
	server keeps of what a client sends. `Remotes.SettingSet` carries a name
	and a value from the client, so the rules are held here against the
	things a client could send that are not settings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.Settings)
local SettingsRules = require(ReplicatedStorage.Shared.Util.SettingsRules)
local TestRunner = require(script.Parent.TestRunner)

return function(t: TestRunner.Helper)
	t.test("a new player hears everything and feels the shake", function()
		local fresh = SettingsRules.default()
		t.equal(fresh.music, 1)
		t.equal(fresh.sound, 1)
		t.isTrue(fresh.haptics)
		for name in Config.defaults :: { [string]: any } do
			t.notNil((Config.attributes :: { [string]: string })[name], `{name} has no attribute`)
		end
	end)

	t.test("a volume is kept as one of the steps, silent to full", function()
		local steps = Config.steps
		for n = 0, steps do
			local name, value = SettingsRules.clean("music", n / steps)
			t.equal(name, "music")
			t.equal(value, n / steps)
		end
		local _, snapped = SettingsRules.clean("sound", 0.3)
		t.equal(snapped, 0.25, "0.3 snaps to the nearest step")
		local _, over = SettingsRules.clean("sound", 40)
		t.equal(over, 1, "over full is full")
		local _, under = SettingsRules.clean("music", -3)
		t.equal(under, 0, "under silent is silent")
	end)

	t.test("what is not a setting is dropped", function()
		local wrong: { { any } } = {
			{ "music", "loud" },
			{ "music", 0 / 0 },
			{ "music", true },
			{ "sound", {} },
			{ "haptics", 1 },
			{ "haptics", "true" },
			{ "coins", 99999 },
			{ "soulstones", 1 },
			{ 3, 1 },
		}
		for _, bad in wrong do
			local name, value = SettingsRules.clean(bad[1], bad[2])
			t.isNil(name, `kept {tostring(bad[1])} = {tostring(bad[2])}`)
			t.isNil(value)
		end
		local name, value = SettingsRules.clean("music", nil)
		t.isNil(name)
		t.isNil(value)
	end)

	t.test("vibration is a yes or a no", function()
		local name, on = SettingsRules.clean("haptics", true)
		t.equal(name, "haptics")
		t.equal(on, true)
		local _, off = SettingsRules.clean("haptics", false)
		t.equal(off, false)
	end)

	t.test("a stored copy reads back clean", function()
		local kept = SettingsRules.read({ music = 0.75, sound = 0.5, haptics = false })
		t.equal(kept.music, 0.75)
		t.equal(kept.sound, 0.5)
		t.isFalse(kept.haptics)
		local broken = SettingsRules.read({ music = "x", sound = 0 / 0, haptics = "no" })
		t.equal(broken.music, 1)
		t.equal(broken.sound, 1)
		t.isTrue(broken.haptics)
		t.equal(SettingsRules.read(nil).music, 1)
		t.equal(SettingsRules.read(7).sound, 1)
	end)
end
