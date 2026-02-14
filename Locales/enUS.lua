---@class LibAT.Locales
local LibAT = _G.LibAT
if not LibAT then
	return
end

-- Basic localization for LibAT (Phase 1)
-- Phase 5 will implement full localization system

local L = {}

-- Error Display
L['Options'] = 'Options'
L['Auto popup on errors'] = 'Auto popup on errors'
L['Chat frame output'] = 'Chat frame output'
L['Font Size'] = 'Font Size'
L['Reset to Defaults'] = 'Reset to Defaults'
L['Show Minimap Icon'] = 'Show Minimap Icon'
L['Session: %d'] = 'Session: %d'
L['No errors'] = 'No errors'
L['You have no errors, yay!'] = 'You have no errors, yay!'
L['All Errors'] = 'All Errors'
L['Current Session'] = 'Current Session'
L['Previous Session'] = 'Previous Session'
L['< Previous'] = '< Previous'
L['Next >'] = 'Next >'
L['Easy Copy All'] = 'Easy Copy All'
L['Clear all errors'] = 'Clear all errors'
L['BugGrabber is required for LibAT error handling.'] = 'BugGrabber is required for LibAT error handling.'
L['LibAT Error'] = 'LibAT Error'
L['New error captured. Type /libat errors to view.'] = 'New error captured. Type /libat errors to view.'
L['|cffffffffLibAT|r: All stored errors have been wiped.'] = '|cffffffffLibAT|r: All stored errors have been wiped.'

-- General
L['LibAT'] = 'LibAT'
L['Addon Tools'] = 'Addon Tools'

-- Addon Manager
L['Addon Manager'] = 'Addon Manager'
L['Categories'] = 'Categories'
L['All'] = 'All'
L['Load on Demand'] = 'Load on Demand'
L['Protected'] = 'Protected'
L['Enabled'] = 'Enabled'
L['Disabled'] = 'Disabled'
L['Profile'] = 'Profile'
L['Default'] = 'Default'
L['Changes'] = 'Changes'
L['Reload UI'] = 'Reload UI'
L['Apply'] = 'Apply'
L['Cancel'] = 'Cancel'
L['Search'] = 'Search'
L['Sort'] = 'Sort'
L['Name'] = 'Name'
L['Title'] = 'Title'
L['Author'] = 'Author'
L['Version'] = 'Version'
L['Description'] = 'Description'
L['Status'] = 'Status'
L['Loaded'] = 'Loaded'
L['Dependencies'] = 'Dependencies'
L['No addon selected'] = 'No addon selected'
L['No description available'] = 'No description available'
L['Unknown'] = 'Unknown'
L['Warning'] = 'Warning'
L['Create Profile'] = 'Create Profile'
L['Delete Profile'] = 'Delete Profile'
L['Load Profile'] = 'Load Profile'
L['Save Profile'] = 'Save Profile'
L['Enable All'] = 'Enable All'
L['Disable All'] = 'Disable All'
L['Select All'] = 'Select All'
L['Deselect All'] = 'Deselect All'

-- Store in LibAT namespace
LibAT.L = L

return L
