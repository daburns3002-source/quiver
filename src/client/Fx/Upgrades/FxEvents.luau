--!strict
--[[
	The moments the upgrade effects hang off, fired by the modules that
	already know them: the renderer when an arrow leaves, meets a body or a
	wall; the weapon pose when a swing starts, lands and ends; the firing
	prediction when a volley leaves. So adding an effect is a listener here,
	never another branch in the code that flies arrows or swings swords.

	Presentation only: every one of these is the client's drawing of a moment
	the server decides.
]]

local FxEvents = {}

export type Signal<T...> = {
	connect: (self: Signal<T...>, listener: (T...) -> ()) -> (),
	fire: (self: Signal<T...>, T...) -> (),
}

local function signal<T...>(): Signal<T...>
	local listeners: { (T...) -> () } = {}
	local s = {}
	function s.connect(_self: any, listener: (T...) -> ())
		table.insert(listeners, listener)
	end
	function s.fire(_self: any, ...: T...)
		for _, listener in listeners do
			-- one broken effect must not stop the arrows being drawn
			local ok, err = pcall(listener :: any, ...)
			if not ok then
				warn("[UpgradeFx] " .. tostring(err))
			end
		end
	end
	return (s :: any) :: Signal<T...>
end

--[[ A drawn shot left: its part, its pool ("Player", "PlayerOrb", "Enemy"),
     its aim, and `chained` when the server invented it off a body (a
     ricochet, a chain). ]]
FxEvents.launched = signal() :: Signal<BasePart, string, Vector3, boolean>
--[[ A drawn player shot reached a body: where, its heading, its pool, and
     how many more bodies it may pass through. ]]
FxEvents.contact = signal() :: Signal<Vector3, Vector3, string, number>
--[[ A drawn player shot met a wall: where, the wall's normal, the heading
     it leaves on, its pool, and whether it bounced. ]]
FxEvents.wall = signal() :: Signal<Vector3, Vector3, Vector3, string, boolean>
--[[ This client fired a volley (a melee class's swing included): its aim. ]]
FxEvents.fired = signal() :: Signal<Vector3>
--[[ A swing's blow landed: which of how many, and whether it is the
     combo's heavy last. ]]
FxEvents.blow = signal() :: Signal<number, number, boolean>
--[[ A swing's slash window: which blow, and 0..1 through it; nil when over. ]]
FxEvents.slash = signal() :: Signal<number, number?>
--[[ A meteor's rock began to fall: the rock part. ]]
FxEvents.meteor = signal() :: Signal<BasePart>
--[[ This player confirmed a card on the draft screen: its id. ]]
FxEvents.picked = signal() :: Signal<string>
--[[ A ground slam landed (Earthbreaker): where, and how wide. ]]
FxEvents.slam = signal() :: Signal<Vector3, number>

return FxEvents
