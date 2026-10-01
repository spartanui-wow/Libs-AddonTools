---@class LibAT
local LibAT = LibAT

-- Global radio group storage
---@class RadioGroupData
---@field buttons Frame[] List of radio button containers in the group
---@field value any Currently selected value
---@field callbacks function[] List of callback functions

---@type table<string, RadioGroupData>
local RadioGroups = {}

----------------------------------------------------------------------------------------------------
-- Radio Button Component
----------------------------------------------------------------------------------------------------

---@class LibAT.RadioContainer : Frame
---@field radio CheckButton The actual radio button
---@field Text FontString The label font string
---@field groupName string Radio group name
---@field value any Associated value
---@field SetValue fun(self: LibAT.RadioContainer, value: any) Set the associated value
---@field GetValue fun(self: LibAT.RadioContainer): any Get the associated value
---@field SetChecked fun(self: LibAT.RadioContainer, checked: boolean) Set checked state
---@field GetChecked fun(self: LibAT.RadioContainer): boolean Get checked state
---@field SetText fun(self: LibAT.RadioContainer, text: string) Set label text
---@field GetText fun(self: LibAT.RadioContainer): string Get label text
---@field HookScript fun(self: LibAT.RadioContainer, event: string, handler: function) Hook script on the radio button

---Create a radio button with a container frame for proper positioning
---@param parent Frame Parent frame
---@param text string Button label
---@param groupName string Radio group name
---@param width? number Optional width (default 120)
---@param height? number Optional height (default 20)
---@return LibAT.RadioContainer container Container frame with radio button and label
function LibAT.UI.CreateRadio(parent, text, groupName, width, height)
	width = width or 120
	height = height or 20

	-- Create container frame that holds both radio and label
	---@type LibAT.RadioContainer
	local container = CreateFrame('Frame', nil, parent)
	container:SetSize(width, height)

	-- The radio is a plain CheckButton drawn with the kit: a ring, and a dot while checked
	local Kit = LibAT.UI.Kit
	local radio = CreateFrame('CheckButton', nil, container)
	radio:SetSize(20, 20)
	radio:SetPoint('LEFT', container, 'LEFT', 0, 0)
	container.radio = radio
	radio.ring = radio:CreateTexture(nil, 'ARTWORK')
	radio.ring:SetSize(16, 16)
	radio.ring:SetPoint('CENTER')
	radio.dot = radio:CreateTexture(nil, 'OVERLAY')
	radio.dot:SetSize(8, 8)
	radio.dot:SetPoint('CENTER')
	radio:SetCheckedTexture(radio.dot)
	radio.glow = radio:CreateTexture(nil, 'HIGHLIGHT')
	radio.glow:SetSize(16, 16)
	radio.glow:SetPoint('CENTER')
	radio.glow:SetBlendMode('ADD')

	-- Create label
	local label = container:CreateFontString(nil, 'OVERLAY')
	Kit:SetFont(label, 12)
	label:SetText(text)
	label:SetPoint('LEFT', radio, 'RIGHT', 4, 0)
	label:SetPoint('RIGHT', container, 'RIGHT', 0, 0)
	label:SetJustifyH('LEFT')
	label:SetWordWrap(false)
	container.Text = label

	-- Group helpers check radios directly, so the ring follows every SetChecked
	local NativeSetChecked = radio.SetChecked
	function radio:SetChecked(checked)
		NativeSetChecked(self, checked)
		container:ApplyKit()
	end
	Kit:Track(container, function(owner, config)
		local c = config.colors
		local r, g, b = LibAT.UI.GetAccentColor()
		local checked = owner.radio:GetChecked()
		Kit:SetAsset(owner.radio.ring, config, 'radioRing')
		Kit:SetAsset(owner.radio.dot, config, 'switchKnob')
		Kit:SetAsset(owner.radio.glow, config, 'radioRing')
		if checked then
			owner.radio.ring:SetVertexColor(r, g, b, 1)
		else
			owner.radio.ring:SetVertexColor(c.trimHi[1], c.trimHi[2], c.trimHi[3], 0.85)
		end
		owner.radio.dot:SetVertexColor(r, g, b, 1)
		owner.radio.glow:SetVertexColor(1, 1, 1, 0.25)
		owner.Text:SetTextColor(c.text[1], c.text[2], c.text[3])
	end)

	-- Store group reference and value on container
	container.groupName = groupName
	container.value = nil

	-- Initialize group if needed
	if not RadioGroups[groupName] then
		RadioGroups[groupName] = {
			buttons = {},
			value = nil,
			callbacks = {},
		}
	end

	-- Add container to group (for group value tracking)
	table.insert(RadioGroups[groupName].buttons, container)

	-- Click handler on the radio button
	radio:SetScript('OnClick', function(self)
		-- Uncheck all others in group
		for _, btn in ipairs(RadioGroups[groupName].buttons) do
			btn.radio:SetChecked(btn == container)
		end

		-- Update group value
		RadioGroups[groupName].value = container.value

		-- Fire callbacks
		for _, callback in ipairs(RadioGroups[groupName].callbacks) do
			callback(container.value)
		end
	end)

	-- Extend click detection to the entire container
	container:EnableMouse(true)
	container:SetScript('OnMouseDown', function()
		radio:Click()
	end)

	-- Passthrough methods to the container
	---Set the value associated with this radio button
	---@param value any The value to associate
	function container:SetValue(value)
		self.value = value
	end

	---Get the value associated with this radio button
	---@return any value The associated value
	function container:GetValue()
		return self.value
	end

	---Set checked state
	---@param checked boolean Whether the radio is checked
	function container:SetChecked(checked)
		self.radio:SetChecked(checked)
	end

	---Get checked state
	---@return boolean checked Whether the radio is checked
	function container:GetChecked()
		return self.radio:GetChecked()
	end

	---Programmatically click the radio button
	function container:Click()
		self.radio:Click()
	end

	---Set the label text
	---@param labelText string The text to display
	function container:SetText(labelText)
		self.Text:SetText(labelText)
	end

	---Get the label text
	---@return string text The label text
	function container:GetText()
		return self.Text:GetText()
	end

	---Hook a script on the radio button
	---@param event string Script event name
	---@param handler function Script handler
	function container:HookScript(event, handler)
		-- Wrap handler to pass container as self instead of the inner radio
		self.radio:HookScript(event, function(_, ...)
			handler(container, ...)
		end)
	end

	---Set a script on the radio button
	---@param event string Script event name
	---@param handler function|nil Script handler
	function container:SetScript(event, handler)
		-- For radio-specific events, delegate to the radio button
		if event == 'OnClick' or event == 'OnEnter' or event == 'OnLeave' then
			if handler then
				-- Wrap handler to pass container as self instead of the inner radio
				self.radio:SetScript(event, function(_, ...)
					handler(container, ...)
				end)
			else
				self.radio:SetScript(event, nil)
			end
		else
			-- Call the original Frame SetScript for container events
			getmetatable(self).__index.SetScript(self, event, handler)
		end
	end

	return container
end

---Set the selected value of a radio group
---@param groupName string Radio group name
---@param value any Value to select
function LibAT.UI.SetRadioGroupValue(groupName, value)
	if not RadioGroups[groupName] then
		return
	end

	for _, container in ipairs(RadioGroups[groupName].buttons) do
		if container.value == value then
			container.radio:SetChecked(true)
			RadioGroups[groupName].value = value
		else
			container.radio:SetChecked(false)
		end
	end
end

---Get the selected value of a radio group
---@param groupName string Radio group name
---@return any|nil value Selected value or nil if no selection
function LibAT.UI.GetRadioGroupValue(groupName)
	if not RadioGroups[groupName] then
		return nil
	end
	return RadioGroups[groupName].value
end

---Register a callback for radio group value changes
---@param groupName string Radio group name
---@param callback function Callback function receiving (value)
function LibAT.UI.OnRadioGroupValueChanged(groupName, callback)
	if not RadioGroups[groupName] then
		RadioGroups[groupName] = {
			buttons = {},
			value = nil,
			callbacks = {},
		}
	end

	table.insert(RadioGroups[groupName].callbacks, callback)
end

---Clear all selections in a radio group
---@param groupName string Radio group name
function LibAT.UI.ClearRadioGroup(groupName)
	if not RadioGroups[groupName] then
		return
	end

	for _, container in ipairs(RadioGroups[groupName].buttons) do
		container.radio:SetChecked(false)
	end

	RadioGroups[groupName].value = nil
end

---Get all radio buttons in a group (useful for cleanup)
---@param groupName string Radio group name
---@return Frame[]|nil buttons Array of radio buttons or nil
function LibAT.UI.GetRadioGroupButtons(groupName)
	if not RadioGroups[groupName] then
		return nil
	end
	return RadioGroups[groupName].buttons
end

return LibAT.UI
