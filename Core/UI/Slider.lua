---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Slider Component
----------------------------------------------------------------------------------------------------

---Create a slider with modern styling
---@param parent Frame Parent frame
---@param width number Slider width
---@param height number Slider height
---@param min number Minimum value
---@param max number Maximum value
---@param step number Value step increment
---@return Slider slider Slider with standard methods
function LibAT.UI.CreateSlider(parent, width, height, min, max, step)
	local slider = CreateFrame('Slider', nil, parent, 'OptionsSliderTemplate')
	slider:SetSize(width, height)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)

	-- Style the slider with modern aesthetic
	-- SetBackdrop requires BackdropTemplate in 9.0+, use pcall for safety
	if slider.SetBackdrop then
		pcall(function()
			slider:SetBackdrop({
				bgFile = 'Interface\\Buttons\\UI-SliderBar-Background',
				edgeFile = 'Interface\\Buttons\\UI-SliderBar-Border',
				tile = true,
				tileSize = 8,
				edgeSize = 8,
				insets = { left = 3, right = 3, top = 6, bottom = 6 },
			})
		end)
	end

	-- Hide default low/high text (we'll handle labels externally)
	if slider.Low then
		slider.Low:Hide()
	end
	if slider.High then
		slider.High:Hide()
	end

	-- Hide default text (we'll handle display externally)
	if slider.Text then
		slider.Text:Hide()
	end

	return slider
end

return LibAT.UI
