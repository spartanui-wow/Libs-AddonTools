---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- BlizzardAddonListEnhance: Makes Blizzard's AddonList movable/resizable
-- and adds a sidecar panel with profile controls

local Enhance = {}
AddonManager.BlizzardEnhance = Enhance

local sidecarPanel
local enhanced = false
local sessionAddonStates = {} -- Snapshot of addon enabled states at session start (what's actually loaded)

----------------------------------------------------------------------------------------------------
-- Position/Size Persistence
----------------------------------------------------------------------------------------------------

local function SavePosition()
	if not AddonManager.DB or not AddonList then
		return
	end
	if not AddonManager.DB.addonListPosition then
		AddonManager.DB.addonListPosition = {}
	end
	local point, _, relPoint, x, y = AddonList:GetPoint(1)
	AddonManager.DB.addonListPosition.point = point
	AddonManager.DB.addonListPosition.relPoint = relPoint
	AddonManager.DB.addonListPosition.x = x
	AddonManager.DB.addonListPosition.y = y
end

local function SaveSize()
	if not AddonManager.DB or not AddonList then
		return
	end
	if not AddonManager.DB.addonListPosition then
		AddonManager.DB.addonListPosition = {}
	end
	AddonManager.DB.addonListPosition.width = AddonList:GetWidth()
	AddonManager.DB.addonListPosition.height = AddonList:GetHeight()
end

local function RestorePosition()
	if not AddonManager.DB or not AddonManager.DB.addonListPosition or not AddonList then
		return
	end
	local pos = AddonManager.DB.addonListPosition
	if pos.point and pos.x and pos.y then
		AddonList:ClearAllPoints()
		AddonList:SetPoint(pos.point, UIParent, pos.relPoint or 'CENTER', pos.x, pos.y)
	end
	if pos.width and pos.height then
		AddonList:SetSize(pos.width, pos.height)
	end
end

----------------------------------------------------------------------------------------------------
-- Sidecar Panel
----------------------------------------------------------------------------------------------------

local function UpdateSidecarStatus()
	if not sidecarPanel or not sidecarPanel.statusText then
		return
	end
	-- Check if current addon states differ from what was loaded (needs reload)
	if sidecarPanel.pendingReload then
		sidecarPanel.statusText:SetText(string.format('|cffff0000%d change(s) - reload needed|r', sidecarPanel.changeCount or 0))
		if sidecarPanel.reloadBtn then
			sidecarPanel.reloadBtn:Show()
		end
	else
		sidecarPanel.statusText:SetText('')
		if sidecarPanel.reloadBtn then
			sidecarPanel.reloadBtn:Hide()
		end
	end
end

local function RefreshSidecarDropdown()
	if not sidecarPanel or not sidecarPanel.profileText or not AddonManager.Profiles then
		return
	end
	local activeProfile = AddonManager.Profiles.GetActiveProfile() or 'Default'
	sidecarPanel.selectedProfile = activeProfile
	sidecarPanel.profileText:SetText(activeProfile)
	sidecarPanel.pendingReload = false
	sidecarPanel.changeCount = 0
	UpdateSidecarStatus()
end

---Apply a profile's addon states immediately via C_AddOns APIs and refresh Blizzard's AddonList
---@param profileName string
local function ApplyProfileToBlizzardList(profileName)
	if not AddonManager.Profiles or not AddonManager.Core then
		return
	end

	local profile = AddonManager.Profiles.GetProfile(profileName)
	if not profile or not profile.enabled then
		if AddonManager.logger then
			AddonManager.logger.warning(string.format('Profile "%s" has no saved addon states', profileName))
		end
		return
	end

	-- Apply addon states directly via C_AddOns (changes WoW's pending state)
	local changeCount = 0
	for _, addon in pairs(AddonManager.Core.AddonCache) do
		local profileEnabled = profile.enabled[addon.name]
		if profileEnabled ~= nil and profileEnabled ~= addon.enabled then
			if profileEnabled then
				C_AddOns.EnableAddOn(addon.index)
			else
				C_AddOns.DisableAddOn(addon.index)
			end
			-- Update our cache too
			addon.enabled = profileEnabled
			changeCount = changeCount + 1
		end
	end

	C_AddOns.SaveAddOns()

	-- Set as active profile
	AddonManager.Profiles.SetActiveProfile(profileName)

	-- Refresh Blizzard's addon list UI
	if AddonList_Update then
		AddonList_Update()
	end

	-- Compare current state against what was loaded at session start
	-- Only need a reload if something differs from the original session state
	local reloadCount = 0
	for addonName, originalEnabled in pairs(sessionAddonStates) do
		local addon = AddonManager.Core.GetAddonByName(addonName)
		if addon and addon.enabled ~= originalEnabled then
			reloadCount = reloadCount + 1
		end
	end

	sidecarPanel.pendingReload = (reloadCount > 0)
	sidecarPanel.changeCount = reloadCount
	UpdateSidecarStatus()

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Applied profile "%s" to AddonList: %d switched, %d differ from session', profileName, changeCount, reloadCount))
	end
end

local function ShowSidecarProfileMenu(anchorFrame)
	if not AddonManager.Profiles then
		return
	end

	local menu = CreateFrame('Frame', 'LibAT_BlizzAddonList_ProfileMenu', UIParent, 'UIDropDownMenuTemplate')
	UIDropDownMenu_Initialize(menu, function(self, level)
		local info = UIDropDownMenu_CreateInfo()
		local profiles = AddonManager.Profiles.GetProfileNames()
		local activeProfile = AddonManager.Profiles.GetActiveProfile()

		for _, profileName in ipairs(profiles) do
			info.text = profileName
			info.func = function()
				sidecarPanel.selectedProfile = profileName
				if sidecarPanel.profileText then
					sidecarPanel.profileText:SetText(profileName)
				end
				-- Immediately apply the profile states and refresh Blizzard's checkboxes
				ApplyProfileToBlizzardList(profileName)
				CloseDropDownMenus()
			end
			info.checked = (profileName == activeProfile)
			UIDropDownMenu_AddButton(info, level)
		end

		-- Separator
		info = UIDropDownMenu_CreateInfo()
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		-- Create new profile
		info = UIDropDownMenu_CreateInfo()
		info.text = 'Create Profile'
		info.notCheckable = true
		info.func = function()
			CloseDropDownMenus()
			StaticPopupDialogs['LIBAT_SIDECAR_CREATE_PROFILE'] = {
				text = 'Enter profile name:',
				button1 = 'Create',
				button2 = 'Cancel',
				hasEditBox = true,
				OnAccept = function(dialog)
					local name = dialog:GetEditBox():GetText()
					if name and name ~= '' then
						-- Rescan so cache matches current Blizzard checkbox states
						AddonManager.Core.ScanAddons()
						AddonManager.Profiles.CreateProfile(name)
						sidecarPanel.selectedProfile = name
						if sidecarPanel.profileText then
							sidecarPanel.profileText:SetText(name)
						end
						AddonManager.Profiles.SetActiveProfile(name)
					end
				end,
				EditBoxOnEnterPressed = function(editBox)
					local name = editBox:GetText()
					if name and name ~= '' then
						AddonManager.Core.ScanAddons()
						AddonManager.Profiles.CreateProfile(name)
						sidecarPanel.selectedProfile = name
						if sidecarPanel.profileText then
							sidecarPanel.profileText:SetText(name)
						end
						AddonManager.Profiles.SetActiveProfile(name)
					end
					editBox:GetParent():Hide()
				end,
				EditBoxOnEscapePressed = function(editBox)
					editBox:GetParent():Hide()
				end,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
			}
			StaticPopup_Show('LIBAT_SIDECAR_CREATE_PROFILE')
		end
		UIDropDownMenu_AddButton(info, level)
	end, 'MENU')

	ToggleDropDownMenu(1, nil, menu, anchorFrame, 0, 0)
end

local function CreateSidecarPanel()
	if sidecarPanel then
		return sidecarPanel
	end

	sidecarPanel = CreateFrame('Frame', 'LibAT_AddonListSidecar', AddonList, 'InsetFrameTemplate3')
	sidecarPanel:SetWidth(200)
	sidecarPanel:SetPoint('TOPLEFT', AddonList, 'TOPRIGHT', 2, 0)
	sidecarPanel:SetPoint('BOTTOMLEFT', AddonList, 'BOTTOMRIGHT', 2, 0)

	-- Title
	local title = sidecarPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	title:SetPoint('TOP', sidecarPanel, 'TOP', 0, -12)
	title:SetText('Profiles')

	-- Profile dropdown button
	local dropdownBtn = CreateFrame('Button', nil, sidecarPanel, 'BackdropTemplate')
	dropdownBtn:SetSize(170, 24)
	dropdownBtn:SetPoint('TOP', title, 'BOTTOM', 0, -12)
	dropdownBtn:SetBackdrop({
		bgFile = 'Interface\\Buttons\\WHITE8x8',
		edgeFile = 'Interface\\Buttons\\WHITE8x8',
		edgeSize = 1,
	})
	dropdownBtn:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	dropdownBtn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

	local profileText = dropdownBtn:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	profileText:SetPoint('LEFT', dropdownBtn, 'LEFT', 8, 0)
	profileText:SetPoint('RIGHT', dropdownBtn, 'RIGHT', -16, 0)
	profileText:SetJustifyH('LEFT')
	sidecarPanel.profileText = profileText

	local arrow = dropdownBtn:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	arrow:SetPoint('RIGHT', dropdownBtn, 'RIGHT', -4, 0)
	arrow:SetText('v')

	dropdownBtn:SetScript('OnClick', function(self)
		ShowSidecarProfileMenu(self)
	end)
	dropdownBtn:SetScript('OnEnter', function(self)
		self:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end)
	dropdownBtn:SetScript('OnLeave', function(self)
		self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	end)

	-- Status text (shows change count after profile switch)
	local statusText = sidecarPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	statusText:SetPoint('TOP', dropdownBtn, 'BOTTOM', 0, -6)
	statusText:SetPoint('LEFT', sidecarPanel, 'LEFT', 15, 0)
	statusText:SetPoint('RIGHT', sidecarPanel, 'RIGHT', -15, 0)
	statusText:SetJustifyH('CENTER')
	statusText:SetText('')
	sidecarPanel.statusText = statusText

	-- Reload UI button (only visible after profile switch with changes)
	local reloadBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Reload UI')
	reloadBtn:SetPoint('TOP', statusText, 'BOTTOM', 0, -4)
	reloadBtn:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)
	reloadBtn:Hide()
	sidecarPanel.reloadBtn = reloadBtn

	-- Save Profile button (saves current checked states to the selected profile)
	local saveBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Save Profile')
	saveBtn:SetPoint('TOP', reloadBtn, 'BOTTOM', 0, -8)
	saveBtn:SetScript('OnClick', function()
		if not AddonManager.Profiles or not AddonManager.Core then
			return
		end
		local profileName = sidecarPanel.selectedProfile or 'Default'
		-- Rescan so cache matches what Blizzard's list currently shows
		AddonManager.Core.ScanAddons()
		AddonManager.Profiles.SaveProfile(profileName)
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Saved current addon states to profile: %s', profileName))
		end
	end)

	-- Separator
	local sep = sidecarPanel:CreateTexture(nil, 'ARTWORK')
	sep:SetSize(170, 1)
	sep:SetPoint('TOP', saveBtn, 'BOTTOM', 0, -12)
	sep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

	-- Open Addon Manager button
	local openBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Open Addon Manager')
	openBtn:SetPoint('TOP', sep, 'BOTTOM', 0, -12)
	openBtn:SetScript('OnClick', function()
		local DevUI = LibAT:GetModule('Handler.DevUI', true)
		if DevUI and DevUI.ShowTab then
			DevUI.ShowTab(5)
		end
	end)

	sidecarPanel.selectedProfile = AddonManager.Profiles and AddonManager.Profiles.GetActiveProfile() or 'Default'
	sidecarPanel.pendingReload = false
	sidecarPanel.changeCount = 0

	return sidecarPanel
end

----------------------------------------------------------------------------------------------------
-- Enhancement Setup
----------------------------------------------------------------------------------------------------

function Enhance.Setup()
	if enhanced or not AddonList then
		return
	end
	enhanced = true

	-- Remove from UIPanelWindows so WoW doesn't manage its position
	if UIPanelWindows then
		UIPanelWindows['AddonList'] = nil
	end
	AddonList:SetAttribute('UIPanelLayout-defined', nil)
	AddonList:SetAttribute('UIPanelLayout-enabled', nil)
	AddonList:SetAttribute('UIPanelLayout-area', nil)
	AddonList:SetAttribute('UIPanelLayout-pushable', nil)

	-- Make movable
	AddonList:SetMovable(true)
	AddonList:SetClampedToScreen(true)
	AddonList:EnableMouse(true)
	AddonList:RegisterForDrag('LeftButton')
	AddonList:HookScript('OnDragStart', function(self)
		self:StartMoving()
	end)
	AddonList:HookScript('OnDragStop', function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)

	-- Make resizable
	AddonList:SetResizable(true)
	AddonList:SetResizeBounds(500, 400, 1200, 900)

	-- Resize grip
	local resizeHandle = CreateFrame('Button', nil, AddonList)
	resizeHandle:SetSize(16, 16)
	resizeHandle:SetPoint('BOTTOMRIGHT', AddonList, 'BOTTOMRIGHT', -2, 2)
	resizeHandle:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
	resizeHandle:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
	resizeHandle:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')

	resizeHandle:SetScript('OnMouseDown', function()
		AddonList:StartSizing('BOTTOMRIGHT')
	end)
	resizeHandle:SetScript('OnMouseUp', function()
		AddonList:StopMovingOrSizing()
		SaveSize()
		SavePosition()
	end)

	-- Snapshot current addon states (what's actually loaded this session)
	if AddonManager.Core and AddonManager.Core.AddonCache then
		wipe(sessionAddonStates)
		for _, addon in pairs(AddonManager.Core.AddonCache) do
			sessionAddonStates[addon.name] = addon.enabled
		end
	end

	-- Restore saved position/size
	RestorePosition()

	-- Create sidecar panel
	CreateSidecarPanel()
	RefreshSidecarDropdown()

	if AddonManager.logger then
		AddonManager.logger.info('Blizzard AddonList enhanced: movable, resizable, sidecar panel added')
	end
end

----------------------------------------------------------------------------------------------------
-- Hook into AddonList show
----------------------------------------------------------------------------------------------------

-- Wait for AddonList to exist, then hook
local function TryHook()
	if AddonList then
		AddonList:HookScript('OnShow', function()
			if not enhanced then
				Enhance.Setup()
			end
			RefreshSidecarDropdown()
		end)
		return true
	end
	return false
end

-- Try immediately, or wait for it
if not TryHook() then
	local hookFrame = CreateFrame('Frame')
	hookFrame:RegisterEvent('ADDON_LOADED')
	hookFrame:SetScript('OnEvent', function(self, event, addonName)
		if addonName == 'Blizzard_AddonList' or AddonList then
			if TryHook() then
				self:UnregisterAllEvents()
			end
		end
	end)
end
