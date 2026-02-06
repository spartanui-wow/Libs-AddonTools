---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

----------------------------------------------------------------------------------------------------
-- Serialization Pipeline
-- Encode: Data table → AceSerializer → LibCompress → LibBase64 → shareable string
-- Decode: shareable string → LibBase64 → LibCompress → AceSerializer → Data table
----------------------------------------------------------------------------------------------------

-- Library references (resolved lazily to handle load order)
local AceSerializer
local LibCompress
local LibBase64

---Get library references (lazy initialization)
---@return boolean success Whether all libraries are available
---@return string|nil error Error message if a library is missing
local function EnsureLibraries()
	if AceSerializer and LibCompress and LibBase64 then
		return true
	end

	AceSerializer = LibStub and LibStub('AceSerializer-3.0', true)
	LibCompress = LibStub and LibStub('LibCompress', true)
	LibBase64 = LibStub and LibStub('LibBase64-1.0', true)

	if not AceSerializer then
		return false, 'AceSerializer-3.0 not available'
	end
	if not LibCompress then
		return false, 'LibCompress not available'
	end
	if not LibBase64 then
		return false, 'LibBase64-1.0 not available'
	end

	return true
end

---Encode a data table to a compressed, base64-encoded string
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

	-- Step 2: Compress with LibCompress
	local compressed, compressErr = LibCompress:Compress(serialized)
	if not compressed then
		return nil, 'Compression failed: ' .. tostring(compressErr)
	end

	-- Step 3: Encode to Base64
	local ok, encoded = pcall(function()
		return LibBase64:Encode(compressed)
	end)
	if not ok then
		return nil, 'Base64 encoding failed: ' .. tostring(encoded)
	end

	return encoded
end

---Decode a compressed, base64-encoded string back to a data table
---@param encodedString string The base64-encoded string to decode
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

	-- Step 1: Decode from Base64
	local ok, decoded = pcall(function()
		return LibBase64:Decode(encodedString)
	end)
	if not ok or not decoded then
		return nil, 'Base64 decoding failed: ' .. tostring(decoded)
	end

	-- Step 2: Decompress with LibCompress
	local decompressed, decompressErr = LibCompress:Decompress(decoded)
	if not decompressed then
		return nil, 'Decompression failed: ' .. tostring(decompressErr)
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
