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
		profile = {
			profiles = {
				['Default'] = {
					enabled = {}, -- { [addonName] = true/false }
				},
			},
			activeProfile = 'Default',
			categories = {
				custom = {}, -- { categoryName = { addon1, addon2, ... } }
			},
			perCharacter = {}, -- { [characterName] = { activeProfile = 'ProfileName', profiles = {} } }
		},
	}
	AddonManager.Database = LibAT.Database:RegisterNamespace('AddonManager', defaults)
	AddonManager.DB = AddonManager.Database.profile

	-- Register logger category
	if LibAT.InternalLog then
		AddonManager.logger = LibAT.InternalLog:RegisterCategory('AddonManager')
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
