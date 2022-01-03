--[[
	Persistence 0.1.0 by BenSBk
	Depends on:
	- The Roblox API
	- ProfileService @ 2022-01-03
	
	Persistence is a lightweight wrapper over ProfileService. Players should be
	registered upon joining and deregistered upon leaving. init must be called
	before calling register.
]]

local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ProfileService = require(ServerStorage.Modules.ProfileService)

local profileByPlayer = {}
local yieldsForProfileByPlayer = {}
local releasedSet = setmetatable({}, {__mode = "k"})
local boundCallbackMapByField = {}
local isServer = RunService:IsServer()
local profileStore
local template

local function deepCopy(original)
	local copy
	if typeof(original) == "table" then
		copy = {}
		for key, value in pairs(original) do
			copy[deepCopy(key)] = deepCopy(value)
		end
	else
		copy = original
	end
	return copy
end

local function awaitData(player)
	local profile = profileByPlayer[player]
	if not profile then
		if releasedSet[player] then
			-- The player was already released.
			return deepCopy(template)
		else
			local yields = yieldsForProfileByPlayer[player]
			-- We create the list if it doesn't already exist.
			if not yields then
				yields = {}
				yieldsForProfileByPlayer[player] = yields
			end

			local thread = coroutine.running()
			table.insert(yields, thread)
			profile = coroutine.yield()
			if not profile then
				-- The player was released.
				return deepCopy(template)
			end
		end
	end
	return profile.Data
end

local function resumeYields(player, profile)
	local yields = yieldsForProfileByPlayer[player]
	if not yields then
		return
	end
	yieldsForProfileByPlayer[player] = nil
	for _, yield in ipairs(yields) do
		task.spawn(yield, profile)
	end
end

local Persistence = {}

function Persistence.await(player: Player, field: string): any
	assert(isServer, "Persistence can only be used on the server")
	
	return deepCopy(awaitData(player)[field])
end

function Persistence.get(player: Player, field: string): (boolean, any?)
	assert(isServer, "Persistence can only be used on the server")
	
	local profile = profileByPlayer[player]
	if not profile then
		return false
	end
	return true, deepCopy(profile.Data[field])
end

function Persistence.set(player: Player, field: string, value: any)
	assert(isServer, "Persistence can only be used on the server")
	
	task.spawn(function()
		awaitData(player)[field] = deepCopy(value)

		-- We invoke bound callbacks.
		local callbackById = boundCallbackMapByField[field]
		if not callbackById then
			return
		end
		for _, callback in pairs(callbackById) do
			task.spawn(callback, player, deepCopy(value))
		end
	end)
end

function Persistence.bindToChange(field: string, callback: (player: Player, value: any) -> ()): () -> ()
	assert(isServer, "Persistence can only be used on the server")
	
	local callbackById = boundCallbackMapByField[field]
	if not callbackById then
		callbackById = {}
		boundCallbackMapByField[field] = callbackById
	end

	local id = {}
	callbackById[id] = callback

	return function()
		if not callbackById[id] then
			return
		end
		callbackById[id] = nil
		-- We check if we can now remove the callback map.
		if not next(callbackById) then
			boundCallbackMapByField[field] = nil
		end
	end
end

function Persistence.register(player: Player)
	assert(isServer, "Persistence can only be used on the server")
	assert(profileStore, "You need to initialiase Persistence before calling Persistence.register")
	
	local profile = profileStore:LoadProfileAsync(tostring(player.UserId))
	if not profile then
		-- The profile couldn't be loaded possibly due to other Roblox servers
		-- trying to load this profile at the same time:
		player:Kick("There was an error loading the game. Please try again later.")
	end

	profile:AddUserId(player.UserId) -- GDPR compliance
	-- Fill in missing variables from ProfileTemplate (optional)
	profile:Reconcile()
	profile:ListenToRelease(function()
		releasedSet[player] = true
		profileByPlayer[player] = nil
		-- The profile could've been loaded on another Roblox server:
		player:Kick()
		resumeYields(player, nil)
	end)
	if player.Parent then
		profileByPlayer[player] = profile
		resumeYields(player, profile)
	else
		-- Player left before the profile loaded:
		profile:Release()
	end
end

function Persistence.deregister(player: Player)
	assert(isServer, "Persistence can only be used on the server")
	
	local profile = profileByPlayer[player]
	if profile ~= nil then
		profile:Release()
	end
end

function Persistence.init(storeName, originalTemplate)
	assert(isServer, "Persistence can only be used on the server")
	assert(not profileStore, "Persistence has already been initialised")
	
	template = deepCopy(originalTemplate)
	profileStore = ProfileService.GetProfileStore(storeName, template)
end

return Persistence
