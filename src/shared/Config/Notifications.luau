--!strict
--[[
	Roblox's experience notifications (owner, 2026-11-18: "yes all of these
	create them"; `docs/NOTIFICATIONS.md`): a ping in the player's Roblox
	notifications, with a Join button, when there is a reason to come back.
	Opt-in only. The rules are `Util/NotifyRules`, pure and pinned by
	`tests/NotifyRules.spec`; the server is `Server/Data/Notify`, the queue
	`Server/Data/NotifyQueue`, the one Open Cloud call
	`Server/Data/NotifySender`, the question `Client/UI/NotifyPrompt`.

	**Nothing is sent until the owner says yes.** `send` stays false, and
	each kind's `messageId` stays empty, until the owner has made the five
	notification strings on the Creator Dashboard, made the API key and put
	it in the experience's secrets as `secret` (the steps are in
	`docs/NOTIFICATIONS.md`). A kind with no `messageId` is never sent even
	with `send` on.
]]

local HOUR = 3600
local DAY = 86400

return table.freeze({
	--[[ The owner's switch for sending. Off until the owner's yes. ]]
	send = false,
	--[[ Whether the game asks players to opt in. Roblox shows its own
	     opt-in only to players 13 and over, and never twice in 30 days. ]]
	ask = true,
	--[[ The experience secret that holds the Open Cloud API key
	     (`HttpService:GetSecret`), restricted to apis.roblox.com. ]]
	secret = "NotifyApiKey",

	--[[ The messages, by kind. `messageId` is the notification string's
	     Asset ID copied from the Creator Dashboard (Engagement >
	     Notifications); `rank` breaks a tie when two fall due together,
	     lower first. The text each string should have is in
	     `docs/NOTIFICATIONS.md`; none takes a parameter of its own, so a
	     send can never miss one. ]]
	kinds = table.freeze({
		event = table.freeze({ messageId = "", rank = 1 }),
		season = table.freeze({ messageId = "", rank = 2 }),
		rotation = table.freeze({ messageId = "", rank = 3 }),
		daily = table.freeze({ messageId = "", rank = 4 }),
		gift = table.freeze({ messageId = "", rank = 5 }),
	}),

	--[[ Asking. Never in the player's first session (`joins`), only just
	     after a daily reward is claimed, and after NOT NOW not again for
	     `retryDays`; at most `maxAsks` NOT NOWs, then never again. When
	     Roblox says it cannot ask (already opted in, under 13, or asked in
	     the last 30 days), the game waits `cannotDays` before trying. ]]
	joins = 2,
	retryDays = 3,
	maxAsks = 3,
	cannotDays = 7,

	--[[ Sending, while the player is away. Never sooner than `quiet` after
	     they leave, never two closer than `gap` (Roblox delivers one a day
	     from an experience anyway), at most `perAbsence` until they come
	     back, and nothing at all once they have been gone `giveUp`. Each
	     lands in the player's own evening, `fromHour` to `toHour` local
	     time, by the clock their device reported when they said yes. ]]
	quiet = 3 * HOUR,
	gap = 20 * HOUR,
	perAbsence = 3,
	giveUp = 14 * DAY,
	fromHour = 16,
	toHour = 20,
	--[[ A daily reward still unclaimed is pinged again this long after the
	     first ping about it, if nothing else is sent between. ]]
	dailyAgain = 3 * DAY,

	--[[ The queue's pace, per game server: every `poll` seconds it sends at
	     most `perPoll` (Roblox allows a server 500 web calls a minute, and
	     the game makes others). A send Roblox asks to slow down (429) or
	     that fails on its side (5xx) waits `retry`, doubling, `retries`
	     times; a refused key (401, 403) stops this server sending for
	     `keyPause`. A claimed entry is held `lease` while it is sent. ]]
	poll = 60,
	perPoll = 20,
	retry = 5 * 60,
	retries = 3,
	keyPause = 30 * 60,
	lease = 2 * 60,
})
