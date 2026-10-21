--!strict
--[[
	Server entry point.

	Phase 0: proves Rojo sync and MCP playtest work end to end. Run bootstrapping
	arrives in Phase 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Log = require(Shared.Util.Log)

local log = Log.forTag("Server")

log.info("%s v%s booting", Game.Name, Game.Version)
