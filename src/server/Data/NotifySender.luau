--!strict
--[[
	The one Open Cloud call the notifications make (`docs/NOTIFICATIONS.md`):
	Create User Notification, `POST https://apis.roblox.com/cloud/v2/users/
	{id}/notifications`, scope `user.user-notification:write`, from this game
	server with `HttpService:RequestAsync`.

	**The API key never touches the repo.** It is the experience secret
	named `Config/Notifications.secret`, read with `HttpService:GetSecret`
	and handed to the request as the `x-api-key` header as a `Secret`: no
	script ever sees its text. Secrets do not exist in a local Studio
	playtest, so there the key is missing and nothing is sent.

	`request`, `secret` and `messageId` are fields so `tests/NotifySender.spec` can stub
	them; nothing else in the game calls Open Cloud.

	`send` answers with what the queue should do next (`NotifyRules.step`):
	- "sent": Roblox took it (200). Whether it reaches the player is
	  Roblox's: opted in, 13 or over, one a day from an experience.
	- "retry": Roblox asked to slow down (429), failed on its side (5xx),
	  or the web call itself failed.
	- "drop": refused for good (a kind with no message yet, a bad request,
	  no such user).
	- "key": the key is missing or refused (401, 403): the queue stops
	  sending on this server for a while rather than burn calls.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Notifications = require(ReplicatedStorage.Shared.Config.Notifications)

local log = Log.forTag("Notify")

local NotifySender = {}

NotifySender.URL = "https://apis.roblox.com/cloud/v2/users/%d/notifications"

export type Options = {
	Url: string,
	Method: string,
	Headers: { [string]: any },
	Body: string,
}
export type Response = { StatusCode: number, Body: string }

--[[ The web call, `HttpService:RequestAsync` unless a spec swaps it. ]]
NotifySender.request = function(options: Options): Response
	local response = HttpService:RequestAsync(options :: any)
	return { StatusCode = response.StatusCode, Body = response.Body }
end

--[[ The API key as a `Secret`, nil when the experience has none (always,
     in a local Studio playtest). ]]
NotifySender.secret = function(): any
	local ok, secret = pcall(function()
		return HttpService:GetSecret(Notifications.secret)
	end)
	return if ok then secret else nil
end

--[[ The notification string's Asset ID for `kind`, "" for none yet. ]]
NotifySender.messageId = function(kind: string): string
	local entry = Notifications.kinds[kind]
	return if entry then entry.messageId else ""
end

--[[ The universe the message is from: this experience. ]]
NotifySender.universe = function(): number
	return game.GameId
end

--[[ The request's body for a message of `kind`, as the Open Cloud guide
     writes it. The Join button carries `notify:<kind>` as launch data, and
     the dashboard's analytics count it under the kind. ]]
function NotifySender.body(kind: string, messageId: string): { [string]: any }
	return {
		source = { universe = `universes/{NotifySender.universe()}` },
		payload = {
			message_id = messageId,
			type = "MOMENT",
			join_experience = { launch_data = `notify:{kind}` },
			analytics_data = { category = kind },
		},
	}
end

--[[ What a status means for the queue. ]]
function NotifySender.outcome(status: number): string
	if status >= 200 and status < 300 then
		return "sent"
	elseif status == 401 or status == 403 then
		return "key"
	elseif status == 429 or status >= 500 then
		return "retry"
	end
	return "drop"
end

--[[ Sends `user` the message of `kind`. Yields. ]]
function NotifySender.send(user: number, kind: string): string
	local messageId = NotifySender.messageId(kind)
	if messageId == "" then
		return "drop"
	end
	local key = NotifySender.secret()
	if key == nil then
		log.warn("no API key: the secret %q is missing", Notifications.secret)
		return "key"
	end
	local ok, response = pcall(NotifySender.request, {
		Url = string.format(NotifySender.URL, user),
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["x-api-key"] = key },
		Body = HttpService:JSONEncode(NotifySender.body(kind, messageId)),
	})
	if not ok then
		log.warn("send to %d failed: %s", user, tostring(response))
		return "retry"
	end
	local outcome = NotifySender.outcome(response.StatusCode)
	if outcome ~= "sent" then
		log.warn("send %s to %d: %d %s", kind, user, response.StatusCode, response.Body)
	end
	return outcome
end

return NotifySender
