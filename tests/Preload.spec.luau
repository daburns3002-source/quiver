--!strict
--[[
	The next room is built while this one is played and swapped in at the
	door (`Arena.prepare`), and the clients load it, its enemies and every
	card image ahead of time (`Fx/RoomPreload`, `UI/Cards/CardPreload`;
	owner, 2026-10-26: "next rooms need to preload while playing current
	room", "I also want icons to preload as well").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local Abilities = require(ReplicatedStorage.Shared.Config.Abilities)
local Arena = require(ServerScriptService.Server.Arena.Arena)
local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local BossBanners = require(ReplicatedStorage.Shared.Config.BossBanners)
local CardAssets = require(ReplicatedStorage.Shared.Config.CardAssets)
local EnemyDesigns = require(ReplicatedStorage.Shared.Config.EnemyDesigns)
local NewEnemies = require(ReplicatedStorage.Shared.Config.NewEnemies)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local TestRunner = require(script.Parent.TestRunner)

local Client = StarterPlayer.StarterPlayerScripts.Client
local CardPreload = require(Client.UI.Cards.CardPreload) :: any
local RoomPreload = require(Client.Fx.RoomPreload) :: any

local function has(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

return function(t: TestRunner.Helper)
	local roomA: { Balance.Obstacle } = {
		{ offset = Vector2.new(0, 0), size = Vector3.new(6, 10, 6) },
	}
	local roomB: { Balance.Obstacle } = {
		{ offset = Vector2.new(8, 8), size = Vector3.new(4, 10, 4) },
	}

	t.test("a prepared room is the one swapped in at the door, with its cover", function()
		local park = Instance.new("Folder")
		local live = Instance.new("Folder")
		Arena.prepare(roomA, nil, { "Charger", "Spitter" }, park)
		local parked = park:FindFirstChild("Arena")
		t.notNil(parked, "nothing was parked")
		t.equal((parked :: Instance):GetAttribute("Roster"), "Charger,Spitter")

		Arena.build(live, roomA)
		t.isTrue(live:FindFirstChild("Arena") == parked, "the room was built again, not swapped in")
		t.equal(#park:GetChildren(), 0, "the parked room stayed parked")
		-- its cover is the live layout
		t.isFalse(Arena.isClear(Vector3.new(0, 2, 0), 1), "the prepared room's pillar is not solid")
		t.isTrue(Arena.isClear(Vector3.new(8, 2, 8), 1), "open floor reads as blocked")
	end)

	t.test(
		"a room other than the prepared one is built fresh and the parked one dropped",
		function()
			local park = Instance.new("Folder")
			local live = Instance.new("Folder")
			Arena.prepare(roomA, nil, nil, park)
			local parked = park:FindFirstChild("Arena") :: Instance
			Arena.build(live, roomB)
			t.isTrue(live:FindFirstChild("Arena") ~= parked, "the wrong room was swapped in")
			t.isTrue(parked.Parent == nil, "the unused room was left behind")
			t.isFalse(
				Arena.isClear(Vector3.new(8, 2, 8), 1),
				"the built room's pillar is not solid"
			)
		end
	)

	t.test("every enemy's meshes, picture and banner are loaded with its room", function()
		for _, config in Balance.Enemies :: any do
			if type(config) ~= "table" or type(config.displayName) ~= "string" then
				continue
			end
			local name = config.displayName
			local ids = RoomPreload.enemyContent(name)
			local design = (EnemyDesigns :: any)[name]
			if type(design) == "table" then
				for _, spec in design do
					if type(spec) == "table" and type(spec.meshId) == "string" then
						t.isTrue(
							has(ids, spec.meshId),
							`{name}'s mesh {spec.meshId} is not preloaded`
						)
					end
				end
			end
			local met = (NewEnemies.enemies :: any)[name]
			if met then
				t.isTrue(has(ids, met.picture), `{name}'s NEW ENEMY! picture is not preloaded`)
			end
			local banner = config.boss and (BossBanners.bosses :: any)[config.boss.title]
			if banner and banner.icon ~= "" then
				t.isTrue(has(ids, banner.icon), `{name}'s banner icon is not preloaded`)
			end
		end
	end)

	t.test(
		"every card a class can be dealt has its icon warmed, with every rarity's frame",
		function()
			for _, class in { "Ranger", "Arcanist", "Warden" } do
				local ids = CardPreload.imagesFor(class)
				for _, ability in Abilities.all do
					local classes = ability.classes
					if not classes or table.find(classes, class) then
						t.isTrue(
							has(ids, CardAssets.icons[ability.icon]),
							`{class}: {ability.name}'s icon`
						)
					end
				end
				for name in Rarities.byName do
					t.isTrue(has(ids, (CardAssets.bodies :: any)[name]), `{class}: the {name} body`)
					t.isTrue(
						has(ids, (CardAssets.banners :: any)[name]),
						`{class}: the {name} banner`
					)
				end
			end
			local all = CardPreload.imagesFor(nil)
			for _, id in CardAssets.icons :: { [string]: string } do
				t.isTrue(has(all, id), `icon {id} is never preloaded`)
			end
		end
	)
end
