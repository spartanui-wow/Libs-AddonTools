---@class LibAT.Logger
local LibAT = _G.LibAT
if not LibAT then return end

local Logger = {}
LibAT.Systems.Logger = Logger

-- Phase 1: Preserve external API compatibility while implementing basic functionality
-- Phase 5 will implement the full AuctionHouse-styled UI and hierarchical categorization

----------------------------------------------------------------------------------------------------
-- Type Definitions for Logger System (preserved from original)
----------------------------------------------------------------------------------------------------

---@alias LogLevel
---| "debug"    # Detailed debugging information
---| "info"     # General informational messages
---| "warning"  # Warning conditions
---| "error"    # Error conditions
---| "critical" # Critical system failures

---Logger function returned by RegisterAddon
---@alias SimpleLogger fun(message: string, level?: LogLevel): nil

---Logger table returned by RegisterAddonCategory
---@alias ComplexLoggers table<string, SimpleLogger>

-- Log levels with colors, priorities, and display names
local LOG_LEVELS = {
    ['debug'] = {color = '|cff888888', priority = 1, display = 'Debug'},
    ['info'] = {color = '|cff00ff00', priority = 2, display = 'Info'},
    ['warning'] = {color = '|cffffff00', priority = 3, display = 'Warning'},
    ['error'] = {color = '|cffff0000', priority = 4, display = 'Error'},
    ['critical'] = {color = '|cffff00ff', priority = 5, display = 'Critical'}
}

-- Global and per-module log level settings
local GlobalLogLevel = 2 -- Default to 'info' and above
local ModuleLogLevels = {} -- Per-module overrides

-- Registration system for external addons (preserved API)
local RegisteredAddons = {} -- Simple addons registered under "External Addons"
local AddonCategories = {} -- Complex addons with custom categories
local AddonLoggers = {} -- Cache of logger functions by addon name

-- Storage for log messages
local LogMessages = {}

----------------------------------------------------------------------------------------------------
-- External API - Preserved from SpartanUI for compatibility
----------------------------------------------------------------------------------------------------

---Register a simple addon for logging under "External Addons" category
---@param addonName string Name of the addon to register
---@return SimpleLogger logger Logger function that takes (message, level?)
function LibAT.Logger.RegisterAddon(addonName)
    -- Protect against incorrect colon syntax: LibAT.Logger:RegisterAddon()
    if type(addonName) == 'table' and addonName == LibAT.Logger then
        error('RegisterAddon: Called with colon syntax (:) - use dot syntax (.) instead: LibAT.Logger.RegisterAddon(addonName)')
    end

    if not addonName or addonName == '' or type(addonName) ~= 'string' then
        error('RegisterAddon: addonName must be a non-empty string')
    end

    -- Store registration
    RegisteredAddons[addonName] = true

    -- Create and cache logger function
    local loggerFunc = function(message, level)
        Logger.Log(message, addonName, level)
    end

    AddonLoggers[addonName] = loggerFunc

    -- Initialize in database if logger is ready
    if LibAT.DB and LibAT.DB.logger then
        LibAT.DB.logger.modules[addonName] = true
    end

    return loggerFunc
end

---Register an addon with its own expandable category and subcategories
---@param addonName string Name of the addon (will be the category name)
---@param subcategories string[] Array of subcategory names
---@return ComplexLoggers loggers Table of logger functions keyed by subcategory name
function LibAT.Logger.RegisterAddonCategory(addonName, subcategories)
    -- Protect against incorrect colon syntax: LibAT.Logger:RegisterAddonCategory()
    if type(addonName) == 'table' and addonName == LibAT.Logger then
        error('RegisterAddonCategory: Called with colon syntax (:) - use dot syntax (.) instead: LibAT.Logger.RegisterAddonCategory(addonName, subcategories)')
    end

    if not addonName or addonName == '' or type(addonName) ~= 'string' then
        error('RegisterAddonCategory: addonName must be a non-empty string')
    end
    if not subcategories or type(subcategories) ~= 'table' or #subcategories == 0 then
        error('RegisterAddonCategory: subcategories must be a non-empty array')
    end

    -- Validate all subcategory names are strings
    for i, subcat in ipairs(subcategories) do
        if type(subcat) ~= 'string' or subcat == '' then
            error('RegisterAddonCategory: subcategory at index ' .. i .. ' must be a non-empty string, got: ' .. type(subcat))
        end
        -- Check for invalid characters that could cause parsing issues
        if subcat:find('%.') then
            error('RegisterAddonCategory: subcategory "' .. subcat .. '" cannot contain dots (.) as they are used for hierarchy parsing')
        end
    end

    -- Validate addonName doesn't contain problematic characters
    if addonName:find('%.') then
        error('RegisterAddonCategory: addonName "' .. addonName .. '" cannot contain dots (.) as they are used for hierarchy parsing')
    end

    -- Store category registration
    AddonCategories[addonName] = {
        subcategories = subcategories,
        expanded = false
    }

    -- Create logger functions for each subcategory
    local loggers = {}
    for _, subcat in ipairs(subcategories) do
        local moduleName = addonName .. '.' .. subcat
        loggers[subcat] = function(message, level)
            Logger.Log(message, moduleName, level)
        end

        -- Initialize in database if logger is ready
        if LibAT.DB and LibAT.DB.logger then
            LibAT.DB.logger.modules[moduleName] = true
        end
    end

    -- Cache the logger table
    AddonLoggers[addonName] = loggers

    return loggers
end

----------------------------------------------------------------------------------------------------
-- Core Logging Functions
----------------------------------------------------------------------------------------------------

---Enhanced logging function with log levels
---@param debugText string The message to log
---@param module string The module name
---@param level? LogLevel Log level - defaults to 'info'
function Logger.Log(debugText, module, level)
    level = level or 'info'

    -- Validate module name to prevent invalid entries
    if type(module) ~= 'string' or module == '' then
        -- Log to a fallback module name and issue a warning
        module = 'InvalidModule'
        debugText = 'Invalid module name provided to Logger.Log: ' .. tostring(debugText)
        level = 'warning'
    end

    -- Initialize module if it doesn't exist
    if not LogMessages[module] then
        LogMessages[module] = {}
        if LibAT.DB and LibAT.DB.logger then
            LibAT.DB.logger.modules[module] = true
        end
    end

    -- Validate log level
    local logLevel = LOG_LEVELS[level]
    if not logLevel then
        level = 'info'
        logLevel = LOG_LEVELS[level]
    end

    -- Create log entry with timestamp and level
    local timestamp = date('%H:%M:%S')
    local coloredLevel = logLevel.color .. '[' .. logLevel.display:upper() .. ']|r'
    local formattedMessage = timestamp .. ' ' .. coloredLevel .. ' ' .. tostring(debugText)

    -- Store the log entry
    local logEntry = {
        timestamp = GetTime(),
        level = level,
        message = tostring(debugText),
        formattedMessage = formattedMessage
    }

    table.insert(LogMessages[module], logEntry)

    -- Maintain maximum log history
    local maxHistory = (LibAT.DB and LibAT.DB.logger and LibAT.DB.logger.maxLogHistory) or 1000
    if #LogMessages[module] > maxHistory then
        table.remove(LogMessages[module], 1)
    end

    -- Simple console output for Phase 1
    if logLevel.priority >= GlobalLogLevel then
        LibAT:Print("[" .. module .. "] " .. formattedMessage)
    end
end

-- Compatibility function to maintain existing LibAT.Log calls
function LibAT.Log(debugText, module, level)
    Logger.Log(debugText, module, level)
end

-- Compatibility function to maintain existing LibAT.Debug calls
function LibAT.Debug(debugText, module, level)
    Logger.Log(debugText, module, level)
end

----------------------------------------------------------------------------------------------------
-- Basic UI Functions (Phase 1 - Simple Implementation)
----------------------------------------------------------------------------------------------------

local LogWindow = nil

local function CreateBasicLogWindow()
    if LogWindow then return end

    LogWindow = CreateFrame('Frame', 'LibATLogWindow', UIParent, 'ButtonFrameTemplate')
    ButtonFrameTemplate_HidePortrait(LogWindow)
    LogWindow:SetSize(600, 400)
    LogWindow:SetPoint('CENTER')
    LogWindow:SetFrameStrata('HIGH')
    LogWindow:Hide()

    -- Make the window movable
    LogWindow:SetMovable(true)
    LogWindow:EnableMouse(true)
    LogWindow:RegisterForDrag('LeftButton')
    LogWindow:SetScript('OnDragStart', LogWindow.StartMoving)
    LogWindow:SetScript('OnDragStop', LogWindow.StopMovingOrSizing)

    -- Set title
    LogWindow:SetTitle('LibAT Logging (Phase 1 - Basic)')

    -- Create simple text display
    local scrollFrame = CreateFrame('ScrollFrame', nil, LogWindow, 'UIPanelScrollFrameTemplate')
    scrollFrame:SetPoint('TOPLEFT', LogWindow, 'TOPLEFT', 10, -30)
    scrollFrame:SetPoint('BOTTOMRIGHT', LogWindow, 'BOTTOMRIGHT', -30, 40)

    local editBox = CreateFrame('EditBox', nil, scrollFrame)
    editBox:SetMultiLine(true)
    editBox:SetFontObject('GameFontHighlightSmall')
    editBox:SetText('LibAT Logger - Phase 1 Basic Implementation\n\nFull AuctionHouse-styled UI will be implemented in Phase 5.\n\n')
    editBox:SetWidth(scrollFrame:GetWidth() - 20)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    scrollFrame:SetScrollChild(editBox)

    LogWindow.editBox = editBox

    -- Close button
    local closeButton = CreateFrame('Button', nil, LogWindow, 'UIPanelButtonTemplate')
    closeButton:SetSize(80, 22)
    closeButton:SetPoint('BOTTOMRIGHT', LogWindow, 'BOTTOMRIGHT', -10, 10)
    closeButton:SetText('Close')
    closeButton:SetScript('OnClick', function()
        LogWindow:Hide()
    end)

    -- Update display with current logs
    local function UpdateDisplay()
        local displayText = 'LibAT Logger - Phase 1 Basic Implementation\n\n'
        displayText = displayText .. 'Registered Addons: ' .. #RegisteredAddons .. '\n'
        displayText = displayText .. 'Addon Categories: ' .. #AddonCategories .. '\n\n'

        for module, logs in pairs(LogMessages) do
            if #logs > 0 then
                displayText = displayText .. '=== ' .. module .. ' (' .. #logs .. ' entries) ===\n'
                for i = math.max(1, #logs - 5), #logs do
                    local entry = logs[i]
                    if entry then
                        displayText = displayText .. entry.formattedMessage .. '\n'
                    end
                end
                displayText = displayText .. '\n'
            end
        end

        editBox:SetText(displayText)
    end

    UpdateDisplay()
    LogWindow.UpdateDisplay = UpdateDisplay
end

function Logger.ToggleWindow()
    CreateBasicLogWindow()
    if LogWindow:IsVisible() then
        LogWindow:Hide()
    else
        LogWindow.UpdateDisplay()
        LogWindow:Show()
    end
end

----------------------------------------------------------------------------------------------------
-- Initialization
----------------------------------------------------------------------------------------------------

function Logger:Initialize()
    -- This will be called by LibAT after its OnInitialize when DB is ready
    if not LibAT.DB or not LibAT.DB.logger then
        error("Logger:Initialize called before LibAT.DB is ready")
    end

    GlobalLogLevel = LibAT.DB.logger.globalLogLevel or 2
    ModuleLogLevels = LibAT.DB.logger.moduleLogLevels or {}

    -- Register with LibAT
    LibAT:RegisterSystem("Logger", self)

    -- Create slash commands
    SLASH_LIBATLOGS1 = '/libatlogs'
    SlashCmdList['LIBATLOGS'] = Logger.ToggleWindow

    LibAT:Print("Logger system initialized (Phase 1 - Basic functionality)")
    LibAT:Print("External API preserved - third-party addons can use LibAT.Logger.RegisterAddon() and LibAT.Logger.RegisterAddonCategory()")
end

return Logger