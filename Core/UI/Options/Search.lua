---@class LibAT
local LibAT = LibAT
local L = LibAT.UI.OptionWidgets.L

-- Settings search for the settings window. Walks an addon's options table once, then matches
-- every typed word against the option name, its description and where it lives.

---@class LibAT.UI.Options.Search
local Search = {}
LibAT.UI.Options = LibAT.UI.Options or {}
LibAT.UI.Options.Search = Search

local DIALOG = 'AceConfigDialog-3.0-LibAT'
local MAX_RESULTS = 40
local MAX_DEPTH = 7

-- Everyday words mapped to the words the settings use
local SYNONYMS = {
	hp = 'health',
	life = 'health',
	mana = 'power',
	energy = 'power',
	mp = 'power',
	colour = 'color',
	size = 'scale',
	bigger = 'scale',
	smaller = 'scale',
	move = 'position',
	moving = 'position',
	place = 'position',
	buffs = 'buff',
	debuffs = 'debuff',
	auras = 'aura',
	hotkey = 'keybind',
	keybinds = 'keybind',
	bars = 'bar',
	castbar = 'cast',
	portraits = 'portrait',
	see = 'alpha',
	transparency = 'alpha',
	opacity = 'alpha',
}

---@class LibAT.UI.Options.SearchEntry
---@field name string
---@field lowerName string
---@field lowerDesc string
---@field lowerCrumb string
---@field crumb string
---@field path string[]
---@field isGroup boolean

---@type table<string, LibAT.UI.Options.SearchEntry[]>
local indexes = {}

local function Clean(text)
	if type(text) ~= 'string' then
		return nil
	end
	text = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|T.-|t', ''):gsub('|A.-|a', ''):gsub('\n', ' ')
	text = strtrim(text)
	if text == '' then
		return nil
	end
	return text
end

---Resolve a name/desc/hidden member the way AceConfig does, without letting errors escape
local function Resolve(value, info)
	if type(value) == 'function' then
		local ok, result = pcall(value, info)
		if ok then
			return result
		end
		return nil
	end
	return value
end

local function IsHidden(option, info)
	return Resolve(option.hidden, info) == true or Resolve(option.dialogHidden, info) == true
end

local function Walk(appName, root, group, path, crumbs, depth, out)
	if depth > MAX_DEPTH or type(group.args) ~= 'table' then
		return
	end
	for key, option in pairs(group.args) do
		if type(option) == 'table' and type(key) == 'string' then
			local childPath = {}
			for i = 1, #path do
				childPath[i] = path[i]
			end
			childPath[#childPath + 1] = key
			local info = { options = root, option = option, arg = option.arg, handler = option.handler, type = option.type, [0] = appName }
			for i = 1, #childPath do
				info[i] = childPath[i]
			end

			if not IsHidden(option, info) then
				local name = Clean(Resolve(option.name, info))
				local isGroup = option.type == 'group'
				local isInline = isGroup and (option.inline or option.guiInline or option.dialogInline)
				local skip = option.type == 'description' or option.type == 'header'

				if name and not skip and not isInline then
					local desc = Clean(Resolve(option.desc, info)) or ''
					local crumb = table.concat(crumbs, ' > ')
					out[#out + 1] = {
						name = name,
						lowerName = name:lower(),
						lowerDesc = desc:lower(),
						lowerCrumb = crumb:lower(),
						crumb = crumb,
						path = childPath,
						isGroup = isGroup,
					}
				end

				if isGroup then
					local childCrumbs = {}
					for i = 1, #crumbs do
						childCrumbs[i] = crumbs[i]
					end
					if name and not isInline then
						childCrumbs[#childCrumbs + 1] = name
					end
					Walk(appName, root, option, childPath, childCrumbs, depth + 1, out)
				end
			end
		end
	end
end

---@param appName string
---@return LibAT.UI.Options.SearchEntry[]
function Search:GetIndex(appName)
	if indexes[appName] then
		return indexes[appName]
	end
	local registry = LibStub('AceConfigRegistry-3.0')
	local app = registry:GetOptionsTable(appName)
	local index = {}
	if app then
		local root = app('dialog', DIALOG)
		Walk(appName, root, root, {}, {}, 1, index)
	end
	indexes[appName] = index
	return index
end

---@param appName? string Forget one addon's settings, or every addon's when nil
function Search:Invalidate(appName)
	if appName then
		indexes[appName] = nil
	else
		wipe(indexes)
	end
end

---Score an entry against the query words (0 = no match)
---@param entry LibAT.UI.Options.SearchEntry
---@param words string[]
---@return number
local function Score(entry, words)
	local total = 0
	for _, word in ipairs(words) do
		local best = 0
		local alt = SYNONYMS[word]
		for _, w in ipairs({ word, alt }) do
			if w then
				if entry.lowerName == w then
					best = math.max(best, 100)
				elseif entry.lowerName:sub(1, #w) == w then
					best = math.max(best, 60)
				elseif entry.lowerName:find(w, 1, true) then
					best = math.max(best, 40)
				elseif entry.lowerDesc:find(w, 1, true) then
					best = math.max(best, 12)
				elseif entry.lowerCrumb:find(w, 1, true) then
					best = math.max(best, 6)
				end
			end
		end
		if best == 0 then
			return 0
		end
		total = total + best
	end
	if entry.isGroup then
		total = total + 5
	end
	-- Shallower settings first when scores tie
	return total - #entry.path * 0.5
end

---Search and return ranked entries
---@param appName string
---@param text string
---@return LibAT.UI.Options.SearchEntry[]
function Search:Find(appName, text)
	local words = {}
	for word in text:lower():gmatch('%S+') do
		if #word >= 2 then
			words[#words + 1] = word
		end
	end
	local results = {}
	if #words == 0 then
		return results
	end
	local scored = {}
	for _, entry in ipairs(self:GetIndex(appName)) do
		local score = Score(entry, words)
		if score > 0 then
			scored[#scored + 1] = { entry = entry, score = score }
		end
	end
	table.sort(scored, function(a, b)
		if a.score == b.score then
			return a.entry.name < b.entry.name
		end
		return a.score > b.score
	end)
	for i = 1, math.min(MAX_RESULTS, #scored) do
		results[i] = scored[i].entry
	end
	return results
end

---Open the page holding an entry and bring the setting into view
---@param appName string
---@param entry LibAT.UI.Options.SearchEntry
function Search:Go(appName, entry)
	local ACD = LibStub(DIALOG)
	local groupPath = {}
	local optionKey
	if entry.isGroup then
		groupPath = entry.path
	else
		for i = 1, #entry.path - 1 do
			groupPath[i] = entry.path[i]
		end
		optionKey = entry.path[#entry.path]
	end
	ACD:Navigate(appName, groupPath, optionKey)
end

---Run a search for the window's search box
---@param window table The LibAT-OptionsWindow widget
---@param text string
function Search:Run(window, text)
	local appName = window:GetUserData('appName')
	if not appName or not text or strtrim(text) == '' then
		window:ClearSearch()
		return
	end
	local results = {}
	for i, entry in ipairs(self:Find(appName, text)) do
		results[i] = {
			text = entry.name,
			sub = entry.crumb ~= '' and entry.crumb or L['Main page'],
			onClick = function()
				Search:Go(appName, entry)
			end,
		}
	end
	window:ShowResults(results)
end

local registry = LibStub('AceConfigRegistry-3.0', true)
if registry then
	registry.RegisterCallback(Search, 'ConfigTableChange', function(_, appName)
		Search:Invalidate(appName)
	end)
end
