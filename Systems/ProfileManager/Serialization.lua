---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

----------------------------------------------------------------------------------------------------
-- Serialization Pipeline
-- Encode: Data table → AceSerializer → LibDeflate (Compress + EncodeForPrint) → shareable string
-- Decode: shareable string → LibDeflate (DecodeForPrint + Decompress) → AceSerializer → Data table
--
-- Uses DEFLATE compression (same as ElvUI, WeakAuras) for better compression ratios
-- and industry-standard codec compatibility.
----------------------------------------------------------------------------------------------------

-- Library references (resolved lazily to handle load order)
local AceSerializer
local LibDeflate

---Get library references (lazy initialization)
---@return boolean success Whether all libraries are available
---@return string|nil error Error message if a library is missing
local function EnsureLibraries()
	if AceSerializer and LibDeflate then
		return true
	end

	AceSerializer = LibStub and LibStub('AceSerializer-3.0', true)
	LibDeflate = LibStub and LibStub('LibDeflate', true)

	if not AceSerializer then
		return false, 'AceSerializer-3.0 not available'
	end
	if not LibDeflate then
		return false, 'LibDeflate not available'
	end

	return true
end

---Encode a data table to a compressed, printable string
---@param data table The data to encode
---@return string|nil encoded The encoded string, or nil on error
---@return string|nil error Error message if encoding failed
function ProfileManager.EncodeData(data)
	local libsOk, libErr = EnsureLibraries()
	if not libsOk then
		return nil, libErr
	end

	-- Step 1: Serialize with AceSerializer
	local serialized = AceSerializer:Serialize(data)
	if not serialized then
		return nil, 'Serialization failed'
	end

	-- Step 2: Compress with LibDeflate (DEFLATE algorithm)
	local compressed = LibDeflate:CompressDeflate(serialized, { level = 9 })
	if not compressed then
		return nil, 'Compression failed'
	end

	-- Step 3: Encode for print (custom base-64-like encoding optimized for WoW)
	local encoded = LibDeflate:EncodeForPrint(compressed)
	if not encoded then
		return nil, 'EncodeForPrint failed'
	end

	return encoded
end

---Decode a compressed, printable string back to a data table
---@param encodedString string The encoded string to decode
---@return table|nil data The decoded data table, or nil on error
---@return string|nil error Error message if decoding failed
function ProfileManager.DecodeData(encodedString)
	local libsOk, libErr = EnsureLibraries()
	if not libsOk then
		return nil, libErr
	end

	if not encodedString or type(encodedString) ~= 'string' or encodedString == '' then
		return nil, 'Invalid input: expected non-empty string'
	end

	-- Step 1: Decode from printable format
	local decoded = LibDeflate:DecodeForPrint(encodedString)
	if not decoded then
		return nil, 'DecodeForPrint failed: invalid encoding'
	end

	-- Step 2: Decompress with LibDeflate
	local decompressed = LibDeflate:DecompressDeflate(decoded)
	if not decompressed then
		return nil, 'Decompression failed'
	end

	-- Step 3: Deserialize with AceSerializer
	local success, data = AceSerializer:Deserialize(decompressed)
	if not success then
		return nil, 'Deserialization failed: ' .. tostring(data)
	end

	if type(data) ~= 'table' then
		return nil, 'Deserialized data is not a table'
	end

	return data
end
