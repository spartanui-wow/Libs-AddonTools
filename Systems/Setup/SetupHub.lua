---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup window: step list on the left, the current step on the right, progress and buttons below
----------------------------------------------------------------------------------------------------

local Setup = LibAT.Setup
local Log = Setup.Log
local SafeCall = Setup.SafeCall
local Kit = LibAT.UI.Kit

---@class LibAT.SetupHub
local Hub = {}
Setup.Hub = Hub
LibStub('AceEvent-3.0'):Embed(Hub)

local LEFT_WIDTH = 190
local STEP_ROW_HEIGHT = 18
local ADDON_ROW_HEIGHT = 24
local NONE_IMPORT = '__none'

Hub.run = { regs = {}, entries = {} }
Hub.index = 0
Hub.page = nil ---@type 'start'|'step'|'summary'|'whatsnew'|nil
Hub.startChecks = {}
Hub.startRegs = {}
Hub.origToggle = {}
Hub.customFrames = {}
Hub.formFrames = {}
Hub.importChoice = {}
Hub.grids = {}
Hub.toastQueue = {}

----------------------------------------------------------------------------------------------------
-- Small helpers
----------------------------------------------------------------------------------------------------

---@param count number
---@param one string
---@param many string
---@return string
local function Plural(count, one, many)
	return count == 1 and one or many
end

---@param reg LibAT.SetupRegistration
---@return string
local function IconMarkup(reg)
	local icon = reg.config.icon
	if icon == nil or icon == '' then
		return ''
	end
	return '|T' .. tostring(icon) .. ':16:16:0:0|t '
end

---A scroll frame owned by the active kit.
---@param parent Frame
---@param skin? table
---@return ScrollFrame scroll
---@return Frame child
local function CreateScroll(parent, skin)
	return skin:CreateScroll(parent)
end

---A plain text button
---@param parent Frame
---@param fontObject? string
---@return Button
local function CreateTextButton(parent, fontObject, skin)
	return skin:CreateTextButton(parent)
end

local function CreateSkinFontString(parent, layer)
	return parent:CreateFontString(nil, layer)
end

function Hub:GetLeftWidth()
	return 218
end

---Get the entry list positions of one addon inside the run
---@param reg LibAT.SetupRegistration
---@return number|nil first
---@return number|nil last
function Hub:GetAddonRange(reg)
	local first, last
	for i, entry in ipairs(self.run.entries) do
		if entry.reg == reg then
			first = first or i
			last = i
		end
	end
	return first, last
end

---@param reg LibAT.SetupRegistration
---@return boolean
function Hub:IsInRun(reg)
	if not self.run then
		return false
	end
	for _, r in ipairs(self.run.regs) do
		if r == reg then
			return true
		end
	end
	return false
end

----------------------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------------------

function Hub:EnsureWindow()
	local skin = Kit:GetActive()
	self.skin = skin
	if self.window then
		return self.window
	end
	self.grids = {}
	self.toggleGroups = {}
	self.formFrames = {}
	self.customFrames = {}
	self.summaryFrame = nil

	local w = skin:CreateWindow()
	w._setupKitId = skin.id
	self.window = w
	if LibAT.SetupWizard then
		LibAT.SetupWizard.window = w
	end
	w:HookScript('OnHide', function()
		Hub:OnHidden()
	end)

	self:CreateLeftSide(w)
	self:CreateRightSide(w)
	self:CreateFooter(w)

	self:RegisterMessage(LibAT.UI.ACCENT_CHANGED, 'ApplyAccent')
	self:RegisterMessage(LibAT.UI.BACKDROP_CHANGED, 'ApplyBackdrop')
	self:RegisterMessage(Kit.CHANGED, 'ApplyKit')
	self:ApplyAccent()
	return w
end

---Repaint the current setup window without changing the setup run.
function Hub:RebuildWindow()
	self:ApplyKit()
end

---@param w Frame
function Hub:CreateLeftSide(w)
	local left = w.LeftPanel
	local skin = self.skin
	left.Scroll, left.List = CreateScroll(left, skin)
	left.Scroll:SetPoint('TOPLEFT', left, 'TOPLEFT', skin.owned and 12 or 4, skin.owned and -12 or -6)
	left.Scroll:SetPoint('BOTTOMRIGHT', left, 'BOTTOMRIGHT', skin.owned and -24 or -14, skin.owned and 64 or 56)
	left.rows = {}

	left.WhatsNew = CreateFrame('Button', nil, left)
	left.WhatsNew:SetPoint('BOTTOMLEFT', left, 'BOTTOMLEFT', 8, 32)
	left.WhatsNew:SetPoint('BOTTOMRIGHT', left, 'BOTTOMRIGHT', -8, 32)
	left.WhatsNew:SetHeight(18)
	left.WhatsNew.line = left.WhatsNew:CreateTexture(nil, 'ARTWORK')
	left.WhatsNew.line:SetPoint('TOPLEFT', left.WhatsNew, 'TOPLEFT', 0, 4)
	left.WhatsNew.line:SetPoint('TOPRIGHT', left.WhatsNew, 'TOPRIGHT', 0, 4)
	left.WhatsNew.line:SetHeight(1)
	left.WhatsNew.line:SetColorTexture(0.3, 0.3, 0.3, 0.8)
	left.WhatsNew.text = CreateSkinFontString(left.WhatsNew, 'OVERLAY', skin, 'GameFontNormal')
	if skin.owned then
		skin:SetFont(left.WhatsNew.text, 12)
		left.WhatsNew.line:SetColorTexture(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.35)
	end
	left.WhatsNew.text:SetPoint('LEFT', left.WhatsNew, 'LEFT', 2, 0)
	left.WhatsNew:SetScript('OnClick', function()
		Hub:OpenWhatsNew()
	end)

	if skin.owned then
		left.AutoOpen = skin:CreateSwitchRow(left, 'Open after login')
		left.AutoOpen:SetPoint('BOTTOMLEFT', left, 'BOTTOMLEFT', 8, 8)
		left.AutoOpen:SetPoint('BOTTOMRIGHT', left, 'BOTTOMRIGHT', -8, 8)
		left.AutoOpen.onToggle = function(checked)
			Setup:SetAutoOpen(checked)
		end
	else
		left.AutoOpen = LibAT.UI.CreateCheckbox(left, 'Open after login', LEFT_WIDTH - 16)
		left.AutoOpen:SetPoint('BOTTOMLEFT', left, 'BOTTOMLEFT', 6, 6)
		left.AutoOpen:SetScript('OnClick', function(self)
			Setup:SetAutoOpen(self:GetChecked() and true or false)
		end)
		left.AutoOpen:SetScript('OnEnter', function(self)
			if GameTooltip then
				GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
				GameTooltip:SetText('Open after login', 1, 1, 1)
				GameTooltip:AddLine('When this is off, a small note tells you when an addon is ready to set up.', nil, nil, nil, true)
				GameTooltip:Show()
			end
		end)
		left.AutoOpen:SetScript('OnLeave', function()
			if GameTooltip then
				GameTooltip:Hide()
			end
		end)
	end
end

---@param w Frame
function Hub:CreateRightSide(w)
	local right = w.RightPanel
	local skin = self.skin

	right.AddonLabel = CreateSkinFontString(right, 'OVERLAY', skin, 'GameFontHighlightSmall')
	if skin.owned then
		skin:SetFont(right.AddonLabel, 13)
	end
	right.AddonLabel:SetPoint('TOPLEFT', right, 'TOPLEFT', 16, -12)
	right.AddonLabel:SetTextColor(skin.owned and skin.colors.secondary[1] or 0.65, skin.owned and skin.colors.secondary[2] or 0.65, skin.owned and skin.colors.secondary[3] or 0.65)
	right.AddonLabel:SetJustifyH('LEFT')

	right.Badge = CreateFrame('Frame', nil, right)
	right.Badge:SetSize(90, 16)
	right.Badge:SetPoint('TOPRIGHT', right, 'TOPRIGHT', -14, -12)
	right.Badge.bg = right.Badge:CreateTexture(nil, 'BACKGROUND')
	right.Badge.bg:SetAllPoints()
	right.Badge.bg:SetColorTexture(0.55, 0.42, 0.05, 0.85)
	right.Badge.text = CreateSkinFontString(right.Badge, 'OVERLAY', skin, 'GameFontHighlightSmall')
	if skin.owned then
		skin:SetFont(right.Badge.text, 11)
	end
	right.Badge.text:SetPoint('CENTER')
	right.Badge.text:SetText('Recommended')

	-- Centred in the strip under the cards, shown on picture pages only
	right.Density = CreateTextButton(right, nil, skin)
	right.Density:SetPoint('BOTTOM', right, 'BOTTOM', 0, 8)
	right.Density:SetScript('OnClick', function()
		Setup:SetDense(not Setup:GetDense())
		Hub:RenderCurrent()
	end)
	right.Density:Hide()
	right.Badge:EnableMouse(true)
	right.Badge:SetScript('OnEnter', function(self)
		if GameTooltip then
			GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
			GameTooltip:SetText('Recommended', 1, 1, 1)
			GameTooltip:AddLine('Not sure? Pick the choice marked Recommended.', nil, nil, nil, true)
			GameTooltip:Show()
		end
	end)
	right.Badge:SetScript('OnLeave', function()
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	right.Badge:Hide()

	if skin.owned then
		-- The kit's divider runs from the addon name to the panel edge
		right.Divider = right:CreateTexture(nil, 'ARTWORK')
		right.Divider:SetPoint('LEFT', right.AddonLabel, 'RIGHT', 12, 0)
		right.Divider:SetPoint('RIGHT', right, 'RIGHT', -16, 0)
		LibAT.UI.Kit:Track(right.Divider, function(owner, kit)
			local height = kit.layout.dividerHeight
			if height and LibAT.UI.Kit:SetAsset(owner, kit, 'divider') then
				owner:SetHeight(height)
				owner:SetVertexColor(1, 1, 1, 1)
			else
				owner:SetTexture('Interface\\Buttons\\WHITE8X8')
				owner:SetTexCoord(0, 1, 0, 1)
				owner:SetHeight(1)
				owner:SetVertexColor(kit.colors.trim[1], kit.colors.trim[2], kit.colors.trim[3], 0.55)
				owner:Show()
			end
		end)
	end

	right.Title = CreateSkinFontString(right, 'OVERLAY', skin, 'GameFontNormalLarge')
	if skin.owned then
		skin:SetFont(right.Title, 22)
		right.Title:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])
	end
	right.Title:SetPoint('TOPLEFT', right.AddonLabel, 'BOTTOMLEFT', 0, -3)
	right.Title:SetPoint('RIGHT', right.Badge, 'LEFT', -10, 0)
	right.Title:SetJustifyH('LEFT')

	right.Text = CreateSkinFontString(right, 'OVERLAY', skin, 'GameFontHighlight')
	if skin.owned then
		skin:SetFont(right.Text, 13)
	end
	right.Text:SetPoint('TOPLEFT', right.Title, 'BOTTOMLEFT', 0, -4)
	right.Text:SetPoint('RIGHT', right, 'RIGHT', -14, 0)
	right.Text:SetJustifyH('LEFT')
	right.Text:SetWordWrap(true)
	right.Text:SetTextColor(skin.owned and skin.colors.secondary[1] or 0.85, skin.owned and skin.colors.secondary[2] or 0.85, skin.owned and skin.colors.secondary[3] or 0.85)

	right.Scroll, right.Content = CreateScroll(right, skin)
	right.Scroll:SetPoint('TOPLEFT', right.Text, 'BOTTOMLEFT', 0, -12)
	right.Scroll:SetPoint('BOTTOMRIGHT', right, 'BOTTOMRIGHT', -24, 34)
	right.Scroll:HookScript('OnSizeChanged', function()
		Hub:OnContentResized()
	end)

	right.Message = CreateSkinFontString(right.Content, 'OVERLAY', skin, 'GameFontHighlight')
	if skin.owned then
		skin:SetFont(right.Message, 14)
		right.Message:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])
	end
	right.Message:SetPoint('TOPLEFT', right.Content, 'TOPLEFT', 0, -6)
	right.Message:SetPoint('RIGHT', right.Content, 'RIGHT', 0, 0)
	right.Message:SetJustifyH('LEFT')
	right.Message:SetWordWrap(true)

	right.Progress = skin.owned and skin:CreateProgress(right) or LibAT.UI.CreateProgressBar(right, 200, 14)
	right.Progress:ClearAllPoints()
	right.Progress:SetPoint('BOTTOMLEFT', right, 'BOTTOMLEFT', 14, 10)
	right.Progress:SetPoint('BOTTOMRIGHT', right, 'BOTTOMRIGHT', -190, 10)

	right.ReloadText = CreateSkinFontString(right, 'OVERLAY', skin, 'GameFontNormalSmall')
	if skin.owned then
		skin:SetFont(right.ReloadText, 11)
		right.ReloadText:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	end
	right.ReloadText:SetPoint('LEFT', right.Progress, 'RIGHT', 10, 0)
	right.ReloadText:SetPoint('RIGHT', right, 'RIGHT', -14, 0)
	right.ReloadText:SetJustifyH('RIGHT')

	right.Combat = CreateFrame('Frame', nil, skin.owned and w or right)
	right.Combat:SetAllPoints(right)
	right.Combat:SetFrameLevel(w:GetFrameLevel() + 80)
	right.Combat.bg = right.Combat:CreateTexture(nil, 'BACKGROUND')
	right.Combat.bg:SetAllPoints()
	right.Combat.bg:SetColorTexture(0, 0, 0, 0.55)
	right.Combat.text = CreateSkinFontString(right.Combat, 'OVERLAY', skin, 'GameFontNormalLarge')
	if skin.owned then
		skin:SetFont(right.Combat.text, 18)
		right.Combat.text:SetTextColor(1, 1, 1)
	end
	right.Combat.text:SetPoint('CENTER')
	right.Combat.text:SetText('Waiting for combat to end')
	right.Combat:Hide()
end

---@param w Frame
function Hub:CreateFooter(w)
	local skin = self.skin
	local bar = w.Footer
	if not skin.owned then
		bar = CreateFrame('Frame', nil, w)
		bar:SetPoint('BOTTOMLEFT', w, 'BOTTOMLEFT', 0, 0)
		bar:SetPoint('BOTTOMRIGHT', w, 'BOTTOMRIGHT', 0, 0)
		bar:SetHeight(36)
		w.Footer = bar
	end

	if skin.owned then
		w.ownedButtons = {}
		w.BackButton = skin:CreateButton(bar, 'Back', false)
		w.BackButton:SetPoint('LEFT', bar, 'LEFT', skin.footerInset or 18, skin.footerLift or 0)
		w.BackButton:SetScript('OnClick', function()
			Hub:GoBack()
		end)

		w.NextButton = skin:CreateButton(bar, 'Next', true)
		w.NextButton:SetPoint('RIGHT', bar, 'RIGHT', -(skin.footerInset or 18), skin.footerLift or 0)
		w.NextButton:SetScript('OnClick', function()
			Hub:GoNext()
		end)

		w.SkipAheadButton = skin:CreateButton(bar, 'Skip ahead', false)
		w.SkipAheadButton:SetPoint('RIGHT', w.NextButton, 'LEFT', -10, 0)
		w.SkipAheadButton:SetScript('OnClick', function()
			Hub:ToggleSkipMenu()
		end)
		w.ownedButtons[1], w.ownedButtons[2], w.ownedButtons[3] = w.BackButton, w.NextButton, w.SkipAheadButton

		local popup = CreateFrame('Frame', nil, w)
		popup:SetSize(300, 74)
		popup:SetPoint('BOTTOMRIGHT', w.SkipAheadButton, 'TOPRIGHT', 0, 8)
		popup:SetFrameLevel(w:GetFrameLevel() + 70)
		popup.bg = popup:CreateTexture(nil, 'BACKGROUND')
		popup.bg:SetTexture('Interface\\Buttons\\WHITE8X8')
		popup.bg:SetAllPoints()
		popup.bg:SetVertexColor(skin.colors.panel[1], skin.colors.panel[2], skin.colors.panel[3], 0.98)
		popup.edges = {}
		local function Edge(pointA, pointB, width, height)
			local tex = popup:CreateTexture(nil, 'BORDER')
			tex:SetTexture('Interface\\Buttons\\WHITE8X8')
			tex:SetPoint(pointA)
			tex:SetPoint(pointB)
			if width then
				tex:SetWidth(width)
			else
				tex:SetHeight(height)
			end
			tex:SetVertexColor(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.72)
		end
		Edge('TOPLEFT', 'BOTTOMLEFT', 1)
		Edge('TOPRIGHT', 'BOTTOMRIGHT', 1)
		Edge('TOPLEFT', 'TOPRIGHT', nil, 1)
		Edge('BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1)
		popup.skip = skin:CreateTextButton(popup)
		popup.skip:SetPoint('TOPLEFT', popup, 'TOPLEFT', 12, -12)
		popup.skip:SetLabel('Skip this addon - keeps current settings')
		popup.skip:SetScript('OnClick', function()
			popup:Hide()
			Hub:OnSkipClicked()
		end)
		popup.recommended = skin:CreateTextButton(popup)
		popup.recommended:SetPoint('TOPLEFT', popup.skip, 'BOTTOMLEFT', 0, -12)
		popup.recommended:SetLabel('Use recommended - keeps choices already made')
		popup.recommended:SetScript('OnClick', function()
			popup:Hide()
			Hub:OnRecommendedClicked()
		end)
		popup:Hide()
		w.SkipMenu = popup

		w.RightPanel.Progress:SetParent(bar)
		w.RightPanel.Progress:ClearAllPoints()
		w.RightPanel.Progress:SetPoint('CENTER', bar, 'CENTER', 0, 0)
		w.RightPanel.Progress:SetWidth(210)
		local reloadText = w.RightPanel.ReloadText
		reloadText:SetParent(bar)
		reloadText:ClearAllPoints()
		reloadText:SetPoint('TOP', w.RightPanel.Progress, 'BOTTOM', 0, -2)
		reloadText:SetJustifyH('CENTER')
		return
	end

	w.BackButton = LibAT.UI.CreateButton(bar, 90, 22, 'Back')
	w.BackButton:SetPoint('LEFT', bar, 'LEFT', LEFT_WIDTH + 30, -2)
	w.BackButton:SetScript('OnClick', function()
		Hub:GoBack()
	end)

	w.NextButton = LibAT.UI.CreateButton(bar, 150, 22, 'Next')
	w.NextButton:SetPoint('RIGHT', bar, 'RIGHT', -24, -2)
	w.NextButton:SetScript('OnClick', function()
		Hub:GoNext()
	end)

	w.RecButton = LibAT.UI.CreateButton(bar, 190, 22, 'Use recommended for the rest')
	w.RecButton:SetPoint('RIGHT', w.NextButton, 'LEFT', -6, 0)
	w.RecButton:SetScript('OnClick', function()
		Hub:OnRecommendedClicked()
	end)

	w.SkipButton = LibAT.UI.CreateButton(bar, 130, 22, 'Skip this addon')
	w.SkipButton:SetPoint('RIGHT', w.RecButton, 'LEFT', -6, 0)
	w.SkipButton:SetScript('OnClick', function()
		Hub:OnSkipClicked()
	end)
end

function Hub:ToggleSkipMenu()
	local menu = self.window and self.window.SkipMenu
	if not menu then
		return
	end
	menu:SetShown(not menu:IsShown())
end

---@return boolean
function Hub:IsShown()
	return self.window and self.window:IsShown() and true or false
end

function Hub:Close()
	if self.window then
		self.window:Hide()
	end
end

----------------------------------------------------------------------------------------------------
-- Opening and the run of steps
----------------------------------------------------------------------------------------------------

---Build the list of steps for these addons. Due steps when there are any, otherwise all of them.
---@param regs LibAT.SetupRegistration[]
function Hub:BuildRun(regs)
	local run = { regs = {}, entries = {}, candidates = {} }
	for _, reg in ipairs(regs) do
		local steps = Setup:GetDueSteps(reg)
		local candidates = Setup:GetDueSteps(reg, true)
		if #steps == 0 then
			steps = Setup:GetVisibleSteps(reg)
			candidates = Setup:GetVisibleSteps(reg, true)
		end
		if #steps > 0 then
			run.regs[#run.regs + 1] = reg
			run.candidates[reg] = candidates
			for _, step in ipairs(steps) do
				run.entries[#run.entries + 1] = { reg = reg, step = step }
			end
		end
	end
	self.run = run
	self.index = 0
end

---Steps can appear or disappear as the player picks things (a later step's hidden() changes),
---so the list is rebuilt before moving, keeping the player on the step they are on.
function Hub:RefreshRun()
	local run = self.run
	if not run or not run.candidates then
		return
	end
	local current = self.run.entries[self.index]
	local entries = {}
	for _, reg in ipairs(run.regs) do
		for _, step in ipairs(run.candidates[reg] or {}) do
			if step == (current and current.step) or Setup:IsStepVisible(reg, step) then
				entries[#entries + 1] = { reg = reg, step = step }
			end
		end
	end
	run.entries = entries
	if current then
		for i, entry in ipairs(entries) do
			if entry.step == current.step then
				self.index = i
				return
			end
		end
	end
end

---Add an addon that is not in the run yet, just before the summary
---@param reg LibAT.SetupRegistration
function Hub:AddToRun(reg)
	if self:IsInRun(reg) then
		return
	end
	local steps = Setup:GetDueSteps(reg)
	if #steps == 0 then
		steps = Setup:GetVisibleSteps(reg)
	end
	if #steps == 0 then
		return
	end
	self.run.regs[#self.run.regs + 1] = reg
	if self.run.candidates then
		local candidates = Setup:GetDueSteps(reg, true)
		self.run.candidates[reg] = #candidates > 0 and candidates or Setup:GetVisibleSteps(reg, true)
	end
	for _, step in ipairs(steps) do
		self.run.entries[#self.run.entries + 1] = { reg = reg, step = step }
	end
end

---Open the window
---@param addonId? string
---@param stepId? string
---@param auto? boolean Opened by itself after login
function Hub:Open(addonId, stepId, auto)
	self:EnsureWindow()
	for _, reg in pairs(Setup.registrations) do
		reg.forceDetect = true
	end
	self.startShown = false

	if addonId then
		local reg = Setup:GetRegistration(addonId) or Setup:FindRegistration(addonId)
		if reg then
			if not self.window:IsShown() or not self:IsInRun(reg) then
				if self.window:IsShown() and #self.run.entries > 0 then
					self:AddToRun(reg)
				else
					self:BuildRun({ reg })
				end
			end
			local first, last = self:GetAddonRange(reg)
			local target = first
			if stepId and first then
				for i = first, last do
					if self.run.entries[i].step.id == stepId then
						target = i
					end
				end
			end
			self.window:Show()
			if target then
				self:ShowEntry(target)
			else
				self:ShowStart()
			end
			return
		end
		Log('warning', 'Open: no addon "' .. tostring(addonId) .. '"')
	end

	local due = Setup:GetDueAddons(auto)
	self.window:Show()
	if #due == 1 then
		self:BuildRun(due)
		if #self.run.entries > 0 then
			self:ShowEntry(1)
			return
		end
	end
	self:ShowStart(due)
end

---Leave the current step: run its onLeave
---@param closing? boolean the window is closing, the player did not move on (ctx.closing)
function Hub:LeaveCurrent(closing)
	if self.page ~= 'step' then
		return
	end
	local entry = self.run.entries[self.index]
	if entry and entry.step.onLeave then
		local ctx = Setup:CreateContext(entry.reg, entry.step)
		ctx.closing = closing and true or nil
		SafeCall(entry.reg.id .. '.' .. entry.step.id .. ' onLeave', entry.step.onLeave, ctx)
	end
end

---Show one step of the run
---@param index number
function Hub:ShowEntry(index)
	local entry = self.run.entries[index]
	if not entry then
		self:ShowSummary()
		return
	end
	self:LeaveCurrent()
	self.page = 'step'
	self.index = index
	self:Render(true)
end

---@param due? LibAT.SetupRegistration[]
function Hub:ShowStart(due)
	self:LeaveCurrent()
	local regs = due
	self.startAllDone = false
	if not regs or #regs == 0 then
		regs = Setup:GetSortedRegistrations()
		self.startAllDone = true
	end
	self.startRegs = regs
	self.startChecks = {}
	for _, reg in ipairs(regs) do
		local rec = Setup:GetRecord(reg)
		self.startChecks[reg.id] = (not self.startAllDone) and not (rec and rec.muted)
	end
	self.startShown = true
	self.page = 'start'
	self.index = 0
	self:Render(true)
end

function Hub:ShowSummary()
	self:LeaveCurrent()
	self.page = 'summary'
	self:Render(true)
end

function Hub:OpenWhatsNew()
	-- What's new has its own window, so it never looks like setup asking for something
	if Setup.WhatsNew then
		Setup.WhatsNew:Open()
	end
end

---When a step says its pick finishes the addon (step.finishNow returns a button label), Next does it
---@return string|nil label
function Hub:GetFinishNowLabel()
	local entry = self.page == 'step' and self.run and self.run.entries[self.index]
	if not entry or type(entry.step.finishNow) ~= 'function' then
		return nil
	end
	local ok, label = SafeCall(entry.reg.id .. '.' .. entry.step.id .. ' finishNow', entry.step.finishNow)
	return ok and type(label) == 'string' and label or nil
end

---Next button
function Hub:GoNext()
	self:RefreshRun()
	if self.page == 'step' and self:GetFinishNowLabel() and not Setup.inCombat then
		-- Only this addon is finished; other addons still due open again after the reload
		local entry = self.run.entries[self.index]
		self.finishing = true
		self:LeaveCurrent()
		self.page = nil
		Setup:FinishAndReload({ entry.reg })
		self:Close()
		self.finishing = false
		return
	end
	if self.page == 'step' then
		local entry = self.run.entries[self.index]
		local last
		if entry then
			last = select(2, self:GetAddonRange(entry.reg))
		end
		if last == self.index then
			-- Moving on from an addon's last step finishes it (just seeing a page does not)
			Setup:MarkDone(entry.reg, true)
		end
		if self.index < #self.run.entries then
			self:ShowEntry(self.index + 1)
		else
			self:ShowSummary()
		end
	elseif self.page == 'start' then
		self:StartChecked(false)
	elseif self.page == 'summary' then
		self:Finish(Setup:GetStagedCount() > 0)
	elseif self.page == 'whatsnew' then
		self:GoBack()
	end
end

---Back button
function Hub:GoBack()
	self:RefreshRun()
	if self.page == 'step' then
		if self.index > 1 then
			self:ShowEntry(self.index - 1)
		elseif self.startShown then
			self:ShowStart(self.startRegs)
		end
	elseif self.page == 'summary' then
		if #self.run.entries > 0 then
			self:ShowEntry(#self.run.entries)
		else
			self:ShowStart(self.startRegs)
		end
	elseif self.page == 'whatsnew' then
		local page, index = self.returnPage, self.returnIndex
		self.returnPage, self.returnIndex = nil, nil
		if page == 'step' and self.run.entries[index] then
			self:ShowEntry(index)
		elseif page == 'summary' then
			self:ShowSummary()
		elseif page == 'start' then
			self:ShowStart(self.startRegs)
		else
			self:Close()
		end
	end
end

---Move to the first step of the addon after this one, or the summary
---@param reg LibAT.SetupRegistration
function Hub:GoPastAddon(reg)
	local _, last = self:GetAddonRange(reg)
	if last and self.run.entries[last + 1] then
		self:ShowEntry(last + 1)
	else
		self:ShowSummary()
	end
end

function Hub:OnSkipClicked()
	if self.page == 'summary' then
		self:Finish(false)
		return
	end
	local entry = self.page == 'step' and self.run.entries[self.index]
	if not entry then
		return
	end
	Setup:MarkSkipped(entry.reg)
	self:GoPastAddon(entry.reg)
end

function Hub:OnRecommendedClicked()
	if self.page == 'start' then
		self:StartChecked(true)
		return
	end
	local entry = self.page == 'step' and self.run.entries[self.index]
	if not entry then
		return
	end
	local _, last = self:GetAddonRange(entry.reg)
	local steps = {}
	for i = self.index, last do
		steps[#steps + 1] = self.run.entries[i].step
	end
	self:LeaveCurrent()
	self.page = nil
	Setup:ApplyRecommended(entry.reg, steps)
	self:GoPastAddon(entry.reg)
end

---Start page buttons
---@param recommended boolean Use recommended settings instead of walking through the steps
function Hub:StartChecked(recommended)
	local chosen = {}
	for _, reg in ipairs(self.startRegs) do
		if self.startChecks[reg.id] then
			chosen[#chosen + 1] = reg
		end
	end
	if #chosen == 0 then
		return
	end
	self:BuildRun(chosen)
	if recommended then
		for _, reg in ipairs(self.run.regs) do
			local steps = {}
			for _, entry in ipairs(self.run.entries) do
				if entry.reg == reg then
					steps[#steps + 1] = entry.step
				end
			end
			Setup:ApplyRecommended(reg, steps)
		end
		self:ShowSummary()
		return
	end
	if #self.run.entries > 0 then
		self:ShowEntry(1)
	else
		self:ShowSummary()
	end
end

---Finish buttons on the summary page
---@param reload boolean
function Hub:Finish(reload)
	if Setup.inCombat then
		return
	end
	local regs = self.run.regs
	self.finishing = true
	self:LeaveCurrent()
	self.page = nil
	if reload then
		Setup:FinishAndReload(regs)
		self:Close()
	else
		self:Close()
		Setup:FinishWithoutReload(regs)
	end
	self.finishing = false
end

---The window was hidden (Finish, Close, Escape): count a reminder for addons still due
function Hub:OnHidden()
	-- A cinematic or movie closes every window when it starts. That is the game, not the player:
	-- keep the window where it was and bring it back when the cinematic ends.
	if not self.finishing and Setup:IsCinematicPlaying() then
		Setup.reopenAfterCinematic = true
		if GameTooltip then
			GameTooltip:Hide()
		end
		return
	end
	self:LeaveCurrent(not self.finishing)
	if GameTooltip then
		GameTooltip:Hide()
	end
	if self.finishing or not self.autoOpenedThisSession or self.remindCounted then
		return
	end
	self.remindCounted = true
	local regs = #self.run.regs > 0 and self.run.regs or self.startRegs or {}
	for _, reg in ipairs(regs) do
		local rec = Setup:GetRecord(reg)
		-- Pending addons, and finished ones still waiting on a new profile's steps
		if rec and (rec.status == 'pending' or #Setup:GetDueSteps(reg) > 0) then
			rec.remind = (rec.remind or 0) + 1
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Rendering
----------------------------------------------------------------------------------------------------

---Grid for a kind of page, created once and reused
---@param key string
---@return LibAT.CardGrid
function Hub:GetGrid(key)
	local grid = self.grids[key]
	if grid then
		return grid
	end
	local content = self.window.RightPanel.Content
	local opts
	if self.skin.owned then
		if key == 'look' then
			opts = { artHeight = 148, minWidth = 210, maxColumns = 3, cardHeight = 238, spacing = 12 }
		elseif key == 'look-dense' then
			-- Show more at once: four across, no captions
			opts = { artHeight = 88, minWidth = 160, maxColumns = 4, cardHeight = 150, spacing = 10 }
		elseif key == 'look-compact-dense' then
			opts = { artHeight = 40, minWidth = 150, maxColumns = 4, cardHeight = 74, spacing = 8 }
		elseif key:find('^tiles') then
			-- Links on the final page: small text cards, three across
			opts = { artHeight = 0, minWidth = 160, maxColumns = 3, cardHeight = 58, spacing = 8 }
		elseif key == 'look-compact' then
			-- A short band of art and the name under it (step.compact), for cards with no caption
			opts = { artHeight = 62, minWidth = 210, maxColumns = 3, cardHeight = 102, spacing = 10 }
		elseif key == 'whatsnew' then
			opts = { artHeight = 0, minWidth = 260, maxColumns = 2, cardHeight = 72 }
		elseif key == 'start' then
			opts = { artHeight = 0, minWidth = 260, maxColumns = 2, cardHeight = 70 }
		else
			opts = { artHeight = 0, minWidth = 240, maxColumns = 2, cardHeight = 64 }
		end
	elseif key == 'look' then
		opts = { artHeight = 92, minWidth = 165, maxColumns = 4 }
	elseif key == 'look-compact' then
		opts = { artHeight = 48, minWidth = 165, maxColumns = 4, cardHeight = 86 }
	elseif key == 'look-dense' then
		opts = { artHeight = 70, minWidth = 140, maxColumns = 5, cardHeight = 120 }
	elseif key == 'look-compact-dense' then
		opts = { artHeight = 36, minWidth = 140, maxColumns = 5, cardHeight = 70 }
	elseif key == 'whatsnew' then
		opts = { artHeight = 0, minWidth = 220, maxColumns = 2, cardHeight = 104 }
	elseif key == 'start' then
		opts = { artHeight = 0, minWidth = 230, maxColumns = 2, cardHeight = 100 }
	else
		opts = { artHeight = 0, minWidth = 200, maxColumns = 4, cardHeight = 96 }
	end
	grid = self.skin.owned and self.skin:CreateCardGrid(content, opts) or LibAT.UI.CreateCardGrid(content, opts)
	self.grids[key] = grid
	return grid
end

---Hide everything in the content area
function Hub:HideContent()
	local right = self.window.RightPanel
	right.Message:SetText('')
	right.Message:Hide()
	for _, grid in pairs(self.grids) do
		grid:Hide()
	end
	for _, group in ipairs(self.toggleGroups or {}) do
		group:Hide()
	end
	for _, form in pairs(self.formFrames) do
		form.frame:Hide()
	end
	for _, frame in pairs(self.customFrames) do
		frame:Hide()
	end
	for _, frame in pairs(self.choiceExtras or {}) do
		frame:Hide()
	end
	for _, header in pairs(self.followHeaders or {}) do
		header:Hide()
	end
	if self.whatsNewFrame then
		self.whatsNewFrame:Hide()
	end
	if self.summaryFrame then
		self.summaryFrame:Hide()
	end
end

---Width available for content
---@return number
function Hub:GetContentWidth()
	local width = self.window.RightPanel.Scroll:GetWidth() or 0
	if width < 100 then
		width = 540
	end
	-- Room on the right for a selected card's glow and the panel's inner edge, so the last column
	-- of cards (and its corner badges) is never cut off
	return width - 14
end

---@param title string
---@param text? string
---@param addonLabel? string
---@param recommended? boolean
function Hub:SetHeader(title, text, addonLabel, recommended)
	local right = self.window.RightPanel
	right.AddonLabel:SetText(addonLabel or '')
	right.Title:SetText(title or '')
	right.Text:SetText(text or '')
	right.Badge:SetShown(recommended and true or false)
	-- Picture pages offer smaller cards, so more fit at once
	local entry = self.page == 'step' and self.run and self.run.entries[self.index]
	local pictures = entry and entry.step.kind == 'look'
	right.Density:SetShown(pictures and true or false)
	if pictures then
		right.Density:SetLabel(Setup:GetDense() and 'Bigger pictures' or 'Show more at once')
		if right.Density.ApplyColor then
			right.Density:ApplyColor()
		end
	end
	-- The cards use the whole panel; picture pages keep a strip at the bottom for the size button.
	-- Windows whose kit draws its own footer bar need no room for the progress bar here.
	local bottom = (self.skin.owned and 10 or 34) + (pictures and 22 or 0)
	if right.scrollBottom ~= bottom then
		right.scrollBottom = bottom
		right.Scroll:SetPoint('BOTTOMRIGHT', right, 'BOTTOMRIGHT', -24, bottom)
		right.Density:ClearAllPoints()
		right.Density:SetPoint('BOTTOM', right, 'BOTTOM', 0, bottom - 22)
	end
	if self.skin.owned then
		local plain = (addonLabel or ''):gsub('|T.-|t%s*', '')
		self.window:SetTitle(plain ~= '' and (plain .. ' Setup') or 'Setup')
	end
end

---Draw the current page. Never draws inside another draw: a draw changes the header, which resizes
---the scroll area, and the next size read fires its resize handler in the middle of the draw. A
---second draw started there builds the page's frames again, the first draw then replaces the saved
---ones, and the extra copies stay on screen on every later page. Such requests wait until the
---running draw is done, then run once.
---@param scrollToTop? boolean
function Hub:Render(scrollToTop)
	if not self.window then
		return
	end
	if self.rendering then
		self.renderQueued = true
		self.renderQueuedTop = self.renderQueuedTop or scrollToTop
		return
	end
	self.rendering = true
	-- An error must not leave the window locked out of drawing
	xpcall(self.RenderNow, geterrorhandler(), self, scrollToTop)
	if self.renderQueued then
		local top = self.renderQueuedTop
		self.renderQueued, self.renderQueuedTop = nil, nil
		xpcall(self.RenderNow, geterrorhandler(), self, top)
		-- Requests made during the second pass are dropped, so two draws can never chase each other
		self.renderQueued, self.renderQueuedTop = nil, nil
	end
	self.rendering = false
end

---@param scrollToTop? boolean
function Hub:RenderNow(scrollToTop)
	local right = self.window.RightPanel
	self:HideContent()
	right.Content:SetWidth(self:GetContentWidth())

	local height = 1
	if self.page == 'start' then
		height = self:RenderStart()
	elseif self.page == 'summary' then
		height = self:RenderSummary(self.run.regs, true)
	elseif self.page == 'whatsnew' then
		height = self:RenderWhatsNew()
	elseif self.page == 'step' then
		local entry = self.run.entries[self.index]
		if entry then
			height = self:RenderStep(entry)
		end
	end
	self.contentHeight = height
	local current = self.page == 'step' and self.run and self.run.entries[self.index]
	local currentKey = current and (current.reg.id .. '.' .. current.step.id)
	for key, frame in pairs(self.choiceExtras or {}) do
		if key ~= currentKey then
			frame:Hide()
		end
	end
	right.Content:SetHeight(math.max(height, 1))
	if scrollToTop then
		right.Scroll:SetVerticalScroll(0)
	end
	self:RefreshList()
	self:UpdateFooter()
	self:OnCombatChanged(Setup.inCombat)
end

---Draw the current page again (after a change)
function Hub:RenderCurrent()
	if self:IsShown() then
		self:Render(false)
	end
end

---Re-measure the page height (custom pages that grew)
function Hub:UpdateScrollHeight()
	if not self.window or self.page ~= 'step' then
		return
	end
	local entry = self.run.entries[self.index]
	local frame = entry and self.customFrames[entry.reg.id .. '.' .. entry.step.id]
	if frame and frame:IsShown() then
		local height = math.max(frame:GetHeight() or 1, type(frame.totalHeight) == 'number' and frame.totalHeight or 0, 1)
		self.window.RightPanel.Content:SetHeight(height)
	end
end

function Hub:OnContentResized()
	if not self:IsShown() or self.resizing then
		return
	end
	self.resizing = true
	local entry = self.page == 'step' and self.run.entries[self.index]
	if entry and entry.step.kind == 'custom' then
		local width = self:GetContentWidth()
		self.window.RightPanel.Content:SetWidth(width)
		local frame = self.customFrames[entry.reg.id .. '.' .. entry.step.id]
		if frame then
			frame:SetWidth(width)
		end
	else
		self:Render(false)
	end
	self.resizing = false
end

---@param entry {reg: LibAT.SetupRegistration, step: LibAT.SetupStep}
---@return number height
function Hub:RenderStep(entry)
	local reg, step = entry.reg, entry.step
	local ctx = Setup:CreateContext(reg, step)
	local hasRecommended = false
	if step.kind == 'look' or step.kind == 'choice' then
		hasRecommended = Setup:GetRecommended(step) ~= nil
	elseif step.kind == 'toggles' then
		for _, item in ipairs(Setup:GetToggleItems(step)) do
			if item.recommended ~= nil then
				hasRecommended = true
			end
		end
	end
	self:SetHeader(step.title or step.name, step.text, IconMarkup(reg) .. reg.name, hasRecommended)

	local kind = step.kind
	if kind == 'look' or kind == 'choice' then
		return self:RenderChoice(reg, step, ctx)
	elseif kind == 'toggles' then
		return self:RenderToggles(reg, step, ctx)
	elseif kind == 'import' then
		return self:RenderImport(reg, step, ctx)
	elseif kind == 'form' then
		return self:RenderForm(reg, step, ctx)
	elseif kind == 'custom' then
		return self:RenderCustom(reg, step, ctx)
	elseif kind == 'summary' then
		return self:RenderSummary({ reg }, false)
	end
	return 1
end

---A row of choices drawn above a look or choice step's cards (step.extra)
---@return number height
function Hub:RenderChoiceExtra(reg, step, ctx)
	local extra = step.extra
	local key = reg.id .. '.' .. step.id
	self.choiceExtras = self.choiceExtras or {}
	local frame = self.choiceExtras[key]
	-- Only the page on screen draws its row
	local onScreen = self.page == 'step' and self.run and self.run.entries[self.index]
	if not onScreen or onScreen.step ~= step then
		if frame then
			frame:Hide()
		end
		return 0
	end
	local content = self.window.RightPanel.Content
	local Kit = LibAT.UI.Kit
	local width = self:GetContentWidth()
	if not frame then
		frame = CreateFrame('Frame', nil, content)
		frame.title = CreateSkinFontString(frame, 'OVERLAY', self.skin, 'GameFontNormal')
		frame.title:SetJustifyH('LEFT')
		frame.title:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, 0)
		frame.text = CreateSkinFontString(frame, 'OVERLAY', self.skin, 'GameFontHighlightSmall')
		frame.text:SetJustifyH('LEFT')
		frame.text:SetWordWrap(true)
		frame.text:SetPoint('TOPLEFT', frame.title, 'BOTTOMLEFT', 0, -3)
		-- One joined row of buttons; the picked one is filled
		frame.segments = {}
		for i, choice in ipairs(extra.choices) do
			local button = Kit:CreateButton(frame, choice.title, 'secondary')
			button:SetScript('OnClick', function()
				SafeCall(key .. ' extra set', extra.set, choice.value, frame.ctx)
				Hub:RenderCurrent()
			end)
			frame.segments[i] = button
		end
		self.choiceExtras[key] = frame
	end
	self.skin:SetFont(frame.title, 14)
	self.skin:SetFont(frame.text, 12)
	local colors = self.skin.colors
	frame.title:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	frame.text:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
	frame.title:SetText(extra.title or '')
	frame.text:SetWidth(width)
	frame.text:SetText(extra.text or '')
	frame.ctx = ctx
	local _, current = SafeCall(key .. ' extra get', extra.get)
	local textHeight = (extra.text and extra.text ~= '') and (frame.text:GetStringHeight() + 3) or 0
	local x = 0
	for i, choice in ipairs(extra.choices) do
		local button = frame.segments[i]
		button.style = choice.value == current and 'primary' or 'secondary'
		if button.ApplyKit then
			button:ApplyKit()
		end
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -(18 + textHeight + 6))
		-- Neighbours share their edge
		x = x + (button:GetWidth() or 80) - 1
	end
	local height = 18 + textHeight + 6 + 26
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
	frame:SetSize(width, height)
	frame:Show()
	-- Room before the cards, with their own heading when the step names one
	return height + 16
end

---Look and choice steps
---@return number height
function Hub:RenderChoice(reg, step, ctx)
	local dense = step.kind == 'look' and Setup:GetDense()
	local gridKey = step.kind == 'look' and ((step.compact and 'look-compact' or 'look') .. (dense and '-dense' or '')) or 'choice'
	local grid = self:GetGrid(gridKey)
	local list = {}
	for _, option in ipairs(Setup:GetOptions(step)) do
		local variant
		if option.variants and step.getVariant then
			local _, v = SafeCall(reg.id .. '.' .. step.id .. ' getVariant', step.getVariant, option.value)
			variant = v
		end
		list[#list + 1] = {
			value = option.value,
			title = option.title,
			-- Small cards show the picture and the name only
			caption = not dense and option.caption or nil,
			tag = option.tag,
			tagStyle = option.tagStyle,
			art = option.art,
			accent = option.accent,
			recommended = option.recommended or (step.recommended ~= nil and step.recommended == option.value),
			variants = option.variants,
			variant = variant,
		}
	end
	grid.opts.onClick = function(_, value)
		local _, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
		if current ~= value then
			Setup:CallSet(reg, step, ctx, value)
		end
		LibAT.UI.NotifyAccentChanged()
		Hub:RenderCurrent()
	end
	grid.opts.onVariant = function(_, value, variant)
		local _, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
		if current ~= value then
			Setup:CallSet(reg, step, ctx, value)
		end
		SafeCall(reg.id .. '.' .. step.id .. ' setVariant', step.setVariant, value, variant, ctx)
		LibAT.UI.NotifyAccentChanged()
		Hub:RenderCurrent()
	end
	grid.opts.onCheck = nil
	grid:SetCards(list)
	local _, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
	local label = step.selectedLabel or (step.kind == 'look' and 'In use' or 'Selected')
	for _, card in ipairs(grid.cards) do
		local selected = card.data.value == current
		card:SetState(selected, true, selected and label or nil)
	end
	local top = 0
	if step.extra and step.extra.choices and #step.extra.choices > 0 then
		top = self:RenderChoiceExtra(reg, step, ctx)
	end
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', self.window.RightPanel.Content, 'TOPLEFT', 0, -top)
	grid:Show()
	local height = top + grid:Layout(self:GetContentWidth())
	if step.follow then
		height = height + self:RenderChoiceFollow(reg, step, ctx, height)
	end
	return height
end

---A second set of cards under a choice, shown when the first pick needs one (step.follow)
---@return number height
function Hub:RenderChoiceFollow(reg, step, ctx, top)
	local follow = step.follow
	local key = reg.id .. '.' .. step.id
	local content = self.window.RightPanel.Content
	local grid = self:GetGrid('follow')
	self.followHeaders = self.followHeaders or {}
	local header = self.followHeaders[key]
	if not header then
		header = CreateSkinFontString(content, 'OVERLAY', self.skin, 'GameFontNormal')
		header:SetJustifyH('LEFT')
		self.followHeaders[key] = header
	end
	local shown = true
	if type(follow.shown) == 'function' then
		local ok, result = SafeCall(key .. ' follow shown', follow.shown)
		shown = ok and result and true or false
	end
	if not shown then
		header:Hide()
		grid:Hide()
		return 0
	end
	local options = follow.choices
	if type(options) == 'function' then
		local ok, result = SafeCall(key .. ' follow choices', options)
		options = ok and type(result) == 'table' and result or {}
	end
	self.skin:SetFont(header, 15)
	local colors = self.skin.colors
	header:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	header:SetText(type(follow.title) == 'function' and select(2, SafeCall(key .. ' follow title', follow.title)) or follow.title or '')
	header:ClearAllPoints()
	header:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -(top + 18))
	header:Show()
	local list = {}
	for _, option in ipairs(options) do
		list[#list + 1] = { value = option.value, title = option.title, caption = option.caption, tag = option.tag, recommended = option.recommended }
	end
	grid.opts.onClick = function(_, value)
		SafeCall(key .. ' follow set', follow.set, value, ctx)
		Hub:RenderCurrent()
	end
	grid.opts.onVariant = nil
	grid.opts.onCheck = nil
	grid:SetCards(list)
	local _, current = SafeCall(key .. ' follow get', follow.get)
	for _, card in ipairs(grid.cards) do
		local selected = card.data.value == current
		card:SetState(selected, true, selected and 'Selected' or nil)
	end
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -(top + 44))
	grid:Show()
	return 44 + grid:Layout(self:GetContentWidth())
end

---A toggle group: header, Turn all on/off, and a grid of checkable cards
---@param index number
---@return Frame
function Hub:GetToggleGroup(index)
	self.toggleGroups = self.toggleGroups or {}
	local group = self.toggleGroups[index]
	if group then
		return group
	end
	local content = self.window.RightPanel.Content
	group = CreateFrame('Frame', nil, content)
	group:SetHeight(1)
	group.Title = CreateSkinFontString(group, 'OVERLAY', self.skin, 'GameFontNormal')
	if self.skin.owned then
		self.skin:SetFont(group.Title, 12)
		group.Title:SetTextColor(self.skin.colors.secondary[1], self.skin.colors.secondary[2], self.skin.colors.secondary[3])
	end
	group.Title:SetPoint('TOPLEFT', group, 'TOPLEFT', 0, 0)
	group.AllOff = CreateTextButton(group, nil, self.skin)
	group.AllOff:SetPoint('TOPRIGHT', group, 'TOPRIGHT', 0, 0)
	group.AllOn = CreateTextButton(group, nil, self.skin)
	group.AllOn:SetPoint('RIGHT', group.AllOff, 'LEFT', -12, 0)
	group.AllOn:SetLabel('Turn all on')
	group.AllOff:SetLabel('Turn all off')
	if self.skin.owned then
		group.rows = {}
	else
		group.grid = LibAT.UI.CreateCardGrid(group, { artHeight = 0, minWidth = 180, maxColumns = 3, cardHeight = 78 })
		group.grid:SetPoint('TOPLEFT', group, 'TOPLEFT', 0, -22)
	end
	self.toggleGroups[index] = group
	return group
end

---Toggles steps
---@return number height
function Hub:RenderToggles(reg, step, ctx)
	local groups = step.groups and Setup:GetToggleGroups(step) or { { items = step.items or {} } }
	local width = self:GetContentWidth()
	local content = self.window.RightPanel.Content
	local y = 0
	local prefix = reg.id .. '.' .. step.id .. '.'

	local function Current(item)
		if item.core then
			return true
		end
		local _, value = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get, item.key)
		return value and true or false
	end
	local function Original(item)
		local key = prefix .. tostring(item.key)
		if self.origToggle[key] == nil then
			self.origToggle[key] = Current(item)
		end
		return self.origToggle[key]
	end
	local function SetItem(item, value)
		if item.core then
			return
		end
		if Current(item) ~= value then
			Setup:CallToggle(reg, step, ctx, item, value, Original(item))
		end
	end

	for i, groupDef in ipairs(groups) do
		local group = self:GetToggleGroup(i)
		local items = groupDef.items or {}
		local byKey = {}
		local list = {}
		for _, item in ipairs(items) do
			Original(item)
			byKey[item.key] = item
			local tag
			if item.core then
				tag = 'Core'
			elseif item.needsReload then
				tag = 'Needs reload'
			end
			list[#list + 1] = {
				value = item.key,
				title = item.title,
				caption = item.caption,
				tag = tag,
				checkable = true,
				checked = Current(item),
				recommended = item.recommended == true,
				disabled = item.core,
			}
		end
		group.AllOn:SetScript('OnClick', function()
			for _, item in ipairs(items) do
				SetItem(item, true)
			end
			Hub:RenderCurrent()
		end)
		group.AllOff:SetScript('OnClick', function()
			for _, item in ipairs(items) do
				SetItem(item, false)
			end
			Hub:RenderCurrent()
		end)
		group.Title:SetText(groupDef.title or '')
		group.AllOn:ApplyColor()
		group.AllOff:ApplyColor()
		-- Steps whose switches each need their own decision leave out "Turn all on"
		group.AllOn:SetShown(not step.noBulk)
		group.AllOff:SetShown(not step.noBulk)
		group:ClearAllPoints()
		group:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
		group:SetWidth(width)
		local height
		if self.skin.owned then
			local columns = width >= 560 and 2 or 1
			local spacing = 14
			local rowWidth = math.floor((width - (columns - 1) * spacing) / columns)
			-- Each line of the grid is as tall as its tallest row, so long descriptions never overlap
			local lineTop, lineHeight = 26, 0
			for rowIndex, item in ipairs(items) do
				local row = group.rows[rowIndex]
				if not row then
					row = self.skin:CreateSwitchRow(group, item.title, item.caption)
					group.rows[rowIndex] = row
				end
				local currentItem = item
				local currentRow = row
				row:SetText(item.title)
				row:SetDescription(item.caption)
				row:SetChecked(Current(item))
				row:SetEnabled(not item.core)
				if item.core then
					row:SetBadge('Always on', 'skipped')
				elseif item.needsReload then
					row:SetBadge('Needs reload', 'warning')
				elseif item.recommended == true then
					row:SetBadge('Recommended', 'recommended')
				else
					row:SetBadge(nil)
				end
				row.onToggle = function(checked)
					SetItem(currentItem, checked)
					currentRow:SetChecked(Current(currentItem))
				end
				local column = (rowIndex - 1) % columns
				if column == 0 and rowIndex > 1 then
					lineTop = lineTop + lineHeight + 4
					lineHeight = 0
				end
				row:ClearAllPoints()
				row:SetPoint('TOPLEFT', group, 'TOPLEFT', column * (rowWidth + spacing), -lineTop)
				row:SetWidth(rowWidth)
				lineHeight = math.max(lineHeight, row:Fit())
				row:Show()
			end
			for rowIndex = #items + 1, #group.rows do
				group.rows[rowIndex]:Hide()
			end
			height = lineTop + lineHeight
		else
			group.grid.opts.onCheck = function(card, key, checked)
				local item = byKey[key]
				if item then
					SetItem(item, checked)
					card:SetChecked(Current(item))
				end
			end
			group.grid:SetCards(list)
			for _, card in ipairs(group.grid.cards) do
				local item = byKey[card.data.value]
				card:SetState(false, not item.core, item.core and 'Always on' or nil)
			end
			local gridHeight = group.grid:Layout(width)
			height = 22 + gridHeight
		end
		group:SetHeight(height)
		group:Show()
		y = y + height + 16
	end
	return math.max(y - 16, 1)
end

---Import steps
---@return number height
function Hub:RenderImport(reg, step, ctx)
	local grid = self:GetGrid('choice')
	local key = reg.id .. '.' .. step.id
	local sources = Setup:GetDetectedSources(reg, step)
	local byId = {}
	local list = {}
	for _, source in ipairs(sources) do
		byId[source.id] = source
		list[#list + 1] = { value = source.id, title = source.title, caption = source.caption }
	end
	list[#list + 1] = { value = NONE_IMPORT, title = "Don't import", caption = 'Start with the default settings.' }
	local stageKey = 'import:' .. step.id
	grid.opts.onClick = function(_, value)
		Hub.importChoice[key] = value
		local source = byId[value]
		if source then
			ctx:NeedsReload(stageKey, 'Import from ' .. source.title, function()
				source.apply(ctx)
			end)
		else
			ctx:CancelReload(stageKey)
		end
		Hub:RenderCurrent()
	end
	grid.opts.onVariant = nil
	grid.opts.onCheck = nil
	grid:SetCards(list)
	local current = self.importChoice[key] or NONE_IMPORT
	for _, card in ipairs(grid.cards) do
		local selected = card.data.value == current
		card:SetState(selected, true, selected and 'Selected' or nil)
	end
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', self.window.RightPanel.Content, 'TOPLEFT', 0, 0)
	grid:Show()
	return grid:Layout(self:GetContentWidth())
end

---Form steps: BuildWidgets definitions, built once per step and refreshed on later visits
---@return number height
function Hub:RenderForm(reg, step, ctx)
	local key = reg.id .. '.' .. step.id
	local form = self.formFrames[key]
	local content = self.window.RightPanel.Content
	if not form then
		local frame = CreateFrame('Frame', nil, content)
		frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
		frame:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0)
		frame:SetHeight(1)
		local defs = {}
		for id, def in pairs(step.widgets) do
			local copy = setmetatable({}, { __index = def })
			if type(def.set) == 'function' then
				copy.set = function(info, value)
					local ok = SafeCall(key .. '.' .. tostring(id) .. ' set', def.set, info, value)
					if ok and type(def.get) == 'function' then
						local _, now = SafeCall(key .. '.' .. tostring(id) .. ' get', def.get)
						if rawequal(now, info) then
							Log('error', key .. ' widget "' .. tostring(id) .. '" stored its first argument. Form setters are called set(info, value): write set = function(_, value)')
						end
					end
				end
			end
			defs[id] = copy
		end
		local widgets, height = LibAT.UI.BuildWidgets(frame, defs, math.min(self:GetContentWidth(), 460))
		form = { frame = frame, widgets = widgets, height = height or 1 }
		self.formFrames[key] = form
	else
		LibAT.UI.RefreshWidgets(form.widgets)
	end
	form.frame:SetHeight(math.max(form.height, 1))
	form.frame:Show()
	return form.height
end

---Custom steps: build(frame, ctx). Built once when step.cache is set, otherwise rebuilt each visit.
---@return number height
function Hub:RenderCustom(reg, step, ctx)
	local key = reg.id .. '.' .. step.id
	local content = self.window.RightPanel.Content
	local frame = self.customFrames[key]
	local width = self:GetContentWidth()
	if frame and step.cache then
		frame:SetWidth(width)
		frame:Show()
		ctx.frame = frame
		if step.onShow then
			SafeCall(key .. ' onShow', step.onShow, frame, ctx)
		end
	else
		if frame then
			frame:Hide()
		end
		frame = CreateFrame('Frame', nil, content)
		frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
		frame:SetWidth(width)
		frame:SetHeight(1)
		self.customFrames[key] = frame
		ctx.frame = frame
		frame:Show()
		SafeCall(key .. ' build', step.build, frame, ctx)
	end
	local height = frame:GetHeight() or 1
	if type(frame.totalHeight) == 'number' and frame.totalHeight > height then
		height = frame.totalHeight
	end
	if type(ctx.height) == 'number' and ctx.height > height then
		height = ctx.height
	end
	height = math.max(height, 1)
	frame:SetHeight(height)
	return height
end

---Text for the value a step is set to, for the summary
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return string|nil
function Hub:DescribeValue(reg, step)
	if step.kind == 'look' or step.kind == 'choice' then
		local _, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
		for _, option in ipairs(Setup:GetOptions(step)) do
			if option.value == current then
				local text = option.title
				if option.variants and step.getVariant then
					local _, variant = SafeCall(reg.id .. '.' .. step.id .. ' getVariant', step.getVariant, option.value)
					for _, v in ipairs(option.variants) do
						if v.value == variant then
							text = text .. ' (' .. v.text .. ')'
						end
					end
				end
				return text
			end
		end
		return current ~= nil and tostring(current) or 'Not set'
	elseif step.kind == 'toggles' then
		local items = Setup:GetToggleItems(step)
		local on = 0
		for _, item in ipairs(items) do
			local _, value = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get, item.key)
			if item.core or value then
				on = on + 1
			end
		end
		return on .. ' of ' .. #items .. ' on'
	elseif step.kind == 'import' then
		local choice = self.importChoice[reg.id .. '.' .. step.id]
		for _, source in ipairs(step.sources or {}) do
			if source.id == choice then
				return 'From ' .. source.title
			end
		end
		return 'Nothing'
	end
	return nil
end

---Summary: every choice with a Change link, and the changes that need a reload
---@param regs LibAT.SetupRegistration[]
---@param final boolean The last page of the run (shows the reload list and finish text)
---@return number height
function Hub:RenderSummary(regs, final)
	local content = self.window.RightPanel.Content
	if final then
		local reloadCount = Setup:GetStagedCount()
		self:SetHeader(
			'All done',
			reloadCount > 0 and (reloadCount .. ' ' .. Plural(reloadCount, 'change is', 'changes are') .. ' ready. Your screen reloads once to apply your choices.')
				or 'Your choices are ready. You can change any of them later.',
			'',
			false
		)
	end
	local frame = self.summaryFrame
	if not frame then
		frame = CreateFrame('Frame', nil, content)
		frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
		frame:SetPoint('TOPRIGHT', content, 'TOPRIGHT', 0, 0)
		frame.rows = {}
		frame.boxes = {}
		frame.icons = {}
		-- Pictures sit on a layer above the framed boxes
		frame.top = CreateFrame('Frame', nil, frame)
		frame.top:SetAllPoints(frame)
		frame.top:SetFrameLevel(frame:GetFrameLevel() + 5)
		self.summaryFrame = frame
	end
	local owned = self.skin.owned
	local colors = owned and self.skin.colors or { text = { 1, 1, 1 }, secondary = { 0.8, 0.8, 0.8 } }
	local width = self:GetContentWidth()
	local used, boxes, icons, tiles = 0, 0, 0, 0
	local y = 0

	local function Row(indent, size, top)
		used = used + 1
		local row = frame.rows[used]
		if not row then
			row = CreateFrame('Frame', nil, frame)
			row:SetHeight(20)
			row.label = CreateSkinFontString(row, 'OVERLAY', self.skin, 'GameFontHighlight')
			row.label:SetJustifyH('LEFT')
			row.value = CreateSkinFontString(row, 'OVERLAY', self.skin, 'GameFontHighlight')
			row.value:SetJustifyH('LEFT')
			row.link = CreateTextButton(row, nil, self.skin)
			frame.rows[used] = row
		end
		if owned then
			self.skin:SetFont(row.label, size or 13)
			self.skin:SetFont(row.value, 13)
		else
			row.label:SetFontObject(size and 'GameFontNormal' or 'GameFontHighlight')
		end
		row.label:ClearAllPoints()
		row.label:SetPoint('LEFT', row, 'LEFT', indent or 0, 0)
		row.label:SetWidth(0)
		row.label:SetWordWrap(false)
		row.label:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
		row.value:ClearAllPoints()
		row.value:SetPoint('LEFT', row, 'LEFT', 180, 0)
		row.value:SetPoint('RIGHT', row, 'RIGHT', -70, 0)
		row.value:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
		row.value:SetText('')
		row.link:Hide()
		row.link:ClearAllPoints()
		row.link:SetPoint('RIGHT', row, 'RIGHT', -10, 0)
		row.link:ApplyColor()
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -(top or y))
		row:SetPoint('RIGHT', frame, 'RIGHT', 0, 0)
		row:Show()
		return row
	end
	---A framed box behind rows already placed between top and bottom
	local function Box(top, bottom)
		boxes = boxes + 1
		local box = frame.boxes[boxes]
		if not box then
			box = owned and Kit:CreatePanel(frame, { elevation = 1, materialAlpha = 0.04, shadow = false }) or CreateFrame('Frame', nil, frame)
			box:SetFrameLevel(frame:GetFrameLevel())
			frame.boxes[boxes] = box
		end
		box:ClearAllPoints()
		box:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -top)
		box:SetPoint('RIGHT', frame, 'RIGHT', 0, 0)
		box:SetHeight(bottom - top)
		box:Show()
		return box
	end
	local function Icon(texture, x, top, size)
		icons = icons + 1
		local icon = frame.icons[icons]
		if not icon then
			icon = frame.top:CreateTexture(nil, 'OVERLAY')
			frame.icons[icons] = icon
		end
		icon:SetTexture(texture)
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint('TOPLEFT', frame, 'TOPLEFT', x, -top)
		icon:Show()
		return icon
	end

	for _, reg in ipairs(regs) do
		local header = Row(0, 15)
		header.label:SetText(IconMarkup(reg) .. reg.name)
		local rec = Setup:GetRecord(reg)
		if rec and rec.status == 'skipped' then
			header.value:SetText('Skipped')
		end
		if reg.config.optionsCommand then
			header.link:SetLabel('More settings')
			header.link:SetScript('OnClick', function()
				Setup:RunAction(reg, nil)
			end)
			header.link:Show()
		end
		y = y + 26

		-- Only real choices: a step's own summary() decides its line (nil leaves it out); otherwise
		-- the picked value, and steps with nothing to show are left out
		local boxTop = y
		local any = false
		for i, entry in ipairs(self.run.entries) do
			if entry.reg == reg and entry.step.kind ~= 'summary' then
				local value
				if type(entry.step.summary) == 'function' then
					local ok, text = SafeCall(reg.id .. '.' .. entry.step.id .. ' summary', entry.step.summary)
					value = ok and text or nil
				else
					value = self:DescribeValue(reg, entry.step)
				end
				if value and value ~= '' and value ~= 'Not set' then
					if not any then
						y = y + 6
					end
					any = true
					local stepRow = Row(14)
					stepRow.label:SetText(entry.step.name or entry.step.title)
					stepRow.value:SetText(value)
					stepRow.link:SetLabel('Change')
					stepRow.link:SetScript('OnClick', function()
						Hub:ShowEntry(i)
					end)
					stepRow.link:Show()
					y = y + 22
				end
			end
		end
		if any then
			y = y + 6
			Box(boxTop, y)
			y = y + 12
		end

		local finish = final and reg.config.finish
		if type(finish) == 'table' then
			-- Where the settings are: a framed note with the addon's picture
			if finish.note then
				local noteTop = y
				local size = 40
				local indent = 14
				if reg.config.icon then
					Icon(reg.config.icon, 12, noteTop + 10, size)
					indent = 12 + size + 12
				end
				local noteRow = Row(indent, 13, noteTop + 10)
				noteRow.label:SetWordWrap(true)
				noteRow.label:SetWidth(width - indent - 16)
				noteRow.label:SetText(finish.note)
				noteRow:SetHeight(math.max(noteRow.label:GetStringHeight() or 20, size))
				y = noteTop + 10 + math.max(noteRow.label:GetStringHeight() or 20, size) + 10
				Box(noteTop, y)
				y = y + 16
			end
			-- Pages worth a look later, as tiles
			if finish.links and #finish.links > 0 then
				local title = Row(0, 14)
				title.label:SetText(finish.linksTitle or 'When you want more')
				y = y + 24
				tiles = tiles + 1
				local grid = self:GetGrid('tiles' .. tiles)
				local list = {}
				for index, link in ipairs(finish.links) do
					list[#list + 1] = { value = index, title = link.title, caption = link.caption }
				end
				grid.opts.onClick = function(_, index)
					local link = finish.links[index]
					if link then
						SafeCall(reg.id .. ' finish link', link.onClick)
					end
				end
				grid.opts.onVariant = nil
				grid.opts.onCheck = nil
				grid:SetCards(list)
				for _, card in ipairs(grid.cards) do
					card:SetState(false, true, nil)
				end
				grid:ClearAllPoints()
				grid:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -y)
				grid:Show()
				y = y + grid:Layout(width) + 16
			end
		end
		y = y + 8
	end

	if final or #Setup.staged > 0 then
		local boxTop = y
		y = y + 10
		local header = Row(14, 14)
		local count = Setup:GetStagedCount()
		if count > 0 then
			header.label:SetText(count .. ' ' .. Plural(count, 'change needs', 'changes need') .. ' a reload')
			if owned then
				local r, g, b = LibAT.UI.GetAccentColor()
				header.label:SetTextColor(r, g, b)
			else
				header.label:SetTextColor(1, 0.82, 0)
			end
			y = y + 22
			for _, staged in ipairs(Setup.staged) do
				local row = Row(28)
				row.label:SetText('- ' .. staged.label)
				y = y + 20
			end
		else
			header.label:SetText('Nothing needs a reload. Your choices are already on screen.')
			header.label:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
			y = y + 22
		end
		y = y + 8
		Box(boxTop, y)
	end

	for i = used + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	for i = boxes + 1, #frame.boxes do
		frame.boxes[i]:Hide()
	end
	for i = icons + 1, #frame.icons do
		frame.icons[i]:Hide()
	end
	local height = math.max(y, 1)
	frame:SetHeight(height)
	frame:Show()
	return height
end

---Start page: one card per addon
---@return number height
function Hub:RenderStart()
	local regs = self.startRegs
	if self.startAllDone then
		self:SetHeader('Everything is set up', 'Check an addon to go through its setup again.', '', false)
	else
		self:SetHeader("Let's set up your addons", 'Pick the addons to set up now. You can come back any time with /setup.', '', false)
	end
	local grid = self:GetGrid('start')
	local list = {}
	for _, reg in ipairs(regs) do
		local steps = Setup:GetDueSteps(reg)
		if #steps == 0 then
			steps = Setup:GetVisibleSteps(reg)
		end
		local minutes = math.max(1, math.ceil(#steps * 20 / 60))
		local rec = Setup:GetRecord(reg)
		local muted = rec and rec.muted
		list[#list + 1] = {
			value = reg.id,
			title = IconMarkup(reg) .. reg.name,
			caption = reg.config.summary or (#steps .. ' short ' .. Plural(#steps, 'step', 'steps') .. '.'),
			tag = 'About ' .. minutes .. ' ' .. Plural(minutes, 'minute', 'minutes'),
			checkable = true,
			checked = self.startChecks[reg.id] and true or false,
			tooltip = (reg.config.summary and (reg.config.summary .. '\n\n') or '') .. 'Checked addons are set up when you press Set up checked addons.',
			link = not self.startAllDone and {
				text = muted and 'Show again' or "Don't show again",
				onClick = function()
					Setup:SetMuted(reg.id, not muted)
					Hub.startChecks[reg.id] = muted and true or false
					Hub:RenderCurrent()
				end,
			} or nil,
		}
	end
	grid.opts.onCheck = function(_, id, checked)
		Hub.startChecks[id] = checked
		Hub:UpdateFooter()
	end
	grid.opts.onClick = nil
	grid.opts.onVariant = nil
	grid:SetCards(list)
	for _, card in ipairs(grid.cards) do
		local reg = Setup:GetRegistration(card.data.value)
		local status = reg and Setup:GetStatus(reg.id)
		local label
		if status == 'done' then
			label = 'Done'
		elseif status == 'skipped' then
			label = 'Skipped'
		end
		card:SetState(false, true, label)
	end
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', self.window.RightPanel.Content, 'TOPLEFT', 0, 0)
	grid:Show()
	return grid:Layout(self:GetContentWidth())
end

---What's new page: the newest entry of every addon that has one
---@return number height
function Hub:RenderWhatsNew()
	self:SetHeader("What's new", 'The latest changes in your addons.', '', false)
	local content = self.window.RightPanel.Content
	local frame = self.whatsNewFrame
	if not frame then
		frame = CreateFrame('Frame', nil, content)
		self.whatsNewFrame = frame
	end
	local width = self:GetContentWidth()
	frame:ClearAllPoints()
	frame:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, 0)
	frame:SetWidth(width)
	frame:Show()
	local ok, height = pcall(Setup.WhatsNew.Draw, Setup.WhatsNew, frame, width, function()
		Hub:RenderCurrent()
	end)
	if not ok then
		Log('error', "What's new could not be drawn: " .. tostring(height))
		height = 20
	end
	frame:SetHeight(math.max(height, 1))
	return height
end

----------------------------------------------------------------------------------------------------
-- Left list
----------------------------------------------------------------------------------------------------

-- Vertical offsets of the route dots within a 26px rail row, above and below its node
local ROUTE_DOTS = { 11, 7, 3, -3, -7, -11 }

---@param index number
---@return Button
function Hub:GetListRow(index)
	local left = self.window.LeftPanel
	local row = left.rows[index]
	if row then
		return row
	end
	row = CreateFrame('Button', nil, left.List)
	row.highlight = row:CreateTexture(nil, 'HIGHLIGHT')
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.06)
	row.current = row:CreateTexture(nil, 'ARTWORK')
	row.current:SetSize(18, 18)
	row.current:SetTexture(self.skin:Texture('chapter-marker'))
	row.fill = row:CreateTexture(nil, 'BACKGROUND')
	row.fill:SetAllPoints()
	row.text = CreateSkinFontString(row, 'OVERLAY', self.skin, 'GameFontHighlightSmall')
	self.skin:SetFont(row.text, 12)
	row.text:SetJustifyH('LEFT')
	row.text:SetWordWrap(false)
	row.status = CreateSkinFontString(row, 'OVERLAY', self.skin, 'GameFontHighlightSmall')
	self.skin:SetFont(row.status, 11)
	row.check = row:CreateTexture(nil, 'OVERLAY')
	row.check:SetSize(18, 18)
	row.check:SetTexture(self.skin:Texture('chapter-check'))
	row.chevron = row:CreateTexture(nil, 'OVERLAY')
	row.chevron:SetSize(12, 12)
	row.chevron:SetTexture(self.skin:Texture('chevron'))
	row.chevron:SetPoint('LEFT', row, 'LEFT', 3, 0)
	row.status:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
	row.status:SetJustifyH('RIGHT')
	row:SetScript('OnClick', function(self)
		if self.onClick then
			self.onClick()
		end
	end)
	left.rows[index] = row
	return row
end

----------------------------------------------------------------------------------------------------
-- Chapter rail: the step list as a route of chapters, dressed by the window kit
----------------------------------------------------------------------------------------------------

-- Chapters sit a level below their addon: shorter rows, smaller text
local RAIL_HEADER_HEIGHT = 30
local RAIL_CHAPTER_HEIGHT = 30
local RAIL_PAGE_HEIGHT = 25 -- pages inside an open chapter
local RAIL_PAGE_INDENT = 12
local RAIL_AXIS = 20 -- x of the route line within a row
local RAIL_TEXT = 40 -- x where chapter names start
-- Dots on the path ahead, measured from the node's center, in each half of a row
-- Dots on the path ahead: up to this many, every RAIL_DOT_STEP px from the node to the row's edge
local RAIL_DOTS = { 1, 2, 3 }
local RAIL_DOT_STEP = 4
local WHITE = 'Interface\\Buttons\\WHITE8X8'

---@param index number
---@return Button
function Hub:GetChapterRow(index)
	local left = self.window.LeftPanel
	left.chapterRows = left.chapterRows or {}
	local row = left.chapterRows[index]
	if row then
		return row
	end
	row = CreateFrame('Button', nil, left.List)
	row.highlight = row:CreateTexture(nil, 'HIGHLIGHT')
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.04)
	row.lineTop = row:CreateTexture(nil, 'ARTWORK', nil, 0)
	row.lineTop:SetTexture(WHITE)
	row.lineTop:SetWidth(2)
	row.lineBottom = row:CreateTexture(nil, 'ARTWORK', nil, 0)
	row.lineBottom:SetTexture(WHITE)
	row.lineBottom:SetWidth(2)
	row.dots = {}
	for i = 1, #RAIL_DOTS * 2 do
		local dot = row:CreateTexture(nil, 'ARTWORK', nil, 0)
		dot:SetTexture(WHITE)
		dot:SetSize(2, 2)
		row.dots[i] = dot
	end
	row.node = row:CreateTexture(nil, 'ARTWORK', nil, 5)
	row.text = row:CreateFontString(nil, 'OVERLAY')
	row.text:SetJustifyH('LEFT')
	row.text:SetWordWrap(false)
	row.check = row:CreateTexture(nil, 'OVERLAY')
	row.check:SetSize(10, 10)
	row.chevron = row:CreateTexture(nil, 'OVERLAY')
	row.chevron:SetSize(12, 12)
	row.status = row:CreateTexture(nil, 'OVERLAY')
	row.status:SetSize(12, 12)
	row.divider = row:CreateTexture(nil, 'ARTWORK')
	row.divider:SetTexture(WHITE)
	row.divider:SetHeight(1)
	-- + / - for a chapter with pages inside it
	row.toggle = CreateFrame('Button', nil, row)
	row.toggle:SetSize(18, 18)
	row.toggle:SetPoint('RIGHT', row, 'RIGHT', -2, 0)
	row.toggle.across = row.toggle:CreateTexture(nil, 'OVERLAY')
	row.toggle.across:SetTexture(WHITE)
	row.toggle.across:SetSize(8, 2)
	row.toggle.across:SetPoint('CENTER')
	row.toggle.down = row.toggle:CreateTexture(nil, 'OVERLAY')
	row.toggle.down:SetTexture(WHITE)
	row.toggle.down:SetSize(2, 8)
	row.toggle.down:SetPoint('CENTER')
	row.toggle:SetScript('OnClick', function(self)
		if self.onClick then
			self.onClick()
		end
	end)
	row:SetScript('OnClick', function(self)
		if self.onClick then
			self.onClick()
		end
	end)
	left.chapterRows[index] = row
	return row
end

local function ResetRow(row)
	for _, key in ipairs({ 'lineTop', 'lineBottom', 'node', 'check', 'chevron', 'status', 'divider', 'toggle' }) do
		row[key]:Hide()
	end
	for _, dot in ipairs(row.dots) do
		dot:Hide()
	end
end

---A line from the top edge or the bottom edge of a row to its node.
local function ShowLine(tex, row, fromTop, color)
	tex:SetVertexColor(color[1], color[2], color[3], 0.9)
	tex:ClearAllPoints()
	if fromTop then
		tex:SetPoint('TOP', row, 'TOPLEFT', RAIL_AXIS, 0)
		tex:SetPoint('BOTTOM', row, 'LEFT', RAIL_AXIS, 0)
	else
		tex:SetPoint('TOP', row, 'LEFT', RAIL_AXIS, 0)
		tex:SetPoint('BOTTOM', row, 'BOTTOMLEFT', RAIL_AXIS, 0)
	end
	tex:Show()
end

local function ShowDots(row, fromTop, color)
	-- Spaced evenly out to the row's edge, so the dotted path runs on into the next row
	local half = (row:GetHeight() or 24) / 2
	for i in ipairs(RAIL_DOTS) do
		local dot = row.dots[fromTop and i or (#RAIL_DOTS + i)]
		-- The upper half starts 2px further in, so the gap across two rows matches the step
		local offset = half - (i - 1) * RAIL_DOT_STEP - (fromTop and 3 or 1)
		if offset > 6 then
			dot:SetVertexColor(color[1], color[2], color[3], 0.8)
			dot:ClearAllPoints()
			dot:SetPoint('CENTER', row, 'LEFT', RAIL_AXIS, fromTop and offset or -offset)
			dot:Show()
		else
			dot:Hide()
		end
	end
end

---A check mark tinted to the kit's tick color
local function ShowCheck(tex, kit, color)
	LibAT.UI.Kit:SetAsset(tex, kit, 'check')
	tex:SetVertexColor(color[1], color[2], color[3], 1)
end

---Chapters of one addon in this run: neighbouring steps that share a chapter become one entry.
---@return {name: string, first: number, last: number}[]
function Hub:GetChapters(reg)
	local chapters = {}
	for i, entry in ipairs(self.run.entries) do
		if entry.reg == reg then
			local name = reg:GetChapter(entry.step)
			local last = chapters[#chapters]
			if last and last.name == name and last.last == i - 1 then
				last.last = i
			else
				chapters[#chapters + 1] = { name = name, first = i, last = i }
			end
		end
	end
	return chapters
end

---A chapter is open while one of its pages is showing, unless the player opened or closed it
---@param key string
---@param showing boolean
---@return boolean
function Hub:IsChapterOpen(key, showing)
	local choice = self.chapterOpen and self.chapterOpen[key]
	if choice == nil then
		return showing
	end
	return choice
end

---The rail's stops: each chapter, and the pages of every open chapter below it
---@return {name: string, first: number, last: number, page?: boolean, key?: string, open?: boolean}[]
function Hub:GetRailItems(reg)
	local items = {}
	for _, chapter in ipairs(self:GetChapters(reg)) do
		local hasPages = chapter.last > chapter.first
		local key = reg.id .. ':' .. chapter.name
		local showing = self.page == 'step' and self.index >= chapter.first and self.index <= chapter.last
		local open = hasPages and self:IsChapterOpen(key, showing)
		items[#items + 1] = { name = chapter.name, first = chapter.first, last = open and chapter.first or chapter.last, key = hasPages and key or nil, open = open }
		if open then
			for i = chapter.first + 1, chapter.last do
				local step = self.run.entries[i].step
				items[#items + 1] = { name = step.name or step.title or step.id, first = i, last = i, page = true }
			end
		end
	end
	return items
end

---Addons the left list shows: an addon with no page for this character (no Enchanting, no totems,
---nothing to import) is left out unless it is part of the current run
---@return LibAT.SetupRegistration[]
function Hub:GetRailRegistrations()
	local list = {}
	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		if self:IsInRun(reg) or #Setup:GetVisibleSteps(reg) > 0 then
			list[#list + 1] = reg
		end
	end
	return list
end

function Hub:RefreshChapterRail(width)
	local left = self.window.LeftPanel
	local kit = self.skin
	local Kit = LibAT.UI.Kit
	local colors = kit.colors
	local r, g, b = LibAT.UI.GetAccentColor()
	local behind = colors.path or { r, g, b }
	local ahead = colors.pathAhead or colors.muted
	local tick = colors.tick or colors.done
	local used, y = 0, 0

	local function NextRow(height)
		used = used + 1
		local row = self:GetChapterRow(used)
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', left.List, 'TOPLEFT', 0, -y)
		row:SetSize(width, height)
		ResetRow(row)
		row.text:ClearAllPoints()
		row:Show()
		y = y + height
		return row
	end

	local registrations = self:GetRailRegistrations()
	for regIndex, reg in ipairs(registrations) do
		local inRun = self:IsInRun(reg)
		local header = NextRow(RAIL_HEADER_HEIGHT)
		kit:SetFont(header.text, 15)
		header.text:SetPoint('LEFT', header, 'LEFT', 6, 0)
		header.text:SetPoint('RIGHT', header, 'RIGHT', -40, 0)
		header.text:SetText(reg.name)
		local color = inRun and colors.text or colors.secondary
		header.text:SetTextColor(color[1], color[2], color[3])
		Kit:SetAsset(header.chevron, kit, 'triangle')
		header.chevron:ClearAllPoints()
		header.chevron:SetPoint('RIGHT', header, 'RIGHT', -6, 0)
		header.chevron:SetRotation(inRun and math.rad(-90) or 0)
		header.chevron:SetVertexColor(colors.secondary[1], colors.secondary[2], colors.secondary[3], 0.9)
		if Setup:GetStatus(reg.id) == 'done' then
			ShowCheck(header.status, kit, tick)
			header.status:ClearAllPoints()
			header.status:SetPoint('RIGHT', header.chevron, 'LEFT', -6, 0)
		end
		header.onClick = function()
			Hub:GoToAddon(reg)
		end

		if inRun then
			local chapters = self:GetRailItems(reg)
			for c, chapter in ipairs(chapters) do
				local page = chapter.page
				local row = NextRow(page and RAIL_PAGE_HEIGHT or RAIL_CHAPTER_HEIGHT)
				local isCurrent = self.page == 'step' and self.index >= chapter.first and self.index <= chapter.last
				local seen = self.page == 'summary' or (self.page == 'step' and chapter.last < self.index)
				local previous = chapters[c - 1]
				local previousCurrent = previous and self.page == 'step' and self.index >= previous.first and self.index <= previous.last
				local isLast = c == #chapters
				-- Pages draw a size smaller than their chapter
				local nodeScale = page and 0.75 or 1

				kit:SetFont(row.text, page and 12 or 14)
				local textX = page and (RAIL_TEXT + RAIL_PAGE_INDENT) or RAIL_TEXT
				row.text:SetPoint('LEFT', row, 'LEFT', textX, 0)
				row.text:SetPoint('RIGHT', row, 'RIGHT', chapter.key and -22 or -4, 0)
				row.text:SetText(chapter.name)
				local textWidth = LibAT.UI.MeasureText(row.text, 7)
				if chapter.key then
					local toggle = row.toggle
					local tone = colors.secondary
					toggle.across:SetVertexColor(tone[1], tone[2], tone[3], 1)
					toggle.down:SetVertexColor(tone[1], tone[2], tone[3], 1)
					toggle.down:SetShown(not chapter.open)
					local key, open = chapter.key, chapter.open
					toggle.onClick = function()
						Hub.chapterOpen = Hub.chapterOpen or {}
						Hub.chapterOpen[key] = not open
						Hub:RefreshList()
					end
					toggle:Show()
				end

				-- The path behind is solid in the path color; ahead it is solid to the next stop, then dotted
				if seen then
					ShowLine(row.lineTop, row, true, behind)
					if not isLast then
						ShowLine(row.lineBottom, row, false, behind)
					end
				elseif isCurrent then
					ShowLine(row.lineTop, row, true, behind)
					if not isLast then
						ShowLine(row.lineBottom, row, false, ahead)
					end
				else
					if previousCurrent then
						ShowLine(row.lineTop, row, true, ahead)
					else
						ShowDots(row, true, ahead)
					end
					if not isLast then
						ShowDots(row, false, ahead)
					end
				end

				row.node:ClearAllPoints()
				row.node:SetPoint('CENTER', row, 'LEFT', RAIL_AXIS, 0)
				row.node:SetVertexColor(1, 1, 1, 1)
				if isCurrent then
					if Kit:SetAsset(row.node, kit, 'marker') then
						row.node:SetSize(16 * nodeScale, 16 * nodeScale)
					else
						Kit:SetAsset(row.node, kit, 'activeMarker')
						row.node:SetSize(9 * nodeScale, 9 * nodeScale)
						row.node:SetVertexColor(r, g, b, 1)
					end
					row.text:SetTextColor(1, 1, 1)
				else
					if Kit:SetAsset(row.node, kit, seen and 'node-done' or 'node-upcoming') then
						local size = (seen and 11 or 12) * nodeScale
						row.node:SetSize(size, size)
					else
						local tone = seen and colors.secondary or colors.muted
						Kit:SetAsset(row.node, kit, 'activeMarker')
						row.node:SetSize(7 * nodeScale, 7 * nodeScale)
						row.node:SetVertexColor(tone[1], tone[2], tone[3], 1)
					end
					local textColor = seen and colors.text or colors.secondary
					row.text:SetTextColor(textColor[1], textColor[2], textColor[3])
					if seen then
						ShowCheck(row.check, kit, tick)
						row.check:ClearAllPoints()
						row.check:SetPoint('LEFT', row, 'LEFT', textX + textWidth + 6, 0)
					end
				end
				row.node:Show()
				row.onClick = function()
					Hub:ShowEntry(chapter.first)
				end
			end
			y = y + 6
		end

		if regIndex < #registrations then
			local last = left.chapterRows[used]
			last.divider:ClearAllPoints()
			last.divider:SetPoint('BOTTOMLEFT', last, 'BOTTOMLEFT', 0, inRun and -6 or 0)
			last.divider:SetPoint('BOTTOMRIGHT', last, 'BOTTOMRIGHT', 0, inRun and -6 or 0)
			last.divider:SetVertexColor(colors.trim[1], colors.trim[2], colors.trim[3], 0.4)
			last.divider:Show()
		end
	end

	for i = used + 1, #(left.chapterRows or {}) do
		left.chapterRows[i]:Hide()
	end
	left.List:SetSize(width, math.max(y, 1))
end

function Hub:RefreshList()
	if not self.window then
		return
	end
	local left = self.window.LeftPanel
	local owned = self.skin.owned
	local width = self:GetLeftWidth() - (owned and 36 or 20)
	local r, g, b = LibAT.UI.GetAccentColor()
	local used = 0
	local y = 0
	local currentEntry = self.page == 'step' and self.run.entries[self.index]
	local check = owned and '' or LibAT.UI.AtlasMarkup('common-icon-checkmark', 12)

	if owned then
		self:RefreshChapterRail(width)
	else
		for _, reg in ipairs(self:GetRailRegistrations()) do
			used = used + 1
			local row = self:GetListRow(used)
			row:ClearAllPoints()
			row:SetPoint('TOPLEFT', left.List, 'TOPLEFT', 0, -y)
			row:SetSize(width, owned and 30 or ADDON_ROW_HEIGHT)
			row.text:ClearAllPoints()
			row.text:SetPoint('LEFT', row, 'LEFT', owned and 20 or 6, 0)
			row.text:SetPoint('RIGHT', row.status, 'LEFT', -4, 0)
			if owned then
				self.skin:SetFont(row.text, 14)
			else
				row.text:SetFontObject('GameFontNormal')
			end
			row.text:SetText(IconMarkup(reg) .. reg.name)
			local inRun = self:IsInRun(reg)
			if owned then
				local color = inRun and self.skin.colors.text or self.skin.colors.dim
				row.text:SetTextColor(color[1], color[2], color[3])
			else
				row.text:SetTextColor(1, inRun and 0.82 or 0.7, inRun and 0 or 0.4)
			end
			local status = Setup:GetStatus(reg.id)
			if status == 'done' then
				row.status:SetText(check ~= '' and check or '|cff55cc55Done|r')
			elseif status == 'skipped' then
				row.status:SetText('|cff888888Skipped|r')
			else
				row.status:SetText('')
			end
			row.current:Hide()
			if owned then
				row.check:Hide()
				row.chevron:SetRotation(inRun and math.rad(90) or 0)
				row.chevron:SetVertexColor(self.skin.colors.secondary[1], self.skin.colors.secondary[2], self.skin.colors.secondary[3], 0.8)
				row.chevron:Show()
				row.routeLine:Hide()
				row.banner:Hide()
				row.node:Hide()
				for _, dot in ipairs(row.routeDots) do
					dot:Hide()
				end
			end
			row.fill:SetColorTexture(0, 0, 0, 0)
			row.onClick = function()
				Hub:GoToAddon(reg)
			end
			row:Show()
			y = y + (owned and 30 or ADDON_ROW_HEIGHT)

			if inRun then
				for i, entry in ipairs(self.run.entries) do
					if entry.reg == reg then
						used = used + 1
						local stepRow = self:GetListRow(used)
						stepRow:ClearAllPoints()
						stepRow:SetPoint('TOPLEFT', left.List, 'TOPLEFT', 0, -y)
						stepRow:SetSize(width, owned and 26 or STEP_ROW_HEIGHT)
						local indent = owned and (entry.step._parentId and 42 or 32) or (entry.step._parentId and 30 or 18)
						stepRow.text:ClearAllPoints()
						stepRow.text:SetPoint('LEFT', stepRow, 'LEFT', indent, 0)
						stepRow.text:SetPoint('RIGHT', stepRow, 'RIGHT', -4, 0)
						if owned then
							self.skin:SetFont(stepRow.text, 12)
						else
							stepRow.text:SetFontObject('GameFontHighlightSmall')
						end
						stepRow.status:SetText('')
						if stepRow.banner then
							stepRow.banner:Hide()
						end
						local isCurrent = entry == currentEntry
						local seen = self.page == 'summary' or (self.page == 'step' and i < self.index)
						if isCurrent then
							stepRow.text:SetText(entry.step.name or entry.step.title)
							stepRow.text:SetTextColor(owned and r or 1, owned and g or 1, owned and b or 1)
							if owned and self.skin.route then
								stepRow.current:ClearAllPoints()
								stepRow.current:SetPoint('CENTER', stepRow, 'LEFT', 21, 0)
								stepRow.current:SetVertexColor(1, 1, 1, 1)
							elseif owned then
								stepRow.current:ClearAllPoints()
								stepRow.current:SetPoint('LEFT', stepRow, 'LEFT', 12, 0)
								stepRow.current:SetVertexColor(r, g, b, 1)
							else
								stepRow.current:SetColorTexture(r, g, b, 1)
							end
							stepRow.current:Show()
							if owned and self.skin.route then
								stepRow.fill:SetColorTexture(0, 0, 0, 0)
								stepRow.text:SetTextColor(1, 1, 1)
								stepRow.banner:ClearAllPoints()
								stepRow.banner:SetPoint('LEFT', stepRow, 'LEFT', 6, 0)
								stepRow.banner:SetSize(math.min(indent + LibAT.UI.MeasureText(stepRow.text, 6) + 26, width), 26)
								stepRow.banner:SetVertexColor(r, g, b, 0.9)
								stepRow.banner:Show()
							else
								stepRow.fill:SetColorTexture(r, g, b, owned and 0.08 or 0.12)
							end
						else
							stepRow.text:SetText(entry.step.name or entry.step.title)
							if owned then
								local color = seen and self.skin.colors.secondary or self.skin.colors.dim
								stepRow.text:SetTextColor(color[1], color[2], color[3])
							else
								local shade = seen and 0.85 or 0.6
								stepRow.text:SetTextColor(shade, shade, shade)
							end
							stepRow.current:Hide()
							stepRow.fill:SetColorTexture(0, 0, 0, 0)
						end
						if owned and self.skin.route then
							-- One continuous route: a node on every step, solid up to the current step, dotted after it
							local nextEntry = self.run.entries[i + 1]
							local isLast = not nextEntry or nextEntry.reg ~= reg
							local brass = self.skin.colors.rim
							stepRow.chevron:Hide()
							stepRow.node:ClearAllPoints()
							stepRow.node:SetPoint('CENTER', stepRow, 'LEFT', 21, 0)
							stepRow.node:SetTexture(self.skin:Texture(seen and 'waypoint' or 'node-ring'))
							stepRow.node:SetShown(not isCurrent)
							stepRow.check:ClearAllPoints()
							stepRow.check:SetSize(13, 13)
							stepRow.check:SetPoint('LEFT', stepRow, 'LEFT', indent + LibAT.UI.MeasureText(stepRow.text, 6) + 5, 0)
							stepRow.check:SetShown(seen and not isCurrent)
							stepRow.routeLine:ClearAllPoints()
							stepRow.routeLine:SetPoint('TOP', stepRow, 'TOPLEFT', 21, 0)
							stepRow.routeLine:SetPoint('BOTTOM', stepRow, (seen and not isLast) and 'BOTTOMLEFT' or 'LEFT', 21, 0)
							stepRow.routeLine:SetVertexColor(brass[1], brass[2], brass[3], 0.75)
							stepRow.routeLine:SetShown(seen or isCurrent)
							for dotIndex, dot in ipairs(stepRow.routeDots) do
								local dotY = ROUTE_DOTS[dotIndex]
								if dotY then
									dot:ClearAllPoints()
									dot:SetPoint('CENTER', stepRow, 'LEFT', 21, dotY)
									dot:SetVertexColor(brass[1], brass[2], brass[3], 0.55)
									dot:SetShown(not seen and ((dotY > 0 and not isCurrent) or (dotY < 0 and not isLast)))
								else
									dot:Hide()
								end
							end
						elseif owned then
							stepRow.chevron:Hide()
							stepRow.node:Hide()
							stepRow.check:ClearAllPoints()
							stepRow.check:SetSize(18, 18)
							stepRow.check:SetPoint('LEFT', stepRow, 'LEFT', 12, 0)
							stepRow.check:SetShown(seen and not isCurrent)
							stepRow.routeLine:Hide()
							for _, dot in ipairs(stepRow.routeDots) do
								dot:Hide()
							end
						end
						stepRow.onClick = function()
							Hub:ShowEntry(i)
						end
						stepRow:Show()
						y = y + (owned and 26 or STEP_ROW_HEIGHT)
					end
				end
				y = y + 4
			end
		end
		for i = used + 1, #left.rows do
			left.rows[i]:Hide()
		end
		left.List:SetSize(width, math.max(y, 1))
	end

	local hasWhatsNew = false
	for _, reg in pairs(Setup.registrations) do
		if #reg.whatsNew > 0 then
			hasWhatsNew = true
		end
	end
	local unseen = #Setup:GetUnseenWhatsNewAddons()
	left.WhatsNew.text:SetText("What's new" .. (unseen > 0 and (' (' .. unseen .. ')') or ''))
	left.WhatsNew:SetShown(hasWhatsNew)
	left.AutoOpen:SetChecked(Setup:GetAutoOpen())
end

---Jump to an addon from the left list
---@param reg LibAT.SetupRegistration
function Hub:GoToAddon(reg)
	if not self:IsInRun(reg) then
		self:AddToRun(reg)
	end
	local first = self:GetAddonRange(reg)
	if first then
		self:ShowEntry(first)
	end
end

----------------------------------------------------------------------------------------------------
-- Footer, progress, combat, accent
----------------------------------------------------------------------------------------------------

function Hub:UpdateFooter()
	local w = self.window
	if not w then
		return
	end
	if self.skin.owned then
		self:UpdateOwnedFooter()
		return
	end
	local right = w.RightPanel
	local staged = Setup:GetStagedCount()
	right.ReloadText:SetText(staged > 0 and (staged .. ' ' .. Plural(staged, 'change needs', 'changes need') .. ' a reload') or '')

	local total = #self.run.entries
	local page = self.page
	w.BackButton:Show()
	w.SkipButton:Show()
	w.RecButton:Show()
	w.NextButton:Show()
	w.NextButton:Enable()
	w.SkipButton:Enable()
	w.RecButton:Enable()
	w.BackButton:Enable()
	right.Progress:Show()

	if page == 'start' then
		w.BackButton:Hide()
		w.SkipButton:Hide()
		w.RecButton:SetText('Use recommended settings for all')
		w.NextButton:SetText('Set up checked addons')
		local any = false
		for _, reg in ipairs(self.startRegs) do
			if self.startChecks[reg.id] then
				any = true
			end
		end
		w.NextButton:SetEnabled(any)
		w.RecButton:SetEnabled(any and not self.startAllDone)
		right.Progress:Hide()
	elseif page == 'step' then
		w.SkipButton:SetText('Skip this addon')
		w.RecButton:SetText('Use recommended for the rest')
		w.NextButton:SetText(self:GetFinishNowLabel() or (self.index >= total and 'Finish' or 'Next'))
		w.BackButton:SetEnabled(self.index > 1 or self.startShown)
		right.Progress:SetMinMaxValues(0, math.max(total, 1))
		right.Progress:SetValue(self.index)
		right.Progress:SetText('Step ' .. self.index .. ' of ' .. total)
		local entry = self.run.entries[self.index]
		local rec = entry and Setup:GetRecord(entry.reg)
		w.SkipButton:SetEnabled(rec ~= nil and rec.status == 'pending')
	elseif page == 'summary' then
		w.RecButton:Hide()
		w.BackButton:SetEnabled(total > 0 or self.startShown)
		if staged > 0 then
			w.SkipButton:SetText('Finish without reloading')
			w.NextButton:SetText('Finish and reload')
		else
			w.SkipButton:Hide()
			w.NextButton:SetText('Finish')
		end
		right.Progress:SetMinMaxValues(0, 1)
		right.Progress:SetValue(1)
		right.Progress:SetText('All steps done')
		if Setup.inCombat then
			w.NextButton:Disable()
			w.SkipButton:Disable()
		end
	elseif page == 'whatsnew' then
		w.SkipButton:Hide()
		w.RecButton:Hide()
		w.BackButton:SetShown(self.returnPage ~= nil)
		w.NextButton:SetText(self.returnPage and 'Back to setup' or 'Close')
		right.Progress:Hide()
	else
		w.SkipButton:Hide()
		w.RecButton:Hide()
		w.BackButton:Hide()
		right.Progress:Hide()
		w.NextButton:SetText('Close')
	end
end

function Hub:UpdateOwnedFooter()
	local w = self.window
	local right = w.RightPanel
	local staged = Setup:GetStagedCount()
	local total = #self.run.entries
	local page = self.page
	local any = false
	if w.SkipMenu then
		w.SkipMenu:Hide()
	end
	w.BackButton:Show()
	w.SkipAheadButton:Show()
	w.NextButton:Show()
	w.RightPanel.Progress:Show()
	w.BackButton:SetEnabled(true)
	w.SkipAheadButton:SetEnabled(true)
	w.NextButton:SetEnabled(true)
	w.SkipAheadButton:SetText('Skip ahead')
	w.SkipAheadButton:SetScript('OnClick', function()
		Hub:ToggleSkipMenu()
	end)
	right.ReloadText:SetText(staged > 0 and (staged .. ' ' .. Plural(staged, 'change needs', 'changes need') .. ' a reload') or '')

	if page == 'start' then
		w.BackButton:Hide()
		for _, reg in ipairs(self.startRegs) do
			if self.startChecks[reg.id] then
				any = true
			end
		end
		w.NextButton:SetText(any and 'Set up checked addons' or 'Check an addon above')
		w.NextButton:SetEnabled(any)
		w.SkipAheadButton:SetShown(any and not self.startAllDone)
		w.RightPanel.Progress:Hide()
		if w.SkipMenu then
			w.SkipMenu.skip:Hide()
			w.SkipMenu.recommended:SetLabel('Use recommended for all - keeps current addon choices')
		end
	elseif page == 'step' then
		w.NextButton:SetText(self:GetFinishNowLabel() or (self.index >= total and 'Finish' or 'Next'))
		w.BackButton:SetEnabled(self.index > 1 or self.startShown)
		w.RightPanel.Progress:SetMinMaxValues(0, math.max(total, 1))
		w.RightPanel.Progress:SetValue(self.index)
		w.RightPanel.Progress:SetText('Step ' .. self.index .. ' of ' .. total)
		if w.SkipMenu then
			w.SkipMenu.skip:Show()
			w.SkipMenu.skip:SetLabel('Skip this addon - keeps current settings')
			w.SkipMenu.recommended:SetLabel('Use recommended - keeps choices already made')
		end
	elseif page == 'summary' then
		w.BackButton:SetEnabled(total > 0 or self.startShown)
		w.NextButton:SetText(staged > 0 and 'Finish and reload' or 'Finish')
		if staged > 0 then
			w.SkipAheadButton:SetText('Finish without reload')
			w.SkipAheadButton:SetScript('OnClick', function()
				Hub:Finish(false)
			end)
		else
			w.SkipAheadButton:Hide()
		end
		w.RightPanel.Progress:SetMinMaxValues(0, 1)
		w.RightPanel.Progress:SetValue(1)
		w.RightPanel.Progress:SetText('All steps done')
		if Setup.inCombat then
			w.NextButton:SetEnabled(false)
			w.SkipAheadButton:SetEnabled(false)
		end
	elseif page == 'whatsnew' then
		w.SkipAheadButton:Hide()
		w.BackButton:SetShown(self.returnPage ~= nil)
		w.NextButton:SetText(self.returnPage and 'Back to setup' or 'Close')
		w.RightPanel.Progress:Hide()
	else
		w.SkipAheadButton:Hide()
		w.BackButton:Hide()
		w.NextButton:SetText('Close')
		w.RightPanel.Progress:Hide()
	end

	for _, button in ipairs(w.ownedButtons or {}) do
		button:ApplyAccent()
	end
end

---Fade the window and block Finish while the player is in combat
---@param inCombat boolean
function Hub:OnCombatChanged(inCombat)
	if not self.window then
		return
	end
	if self.skin.owned then
		self.window:SetAlpha(1)
		self.window.VisualRoot:SetAlpha(inCombat and 0.4 or 1)
	else
		self.window:SetAlpha(inCombat and 0.4 or 1)
	end
	self.window.RightPanel.Combat:SetShown(inCombat and true or false)
	if self.lastCombat ~= inCombat then
		self.lastCombat = inCombat
		self:UpdateFooter()
	end
end

---Repaint everything that uses the accent color
function Hub:ApplyAccent()
	local w = self.window
	if not w then
		return
	end
	local r, g, b = LibAT.UI.GetAccentColor()
	if w.AccentLine then
		w.AccentLine.tex:SetColorTexture(r, g, b, 1)
	end
	w.RightPanel.Progress:SetStatusBarColor(r, g, b)
	if self.skin.owned then
		self.skin:ApplyAccent(w)
	end
	for _, grid in pairs(self.grids) do
		grid:ApplyAccent()
	end
	for _, group in ipairs(self.toggleGroups or {}) do
		if group.grid then
			group.grid:ApplyAccent()
		end
		for _, row in ipairs(group.rows or {}) do
			row:ApplyAccent()
		end
		group.AllOn:ApplyColor()
		group.AllOff:ApplyColor()
	end
	if self.toast then
		self.toast.band:SetColorTexture(r, g, b, 1)
		if self.toast.action.ApplyAccent then
			self.toast.action:ApplyAccent()
		end
	end
	if self:IsShown() then
		self:RefreshList()
	end
end

---Repaint the live window after the host changes trim kits.
function Hub:ApplyKit()
	self.skin = Kit:GetActive()
	local w = self.window
	if not w then
		return
	end
	w._setupKitId = self.skin.id
	if w.ApplyKit then
		w:ApplyKit()
	end
	local colors = self.skin.colors
	w.RightPanel.AddonLabel:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
	w.RightPanel.Title:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	w.RightPanel.Text:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
	w.RightPanel.Message:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	w.RightPanel.ReloadText:SetTextColor(colors.secondary[1], colors.secondary[2], colors.secondary[3])
	w.LeftPanel.WhatsNew.line:SetColorTexture(colors.trim[1], colors.trim[2], colors.trim[3], 0.35)
	if w.SkipMenu then
		w.SkipMenu.bg:SetVertexColor(colors.panel[1], colors.panel[2], colors.panel[3], 0.98)
	end
	self:ApplyAccent()
	-- Picking a look changes the kit; repaint in place so the page keeps its scroll position
	if self:IsShown() then
		self:Render(false)
	end
end

---Refresh the host-provided setup backdrop without repainting unrelated controls.
function Hub:ApplyBackdrop()
	if self.window and self.window.RefreshBackdrop then
		self.window:RefreshBackdrop()
	end
end

function Hub:OnRegistrationChanged()
	if self:IsShown() then
		self:RefreshList()
		if self.page == 'start' then
			self:RenderCurrent()
		end
	end
end

function Hub:OnStatusChanged()
	if self:IsShown() then
		self:RefreshList()
		self:UpdateFooter()
	end
end

function Hub:OnStagedChanged()
	if self:IsShown() then
		self:UpdateFooter()
	end
end

----------------------------------------------------------------------------------------------------
-- Toasts
----------------------------------------------------------------------------------------------------

function Hub:CreateToast()
	local skin = self.skin or Kit:GetActive()
	local toast = CreateFrame('Frame', nil, UIParent)
	toast:SetSize(400, 58)
	toast:SetPoint('TOP', UIParent, 'TOP', 0, -140)
	toast:SetFrameStrata('DIALOG')
	toast:EnableMouse(true)
	toast.bg = toast:CreateTexture(nil, 'BACKGROUND')
	toast.bg:SetAllPoints()
	if skin.owned then
		toast.bg:SetColorTexture(skin.colors.panel[1], skin.colors.panel[2], skin.colors.panel[3], 0.98)
	else
		toast.bg:SetColorTexture(0.05, 0.05, 0.06, 0.94)
	end
	toast.band = toast:CreateTexture(nil, 'ARTWORK')
	toast.band:SetPoint('TOPLEFT')
	toast.band:SetPoint('BOTTOMLEFT')
	toast.band:SetWidth(3)
	toast.title = CreateSkinFontString(toast, 'OVERLAY', skin, 'GameFontNormalSmall')
	if skin.owned then
		skin:SetFont(toast.title, 12)
		toast.title:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])
	end
	toast.title:SetPoint('TOPLEFT', toast, 'TOPLEFT', 12, -8)
	toast.title:SetText('Setup')
	toast.text = CreateSkinFontString(toast, 'OVERLAY', skin, 'GameFontHighlight')
	if skin.owned then
		skin:SetFont(toast.text, 12)
		toast.text:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	end
	toast.text:SetPoint('TOPLEFT', toast.title, 'BOTTOMLEFT', 0, -3)
	toast.text:SetPoint('RIGHT', toast, 'RIGHT', -120, 0)
	toast.text:SetJustifyH('LEFT')
	toast.text:SetWordWrap(true)
	if skin.owned then
		toast.action = skin:CreateButton(toast, 'Open', true)
		toast.action:SetHeight(24)
	else
		toast.action = LibAT.UI.CreateButton(toast, 100, 22, 'Open')
	end
	toast.action:SetPoint('RIGHT', toast, 'RIGHT', -12, -4)
	toast.close = CreateFrame('Button', nil, toast)
	toast.close:SetSize(16, 16)
	toast.close:SetPoint('TOPRIGHT', toast, 'TOPRIGHT', -4, -4)
	toast.close.text = CreateSkinFontString(toast.close, 'OVERLAY', skin, 'GameFontHighlightSmall')
	if skin.owned then
		skin:SetFont(toast.close.text, 12)
		toast.close.text:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	end
	toast.close.text:SetPoint('CENTER')
	toast.close.text:SetText('x')
	toast.close:SetScript('OnClick', function()
		local current = Hub.currentToast
		if current and current.opts and current.opts.onDismiss then
			SafeCall('toast dismiss', current.opts.onDismiss)
		end
		Hub:HideToast()
	end)
	toast:Hide()
	local r, g, b = LibAT.UI.GetAccentColor()
	toast.band:SetColorTexture(r, g, b, 1)
	self.toast = toast
	return toast
end

---Show a short message near the top of the screen. Messages queue up and show one at a time.
---@param text string
---@param actionText? string
---@param actionFn? fun()
---@param opts? {duration?: number, onDismiss?: fun()}
function Hub:ShowToast(text, actionText, actionFn, opts)
	self.toastQueue[#self.toastQueue + 1] = { text = text, actionText = actionText, actionFn = actionFn, opts = opts }
	if not self.toast or not self.toast:IsShown() then
		self:ShowNextToast()
	end
end

function Hub:ShowNextToast()
	local item = table.remove(self.toastQueue, 1)
	if not item then
		return
	end
	local toast = self.toast or self:CreateToast()
	self.currentToast = item
	toast.text:SetText(item.text)
	if item.actionText and item.actionFn then
		toast.action:SetText(item.actionText)
		toast.action:SetScript('OnClick', function()
			Hub:HideToast()
			SafeCall('toast action', item.actionFn)
		end)
		toast.action:Show()
	else
		toast.action:Hide()
	end
	toast:Show()
	self.toastToken = (self.toastToken or 0) + 1
	local token = self.toastToken
	C_Timer.After((item.opts and item.opts.duration) or 15, function()
		if Hub.toastToken == token then
			Hub:HideToast()
		end
	end)
end

function Hub:HideToast()
	self.toastToken = (self.toastToken or 0) + 1
	self.currentToast = nil
	if self.toast then
		self.toast:Hide()
	end
	self:ShowNextToast()
end
