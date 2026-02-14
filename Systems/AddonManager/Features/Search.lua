---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Search: Full-text search engine for addon metadata
-- Searches name, title, author, notes with highlighting

local Search = {}
AddonManager.Search = Search

----------------------------------------------------------------------------------------------------
-- Search Configuration
----------------------------------------------------------------------------------------------------

Search.SearchableFields = {
	'name',
	'title',
	'author',
	'notes',
	'version',
	'category',
}

----------------------------------------------------------------------------------------------------
-- Search Engine
----------------------------------------------------------------------------------------------------

---Search addons by term across all searchable fields
---@param addons LibAT.AddonManager.AddonMetadata[] List of addons to search
---@param searchTerm string Search term (case-insensitive)
---@return LibAT.AddonManager.AddonMetadata[] matches Matching addons
function Search.SearchAddons(addons, searchTerm)
	if not searchTerm or searchTerm == '' then
		return addons
	end

	local results = {}
	local searchLower = searchTerm:lower()

	for _, addon in ipairs(addons) do
		if Search.AddonMatchesSearch(addon, searchLower) then
			table.insert(results, addon)
		end
	end

	return results
end

---Check if an addon matches the search term
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param searchLower string Lowercase search term
---@return boolean matches Whether addon matches search
function Search.AddonMatchesSearch(addon, searchLower)
	for _, field in ipairs(Search.SearchableFields) do
		local value = addon[field]
		if value and type(value) == 'string' then
			if value:lower():find(searchLower, 1, true) then
				return true
			end
		end
	end

	-- Also search dependencies
	if addon.dependencies then
		for _, dep in ipairs(addon.dependencies) do
			if dep:lower():find(searchLower, 1, true) then
				return true
			end
		end
	end

	return false
end

----------------------------------------------------------------------------------------------------
-- Highlight Search Terms
----------------------------------------------------------------------------------------------------

---Highlight search terms in text with color
---@param text string Text to highlight in
---@param searchTerm string Term to highlight
---@param highlightColor? string Color code (default: magenta)
---@return string highlighted Text with highlighted matches
function Search.HighlightSearchTerm(text, searchTerm, highlightColor)
	if not text or not searchTerm or searchTerm == '' then
		return text or ''
	end

	highlightColor = highlightColor or '|cffff00ff' -- Magenta
	local resetColor = '|r'
	local searchLower = searchTerm:lower()
	local result = text
	local pos = 1

	while pos <= #result do
		local textLower = result:lower()
		local startPos, endPos = textLower:find(searchLower, pos, true)
		if not startPos then
			break
		end
		local actualMatch = result:sub(startPos, endPos)
		local highlightedMatch = highlightColor .. actualMatch .. resetColor
		result = result:sub(1, startPos - 1) .. highlightedMatch .. result:sub(endPos + 1)
		pos = startPos + #highlightedMatch
	end

	return result
end

----------------------------------------------------------------------------------------------------
-- Advanced Search (Multi-term)
----------------------------------------------------------------------------------------------------

---Parse search query into multiple terms (space-separated)
---@param query string Search query
---@return string[] terms List of search terms
function Search.ParseSearchQuery(query)
	if not query or query == '' then
		return {}
	end

	local terms = {}
	for term in query:gmatch('%S+') do
		table.insert(terms, term)
	end

	return terms
end

---Check if addon matches ALL search terms (AND logic)
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param terms string[] List of search terms
---@return boolean matches Whether addon matches all terms
function Search.AddonMatchesAllTerms(addon, terms)
	for _, term in ipairs(terms) do
		if not Search.AddonMatchesSearch(addon, term:lower()) then
			return false
		end
	end
	return true
end

---Search addons with multiple terms (AND logic)
---@param addons LibAT.AddonManager.AddonMetadata[] List of addons
---@param query string Search query (space-separated terms)
---@return LibAT.AddonManager.AddonMetadata[] matches Matching addons
function Search.SearchAddonsMultiTerm(addons, query)
	local terms = Search.ParseSearchQuery(query)
	if #terms == 0 then
		return addons
	end

	local results = {}
	for _, addon in ipairs(addons) do
		if Search.AddonMatchesAllTerms(addon, terms) then
			table.insert(results, addon)
		end
	end

	return results
end

----------------------------------------------------------------------------------------------------
-- Search History
----------------------------------------------------------------------------------------------------

Search.History = {}
Search.MaxHistorySize = 20

---Add search term to history
---@param term string Search term
function Search.AddToHistory(term)
	if not term or term == '' then
		return
	end

	-- Remove if already in history
	for i, existing in ipairs(Search.History) do
		if existing == term then
			table.remove(Search.History, i)
			break
		end
	end

	-- Add to front
	table.insert(Search.History, 1, term)

	-- Trim to max size
	while #Search.History > Search.MaxHistorySize do
		table.remove(Search.History)
	end
end

---Get search history
---@return string[] history List of recent search terms
function Search.GetHistory()
	return Search.History
end

---Clear search history
function Search.ClearHistory()
	wipe(Search.History)
end
