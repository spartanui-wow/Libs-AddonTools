---@class LibATErrorDisplay
local ErrorDisplay = _G.LibATErrorDisplay

-- Localization
local L = {
    ["BugGrabber is required for LibAT error handling."] = "BugGrabber is required for LibAT error handling.",
    ["LibAT Error"] = "LibAT Error",
    ["New error captured. Type /libat errors to view."] = "New error captured. Type /libat errors to view.",
    ["|cffffffffLibAT|r: All stored errors have been wiped."] = "|cffffffffLibAT|r: All stored errors have been wiped.",
}

ErrorDisplay.ErrorHandler = {}

local errorDB = {}
local sessionList = {}
local MAX_ERRORS = 1000
local currentSession = nil

local function colorStack(ret)
    ret = tostring(ret) or ''

    -- Color string literals
    ret = ret:gsub('"([^"]+)"', '"|cffCE9178%1|r"')

    -- Color the file name (keeping the extension .lua in the same color)
    ret = ret:gsub('/([^/]+%.lua)', '/|cff4EC9B0%1|r')

    -- Color the full path, with non-important parts in light grey
    ret =
        ret:gsub(
        '(%[)(@?)([^%]]+)(%])',
        function(open, at, path, close)
            -- Color 'string' purple when it's the first word in the path
            local coloredPath = path:gsub('^(string%s)', '|cffC586C0%1|r')
            return '|r' .. open .. at .. '|r|cffCE9178' .. coloredPath:gsub('"', '|r"|r') .. '|r' .. close .. '|r'
        end
    )

    -- Color partial paths
    ret = ret:gsub('(<%.%.%.%S+/)', '|cffCE9178%1|r')

    -- Color line numbers
    ret = ret:gsub(':(%d+)', ':|cffD7BA7D%1|r')

    -- Color error messages (main error text)
    ret =
        ret:gsub(
        '([^:\n]+):([^\n]*)',
        function(prefix, message)
            if not prefix:match('[/\\]') and not prefix:match('^%d+$') then
                return '|cffFF5252' .. prefix .. ':' .. message .. '|r'
            else
                return '|cffCE9178' .. prefix .. ':|r|cffFF5252' .. message .. '|r'
            end
        end
    )

    -- Color method names, function calls, and variables orange
    ret = ret:gsub("'([^']+)'", "|cffFFA500'%1'|r|r")
    ret = ret:gsub('`([^`]+)`', '|cffFFA500`%1`|r|r')
    ret = ret:gsub("`([^`]+)'", '|cffFFA500`%1`|r|r')
    ret = ret:gsub('(%([^)]+%))', '|cffFFA500%1|r|r')
    ret = ret:gsub('([%w_]+:[%w_]+)', '|cffFFA500%1|r')

    -- Color Lua keywords purple, 'in' grey
    local keywords = {
        ['and'] = true,
        ['break'] = true,
        ['do'] = true,
        ['else'] = true,
        ['elseif'] = true,
        ['end'] = true,
        ['false'] = true,
        ['for'] = true,
        ['function'] = true,
        ['if'] = true,
        ['local'] = true,
        ['nil'] = true,
        ['not'] = true,
        ['or'] = true,
        ['repeat'] = true,
        ['return'] = true,
        ['then'] = true,
        ['true'] = true,
        ['until'] = true,
        ['while'] = true,
        ['boolean'] = true,
        ['string'] = true
    }
    ret =
        ret:gsub(
        '%f[%w](%a+)%f[%W]',
        function(word)
            if keywords[word] then
                return '|cffC586C0' .. word .. '|r'
            elseif word == 'in' then
                return '|r' .. word .. '|r'
            end
            return word
        end
    )

    -- Color the error count at the start
    ret = ret:gsub('^(%d+x)', '|cffa6fd79%1|r')

    return ret
end

local function colorLocals(ret)
    ret = tostring(ret) or ''
    -- Remove temporary nil and table lines
    ret = ret:gsub('%(%*temporary%) = nil\n', '')
    ret = ret:gsub('%(%*temporary%) = <table> {.-}\n', '')

    ret = ret:gsub('[%.I][%.n][%.t][%.e][%.r]face\\', '')
    ret = ret:gsub('%.?%.?%.?\\?AddOns\\', '')
    ret = ret:gsub('|(%a)', '||%1'):gsub('|$', '||') -- Pipes

    -- File paths and line numbers
    ret = ret:gsub('> %@(.-):(%d+)', '> @|cff4EC9B0%1|r:|cffD7BA7D%2|r')

    -- Variable names
    ret = ret:gsub('(%s-)([%a_][%w_]*) = ', '%1|cff9CDCFE%2|r = ')

    -- Numbers
    ret = ret:gsub('= (%-?%d+%.?%d*)\n', '= |cffB5CEA8%1|r\n')

    -- nil, true, false
    ret = ret:gsub('= (nil)\n', '= |cff569CD6%1|r\n')
    ret = ret:gsub('= (true)\n', '= |cff569CD6%1|r\n')
    ret = ret:gsub('= (false)\n', '= |cff569CD6%1|r\n')

    -- Strings
    ret = ret:gsub('= (".-")\n', '= |cffCE9178%1|r\n')
    ret = ret:gsub("= ('.-')\n", '= |cffCE9178%1|r\n')

    -- Tables and functions
    ret = ret:gsub('= (<.->)', '= |cffDCDCAA%1|r')

    return ret
end

function ErrorDisplay.ErrorHandler:Initialize()
    if not BugGrabber then
        print(L['BugGrabber is required for LibAT error handling.'])
        return
    end

    -- Load persistent error database
    errorDB = ErrorDisplay.Config:GetErrorDatabase()

    -- Initialize our own session tracking
    if ErrorDisplay.Config:ShouldIncrementSession() then
        currentSession = ErrorDisplay.Config:IncrementSession()
        print('LibAT Error Display: Starting new session #' .. currentSession)
    else
        currentSession = ErrorDisplay.Config:GetCurrentSession()
    end

    -- Update session list
    if not tContains(sessionList, currentSession) then
        table.insert(sessionList, currentSession)
    end

    -- Register with BugGrabber
    BugGrabber.RegisterCallback(self, 'BugGrabber_BugGrabbed', 'OnBugGrabbed')

    -- Grab any errors that occurred before we loaded
    local existingErrors = BugGrabber:GetDB()
    for _, err in ipairs(existingErrors) do
        -- Check if we've already processed this error by looking for it in our errorDB
        local alreadyProcessed = false
        for _, existingErr in ipairs(errorDB) do
            if existingErr.message == err.message and
               existingErr.stack == err.stack and
               existingErr.time == err.time then
                alreadyProcessed = true
                break
            end
        end

        -- Only process new errors from BugGrabber
        if not alreadyProcessed then
            self:ProcessError(err)
        end
    end
end

function ErrorDisplay.ErrorHandler:ColorText(text)
    text = colorLocals(text)
    text = colorStack(text)
    return text
end

function ErrorDisplay.ErrorHandler:OnBugGrabbed(callback, errorObject)
    -- Debug: Show that we're capturing a new error in current session
    if ErrorDisplay.db.chatframe ~= false then
        print('LibAT: New error captured in session #' .. currentSession)
    end

    self:ProcessError(errorObject)
    -- Check if the error window is shown and update the display
    if ErrorDisplay.BugWindow.window and ErrorDisplay.BugWindow.window:IsShown() then
        ErrorDisplay.BugWindow:updateDisplay(true)
    end
end

function ErrorDisplay.ErrorHandler:ProcessError(errorObject)
    local err = {
        message = errorObject.message,
        stack = errorObject.stack,
        locals = errorObject.locals,
        time = errorObject.time,
        session = currentSession, -- Always assign to current session
        counter = 1
    }

    -- Check for duplicate errors
    for i = #errorDB, 1, -1 do
        local oldErr = errorDB[i]
        if oldErr.message == err.message and oldErr.stack == err.stack then
            oldErr.counter = (oldErr.counter or 1) + 1
            return
        end
    end

    -- Add new error
    table.insert(errorDB, err)

    -- Trim old errors if necessary
    if #errorDB > MAX_ERRORS then
        table.remove(errorDB, 1)
    end

    -- Save to persistent storage
    ErrorDisplay.Config:SaveErrorDatabase(errorDB)

    -- Trigger the onError function from the main addon file
    if ErrorDisplay.OnError then
        ErrorDisplay.OnError()
    end
end

function ErrorDisplay.ErrorHandler:CaptureError(errorObject)
    local err = {
        message = errorObject.message,
        stack = errorObject.stack,
        locals = errorObject.locals,
        time = errorObject.time,
        session = currentSession, -- Always assign to current session
        counter = 1
    }

    -- Check for duplicate errors
    for i = #errorDB, 1, -1 do
        local oldErr = errorDB[i]
        if oldErr.message == err.message and oldErr.stack == err.stack then
            oldErr.counter = (oldErr.counter or 1) + 1
            return
        end
    end

    -- Add new error
    table.insert(errorDB, err)

    -- Trim old errors if necessary
    if #errorDB > MAX_ERRORS then
        table.remove(errorDB, 1)
    end

    -- Save to persistent storage
    ErrorDisplay.Config:SaveErrorDatabase(errorDB)

    -- Auto popup if enabled
    if ErrorDisplay.db.autoPopup then
        ErrorDisplay.BugWindow:OpenErrorWindow()
    end

    -- Print to chat if enabled
    if ErrorDisplay.db.chatframe ~= false then
        print('|cffff4411' .. L['LibAT Error'] .. ':|r ' .. L['New error captured. Type /libat errors to view.'])
    end
end

function ErrorDisplay.ErrorHandler:GetErrors(sessionId)
    if not sessionId then
        return errorDB
    end
    local sessionErrors = {}
    for _, err in ipairs(errorDB) do
        if err.session == sessionId then
            table.insert(sessionErrors, err)
        end
    end
    return sessionErrors
end

function ErrorDisplay.ErrorHandler:GetCurrentSession()
    return currentSession
end

function ErrorDisplay.ErrorHandler:GetSessionList()
    -- Return list of sessions that have errors, plus current session
    local sessionsWithErrors = {}
    for _, err in ipairs(errorDB) do
        if err.session and not tContains(sessionsWithErrors, err.session) then
            table.insert(sessionsWithErrors, err.session)
        end
    end

    -- Ensure current session is included
    if not tContains(sessionsWithErrors, currentSession) then
        table.insert(sessionsWithErrors, currentSession)
    end

    -- Sort sessions
    table.sort(sessionsWithErrors)
    return sessionsWithErrors
end

function ErrorDisplay.ErrorHandler:GetSessionInfo(sessionId)
    local sessionHistory = ErrorDisplay.Config:GetSessionHistory()
    for _, session in ipairs(sessionHistory) do
        if session.id == sessionId then
            return session
        end
    end

    -- If not found in history, return basic info
    if sessionId == currentSession then
        return {
            id = sessionId,
            startTime = time(),
            gameTime = GetTime(),
            playerName = UnitName('player'),
            realmName = GetRealmName(),
            buildInfo = select(1, GetBuildInfo()),
            isCurrent = true
        }
    end

    return {
        id = sessionId,
        startTime = nil,
        gameTime = nil,
        playerName = 'Unknown',
        realmName = 'Unknown',
        buildInfo = 'Unknown'
    }
end

function ErrorDisplay.ErrorHandler:GetSessionsWithInfo()
    local sessions = self:GetSessionList()
    local sessionData = {}

    for _, sessionId in ipairs(sessions) do
        local info = self:GetSessionInfo(sessionId)
        local errorCount = #self:GetErrors(sessionId)

        table.insert(sessionData, {
            id = sessionId,
            info = info,
            errorCount = errorCount,
            isCurrent = sessionId == currentSession
        })
    end

    return sessionData
end

function ErrorDisplay.ErrorHandler:FormatError(err)
    local s = ErrorDisplay.ErrorHandler:ColorText(tostring(err.message) .. (err.stack and '\n' .. tostring(err.stack) or ''))
    local l = colorLocals(tostring(err.locals))
    return string.format('%dx %s\n\nLocals:\n%s', err.counter or 1, s, l)
end

function ErrorDisplay.ErrorHandler:Reset()
    wipe(errorDB)
    wipe(sessionList)
    ErrorDisplay.Config:ClearErrorDatabase()
    self:Initialize()
    print(L['|cffffffffLibAT|r: All stored errors have been wiped.'])
end

return ErrorDisplay.ErrorHandler