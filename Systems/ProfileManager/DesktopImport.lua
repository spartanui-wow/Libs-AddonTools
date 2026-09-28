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

	-- Validate before writing so a damaged payload cannot half-apply
	if importData.Namespaces ~= nil and type(importData.Namespaces) ~= 'table' then
		return false, 'Namespace data is damaged'
	end
	for namespace, nsData in pairs(importData.Namespaces or {}) do
		if type(namespace) ~= 'string' or type(nsData) ~= 'table' then
			return false, 'Namespace "' .. tostring(namespace) .. '" is damaged'
		end
	end
	if importData.BaseDB ~= nil and type(importData.BaseDB) ~= 'table' then
		return false, 'Profile data is damaged'
	end
	if importData.GlobalDB ~= nil and type(importData.GlobalDB) ~= 'table' then
		return false, 'Global data is damaged'
	end

	-- Import namespaces into the target profile, keeping each namespace's other profiles
	for namespace, nsData in pairs(importData.Namespaces or {}) do
		if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
			if ProfileManagerState.ApplyNamespaceImport(db.sv, namespace, nsData, targetProfileKey) then
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

local RefreshReviewContent

---@param entry table|nil
---@return string|nil targetKey
---@return boolean ok False when "Create New" was picked without a name
local function ResolveTarget(entry)
	if entry and entry.selectedDest == '__NEW__' then
		local newName = (entry.selectedNewName or ''):match('^%s*(.-)%s*$') or ''
		if newName == '' then
			return nil, false
		end
		return newName, true
	end
	return entry and entry.selectedDest or nil, true
end

local function ApplyAll()
	local names = {}
	for addonName in pairs(pendingImports) do
		table.insert(names, addonName)
	end
	for _, name in ipairs(names) do
		local targetKey, ok = ResolveTarget(pendingImports[name])
		if ok then
			ProfileManager:ApplyDesktopImport(name, targetKey)
		else
			-- A blank "Create New" name must not fall through to the current profile
			LibAT:Print('|cffff0000Skipped ' .. name .. ':|r enter a name for the new profile, then apply it.')
		end
	end
	RefreshReviewContent()
end

---@param row Frame
---@return string currentKey
---@return table|nil db
local function CurrentProfileKey(row)
	local addon = row.addonId and ProfileManagerState.registeredAddons[row.addonId]
	local db = addon and addon.db
	return (db and db.keys and db.keys.profile) or 'Default', db
end

local ROW_HEIGHT = 88

---Build one review row. Rows are reused, so every handler reads the row's current entry.
---@param parent Frame
---@return Frame
local function CreateReviewRow(parent)
	local row = CreateFrame('Frame', nil, parent)
	row:SetHeight(ROW_HEIGHT)

	local bg = row:CreateTexture(nil, 'BACKGROUND')
	bg:SetAllPoints()
	bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)

	row.nameText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	row.nameText:SetPoint('TOPLEFT', 8, -6)

	row.titleText = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	row.titleText:SetPoint('TOPLEFT', row.nameText, 'BOTTOMLEFT', 0, -2)

	row.dateText = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
	row.dateText:SetPoint('TOPLEFT', row.titleText, 'BOTTOMLEFT', 0, -2)

	row.destLabel = row:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
	row.destLabel:SetText('To:')

	row.destDropdown = LibAT.UI.CreateDropdown(row, '', 160, 20)
	row.destDropdown:SetPoint('LEFT', row.destLabel, 'RIGHT', 4, 0)

	row.newProfileInput = CreateFrame('EditBox', nil, row, 'InputBoxTemplate')
	row.newProfileInput:SetSize(100, 18)
	row.newProfileInput:SetPoint('LEFT', row.destDropdown, 'RIGHT', 4, 0)
	row.newProfileInput:SetAutoFocus(false)
	row.newProfileInput:SetFontObject('GameFontHighlightSmall')
	row.newProfileInput:SetScript('OnEscapePressed', row.newProfileInput.ClearFocus)
	row.newProfileInput:SetScript('OnTextChanged', function(self)
		if row.entry then
			row.entry.selectedNewName = self:GetText()
		end
	end)

	if row.destDropdown.SetupMenu then
		row.destDropdown:SetupMenu(function(_, rootDescription)
			local entry = row.entry
			if not entry then
				return
			end
			local currentKey, db = CurrentProfileKey(row)
			rootDescription:CreateButton('Current (' .. currentKey .. ')', function()
				entry.selectedDest = nil
				entry.selectedNewName = nil
				row.destDropdown:SetText('Current (' .. currentKey .. ')')
				row.newProfileInput:Hide()
			end)
			if db and db.sv and db.sv.profiles then
				local sorted = {}
				for name in pairs(db.sv.profiles) do
					if name ~= currentKey then
						table.insert(sorted, name)
					end
				end
				table.sort(sorted)
				for _, name in ipairs(sorted) do
					rootDescription:CreateButton(name, function()
						entry.selectedDest = name
						entry.selectedNewName = nil
						row.destDropdown:SetText(name)
						row.newProfileInput:Hide()
					end)
				end
			end
			rootDescription:CreateButton('|cff00ff00Create New...|r', function()
				entry.selectedDest = '__NEW__'
				row.destDropdown:SetText('New Profile:')
				row.newProfileInput:SetText(entry.selectedNewName or '')
				row.newProfileInput:Show()
				row.newProfileInput:SetFocus()
			end)
		end)
	end

	row.applyBtn = LibAT.UI.CreateButton(row, 70, 22, 'Apply')
	row.applyBtn:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -80, -6)
	row.applyBtn:SetScript('OnClick', function()
		local targetKey, ok = ResolveTarget(row.entry)
		if not ok then
			LibAT:Print('|cffff0000Error:|r Please enter a name for the new profile.')
			return
		end
		ProfileManager:ApplyDesktopImport(row.addonName, targetKey)
		RefreshReviewContent()
	end)

	row.dismissBtn = LibAT.UI.CreateButton(row, 70, 22, 'Dismiss')
	row.dismissBtn:SetPoint('TOPRIGHT', row, 'TOPRIGHT', -5, -6)
	row.dismissBtn:SetScript('OnClick', function()
		pendingImports[row.addonName] = nil
		if LibAT_ProfileHub_PendingImports then
			LibAT_ProfileHub_PendingImports[row.addonName] = nil
		end
		RefreshReviewContent()
	end)

	return row
end

---@param row Frame
---@param addonName string
---@param entry table
local function PaintReviewRow(row, addonName, entry)
	row.addonName = addonName
	row.entry = entry
	row.addonId = FindAddonByName(addonName)

	local statusColor = row.addonId and '|cff00ff00' or '|cffff9900'
	local statusNote = row.addonId and '' or ' (not loaded)'
	row.nameText:SetText(statusColor .. addonName .. statusNote .. '|r')
	row.titleText:SetText(entry.title or '')

	local lastAnchor = row.titleText
	if entry.imported_at and entry.imported_at ~= '' then
		row.dateText:SetText('Staged: ' .. entry.imported_at:sub(1, 10))
		row.dateText:Show()
		lastAnchor = row.dateText
	else
		row.dateText:Hide()
	end

	local registered = row.addonId ~= nil
	row.destLabel:ClearAllPoints()
	row.destLabel:SetPoint('TOPLEFT', lastAnchor, 'BOTTOMLEFT', 0, -4)
	row.destLabel:SetShown(registered)
	row.destDropdown:SetShown(registered)
	row.applyBtn:SetShown(registered)

	if registered and entry.selectedDest == '__NEW__' then
		row.destDropdown:SetText('New Profile:')
		row.newProfileInput:SetText(entry.selectedNewName or '')
		row.newProfileInput:Show()
	else
		if registered then
			local currentKey = CurrentProfileKey(row)
			row.destDropdown:SetText(entry.selectedDest or ('Current (' .. currentKey .. ')'))
		end
		row.newProfileInput:Hide()
	end
end

---Build the parts of the review window that live as long as the window
local function EnsureReviewLayout()
	if reviewWindow.review then
		return reviewWindow.review
	end
	local review = { rows = {} }

	review.emptyText = reviewWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	review.emptyText:SetPoint('CENTER', 0, 20)
	review.emptyText:SetText('No pending imports.')

	review.header = reviewWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	review.header:SetPoint('TOPLEFT', 20, -35)

	review.scrollFrame = CreateFrame('ScrollFrame', nil, reviewWindow, 'UIPanelScrollFrameTemplate')
	review.scrollFrame:SetPoint('TOPLEFT', review.header, 'BOTTOMLEFT', 0, -10)
	review.scrollFrame:SetPoint('BOTTOMRIGHT', -35, 50)

	review.content = CreateFrame('Frame', nil, review.scrollFrame)
	review.content:SetSize(1, 1)
	review.scrollFrame:SetScrollChild(review.content)
	review.scrollFrame:HookScript('OnSizeChanged', function(_, width)
		review.content:SetWidth(math.max(width or 1, 1))
	end)

	review.applyAllBtn = LibAT.UI.CreateButton(reviewWindow, 120, 26, 'Apply All')
	review.applyAllBtn:SetPoint('BOTTOM', 0, 15)
	review.applyAllBtn:SetScript('OnClick', ApplyAll)

	reviewWindow.review = review
	return review
end

---Refresh the review window from the current pending imports
RefreshReviewContent = function()
	if not reviewWindow then
		return
	end
	local review = EnsureReviewLayout()

	local names = {}
	for addonName in pairs(pendingImports) do
		table.insert(names, addonName)
	end
	table.sort(names)
	local count = #names

	review.emptyText:SetShown(count == 0)
	review.header:SetShown(count > 0)
	review.scrollFrame:SetShown(count > 0)
	review.header:SetText(count .. ' pending import(s) from the desktop app:')

	local yOffset = 0
	for i, addonName in ipairs(names) do
		local row = review.rows[i]
		if not row then
			row = CreateReviewRow(review.content)
			review.rows[i] = row
		end
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', review.content, 'TOPLEFT', 0, yOffset)
		row:SetPoint('TOPRIGHT', review.content, 'TOPRIGHT', -10, yOffset)
		PaintReviewRow(row, addonName, pendingImports[addonName])
		row:Show()
		yOffset = yOffset - ROW_HEIGHT - 4
	end
	for i = count + 1, #review.rows do
		review.rows[i]:Hide()
	end
	review.content:SetHeight(math.max(-yOffset, 1))

	-- Apply All only when several imports are staged and every addon is loaded
	local allRegistered = count > 1
	for _, addonName in ipairs(names) do
		if not FindAddonByName(addonName) then
			allRegistered = false
			break
		end
	end
	review.applyAllBtn:SetShown(allRegistered)
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
		-- Keep the staged import until the user actually confirms it
		self:ShowCompositeImport(cleanEncoded, function()
			pendingImports[addonName] = nil
			if LibAT_ProfileHub_PendingImports then
				LibAT_ProfileHub_PendingImports[addonName] = nil
			end
		end)
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
