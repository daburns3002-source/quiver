--!strict
--[[
	Client entry point.

	Phase 0: proves Rojo sync and MCP playtest work end to end. Input, camera and
	UI arrive in Phase 1.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Log = require(Shared.Util.Log)

local log = Log.forTag("Client")

log.info("%s v%s client ready", Game.Name, Game.Version)
