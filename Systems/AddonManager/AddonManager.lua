---@class LibAT
local LibAT = LibAT

-- AddonManager: Full-featured addon management system integrated with DevUI
-- Provides profiles, search, categories, dependency visualization, and compatibility checking

local AddonManager = LibAT:NewModule('Handler.AddonManager', 'AceEvent-3.0') ---@class LibAT.AddonManager : AceAddon, AceEvent-3.0
AddonManager.description = 'Addon Manager with profiles, search, and dependency tracking'

----------------------------------------------------------------------------------------------------
-- Module Lifecycle
----------------------------------------------------------------------------------------------------

function AddonManager:OnInitialize()
	-- Register database namespace
	local defaults = {
		global = {
			favorites = {}, -- { [addonName] = true }
			lockFavorites = true, -- when true, favorites are forced ON during profile apply
			profiles = {
				[1] = {
					displayName = 'Default',
					enabled = {}, -- { [addonName] = true/false }
				},
			},
			nextProfileId = 2,
			activeProfile = 1, -- int ID
			categories = {
				custom = {}, -- { categoryName = { addon1, addon2, ... } }
			},
			perCharacter = {}, -- { [characterName] = { activeProfile = profileId, profiles = {}, nextProfileId = n } }
			addonListPosition = nil, -- { point, relPoint, x, y, width, height } saved AddonList position/size
		},
	}
	AddonManager.Database = LibAT.Database:RegisterNamespace('AddonManager', defaults)
	AddonManager.DB = AddonManager.Database.global
	AddonManager.GDB = AddonManager.Database.global -- alias for backwards compat with Favorites.lua

	-- One-time migration: move data from profile scope to global scope
	local oldProfile = AddonManager.Database.profile
	if oldProfile then
		local migrated = false

		-- Migrate profiles (skip Default if its enabled table is empty - that's just defaults)
		if oldProfile.profiles then
			for name, data in pairs(oldProfile.profiles) do
				local isJustDefault = (name == 'Default' and data.enabled and not next(data.enabled))
				if not isJustDefault and not AddonManager.DB.profiles[name] then
					AddonManager.DB.profiles[name] = data
					migrated = true
				end
			end
		end

		-- Migrate perCharacter
		if oldProfile.perCharacter then
			for charName, data in pairs(oldProfile.perCharacter) do
				if not AddonManager.DB.perCharacter[charName] then
					AddonManager.DB.perCharacter[charName] = data
					migrated = true
				end
			end
		end

		-- Migrate custom categories
		if oldProfile.categories and oldProfile.categories.custom then
			for catName, addons in pairs(oldProfile.categories.custom) do
				if not AddonManager.DB.categories.custom[catName] then
					AddonManager.DB.categories.custom[catName] = addons
					migrated = true
				end
			end
		end

		-- Migrate activeProfile
		if oldProfile.activeProfile and oldProfile.activeProfile ~= 'Default' then
			if AddonManager.DB.activeProfile == 'Default' then
				AddonManager.DB.activeProfile = oldProfile.activeProfile
				migrated = true
			end
		end

		-- Migrate addonListPosition
		if oldProfile.addonListPosition and not AddonManager.DB.addonListPosition then
			AddonManager.DB.addonListPosition = oldProfile.addonListPosition
			migrated = true
		end

		-- Clear old profile data after migration
		if migrated then
			oldProfile.profiles = nil
			oldProfile.activeProfile = nil
			oldProfile.categories = nil
			oldProfile.perCharacter = nil
			oldProfile.addonListPosition = nil
			AddonManager._migrated = true
		end
	end

	-- Migration: string-keyed profiles to int-keyed profiles with displayName
	local needsIntMigration = false
	if AddonManager.DB.profiles then
		for key in pairs(AddonManager.DB.profiles) do
			if type(key) == 'string' then
				needsIntMigration = true
				break
			end
		end
	end

	if needsIntMigration then
		local nextId = 1
		local newProfiles = {}
		local nameToId = {}

		-- Default always gets ID 1
		if AddonManager.DB.profiles['Default'] then
			newProfiles[1] = AddonManager.DB.profiles['Default']
			newProfiles[1].displayName = 'Default'
			nameToId['Default'] = 1
			nextId = 2
		else
			newProfiles[1] = { displayName = 'Default', enabled = {} }
			nameToId['Default'] = 1
			nextId = 2
		end

		-- Convert remaining global profiles
		for name, data in pairs(AddonManager.DB.profiles) do
			if type(name) == 'string' and name ~= 'Default' then
				data.displayName = name
				newProfiles[nextId] = data
				nameToId[name] = nextId
				nextId = nextId + 1
			end
		end

		AddonManager.DB.profiles = newProfiles
		AddonManager.DB.nextProfileId = nextId

		-- Convert global activeProfile from string to int
		if type(AddonManager.DB.activeProfile) == 'string' then
			AddonManager.DB.activeProfile = nameToId[AddonManager.DB.activeProfile] or 1
		end

		-- Convert per-character data
		if AddonManager.DB.perCharacter then
			for charName, charData in pairs(AddonManager.DB.perCharacter) do
				-- Convert per-char profiles
				if charData.profiles then
					local charNeedsConvert = false
					for key in pairs(charData.profiles) do
						if type(key) == 'string' then
							charNeedsConvert = true
							break
						end
					end

					if charNeedsConvert then
						local charNextId = 1
						local charNewProfiles = {}
						local charNameToId = {}

						for name, data in pairs(charData.profiles) do
							if type(name) == 'string' then
								data.displayName = name
								charNewProfiles[charNextId] = data
								charNameToId[name] = charNextId
								charNextId = charNextId + 1
							end
						end

						charData.profiles = charNewProfiles
						charData.nextProfileId = charNextId

						-- Convert per-char activeProfile
						if type(charData.activeProfile) == 'string' then
							charData.activeProfile = charNameToId[charData.activeProfile] or nameToId[charData.activeProfile]
						end
					end
				elseif type(charData.activeProfile) == 'string' then
					-- No per-char profiles but activeProfile is a string pointing to a global profile
					charData.activeProfile = nameToId[charData.activeProfile]
				end
			end
		end

		AddonManager._migratedIntId = true
	end

	-- Register logger category
	if LibAT.InternalLog then
		AddonManager.logger = LibAT.InternalLog:RegisterCategory('AddonManager')
	end

	if AddonManager._migrated and AddonManager.logger then
		AddonManager.logger.info('Migrated AddonManager data from profile to global scope')
		AddonManager._migrated = nil
	end

	if AddonManager._migratedIntId and AddonManager.logger then
		AddonManager.logger.info('Migrated AddonManager profiles from string keys to int IDs')
		AddonManager._migratedIntId = nil
	end

	-- Initialize Core (API compatibility layer)
	if AddonManager.logger then
		AddonManager.logger.info('Initializing AddonManager core systems')
	end
end

function AddonManager:OnEnable()
	-- Register events
	self:RegisterEvent('ADDON_LOADED', 'OnAddonLoaded')
	self:RegisterEvent('PLAYER_LOGIN', 'OnPlayerLogin')

	if AddonManager.logger then
		AddonManager.logger.info('AddonManager enabled')
	end
end

function AddonManager:OnDisable()
	self:UnregisterAllEvents()

	if AddonManager.logger then
		AddonManager.logger.info('AddonManager disabled')
	end
end

----------------------------------------------------------------------------------------------------
-- Event Handlers
----------------------------------------------------------------------------------------------------

function AddonManager:OnAddonLoaded(event, addonName)
	-- Track addon loading for performance metrics (used by Performance system)
	-- This is just a placeholder for future integration
end

function AddonManager:OnPlayerLogin()
	-- Scan all installed addons and build metadata cache
	if AddonManager.Core then
		AddonManager.Core.ScanAddons()
	end

	if AddonManager.logger then
		AddonManager.logger.info('Player login - scanning installed addons')
	end
end
