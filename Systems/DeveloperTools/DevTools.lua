---@class LibAT
local LibAT = LibAT
local DevTools = LibAT:NewModule('Handler.DevTools') ---@class LibAT.DevToolsInternal : AceAddon, AceEvent-3.0, AceConsole-3.0
DevTools.description = 'Developer Tools and Debugging Utilities'

-- Logger instance
---@type LibAT.Logger.AddonLogger?
local logger

---Custom OnMouseDown handler for TableAttributeDisplay value buttons
---@param self Button
---@param button string Mouse button that was clicked
local function OnMouseDown(self, button)
	local text = self.Text and self.Text:GetText()
	if not text then
		return
	end

	if button == 'RightButton' then
		local editBox = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
		if not editBox then
			editBox = ChatFrame1EditBox
		end

		if editBox then
			if not editBox:IsShown() and ChatEdit_ActivateChat then
				ChatEdit_ActivateChat(editBox)
			end
			editBox:SetText(text)
			LibAT:Print('Copied to chat: |cff00ccff' .. tostring(text) .. '|r')
		else
			LibAT:Print('Chat edit box not available.')
		end
	elseif button == 'MiddleButton' then
		local parent = self:GetParent()
		if parent and parent.GetAttributeData then
			local attrData = parent:GetAttributeData()
			if attrData and attrData.rawValue then
				local rawData = attrData.rawValue
				if type(rawData) == 'table' and rawData.IsObjectType then
					if rawData:IsObjectType('Texture') then
						_G.TEX = rawData
						LibAT:Print('Set |cff00ff00_G.TEX|r to: |cff00ccff' .. tostring(text) .. '|r')
					else
						_G.FRAME = rawData
						LibAT:Print('Set |cff00ff00_G.FRAME|r to: |cff00ccff' .. tostring(text) .. '|r')
					end
				end
			end
		end
	else
		if _G.TableAttributeDisplayValueButton_OnMouseDown then
			_G.TableAttributeDisplayValueButton_OnMouseDown(self)
		end
	end
end

---Patch all ValueButtons in an inspector's LinesContainer with our custom handler
---@param inspector Frame TableInspectorMixin instance
local function PatchInspectorLines(inspector)
	local scrollFrame = inspector.LinesScrollFrame
	if not scrollFrame or not scrollFrame.LinesContainer then
		return
	end

	local children = { scrollFrame.LinesContainer:GetChildren() }
	for _, child in ipairs(children) do
		if child.ValueButton and child.ValueButton:GetScript('OnMouseDown') ~= OnMouseDown then
			child.ValueButton:SetScript('OnMouseDown', OnMouseDown)
		end
	end
end

---Hook an inspector instance's UpdateLines to auto-patch ValueButtons after refresh
---@param inspector Frame TableInspectorMixin instance
local function HookInspectorInstance(inspector)
	if inspector._devToolsHooked then
		return
	end
	inspector._devToolsHooked = true
	hooksecurefunc(inspector, 'UpdateLines', function(self)
		PatchInspectorLines(self)
	end)
end

---Setup hooks for TableAttributeDisplay to add right-click copy and middle-click frame capture
local function SetupTableInspectorHooks()
	local function SetupHooks()
		-- Hook the singleton instance used by frame stack (ctrl+click)
		if _G.TableAttributeDisplay then
			HookInspectorInstance(_G.TableAttributeDisplay)
		end

		-- Wrap DisplayTableInspectorWindow to catch /tinspect pool instances
		if _G.DisplayTableInspectorWindow then
			local origDisplay = _G.DisplayTableInspectorWindow
			_G.DisplayTableInspectorWindow = function(...)
				local result = origDisplay(...)
				if result then
					HookInspectorInstance(result)
					PatchInspectorLines(result)
				end
				return result
			end
		end

		if logger then
			logger.debug('TableAttributeDisplay hooks installed')
		end
	end

	if _G.TableAttributeDisplay then
		SetupHooks()
	else
		local frame = CreateFrame('Frame')
		frame:RegisterEvent('ADDON_LOADED')
		frame:SetScript('OnEvent', function(self, event, addonName)
			if addonName == 'Blizzard_DebugTools' then
				SetupHooks()
				self:UnregisterEvent('ADDON_LOADED')
			end
		end)
	end
end

---Register slash commands for developer tools
local function RegisterSlashCommands()
	-- /devcon - Open developer console
	SLASH_DEVCON1 = '/devcon'
	SlashCmdList['DEVCON'] = function()
		if _G.DeveloperConsole then
			_G.DeveloperConsole:Toggle()
		else
			LibAT:Print('Developer Console is not available. Launch WoW with -console flag or use this command to open it without the flag.')
		end
	end

	-- /frame [frameName] [tinspect] - Inspect a frame
	SLASH_INSPECTFRAME1 = '/frame'
	SlashCmdList['INSPECTFRAME'] = function(msg)
		local args = { strsplit(' ', msg) }
		local frameName = args[1]
		local openInspector = args[2] and (args[2]:lower() == 'true' or args[2] == '1')

		if not frameName or frameName == '' then
			LibAT:Print('Usage: /frame <frameName> [true|1] - Set global FRAME variable and optionally open in TableAttributeDisplay')
			return
		end

		local frame = _G[frameName]
		if not frame then
			LibAT:Print('Frame not found: ' .. frameName)
			return
		end

		_G.FRAME = frame
		LibAT:Print('Set |cff00ff00_G.FRAME|r to: |cff00ccff' .. frameName .. '|r')

		if openInspector and _G.TableAttributeDisplay then
			_G.TableAttributeDisplay:InspectTable(frame)
			LibAT:Print('Opened in TableAttributeDisplay')
		end
	end

	-- /getpoint [frameName] - Get frame positioning information
	SLASH_GETPOINT1 = '/getpoint'
	SlashCmdList['GETPOINT'] = function(msg)
		local frameName = msg and msg:trim()

		if not frameName or frameName == '' then
			LibAT:Print('Usage: /getpoint <frameName> - Get frame positioning information')
			return
		end

		local frame = _G[frameName]
		if not frame then
			LibAT:Print('Frame not found: ' .. frameName)
			return
		end

		if not frame.GetPoint then
			LibAT:Print('Object is not a frame: ' .. frameName)
			return
		end

		local numPoints = frame:GetNumPoints()
		if numPoints == 0 then
			LibAT:Print(frameName .. ' has no anchor points')
			return
		end

		LibAT:Print('Anchor points for |cff00ccff' .. frameName .. '|r:')
		for i = 1, numPoints do
			local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(i)
			local relativeToName = relativeTo and relativeTo:GetName() or 'UIParent'
			LibAT:Print(string.format('  %d: |cff00ff00%s|r to |cff00ccff%s|r |cff00ff00%s|r (%.2f, %.2f)', i, point, relativeToName, relativePoint, xOffset or 0, yOffset or 0))
		end
	end

	-- /texlist [frameName] - List all textures in a frame
	SLASH_TEXLIST1 = '/texlist'
	SlashCmdList['TEXLIST'] = function(msg)
		local frameName = msg and msg:trim()

		if not frameName or frameName == '' then
			LibAT:Print('Usage: /texlist <frameName> - List all textures in a frame')
			return
		end

		local frame = _G[frameName]
		if not frame then
			LibAT:Print('Frame not found: ' .. frameName)
			return
		end

		local textures = {}
		local regions = { frame:GetRegions() }

		for _, region in ipairs(regions) do
			if region:IsObjectType('Texture') then
				local texturePath = region:GetTexture()
				local drawLayer = region:GetDrawLayer()
				table.insert(textures, {
					path = texturePath or 'nil',
					name = region:GetName() or 'Unnamed',
					layer = drawLayer or 'ARTWORK',
				})
			end
		end

		if #textures == 0 then
			LibAT:Print('No textures found in ' .. frameName)
			return
		end

		LibAT:Print('Textures in |cff00ccff' .. frameName .. '|r:')
		for i, tex in ipairs(textures) do
			LibAT:Print(string.format('  %d: |cff00ff00%s|r - %s (|cffffcc00%s|r)', i, tex.name, tex.path, tex.layer))
		end
	end

	-- /framelist [copyChat] [showHidden] [showRegions] [showAnchors] - Enhanced fstack
	SLASH_FRAMELIST1 = '/framelist'
	SlashCmdList['FRAMELIST'] = function(msg)
		local args = { strsplit(' ', msg) }
		local copyChat = args[1] and (args[1]:lower() == 'true' or args[1] == '1')
		local showHidden = args[2] and (args[2]:lower() == 'true' or args[2] == '1')
		local showRegions = args[3] and (args[3]:lower() == 'true' or args[3] == '1')
		local showAnchors = args[4] and (args[4]:lower() == 'true' or args[4] == '1')

		-- Get the frame stack at mouse position
		local frames = { GetMouseFoci() }

		if #frames == 0 then
			LibAT:Print('No frames found under mouse cursor')
			return
		end

		local output = {}
		table.insert(output, '|cff00ff00Frame Stack:|r')

		for i, frame in ipairs(frames) do
			if frame and (not frame.IsVisible or frame:IsVisible() or showHidden) then
				local name = 'Unnamed'
				if frame.GetName then
					name = frame:GetName() or 'Unnamed'
				end
				local objectType = 'Unknown'
				if frame.GetObjectType then
					objectType = frame:GetObjectType()
				end
				local visible = 'Unknown'
				if frame.IsVisible then
					visible = frame:IsVisible() and 'Visible' or 'Hidden'
				end

				table.insert(output, string.format('  %d. |cff00ccff%s|r (|cffffcc00%s|r) - %s', i, name, objectType, visible))

				-- Show regions if requested
				if showRegions and frame.GetRegions then
					local regions = { frame:GetRegions() }
					for j, region in ipairs(regions) do
						if region then
							local regionName = 'Unnamed'
							if region.GetName then
								regionName = region:GetName() or 'Unnamed'
							end
							local regionType = 'Unknown'
							if region.GetObjectType then
								regionType = region:GetObjectType()
							end
							table.insert(output, string.format('     Region %d: |cffcccccc%s|r (|cffcccc00%s|r)', j, regionName, regionType))
						end
					end
				end

				-- Show anchors if requested
				if showAnchors and frame.GetPoint then
					local numPoints = 0
					if frame.GetNumPoints then
						numPoints = frame:GetNumPoints()
					end
					if numPoints > 0 then
						for j = 1, numPoints do
							local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(j)
							local relativeToName = relativeTo and (relativeTo:GetName() or 'UIParent') or 'UIParent'
							table.insert(
								output,
								string.format('     Anchor %d: |cff00ff00%s|r to |cff00ccff%s|r |cff00ff00%s|r (%.2f, %.2f)', j, point, relativeToName, relativePoint, xOffset or 0, yOffset or 0)
							)
						end
					end
				end
			end
		end

		-- Output to chat or console
		for _, line in ipairs(output) do
			LibAT:Print(line)
		end

		if copyChat then
			LibAT:Print('Use Ctrl+C to copy the output')
		end
	end
end

---Initialize the DevTools module (called by Ace3)
function DevTools:OnInitialize() end

---Enable the DevTools module (called by Ace3)
function DevTools:OnEnable()
	-- Register slash commands
	RegisterSlashCommands()

	-- Setup TableAttributeDisplay hooks
	SetupTableInspectorHooks()
end
