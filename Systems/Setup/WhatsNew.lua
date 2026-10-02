---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- What's new: its own small window, so an update never looks like setup asking for something.
-- Opens by itself after an update only when a newer release has a hero; the setup window's
-- What's new link opens it too.
----------------------------------------------------------------------------------------------------

local Setup = LibAT.Setup
local Kit = LibAT.UI.Kit

---@class LibAT.SetupWhatsNewWindow
local WhatsNew = {}
Setup.WhatsNew = WhatsNew

WhatsNew.open = {} -- older versions the player unfolded, by addon id @ version

local FALLBACK_COLORS = { text = { 1, 1, 1 }, secondary = { 0.8, 0.8, 0.8 }, muted = { 0.6, 0.6, 0.6 } }

---A hero picture: one 2:1 card, or a list of them (the first large, the rest stacked beside it).
---Each is cropped to its lower part, where the frames and bars are, so the band stays short.
---@param art LibAT.CardArt|LibAT.CardArt[]
---@return table[]
local function HeroPictures(art)
	if type(art) == 'table' and art[1] ~= nil then
		return art
	end
	return { art }
end

---@param texture Texture
---@param art LibAT.CardArt
---@param width number
---@param height number
local function ShowCropped(texture, art, width, height)
	texture:SetTexture(type(art) == 'table' and art.texture or art)
	-- A 2:1 picture shown at this size keeps its full width and its lowest part
	local visible = math.min(1, (2 * height) / math.max(width, 1))
	texture:SetTexCoord(0, 1, 1 - visible, 1)
	texture:SetSize(width, height)
	texture:Show()
end

---Draw every addon's What's new into a frame. Pools its regions on the frame.
---@param frame Frame
---@param width number
---@param onChanged fun() redraw after the player unfolds an older version
---@return number height
function WhatsNew:Draw(frame, width, onChanged)
	local config = Kit:GetKitFor(frame) or Kit:GetActive()
	local colors = (config and config.colors) or FALLBACK_COLORS
	local accent = { LibAT.UI.GetAccentColor() }
	frame.texts = frame.texts or {}
	frame.links = frame.links or {}
	frame.arts = frame.arts or {}
	frame.buttons = frame.buttons or {}
	local used = { texts = 0, links = 0, arts = 0, buttons = 0 }
	local y = 0

	local function Text(value, size, color, indent, textWidth)
		used.texts = used.texts + 1
		local fs = frame.texts[used.texts]
		if not fs then
			fs = frame:CreateFontString(nil, 'OVERLAY')
			-- A font before any text, in case the kit has no font of the asked size
			fs:SetFontObject(GameFontHighlight)
			fs:SetJustifyH('LEFT')
			fs:SetWordWrap(true)
			frame.texts[used.texts] = fs
		end
		Kit:SetFont(fs, size)
		fs:SetTextColor(color[1], color[2], color[3])
		fs:ClearAllPoints()
		fs:SetPoint('TOPLEFT', frame, 'TOPLEFT', indent or 0, -y)
		fs:SetWidth(textWidth or (width - (indent or 0)))
		fs:SetText(value or '')
		fs:Show()
		return fs
	end
	local function Link(label, onClick)
		used.links = used.links + 1
		local link = frame.links[used.links]
		if not link then
			link = Kit:CreateTextButton(frame)
			frame.links[used.links] = link
		end
		link:SetLabel(label)
		link:SetScript('OnClick', onClick)
		if link.ApplyColor then
			link:ApplyColor()
		end
		link:ClearAllPoints()
		link:Show()
		return link
	end
	local function Picture(art, x, top, w, h)
		used.arts = used.arts + 1
		local texture = frame.arts[used.arts]
		if not texture then
			texture = frame:CreateTexture(nil, 'ARTWORK')
			frame.arts[used.arts] = texture
		end
		texture:ClearAllPoints()
		texture:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -top)
		ShowCropped(texture, art, w, h)
	end
	local function ChangeLines(entry, indent)
		for _, line in ipairs(entry.lines or {}) do
			local kind = Text(line.kind == 'new' and 'New' or 'Better', 11, line.kind == 'new' and accent or colors.secondary, indent, 58)
			local text = Text(line.text, 13, colors.text, indent + 64, width - indent - 64)
			y = y + math.max(kind:GetStringHeight(), text:GetStringHeight()) + 6
		end
		if entry.fixes and entry.fixes > 0 then
			Text('Fixed', 11, colors.muted or colors.secondary, indent, 58)
			Text(entry.fixes .. (entry.fixes == 1 and ' problem fixed' or ' problems fixed'), 13, colors.secondary, indent + 64, width - indent - 64)
			y = y + 20
		end
	end

	local any = false
	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		local history = Setup:GetWhatsNewHistory(reg)
		local newest = history[1]
		if newest then
			any = true
			local unseen = Setup:GetUnseenWhatsNew(reg) ~= nil
			local hero = newest.hero
			if hero then
				if hero.art then
					-- One large picture, and up to two smaller ones stacked beside it
					local pictures = HeroPictures(hero.art)
					local height = math.floor(width * 0.22)
					if #pictures == 1 then
						Picture(pictures[1], 0, y, width, height)
					else
						local gap = 3
						local mainWidth = math.floor((width - gap) * 2 / 3)
						local sideWidth = width - mainWidth - gap
						local sideHeight = math.floor((height - gap) / 2)
						Picture(pictures[1], 0, y, mainWidth, height)
						for i = 2, math.min(#pictures, 3) do
							Picture(pictures[i], mainWidth + gap, y + (i - 2) * (sideHeight + gap), sideWidth, sideHeight)
						end
					end
					y = y + height + 10
				end
				Text((reg.config.brand or reg.name) .. ' ' .. newest.version, 12, accent, 0)
				y = y + 16
				local title = Text(hero.title, 22, colors.text, 0)
				y = y + title:GetStringHeight() + 4
				if hero.text then
					local body = Text(hero.text, 13, colors.secondary, 0, math.min(width, 560))
					y = y + body:GetStringHeight() + 10
				end
				if hero.action then
					used.buttons = used.buttons + 1
					local button = frame.buttons[used.buttons]
					if not button then
						button = Kit:CreateButton(frame, '', 'primary')
						frame.buttons[used.buttons] = button
					end
					button:SetText(hero.action.text or 'Show me')
					button:SetScript('OnClick', function()
						WhatsNew:Close()
						Setup:RunAction(reg, hero.action)
					end)
					button:ClearAllPoints()
					button:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -y)
					button:Show()
					y = y + 34
				end
				y = y + 10
			else
				local title = Text(newest.title, 16, colors.text, 0, width - 140)
				local link = Link((newest.action and newest.action.text) or 'Show me', function()
					WhatsNew:Close()
					Setup:RunAction(reg, newest.action)
				end)
				link:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -4, -y)
				y = y + title:GetStringHeight() + 4
				local tag = Text((reg.config.brand or reg.name) .. ' ' .. newest.version .. (unseen and '  -  New' or ''), 12, unseen and accent or (colors.muted or colors.secondary), 0)
				y = y + tag:GetStringHeight() + 4
				if newest.caption then
					local caption = Text(newest.caption, 13, colors.secondary, 0)
					y = y + caption:GetStringHeight() + 6
				end
			end
			if newest.lines or newest.fixes then
				local header = Text('Also in ' .. newest.version, 14, colors.text, 0)
				y = y + header:GetStringHeight() + 6
				ChangeLines(newest, 0)
			end
			-- Earlier versions fold away
			for i = 2, #history do
				local entry = history[i]
				local key = reg.id .. '@' .. entry.version
				local open = self.open[key] and true or false
				local count = #(entry.lines or {})
				local label = entry.version .. '   ' .. count .. ' new and better' .. ((entry.fixes and entry.fixes > 0) and (', ' .. entry.fixes .. ' fixed') or '')
				local link = Link((open and 'Hide ' or 'Show ') .. label, function()
					WhatsNew.open[key] = not open
					onChanged()
				end)
				link:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -y)
				y = y + 22
				if open then
					ChangeLines(entry, 12)
					y = y + 4
				end
			end
			y = y + 18
		end
	end

	for i = used.texts + 1, #frame.texts do
		frame.texts[i]:Hide()
	end
	for i = used.links + 1, #frame.links do
		frame.links[i]:Hide()
	end
	for i = used.arts + 1, #frame.arts do
		frame.arts[i]:Hide()
	end
	for i = used.buttons + 1, #frame.buttons do
		frame.buttons[i]:Hide()
	end
	if not any then
		Text('Nothing new right now.', 14, colors.text, 0)
		y = 24
	end
	return y
end

---@return Frame
function WhatsNew:EnsureWindow()
	if self.window then
		return self.window
	end
	local window = Kit:CreateShell({ name = 'LibAT_WhatsNew', title = "What's new", width = 720, height = 600, footer = true })
	local scroll, child = Kit:CreateScrollArea(window.Body)
	scroll:SetPoint('TOPLEFT', window.Body, 'TOPLEFT', 18, -14)
	scroll:SetPoint('BOTTOMRIGHT', window.Body, 'BOTTOMRIGHT', -26, 12)
	window.Scroll = scroll
	window.Child = child
	local close = Kit:CreateButton(window.Footer, 'Close', 'primary', 110)
	close:SetPoint('RIGHT', window.Footer, 'RIGHT', -14, 0)
	close:SetScript('OnClick', function()
		WhatsNew:Close()
	end)
	window.Close = close
	window:HookScript('OnHide', function()
		-- Everything shown counts as seen
		for _, reg in ipairs(Setup:GetSortedRegistrations()) do
			Setup:MarkWhatsNewSeen(reg)
		end
	end)
	self.window = window
	return window
end

function WhatsNew:Refresh()
	local window = self.window
	if not window or not window:IsShown() then
		return
	end
	local width = math.max((window.Scroll:GetWidth() or 0), 400)
	window.Child:SetWidth(width)
	local ok, height = pcall(self.Draw, self, window.Child, width, function()
		WhatsNew:Refresh()
	end)
	if not ok then
		Setup.Log('error', "What's new could not be drawn: " .. tostring(height))
		height = 20
	end
	window.Child:SetHeight(math.max(height, 1))
end

---"<Addon> What's new" when only one addon has something to show, in its own colors if it gives them
local function WindowTitle()
	local only
	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		if Setup:GetNewestWhatsNew(reg) then
			if only then
				return "What's new"
			end
			only = reg
		end
	end
	return only and ((only.config.brand or only.name) .. " What's new") or "What's new"
end

function WhatsNew:Open()
	local window = self:EnsureWindow()
	if window.TitleText then
		window.TitleText:SetText(WindowTitle())
	end
	window:Show()
	window.Scroll:SetVerticalScroll(0)
	self:Refresh()
	-- Sizes settle on the next frame after the window first shows
	C_Timer.After(0, function()
		WhatsNew:Refresh()
	end)
end

function WhatsNew:Close()
	if self.window then
		self.window:Hide()
	end
end
