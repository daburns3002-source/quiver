--!strict
--[[
	Tagged logging. Every subsystem logs through here so playtest console output
	read over MCP is greppable by tag.
]]

local Log = {}

export type Logger = {
	info: (string, ...any) -> (),
	warn: (string, ...any) -> (),
}

function Log.forTag(tag: string): Logger
	local prefix = `[{tag}]`

	return {
		info = function(message: string, ...: any)
			print(prefix, string.format(message, ...))
		end,

		warn = function(message: string, ...: any)
			warn(prefix, string.format(message, ...))
		end,
	}
end

return Log
