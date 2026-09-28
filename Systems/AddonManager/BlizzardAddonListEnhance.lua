---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- BlizzardEnhance: light touches on Blizzard's own addon list. It gets a shortcut into the Addon
-- Manager, keeps locked favorites enabled when the list is used, and the game menu AddOns button
-- can optionally open the Addon Manager instead.

---@class LibAT.AddonManager.BlizzardEnhance
local Enhance = {}
AddonManager.BlizzardEnhance = Enhance

local hookedList = false
local hookedMenu = false
local shortcut

local function IsEnabled()
	return AddonManager.DB and AddonManager.DB.enabled ~= false
end

local function RefreshBlizzardList()
	if AddonList and AddonList:IsVisible() and AddonList_Update then
		AddonList_Update()
	end
end

---Re-enable locked favorites after the Blizzard list turns something off
local function EnforceLockSoon()
	if not IsEnabled() or not AddonManager.Favorites.IsLocked() then
		return
	end
	C_Timer.After(0, function()
		if AddonManager.Favorites.EnforceLock() > 0 then
			RefreshBlizzardList()
		end
	end)
end

local function CreateShortcut()
	if shortcut or not AddonList then
		return
	end
	shortcut = CreateFrame('Button', nil, AddonList, 'UIPanelButtonTemplate')
	shortcut:SetSize(130, 22)
	shortcut:SetText('Addon Manager')
	local anchor = AddonList.DisableAllButton
	if anchor then
		shortcut:SetPoint('LEFT', anchor, 'RIGHT', 4, 0)
	else
		shortcut:SetPoint('BOTTOMLEFT', AddonList, 'BOTTOMLEFT', 250, 4)
	end
	shortcut:SetScript('OnClick', function()
		HideUIPanel(AddonList)
		AddonManager.Open()
		-- Closing the list re-opens the game menu when the list was opened from it; close it again
		local function CloseGameMenu()
			if GameMenuFrame and GameMenuFrame:IsShown() then
				HideUIPanel(GameMenuFrame)
			end
		end
		CloseGameMenu()
		C_Timer.After(0, CloseGameMenu)
	end)
	shortcut:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_TOP')
		GameTooltip:SetText('Addon Manager', 1, 1, 1)
		GameTooltip:AddLine('Profiles, favorites, search and details for every addon.', 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	shortcut:SetScript('OnLeave', GameTooltip_Hide)
end

local function HookAddonList()
	if hookedList or not AddonList then
		return
	end
	hookedList = true

	CreateShortcut()
	shortcut:SetShown(IsEnabled())

	if AddonList_Enable then
		hooksecurefunc('AddonList_Enable', function(_, enabled)
			if not enabled then
				EnforceLockSoon()
			end
		end)
	end

	-- The Disable All button holds a direct reference to its handler, so hook the API underneath
	hooksecurefunc(C_AddOns, 'DisableAllAddOns', EnforceLockSoon)

	-- Changes made in the Blizzard list show up in the manager once the list closes
	AddonList:HookScript('OnHide', function()
		AddonManager.Core.Notify('state')
	end)
end

local function OpenFromGameMenu()
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
	HideUIPanel(GameMenuFrame)
	AddonManager.Open()
end

local function HookGameMenu()
	if hookedMenu or not GameMenuFrame then
		return
	end
	hookedMenu = true

	-- Game menu buttons are pooled and rebuilt every time the menu opens
	if GameMenuFrame.InitButtons and GameMenuFrame.buttonPool then
		hooksecurefunc(GameMenuFrame, 'InitButtons', function(self)
			if not AddonManager.DB.gameMenuOpensManager then
				return
			end
			for button in self.buttonPool:EnumerateActive() do
				if button:GetText() == ADDONS then
					button:SetScript('OnClick', OpenFromGameMenu)
				end
			end
		end)
	elseif GameMenuButtonAddons then
		local original = GameMenuButtonAddons:GetScript('OnClick')
		GameMenuButtonAddons:SetScript('OnClick', function(...)
			if AddonManager.DB.gameMenuOpensManager then
				OpenFromGameMenu()
			elseif original then
				original(...)
			end
		end)
	end
end

---Apply the current setting to the shortcut button
function Enhance.Refresh()
	if shortcut then
		shortcut:SetShown(IsEnabled())
	end
end

function Enhance.Initialize()
	HookGameMenu()
	if AddonList then
		HookAddonList()
	elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
		EventUtil.ContinueOnAddOnLoaded('Blizzard_AddOnList', HookAddonList)
	end
end
