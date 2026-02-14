---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Dependencies: Dependency chain analysis and visualization
-- Builds dependency graphs, detects missing dependencies, shows parent-child relationships

local Dependencies = {}
AddonManager.Dependencies = Dependencies

----------------------------------------------------------------------------------------------------
-- Dependency Analysis
----------------------------------------------------------------------------------------------------

---Build dependency graph for an addon
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return table graph Dependency graph with children and parents
function Dependencies.BuildDependencyGraph(addon)
	if not addon then
		return {}
	end

	local graph = {
		addon = addon,
		children = {}, -- Addons that depend on this one
		parents = {}, -- Addons this one depends on
		missing = {}, -- Missing dependencies
	}

	-- Find parent dependencies
	if addon.dependencies then
		for _, depName in ipairs(addon.dependencies) do
			local dep = AddonManager.Core and AddonManager.Core.GetAddonByName(depName)
			if dep then
				table.insert(graph.parents, dep)
			else
				table.insert(graph.missing, depName)
			end
		end
	end

	-- Find child dependencies (addons that depend on this one)
	if AddonManager.Core then
		for i, otherAddon in pairs(AddonManager.Core.AddonCache) do
			if otherAddon.dependencies then
				for _, depName in ipairs(otherAddon.dependencies) do
					if depName == addon.name then
						table.insert(graph.children, otherAddon)
						break
					end
				end
			end
		end
	end

	return graph
end

---Check if addon has unmet dependencies
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return boolean hasUnmet Whether addon has unmet dependencies
---@return string[] missing List of missing dependency names
function Dependencies.HasUnmetDependencies(addon)
	if not addon or not addon.dependencies or #addon.dependencies == 0 then
		return false, {}
	end

	local missing = {}

	for _, depName in ipairs(addon.dependencies) do
		local dep = AddonManager.Core and AddonManager.Core.GetAddonByName(depName)
		if not dep then
			table.insert(missing, depName)
		elseif not dep.enabled then
			table.insert(missing, depName .. ' (disabled)')
		end
	end

	return #missing > 0, missing
end

---Get all dependencies recursively (depth-first)
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param visited? table<string, boolean> Visited addons (for cycle detection)
---@return LibAT.AddonManager.AddonMetadata[] dependencies List of all dependencies
function Dependencies.GetAllDependencies(addon, visited)
	if not addon then
		return {}
	end

	visited = visited or {}
	local deps = {}

	-- Prevent infinite loops
	if visited[addon.name] then
		return deps
	end
	visited[addon.name] = true

	-- Add direct dependencies
	if addon.dependencies then
		for _, depName in ipairs(addon.dependencies) do
			local dep = AddonManager.Core and AddonManager.Core.GetAddonByName(depName)
			if dep and not visited[dep.name] then
				table.insert(deps, dep)

				-- Recursively get dependencies of dependencies
				local subDeps = Dependencies.GetAllDependencies(dep, visited)
				for _, subDep in ipairs(subDeps) do
					if not visited[subDep.name] then
						table.insert(deps, subDep)
						visited[subDep.name] = true
					end
				end
			end
		end
	end

	return deps
end

---Get all dependents (addons that depend on this one) recursively
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param visited? table<string, boolean> Visited addons (for cycle detection)
---@return LibAT.AddonManager.AddonMetadata[] dependents List of all dependents
function Dependencies.GetAllDependents(addon, visited)
	if not addon or not AddonManager.Core then
		return {}
	end

	visited = visited or {}
	local dependents = {}

	-- Prevent infinite loops
	if visited[addon.name] then
		return dependents
	end
	visited[addon.name] = true

	-- Find direct dependents
	for i, otherAddon in pairs(AddonManager.Core.AddonCache) do
		if otherAddon.dependencies and not visited[otherAddon.name] then
			for _, depName in ipairs(otherAddon.dependencies) do
				if depName == addon.name then
					table.insert(dependents, otherAddon)
					visited[otherAddon.name] = true

					-- Recursively get dependents of dependents
					local subDeps = Dependencies.GetAllDependents(otherAddon, visited)
					for _, subDep in ipairs(subDeps) do
						if not visited[subDep.name] then
							table.insert(dependents, subDep)
							visited[subDep.name] = true
						end
					end
					break
				end
			end
		end
	end

	return dependents
end

----------------------------------------------------------------------------------------------------
-- Dependency Tree Visualization
----------------------------------------------------------------------------------------------------

---Generate dependency tree as formatted text
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param showChildren? boolean Show children (addons that depend on this)
---@param showParents? boolean Show parents (dependencies)
---@return string tree Formatted dependency tree
function Dependencies.GenerateDependencyTree(addon, showChildren, showParents)
	if not addon then
		return 'No addon selected'
	end

	local lines = {}

	if showParents == nil then
		showParents = true
	end
	if showChildren == nil then
		showChildren = true
	end

	-- Show addon name
	table.insert(lines, string.format('|cffffd700%s|r', addon.title or addon.name))

	-- Show parent dependencies
	if showParents and addon.dependencies and #addon.dependencies > 0 then
		table.insert(lines, '')
		table.insert(lines, '|cff00ff00Dependencies:|r')
		for i, depName in ipairs(addon.dependencies) do
			local dep = AddonManager.Core and AddonManager.Core.GetAddonByName(depName)
			if dep then
				local status = dep.enabled and '|cff00ff00[Enabled]|r' or '|cffff0000[Disabled]|r'
				table.insert(lines, string.format('  %s %s', dep.title or dep.name, status))
			else
				table.insert(lines, string.format('  %s |cffff0000[Missing]|r', depName))
			end
		end
	end

	-- Show optional dependencies
	if showParents and addon.optionalDeps and #addon.optionalDeps > 0 then
		table.insert(lines, '')
		table.insert(lines, '|cffaaaaaa Optional Dependencies:|r')
		for i, depName in ipairs(addon.optionalDeps) do
			local dep = AddonManager.Core and AddonManager.Core.GetAddonByName(depName)
			if dep then
				local status = dep.enabled and '|cff00ff00[Enabled]|r' or '|cff888888[Disabled]|r'
				table.insert(lines, string.format('  %s %s', dep.title or dep.name, status))
			else
				table.insert(lines, string.format('  %s |cff888888[Not Installed]|r', depName))
			end
		end
	end

	-- Show child dependencies (addons that depend on this)
	if showChildren then
		local graph = Dependencies.BuildDependencyGraph(addon)
		if #graph.children > 0 then
			table.insert(lines, '')
			table.insert(lines, '|cffffff00Required By:|r')
			for _, child in ipairs(graph.children) do
				local status = child.enabled and '|cff00ff00[Enabled]|r' or '|cffff0000[Disabled]|r'
				table.insert(lines, string.format('  %s %s', child.title or child.name, status))
			end
		end
	end

	-- Show X-Part-Of relationship
	if addon.partOf then
		table.insert(lines, '')
		table.insert(lines, string.format('|cffff00ffPart Of:|r %s', addon.partOf))
	end

	return table.concat(lines, '\n')
end

----------------------------------------------------------------------------------------------------
-- Dependency Warnings
----------------------------------------------------------------------------------------------------

---Check if disabling this addon would break other addons
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return boolean wouldBreak Whether disabling would break dependencies
---@return string[] affectedAddons List of addons that would be affected
function Dependencies.WouldBreakDependencies(addon)
	if not addon then
		return false, {}
	end

	local dependents = Dependencies.GetAllDependents(addon)
	local affected = {}

	for _, dependent in ipairs(dependents) do
		if dependent.enabled then
			table.insert(affected, dependent.title or dependent.name)
		end
	end

	return #affected > 0, affected
end

---Generate warning message for dependency issues
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param action string Action being performed ('enable' or 'disable')
---@return string|nil warning Warning message or nil if no issues
function Dependencies.GetDependencyWarning(addon, action)
	if not addon then
		return nil
	end

	if action == 'disable' then
		local wouldBreak, affected = Dependencies.WouldBreakDependencies(addon)
		if wouldBreak then
			return string.format('Disabling this addon will affect:\n%s', table.concat(affected, '\n'))
		end
	elseif action == 'enable' then
		local hasUnmet, missing = Dependencies.HasUnmetDependencies(addon)
		if hasUnmet then
			return string.format('This addon requires:\n%s', table.concat(missing, '\n'))
		end
	end

	return nil
end
