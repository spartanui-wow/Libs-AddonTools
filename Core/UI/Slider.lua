---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Slider Component
----------------------------------------------------------------------------------------------------

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local KNOB = 14

local function UpdateFill(slider)
	local minimum, maximum = slider:GetMinMaxValues()
	local span = (maximum or 1) - (minimum or 0)
	local share = span > 0 and ((slider:GetValue() or 0) - minimum) / span or 0
	local width = math.max((slider:GetWidth() or 0) - KNOB, 0)
	slider.kitFill:SetWidth(math.max(width * math.min(math.max(share, 0), 1), 1))
end

local function PaintSlider(slider, config)
	local c = config.colors
	local r, g, b = LibAT.UI.GetAccentColor()
	local enabled = slider:IsEnabled()
	local hot = enabled and (slider.kitHovered or slider.kitDragging)
	slider.kitTrack:SetVertexColor(c.trim[1], c.trim[2], c.trim[3], enabled and 0.45 or 0.2)
	slider.kitFill:SetVertexColor(r, g, b, enabled and 1 or 0.35)
	LibAT.UI.Kit:SetAsset(slider.kitKnob, config, 'switchKnob')
	if hot then
		slider.kitKnob:SetVertexColor(1, 1, 1, 1)
	else
		slider.kitKnob:SetVertexColor(0.88, 0.9, 0.92, enabled and 1 or 0.5)
	end
end

---Create a slider drawn with the window kit: a thin track, the accent filled up to the value and a
---round knob. It is a normal Slider, so SetValue, SetScript('OnValueChanged') and the rest work.
---@param parent Frame Parent frame
---@param width number Slider width
---@param height number Slider height
---@param min number Minimum value
---@param max number Maximum value
---@param step number Value step increment
---@return Slider slider Slider with standard methods
function LibAT.UI.CreateSlider(parent, width, height, min, max, step)
	local slider = CreateFrame('Slider', nil, parent)
	slider:SetOrientation('HORIZONTAL')
	slider:SetSize(width, math.max(height or 16, KNOB))
	slider:SetHitRectInsets(0, 0, -4, -4)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	slider.kitTrack = slider:CreateTexture(nil, 'BACKGROUND')
	slider.kitTrack:SetTexture(WHITE)
	slider.kitTrack:SetPoint('LEFT', KNOB / 2, 0)
	slider.kitTrack:SetPoint('RIGHT', -KNOB / 2, 0)
	slider.kitTrack:SetHeight(4)
	slider.kitFill = slider:CreateTexture(nil, 'ARTWORK')
	slider.kitFill:SetTexture(WHITE)
	slider.kitFill:SetPoint('LEFT', slider.kitTrack, 'LEFT', 0, 0)
	slider.kitFill:SetHeight(4)

	slider.kitKnob = slider:CreateTexture(nil, 'OVERLAY')
	slider.kitKnob:SetSize(KNOB, KNOB)
	slider:SetThumbTexture(slider.kitKnob)

	LibAT.UI.Kit:Track(slider, PaintSlider)
	local function Repaint(self)
		self:ApplyKit()
	end
	-- Callers set their own OnValueChanged and tooltips; the slider keeps drawing itself
	LibAT.UI.KeepScripts(slider, {
		OnValueChanged = UpdateFill,
		OnSizeChanged = UpdateFill,
		OnEnter = function(self)
			self.kitHovered = true
			self:ApplyKit()
		end,
		OnLeave = function(self)
			self.kitHovered = false
			self:ApplyKit()
		end,
		OnMouseDown = function(self)
			self.kitDragging = true
			self:ApplyKit()
		end,
		OnMouseUp = function(self)
			self.kitDragging = false
			self:ApplyKit()
		end,
		OnEnable = Repaint,
		OnDisable = Repaint,
	})
	UpdateFill(slider)
	return slider
end

return LibAT.UI
