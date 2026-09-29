---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Accent color - one color that LibAT windows use for highlights, bands and progress
----------------------------------------------------------------------------------------------------

LibAT.UI.ACCENT_CHANGED = 'LIBAT_SETUP_ACCENT_CHANGED'

local DEFAULT_R, DEFAULT_G, DEFAULT_B = 226 / 255, 31 / 255, 31 / 255 -- e21f1f

local provider = nil ---@type fun(): any
local backdropProvider = nil ---@type fun(): string|nil
local lastR, lastG, lastB = DEFAULT_R, DEFAULT_G, DEFAULT_B

---Turn a provider result into r, g, b (0-1). Accepts r, g, b numbers, {r, g, b}, {r=, g=, b=} or 'rrggbb'.
---@return number|nil r
---@return number|nil g
---@return number|nil b
local function Normalize(a, b, c)
	if type(a) == 'number' and type(b) == 'number' and type(c) == 'number' then
		return a, b, c
	end
	if type(a) == 'table' then
		local r = a.r or a[1]
		local g = a.g or a[2]
		local bl = a.b or a[3]
		if type(r) == 'number' and type(g) == 'number' and type(bl) == 'number' then
			return r, g, bl
		end
		return nil
	end
	if type(a) == 'string' then
		local hex = a:gsub('^#', ''):gsub('^|c%x%x', '')
		if #hex == 8 then
			hex = hex:sub(3)
		end
		if #hex == 6 and not hex:find('%X') then
			return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
		end
	end
	return nil
end

---Get the current accent color. Falls back to LibAT red when no provider is set or it fails.
---@return number r
---@return number g
---@return number b
function LibAT.UI.GetAccentColor()
	if provider then
		local ok, a, b, c = pcall(provider)
		if ok then
			local r, g, bl = Normalize(a, b, c)
			if r then
				return math.min(math.max(r, 0), 1), math.min(math.max(g, 0), 1), math.min(math.max(bl, 0), 1)
			end
		elseif LibAT.InternalLog then
			LibAT.InternalLog.warning('Accent provider failed: ' .. tostring(a))
		end
	end
	return DEFAULT_R, DEFAULT_G, DEFAULT_B
end

---Get the accent color as a 'rrggbb' hex string, for |cff color codes
---@return string hex
function LibAT.UI.GetAccentHex()
	local r, g, b = LibAT.UI.GetAccentColor()
	return string.format('%02x%02x%02x', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

---Tell every LibAT window that the accent may have changed. Sends LIBAT_SETUP_ACCENT_CHANGED(r, g, b)
---when the color is different from the last one sent, or always when force is true.
---@param force? boolean Send even when the color did not change
function LibAT.UI.NotifyAccentChanged(force)
	local r, g, b = LibAT.UI.GetAccentColor()
	if not force and r == lastR and g == lastG and b == lastB then
		return
	end
	lastR, lastG, lastB = r, g, b
	if LibAT.SendMessage then
		LibAT:SendMessage(LibAT.UI.ACCENT_CHANGED, r, g, b)
	end
end

---Set the function LibAT asks for its accent color. It may return r, g, b (0-1), a color table or a
---'rrggbb' string. Pass nil to go back to LibAT red. Windows repaint right away.
---@param fn? fun(): any
function LibAT.UI.SetAccentProvider(fn)
	if fn ~= nil and type(fn) ~= 'function' then
		if LibAT.InternalLog then
			LibAT.InternalLog.warning('SetAccentProvider expects a function, got ' .. type(fn))
		end
		return
	end
	provider = fn
	LibAT.UI.NotifyAccentChanged(true)
end

---Get the backdrop supplied by the host addon. A nil return uses the setup skin's neutral art.
---@return string|nil texturePath
function LibAT.UI.GetBackdrop()
	if not backdropProvider then
		return nil
	end
	local ok, path = pcall(backdropProvider)
	if ok and type(path) == 'string' and path ~= '' then
		return path
	end
	if not ok and LibAT.InternalLog then
		LibAT.InternalLog.warning('Backdrop provider failed: ' .. tostring(path))
	end
	return nil
end

---Set the setup window backdrop provider. Pass nil to use the shipped neutral backdrop.
---@param fn? fun(): string|nil
function LibAT.UI.SetBackdropProvider(fn)
	if fn ~= nil and type(fn) ~= 'function' then
		if LibAT.InternalLog then
			LibAT.InternalLog.warning('SetBackdropProvider expects a function, got ' .. type(fn))
		end
		return
	end
	backdropProvider = fn
	LibAT.UI.NotifyAccentChanged(true)
end

return LibAT.UI
