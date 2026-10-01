---@class LibAT
local LibAT = LibAT

---Create an info/help button with tooltip support: a small ring with an "i", drawn with the kit
---@param parent Frame Parent frame
---@param tooltipTitle string Tooltip header text
---@param tooltipText string Tooltip body text
---@param size? number Optional button size (default 20)
---@return Frame button Info button with tooltip
function LibAT.UI.CreateInfoButton(parent, tooltipTitle, tooltipText, size)
	size = size or 20
	local Kit = LibAT.UI.Kit
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(size, size)

	button.Icon = button:CreateTexture(nil, 'ARTWORK')
	button.Icon:SetSize(size * 0.8, size * 0.8)
	button.Icon:SetPoint('CENTER', 0, 0)
	button.Glyph = button:CreateFontString(nil, 'OVERLAY')
	Kit:SetFont(button.Glyph, size >= 18 and 12 or 11, true)
	button.Glyph:SetPoint('CENTER', 0, 0)
	button.Glyph:SetText('i')

	local function Paint(self, config)
		config = config or Kit:GetKitFor(self)
		local c = config.colors
		Kit:SetAsset(self.Icon, config, 'radioRing')
		if self.hovered then
			local r, g, b = LibAT.UI.GetAccentColor()
			self.Icon:SetVertexColor(r, g, b, 1)
			self.Glyph:SetTextColor(c.text[1], c.text[2], c.text[3])
		else
			self.Icon:SetVertexColor(c.trimHi[1], c.trimHi[2], c.trimHi[3], 0.85)
			self.Glyph:SetTextColor(c.secondary[1], c.secondary[2], c.secondary[3])
		end
	end

	button:SetScript('OnMouseDown', function(self)
		self.Icon:SetPoint('CENTER', 0, -1)
		self.Glyph:SetPoint('CENTER', 0, -1)
	end)
	button:SetScript('OnMouseUp', function(self)
		self.Icon:SetPoint('CENTER', 0, 0)
		self.Glyph:SetPoint('CENTER', 0, 0)
	end)

	-- Callers may replace the tooltip; the hover color stays either way
	LibAT.UI.KeepScripts(button, {
		OnEnter = function(self)
			self.hovered = true
			Paint(self)
		end,
		OnLeave = function(self)
			self.hovered = false
			Paint(self)
		end,
	})
	button:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText(tooltipTitle, 1, 1, 1, nil, true)
		if tooltipText and tooltipText ~= '' then
			GameTooltip:AddLine(tooltipText, nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	button:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	return Kit:Track(button, Paint)
end

return LibAT.UI
