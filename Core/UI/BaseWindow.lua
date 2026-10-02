---@class LibAT
local LibAT = LibAT

-- The classic window helpers, drawn by the active UI kit. Every window built with them shares one
-- look (the kit SpartanUI or another host picks), and these signatures stay as they always were.

----------------------------------------------------------------------------------------------------
-- Window Configuration
----------------------------------------------------------------------------------------------------

---@class WindowConfig
---@field name string Unique name for the window frame
---@field title string Window title text
---@field width number Window width (default 800)
---@field height number Window height (default 538)
---@field portrait? string Unused; kept so older callers still work
---@field hidePortrait? boolean Unused; kept so older callers still work
---@field resizable? boolean Allow the window to be resized (default false)
---@field minWidth? number Minimum resize width (default 200)
---@field minHeight? number Minimum resize height (default 150)
---@field footer? boolean Show the footer bar from the start (action buttons turn it on)
---@field kit? string Keep this window on one kit: a kit id, 'default' (LibAT's own look) or 'auto' (follow the host addon, the default)

-- Where content started in the old template window; offsets given relative to it still line up
local TEMPLATE_TOP = -33
local TEMPLATE_BOTTOM = 12

----------------------------------------------------------------------------------------------------
-- Base Window Creation
----------------------------------------------------------------------------------------------------

---Create a window dressed by the active UI kit
---@param config WindowConfig Window configuration
---@return Frame window The created window frame; place content in window.Body
function LibAT.UI.CreateWindow(config)
	if not config.name or config.name == '' then
		error('CreateWindow: config.name is required')
	end
	if not config.title or config.title == '' then
		error('CreateWindow: config.title is required')
	end
	config.width = config.width or 800
	config.height = config.height or 538

	local window = LibAT.UI.Kit:CreateShell({
		name = config.name,
		title = config.title,
		width = config.width,
		height = config.height,
		footer = config.footer,
		resizable = config.resizable,
		minWidth = config.minWidth,
		minHeight = config.minHeight,
		kit = config.kit,
	})
	window.config = config
	return window
end

---The kit window a frame lives in, if any (a tab's content frame inside a window, for example).
---@param frame Frame
---@return Frame|nil
local function FindShell(frame)
	local current = frame
	for _ = 1, 6 do
		if not current then
			return nil
		end
		if current.kitShell then
			return current
		end
		current = current:GetParent()
	end
	return nil
end

---The footer bar of the kit window a frame lives in, turned on. Nil outside a kit window.
---@param frame Frame The window or a frame inside it
---@return Frame|nil footer
---@return number padding Space to keep from the footer's ends
function LibAT.UI.GetFooter(frame)
	local shell = FindShell(frame)
	if not shell then
		return nil, 0
	end
	if not shell.Footer:IsShown() then
		shell:SetFooterShown(true)
	end
	return shell.Footer, LibAT.UI.Kit:GetKitFor(shell).layout.barPadding
end

---Move a bar a view built along the bottom of its content (status text, reload buttons) into the
---kit window's footer. Outside a kit window it stays where it is and this returns false, so the view
---keeps room for it.
---@param bar Frame
---@param frame Frame The view, or any frame inside the window
---@return boolean placed
function LibAT.UI.PlaceInFooter(bar, frame)
	local footer, padding = LibAT.UI.GetFooter(frame)
	if not footer then
		return false
	end
	bar:ClearAllPoints()
	bar:SetPoint('TOPLEFT', footer, 'TOPLEFT', padding, 0)
	bar:SetPoint('BOTTOMRIGHT', footer, 'BOTTOMRIGHT', -padding, 0)
	return true
end

---Put a button at the left end of the kit window's footer (Reload UI, for example). Outside a kit
---window it goes at the bottom left of the frame.
---@param button Button
---@param frame Frame
function LibAT.UI.PlaceAtFooterLeft(button, frame)
	local footer, padding = LibAT.UI.GetFooter(frame)
	button:ClearAllPoints()
	if footer then
		button:SetPoint('LEFT', footer, 'LEFT', padding, 0)
	else
		button:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', 4, 1)
	end
end

----------------------------------------------------------------------------------------------------
-- Window Layout Helpers
----------------------------------------------------------------------------------------------------

---Create a control frame (search and filters) across the top of the content
---@param window Frame The window, or any frame to place it in
---@param yOffset? number Y offset from the top (default -33, the old title height)
---@param height? number Height (default 28)
---@return Frame controlFrame
function LibAT.UI.CreateControlFrame(window, yOffset, height)
	height = height or 28
	local controlFrame = CreateFrame('Frame', nil, window)
	if window.kitShell then
		local y = (yOffset or TEMPLATE_TOP) - TEMPLATE_TOP
		controlFrame:SetPoint('TOPLEFT', window.Body, 'TOPLEFT', 0, y)
		controlFrame:SetPoint('TOPRIGHT', window.Body, 'TOPRIGHT', 0, y)
	else
		yOffset = yOffset or TEMPLATE_TOP
		controlFrame:SetPoint('TOPLEFT', window, 'TOPLEFT', 2, yOffset)
		controlFrame:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -2, yOffset)
	end
	controlFrame:SetHeight(height)
	return controlFrame
end

---Create the main content area below a control frame
---@param window Frame The window, or any frame to place it in
---@param controlFrame Frame The control frame to anchor below
---@param yOffset? number Gap below the control frame (default -4)
---@param bottomOffset? number Distance from the bottom (default 12)
---@return Frame contentFrame
function LibAT.UI.CreateContentFrame(window, controlFrame, yOffset, bottomOffset)
	yOffset = yOffset or -4
	bottomOffset = bottomOffset or TEMPLATE_BOTTOM
	local contentFrame = CreateFrame('Frame', nil, window)
	contentFrame:SetPoint('TOPLEFT', controlFrame, 'BOTTOMLEFT', 0, yOffset)
	if window.kitShell then
		contentFrame:SetPoint('BOTTOMRIGHT', window.Body, 'BOTTOMRIGHT', 0, bottomOffset - TEMPLATE_BOTTOM)
	else
		contentFrame:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -20, bottomOffset)
	end
	return contentFrame
end

---Create a left panel for navigation
---@param parent Frame The parent frame
---@param width? number Width (default 155)
---@param xOffset? number X offset from the left (default 5)
---@param yOffset? number Y offset from the top (default 5)
---@param bottomOffset? number Distance from the bottom (default 13)
---@return Frame leftPanel
function LibAT.UI.CreateLeftPanel(parent, width, xOffset, yOffset, bottomOffset)
	local leftPanel = CreateFrame('Frame', nil, parent)
	leftPanel:SetPoint('TOPLEFT', parent, 'TOPLEFT', xOffset or 0, yOffset or 0)
	leftPanel:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', xOffset or 0, bottomOffset or 0)
	leftPanel:SetWidth(width or 155)
	return LibAT.UI.Kit:SkinPanel(leftPanel, { elevation = 1, shadow = false })
end

---Create a right panel for content beside a left panel
---@param parent Frame The parent frame
---@param leftPanel Frame The left panel to anchor beside
---@param spacing? number Gap between the panels (default 10)
---@param rightOffset? number Offset from the right (default 0)
---@param yOffset? number Y offset from the top (default 0)
---@param bottomOffset? number Distance from the bottom (default 0)
---@return Frame rightPanel
function LibAT.UI.CreateRightPanel(parent, leftPanel, spacing, rightOffset, yOffset, bottomOffset)
	local rightPanel = CreateFrame('Frame', nil, parent)
	rightPanel:SetPoint('TOPLEFT', leftPanel, 'TOPRIGHT', spacing or 10, yOffset or 0)
	rightPanel:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', rightOffset or 0, bottomOffset or 0)
	return LibAT.UI.Kit:SkinPanel(rightPanel, { elevation = 1, shadow = false })
end

---Create action buttons along the right of the window's footer
---@param window Frame The window, or a frame inside it (the buttons show and hide with it)
---@param buttons table Array of button configs: {text = "Button", width = 70, height = 22, onClick = function}
---@param spacing? number Gap between buttons (default 6)
---@param bottomOffset? number Distance from the bottom when the frame is not in a kit window (default 4)
---@param rightOffset? number Offset from the right when the frame is not in a kit window (default -3)
---@return table buttons
function LibAT.UI.CreateActionButtons(window, buttons, spacing, bottomOffset, rightOffset)
	spacing = spacing or 6
	local footer, padding = LibAT.UI.GetFooter(window)

	local createdButtons = {}
	local previousButton = nil
	for i = #buttons, 1, -1 do -- Reverse order so the rightmost button is placed first
		local buttonConfig = buttons[i]
		local button = LibAT.UI.CreateButton(window, buttonConfig.width or 70, buttonConfig.height or 24, buttonConfig.text or 'Button', buttonConfig.black)
		if previousButton then
			button:SetPoint('RIGHT', previousButton, 'LEFT', -spacing, 0)
		elseif footer then
			button:SetPoint('RIGHT', footer, 'RIGHT', -padding, 0)
		else
			button:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', rightOffset or -3, bottomOffset or 4)
		end
		if buttonConfig.onClick then
			button:SetScript('OnClick', buttonConfig.onClick)
		end
		-- The footer bar is drawn above the window's own children; keep the buttons on top of it
		if footer and button:GetFrameLevel() <= footer:GetFrameLevel() then
			button:SetFrameLevel(footer:GetFrameLevel() + 2)
		end
		table.insert(createdButtons, 1, button)
		previousButton = button
	end
	return createdButtons
end

return LibAT.UI
