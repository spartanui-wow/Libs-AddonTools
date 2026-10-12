---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Drawn card pictures - a card's picture drawn by code instead of an image file
--
-- A card's art may carry a draw function. The card gives it a frame over the picture area (one
-- per card, reused) and calls it again whenever the card is shown, resized, picked, enabled or
-- disabled, or repainted with a new window kit:
--
--   art = {
--   	draw = function(holder, data, card, width, height, state) ... end,
--   	release = function(holder, data, card) ... end, -- optional
--   	color = { 0.05, 0.05, 0.06, 1 }, -- optional backdrop under the drawing
--   }
--
-- art may also be the draw function itself. Both LibAT.UI.CreateCard and Kit:CreateCard (and their
-- grids) support it, so setup look steps and settings card grids get it alike.
--
-- When the card is reused for other data, release runs and everything in the holder is hidden.
-- Keep the pieces you make on the holder and Show them in every draw.
----------------------------------------------------------------------------------------------------

---@class LibAT.CardArtState
---@field selected boolean The card is the picked one
---@field enabled boolean The card can be clicked
---@field label? string The status badge text, such as 'In use'
---@field kit? table The window kit the card is painted with (kit cards only)

---@alias LibAT.CardArtDraw fun(holder: Frame, data: LibAT.CardData, card: Frame, width: number, height: number, state: LibAT.CardArtState)
---@alias LibAT.CardArtRelease fun(holder: Frame, data: LibAT.CardData, card: Frame)

---@class LibAT.CardArtOptions
---@field anchor ScriptRegion The card's picture region; the holder covers it
---@field size fun(card: Frame): number, number Width and height of the picture area
---@field top? Frame[] Card frames (badges) kept above the drawing
---@field kit? boolean Pass the card's window kit in state.kit and redraw when it changes

---@class LibAT.UI.CardArt
local CardArt = {}
LibAT.UI.CardArt = CardArt

-- How far above the holder the card's badges sit, so a drawing with nested frames stays under them
local TOP_OFFSET = 12
local EMPTY = {}

local reported = {}

---Show a drawing error once
---@param err any
local function Report(err)
	local key = tostring(err)
	if reported[key] then
		return
	end
	reported[key] = true
	if LibAT.InternalLog and LibAT.InternalLog.error then
		LibAT.InternalLog.error('Card picture: ' .. key)
	end
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	end
end

---The draw function of a card's art, or nil for a plain picture
---@param art any
---@return LibAT.CardArtDraw|nil
function CardArt.GetDraw(art)
	if type(art) == 'function' then
		return art
	end
	if type(art) == 'table' and type(art.draw) == 'function' then
		return art.draw
	end
	return nil
end

---The art's fields for reading. Safe when art is nil or a draw function.
---@param art any
---@return LibAT.CardArt
function CardArt.Fields(art)
	if type(art) == 'table' then
		return art
	end
	return EMPTY
end

---Hide everything a drawing left in the holder
---@param holder Frame
local function Clear(holder)
	for _, region in ipairs({ holder:GetRegions() }) do
		region:Hide()
	end
	for _, child in ipairs({ holder:GetChildren() }) do
		child:Hide()
	end
end

---@param card Frame
---@param opts LibAT.CardArtOptions
---@return Frame holder
local function CreateHolder(card, opts)
	local holder = CreateFrame('Frame', nil, card)
	holder:SetAllPoints(opts.anchor)
	holder.card = card
	holder.state = {}
	holder.last = {}
	holder:SetScript('OnShow', function(self)
		CardArt.Request(self.card, true)
	end)
	holder:SetScript('OnSizeChanged', function(self)
		CardArt.Request(self.card)
	end)
	holder:Hide()
	card.drawnArt = holder
	return holder
end

---Point a card at its art. Called from the card's SetData. Returns true when the art is drawn,
---so the card keeps its picture area even without an image.
---@param card Frame
---@param art any The card's art, or nil when the card has no picture area
---@param data? LibAT.CardData
---@param opts? LibAT.CardArtOptions
---@return boolean drawn
function CardArt.Bind(card, art, data, opts)
	local draw = CardArt.GetDraw(art)
	local holder = card.drawnArt
	if holder and holder.draw and (holder.art ~= art or holder.data ~= data) then
		CardArt.Release(card)
	end
	if not draw or not opts or not opts.anchor then
		CardArt.Release(card)
		card.artDrawn = false
		return false
	end
	holder = holder or CreateHolder(card, opts)
	holder.opts = opts
	holder.art, holder.data, holder.draw = art, data, draw
	wipe(holder.last)
	card.artDrawn = true
	-- Showing a visible holder draws it through OnShow; a hidden one draws when the card shows
	if holder:IsShown() then
		CardArt.Request(card, true)
	else
		holder:Show()
	end
	return true
end

---Draw the card's picture if anything it depends on changed. Cheap to call often.
---@param card Frame
---@param force? boolean Draw even when nothing changed (the card was shown again)
function CardArt.Request(card, force)
	local holder = card and card.drawnArt
	if not holder or not holder.draw or holder.drawing or not holder:IsVisible() then
		return
	end
	local opts = holder.opts or EMPTY
	local width, height = 0, 0
	if opts.size then
		width, height = opts.size(card)
	end
	if (width or 0) < 2 or (height or 0) < 2 then
		width, height = holder:GetSize()
	end
	-- Not laid out yet; OnSizeChanged draws it once it is
	if (width or 0) < 2 or (height or 0) < 2 then
		return
	end
	width, height = math.floor(width + 0.5), math.floor(height + 0.5)
	local data = holder.data
	local selected = card.selected and true or false
	local enabled = card.enabled ~= false
	local label = card.stateLabel
	local variant = type(data) == 'table' and data.variant or nil
	local kit = opts.kit and LibAT.UI.Kit and LibAT.UI.Kit:GetKitFor(card) or nil
	local last = holder.last
	if
		not force
		and last.drawn
		and last.width == width
		and last.height == height
		and last.selected == selected
		and last.enabled == enabled
		and last.label == label
		and last.variant == variant
		and last.kit == kit
	then
		return
	end
	last.drawn, last.width, last.height = true, width, height
	last.selected, last.enabled, last.label, last.variant, last.kit = selected, enabled, label, variant, kit

	local state = holder.state
	state.selected, state.enabled, state.label, state.kit = selected, enabled, label, kit
	holder:SetFrameLevel(card:GetFrameLevel())
	holder.drawing = true
	local ok, err = pcall(holder.draw, holder, data, card, width, height, state)
	holder.drawing = nil
	if not ok then
		Report(err)
	end
	local level = holder:GetFrameLevel() + TOP_OFFSET
	for _, frame in ipairs(opts.top or EMPTY) do
		frame:SetFrameLevel(level)
	end
end

---Let go of the drawing so the card can be reused. Called from the card's Reset.
---@param card Frame
function CardArt.Release(card)
	local holder = card and card.drawnArt
	if not holder then
		return
	end
	if holder.draw then
		local release = type(holder.art) == 'table' and holder.art.release
		if type(release) == 'function' then
			local ok, err = pcall(release, holder, holder.data, card)
			if not ok then
				Report(err)
			end
		end
		Clear(holder)
	end
	holder.art, holder.data, holder.draw = nil, nil, nil
	wipe(holder.last)
	card.artDrawn = false
	holder:Hide()
end

LibAT.Capabilities = LibAT.Capabilities or {}
LibAT.Capabilities.cardArtDraw = 1

return CardArt
