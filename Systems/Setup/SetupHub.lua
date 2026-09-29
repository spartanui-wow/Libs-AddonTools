---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup window: step list on the left, the current step on the right, progress and buttons below
----------------------------------------------------------------------------------------------------

local Setup = LibAT.Setup
local Log = Setup.Log
local SafeCall = Setup.SafeCall

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

---A scroll frame with the thin scroll bar where the client has it, or mouse wheel scrolling
---@param parent Frame
---@return ScrollFrame scroll
---@return Frame child
local function CreateScroll(parent)
	local scroll = CreateFrame('ScrollFrame', nil, parent)
	local child = CreateFrame('Frame', nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	if ScrollUtil and ScrollUtil.InitScrollFrameWithScrollBar then
		scroll.ScrollBar = CreateFrame('EventFrame', nil, scroll, 'MinimalScrollBar')
		scroll.ScrollBar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 6, 0)
		scroll.ScrollBar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 6, 0)
		ScrollUtil.InitScrollFrameWithScrollBar(scroll, scroll.ScrollBar)
	else
		scroll:EnableMouseWheel(true)
		scroll:SetScript('OnMouseWheel', function(self, delta)
			local range = math.max((child:GetHeight() or 0) - (self:GetHeight() or 0), 0)
			self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - delta * 40, 0), range))
		end)
	end
	return scroll, child
end

---A plain text button
---@param parent Frame
---@param fontObject? string
---@return Button
local function CreateTextButton(parent, fontObject)
	local button = CreateFrame('Button', nil, parent)
	button:SetHeight(16)
	button.text = button:CreateFontString(nil, 'OVERLAY', fontObject or 'GameFontHighlightSmall')
	button.text:SetPoint('LEFT', button, 'LEFT', 0, 0)
	button.text:SetJustifyH('LEFT')
	function button:SetLabel(text)
		self.text:SetText(text)
		self:SetWidth(LibAT.UI.MeasureText(self.text, 6) + 4)
	end
	button:SetScript('OnEnter', function(self)
		local r, g, b = LibAT.UI.GetAccentColor()
		self.text:SetTextColor(math.min(r + 0.3, 1), math.min(g + 0.3, 1), math.min(b + 0.3, 1))
	end)
	button:SetScript('OnLeave', function(self)
		self:ApplyColor()
	end)
	function button:ApplyColor()
		local r, g, b = LibAT.UI.GetAccentColor()
		self.text:SetTextColor(math.min(r + 0.15, 1), math.min(g + 0.15, 1), math.min(b + 0.15, 1))
	end
	button:ApplyColor()
	return button
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
	if self.window then
		return self.window
	end

	local w = LibAT.UI.CreateWindow({
		name = 'LibAT_SetupHub',
		title = 'Setup',
		width = 800,
		height = 538,
		minWidth = 800,
		minHeight = 538,
		resizable = true,
	})
	self.window = w
	if LibAT.SetupWizard then
		LibAT.SetupWizard.window = w
	end
	w:HookScript('OnHide', function()
		Hub:OnHidden()
	end)

	-- 2px accent line under the title bar
	w.AccentLine = CreateFrame('Frame', nil, w)
	w.AccentLine:SetPoint('TOPLEFT', w, 'TOPLEFT', 3, -24)
	w.AccentLine:SetPoint('TOPRIGHT', w, 'TOPRIGHT', -3, -24)
	w.AccentLine:SetHeight(2)
	w.AccentLine.tex = w.AccentLine:CreateTexture(nil, 'ARTWORK')
	w.AccentLine.tex:SetAllPoints()

	w.MainContent = LibAT.UI.CreateContentFrame(w, w.AccentLine, -8, 40)
	w.LeftPanel = LibAT.UI.CreateLeftPanel(w.MainContent, LEFT_WIDTH)
	w.RightPanel = LibAT.UI.CreateRightPanel(w.MainContent, w.LeftPanel, 14)

	self:CreateLeftSide(w)
	self:CreateRightSide(w)
	self:CreateFooter(w)

	self:RegisterMessage(LibAT.UI.ACCENT_CHANGED, 'ApplyAccent')
	self:ApplyAccent()
	return w
end

---@param w Frame
function Hub:CreateLeftSide(w)
	local left = w.LeftPanel
	left.Scroll, left.List = CreateScroll(left)
	left.Scroll:SetPoint('TOPLEFT', left, 'TOPLEFT', 4, -6)
	left.Scroll:SetPoint('BOTTOMRIGHT', left, 'BOTTOMRIGHT', -14, 56)
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
	left.WhatsNew.text = left.WhatsNew:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	left.WhatsNew.text:SetPoint('LEFT', left.WhatsNew, 'LEFT', 2, 0)
	left.WhatsNew:SetScript('OnClick', function()
		Hub:OpenWhatsNew()
	end)

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

---@param w Frame
function Hub:CreateRightSide(w)
	local right = w.RightPanel

	right.AddonLabel = right:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	right.AddonLabel:SetPoint('TOPLEFT', right, 'TOPLEFT', 14, -10)
	right.AddonLabel:SetTextColor(0.65, 0.65, 0.65)
	right.AddonLabel:SetJustifyH('LEFT')

	right.Badge = CreateFrame('Frame', nil, right)
	right.Badge:SetSize(90, 16)
	right.Badge:SetPoint('TOPRIGHT', right, 'TOPRIGHT', -14, -12)
	right.Badge.bg = right.Badge:CreateTexture(nil, 'BACKGROUND')
	right.Badge.bg:SetAllPoints()
	right.Badge.bg:SetColorTexture(0.55, 0.42, 0.05, 0.85)
	right.Badge.text = right.Badge:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	right.Badge.text:SetPoint('CENTER')
	right.Badge.text:SetText('Recommended')
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

	right.Title = right:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	right.Title:SetPoint('TOPLEFT', right.AddonLabel, 'BOTTOMLEFT', 0, -3)
	right.Title:SetPoint('RIGHT', right.Badge, 'LEFT', -10, 0)
	right.Title:SetJustifyH('LEFT')

	right.Text = right:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	right.Text:SetPoint('TOPLEFT', right.Title, 'BOTTOMLEFT', 0, -4)
	right.Text:SetPoint('RIGHT', right, 'RIGHT', -14, 0)
	right.Text:SetJustifyH('LEFT')
	right.Text:SetWordWrap(true)
	right.Text:SetTextColor(0.85, 0.85, 0.85)

	right.Scroll, right.Content = CreateScroll(right)
	right.Scroll:SetPoint('TOPLEFT', right.Text, 'BOTTOMLEFT', 0, -12)
	right.Scroll:SetPoint('BOTTOMRIGHT', right, 'BOTTOMRIGHT', -24, 34)
	right.Scroll:HookScript('OnSizeChanged', function()
		Hub:OnContentResized()
	end)

	right.Message = right.Content:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	right.Message:SetPoint('TOPLEFT', right.Content, 'TOPLEFT', 0, -6)
	right.Message:SetPoint('RIGHT', right.Content, 'RIGHT', 0, 0)
	right.Message:SetJustifyH('LEFT')
	right.Message:SetWordWrap(true)

	right.Progress = LibAT.UI.CreateProgressBar(right, 200, 14)
	right.Progress:ClearAllPoints()
	right.Progress:SetPoint('BOTTOMLEFT', right, 'BOTTOMLEFT', 14, 10)
	right.Progress:SetPoint('BOTTOMRIGHT', right, 'BOTTOMRIGHT', -190, 10)

	right.ReloadText = right:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	right.ReloadText:SetPoint('LEFT', right.Progress, 'RIGHT', 10, 0)
	right.ReloadText:SetPoint('RIGHT', right, 'RIGHT', -14, 0)
	right.ReloadText:SetJustifyH('RIGHT')

	right.Combat = CreateFrame('Frame', nil, right)
	right.Combat:SetAllPoints(right)
	right.Combat:SetFrameLevel(right:GetFrameLevel() + 50)
	right.Combat.bg = right.Combat:CreateTexture(nil, 'BACKGROUND')
	right.Combat.bg:SetAllPoints()
	right.Combat.bg:SetColorTexture(0, 0, 0, 0.55)
	right.Combat.text = right.Combat:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	right.Combat.text:SetPoint('CENTER')
	right.Combat.text:SetText('Waiting for combat to end')
	right.Combat:Hide()
end

---@param w Frame
function Hub:CreateFooter(w)
	local bar = CreateFrame('Frame', nil, w)
	bar:SetPoint('BOTTOMLEFT', w, 'BOTTOMLEFT', 0, 0)
	bar:SetPoint('BOTTOMRIGHT', w, 'BOTTOMRIGHT', 0, 0)
	bar:SetHeight(36)
	w.Footer = bar

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
function Hub:LeaveCurrent()
	if self.page ~= 'step' then
		return
	end
	local entry = self.run.entries[self.index]
	if entry and entry.step.onLeave then
		SafeCall(entry.reg.id .. '.' .. entry.step.id .. ' onLeave', entry.step.onLeave, Setup:CreateContext(entry.reg, entry.step))
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
	self:EnsureWindow()
	if self.page ~= 'whatsnew' then
		self:LeaveCurrent()
		self.returnPage = self.page
		self.returnIndex = self.index
	end
	self.page = 'whatsnew'
	self.window:Show()
	self:Render(true)
end

---Next button
function Hub:GoNext()
	self:RefreshRun()
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
	self:LeaveCurrent()
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
		if rec and rec.status == 'pending' then
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
	if key == 'look' then
		opts = { artHeight = 92, minWidth = 165, maxColumns = 4 }
	elseif key == 'whatsnew' then
		opts = { artHeight = 0, minWidth = 220, maxColumns = 2, cardHeight = 104 }
	elseif key == 'start' then
		opts = { artHeight = 0, minWidth = 230, maxColumns = 2, cardHeight = 100 }
	else
		opts = { artHeight = 0, minWidth = 200, maxColumns = 4, cardHeight = 96 }
	end
	grid = LibAT.UI.CreateCardGrid(content, opts)
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
	return width
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
end

---Draw the current page
---@param scrollToTop? boolean
function Hub:Render(scrollToTop)
	if not self.window then
		return
	end
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

---Look and choice steps
---@return number height
function Hub:RenderChoice(reg, step, ctx)
	local grid = self:GetGrid(step.kind == 'look' and 'look' or 'choice')
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
			caption = option.caption,
			tag = option.tag,
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
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', self.window.RightPanel.Content, 'TOPLEFT', 0, 0)
	grid:Show()
	return grid:Layout(self:GetContentWidth())
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
	group.Title = group:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	group.Title:SetPoint('TOPLEFT', group, 'TOPLEFT', 0, 0)
	group.AllOff = CreateTextButton(group)
	group.AllOff:SetPoint('TOPRIGHT', group, 'TOPRIGHT', 0, 0)
	group.AllOn = CreateTextButton(group)
	group.AllOn:SetPoint('RIGHT', group.AllOff, 'LEFT', -12, 0)
	group.AllOn:SetLabel('Turn all on')
	group.AllOff:SetLabel('Turn all off')
	group.grid = LibAT.UI.CreateCardGrid(group, { artHeight = 0, minWidth = 180, maxColumns = 3, cardHeight = 78 })
	group.grid:SetPoint('TOPLEFT', group, 'TOPLEFT', 0, -22)
	self.toggleGroups[index] = group
	return group
end

---Toggles steps
---@return number height
function Hub:RenderToggles(reg, step, ctx)
	local groups = step.groups
	if not groups then
		groups = { { items = step.items or {} } }
	end
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
		group.grid.opts.onCheck = function(card, key, checked)
			local item = byKey[key]
			if item then
				SetItem(item, checked)
				card:SetChecked(Current(item))
			end
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
		group.grid:SetCards(list)
		for _, card in ipairs(group.grid.cards) do
			local item = byKey[card.data.value]
			card:SetState(false, not item.core, item.core and 'Always on' or nil)
		end
		group.Title:SetText(groupDef.title or '')
		group.AllOn:ApplyColor()
		group.AllOff:ApplyColor()
		group:ClearAllPoints()
		group:SetPoint('TOPLEFT', content, 'TOPLEFT', 0, -y)
		group:SetWidth(width)
		local gridHeight = group.grid:Layout(width)
		local height = 22 + gridHeight
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
		self:SetHeader(
			'All done',
			Setup:GetStagedCount() > 0 and 'Here is what you picked. Press Finish and reload to use the changes that need a reload.' or 'Here is what you picked. You can change any of it later.',
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
		self.summaryFrame = frame
	end
	local used = 0
	local function Row(indent, fontObject)
		used = used + 1
		local row = frame.rows[used]
		if not row then
			row = CreateFrame('Frame', nil, frame)
			row:SetHeight(18)
			row.label = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
			row.label:SetJustifyH('LEFT')
			row.value = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
			row.value:SetJustifyH('LEFT')
			row.link = CreateTextButton(row)
			frame.rows[used] = row
		end
		row.label:SetFontObject(fontObject or 'GameFontHighlight')
		row.label:ClearAllPoints()
		row.label:SetPoint('LEFT', row, 'LEFT', indent or 0, 0)
		row.label:SetTextColor(1, 1, 1)
		row.value:ClearAllPoints()
		row.value:SetPoint('LEFT', row, 'LEFT', 220, 0)
		row.value:SetTextColor(0.8, 0.8, 0.8)
		row.value:SetText('')
		row.link:Hide()
		row.link:ClearAllPoints()
		row.link:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
		row.link:ApplyColor()
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', frame, 'TOPLEFT', 0, -(used - 1) * 20)
		row:SetPoint('RIGHT', frame, 'RIGHT', 0, 0)
		row:Show()
		return row
	end

	for _, reg in ipairs(regs) do
		local row = Row(0, 'GameFontNormal')
		row.label:SetText(IconMarkup(reg) .. reg.name)
		row.label:SetTextColor(1, 0.82, 0)
		local rec = Setup:GetRecord(reg)
		if rec and rec.status == 'skipped' then
			row.value:SetText('Skipped')
		end
		if reg.config.optionsCommand then
			row.link:SetLabel('More settings')
			row.link:SetScript('OnClick', function()
				Setup:RunAction(reg, nil)
			end)
			row.link:Show()
		end
		for i, entry in ipairs(self.run.entries) do
			if entry.reg == reg and entry.step.kind ~= 'summary' then
				local value = self:DescribeValue(reg, entry.step)
				local stepRow = Row(14)
				stepRow.label:SetText(entry.step.name or entry.step.title)
				stepRow.value:SetText(value or '')
				if final or entry.step.kind ~= 'custom' then
					stepRow.link:SetLabel('Change')
					stepRow.link:SetScript('OnClick', function()
						Hub:ShowEntry(i)
					end)
					stepRow.link:Show()
				end
			end
		end
		used = used + 1 -- spacer
	end

	if final or #Setup.staged > 0 then
		local header = Row(0, 'GameFontNormal')
		local count = Setup:GetStagedCount()
		if count > 0 then
			header.label:SetText(count .. ' ' .. Plural(count, 'change needs', 'changes need') .. ' a reload')
			header.label:SetTextColor(1, 0.82, 0)
			for _, staged in ipairs(Setup.staged) do
				local row = Row(14)
				row.label:SetText('- ' .. staged.label)
			end
		else
			header.label:SetText('Nothing needs a reload.')
			header.label:SetTextColor(0.7, 0.7, 0.7)
		end
	end

	for i = used + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
	local height = math.max(used * 20, 1)
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
	local grid = self:GetGrid('whatsnew')
	local list = {}
	local unseen = {}
	local regsById = {}
	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		local newest = Setup:GetNewestWhatsNew(reg)
		if newest then
			regsById[reg.id] = reg
			unseen[reg.id] = Setup:GetUnseenWhatsNew(reg) ~= nil
			local action = newest.action or {}
			list[#list + 1] = {
				value = reg.id,
				title = newest.title,
				caption = newest.caption,
				tag = reg.name .. ' ' .. newest.version,
				link = {
					text = action.text or 'Show me',
					onClick = function()
						Setup:RunAction(reg, newest.action)
					end,
				},
			}
		end
	end
	if #list == 0 then
		local message = self.window.RightPanel.Message
		message:SetText('Nothing new right now.')
		message:Show()
		return 20
	end
	grid.opts.onClick = function(_, id)
		local reg = regsById[id]
		local newest = reg and Setup:GetNewestWhatsNew(reg)
		if newest then
			Setup:RunAction(reg, newest.action)
		end
	end
	grid.opts.onCheck = nil
	grid.opts.onVariant = nil
	grid:SetCards(list)
	for _, card in ipairs(grid.cards) do
		card:SetState(false, true, unseen[card.data.value] and 'New' or nil)
	end
	for id in pairs(regsById) do
		Setup:MarkWhatsNewSeen(regsById[id])
	end
	grid:ClearAllPoints()
	grid:SetPoint('TOPLEFT', self.window.RightPanel.Content, 'TOPLEFT', 0, 0)
	grid:Show()
	return grid:Layout(self:GetContentWidth())
end

----------------------------------------------------------------------------------------------------
-- Left list
----------------------------------------------------------------------------------------------------

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
	row.current:SetPoint('TOPLEFT')
	row.current:SetPoint('BOTTOMLEFT')
	row.current:SetWidth(2)
	row.fill = row:CreateTexture(nil, 'BACKGROUND')
	row.fill:SetAllPoints()
	row.text = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	row.text:SetJustifyH('LEFT')
	row.text:SetWordWrap(false)
	row.status = row:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
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

function Hub:RefreshList()
	if not self.window then
		return
	end
	local left = self.window.LeftPanel
	local width = LEFT_WIDTH - 20
	local r, g, b = LibAT.UI.GetAccentColor()
	local used = 0
	local y = 0
	local currentEntry = self.page == 'step' and self.run.entries[self.index]
	local check = LibAT.UI.AtlasMarkup('common-icon-checkmark', 12)

	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		used = used + 1
		local row = self:GetListRow(used)
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', left.List, 'TOPLEFT', 0, -y)
		row:SetSize(width, ADDON_ROW_HEIGHT)
		row.text:ClearAllPoints()
		row.text:SetPoint('LEFT', row, 'LEFT', 6, 0)
		row.text:SetPoint('RIGHT', row.status, 'LEFT', -4, 0)
		row.text:SetFontObject('GameFontNormal')
		row.text:SetText(IconMarkup(reg) .. reg.name)
		local inRun = self:IsInRun(reg)
		row.text:SetTextColor(1, inRun and 0.82 or 0.7, inRun and 0 or 0.4)
		local status = Setup:GetStatus(reg.id)
		if status == 'done' then
			row.status:SetText(check ~= '' and check or '|cff55cc55Done|r')
		elseif status == 'skipped' then
			row.status:SetText('|cff888888Skipped|r')
		else
			row.status:SetText('')
		end
		row.current:Hide()
		row.fill:SetColorTexture(0, 0, 0, 0)
		row.onClick = function()
			Hub:GoToAddon(reg)
		end
		row:Show()
		y = y + ADDON_ROW_HEIGHT

		if inRun then
			for i, entry in ipairs(self.run.entries) do
				if entry.reg == reg then
					used = used + 1
					local stepRow = self:GetListRow(used)
					stepRow:ClearAllPoints()
					stepRow:SetPoint('TOPLEFT', left.List, 'TOPLEFT', 0, -y)
					stepRow:SetSize(width, STEP_ROW_HEIGHT)
					local indent = entry.step._parentId and 30 or 18
					stepRow.text:ClearAllPoints()
					stepRow.text:SetPoint('LEFT', stepRow, 'LEFT', indent, 0)
					stepRow.text:SetPoint('RIGHT', stepRow, 'RIGHT', -4, 0)
					stepRow.text:SetFontObject('GameFontHighlightSmall')
					stepRow.status:SetText('')
					local isCurrent = entry == currentEntry
					if isCurrent then
						stepRow.text:SetText('> ' .. (entry.step.name or entry.step.title))
						stepRow.text:SetTextColor(1, 1, 1)
						stepRow.current:SetColorTexture(r, g, b, 1)
						stepRow.current:Show()
						stepRow.fill:SetColorTexture(r, g, b, 0.12)
					else
						stepRow.text:SetText(entry.step.name or entry.step.title)
						local seen = self.page == 'summary' or (self.page == 'step' and i < self.index)
						local shade = seen and 0.85 or 0.6
						stepRow.text:SetTextColor(shade, shade, shade)
						stepRow.current:Hide()
						stepRow.fill:SetColorTexture(0, 0, 0, 0)
					end
					stepRow.onClick = function()
						Hub:ShowEntry(i)
					end
					stepRow:Show()
					y = y + STEP_ROW_HEIGHT
				end
			end
			y = y + 4
		end
	end
	for i = used + 1, #left.rows do
		left.rows[i]:Hide()
	end
	left.List:SetSize(width, math.max(y, 1))

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
		w.NextButton:SetText(self.index >= total and 'Finish' or 'Next')
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

---Fade the window and block Finish while the player is in combat
---@param inCombat boolean
function Hub:OnCombatChanged(inCombat)
	if not self.window then
		return
	end
	self.window:SetAlpha(inCombat and 0.4 or 1)
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
	w.AccentLine.tex:SetColorTexture(r, g, b, 1)
	w.RightPanel.Progress:SetStatusBarColor(r, g, b)
	for _, grid in pairs(self.grids) do
		grid:ApplyAccent()
	end
	for _, group in ipairs(self.toggleGroups or {}) do
		group.grid:ApplyAccent()
		group.AllOn:ApplyColor()
		group.AllOff:ApplyColor()
	end
	if self.toast then
		self.toast.band:SetColorTexture(r, g, b, 1)
	end
	if self:IsShown() then
		self:RefreshList()
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
	local toast = CreateFrame('Frame', nil, UIParent)
	toast:SetSize(400, 58)
	toast:SetPoint('TOP', UIParent, 'TOP', 0, -140)
	toast:SetFrameStrata('DIALOG')
	toast:EnableMouse(true)
	toast.bg = toast:CreateTexture(nil, 'BACKGROUND')
	toast.bg:SetAllPoints()
	toast.bg:SetColorTexture(0.05, 0.05, 0.06, 0.94)
	toast.band = toast:CreateTexture(nil, 'ARTWORK')
	toast.band:SetPoint('TOPLEFT')
	toast.band:SetPoint('BOTTOMLEFT')
	toast.band:SetWidth(3)
	toast.title = toast:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	toast.title:SetPoint('TOPLEFT', toast, 'TOPLEFT', 12, -8)
	toast.title:SetText('Setup')
	toast.text = toast:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	toast.text:SetPoint('TOPLEFT', toast.title, 'BOTTOMLEFT', 0, -3)
	toast.text:SetPoint('RIGHT', toast, 'RIGHT', -120, 0)
	toast.text:SetJustifyH('LEFT')
	toast.text:SetWordWrap(true)
	toast.action = LibAT.UI.CreateButton(toast, 100, 22, 'Open')
	toast.action:SetPoint('RIGHT', toast, 'RIGHT', -12, -4)
	toast.close = CreateFrame('Button', nil, toast)
	toast.close:SetSize(16, 16)
	toast.close:SetPoint('TOPRIGHT', toast, 'TOPRIGHT', -4, -4)
	toast.close.text = toast.close:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
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
