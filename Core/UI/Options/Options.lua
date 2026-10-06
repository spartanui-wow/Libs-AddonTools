---@class LibAT
local LibAT = LibAT

-- Shows any addon's AceConfig options in the kit settings window: a sidebar with every page, a
-- search box, and controls drawn by the active window kit, so the settings match the rest of the
-- player's interface (SpartanUI's theme when it is installed).
--
--   local ACD = LibAT.UI.Options:Register('MyAddon', { title = 'My Addon', logo = 'Interface\\...' })
--   ACD:Open('MyAddon')
--
-- Register returns AceConfigDialog-3.0-LibAT. Use it (not the stock AceConfigDialog-3.0) for every
-- Open, Close, SelectGroup and Navigate call on that app, since the two keep separate windows.

---@class LibAT.UI.Options
local Options = LibAT.UI.Options or {}
LibAT.UI.Options = Options

Options.DIALOG = 'AceConfigDialog-3.0-LibAT'
Options.WINDOW = 'LibAT-OptionsWindow'

---@class LibAT.UI.Options.App
---@field title? string Window title; may hold color codes. The options table's name when nil.
---@field logo? string|number Texture shown before the title
---@field version? string|fun(): string Quiet text after the title
---@field pages? boolean Use the sidebar as the page tree (default true)
---@field width? number Default window width
---@field height? number Default window height
---@field widgets? table<string, string> Extra widget swaps, merged over the kit controls
---@field footer? fun(holder: Frame, window: table, close: Button) Adds the addon's own footer buttons to `holder`, once. The window has a Close button at the right end (`close`) and is shared between addons, so these buttons only show for this addon. Wrap actions that open another window in `window:RunAbove(fn)` so it opens in front of the settings.

---@type table<string, LibAT.UI.Options.App>
Options.apps = Options.apps or {}

-- Stock AceGUI types and the kit controls that replace them
Options.WIDGET_MAP = {
	CheckBox = 'LibAT-Switch',
	Slider = 'LibAT-Slider',
	EditBox = 'LibAT-EditBox',
	NumberEditBox = 'LibAT-EditBox',
	MultiLineEditBox = 'LibAT-MultiLineEditBox',
	Keybinding = 'LibAT-Keybinding',
	LSM30_Font = 'LibAT-Media-Font',
	LSM30_Statusbar = 'LibAT-Media-Statusbar',
	LSM30_Background = 'LibAT-Media-Background',
	LSM30_Border = 'LibAT-Media-Border',
	LSM30_Sound = 'LibAT-Media-Sound',
	Button = 'LibAT-Button',
	Heading = 'LibAT-Heading',
	ColorPicker = 'LibAT-ColorPicker',
	Dropdown = 'LibAT-Dropdown',
	Segmented = 'LibAT-Segmented',
	Expander = 'LibAT-Expander',
	InlineGroup = 'LibAT-InlineGroup',
	ScrollFrame = 'LibAT-ScrollFrame',
	TabGroup = 'LibAT-TabGroup',
	TreeGroup = 'LibAT-TreeGroup',
	PageGroup = 'LibAT-PageGroup',
}

---@return table AceConfigDialog-3.0-LibAT
function Options:GetDialog()
	return LibStub(self.DIALOG)
end

---Show an addon's options (already registered with AceConfigRegistry-3.0) in the kit settings window
---@param appName string
---@param config? LibAT.UI.Options.App
---@return table dialog AceConfigDialog-3.0-LibAT
function Options:Register(appName, config)
	config = config or {}
	self.apps[appName] = config
	local dialog = self:GetDialog()
	dialog:SetFrameType(appName, self.WINDOW, config.pages ~= false)
	local map = {}
	for stock, kit in pairs(self.WIDGET_MAP) do
		map[stock] = kit
	end
	for stock, custom in pairs(config.widgets or {}) do
		map[stock] = custom
	end
	dialog:SetWidgetMap(appName, map)
	if config.width and config.height then
		dialog:SetDefaultSize(appName, config.width, config.height)
	end
	return dialog
end

---@param appName? string
---@return LibAT.UI.Options.App|nil
function Options:GetApp(appName)
	return appName and self.apps[appName] or nil
end

---Open an addon's settings window, optionally on a page
---@param appName string
---@param ... string Group path
function Options:Open(appName, ...)
	local dialog = self:GetDialog()
	dialog:Open(appName)
	if select('#', ...) > 0 then
		dialog:SelectGroup(appName, ...)
	end
end
