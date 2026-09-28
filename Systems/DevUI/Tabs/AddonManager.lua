---@class LibAT
local LibAT = LibAT

-- DevUI Addons tab: hosts the Addon Manager view (Systems/AddonManager/UI/ManagerView.lua)

LibAT.DevUI = LibAT.DevUI or {}

---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitAddonManager(devUIModule, state)
	local AddonManager = LibAT:GetModule('Handler.AddonManager')

	state.TabModules[state.GetTabIndex('Addons')] = {
		BuildContent = function(contentFrame)
			AddonManager.View.Build(contentFrame)
		end,
		OnActivate = function()
			AddonManager.View.OnActivate()
		end,
	}
end
