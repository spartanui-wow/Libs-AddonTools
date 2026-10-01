---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- ProgressBar Component
----------------------------------------------------------------------------------------------------

local WHITE = 'Interface\\Buttons\\WHITE8X8'

---Create a progress bar drawn with the window kit: a dark well with a 1px trim edge, filled with
---the accent color. Callers that set their own bar color keep it.
---@param parent Frame Parent frame
---@param width number Bar width
---@param height number Bar height
---@return StatusBar progressBar Progress bar with standard methods
function LibAT.UI.CreateProgressBar(parent, width, height)
	local Kit = LibAT.UI.Kit
	local bar = CreateFrame('StatusBar', nil, parent)
	bar:SetSize(width, height)
	bar:SetStatusBarTexture(WHITE)
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)

	bar.bg = bar:CreateTexture(nil, 'BACKGROUND')
	bar.bg:SetTexture(WHITE)
	bar.bg:SetAllPoints(bar)

	bar.Border = CreateFrame('Frame', nil, bar)
	bar.Border:SetAllPoints()
	bar.Border.edges = {}
	for i, anchor in ipairs({ { 'TOPLEFT', 'TOPRIGHT', nil, 1 }, { 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 }, { 'TOPLEFT', 'BOTTOMLEFT', 1 }, { 'TOPRIGHT', 'BOTTOMRIGHT', 1 } }) do
		local edge = bar.Border:CreateTexture(nil, 'BORDER')
		edge:SetTexture(WHITE)
		edge:SetPoint(anchor[1])
		edge:SetPoint(anchor[2])
		if anchor[3] then
			edge:SetWidth(anchor[3])
		else
			edge:SetHeight(anchor[4])
		end
		bar.Border.edges[i] = edge
	end

	bar.text = bar.Border:CreateFontString(nil, 'OVERLAY')
	Kit:SetFont(bar.text, 11)
	bar.text:SetPoint('CENTER')
	bar.text:SetText('')

	local NativeSetStatusBarColor = bar.SetStatusBarColor
	function bar:SetStatusBarColor(...)
		self.kitCustomColor = true
		NativeSetStatusBarColor(self, ...)
	end

	---Set the progress bar text
	---@param text string Text to display
	function bar:SetText(text)
		self.text:SetText(text or '')
	end

	---Update both value and text display
	---@param value number Progress value
	---@param text? string Optional text to display
	function bar:Update(value, text)
		self:SetValue(value)
		if text then
			self:SetText(text)
		end
	end

	Kit:Track(bar, function(owner, config)
		local c = config.colors
		local well = c.surface[0]
		owner.bg:SetVertexColor(well[1], well[2], well[3], 0.85)
		for _, edge in ipairs(owner.Border.edges) do
			edge:SetVertexColor(c.trim[1], c.trim[2], c.trim[3], 0.75)
		end
		if not owner.kitCustomColor then
			local r, g, b = LibAT.UI.GetAccentColor()
			NativeSetStatusBarColor(owner, r, g, b)
		end
		owner.text:SetTextColor(c.text[1], c.text[2], c.text[3])
	end)
	return bar
end

return LibAT.UI
