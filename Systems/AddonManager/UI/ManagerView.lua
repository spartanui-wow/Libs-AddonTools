---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- ManagerView: the Addon Manager surface. Navigation on the left uses the shared LibAT tools
-- styling; the list, details and footer are flat panes. Every control reads live state from Core,
-- so the view is rebuilt from scratch on each refresh and never keeps its own copy of addon state.

---@class LibAT.AddonManager.View
local View = {}
AddonManager.View = View

local T ---@type LibAT.AddonManager.Theme
local Core ---@type LibAT.AddonManager.Core

local NAV_W = 166
local ROW_H = 28
local INDENT = 18
local GAP = 8

---@class LibAT.AddonManager.ViewState
local state = {
	view = 'all', -- all|enabled|disabled|favorites|changes|problems|lod|category
	category = nil, ---@type string|nil
	search = '',
	selected = nil, ---@type string|nil addon name
	sort = 'name', -- name|memory
}

local ui = {}
local dirty = true

local VIEWS = {
	{ key = 'all', label = 'All addons' },
	{ key = 'enabled', label = 'Enabled' },
	{ key = 'disabled', label = 'Disabled' },
	{ key = 'favorites', label = 'Favorites' },
	{ key = 'changes', label = 'Needs reload' },
	{ key = 'problems', label = 'Needs attention' },
	{ key = 'lod', label = 'Load on demand' },
}

----------------------------------------------------------------------------------------------------
-- Filtering
----------------------------------------------------------------------------------------------------

---@param addon LibAT.AddonManager.Addon
---@return string
local function CategoryOf(addon)
	local root = addon.parent or addon
	if root.category then
		return root.category
	end
	if root.security == 'SECURE' then
		return 'Blizzard'
	end
	return 'Other'
end

local VIEW_TEST = {
	all = function()
		return true
	end,
	enabled = function(addon)
		return Core.IsEnabled(addon)
	end,
	disabled = function(addon)
		return not Core.IsEnabled(addon)
	end,
	favorites = function(addon)
		return AddonManager.Favorites.IsFavorite(addon.name)
	end,
	changes = function(addon)
		return Core.NeedsReload(addon)
	end,
	problems = function(addon)
		return Core.HasProblem(addon)
	end,
	lod = function(addon)
		return addon.lod
	end,
}

---@param addon LibAT.AddonManager.Addon
---@param terms string[]
---@return boolean
local function MatchesSearch(addon, terms)
	for _, term in ipairs(terms) do
		if not addon.searchText:find(term, 1, true) then
			return false
		end
	end
	return true
end

---@return string[]
local function SearchTerms()
	local terms = {}
	for term in state.search:lower():gmatch('%S+') do
		table.insert(terms, term)
	end
	return terms
end

---@param a LibAT.AddonManager.Addon
---@param b LibAT.AddonManager.Addon
local function Compare(a, b)
	if state.sort == 'memory' then
		local ma, mb = Core.GetMemory(a), Core.GetMemory(b)
		if ma ~= mb then
			return ma > mb
		end
	end
	return a.sortKey < b.sortKey
end

---Build the rows for the list. The All view and categories keep the parent/child tree; state
---views are flat so every match is visible.
---@return table[] rows
---@return number matched
local function BuildRows()
	local terms = SearchTerms()
	local searching = #terms > 0
	local rows = {}
	local matched = 0

	if state.view == 'all' or state.view == 'category' then
		local roots = {}
		for _, addon in ipairs(Core.addons) do
			if not addon.parent and (state.view == 'all' or CategoryOf(addon) == state.category) then
				table.insert(roots, addon)
			end
		end
		table.sort(roots, Compare)

		for _, root in ipairs(roots) do
			local rootMatch = not searching or MatchesSearch(root, terms)
			local kids = {}
			for _, child in ipairs(root.children) do
				if not searching or rootMatch or MatchesSearch(child, terms) then
					table.insert(kids, child)
				end
			end
			if rootMatch or #kids > 0 then
				local collapsed = AddonManager.DB.collapsed[root.name] and not searching
				table.insert(rows, { addon = root, depth = 0, childCount = #root.children, collapsed = collapsed })
				matched = matched + 1
				if not collapsed then
					for _, child in ipairs(kids) do
						table.insert(rows, { addon = child, depth = 1, childCount = 0 })
					end
				end
				matched = matched + #kids
			end
		end
	else
		local test = VIEW_TEST[state.view] or VIEW_TEST.all
		local list = {}
		for _, addon in ipairs(Core.addons) do
			if test(addon) and (not searching or MatchesSearch(addon, terms)) then
				table.insert(list, addon)
			end
		end
		table.sort(list, Compare)
		for _, addon in ipairs(list) do
			table.insert(rows, { addon = addon, depth = 0, childCount = 0 })
		end
		matched = #list
	end
	return rows, matched
end

---Addons currently shown, including collapsed children, for bulk actions
---@return LibAT.AddonManager.Addon[]
local function ShownAddons()
	local list = {}
	local terms = SearchTerms()
	local searching = #terms > 0
	for _, addon in ipairs(Core.addons) do
		local inView
		if state.view == 'all' then
			inView = true
		elseif state.view == 'category' then
			inView = CategoryOf(addon) == state.category
		else
			inView = (VIEW_TEST[state.view] or VIEW_TEST.all)(addon)
		end
		if inView and (not searching or MatchesSearch(addon, terms)) then
			table.insert(list, addon)
		end
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Shared bits
----------------------------------------------------------------------------------------------------

---@param texture Texture
---@param initial FontString
---@param tile Texture
---@param addon LibAT.AddonManager.Addon
local function PaintIcon(texture, initial, tile, addon)
	if addon.iconTexture then
		texture:SetTexture(tonumber(addon.iconTexture) or addon.iconTexture)
		texture:SetTexCoord(0, 1, 0, 1)
		texture:Show()
		initial:Hide()
		tile:Hide()
	elseif addon.iconAtlas then
		texture:SetAtlas(addon.iconAtlas)
		texture:Show()
		initial:Hide()
		tile:Hide()
	else
		texture:Hide()
		initial:SetText((addon.plainTitle:match('%w') or '?'):upper())
		initial:Show()
		tile:Show()
	end
end

---@param addon LibAT.AddonManager.Addon
local function ToggleAddon(addon)
	local enabled = Core.IsEnabled(addon)
	local full = Core.GetEnableState(addon) >= Core.Enum_All or not Core.IsAllCharacters()
	if enabled and full then
		if AddonManager.Favorites.IsLockedFavorite(addon.name) then
			UIErrorsFrame:AddMessage(addon.plainTitle .. ' is a locked favorite. Unlock favorites to turn it off.', 1, 0.72, 0.28)
			return
		end
		Core.SetEnabled(addon, false)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
	else
		Core.SetEnabled(addon, true)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
end

---@param addon LibAT.AddonManager.Addon
local function Select(addon)
	state.selected = addon and addon.name or nil
	if ui.scrollBox then
		ui.scrollBox:ForEachFrame(function(frame)
			if frame.PaintSelection then
				frame:PaintSelection()
			end
		end)
	end
	View.RefreshDetails()
end

---@param anchor Frame
---@param addon LibAT.AddonManager.Addon
local function OpenAddonMenu(anchor, addon)
	local enabled = Core.IsEnabled(addon)
	local items = {
		{ text = addon.plainTitle, title = true },
		{
			text = enabled and 'Disable' or 'Enable',
			onClick = function()
				ToggleAddon(addon)
			end,
		},
	}
	if #addon.children > 0 then
		table.insert(items, {
			text = string.format('Enable with its %d modules', #addon.children),
			onClick = function()
				local list = { addon }
				for _, child in ipairs(addon.children) do
					table.insert(list, child)
				end
				Core.SetEnabledMany(list, true)
			end,
		})
		table.insert(items, {
			text = string.format('Disable with its %d modules', #addon.children),
			onClick = function()
				local list = { addon }
				for _, child in ipairs(addon.children) do
					table.insert(list, child)
				end
				Core.SetEnabledMany(list, false)
			end,
		})
	end
	if addon.lod and enabled and not Core.IsLoaded(addon) then
		table.insert(items, {
			text = 'Load now',
			onClick = function()
				Core.LoadNow(addon)
			end,
		})
	end
	table.insert(items, {
		text = AddonManager.Favorites.IsFavorite(addon.name) and 'Remove from favorites' or 'Add to favorites',
		divider = true,
		onClick = function()
			AddonManager.Favorites.Toggle(addon.name)
		end,
	})
	T.OpenMenu(anchor, items, true)
end

----------------------------------------------------------------------------------------------------
-- Navigation (shared LibAT tools styling)
----------------------------------------------------------------------------------------------------

local function NavCounts()
	local counts = { all = #Core.addons }
	for key, test in pairs(VIEW_TEST) do
		if key ~= 'all' then
			local n = 0
			for _, addon in ipairs(Core.addons) do
				if test(addon) then
					n = n + 1
				end
			end
			counts[key] = n
		end
	end
	local categories = {}
	for _, addon in ipairs(Core.addons) do
		local cat = CategoryOf(addon)
		categories[cat] = (categories[cat] or 0) + 1
	end
	return counts, categories
end

---@param parent Frame
---@return Button
local function NavButton(parent)
	local btn = LibAT.UI.CreateFilterButton(parent)
	btn:SetFontString(btn.Text)
	btn.Count = btn:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	btn.Count:SetPoint('RIGHT', btn, 'RIGHT', -10, 0)
	btn.Count:SetJustifyH('RIGHT')
	btn:SetScript('OnClick', function(self)
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		state.view = self.viewKey
		state.category = self.category
		View.Refresh()
	end)
	return btn
end

---@param btn Button
---@param kind 'category'|'subCategory'
---@param label string
---@param count number
---@param selected boolean
local function PaintNavButton(btn, kind, label, count, selected)
	LibAT.UI.SetupFilterButton(btn, { type = kind, name = label, selected = selected })
	btn.Text:SetText(label)
	btn.Text:SetPoint('RIGHT', btn, 'RIGHT', -34, 0)
	btn.Text:SetWordWrap(false)
	btn.Count:SetText(count)
	if count == 0 and not selected then
		btn.Count:SetTextColor(0.5, 0.5, 0.5)
		btn.Text:SetAlpha(0.55)
	else
		btn.Count:SetTextColor(0.8, 0.8, 0.8)
		btn.Text:SetAlpha(1)
	end
	if state.view == 'changes' or btn.viewKey ~= 'changes' then
		return
	end
	if count > 0 then
		btn.Count:SetTextColor(T.color.warn[1], T.color.warn[2], T.color.warn[3])
	end
end

local function RefreshNav()
	local counts, categories = NavCounts()
	local child = ui.navChild
	local y = -2
	ui.navButtons = ui.navButtons or {}
	local used = 0

	local function Acquire()
		used = used + 1
		local btn = ui.navButtons[used]
		if not btn then
			btn = NavButton(child)
			ui.navButtons[used] = btn
		end
		btn:ClearAllPoints()
		btn:SetPoint('TOPLEFT', child, 'TOPLEFT', 3, y)
		btn:Show()
		y = y - 22
		return btn
	end

	for _, info in ipairs(VIEWS) do
		local btn = Acquire()
		btn.viewKey = info.key
		btn.category = nil
		PaintNavButton(btn, 'category', info.label, counts[info.key] or 0, state.view == info.key)
		if info.key == 'problems' and (counts.problems or 0) > 0 then
			btn.Count:SetTextColor(T.color.bad[1], T.color.bad[2], T.color.bad[3])
		end
	end

	local names = {}
	for name in pairs(categories) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		local aLast = a == 'Other' or a == 'Blizzard'
		local bLast = b == 'Other' or b == 'Blizzard'
		if aLast ~= bLast then
			return bLast
		end
		return a:lower() < b:lower()
	end)

	y = y - 10
	ui.navCategoryLabel:ClearAllPoints()
	ui.navCategoryLabel:SetPoint('TOPLEFT', child, 'TOPLEFT', 10, y)
	ui.navCategoryLabel:SetShown(#names > 0)
	y = y - 18

	for _, name in ipairs(names) do
		local btn = Acquire()
		btn.viewKey = 'category'
		btn.category = name
		PaintNavButton(btn, 'subCategory', name, categories[name], state.view == 'category' and state.category == name)
	end

	for i = used + 1, #ui.navButtons do
		ui.navButtons[i]:Hide()
	end
	child:SetHeight(-y + 6)
end

local function BuildNav(parent)
	local nav = LibAT.UI.CreateLeftPanel(parent, NAV_W, 0, 0, 0)
	nav:ClearAllPoints()
	nav:SetPoint('TOPLEFT', parent, 'TOPLEFT', 4, -4)
	nav:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', 4, 38)
	ui.nav = nav

	local scroll = CreateFrame('ScrollFrame', nil, nav)
	scroll:SetPoint('TOPLEFT', nav, 'TOPLEFT', 2, -6)
	scroll:SetPoint('BOTTOMRIGHT', nav, 'BOTTOMRIGHT', -2, 4)
	scroll.ScrollBar = CreateFrame('EventFrame', nil, scroll, 'MinimalScrollBar')
	scroll.ScrollBar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 2, 0)
	scroll.ScrollBar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 2, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scroll.ScrollBar)

	local child = CreateFrame('Frame', nil, scroll)
	child:SetSize(NAV_W - 4, 1)
	scroll:SetScrollChild(child)
	ui.navChild = child

	ui.navCategoryLabel = child:CreateFontString(nil, 'OVERLAY', 'GameFontDisableSmall')
	ui.navCategoryLabel:SetText('Categories')
end

----------------------------------------------------------------------------------------------------
-- Toolbar
----------------------------------------------------------------------------------------------------

local function CharacterMenu(anchor)
	local items = { { text = 'Changes apply to', title = true } }
	for _, entry in ipairs(Core.GetCharacters()) do
		local label = entry.label
		if entry.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.class] then
			local c = RAID_CLASS_COLORS[entry.class]
			label = T.Wrap({ c.r, c.g, c.b }, label)
		end
		if entry.isPlayer then
			label = label .. T.Wrap(T.color.faint, '  (this character)')
		end
		local guid = entry.guid
		table.insert(items, {
			text = label,
			checked = Core.character == guid,
			onClick = function()
				if guid == nil then
					AddonManager.DB.characterScope = 'all'
				elseif guid == Core.PlayerGUID() then
					AddonManager.DB.characterScope = 'player'
				end
				Core.SetCharacter(guid)
			end,
		})
	end
	T.OpenMenu(anchor, items)
end

local function ProfileMenu(anchor)
	local Profiles = AddonManager.Profiles
	local activeId = Profiles.GetActiveProfile()
	local activeName = Profiles.GetDisplayName(activeId)
	local items = { { text = 'Apply a profile', title = true } }

	for _, entry in ipairs(Profiles.GetProfiles()) do
		local id = entry.id
		local empty = Profiles.IsEmpty(id)
		table.insert(items, {
			text = entry.displayName .. (empty and T.Wrap(T.color.faint, '  (empty)') or ''),
			checked = id == activeId,
			onClick = function()
				if empty then
					Profiles.SetActiveProfile(id)
					Core.Notify('profiles')
					return
				end
				local changed = Profiles.ApplyProfile(id)
				if changed == 0 then
					UIErrorsFrame:AddMessage(entry.displayName .. ' already matches your addons.', 1, 0.82, 0)
				end
			end,
		})
	end

	table.insert(items, {
		text = 'Save current setup to ' .. activeName,
		divider = true,
		onClick = function()
			Profiles.SaveProfile(activeId)
			UIErrorsFrame:AddMessage('Saved to ' .. activeName, 1, 0.82, 0)
		end,
	})
	table.insert(items, {
		text = 'New profile from current setup...',
		onClick = function()
			T.Prompt('Name the new profile:', '', function(name)
				Profiles.CreateProfile(name)
			end)
		end,
	})
	local locked = Profiles.IsProtectedProfile(activeId)
	table.insert(items, {
		text = 'Rename ' .. activeName .. '...',
		disabled = locked,
		onClick = function()
			T.Prompt('Rename profile:', activeName, function(name)
				Profiles.RenameProfile(activeId, name)
			end)
		end,
	})
	table.insert(items, {
		text = 'Delete ' .. activeName .. '...',
		disabled = locked,
		danger = true,
		onClick = function()
			T.Confirm(string.format('Delete the profile "%s"? Your addons stay as they are.', activeName), function()
				Profiles.DeleteProfile(activeId)
			end, DELETE)
		end,
	})
	T.OpenMenu(anchor, items)
end

local function SettingsMenu(anchor)
	local Favorites = AddonManager.Favorites
	local loadOutOfDate = not Core.IsVersionCheckEnabled()
	local items = {
		{
			text = 'Keep favorites enabled',
			checked = Favorites.IsLocked(),
			onClick = function()
				Favorites.SetLocked(not Favorites.IsLocked())
			end,
		},
		{
			text = ADDON_FORCE_LOAD or 'Load out of date AddOns',
			checked = loadOutOfDate,
			disabled = C_AddOns.SetAddonVersionCheck == nil,
			onClick = function()
				C_AddOns.SetAddonVersionCheck(loadOutOfDate)
				Core.Notify('state')
			end,
		},
		{
			text = 'Open from the game menu',
			checked = AddonManager.DB.gameMenuOpensManager == true,
			onClick = function()
				AddonManager.DB.gameMenuOpensManager = not AddonManager.DB.gameMenuOpensManager
			end,
		},
		{
			text = 'Sort by name',
			checked = state.sort == 'name',
			divider = true,
			onClick = function()
				state.sort = 'name'
				View.Refresh()
			end,
		},
		{
			text = 'Sort by memory',
			checked = state.sort == 'memory',
			onClick = function()
				state.sort = 'memory'
				Core.UpdateMemory(true)
				View.Refresh()
			end,
		},
		{
			text = 'Open the Blizzard addon list',
			divider = true,
			onClick = function()
				ShowUIPanel(AddonList)
			end,
		},
	}
	T.OpenMenu(anchor, items)
end

local function BuildToolbar(parent)
	local bar = CreateFrame('Frame', nil, parent)
	bar:SetPoint('TOPLEFT', ui.nav, 'TOPRIGHT', GAP, 0)
	bar:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -6, -4)
	bar:SetHeight(26)
	ui.toolbar = bar

	ui.settings = T.IconButton(bar, 'gear', 24, 'Options', function(self)
		SettingsMenu(self)
	end)
	ui.settings:SetPoint('RIGHT', bar, 'RIGHT', 0, 0)

	ui.profile = T.Select(bar, 190, function(self)
		ProfileMenu(self)
	end)
	ui.profile:SetCaption('Profile')
	ui.profile:SetPoint('RIGHT', ui.settings, 'LEFT', -6, 0)
	ui.profile.tooltip = 'Profiles'
	ui.profile.hint = 'Save your current addons as a profile, or switch to another one.'

	ui.character = T.Select(bar, 176, function(self)
		CharacterMenu(self)
	end)
	ui.character:SetCaption('For')
	ui.character:SetPoint('RIGHT', ui.profile, 'LEFT', -6, 0)
	ui.character.tooltip = 'Which characters your changes apply to'

	ui.search = T.SearchBox(bar, 'Search addons, authors, notes', function(text)
		state.search = text
		View.RefreshList()
	end)
	ui.search:SetPoint('LEFT', bar, 'LEFT', 0, 0)
	ui.search:SetPoint('RIGHT', ui.character, 'LEFT', -GAP, 0)
end

local function RefreshToolbar()
	local guid = Core.character
	local label = Core.CharacterLabel(guid)
	if guid then
		for _, entry in ipairs(Core.GetCharacters()) do
			if entry.guid == guid and entry.class and RAID_CLASS_COLORS[entry.class] then
				local c = RAID_CLASS_COLORS[entry.class]
				label = T.Wrap({ c.r, c.g, c.b }, label)
			end
		end
	end
	ui.character:SetValue(label)

	local Profiles = AddonManager.Profiles
	local activeId = Profiles.GetActiveProfile()
	local name = Profiles.GetDisplayName(activeId)
	local turnOn, turnOff = Profiles.GetDifferences(activeId)
	local drift = #turnOn + #turnOff
	if drift > 0 and not Profiles.IsEmpty(activeId) then
		ui.profile:SetValue(name .. T.Wrap(T.color.faint, ' *'))
		ui.profile.hint = string.format('%d addon(s) differ from %s. Save to update it, or pick it again to reapply.', drift, name)
	else
		ui.profile:SetValue(name)
		ui.profile.hint = 'Save your current addons as a profile, or switch to another one.'
	end
end

----------------------------------------------------------------------------------------------------
-- List rows
----------------------------------------------------------------------------------------------------

local function BuildRow(row)
	row:SetHeight(ROW_H)
	row:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

	row.hover = T.Fill(row, T.color.hover, 'BACKGROUND', 1)
	row.hover:Hide()
	local a = T.color.accent
	row.sel = T.Fill(row, { a[1], a[2], a[3], 0.14 }, 'BACKGROUND', 2)
	row.sel:Hide()
	row.selEdge = row:CreateTexture(nil, 'ARTWORK')
	row.selEdge:SetTexture(T.WHITE)
	row.selEdge:SetVertexColor(a[1], a[2], a[3], 0.9)
	row.selEdge:SetPoint('TOPLEFT')
	row.selEdge:SetPoint('BOTTOMLEFT')
	row.selEdge:SetWidth(T.Pixel())
	row.selEdge:Hide()

	row.chevron = T.IconButton(row, 'chevron', 16, nil, function(self)
		local addon = self:GetParent().data.addon
		AddonManager.DB.collapsed[addon.name] = not AddonManager.DB.collapsed[addon.name] or nil
		View.RefreshList()
	end)

	row.check = T.Check(row, 14)
	row.check:SetScript('OnClick', function(self)
		ToggleAddon(self:GetParent().data.addon)
	end)
	row.check.onEnter = function(self)
		self:GetParent().hover:Show()
	end
	row.check.onLeave = function(self)
		if not self:GetParent():IsMouseOver() then
			self:GetParent().hover:Hide()
		end
	end

	row.tile = row:CreateTexture(nil, 'ARTWORK')
	row.tile:SetTexture(T.WHITE)
	row.tile:SetVertexColor(1, 1, 1, 0.08)
	row.tile:SetSize(16, 16)
	row.tile:SetPoint('LEFT', row.check, 'RIGHT', 2, 0)
	row.initial = T.Text(row, 'small', T.color.muted)
	row.initial:SetPoint('CENTER', row.tile, 'CENTER', 0, 0)
	row.icon = row:CreateTexture(nil, 'ARTWORK', nil, 1)
	row.icon:SetAllPoints(row.tile)

	row.memory = T.Text(row, 'meta', T.color.faint)
	row.memory:SetPoint('RIGHT', row, 'RIGHT', -10, 0)
	row.memory:SetJustifyH('RIGHT')

	row.tag = T.Text(row, 'meta', T.color.warn)
	row.tag:SetPoint('RIGHT', row.memory, 'LEFT', -10, 0)
	row.tag:SetJustifyH('RIGHT')

	row.star = row:CreateTexture(nil, 'ARTWORK')
	row.star:SetAtlas('auctionhouse-icon-favorite')
	row.star:SetSize(12, 12)

	row.title = T.Text(row, 'body')
	row.title:SetPoint('LEFT', row.tile, 'RIGHT', 8, 0)

	row.count = T.Text(row, 'meta', T.color.faint)

	function row:PaintSelection()
		local selected = self.data and self.data.addon.name == state.selected
		self.sel:SetShown(selected)
		self.selEdge:SetShown(selected)
	end

	row:SetScript('OnEnter', function(self)
		self.hover:Show()
	end)
	row:SetScript('OnLeave', function(self)
		self.hover:Hide()
	end)
	row:SetScript('OnClick', function(self, button)
		local addon = self.data.addon
		if button == 'RightButton' then
			Select(addon)
			OpenAddonMenu(self, addon)
		else
			Select(addon)
		end
	end)
	row:SetScript('OnDoubleClick', function(self)
		ToggleAddon(self.data.addon)
	end)
	row.built = true
end

local TONE_COLOR

local function InitRow(row, data)
	if not row.built then
		BuildRow(row)
	end
	row.data = data
	local addon = data.addon
	local left = 6 + data.depth * INDENT

	row.chevron:ClearAllPoints()
	row.chevron:SetPoint('LEFT', row, 'LEFT', left, 0)
	if data.childCount > 0 then
		row.chevron:Show()
		row.chevron.icon:SetRotation(data.collapsed and (math.pi / 2) or 0)
		row.chevron.tooltip = data.collapsed and 'Show modules' or 'Hide modules'
	else
		row.chevron:Hide()
	end
	row.check:ClearAllPoints()
	row.check:SetPoint('LEFT', row, 'LEFT', left + 16, 0)

	local stateValue = Core.GetEnableState(addon)
	local lockedFav = AddonManager.Favorites.IsLockedFavorite(addon.name)
	if stateValue >= Core.Enum_All or (stateValue > 0 and not Core.IsAllCharacters()) then
		row.check:SetState(true, lockedFav)
	elseif stateValue > 0 then
		row.check:SetState('some')
	else
		row.check:SetState(false)
	end
	if lockedFav then
		row.check.tooltip = 'Locked favorite'
		row.check.hint = 'Favorites stay enabled while "Keep favorites enabled" is on.'
	elseif stateValue > 0 and stateValue < Core.Enum_All and Core.IsAllCharacters() then
		row.check.tooltip = 'Enabled on some characters'
		row.check.hint = 'Click to enable it on every character.'
	else
		row.check.tooltip = nil
		row.check.hint = nil
	end

	PaintIcon(row.icon, row.initial, row.tile, addon)

	local statusKey, statusLabel, tone = Core.GetStatus(addon)
	local enabled = stateValue > 0
	row.title:SetText(addon.plainTitle)
	if statusKey == 'problem' or statusKey == 'banned' then
		T.SetColor(row.title, T.color.bad)
	elseif enabled then
		T.SetColor(row.title, T.color.text)
	else
		T.SetColor(row.title, T.color.faint)
	end

	local showTag = statusKey == 'reload-on' or statusKey == 'reload-off' or statusKey == 'problem' or statusKey == 'banned' or statusKey == 'dep-disabled' or statusKey == 'lod'
	if showTag then
		row.tag:SetText(statusKey == 'lod' and 'On demand' or statusLabel)
		T.SetColor(row.tag, TONE_COLOR[tone] or T.color.faint)
		row.tag:Show()
	else
		row.tag:SetText('')
		row.tag:Hide()
	end

	local mem = Core.GetMemory(addon)
	row.memory:SetText(T.FormatMemory(mem))

	local rightAnchor = showTag and row.tag or row.memory
	local rightPoint = (showTag or mem > 0) and 'LEFT' or 'RIGHT'
	local rightOffset = (showTag or mem > 0) and -10 or 0

	local isFav = AddonManager.Favorites.IsFavorite(addon.name)
	row.star:ClearAllPoints()
	if isFav then
		row.star:SetPoint('RIGHT', rightAnchor, rightPoint, rightOffset, 0)
		row.star:Show()
		rightAnchor, rightPoint, rightOffset = row.star, 'LEFT', -6
	else
		row.star:Hide()
	end

	row.count:ClearAllPoints()
	if data.childCount > 0 and data.collapsed then
		row.count:SetText('+' .. data.childCount)
		row.count:SetPoint('RIGHT', rightAnchor, rightPoint, rightOffset, 0)
		row.count:Show()
		rightAnchor, rightPoint, rightOffset = row.count, 'LEFT', -6
	else
		row.count:Hide()
	end

	row.title:SetPoint('RIGHT', rightAnchor, rightPoint, rightOffset, 0)
	row:PaintSelection()
	if row:IsMouseOver() then
		row.hover:Show()
	else
		row.hover:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- List pane
----------------------------------------------------------------------------------------------------

local function BuildList(parent)
	local pane = CreateFrame('Frame', nil, parent)
	pane:SetPoint('TOPLEFT', ui.toolbar, 'BOTTOMLEFT', 0, -GAP)
	pane:SetPoint('BOTTOM', ui.nav, 'BOTTOM', 0, 0)
	pane:SetPoint('RIGHT', ui.details, 'LEFT', -GAP, 0)
	T.Fill(pane, T.color.pane)
	T.Border(pane, T.color.line)
	ui.listPane = pane

	local header = CreateFrame('Frame', nil, pane)
	header:SetPoint('TOPLEFT')
	header:SetPoint('TOPRIGHT')
	header:SetHeight(32)
	T.Fill(header, T.color.header, 'BACKGROUND', 1)
	T.Line(header, 'BOTTOM')
	ui.listHeader = header

	ui.listTitle = T.Text(header, 'title')
	ui.listTitle:SetPoint('LEFT', 12, 0)
	ui.listCount = T.Text(header, 'meta', T.color.faint)
	ui.listCount:SetPoint('LEFT', ui.listTitle, 'RIGHT', 8, -1)

	ui.bulk = T.IconButton(header, 'more', 22, 'Actions for this list', function(self)
		local shown = ShownAddons()
		local label = #shown == #Core.addons and 'all' or ('the ' .. #shown .. ' shown')
		T.OpenMenu(self, {
			{
				text = 'Enable ' .. label,
				disabled = #shown == 0,
				onClick = function()
					Core.SetEnabledMany(shown, true)
				end,
			},
			{
				text = 'Disable ' .. label,
				disabled = #shown == 0,
				onClick = function()
					T.Confirm(string.format("Disable %s addons? Lib's Addon Tools and locked favorites stay on.", label), function()
						Core.SetEnabledMany(shown, false)
					end, DISABLE)
				end,
			},
			{
				text = 'Expand all',
				divider = true,
				onClick = function()
					wipe(AddonManager.DB.collapsed)
					View.RefreshList()
				end,
			},
			{
				text = 'Collapse all',
				onClick = function()
					for _, addon in ipairs(Core.addons) do
						if #addon.children > 0 then
							AddonManager.DB.collapsed[addon.name] = true
						end
					end
					View.RefreshList()
				end,
			},
		})
	end)
	ui.bulk:SetPoint('RIGHT', header, 'RIGHT', -6, 0)

	local scrollBox = CreateFrame('Frame', nil, pane, 'WowScrollBoxList')
	local scrollBar = CreateFrame('EventFrame', nil, pane, 'MinimalScrollBar')
	scrollBar:SetPoint('TOPRIGHT', header, 'BOTTOMRIGHT', -4, -6)
	scrollBar:SetPoint('BOTTOMRIGHT', pane, 'BOTTOMRIGHT', -4, 6)

	local view = CreateScrollBoxListLinearView(2, 2, 0, 0, 0)
	view:SetElementExtent(ROW_H)
	view:SetElementInitializer('Button', InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	local withBar = {
		CreateAnchor('TOPLEFT', header, 'BOTTOMLEFT', 0, 0),
		CreateAnchor('BOTTOMRIGHT', scrollBar, 'BOTTOMLEFT', -2, -6),
	}
	local withoutBar = {
		CreateAnchor('TOPLEFT', header, 'BOTTOMLEFT', 0, 0),
		CreateAnchor('BOTTOMRIGHT', pane, 'BOTTOMRIGHT', 0, 0),
	}
	if ScrollUtil.AddManagedScrollBarVisibilityBehavior then
		ScrollUtil.AddManagedScrollBarVisibilityBehavior(scrollBox, scrollBar, withBar, withoutBar)
	else
		scrollBox:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, 0)
		scrollBox:SetPoint('BOTTOMRIGHT', scrollBar, 'BOTTOMLEFT', -2, -6)
	end
	ui.scrollBox = scrollBox

	-- Empty state
	local empty = CreateFrame('Frame', nil, pane)
	empty:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 20, -40)
	empty:SetPoint('TOPRIGHT', header, 'BOTTOMRIGHT', -20, -40)
	empty:SetHeight(90)
	empty.title = T.Text(empty, 'title', T.color.muted)
	empty.title:SetPoint('TOP')
	empty.title:SetJustifyH('CENTER')
	empty.title:SetWidth(260)
	empty.title:SetWordWrap(true)
	empty.hint = T.Text(empty, 'meta', T.color.faint)
	empty.hint:SetPoint('TOP', empty.title, 'BOTTOM', 0, -6)
	empty.hint:SetJustifyH('CENTER')
	empty.hint:SetWidth(260)
	empty.hint:SetWordWrap(true)
	empty.action = T.TextButton(empty, 'Clear search', function()
		ui.search:SetText('')
		state.search = ''
		View.RefreshList()
	end)
	empty.action:SetPoint('TOP', empty.hint, 'BOTTOM', 0, -12)
	empty:Hide()
	ui.empty = empty
end

local VIEW_TITLE = {}
for _, info in ipairs(VIEWS) do
	VIEW_TITLE[info.key] = info.label
end

local EMPTY_TEXT = {
	enabled = { 'Nothing is enabled here', 'Turn an addon on from All addons.' },
	disabled = { 'Everything is enabled', 'Addons you turn off will be listed here.' },
	favorites = {
		'No favorites yet',
		'Right-click an addon, or use the star in its details, to keep it close at hand.',
	},
	changes = { 'Nothing waiting for a reload', 'Addons you turn on or off will be listed here until you reload.' },
	problems = {
		'All addons are healthy',
		'Addons that are out of date or missing something they need will show up here.',
	},
	lod = { 'No load-on-demand addons', 'Some addons only load when they are needed; none are installed.' },
}

function View.RefreshList()
	if not ui.scrollBox then
		return
	end
	local rows, matched = BuildRows()
	local dataProvider = CreateDataProvider(rows)
	ui.scrollBox:SetDataProvider(dataProvider, ScrollBoxConstants.RetainScrollPosition)

	local title = state.view == 'category' and state.category or VIEW_TITLE[state.view] or 'Addons'
	ui.listTitle:SetText(title)
	ui.listCount:SetText(matched == 1 and '1 addon' or (matched .. ' addons'))

	if #rows == 0 then
		if state.search ~= '' then
			ui.empty.title:SetText(string.format('No addons match "%s"', state.search))
			ui.empty.hint:SetText('Search looks at titles, folder names, authors and notes.')
			ui.empty.action:Show()
		else
			local text = EMPTY_TEXT[state.view] or { 'No addons here', '' }
			ui.empty.title:SetText(text[1])
			ui.empty.hint:SetText(text[2])
			ui.empty.action:Hide()
		end
		ui.empty:Show()
	else
		ui.empty:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- Details pane
----------------------------------------------------------------------------------------------------

local function DetailLine(index)
	local pool = ui.detailLines
	local line = pool[index]
	if line then
		return line
	end
	line = CreateFrame('Button', nil, ui.detailChild)
	line:SetHeight(20)
	line.hover = T.Fill(line, T.color.hover)
	line.hover:Hide()
	line.dot = line:CreateTexture(nil, 'ARTWORK')
	line.dot:SetSize(12, 12)
	line.dot:SetPoint('LEFT', 2, 0)
	T.SetIcon(line.dot, 'dot')
	line.label = T.Text(line, 'body')
	line.label:SetPoint('LEFT', line.dot, 'RIGHT', 6, 0)
	line.value = T.Text(line, 'meta', T.color.faint)
	line.value:SetPoint('RIGHT', -4, 0)
	line.value:SetJustifyH('RIGHT')
	line.label:SetPoint('RIGHT', line.value, 'LEFT', -6, 0)
	line:SetScript('OnEnter', function(self)
		if self.target then
			self.hover:Show()
		end
	end)
	line:SetScript('OnLeave', function(self)
		self.hover:Hide()
	end)
	line:SetScript('OnClick', function(self)
		if self.target then
			Select(self.target)
			if ui.scrollBox then
				ui.scrollBox:ScrollToElementDataByPredicate(function(data)
					return data.addon == self.target
				end)
			end
		end
	end)
	pool[index] = line
	return line
end

local function DetailHeading(index)
	local pool = ui.detailHeadings
	local fs = pool[index]
	if not fs then
		fs = T.Text(ui.detailChild, 'small', T.color.faint)
		pool[index] = fs
	end
	return fs
end

local function BuildDetails(parent)
	local pane = CreateFrame('Frame', nil, parent)
	pane:SetPoint('TOP', ui.toolbar, 'BOTTOM', 0, -GAP)
	pane:SetPoint('RIGHT', parent, 'RIGHT', -6, 0)
	pane:SetPoint('BOTTOM', ui.nav, 'BOTTOM', 0, 0)
	pane:SetWidth(250)
	T.Fill(pane, T.color.raised)
	T.Border(pane, T.color.line)
	ui.details = pane

	local scroll = CreateFrame('ScrollFrame', nil, pane)
	scroll:SetPoint('TOPLEFT', 0, -1)
	scroll:SetPoint('BOTTOMRIGHT', -12, 1)
	scroll.ScrollBar = CreateFrame('EventFrame', nil, scroll, 'MinimalScrollBar')
	scroll.ScrollBar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 2, -6)
	scroll.ScrollBar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 2, 6)
	ScrollUtil.InitScrollFrameWithScrollBar(scroll, scroll.ScrollBar)
	ui.detailScroll = scroll

	local child = CreateFrame('Frame', nil, scroll)
	child:SetSize(236, 1)
	scroll:SetScrollChild(child)
	scroll:SetScript('OnSizeChanged', function(self, width)
		child:SetWidth(math.max(width, 1))
	end)
	ui.detailChild = child

	-- Header
	ui.dTile = child:CreateTexture(nil, 'ARTWORK')
	ui.dTile:SetTexture(T.WHITE)
	ui.dTile:SetVertexColor(1, 1, 1, 0.08)
	ui.dTile:SetSize(36, 36)
	ui.dTile:SetPoint('TOPLEFT', 14, -14)
	ui.dInitial = T.Text(child, 'title', T.color.muted)
	T.Bump(ui.dInitial, 3)
	ui.dInitial:SetPoint('CENTER', ui.dTile, 'CENTER')
	ui.dIcon = child:CreateTexture(nil, 'ARTWORK', nil, 1)
	ui.dIcon:SetAllPoints(ui.dTile)

	ui.dStar = LibAT.UI.CreateFavoriteButton(child, 16, function(_, isFavorite)
		if state.selected then
			AddonManager.Favorites.Set(state.selected, isFavorite)
		end
	end)
	ui.dStar:SetPoint('TOPRIGHT', -8, -10)
	ui.dStar:SetScript('OnEnter', function(self)
		T.ShowTip(self, self:IsFavorite() and 'Remove from favorites' or 'Add to favorites')
	end)
	ui.dStar:SetScript('OnLeave', GameTooltip_Hide)

	ui.dTitle = T.Text(child, 'title')
	T.Bump(ui.dTitle, 2)
	ui.dTitle:SetPoint('TOPLEFT', ui.dTile, 'TOPRIGHT', 10, 0)
	ui.dTitle:SetPoint('RIGHT', ui.dStar, 'LEFT', -4, 0)
	ui.dTitle:SetWordWrap(true)
	ui.dTitle:SetMaxLines(2)

	ui.dByline = T.Text(child, 'meta', T.color.muted)
	ui.dByline:SetPoint('TOPLEFT', ui.dTitle, 'BOTTOMLEFT', 0, -3)
	ui.dByline:SetPoint('RIGHT', child, 'RIGHT', -12, 0)

	-- Status
	ui.dStatusDot = child:CreateTexture(nil, 'ARTWORK')
	ui.dStatusDot:SetSize(12, 12)
	T.SetIcon(ui.dStatusDot, 'dot')
	ui.dStatus = T.Text(child, 'name')
	ui.dStatus:SetPoint('LEFT', ui.dStatusDot, 'RIGHT', 6, 0)
	ui.dStatus:SetPoint('RIGHT', child, 'RIGHT', -12, 0)
	ui.dScope = T.Text(child, 'meta', T.color.faint)
	ui.dScope:SetPoint('TOPLEFT', ui.dStatus, 'BOTTOMLEFT', 0, -3)
	ui.dScope:SetPoint('RIGHT', child, 'RIGHT', -12, 0)
	ui.dScope:SetWordWrap(true)

	ui.dToggle = T.TextButton(child, 'Disable', function()
		local addon = state.selected and Core.Get(state.selected)
		if addon then
			ToggleAddon(addon)
		end
	end)
	ui.dLoad = T.TextButton(child, 'Load now', function()
		local addon = state.selected and Core.Get(state.selected)
		if addon then
			local loaded, reason = Core.LoadNow(addon)
			if not loaded and reason then
				UIErrorsFrame:AddMessage(reason, 1, 0.3, 0.3)
			end
		end
	end)
	ui.dLoad:SetPoint('LEFT', ui.dToggle, 'RIGHT', 6, 0)

	ui.dNotes = T.Text(child, 'body', T.color.muted)
	ui.dNotes:SetWordWrap(true)
	ui.dNotes:SetJustifyV('TOP')
	ui.dNotes:SetSpacing(2)

	ui.detailLines = {}
	ui.detailHeadings = {}

	-- Overview shown when nothing is selected
	ui.dOverview = T.Text(child, 'meta', T.color.faint)
	ui.dOverview:SetWordWrap(true)
	ui.dOverview:SetPoint('TOPLEFT', 14, -14)
	ui.dOverview:SetPoint('RIGHT', child, 'RIGHT', -12, 0)
end

local function AddonDotColor(addon)
	if not addon then
		return T.color.bad
	end
	if Core.IsLoaded(addon) then
		return T.color.good
	end
	if Core.IsEnabled(addon) then
		return T.color.warn
	end
	return T.color.off
end

function View.RefreshDetails()
	if not ui.details then
		return
	end
	local child = ui.detailChild
	local addon = state.selected and Core.Get(state.selected)

	local headingIndex, lineIndex = 0, 0
	local y

	local function Heading(text)
		headingIndex = headingIndex + 1
		local fs = DetailHeading(headingIndex)
		fs:SetText(text)
		fs:ClearAllPoints()
		fs:SetPoint('TOPLEFT', child, 'TOPLEFT', 14, y - 14)
		fs:Show()
		y = y - 14 - fs:GetStringHeight() - 6
	end

	local function Line(label, value, dotColor, target, labelColor)
		lineIndex = lineIndex + 1
		local line = DetailLine(lineIndex)
		line.label:SetText(label)
		T.SetColor(line.label, labelColor or T.color.text)
		line.value:SetText(value or '')
		if dotColor then
			line.dot:SetVertexColor(dotColor[1], dotColor[2], dotColor[3])
			line.dot:Show()
			line.label:SetPoint('LEFT', line.dot, 'RIGHT', 6, 0)
		else
			line.dot:Hide()
			line.label:SetPoint('LEFT', line, 'LEFT', 4, 0)
		end
		line.target = target
		line:ClearAllPoints()
		line:SetPoint('TOPLEFT', child, 'TOPLEFT', 10, y)
		line:SetPoint('RIGHT', child, 'RIGHT', -8, 0)
		line:Show()
		y = y - 20
	end

	local header = {
		ui.dTile,
		ui.dInitial,
		ui.dIcon,
		ui.dStar,
		ui.dTitle,
		ui.dByline,
		ui.dStatusDot,
		ui.dStatus,
		ui.dScope,
		ui.dToggle,
		ui.dNotes,
	}

	if not addon then
		for _, region in ipairs(header) do
			region:Hide()
		end
		ui.dLoad:Hide()
		local total, enabled, loaded, memory = #Core.addons, 0, 0, 0
		for _, a in ipairs(Core.addons) do
			if Core.IsEnabled(a) then
				enabled = enabled + 1
			end
			if Core.IsLoaded(a) then
				loaded = loaded + 1
				memory = memory + Core.GetMemory(a)
			end
		end
		ui.dOverview:SetText('Select an addon to see what it does, what it needs, and to turn it on or off. Double-click a row to toggle it.')
		ui.dOverview:Show()
		y = -14 - ui.dOverview:GetStringHeight()

		Heading('Installed')
		Line('Addons', tostring(total))
		Line('Enabled', tostring(enabled))
		Line('Running now', tostring(loaded))
		Line('Memory in use', T.FormatMemory(memory))

		local heavy = {}
		for _, a in ipairs(Core.addons) do
			if Core.GetMemory(a) > 0 then
				table.insert(heavy, a)
			end
		end
		table.sort(heavy, function(a, b)
			return Core.GetMemory(a) > Core.GetMemory(b)
		end)
		if #heavy > 0 then
			Heading('Using the most memory')
			for i = 1, math.min(6, #heavy) do
				Line(heavy[i].plainTitle, T.FormatMemory(Core.GetMemory(heavy[i])), T.color.good, heavy[i])
			end
		end
	else
		ui.dOverview:Hide()
		for _, region in ipairs(header) do
			region:Show()
		end

		PaintIcon(ui.dIcon, ui.dInitial, ui.dTile, addon)
		ui.dStar:SetFavorite(AddonManager.Favorites.IsFavorite(addon.name))
		ui.dTitle:SetText(addon.plainTitle)
		local byline = {}
		if addon.version ~= '' then
			table.insert(byline, addon.version)
		end
		if addon.author ~= '' then
			table.insert(byline, 'by ' .. addon.author)
		end
		ui.dByline:SetText(#byline > 0 and table.concat(byline, '  -  ') or addon.name)

		local statusKey, statusLabel, tone = Core.GetStatus(addon)
		local color = TONE_COLOR[tone] or T.color.muted
		ui.dStatusDot:SetVertexColor(color[1], color[2], color[3])
		ui.dStatus:SetText(statusLabel)
		T.SetColor(ui.dStatus, tone == 'muted' and T.color.muted or color)
		ui.dStatusDot:ClearAllPoints()
		local titleBottom = math.max(ui.dTitle:GetStringHeight() + 3 + ui.dByline:GetStringHeight(), 36)
		ui.dStatusDot:SetPoint('TOPLEFT', child, 'TOPLEFT', 14, -14 - titleBottom - 16)

		local scopeText
		local stateValue = Core.GetEnableState(addon)
		if Core.IsAllCharacters() then
			if stateValue >= Core.Enum_All then
				scopeText = 'On for every character'
			elseif stateValue > 0 then
				scopeText = 'On for some characters'
			else
				scopeText = 'Off for every character'
			end
		else
			scopeText = (stateValue > 0 and 'On for ' or 'Off for ') .. Core.CharacterLabel(Core.character)
		end
		if statusKey == 'dep-disabled' then
			scopeText = scopeText .. '. It will not load until the addons it requires are enabled.'
		elseif statusKey == 'reload-on' or statusKey == 'reload-off' then
			scopeText = scopeText .. '. Reload to apply.'
		end
		ui.dScope:SetText(scopeText)

		local enabled = stateValue > 0 and (stateValue >= Core.Enum_All or not Core.IsAllCharacters())
		ui.dToggle:SetLabel(enabled and 'Disable' or 'Enable')
		ui.dToggle:ClearAllPoints()
		ui.dToggle:SetPoint('TOPLEFT', ui.dScope, 'BOTTOMLEFT', -18, -10)
		if enabled and AddonManager.Favorites.IsLockedFavorite(addon.name) then
			ui.dToggle:Disable()
			ui.dToggle.tooltip = 'Locked favorite'
			ui.dToggle.hint = 'Turn off "Keep favorites enabled" in options to disable it.'
		else
			ui.dToggle:Enable()
			ui.dToggle.tooltip = nil
		end
		ui.dLoad:SetShown(addon.lod and Core.IsEnabled(addon) and not Core.IsLoaded(addon))

		y = -14 - titleBottom - 16 - 17 - ui.dScope:GetStringHeight() - 10 - 24

		if addon.notes ~= '' then
			ui.dNotes:SetText(addon.notes)
			ui.dNotes:ClearAllPoints()
			ui.dNotes:SetPoint('TOPLEFT', child, 'TOPLEFT', 14, y - 14)
			ui.dNotes:SetPoint('RIGHT', child, 'RIGHT', -12, 0)
			ui.dNotes:Show()
			y = y - 14 - ui.dNotes:GetStringHeight()
		else
			ui.dNotes:Hide()
		end

		Heading('Details')
		Line('Folder', addon.name, nil, nil, T.color.muted)
		Line('Category', CategoryOf(addon), nil, nil, T.color.muted)
		local mem = Core.GetMemory(addon)
		if mem > 0 then
			Line('Memory', T.FormatMemory(mem), nil, nil, T.color.muted)
		end
		local share = Core.GetCPUShare(addon)
		if share then
			local pct = share * 100
			Line('CPU (session)', pct >= 1 and string.format('%.0f%%', pct) or string.format('%.2f%%', pct), nil, nil, T.color.muted)
		end
		if addon.parent then
			Line('Part of', addon.parent.plainTitle, AddonDotColor(addon.parent), addon.parent)
		end

		if #addon.deps > 0 then
			Heading('Requires')
			for _, depName in ipairs(addon.deps) do
				local dep = Core.byName[depName]
				local value
				if not dep then
					value = 'Missing'
				elseif Core.IsLoaded(dep) then
					value = 'Loaded'
				elseif Core.IsEnabled(dep) then
					value = 'Enabled'
				else
					value = 'Disabled'
				end
				Line(dep and dep.plainTitle or depName, value, AddonDotColor(dep), dep)
			end
		end

		local optional = {}
		for _, depName in ipairs(addon.optDeps) do
			if Core.byName[depName] then
				table.insert(optional, Core.byName[depName])
			end
		end
		if #optional > 0 then
			Heading('Works with')
			for _, dep in ipairs(optional) do
				Line(dep.plainTitle, Core.IsLoaded(dep) and 'Loaded' or nil, AddonDotColor(dep), dep)
			end
		end

		local dependents = Core.GetDependents(addon)
		if #dependents > 0 then
			Heading(string.format('Required by (%d)', #dependents))
			for _, other in ipairs(dependents) do
				Line(other.plainTitle, nil, AddonDotColor(other), other)
			end
		end

		if #addon.children > 0 then
			Heading(string.format('Modules (%d)', #addon.children))
			for _, other in ipairs(addon.children) do
				Line(other.plainTitle, nil, AddonDotColor(other), other)
			end
		end
	end

	for i = headingIndex + 1, #ui.detailHeadings do
		ui.detailHeadings[i]:Hide()
	end
	for i = lineIndex + 1, #ui.detailLines do
		ui.detailLines[i]:Hide()
	end
	child:SetHeight(-y + 14)
end

----------------------------------------------------------------------------------------------------
-- Footer
----------------------------------------------------------------------------------------------------

local function BuildFooter(parent)
	local footer = CreateFrame('Frame', nil, parent)
	footer:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', 4, 4)
	footer:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', -6, 4)
	footer:SetHeight(28)
	ui.footer = footer

	ui.reload = T.TextButton(footer, 'Reload UI', function()
		LibAT:SafeReloadUI()
	end)
	ui.reload:SetPoint('RIGHT', footer, 'RIGHT', 0, 0)

	ui.reloadPrimary = T.TextButton(footer, 'Reload now', function()
		LibAT:SafeReloadUI()
	end, true)
	ui.reloadPrimary:SetPoint('RIGHT', footer, 'RIGHT', 0, 0)

	ui.revert = T.TextButton(footer, 'Undo changes', function()
		Core.RevertToSession()
	end)
	ui.revert:SetPoint('RIGHT', ui.reloadPrimary, 'LEFT', -6, 0)
	ui.revert.tooltip = 'Undo changes'
	ui.revert.hint = "Put this character's addons back to how they were when you logged in or last reloaded."

	ui.pendingDot = footer:CreateTexture(nil, 'ARTWORK')
	ui.pendingDot:SetSize(12, 12)
	ui.pendingDot:SetPoint('LEFT', footer, 'LEFT', 4, 0)
	T.SetIcon(ui.pendingDot, 'dot')
	ui.pendingDot:SetVertexColor(T.color.warn[1], T.color.warn[2], T.color.warn[3])

	ui.summary = T.Text(footer, 'meta', T.color.muted)
	ui.summary:SetPoint('LEFT', footer, 'LEFT', 4, 0)
	ui.summary:SetPoint('RIGHT', ui.revert, 'LEFT', -12, 0)

	-- Clicking the pending message jumps to the list of changes
	ui.pendingHit = CreateFrame('Button', nil, footer)
	ui.pendingHit:SetAllPoints(ui.summary)
	ui.pendingHit:SetScript('OnClick', function()
		state.view = 'changes'
		state.category = nil
		View.Refresh()
	end)
	ui.pendingHit:SetScript('OnEnter', function(self)
		T.ShowTip(self, 'Show what changed', 'Lists every addon that will load or unload when you reload.')
	end)
	ui.pendingHit:SetScript('OnLeave', GameTooltip_Hide)
end

local function RefreshFooter()
	local pending = #Core.GetPendingReload()
	if Core.VersionCheckChanged() then
		pending = pending + 1
	end

	if pending > 0 then
		ui.pendingDot:Show()
		ui.summary:ClearAllPoints()
		ui.summary:SetPoint('LEFT', ui.pendingDot, 'RIGHT', 6, 0)
		ui.summary:SetPoint('RIGHT', ui.revert, 'LEFT', -12, 0)
		T.SetColor(ui.summary, T.color.warn)
		ui.summary:SetText(pending == 1 and '1 change takes effect after a reload' or (pending .. ' changes take effect after a reload'))
		ui.pendingHit:Show()
		ui.reload:Hide()
		ui.reloadPrimary:Show()
		ui.revert:Show()
	else
		ui.pendingDot:Hide()
		ui.summary:ClearAllPoints()
		ui.summary:SetPoint('LEFT', ui.footer, 'LEFT', 4, 0)
		ui.summary:SetPoint('RIGHT', ui.reload, 'LEFT', -12, 0)
		T.SetColor(ui.summary, T.color.faint)
		local enabled, memory = 0, 0
		for _, addon in ipairs(Core.addons) do
			if Core.IsEnabled(addon) then
				enabled = enabled + 1
			end
			memory = memory + Core.GetMemory(addon)
		end
		local text = string.format('%d of %d addons enabled', enabled, #Core.addons)
		if memory > 0 then
			text = text .. '  -  ' .. T.FormatMemory(memory) .. ' in use'
		end
		ui.summary:SetText(text)
		ui.pendingHit:Hide()
		ui.reload:Show()
		ui.reloadPrimary:Hide()
		ui.revert:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- Public
----------------------------------------------------------------------------------------------------

---Refresh everything that depends on addon state
function View.Refresh()
	if not ui.root then
		return
	end
	if not ui.root:IsVisible() then
		dirty = true
		return
	end
	dirty = false
	Core.EnsureScanned()
	if state.selected and not Core.byName[state.selected] then
		state.selected = nil
	end
	RefreshNav()
	RefreshToolbar()
	View.RefreshList()
	View.RefreshDetails()
	RefreshFooter()
end

local function OnSizeChanged()
	if not ui.root or not ui.details then
		return
	end
	local width = ui.root:GetWidth() or 0
	local detailWidth = math.floor(math.max(230, math.min(300, (width - NAV_W) * 0.34)))
	ui.details:SetWidth(detailWidth)

	-- Narrow windows drop the details pane; the row menu still offers every action
	local narrow = width < 780
	ui.details:SetShown(not narrow)
	ui.listPane:ClearAllPoints()
	ui.listPane:SetPoint('TOPLEFT', ui.toolbar, 'BOTTOMLEFT', 0, -GAP)
	ui.listPane:SetPoint('BOTTOM', ui.nav, 'BOTTOM', 0, 0)
	if narrow then
		ui.listPane:SetPoint('RIGHT', ui.root, 'RIGHT', -6, 0)
	else
		ui.listPane:SetPoint('RIGHT', ui.details, 'LEFT', -GAP, 0)
	end

	local compact = width < 900
	ui.character:SetWidth(compact and 140 or 176)
	ui.profile:SetWidth(compact and 160 or 190)
end

---Build the view inside a parent frame
---@param parent Frame
function View.Build(parent)
	T = AddonManager.Theme
	Core = AddonManager.Core
	TONE_COLOR = {
		good = T.color.good,
		warn = T.color.warn,
		bad = T.color.bad,
		muted = T.color.faint,
	}

	local root = CreateFrame('Frame', nil, parent)
	root:SetAllPoints(parent)
	ui.root = root

	BuildNav(root)
	BuildToolbar(root)
	BuildDetails(root)
	BuildList(root)
	BuildFooter(root)

	root:SetScript('OnSizeChanged', OnSizeChanged)
	root:SetScript('OnShow', function()
		Core.UpdateMemory()
		View.Refresh()
		if ui.ticker then
			ui.ticker:Cancel()
		end
		ui.ticker = C_Timer.NewTicker(15, function()
			if root:IsVisible() then
				Core.UpdateMemory(true)
				View.Refresh()
			end
		end)
	end)
	root:SetScript('OnHide', function()
		T.CloseMenu()
		if ui.ticker then
			ui.ticker:Cancel()
			ui.ticker = nil
		end
	end)

	Core.OnChange(function()
		View.Refresh()
	end)

	OnSizeChanged()
	if root:IsVisible() then
		root:GetScript('OnShow')(root)
	end
end

---Refresh if something changed while hidden
function View.OnActivate()
	if dirty then
		View.Refresh()
	end
end
