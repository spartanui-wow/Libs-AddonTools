---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager
local ProfileManagerState = ProfileManager.ProfileManagerState

----------------------------------------------------------------------------------------------------
-- Desktop Import Processing
-- Detects and processes pending imports staged by the Profile Hub desktop app.
-- The desktop writes to LibAT_ProfileHub_PendingImports (SavedVariables of the
-- LibAT_ProfileHub helper addon). This file reads that data, notifies the user,
-- and provides a review/apply UI.
----------------------------------------------------------------------------------------------------

local pendingImports = {} -- validated copy of pending entries
local hasNotified = false
local reviewWindow = nil

----------------------------------------------------------------------------------------------------
-- Addon Lookup
----------------------------------------------------------------------------------------------------

---Find a registered addon by name, checking ID, display name, and metadata
---@param addonName string The addon name to search for
---@return string|nil addonId The registered addon ID, or nil if not found
local function FindAddonByName(addonName)
	local registeredAddons = ProfileManagerState.registeredAddons

	-- Direct ID match
	if registeredAddons[addonName] then
		return addonName
	end

	-- Case-insensitive ID match
	local lowerName = addonName:lower()
	for addonId in pairs(registeredAddons) do
		if addonId:lower() == lowerName then
			return addonId
		end
	end

	-- Search by display name
	for addonId, addon in pairs(registeredAddons) do
		if addon.displayName == addonName then
			return addonId
		end
		if addon.displayName:lower() == lowerName then
			return addonId
		end
	end

	-- Search by original addon name in metadata (auto-discovered addons)
	for addonId, addon in pairs(registeredAddons) do
		if addon.metadata then
			local originalName = addon.metadata.originalAddonName or addon.metadata.svGlobalName
			if originalName and originalName:lower() == lowerName then
				return addonId
			end
		end
	end

	return nil
end

----------------------------------------------------------------------------------------------------
-- Import Application
----------------------------------------------------------------------------------------------------

---Apply decoded import data to a registered addon's AceDB
---@param addonId string The registered addon ID
---@param importData table The decoded import data table
---@param targetProfileKeyOverride? string Optional target profile key (nil = current profile)
---@return boolean success
---@return string|nil error
local function ApplyImportData(addonId, importData, targetProfileKeyOverride)
	local addon = ProfileManagerState.registeredAddons[addonId]
	if not addon then
		return false, 'Addon "' .. addonId .. '" is not registered'
	end

	local db = addon.db
	if not db or not db.sv then
		return false, 'Invalid AceDB object for ' .. addon.displayName
	end

	local targetProfileKey
	if targetProfileKeyOverride and targetProfileKeyOverride ~= '' then
		targetProfileKey = targetProfileKeyOverride
		if not db.sv.profiles then
			db.sv.profiles = {}
		end
	else
		targetProfileKey = db.keys and db.keys.profile or 'Default'
	end
	local importCount = 0

	-- Import namespaces
	if importData.Namespaces then
		if not db.sv.namespaces then
			db.sv.namespaces = {}
		end
		for namespace, nsData in pairs(importData.Namespaces) do
			if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
				if not db.sv.namespaces[namespace] then
					db.sv.namespaces[namespace] = {}
				end
				local profileData = {}
				for key, value in pairs(nsData) do
					if key == '$global' then
						db.sv.namespaces[namespace].global = value
					elseif key ~= 'profiles' then
						profileData[key] = value
					end
				end
				if next(profileData) then
					if not db.sv.namespaces[namespace].profiles then
						db.sv.namespaces[namespace].profiles = {}
					end
					db.sv.namespaces[namespace].profiles[targetProfileKey] = profileData
				end
				importCount = importCount + 1
			end
		end
	end

	-- Import core profile data (BaseDB)
	if importData.BaseDB then
		if not db.sv.profiles then
			db.sv.profiles = {}
		end
		db.sv.profiles[targetProfileKey] = importData.BaseDB
		if type(importData.BaseDB.SetupWizard) == 'table' then
			importData.BaseDB.SetupWizard.FirstLaunch = false
		end
	end

	-- Import global data
	if importData.GlobalDB then
		db.sv.global = importData.GlobalDB
	end

	if importData.BaseDB or importData.GlobalDB or importCount > 0 then
		return true
	end

	return false, 'No data sections found in import'
end

----------------------------------------------------------------------------------------------------
-- Review Window
----------------------------------------------------------------------------------------------------

local function CreateReviewWindow()
	if reviewWindow then
		-- Re-use existing window frame, just rebuild content
		reviewWindow:Show()
		return reviewWindow
	end

	reviewWindow = LibAT.UI.CreateWindow({
		name = 'LibAT_DesktopImportReview',
		title = 'Profile Hub - Pending Imports',
		width = 500,
		height = 400,
	})

	return reviewWindow
end

---Rebuild the review window content based on current pending imports
local function RefreshReviewContent()
	if not reviewWindow then
		return
	end

	-- Clear old dynamic children
	if reviewWindow.dynamicChildren then
		for _, child in ipairs(reviewWindow.dynamicChildren) do
			child:Hide()
			child:SetParent(nil)
		end
	end
	reviewWindow.dynamicChildren = {}

	local count = 0
	for _ in pairs(pendingImports) do
		count = count + 1
	end

	if count == 0 then
		local emptyText = reviewWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
		emptyText:SetPoint('CENTER', 0, 20)
		emptyText:SetText('No pending imports.')
		table.insert(reviewWindow.dynamicChildren, emptyText)
		return
	end

	-- Header
	local header = reviewWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	header:SetPoint('TOPLEFT', 20, -35)
	header:SetText(count .. ' pending import(s) from the desktop app:')
	table.insert(reviewWindow.dynamicChildren, header)

	-- Scrollable list
	local scrollFrame = CreateFrame('ScrollFrame', nil, reviewWindow, 'UIPanelScrollFrameTemplate')
	scrollFrame:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, -10)
	scrollFrame:SetPoint('BOTTOMRIGHT', -35, 50)
	table.insert(reviewWindow.dynamicChildren, scrollFrame)

	local contentFrame = CreateFrame('Frame', nil, scrollFrame)
	contentFrame:SetSize(scrollFrame:GetWidth(), 1)
	scrollFrame:SetScrollChild(contentFrame)

	local yOffset = 0
	local ROW_HEIGHT = 88

	for addonName, entry in pairs(pendingImports) do
		-- Row container
		local row = CreateFrame('Frame', nil, contentFrame)
		row:SetSize(contentFrame:GetWidth() - 10, ROW_HEIGHT)
		row:SetPoint('TOPLEFT', 0, yOffset)

		-- Background
		local bg = row:CreateTexture(nil, 'BACKGROUND')
		bg:SetAllPoints()
		bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

		-- Addon name + title
		local addonId = FindAddonByName(addonName)
		local statusColor = addonId and '|cff00ff00' or '|cffff9900'
		local statusIcon = addonId and '' or ' (not loaded)'

		local nameText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
		nameText:SetPoint('TOPLEFT', 8, -6)
		nameText:SetText(statusColor .. addonName .. statusIcon .. '|r')

		local titleText = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
		titleText:SetPoint('TOPLEFT', nameText, 'BOTTOMLEFT', 0, -2)
		titleText:SetText(entry.title)

		-- Date
		local lastAnchor = titleText
		if entry.imported_at and entry.imported_at ~= '' then
			local dateText = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
			dateText:SetPoint('TOPLEFT', titleText, 'BOTTOMLEFT', 0, -2)
			dateText:SetText('Staged: ' .. entry.imported_at:sub(1, 10))
			lastAnchor = dateText
		end

		-- Profile destination dropdown (only when addon is registered)
		if addonId then
			local addon = ProfileManagerState.registeredAddons[addonId]
			local db = addon.db
			local currentProfileKey = (db and db.keys and db.keys.profile) or 'Default'

			local destLabel = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
			destLabel:SetPoint('TOPLEFT', lastAnchor, 'BOTTOMLEFT', 0, -4)
			destLabel:SetText('To:')

			local destDropdown = LibAT.UI.CreateDropdown(row, 'Current (' .. currentProfileKey .. ')', 160, 20)
			destDropdown:SetPoint('LEFT', destLabel, 'RIGHT', 4, 0)

			-- New profile name input (hidden by default)
			local newProfileInput = CreateFrame('EditBox', nil, row, 'InputBoxTemplate')
			newProfileInput:SetSize(100, 18)
			newProfileInput:SetPoint('LEFT', destDropdown, 'RIGHT', 4, 0)
			newProfileInput:SetAutoFocus(false)
			newProfileInput:SetFontObject('GameFontHighlightSmall')
			newProfileInput:SetScript('OnEscapePressed', newProfileInput.ClearFocus)
			newProfileInput:SetScript('OnTextChanged', function(self)
				entry.selectedNewName = self:GetText()
			end)
			newProfileInput:Hide()

			if destDropdown.SetupMenu then
				destDropdown:SetupMenu(function(owner, rootDescription)
					-- Current profile option
					rootDescription:CreateButton('Current (' .. currentProfileKey .. ')', function()
						entry.selectedDest = nil
						entry.selectedNewName = nil
						destDropdown:SetText('Current (' .. currentProfileKey .. ')')
						newProfileInput:Hide()
					end)

					-- Existing profiles
					if db and db.sv and db.sv.profiles then
						local sorted = {}
						for name in pairs(db.sv.profiles) do
							if name ~= currentProfileKey then
								table.insert(sorted, name)
							end
						end
						table.sort(sorted)
						for _, name in ipairs(sorted) do
							rootDescription:CreateButton(name, function()
								entry.selectedDest = name
								entry.selectedNewName = nil
								destDropdown:SetText(name)
								newProfileInput:Hide()
							end)
						end
					end

					-- Create New option
					rootDescription:CreateButton('|cff00ff00Create New...|r', function()
						entry.selectedDest = '__NEW__'
						destDropdown:SetText('New Profile:')
						newProfileInput:Show()
						newProfileInput:SetFocus()
					end)
				end)
			end
		end

		-- Apply button
		if addonId then
			local applyBtn = LibAT.UI.CreateButton(row, 70, 22, 'Apply')
			applyBtn:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -80, -6)
			applyBtn:SetScript('OnClick', function()
				local targetKey
				if entry.selectedDest == '__NEW__' then
					local newName = (entry.selectedNewName or ''):match('^%s*(.-)%s*$') or ''
					if newName == '' then
						LibAT:Print('|cffff0000Error:|r Please enter a name for the new profile.')
						return
					end
					targetKey = newName
				elseif entry.selectedDest then
					targetKey = entry.selectedDest
				end
				ProfileManager:ApplyDesktopImport(addonName, targetKey)
				RefreshReviewContent()
			end)
		end

		-- Dismiss button
		local dismissBtn = LibAT.UI.CreateButton(row, 70, 22, 'Dismiss')
		dismissBtn:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -5, -6)
		dismissBtn:SetScript('OnClick', function()
			pendingImports[addonName] = nil
			if LibAT_ProfileHub_PendingImports then
				LibAT_ProfileHub_PendingImports[addonName] = nil
			end
			RefreshReviewContent()
		end)

		yOffset = yOffset - ROW_HEIGHT - 4
	end

	contentFrame:SetHeight(math.abs(yOffset))

	-- Apply All button (only if multiple and all addons are registered)
	if count > 1 then
		local allRegistered = true
		for addonName in pairs(pendingImports) do
			if not FindAddonByName(addonName) then
				allRegistered = false
				break
			end
		end
		if allRegistered then
			local applyAllBtn = LibAT.UI.CreateButton(reviewWindow, 120, 26, 'Apply All')
			applyAllBtn:SetPoint('BOTTOM', 0, 15)
			applyAllBtn:SetScript('OnClick', function()
				local names = {}
				for addonName in pairs(pendingImports) do
					table.insert(names, addonName)
				end
				for _, name in ipairs(names) do
					local entry = pendingImports[name]
					local targetKey
					if entry and entry.selectedDest == '__NEW__' then
						local newName = (entry.selectedNewName or ''):match('^%s*(.-)%s*$') or ''
						if newName ~= '' then
							targetKey = newName
						end
					elseif entry and entry.selectedDest then
						targetKey = entry.selectedDest
					end
					ProfileManager:ApplyDesktopImport(name, targetKey)
				end
				RefreshReviewContent()
			end)
			table.insert(reviewWindow.dynamicChildren, applyAllBtn)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---Check for pending imports from the desktop app
---@return number count Number of valid pending imports found
function ProfileManager.CheckDesktopImports()
	-- Verify helper addon is loaded
	if not LibAT_ProfileHub_Loaded then
		return 0
	end

	local pending = LibAT_ProfileHub_PendingImports
	if not pending or type(pending) ~= 'table' or not next(pending) then
		return 0
	end

	-- Build list of valid pending imports
	wipe(pendingImports)
	local count = 0
	for addonName, entry in pairs(pending) do
		if type(entry) == 'table' and entry.encoded and entry.encoded ~= '' then
			pendingImports[addonName] = {
				encoded = entry.encoded,
				title = entry.title or 'Untitled Import',
				source_id = entry.source_id or '',
				imported_at = entry.imported_at or '',
			}
			count = count + 1
		end
	end

	if count > 0 and not hasNotified then
		ProfileManager.NotifyPendingImports(count)
	end

	return count
end

---Show notification about pending imports
---@param count number Number of pending imports
function ProfileManager.NotifyPendingImports(count)
	if hasNotified then
		return
	end
	hasNotified = true

	LibAT:Print(string.format('|cff00ff00%d pending import(s)|r from the Profile Hub desktop app. Type |cff00aaff/profiles desktop|r to review.', count))

	StaticPopupDialogs['LIBAT_DESKTOP_IMPORT_PENDING'] = {
		text = string.format('%d profile import(s) are waiting from the Profile Hub desktop app.\n\nWould you like to review and apply them?', count),
		button1 = 'Review Imports',
		button2 = 'Later',
		OnAccept = function()
			ProfileManager:ShowDesktopImportReview()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show('LIBAT_DESKTOP_IMPORT_PENDING')
end

---Show the desktop import review window
function ProfileManager:ShowDesktopImportReview()
	CreateReviewWindow()
	RefreshReviewContent()
	reviewWindow:Show()
end

---Apply a single pending import
---@param addonName string The addon name key from pending imports
---@param targetProfileKey? string Optional target profile key (nil = current profile)
---@return boolean success
function ProfileManager:ApplyDesktopImport(addonName, targetProfileKey)
	local entry = pendingImports[addonName]
	if not entry then
		LibAT:Print('|cffff0000Error:|r No pending import for ' .. addonName)
		return false
	end

	-- Find the registered addon
	local addonId = FindAddonByName(addonName)
	if not addonId then
		LibAT:Print('|cffff0000Error:|r Addon "' .. addonName .. '" is not loaded or registered. Install/enable it and reload.')
		return false
	end

	-- Strip comment headers (export strings from the database include metadata headers)
	local cleanEncoded = ProfileManager.StripExportHeaders(entry.encoded)
	if not cleanEncoded or cleanEncoded == '' then
		LibAT:Print('|cffff0000Import failed:|r No data after stripping headers')
		return false
	end

	-- Decode the data
	local importData, decodeErr = ProfileManager.DecodeData(cleanEncoded)
	if not importData then
		LibAT:Print('|cffff0000Import failed:|r ' .. tostring(decodeErr))
		return false
	end

	-- Handle composite format
	if importData.format == 'ProfileManager_Composite' then
		self:ShowCompositeImport(cleanEncoded)
		-- Clear from pending after routing to composite UI
		pendingImports[addonName] = nil
		if LibAT_ProfileHub_PendingImports then
			LibAT_ProfileHub_PendingImports[addonName] = nil
		end
		return true
	end

	-- Apply standard import
	local success, applyErr = ApplyImportData(addonId, importData, targetProfileKey)
	if not success then
		LibAT:Print('|cffff0000Import failed:|r ' .. tostring(applyErr))
		return false
	end

	-- Clear from pending
	pendingImports[addonName] = nil
	if LibAT_ProfileHub_PendingImports then
		LibAT_ProfileHub_PendingImports[addonName] = nil
	end

	local addon = ProfileManagerState.registeredAddons[addonId]
	local displayName = addon and addon.displayName or addonName
	local profileDisplay = targetProfileKey or (addon.db and addon.db.keys and addon.db.keys.profile) or 'Default'
	LibAT:Print('|cff00ff00Profile imported successfully|r for ' .. displayName .. ' (profile: ' .. profileDisplay .. ')! |cffff9900Please /reload to apply changes.|r')

	return true
end
