---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Visual tokens for the Addon Manager. The window chrome and navigation come from the shared
-- LibAT tools UI; the working surfaces (list, details, footer) are flat near-black panes with 1px
-- hairlines. Gold is the only accent and it is reserved for selection and the primary action.

---@class LibAT.AddonManager.Theme
local T = {}
AddonManager.Theme = T
LibAT.UI.Flat = T

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local ICON_FILE = 'Interface\\AddOns\\LibsAddonTools\\Images\\ui-icons'

T.WHITE = WHITE

T.color = {
	pane = { 0.047, 0.051, 0.059, 0.94 },
	raised = { 0.066, 0.070, 0.082, 0.96 },
	header = { 0.058, 0.062, 0.072, 0.96 },
	hover = { 1, 1, 1, 0.045 },
	pressed = { 1, 1, 1, 0.08 },
	line = { 1, 1, 1, 0.08 },
	lineStrong = { 1, 1, 1, 0.14 },
	input = { 0, 0, 0, 0.35 },
	text = { 0.91, 0.90, 0.88 },
	muted = { 0.61, 0.61, 0.64 },
	faint = { 0.42, 0.42, 0.44 },
	accent = { 1, 0.82, 0 },
	onAccent = { 0.05, 0.05, 0.06 },
	warn = { 1, 0.72, 0.28 },
	good = { 0.30, 0.82, 0.40 },
	bad = { 0.92, 0.30, 0.30 },
	off = { 0.40, 0.40, 0.42 },
}

----------------------------------------------------------------------------------------------------
-- Icons (8 x 2 grid of 32px white glyphs, tinted with vertex color)
----------------------------------------------------------------------------------------------------

local ICONS = {
	close = 0,
	plus = 1,
	gear = 2,
	search = 3,
	pin = 4,
	popout = 5,
	dock = 6,
	more = 7,
	send = 8,
	chevron = 9,
	mute = 10,
	invite = 11,
	bubble = 12,
	info = 13,
	dot = 14,
	check = 15,
}

---@param texture Texture
---@param name string
function T.SetIcon(texture, name)
	local index = ICONS[name] or 0
	local col = index % 8
	local row = math.floor(index / 8)
	texture:SetTexture(ICON_FILE)
	texture:SetTexCoord(col / 8, (col + 1) / 8, row / 2, (row + 1) / 2)
end

----------------------------------------------------------------------------------------------------
-- Surfaces
----------------------------------------------------------------------------------------------------

---@param parent Frame
---@param color table
---@param layer? DrawLayer
---@param sublevel? number
---@return Texture
function T.Fill(parent, color, layer, sublevel)
	local tex = parent:CreateTexture(nil, layer or 'BACKGROUND', nil, sublevel)
	tex:SetTexture(WHITE)
	tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	tex:SetAllPoints(parent)
	return tex
end

---One physical pixel in UI units
---@return number
function T.Pixel()
	local _, height = GetPhysicalScreenSize()
	if not height or height == 0 then
		return 1
	end
	return 768 / height / UIParent:GetEffectiveScale()
end

---@param parent Frame
---@param side 'TOP'|'BOTTOM'|'LEFT'|'RIGHT'
---@param color? table
---@return Texture
function T.Line(parent, side, color)
	color = color or T.color.line
	local tex = parent:CreateTexture(nil, 'BORDER')
	tex:SetTexture(WHITE)
	tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	local px = T.Pixel()
	if side == 'TOP' or side == 'BOTTOM' then
		tex:SetPoint(side .. 'LEFT')
		tex:SetPoint(side .. 'RIGHT')
		tex:SetHeight(px)
	else
		tex:SetPoint('TOP' .. side)
		tex:SetPoint('BOTTOM' .. side)
		tex:SetWidth(px)
	end
	return tex
end

---@param frame Frame
---@param color? table
function T.Border(frame, color)
	frame.borders = {
		T.Line(frame, 'TOP', color),
		T.Line(frame, 'BOTTOM', color),
		T.Line(frame, 'LEFT', color),
		T.Line(frame, 'RIGHT', color),
	}
end

---@param frame Frame
---@param color table
function T.SetBorderColor(frame, color)
	if not frame.borders then
		return
	end
	for _, line in ipairs(frame.borders) do
		line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end
end

----------------------------------------------------------------------------------------------------
-- Type
----------------------------------------------------------------------------------------------------

local BASE_SIZE = 13

-- Body copy uses the chat face so it covers the player's locale; labels use the UI face
local ROLE = {
	body = { face = 'chat', offset = 0 },
	name = { face = 'ui', offset = -1 },
	title = { face = 'ui', offset = 0 },
	meta = { face = 'chat', offset = -2 },
	small = { face = 'ui', offset = -3 },
}

local function Face(kind)
	local fontObject = kind == 'chat' and ChatFontNormal or GameFontNormal
	local face = fontObject and fontObject:GetFont()
	return face or STANDARD_TEXT_FONT
end

---@param fs FontString
---@param role string
local function ApplyFont(fs, role)
	local spec = ROLE[role] or ROLE.body
	local size = math.max(8, BASE_SIZE + spec.offset + (fs.sizeBump or 0))
	fs:SetFont(Face(spec.face), size, '')
	fs:SetShadowColor(0, 0, 0, 0.85)
	fs:SetShadowOffset(1, -1)
end

---@param parent Frame
---@param role 'body'|'name'|'title'|'meta'|'small'
---@param color? table
---@param layer? DrawLayer
---@return FontString
function T.Text(parent, role, color, layer)
	local fs = parent:CreateFontString(nil, layer or 'OVERLAY')
	fs.role = role
	ApplyFont(fs, role)
	color = color or T.color.text
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
	fs:SetJustifyH('LEFT')
	fs:SetWordWrap(false)
	return fs
end

---@param fs FontString
---@param bump number
function T.Bump(fs, bump)
	fs.sizeBump = bump
	ApplyFont(fs, fs.role or 'body')
end

---@param fs FontString
---@param color table
function T.SetColor(fs, color)
	fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

---@param color table
---@param text string
---@return string
function T.Wrap(color, text)
	return string.format('|cff%02x%02x%02x%s|r', math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5), text)
end

---Memory in KB to a short label
---@param kb number
---@return string
function T.FormatMemory(kb)
	if not kb or kb <= 0 then
		return ''
	end
	if kb >= 1024 then
		return string.format('%.1f MB', kb / 1024)
	end
	return string.format('%.0f KB', kb)
end

----------------------------------------------------------------------------------------------------
-- Tooltip
----------------------------------------------------------------------------------------------------

---@param owner Frame
---@param text string
---@param hint? string
function T.ShowTip(owner, text, hint)
	GameTooltip:SetOwner(owner, 'ANCHOR_TOP')
	GameTooltip:SetText(text, 1, 1, 1)
	if hint then
		GameTooltip:AddLine(hint, T.color.muted[1], T.color.muted[2], T.color.muted[3], true)
	end
	GameTooltip:Show()
end

----------------------------------------------------------------------------------------------------
-- Widgets
----------------------------------------------------------------------------------------------------

---Flat square icon button: glyph at 80% size, muted until hovered
---@param parent Frame
---@param icon string
---@param size number
---@param tooltip? string
---@param onClick? fun(self: Button, mouseButton: string)
---@return Button
function T.IconButton(parent, icon, size, tooltip, onClick)
	local btn = CreateFrame('Button', nil, parent)
	btn:SetSize(size, size)
	btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

	btn.bg = T.Fill(btn, T.color.hover)
	btn.bg:Hide()

	btn.icon = btn:CreateTexture(nil, 'ARTWORK')
	btn.icon:SetPoint('CENTER')
	local glyph = math.floor(size * 0.8 + 0.5)
	btn.icon:SetSize(glyph, glyph)
	T.SetIcon(btn.icon, icon)

	btn.tint = T.color.muted
	btn.icon:SetVertexColor(btn.tint[1], btn.tint[2], btn.tint[3])

	function btn:SetTint(color)
		self.tint = color
		if not self:IsMouseOver() then
			self.icon:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
		end
	end

	btn:SetScript('OnEnter', function(self)
		self.bg:Show()
		self.icon:SetVertexColor(1, 1, 1)
		if self.tooltip then
			T.ShowTip(self, self.tooltip, self.hint)
		end
	end)
	btn:SetScript('OnLeave', function(self)
		self.bg:Hide()
		self.icon:SetVertexColor(self.tint[1], self.tint[2], self.tint[3], self.tint[4] or 1)
		GameTooltip:Hide()
	end)
	btn:SetScript('OnMouseDown', function(self)
		self.icon:SetPoint('CENTER', 0, -1)
	end)
	btn:SetScript('OnMouseUp', function(self)
		self.icon:SetPoint('CENTER', 0, 0)
	end)
	btn:SetScript('OnClick', onClick)
	btn.tooltip = tooltip
	return btn
end

---Flat text button. Primary buttons fill with the accent and use a dark label.
---@param parent Frame
---@param text string
---@param onClick? function
---@param primary? boolean
---@return Button
function T.TextButton(parent, text, onClick, primary)
	local btn = CreateFrame('Button', nil, parent)
	btn.label = T.Text(btn, 'name', primary and T.color.onAccent or T.color.text)
	btn.label:SetPoint('CENTER')
	btn.label:SetText(text)
	btn:SetSize(math.max(72, btn.label:GetStringWidth() + 24), 24)

	if primary then
		local a = T.color.accent
		btn.bg = T.Fill(btn, { a[1], a[2], a[3], 0.9 })
		btn.label:SetShadowOffset(0, 0)
	else
		btn.bg = T.Fill(btn, { 1, 1, 1, 0.07 })
		T.Border(btn, { 1, 1, 1, 0.12 })
	end
	btn.hl = T.Fill(btn, { 1, 1, 1, primary and 0.18 or 0.08 }, 'ARTWORK')
	btn.hl:Hide()

	function btn:SetLabel(value)
		self.label:SetText(value)
		self:SetWidth(math.max(72, self.label:GetStringWidth() + 24))
	end

	btn:SetScript('OnEnter', function(self)
		self.hl:Show()
		if self.tooltip then
			T.ShowTip(self, self.tooltip, self.hint)
		end
	end)
	btn:SetScript('OnLeave', function(self)
		self.hl:Hide()
		GameTooltip:Hide()
	end)
	btn:SetScript('OnMouseDown', function(self)
		self.label:SetPoint('CENTER', 0, -1)
	end)
	btn:SetScript('OnMouseUp', function(self)
		self.label:SetPoint('CENTER', 0, 0)
	end)
	btn:SetScript('OnDisable', function(self)
		self.label:SetAlpha(0.4)
		self.bg:SetAlpha(0.5)
	end)
	btn:SetScript('OnEnable', function(self)
		self.label:SetAlpha(1)
		self.bg:SetAlpha(1)
	end)
	btn:SetScript('OnClick', onClick)
	return btn
end

---Flat dropdown trigger: label on the left, chevron on the right
---@param parent Frame
---@param width number
---@param onClick fun(self: Button)
---@return Button
function T.Select(parent, width, onClick)
	local btn = CreateFrame('Button', nil, parent)
	btn:SetSize(width, 24)
	btn.bg = T.Fill(btn, T.color.input)
	T.Border(btn, { 1, 1, 1, 0.12 })
	btn.hl = T.Fill(btn, T.color.hover, 'ARTWORK')
	btn.hl:Hide()

	btn.caption = T.Text(btn, 'small', T.color.faint)
	btn.caption:SetPoint('LEFT', 8, 0)

	btn.label = T.Text(btn, 'name', T.color.text)
	btn.label:SetPoint('LEFT', btn.caption, 'RIGHT', 6, 0)
	btn.label:SetPoint('RIGHT', -22, 0)

	btn.chevron = btn:CreateTexture(nil, 'ARTWORK')
	btn.chevron:SetSize(14, 14)
	btn.chevron:SetPoint('RIGHT', -5, 0)
	T.SetIcon(btn.chevron, 'chevron')
	btn.chevron:SetVertexColor(T.color.muted[1], T.color.muted[2], T.color.muted[3])

	function btn:SetCaption(text)
		self.caption:SetText(text or '')
		self.label:ClearAllPoints()
		if text and text ~= '' then
			self.label:SetPoint('LEFT', self.caption, 'RIGHT', 6, 0)
		else
			self.label:SetPoint('LEFT', 8, 0)
		end
		self.label:SetPoint('RIGHT', -22, 0)
	end

	function btn:SetValue(text)
		self.label:SetText(text or '')
	end

	btn:SetScript('OnEnter', function(self)
		self.hl:Show()
		T.SetBorderColor(self, { 1, 1, 1, 0.24 })
		if self.tooltip then
			T.ShowTip(self, self.tooltip, self.hint)
		end
	end)
	btn:SetScript('OnLeave', function(self)
		self.hl:Hide()
		T.SetBorderColor(self, { 1, 1, 1, 0.12 })
		GameTooltip:Hide()
	end)
	btn:SetScript('OnClick', onClick)
	return btn
end

---Flat search field with a leading glyph, placeholder, clear button and focus rule
---@param parent Frame
---@param placeholder string
---@param onChange fun(text: string)
---@return EditBox
function T.SearchBox(parent, placeholder, onChange)
	local box = CreateFrame('EditBox', nil, parent)
	box:SetHeight(24)
	box:SetAutoFocus(false)
	box:SetFontObject(ChatFontNormal)
	box:SetTextInsets(26, 22, 0, 0)
	box:SetMaxLetters(64)
	T.Fill(box, T.color.input)
	T.Border(box, { 1, 1, 1, 0.12 })

	box.icon = box:CreateTexture(nil, 'ARTWORK')
	box.icon:SetSize(16, 16)
	box.icon:SetPoint('LEFT', 6, 0)
	T.SetIcon(box.icon, 'search')
	box.icon:SetVertexColor(T.color.faint[1], T.color.faint[2], T.color.faint[3])

	box.placeholder = T.Text(box, 'meta', T.color.faint)
	box.placeholder:SetPoint('LEFT', 26, 0)
	box.placeholder:SetText(placeholder)

	box.focusLine = T.Line(box, 'BOTTOM', { T.color.accent[1], T.color.accent[2], T.color.accent[3], 0.6 })
	box.focusLine:Hide()

	box.clear = T.IconButton(box, 'close', 18, nil, function()
		box:SetText('')
		box:ClearFocus()
	end)
	box.clear:SetPoint('RIGHT', -3, 0)
	box.clear:Hide()

	local pending
	box:SetScript('OnTextChanged', function(self)
		local text = self:GetText() or ''
		self.placeholder:SetShown(text == '')
		self.clear:SetShown(text ~= '')
		if pending then
			pending:Cancel()
		end
		pending = C_Timer.NewTimer(0.15, function()
			pending = nil
			onChange(self:GetText() or '')
		end)
	end)
	box:SetScript('OnEditFocusGained', function(self)
		self.focusLine:Show()
		self.icon:SetVertexColor(T.color.muted[1], T.color.muted[2], T.color.muted[3])
	end)
	box:SetScript('OnEditFocusLost', function(self)
		self.focusLine:Hide()
		self.icon:SetVertexColor(T.color.faint[1], T.color.faint[2], T.color.faint[3])
	end)
	box:SetScript('OnEscapePressed', function(self)
		if (self:GetText() or '') ~= '' then
			self:SetText('')
		end
		self:ClearFocus()
	end)
	box:SetScript('OnEnterPressed', function(self)
		self:ClearFocus()
	end)
	box:SetScript('OnShow', function(self)
		local face, _, flags = ChatFontNormal:GetFont()
		if face then
			self:SetFont(face, BASE_SIZE - 1, flags or '')
		end
		self:SetTextColor(T.color.text[1], T.color.text[2], T.color.text[3])
	end)
	return box
end

---Flat checkbox with three states: false, 'some' (enabled for some characters) and true
---@param parent Frame
---@param size? number
---@return Button
function T.Check(parent, size)
	size = size or 14
	local box = CreateFrame('Button', nil, parent)
	box:SetSize(size + 8, size + 8)

	box.frame = CreateFrame('Frame', nil, box)
	box.frame:SetSize(size, size)
	box.frame:SetPoint('CENTER')
	box.fill = T.Fill(box.frame, T.color.input)
	T.Border(box.frame, { 1, 1, 1, 0.22 })

	box.glyph = box.frame:CreateTexture(nil, 'OVERLAY')
	box.glyph:SetSize(size + 2, size + 2)
	box.glyph:SetPoint('CENTER')
	T.SetIcon(box.glyph, 'check')
	box.glyph:Hide()

	---@param state boolean|'some'
	---@param locked? boolean
	function box:SetState(state, locked)
		self.state = state
		self.locked = locked
		local a = T.color.accent
		if state == true then
			self.fill:SetVertexColor(a[1], a[2], a[3], locked and 0.45 or 0.9)
			self.glyph:SetVertexColor(T.color.onAccent[1], T.color.onAccent[2], T.color.onAccent[3])
			self.glyph:Show()
			T.SetBorderColor(self.frame, { a[1], a[2], a[3], locked and 0.45 or 0.9 })
		elseif state == 'some' then
			self.fill:SetVertexColor(a[1], a[2], a[3], 0.18)
			self.glyph:SetVertexColor(a[1], a[2], a[3], 0.9)
			self.glyph:Show()
			T.SetBorderColor(self.frame, { a[1], a[2], a[3], 0.55 })
		else
			local c = T.color.input
			self.fill:SetVertexColor(c[1], c[2], c[3], c[4])
			self.glyph:Hide()
			T.SetBorderColor(self.frame, { 1, 1, 1, 0.22 })
		end
	end

	box:SetScript('OnEnter', function(self)
		if self.state ~= true then
			T.SetBorderColor(self.frame, { 1, 1, 1, 0.5 })
		end
		if self.tooltip then
			T.ShowTip(self, self.tooltip, self.hint)
		end
		if self.onEnter then
			self.onEnter(self)
		end
	end)
	box:SetScript('OnLeave', function(self)
		self:SetState(self.state, self.locked)
		GameTooltip:Hide()
		if self.onLeave then
			self.onLeave(self)
		end
	end)

	box:SetState(false)
	return box
end

----------------------------------------------------------------------------------------------------
-- Menu (flat dropdown list, closes on outside click or Escape)
----------------------------------------------------------------------------------------------------

local menu

local function CloseMenu()
	if menu then
		menu:Hide()
	end
end
T.CloseMenu = CloseMenu

local function BuildMenu()
	menu = CreateFrame('Frame', 'LibAT_AddonManagerMenu', UIParent)
	menu:SetFrameStrata('FULLSCREEN_DIALOG')
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	T.Fill(menu, { 0.07, 0.075, 0.09, 0.98 })
	T.Border(menu, { 1, 1, 1, 0.14 })
	menu.rows = {}
	menu:Hide()
	menu:SetScript('OnEvent', function(self)
		if not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
			self:Hide()
		end
	end)
	menu:SetScript('OnShow', function(self)
		pcall(self.RegisterEvent, self, 'GLOBAL_MOUSE_DOWN')
	end)
	menu:SetScript('OnHide', function(self)
		pcall(self.UnregisterEvent, self, 'GLOBAL_MOUSE_DOWN')
	end)
	tinsert(UISpecialFrames, 'LibAT_AddonManagerMenu')
end

local function MenuRow(index)
	local row = menu.rows[index]
	if row then
		return row
	end
	row = CreateFrame('Button', nil, menu)
	row:SetHeight(22)
	row.hl = T.Fill(row, T.color.hover)
	row.hl:Hide()
	row.check = row:CreateTexture(nil, 'ARTWORK')
	row.check:SetSize(14, 14)
	row.check:SetPoint('LEFT', 8, 0)
	T.SetIcon(row.check, 'check')
	row.text = T.Text(row, 'body')
	row.text:SetPoint('LEFT', 26, 0)
	row.divider = T.Line(row, 'TOP')
	row:SetScript('OnEnter', function(self)
		if self:IsEnabled() then
			self.hl:Show()
		end
	end)
	row:SetScript('OnLeave', function(self)
		self.hl:Hide()
	end)
	row:SetScript('OnClick', function(self)
		CloseMenu()
		if self.item and self.item.onClick then
			self.item.onClick()
		end
	end)
	menu.rows[index] = row
	return row
end

---@class LibAT.AddonManager.MenuItem
---@field text string
---@field onClick? function
---@field checked? boolean
---@field disabled? boolean
---@field danger? boolean
---@field title? boolean Non-clickable section label
---@field divider? boolean Draw a separator above this item

---Opens a menu under an anchor. Clicking elsewhere or pressing Escape closes it.
---@param anchor Frame
---@param items LibAT.AddonManager.MenuItem[]
---@param alignLeft? boolean
function T.OpenMenu(anchor, items, alignLeft)
	if not menu then
		BuildMenu()
	end
	if menu:IsShown() and menu.owner == anchor then
		CloseMenu()
		return
	end
	local width = math.max(160, anchor:GetWidth())
	local y = -4
	for i, item in ipairs(items) do
		local row = MenuRow(i)
		row.item = item
		row.text:SetText(item.text)
		local color = T.color.text
		if item.title then
			color = T.color.faint
		elseif item.disabled then
			color = T.color.faint
		elseif item.danger then
			color = { 1, 0.45, 0.4 }
		end
		T.SetColor(row.text, color)
		row.text:ClearAllPoints()
		row.text:SetPoint('LEFT', item.title and 10 or 26, 0)
		row.check:SetShown(item.checked == true)
		row.check:SetVertexColor(T.color.accent[1], T.color.accent[2], T.color.accent[3])
		row.divider:SetShown(item.divider == true)
		row:SetEnabled(not item.disabled and not item.title)
		if item.divider then
			y = y - 4
		end
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', 0, y)
		row:SetPoint('TOPRIGHT', 0, y)
		row:Show()
		y = y - 22
		width = math.max(width, row.text:GetStringWidth() + 44)
	end
	for i = #items + 1, #menu.rows do
		menu.rows[i]:Hide()
	end
	menu:SetSize(width, -y + 4)
	menu.owner = anchor
	menu:ClearAllPoints()
	if alignLeft then
		menu:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -2)
	else
		menu:SetPoint('TOPRIGHT', anchor, 'BOTTOMRIGHT', 0, -2)
	end
	menu:Show()
end

----------------------------------------------------------------------------------------------------
-- Dialogs (confirm and text prompt)
----------------------------------------------------------------------------------------------------

StaticPopupDialogs['LIBAT_ADDONMANAGER_CONFIRM'] = {
	text = '%s',
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data)
		if data and data.onAccept then
			data.onAccept()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs['LIBAT_ADDONMANAGER_PROMPT'] = {
	text = '%s',
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = true,
	maxLetters = 48,
	OnShow = function(self, data)
		local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
		editBox:SetText(data and data.initial or '')
		editBox:HighlightText()
		editBox:SetFocus()
	end,
	OnAccept = function(self, data)
		local editBox = self.GetEditBox and self:GetEditBox() or self.editBox
		local text = strtrim(editBox:GetText() or '')
		if text ~= '' and data and data.onAccept then
			data.onAccept(text)
		end
	end,
	EditBoxOnEnterPressed = function(editBox, data)
		local text = strtrim(editBox:GetText() or '')
		if text ~= '' and data and data.onAccept then
			data.onAccept(text)
		end
		editBox:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

---@param text string
---@param onAccept function
---@param acceptLabel? string
function T.Confirm(text, onAccept, acceptLabel)
	StaticPopupDialogs['LIBAT_ADDONMANAGER_CONFIRM'].button1 = acceptLabel or YES
	StaticPopup_Show('LIBAT_ADDONMANAGER_CONFIRM', text, nil, { onAccept = onAccept })
end

---@param text string
---@param initial? string
---@param onAccept fun(text: string)
function T.Prompt(text, initial, onAccept)
	StaticPopup_Show('LIBAT_ADDONMANAGER_PROMPT', text, nil, { initial = initial, onAccept = onAccept })
end
