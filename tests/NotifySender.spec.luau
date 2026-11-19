--!strict
--[[
	The one Open Cloud call (`Data/NotifySender`), against a stub: what it
	sends, where the key goes, and what each answer from Roblox means for
	the queue. Nothing here reaches the web; the stubs are put back after
	every test.
]]

local TestRunner = require(script.Parent.TestRunner)
local HttpService = game:GetService("HttpService")
local ServerScriptService = game:GetService("ServerScriptService")

local NotifySender = require(ServerScriptService.Server.Data.NotifySender) :: any

local KEY = { secret = "stand-in" }

local function stubbed(status: number?, body: () -> ()): { any }
	local saved = {
		request = NotifySender.request,
		secret = NotifySender.secret,
		messageId = NotifySender.messageId,
		universe = NotifySender.universe,
	}
	local calls: { any } = {}
	NotifySender.secret = function()
		return KEY
	end
	NotifySender.universe = function()
		return 10772468005
	end
	NotifySender.messageId = function(kind: string)
		return if kind == "daily" then "5dd7024b-68e3-ac4d-8232-4217f86ca244" else ""
	end
	NotifySender.request = function(options)
		table.insert(calls, options)
		if status == nil then
			error("HttpError: ConnectFail")
		end
		return { StatusCode = status, Body = "{}" }
	end
	local ok, err = (pcall :: any)(body)
	NotifySender.request = saved.request
	NotifySender.secret = saved.secret
	NotifySender.messageId = saved.messageId
	NotifySender.universe = saved.universe
	if not ok then
		error(err, 0)
	end
	return calls
end

return function(t: TestRunner.Helper)
	t.test("a send is one POST to the user's notifications, the key in its header", function()
		local outcome
		local calls = stubbed(200, function()
			outcome = NotifySender.send(505306092, "daily")
		end)
		t.equal(outcome, "sent")
		t.equal(#calls, 1)
		local call = calls[1]
		t.equal(call.Method, "POST")
		t.equal(call.Url, "https://apis.roblox.com/cloud/v2/users/505306092/notifications")
		t.equal(call.Headers["x-api-key"], KEY, "the Secret itself, never its text")
		t.equal(call.Headers["Content-Type"], "application/json")
		local body = HttpService:JSONDecode(call.Body)
		t.equal(body.source.universe, "universes/10772468005")
		t.equal(body.payload.message_id, "5dd7024b-68e3-ac4d-8232-4217f86ca244")
		t.equal(body.payload.type, "MOMENT")
		t.equal(body.payload.analytics_data.category, "daily")
		t.isTrue(
			#body.payload.join_experience.launch_data <= 200,
			"launch data fits Roblox's 200 bytes"
		)
		t.isNil(string.find(call.Body, "stand-in", 1, true), "the key is never in the body")
	end)

	t.test("a kind with no message yet is dropped without a call", function()
		local outcome
		local calls = stubbed(200, function()
			outcome = NotifySender.send(1, "season")
		end)
		t.equal(outcome, "drop")
		t.equal(#calls, 0)
	end)

	t.test("no key: nothing is sent and the queue is told to pause", function()
		local outcome
		local calls = stubbed(200, function()
			NotifySender.secret = function()
				return nil
			end
			outcome = NotifySender.send(1, "daily")
		end)
		t.equal(outcome, "key")
		t.equal(#calls, 0)
	end)

	t.test("what Roblox answers is what the queue does", function()
		local cases = {
			[200] = "sent",
			[400] = "drop",
			[401] = "key",
			[403] = "key",
			[404] = "drop",
			[429] = "retry",
			[500] = "retry",
			[503] = "retry",
		}
		for status, expected in cases do
			local outcome
			stubbed(status, function()
				outcome = NotifySender.send(1, "daily")
			end)
			t.equal(outcome, expected, `status {status}`)
		end
	end)

	t.test("a web call that fails is tried again later", function()
		local outcome
		stubbed(nil, function()
			outcome = NotifySender.send(1, "daily")
		end)
		t.equal(outcome, "retry")
	end)
end
