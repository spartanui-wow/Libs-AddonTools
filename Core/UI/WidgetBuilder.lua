---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Widget Builder - Ace3-Style Declarative Widget Creation
----------------------------------------------------------------------------------------------------

-- Default widget dimensions
local WIDGET_WIDTH = 200
local BUTTON_HEIGHT = 25
local SLIDER_HEIGHT = 40
local CHECKBOX_HEIGHT = 22
local DROPDOWN_HEIGHT = 25
local HEADER_HEIGHT = 20
local DESCRIPTION_HEIGHT = 30
local SPACING = 5

---@class LibAT.WidgetDef
---@field type string Widget type: 'button', 'slider', 'checkbox', 'dropdown', 'header', 'description', 'divider'
---@field order? number Display order (lower = higher in container)
---@field name? string Display label
---@field desc? string Tooltip description
---@field get? fun(): any Getter for current value
---@field set? fun(info: table, value: any) Setter for new value (Ace3-style with info table)
---@field min? number Slider minimum
---@field max? number Slider maximum
---@field step? number Slider step
---@field isPercent? boolean Show slider value as percentage
---@field values? table Dropdown values {key = "display"}
---@field func? fun() Button click function
---@field disabled? fun(): boolean Returns true if widget should be disabled
---@field hidden? fun(): boolean Returns true if widget should be hidden
---@field width? number Custom width

---Build widgets from Ace3-style definitions.
---Setters are called as set(info, value), like AceConfig: write `set = function(_, value)`.
---@param container Frame Parent container frame
---@param definitions table Widget definitions (key = id, value = widget def)
---@param width? number Container width (default 200)
---@return table widgets Created widget frames keyed by id
---@return number totalHeight Total height of all widgets
function LibAT.UI.BuildWidgets(container, definitions, width)
	width = width or WIDGET_WIDTH
	local widgets = {}
	local yOffset = 0

	-- Convert to array and sort by order
	local sorted = {}
	for id, def in pairs(definitions) do
		def._id = id
		table.insert(sorted, def)
	end
	table.sort(sorted, function(a, b)
		return (a.order or 100) < (b.order or 100)
	end)

	-- Create each widget
	for _, def in ipairs(sorted) do
		-- Check if hidden
		if not def.hidden or not def.hidden() then
			local widget, widgetHeight = LibAT.UI.CreateWidgetFromDef(container, def, width)
			if widget then
				widget:SetPoint('TOPLEFT', container, 'TOPLEFT', 0, yOffset)
				yOffset = yOffset - (widgetHeight + SPACING)
				widgets[def._id] = widget
			end
		end
	end

	return widgets, math.abs(yOffset)
end

---Create a single widget from an Ace3-style definition
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width? number Widget width
---@return Frame|nil widget The created widget
---@return number height Widget height
function LibAT.UI.CreateWidgetFromDef(container, def, width)
	width = width or WIDGET_WIDTH

	if def.type == 'button' then
		return LibAT.UI.CreateButtonWidget(container, def, width)
	elseif def.type == 'slider' then
		return LibAT.UI.CreateSliderWidget(container, def, width)
	elseif def.type == 'checkbox' then
		return LibAT.UI.CreateCheckboxWidget(container, def, width)
	elseif def.type == 'dropdown' then
		return LibAT.UI.CreateDropdownWidget(container, def, width)
	elseif def.type == 'header' then
		return LibAT.UI.CreateHeaderWidget(container, def, width)
	elseif def.type == 'description' then
		return LibAT.UI.CreateDescriptionWidget(container, def, width)
	elseif def.type == 'divider' then
		return LibAT.UI.CreateDividerWidget(container, def, width)
	end

	return nil, 0
end

---Create a button widget
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateButtonWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, BUTTON_HEIGHT)

	local btn = LibAT.UI.CreateButton(frame, def.width or width, BUTTON_HEIGHT, def.name or 'Button')
	btn:SetPoint('LEFT', frame, 'LEFT', 0, 0)

	btn:SetScript('OnClick', function()
		if def.disabled and def.disabled() then
			return
		end
		if def.func then
			def.func()
		end
	end)

	-- Add tooltip
	if def.desc then
		btn:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(def.name or '', 1, 1, 1)
			GameTooltip:AddLine(def.desc, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		btn:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	-- Handle disabled state
	if def.disabled and def.disabled() then
		btn:Disable()
	end

	frame.button = btn
	frame.def = def

	---Refresh the widget state
	function frame:Refresh()
		if self.def.disabled then
			if self.def.disabled() then
				self.button:Disable()
			else
				self.button:Enable()
			end
		end
	end

	return frame, BUTTON_HEIGHT
end

---Create a slider widget with label and value display
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateSliderWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, SLIDER_HEIGHT)

	-- Label
	local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
	label:SetText(def.name or 'Slider')
	label:SetTextColor(1, 0.82, 0) -- Gold

	-- Value display
	local valueText = frame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	valueText:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', 0, 0)

	-- Slider
	local slider = LibAT.UI.CreateSlider(frame, width - 10, 16, def.min or 0, def.max or 1, def.step or 1)
	slider:SetPoint('TOPLEFT', frame, 'TOPLEFT', 5, -18)

	-- Update value display
	local function updateValueText(value)
		if def.isPercent then
			valueText:SetText(string.format('%d%%', value * 100))
		else
			if def.step and def.step < 1 then
				valueText:SetText(string.format('%.1f', value))
			else
				valueText:SetText(tostring(math.floor(value)))
			end
		end
	end

	-- Set initial value
	if def.get then
		local value = def.get()
		if value then
			slider:SetValue(value)
			updateValueText(value)
		end
	end

	-- Handle value changed
	slider:SetScript('OnValueChanged', function(self, value)
		updateValueText(value)
		if def.set then
			def.set({}, value)
		end
	end)

	-- Add tooltip
	if def.desc then
		slider:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(def.name or '', 1, 1, 1)
			GameTooltip:AddLine(def.desc, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		slider:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	frame.slider = slider
	frame.label = label
	frame.valueText = valueText
	frame.def = def

	---Refresh the widget state
	function frame:Refresh()
		if self.def.get then
			local value = self.def.get()
			if value then
				self.slider:SetValue(value)
			end
		end
	end

	return frame, SLIDER_HEIGHT
end

---Create a checkbox widget
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateCheckboxWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, CHECKBOX_HEIGHT)

	local checkbox = LibAT.UI.CreateCheckbox(frame, def.name)
	checkbox:SetPoint('LEFT', frame, 'LEFT', 0, 0)

	-- Set initial value
	if def.get then
		local value = def.get()
		checkbox:SetChecked(value == true)
	end

	-- Handle click
	checkbox:SetScript('OnClick', function(self)
		if def.disabled and def.disabled() then
			self:SetChecked(not self:GetChecked()) -- Revert
			return
		end
		if def.set then
			def.set({}, self:GetChecked())
		end
	end)

	-- Add tooltip
	if def.desc then
		checkbox:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(def.name or '', 1, 1, 1)
			GameTooltip:AddLine(def.desc, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		checkbox:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	frame.checkbox = checkbox
	frame.def = def

	---Refresh the widget state
	function frame:Refresh()
		if self.def.get then
			local value = self.def.get()
			self.checkbox:SetChecked(value == true)
		end
	end

	return frame, CHECKBOX_HEIGHT
end

---Create a dropdown widget
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateDropdownWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, DROPDOWN_HEIGHT + 18) -- Extra height for label

	-- Label
	local label = frame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	label:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
	label:SetText(def.name or 'Dropdown')
	label:SetTextColor(1, 0.82, 0) -- Gold

	-- Dropdown button
	local dropdown = LibAT.UI.CreateDropdown(frame, '', def.width or width, DROPDOWN_HEIGHT)
	dropdown:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -16)

	-- Update text based on current value
	local function updateDropdownText()
		if def.get and def.values then
			local currentValue = def.get()
			local displayText = def.values[currentValue] or tostring(currentValue)
			dropdown:SetText(displayText)
		end
	end

	updateDropdownText()

	-- Setup menu generator
	if dropdown.SetupMenu then
		dropdown:SetupMenu(function(owner, rootDescription)
			if not def.values then
				return
			end

			for value, displayText in pairs(def.values) do
				rootDescription:CreateButton(displayText, function()
					if def.set then
						def.set({}, value)
					end
					updateDropdownText()
				end)
			end
		end)
	end

	-- Add tooltip
	if def.desc then
		dropdown:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(def.name or '', 1, 1, 1)
			GameTooltip:AddLine(def.desc, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		dropdown:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	frame.dropdown = dropdown
	frame.label = label
	frame.def = def

	---Refresh the widget state
	function frame:Refresh()
		if self.def.get and self.def.values then
			local currentValue = self.def.get()
			local displayText = self.def.values[currentValue] or tostring(currentValue)
			self.dropdown:SetText(displayText)
		end
	end

	return frame, DROPDOWN_HEIGHT + 18
end

---Create a header widget
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateHeaderWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, HEADER_HEIGHT)

	local header = LibAT.UI.CreateHeader(frame, def.name or 'Header')
	header:SetPoint('LEFT', frame, 'LEFT', 0, 0)

	frame.header = header
	frame.def = def

	return frame, HEADER_HEIGHT
end

---Create a description widget
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateDescriptionWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)

	local text = frame:CreateFontString(nil, 'OVERLAY', def.fontSize == 'medium' and 'GameFontHighlight' or 'GameFontHighlightSmall')
	text:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
	text:SetWidth(width)
	text:SetJustifyH('LEFT')
	text:SetText(def.name or '')

	-- Calculate height based on text
	local height = text:GetStringHeight() or DESCRIPTION_HEIGHT
	frame:SetSize(width, height)

	frame.text = text
	frame.def = def

	return frame, height
end

---Create a divider widget (horizontal line)
---@param container Frame Parent container
---@param def LibAT.WidgetDef Widget definition
---@param width number Widget width
---@return Frame widget
---@return number height
function LibAT.UI.CreateDividerWidget(container, def, width)
	local frame = CreateFrame('Frame', nil, container)
	frame:SetSize(width, 10)

	local line = frame:CreateTexture(nil, 'ARTWORK')
	line:SetHeight(1)
	line:SetPoint('LEFT', frame, 'LEFT', 10, 0)
	line:SetPoint('RIGHT', frame, 'RIGHT', -10, 0)
	line:SetColorTexture(0.5, 0.5, 0.5, 0.5)

	frame.line = line
	frame.def = def

	return frame, 10
end

---Refresh all widgets in a container
---@param widgets table Widget table from BuildWidgets
function LibAT.UI.RefreshWidgets(widgets)
	for _, widget in pairs(widgets) do
		if widget.Refresh then
			widget:Refresh()
		end
	end
end

---Update a single widget's value
---@param widget Frame Widget frame from BuildWidgets
---@param value any New value to set
function LibAT.UI.SetWidgetValue(widget, value)
	if not widget then
		return
	end

	if widget.slider then
		widget.slider:SetValue(value)
	elseif widget.checkbox then
		widget.checkbox:SetChecked(value == true)
	elseif widget.dropdown then
		if widget.def and widget.def.values then
			local displayText = widget.def.values[value] or tostring(value)
			widget.dropdown:SetText(displayText)
		end
	end
end

return LibAT.UI
