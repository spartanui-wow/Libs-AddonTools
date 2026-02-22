---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- BlizzardAddonListEnhance: Makes Blizzard's AddonList movable/resizable
-- and adds a sidecar panel with profile controls

local Enhance = {}
AddonManager.BlizzardEnhance = Enhance

local sidecarPanel
local driftDetailPopup
local enhanced = false
local sessionAddonStates = {} -- Snapshot of addon enabled states at session start (what's actually loaded)
local lastRightClickedNode = nil -- Captured from OnClick hook for use in Menu.ModifyMenu

---Apply or update the star icon and lock icon for a single addon list entry frame.
---Safe to call any time after the frame's treeNode has been set by AddonList_InitAddon.
local function DecorateEntry(entry)
	if not AddonManager.Favorites then
		return
	end
	if not entry.Enabled then
		return
	end
	if not entry.treeNode then
		return
	end

	local data = entry.treeNode:GetData()
	local addonIndex = data and data.addonIndex
	if not addonIndex then
		-- Category/group header node: hide our decorations if they exist
		if entry.SUILockIcon then
			entry.SUILockIcon:Hide()
			entry.Enabled:Show()
		end
		if entry.SUIStar then
			entry.SUIStar:Hide()
		end
		return
	end

	local name = C_AddOns.GetAddOnName(addonIndex)
	local isLockedFavorite = name and AddonManager.Favorites.IsFavorite(name) and AddonManager.Favorites.IsLocked()

	-- Lock icon: replaces checkbox for locked favorites
	if isLockedFavorite then
		if not entry.SUILockIcon then
			local icon = entry:CreateTexture(nil, 'OVERLAY')
			icon:SetAtlas('Forge-Lock', false)
			icon:SetSize(16, 16)
			icon:SetPoint('CENTER', entry.Enabled, 'CENTER')
			entry.SUILockIcon = icon
		end
		entry.Enabled:Hide()
		entry.SUILockIcon:Show()
	else
		if entry.SUILockIcon then
			entry.SUILockIcon:Hide()
		end
		entry.Enabled:Show()
	end

	-- Star icon: clickable favorite toggle, positioned between checkbox and title
	if not entry.SUIStar then
		local star = CreateFrame('Button', nil, entry)
		star:SetSize(14, 14)
		star:SetPoint('LEFT', entry, 'LEFT', 33, 0)

		local starTex = star:CreateTexture(nil, 'ARTWORK')
		starTex:SetAllPoints()
		star.starTex = starTex
		entry.SUIStar = star

		-- Shift Title right to make room for the star
		entry.Title:ClearAllPoints()
		entry.Title:SetPoint('LEFT', entry, 'LEFT', 50, 0)
		entry.Title:SetPoint('RIGHT', entry, 'RIGHT', -140, 0)

		star:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			local isFav = AddonManager.Favorites and self.addonName and AddonManager.Favorites.IsFavorite(self.addonName)
			GameTooltip:SetText(isFav and 'Remove from Favorites' or 'Add to Favorites', 1, 1, 1)
			GameTooltip:Show()
		end)
		star:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
		star:SetScript('OnClick', function(self)
			if not AddonManager.Favorites or not self.addonName then
				return
			end
			if AddonManager.Favorites.IsFavorite(self.addonName) then
				AddonManager.Favorites.RemoveFavorite(self.addonName)
			else
				AddonManager.Favorites.AddFavorite(self.addonName)
			end
			RefreshFavoritesList()
			if AddonList_Update then
				AddonList_Update()
			end
		end)
	end

	-- Update star state
	entry.SUIStar.addonName = name
	local isFavorite = name and AddonManager.Favorites.IsFavorite(name)
	entry.SUIStar.starTex:SetAtlas(isFavorite and 'auctionhouse-icon-favorite' or 'auctionhouse-icon-favorite-off', false)
	entry.SUIStar:Show()
end

local function RefreshLockIcons()
	if not AddonList or not AddonList.ScrollBox then
		return
	end

	AddonList.ScrollBox:ForEachFrame(function(frame)
		DecorateEntry(frame)
	end)
end

----------------------------------------------------------------------------------------------------
-- Sidecar Panel
----------------------------------------------------------------------------------------------------

---Check if live addon states differ from the selected profile. Returns drift count.
local function GetProfileDrift(profileName)
	if not AddonManager.Profiles or not AddonManager.Core then
		return 0
	end

	local profile = AddonManager.Profiles.GetProfile(profileName)
	local drift = 0

	for _, addon in pairs(AddonManager.Core.AddonCache) do
		local liveEnabled = (C_AddOns.GetAddOnEnableState(addon.index) > 0)
		local profileEnabled
		if profile and profile.enabled then
			profileEnabled = profile.enabled[addon.name]
			if profileEnabled == nil then
				profileEnabled = true -- addons not in profile default to enabled
			end
		else
			profileEnabled = true -- Default profile with no saved data = all enabled
		end
		if liveEnabled ~= profileEnabled then
			drift = drift + 1
		end
	end

	return drift
end

---Returns a sorted list of addons that differ from the named profile.
---Each entry: { name, title, willEnable } where willEnable=true means the profile turns it ON.
local function GetProfileDriftList(profileName)
	if not AddonManager.Profiles or not AddonManager.Core then
		return {}
	end

	local profile = AddonManager.Profiles.GetProfile(profileName)
	local list = {}

	for _, addon in pairs(AddonManager.Core.AddonCache) do
		local liveEnabled = (C_AddOns.GetAddOnEnableState(addon.index) > 0)
		local profileEnabled
		if profile and profile.enabled then
			profileEnabled = profile.enabled[addon.name]
			if profileEnabled == nil then
				profileEnabled = true
			end
		else
			profileEnabled = true
		end
		if liveEnabled ~= profileEnabled then
			table.insert(list, {
				name = addon.name,
				title = addon.title or addon.name,
				willEnable = profileEnabled,
			})
		end
	end

	table.sort(list, function(a, b)
		if a.willEnable ~= b.willEnable then
			return a.willEnable
		end
		return a.title < b.title
	end)

	return list
end

local function UpdateDriftDetailPopup(profileName)
	if not driftDetailPopup then
		return
	end

	local child = driftDetailPopup.scrollChild
	local pool = driftDetailPopup.rowPool
	local list = GetProfileDriftList(profileName)

	for _, row in ipairs(pool) do
		row:Hide()
	end

	local yOffset = 0
	for i, entry in ipairs(list) do
		local row = pool[i]
		if not row then
			row = CreateFrame('Frame', nil, child)
			row:SetHeight(18)

			local icon = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			icon:SetPoint('LEFT', row, 'LEFT', 2, 0)
			icon:SetWidth(12)
			row.icon = icon

			local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			label:SetPoint('LEFT', icon, 'RIGHT', 3, 0)
			label:SetPoint('RIGHT', row, 'RIGHT', -2, 0)
			label:SetJustifyH('LEFT')
			label:SetWordWrap(false)
			row.label = label

			table.insert(pool, row)
		end

		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', child, 'TOPLEFT', 4, -yOffset)
		row:SetWidth(child:GetWidth() - 4)

		if entry.willEnable then
			row.icon:SetText('|cff00cc00+|r')
		else
			row.icon:SetText('|cffcc0000-|r')
		end
		row.label:SetText(entry.title)
		row:Show()

		yOffset = yOffset + 18
	end

	child:SetHeight(math.max(yOffset, 1))
end

local function CreateDriftDetailPopup()
	if driftDetailPopup then
		return driftDetailPopup
	end

	driftDetailPopup = CreateFrame('Frame', 'SUIAddonDriftDetail', UIParent, 'BackdropTemplate')
	driftDetailPopup:SetSize(160, 200)
	driftDetailPopup:SetFrameStrata('DIALOG')
	driftDetailPopup:SetBackdrop({
		bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
		edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	driftDetailPopup:Hide()
	driftDetailPopup:SetClampedToScreen(true)
	driftDetailPopup.rowPool = {}

	local title = driftDetailPopup:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	title:SetPoint('TOPLEFT', driftDetailPopup, 'TOPLEFT', 8, -8)
	title:SetText('|cffffd100Profile differences:|r')

	local scrollFrame = LibAT.UI.CreateScrollFrame(driftDetailPopup)
	scrollFrame:SetPoint('TOPLEFT', title, 'BOTTOMLEFT', 0, -4)
	scrollFrame:SetPoint('BOTTOMRIGHT', driftDetailPopup, 'BOTTOMRIGHT', -6, 8)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetWidth(130)
	driftDetailPopup.scrollChild = scrollChild

	tinsert(UISpecialFrames, 'SUIAddonDriftDetail')

	return driftDetailPopup
end

local function UpdateSidecarStatus()
	if not sidecarPanel or not sidecarPanel.statusText then
		return
	end

	local profileName = sidecarPanel.selectedProfile or 'Default'
	local drift = GetProfileDrift(profileName)
	local hasDrift = drift > 0

	if sidecarPanel.applyBtn then
		if hasDrift then
			sidecarPanel.applyBtn:Show()
		else
			sidecarPanel.applyBtn:Hide()
		end
	end

	-- Check if current addon states differ from what was loaded (needs reload)
	if sidecarPanel.pendingReload then
		sidecarPanel.statusText:SetText(string.format('|cffff0000%d change(s) - reload needed|r', sidecarPanel.changeCount or 0))
		if sidecarPanel.reloadBtn then
			sidecarPanel.reloadBtn:Show()
		end
		if sidecarPanel.infoBtn then
			sidecarPanel.infoBtn:Show()
		end
	elseif hasDrift then
		sidecarPanel.statusText:SetText(string.format('|cffff9900%d addon(s) differ from profile|r', drift))
		if sidecarPanel.reloadBtn then
			sidecarPanel.reloadBtn:Hide()
		end
		if sidecarPanel.infoBtn then
			sidecarPanel.infoBtn:Show()
		end
	else
		sidecarPanel.statusText:SetText('')
		if sidecarPanel.reloadBtn then
			sidecarPanel.reloadBtn:Hide()
		end
		if sidecarPanel.infoBtn then
			sidecarPanel.infoBtn:Hide()
			if driftDetailPopup and driftDetailPopup:IsShown() then
				driftDetailPopup:Hide()
			end
		end
	end
end

local function RefreshSidecarDropdown()
	if not sidecarPanel or not sidecarPanel.profileDropdown or not AddonManager.Profiles then
		return
	end
	local activeProfile = AddonManager.Profiles.GetActiveProfile() or 'Default'
	sidecarPanel.selectedProfile = activeProfile
	sidecarPanel.profileDropdown:SetText(activeProfile)
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

	-- Apply addon states directly via C_AddOns (changes WoW's pending state)
	local changeCount = 0
	for _, addon in pairs(AddonManager.Core.AddonCache) do
		local profileEnabled
		if profile and profile.enabled and profile.enabled[addon.name] ~= nil then
			profileEnabled = profile.enabled[addon.name]
		else
			-- Default profile unsaved, or addon not in profile: enable everything
			profileEnabled = true
		end

		local liveEnabled = (C_AddOns.GetAddOnEnableState(addon.index) > 0)
		if profileEnabled ~= liveEnabled then
			if profileEnabled then
				C_AddOns.EnableAddOn(addon.index)
			else
				C_AddOns.DisableAddOn(addon.index)
			end
			addon.enabled = profileEnabled
			changeCount = changeCount + 1
		end
	end

	C_AddOns.SaveAddOns()

	-- Enforce favorites lock (re-enable any favorites disabled by the profile)
	if AddonManager.Favorites then
		AddonManager.Favorites.EnforceLock()
	end

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

----------------------------------------------------------------------------------------------------
-- Favorites UI Helpers
----------------------------------------------------------------------------------------------------

local function RefreshFavoritesList()
	if not sidecarPanel or not sidecarPanel.favScrollChild or not AddonManager.Favorites then
		return
	end

	local scrollChild = sidecarPanel.favScrollChild

	-- Hide all existing rows
	for _, row in ipairs(sidecarPanel.favRowPool) do
		row:Hide()
	end

	local favorites = AddonManager.Favorites.GetFavorites()
	local pendingRemovals = AddonManager.Favorites.PendingRemovals
	local yOffset = 0
	local rowIndex = 0

	local function addRow(addonName, isPendingRemoval)
		rowIndex = rowIndex + 1
		local row = sidecarPanel.favRowPool[rowIndex]
		if not row then
			row = CreateFrame('Frame', nil, scrollChild)
			row:SetSize(155, 20)

			-- Star icon button (reusable favorite button)
			row.starBtn = LibAT.UI.CreateFavoriteButton(row, 14)
			row.starBtn:SetPoint('LEFT', row, 'LEFT', 0, 0)

			-- Addon name label
			row.label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			row.label:SetPoint('LEFT', row.starBtn, 'RIGHT', 4, 0)
			row.label:SetPoint('RIGHT', row, 'RIGHT', 0, 0)
			row.label:SetJustifyH('LEFT')
			row.label:SetWordWrap(false)

			table.insert(sidecarPanel.favRowPool, row)
		end

		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, -yOffset)
		row:Show()

		local addonMeta = AddonManager.Core and AddonManager.Core.GetAddonByName(addonName)
		local displayName = (addonMeta and addonMeta.title) or addonName
		row.label:SetText(displayName)

		if isPendingRemoval then
			row.label:SetTextColor(0.4, 0.4, 0.4)
			row.starBtn:SetFavorite(false)
			row.starBtn.starTex:SetVertexColor(0.4, 0.4, 0.4)
			row.starBtn:SetScript('OnClick', function()
				AddonManager.Favorites.AddFavorite(addonName)
				RefreshFavoritesList()
				if AddonList_Update then
					AddonList_Update()
				end
			end)
			row.starBtn:SetScript('OnEnter', function(self)
				GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
				GameTooltip:SetText('Re-add to favorites', 1, 1, 1)
				GameTooltip:Show()
			end)
		else
			row.label:SetTextColor(1, 1, 1)
			row.starBtn:SetFavorite(true)
			row.starBtn.starTex:SetVertexColor(1, 1, 1)
			row.starBtn:SetScript('OnClick', function()
				AddonManager.Favorites.RemoveFavorite(addonName)
				RefreshFavoritesList()
				if AddonList_Update then
					AddonList_Update()
				end
			end)
			row.starBtn:SetScript('OnEnter', function(self)
				GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
				GameTooltip:SetText('Remove from favorites', 1, 1, 1)
				GameTooltip:Show()
			end)
		end
		row.starBtn:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)

		yOffset = yOffset + 22
	end

	-- Active favorites
	for _, name in ipairs(favorites) do
		addRow(name, false)
	end

	-- Pending removals (dimmed)
	for name in pairs(pendingRemovals) do
		addRow(name, true)
	end

	scrollChild:SetHeight(math.max(yOffset, 1))
end

----------------------------------------------------------------------------------------------------
-- Sidecar Panel Creation
----------------------------------------------------------------------------------------------------

local function CreateSidecarPanel()
	if sidecarPanel then
		return sidecarPanel
	end

	sidecarPanel = LibAT.UI.CreateStyledPanel(AddonList, 'auctionhouse-background-summarylist')
	sidecarPanel:SetWidth(205)
	sidecarPanel:SetPoint('TOPLEFT', AddonList, 'TOPRIGHT', 2, 0)
	sidecarPanel:SetPoint('BOTTOMLEFT', AddonList, 'BOTTOMRIGHT', 2, 0)

	-- Title
	local title = sidecarPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	title:SetPoint('TOP', sidecarPanel, 'TOP', 0, -12)
	title:SetText('Profiles')

	-- Profile dropdown (modern WowStyle1 dropdown)
	local profileDropdown = LibAT.UI.CreateDropdown(sidecarPanel, 'Default', 170, 22)
	profileDropdown:SetPoint('TOP', title, 'BOTTOM', 0, -12)
	sidecarPanel.profileDropdown = profileDropdown

	if profileDropdown.SetupMenu then
		profileDropdown:SetupMenu(function(owner, rootDescription)
			if not AddonManager.Profiles then
				return
			end

			local profiles = AddonManager.Profiles.GetProfileNames()
			local activeProfile = AddonManager.Profiles.GetActiveProfile()

			for _, profileName in ipairs(profiles) do
				rootDescription:CreateRadio(profileName, function()
					return profileName == (sidecarPanel.selectedProfile or activeProfile)
				end, function()
					sidecarPanel.selectedProfile = profileName
					profileDropdown:SetText(profileName)
					ApplyProfileToBlizzardList(profileName)
				end)
			end

			rootDescription:CreateDivider()

			rootDescription:CreateButton('Create Profile', function()
				StaticPopupDialogs['LIBAT_SIDECAR_CREATE_PROFILE'] = {
					text = 'Enter profile name:',
					button1 = 'Create',
					button2 = 'Cancel',
					hasEditBox = true,
					OnAccept = function(dialog)
						local name = dialog:GetEditBox():GetText()
						if name and name ~= '' then
							AddonManager.Core.ScanAddons()
							AddonManager.Profiles.CreateProfile(name)
							sidecarPanel.selectedProfile = name
							profileDropdown:SetText(name)
							AddonManager.Profiles.SetActiveProfile(name)
						end
					end,
					EditBoxOnEnterPressed = function(editBox)
						local name = editBox:GetText()
						if name and name ~= '' then
							AddonManager.Core.ScanAddons()
							AddonManager.Profiles.CreateProfile(name)
							sidecarPanel.selectedProfile = name
							profileDropdown:SetText(name)
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
			end)

			local deletableProfiles = {}
			for _, profileName in ipairs(profiles) do
				if profileName ~= 'Default' then
					table.insert(deletableProfiles, profileName)
				end
			end
			if #deletableProfiles > 0 then
				rootDescription:CreateDivider()
				for _, profileName in ipairs(deletableProfiles) do
					local nameForClosure = profileName
					rootDescription:CreateButton(string.format('Delete "%s"', nameForClosure), function()
						StaticPopupDialogs['LIBAT_SIDECAR_DELETE_PROFILE'] = {
							text = string.format('Delete profile "%s"?', nameForClosure),
							button1 = 'Delete',
							button2 = 'Cancel',
							OnAccept = function()
								if not AddonManager.Profiles then
									return
								end
								AddonManager.Profiles.DeleteProfile(nameForClosure)
								if sidecarPanel.selectedProfile == nameForClosure then
									sidecarPanel.selectedProfile = 'Default'
									profileDropdown:SetText('Default')
									ApplyProfileToBlizzardList('Default')
								end
							end,
							timeout = 0,
							whileDead = true,
							hideOnEscape = true,
						}
						StaticPopup_Show('LIBAT_SIDECAR_DELETE_PROFILE')
					end)
				end
			end
		end)
	end

	-- Status text (shows change count after profile switch)
	local statusText = sidecarPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	statusText:SetPoint('TOP', profileDropdown, 'BOTTOM', 0, -6)
	statusText:SetPoint('LEFT', sidecarPanel, 'LEFT', 15, 0)
	statusText:SetPoint('RIGHT', sidecarPanel, 'RIGHT', -30, 0)
	statusText:SetJustifyH('CENTER')
	statusText:SetText('')
	sidecarPanel.statusText = statusText

	-- Info button: shows which addons differ from the profile
	local infoBtn = LibAT.UI.CreateInfoButton(sidecarPanel, 'Profile differences', 'Click to see which addons differ', 14)
	infoBtn:SetPoint('LEFT', statusText, 'RIGHT', 2, 0)
	infoBtn:SetPoint('TOP', statusText, 'TOP', 0, 1)
	infoBtn:Hide()
	infoBtn:SetScript('OnClick', function()
		CreateDriftDetailPopup()
		if driftDetailPopup:IsShown() then
			driftDetailPopup:Hide()
		else
			local profileName = sidecarPanel.selectedProfile or 'Default'
			UpdateDriftDetailPopup(profileName)
			driftDetailPopup:ClearAllPoints()
			driftDetailPopup:SetPoint('TOPLEFT', sidecarPanel, 'TOPRIGHT', 4, -80)
			driftDetailPopup:Show()
		end
	end)
	sidecarPanel.infoBtn = infoBtn

	-- Apply Profile button (re-applies profile when live state has drifted)
	local applyBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Apply Profile')
	applyBtn:SetPoint('TOP', statusText, 'BOTTOM', 0, -4)
	applyBtn:SetScript('OnClick', function()
		local profileName = sidecarPanel.selectedProfile or 'Default'
		ApplyProfileToBlizzardList(profileName)
	end)
	applyBtn:Hide()
	sidecarPanel.applyBtn = applyBtn

	-- Reload UI button (only visible after profile switch with changes)
	local reloadBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Reload UI')
	reloadBtn:SetPoint('TOP', applyBtn, 'BOTTOM', 0, -4)
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
		UpdateSidecarStatus()
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Saved current addon states to profile: %s', profileName))
		end
	end)

	-- Separator
	local sep = sidecarPanel:CreateTexture(nil, 'ARTWORK')
	sep:SetSize(170, 1)
	sep:SetPoint('TOP', saveBtn, 'BOTTOM', 0, -12)
	sep:SetColorTexture(0.4, 0.4, 0.4, 0.5)

	----------------------------------------------------------------------------------------------------
	-- Favorites Section
	----------------------------------------------------------------------------------------------------

	-- Favorites header
	local favTitle = sidecarPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	favTitle:SetPoint('TOP', sep, 'BOTTOM', 0, -10)
	favTitle:SetText('Favorites')

	-- Lock Favorites checkbox
	local lockCheckbox = LibAT.UI.CreateCheckbox(sidecarPanel, 'Lock Favorites', 170, 24)
	lockCheckbox:SetPoint('TOP', favTitle, 'BOTTOM', 0, -6)
	lockCheckbox:SetPoint('LEFT', sidecarPanel, 'LEFT', 15, 0)
	lockCheckbox._onClickHandler = function(self)
		local locked = self:GetChecked()
		if AddonManager.Favorites then
			AddonManager.Favorites.SetLocked(locked)
		end
		if AddonList_Update then
			AddonList_Update()
		end
	end
	lockCheckbox:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText('Lock Favorites', 1, 0.82, 0)
		GameTooltip:AddLine('Keep favorites enabled no matter\nwhich profile is loaded.', 1, 1, 1, true)
		GameTooltip:Show()
	end)
	lockCheckbox:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	sidecarPanel.lockCheckbox = lockCheckbox

	-- Add Favorite button (opens a scrollable picker popup)
	local addFavBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, '+ Add Favorite')
	addFavBtn:SetPoint('BOTTOM', sidecarPanel, 'BOTTOM', 0, 44)
	sidecarPanel.addFavBtn = addFavBtn

	-- Favorites scroll list — dynamically fills space between lock checkbox and add button
	local favScrollFrame = LibAT.UI.CreateScrollFrame(sidecarPanel)
	favScrollFrame:SetPoint('TOPLEFT', lockCheckbox, 'BOTTOMLEFT', 0, -6)
	favScrollFrame:SetPoint('BOTTOMRIGHT', addFavBtn, 'TOPRIGHT', 0, 6)

	local favScrollChild = CreateFrame('Frame', nil, favScrollFrame)
	favScrollFrame:SetScrollChild(favScrollChild)
	favScrollChild:SetSize(155, 1)

	sidecarPanel.favScrollFrame = favScrollFrame
	sidecarPanel.favScrollChild = favScrollChild
	sidecarPanel.favRowPool = {}

	-- Scrollable favorite picker popup
	local picker = CreateFrame('Frame', 'SUIAddonFavPicker', UIParent, 'BackdropTemplate')
	picker:SetSize(220, 280)
	picker:SetFrameStrata('DIALOG')
	picker:SetBackdrop({
		bgFile = 'Interface\\DialogFrame\\UI-DialogBox-Background',
		edgeFile = 'Interface\\DialogFrame\\UI-DialogBox-Border',
		tile = true,
		tileSize = 32,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	picker:Hide()
	picker:SetClampedToScreen(true)
	picker.rowPool = {}

	local pickerSearch = LibAT.UI.CreateSearchBox(picker, 180, 22)
	pickerSearch:SetPoint('TOP', picker, 'TOP', 0, -10)

	local pickerScroll = LibAT.UI.CreateScrollFrame(picker)
	pickerScroll:SetPoint('TOPLEFT', pickerSearch, 'BOTTOMLEFT', 0, -4)
	pickerScroll:SetPoint('BOTTOMRIGHT', picker, 'BOTTOMRIGHT', -6, 8)

	local pickerChild = CreateFrame('Frame', nil, pickerScroll)
	pickerScroll:SetScrollChild(pickerChild)
	pickerChild:SetWidth(170)

	local function RebuildPickerList(filter)
		for _, row in ipairs(picker.rowPool) do
			row:Hide()
		end

		if not AddonManager.Favorites then
			return
		end

		local nonFavs = AddonManager.Favorites.GetNonFavorites()
		local yOffset = 0
		local rowIndex = 0
		filter = filter and filter:lower() or ''

		for _, addonName in ipairs(nonFavs) do
			local addonMeta = AddonManager.Core and AddonManager.Core.GetAddonByName(addonName)
			local displayName = (addonMeta and addonMeta.title) or addonName

			if filter == '' or displayName:lower():find(filter, 1, true) or addonName:lower():find(filter, 1, true) then
				rowIndex = rowIndex + 1
				local row = picker.rowPool[rowIndex]
				if not row then
					row = CreateFrame('Button', nil, pickerChild)
					row:SetHeight(22)
					row:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight', 'ADD')

					local label = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
					label:SetPoint('LEFT', row, 'LEFT', 4, 0)
					label:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
					label:SetJustifyH('LEFT')
					label:SetWordWrap(false)
					row.label = label

					table.insert(picker.rowPool, row)
				end

				row:ClearAllPoints()
				row:SetPoint('TOPLEFT', pickerChild, 'TOPLEFT', 0, -yOffset)
				row:SetWidth(pickerChild:GetWidth())
				row.label:SetText(displayName)
				row.addonName = addonName
				row:SetScript('OnClick', function()
					AddonManager.Favorites.AddFavorite(addonName)
					picker:Hide()
					RefreshFavoritesList()
					if AddonList_Update then
						AddonList_Update()
					end
				end)
				row:Show()

				yOffset = yOffset + 22
			end
		end

		pickerChild:SetHeight(math.max(yOffset, 1))
	end

	pickerSearch:SetScript('OnTextChanged', function(self)
		RebuildPickerList(self:GetText())
	end)

	-- Close picker when clicking outside; clear focus so EditBox doesn't eat Escape
	picker:SetScript('OnHide', function()
		pickerSearch:SetText('')
		pickerSearch:ClearFocus()
	end)

	-- Register picker in UISpecialFrames so Escape closes it when open
	tinsert(UISpecialFrames, 'SUIAddonFavPicker')

	addFavBtn:SetScript('OnClick', function()
		if picker:IsShown() then
			picker:Hide()
			return
		end
		picker:ClearAllPoints()
		picker:SetPoint('BOTTOMLEFT', sidecarPanel, 'BOTTOMRIGHT', 4, 0)
		RebuildPickerList('')
		picker:Show()
	end)

	-- Open Addon Manager button (pinned to bottom of panel)
	local openBtn = LibAT.UI.CreateButton(sidecarPanel, 170, 24, 'Open Addon Manager')
	openBtn:SetPoint('BOTTOM', sidecarPanel, 'BOTTOM', 0, 12)
	openBtn:SetScript('OnClick', function()
		local DevUI = LibAT:GetModule('Handler.DevUI', true)
		if DevUI and DevUI.ShowTab then
			DevUI.ShowTab(5)
		end
	end)

	-- Commit pending removals when sidecar hides; also close the picker
	sidecarPanel:HookScript('OnHide', function()
		if AddonManager.Favorites then
			AddonManager.Favorites.CommitRemovals()
		end
		picker:Hide()
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

	-- NOTE: Do NOT modify UIPanelWindows or UIPanelLayout attributes.
	-- Doing so permanently breaks WoW's Escape key handling for the entire session.
	-- WoW's UIPanelWindows system handles Escape for AddonList natively.

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
	end)

	-- Make resizable
	AddonList:SetResizable(true)
	AddonList:SetResizeBounds(500, 500, 1200, 900)

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
	end)

	-- Snapshot current addon states (what's actually loaded this session)
	if AddonManager.Core and AddonManager.Core.AddonCache then
		wipe(sessionAddonStates)
		for _, addon in pairs(AddonManager.Core.AddonCache) do
			sessionAddonStates[addon.name] = addon.enabled
		end
	end

	-- Create sidecar panel
	CreateSidecarPanel()
	RefreshSidecarDropdown()

	-- Initialize favorites UI
	if AddonManager.Favorites then
		if sidecarPanel.lockCheckbox then
			sidecarPanel.lockCheckbox:SetChecked(AddonManager.Favorites.IsLocked())
		end
		RefreshFavoritesList()
	end

	-- Hook Blizzard's AddonList_Enable to prevent unchecking locked favorites
	if AddonList_Enable then
		hooksecurefunc('AddonList_Enable', function(index, enabled)
			if enabled then
				return
			end
			if not AddonManager.Favorites or not AddonManager.Favorites.IsLocked() then
				return
			end

			local addonName = C_AddOns.GetAddOnInfo(index)
			if addonName and AddonManager.Favorites.IsFavorite(addonName) then
				-- Re-enable using the same character context Blizzard uses
				-- GetAddonCharacter() is local to Blizzard's AddonList, so we
				-- replicate: nil means "all characters" which is correct for us
				C_AddOns.EnableAddOn(index)
				C_AddOns.SaveAddOns()

				-- Schedule the UI update for next frame to avoid recursion
				-- (AddonList_Update is called by AddonList_Enable, then our hook
				-- runs. Calling AddonList_Update here would re-enter the hook chain.)
				C_Timer.After(0, function()
					if AddonList:IsVisible() and AddonList_Update then
						AddonList_Update()
					end
				end)

				if AddonManager.logger then
					AddonManager.logger.info('Lock prevented disabling favorite: ' .. addonName)
				end
			end
		end)
	end

	-- Hook C_AddOns.DisableAllAddOns to re-enable locked favorites.
	-- The DisableAll button captures AddonList_DisableAll by reference at load time,
	-- so hooksecurefunc('AddonList_DisableAll') never fires. Hooking the underlying
	-- C_AddOns API catches it regardless of caller.
	hooksecurefunc(C_AddOns, 'DisableAllAddOns', function()
		if AddonManager.logger then
			AddonManager.logger.debug('C_AddOns.DisableAllAddOns hook fired, lock=' .. tostring(AddonManager.Favorites and AddonManager.Favorites.IsLocked()))
		end

		if not AddonManager.Favorites or not AddonManager.Favorites.IsLocked() then
			return
		end

		AddonManager.Favorites.EnforceLock()

		C_Timer.After(0, function()
			if AddonList:IsVisible() and AddonList_Update then
				AddonList_Update()
			end
		end)
	end)

	-- Hook each frame as it's initialized so the star appears immediately, even for child
	-- entries that scroll into view after the initial load. OnInitializedFrame fires after
	-- AddonList_InitAddon has run (and entry.treeNode is set), once per frame per update cycle.
	if AddonList.ScrollBox.RegisterCallback then
		AddonList.ScrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, frame)
			DecorateEntry(frame)
		end, Enhance)
	end

	-- Also hook AddonList_Update as a fallback batch refresh for drift status.
	hooksecurefunc('AddonList_Update', function()
		C_Timer.After(0, function()
			RefreshLockIcons()
			UpdateSidecarStatus()
		end)
	end)

	-- Capture the last right-clicked node so Menu.ModifyMenu can access it
	if AddonListNodeMixin then
		hooksecurefunc(AddonListNodeMixin, 'OnClick', function(self, button)
			if button == 'RightButton' then
				lastRightClickedNode = self
			end
		end)
	end

	-- Extend the Blizzard addon list right-click menu with Add/Remove from Favorites
	if Menu and Menu.ModifyMenu then
		Menu.ModifyMenu('MENU_ADDON_LIST_ENTRY', function(owner, rootDescription)
			local node = lastRightClickedNode
			if not node or not AddonManager.Favorites then
				return
			end

			local data = node.treeNode and node.treeNode:GetData()
			local addonIndex = data and data.addonIndex
			if not addonIndex then
				return
			end

			local name = C_AddOns.GetAddOnName(addonIndex)
			if not name then
				return
			end

			rootDescription:CreateDivider()

			if AddonManager.Favorites.IsFavorite(name) then
				rootDescription:CreateButton('Remove from Favorites', function()
					AddonManager.Favorites.RemoveFavorite(name)
					RefreshFavoritesList()
					if AddonList_Update then
						AddonList_Update()
					end
				end)
			else
				rootDescription:CreateButton('Add to Favorites', function()
					AddonManager.Favorites.AddFavorite(name)
					RefreshFavoritesList()
					if AddonList_Update then
						AddonList_Update()
					end
				end)
			end
		end)
	end

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
			-- Refresh favorites on every show
			if AddonManager.Favorites and sidecarPanel then
				if sidecarPanel.lockCheckbox then
					sidecarPanel.lockCheckbox:SetChecked(AddonManager.Favorites.IsLocked())
				end
				RefreshFavoritesList()
			end
			-- Blizzard calls AddonList_Update inside OnShow before our hook runs,
			-- so refresh lock icons and drift status explicitly, deferred one frame.
			C_Timer.After(0, function()
				RefreshLockIcons()
				UpdateSidecarStatus()
			end)
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
