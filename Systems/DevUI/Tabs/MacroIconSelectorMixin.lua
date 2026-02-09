-- LibAT Macro Icon Selector Mixin
-- Extends Blizzard's IconSelectorPopupFrameTemplate to provide an icon browser
-- for the DevUI Macro Editor. Used by MacroIconSelector.xml.

---@class LibATMacroIconSelectorMixin : IconSelectorPopupFrameTemplateMixin
LibATMacroIconSelectorMixin = {}

function LibATMacroIconSelectorMixin:OnShow()
	IconSelectorPopupFrameTemplateMixin.OnShow(self)

	-- Create icon data provider with spellbook icons included
	self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.Spellbook)

	-- Show all icon types by default
	self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
	self:Update()
	self.BorderBox.IconSelectorEditBox:OnTextChanged()

	-- Callback when an icon is clicked in the grid
	local function OnIconSelected(selectionIndex, icon)
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
		self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
		self.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
	end
	self.IconSelector:SetSelectedCallback(OnIconSelected)
end

function LibATMacroIconSelectorMixin:OnHide()
	IconSelectorPopupFrameTemplateMixin.OnHide(self)

	-- Release icon data to free memory
	if self.iconDataProvider then
		self.iconDataProvider:Release()
		self.iconDataProvider = nil
	end
end

function LibATMacroIconSelectorMixin:Update()
	-- Hide the name edit box — our macro editor already has a name field
	self.BorderBox.IconSelectorEditBox:Hide()
	if self.BorderBox.EditBoxHeaderText then
		self.BorderBox.EditBoxHeaderText:Hide()
	end

	-- Set a placeholder name so Blizzard's OnTextChanged enables the OK button
	-- (IconSelectorEditBoxMixin:OnTextChanged checks text length > 0 to enable/disable OK)
	self.BorderBox.IconSelectorEditBox:SetText('Icon')
	self.BorderBox.IconSelectorEditBox:OnTextChanged()

	-- Pre-select current macro icon if one is loaded
	local initialIndex = 1
	if self.currentIcon then
		local index = self:GetIndexOfIcon(self.currentIcon)
		if index then
			initialIndex = index
		end
	end

	self.IconSelector:SetSelectedIndex(initialIndex)
	self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(initialIndex))

	-- Feed icon data to the scrollable grid
	local getSelection = GenerateClosure(self.GetIconByIndex, self)
	local getNumSelections = GenerateClosure(self.GetNumIcons, self)
	self.IconSelector:SetSelectionsDataProvider(getSelection, getNumSelections)
	self.IconSelector:ScrollToSelectedIndex()

	self:SetSelectedIconText()
end

function LibATMacroIconSelectorMixin:OkayButton_OnClick()
	IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)

	local iconTexture = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()

	-- Fire callback to apply the selected icon
	if self.onIconSelected and iconTexture then
		self.onIconSelected(iconTexture)
	end
end

function LibATMacroIconSelectorMixin:CancelButton_OnClick()
	IconSelectorPopupFrameTemplateMixin.CancelButton_OnClick(self)
end
