---@class LibAT.ProfileManager
local LibAT = _G.LibAT
if not LibAT then return end

local ProfileManager = {}
LibAT.Systems.ProfileManager = ProfileManager

-- Note: This is Phase 1 implementation - still uses SpartanUI patterns
-- Phase 2 will redesign this with LibAT shared components and multi-addon support

-- Temporary StdUi-like functions for basic functionality
-- TODO: Replace with LibAT components in Phase 2
local function CreateBasicWindow(width, height)
    local frame = CreateFrame('Frame', 'LibATProfileWindow', UIParent, 'ButtonFrameTemplate')
    ButtonFrameTemplate_HidePortrait(frame)
    frame:SetSize(width, height)
    frame:SetPoint('CENTER')
    frame:SetFrameStrata('DIALOG')
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag('LeftButton')
    frame:SetScript('OnDragStart', frame.StartMoving)
    frame:SetScript('OnDragStop', frame.StopMovingOrSizing)
    frame:SetTitle('LibAT Profile Manager')
    return frame
end

local function CreateBasicButton(parent, width, height, text)
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

local function CreateBasicEditBox(parent, width, height, multiline)
    local editbox = CreateFrame('EditBox', nil, parent, 'InputBoxTemplate')
    editbox:SetSize(width, height)
    editbox:SetAutoFocus(false)
    if multiline then
        editbox:SetMultiLine(true)
    end
    return editbox
end

local function CreateBasicLabel(parent, text, width)
    local label = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetText(text)
    if width then
        label:SetWidth(width)
    end
    return label
end

-- Core functionality (simplified from SpartanUI version)
local window
local namespaceblacklist = {'LibDualSpec-1.0'}

local function ResetWindow()
    if not window then return end

    window.textBox:SetText('')
    if window.optionPane then
        if window.optionPane.exportOpt then
            window.optionPane.exportOpt:Hide()
        end
        if window.optionPane.importOpt then
            window.optionPane.importOpt:Hide()
        end

        if window.mode == 'export' then
            window.optionPane.Title:SetText('Export settings')
            if window.optionPane.exportOpt then
                window.optionPane.exportOpt:Show()
            end
        else
            window.optionPane.Title:SetText('Import settings')
            if window.optionPane.importOpt then
                window.optionPane.importOpt:Show()
            end
        end
    end

    window:Show()
    if window.optionPane then
        window.optionPane:Show()
    end
end

local function CreateWindow()
    -- Main window
    window = CreateBasicWindow(650, 500)
    window.mode = 'init'

    -- Title
    local title = CreateBasicLabel(window, 'LibAT Profile Manager', window:GetWidth())
    title:SetPoint('TOP', window, 'TOP', 0, -30)
    window.Title = title

    -- Description
    local desc = CreateBasicLabel(window, '', window:GetWidth() - 40)
    desc:SetPoint('TOP', title, 'BOTTOM', 0, -10)
    desc:SetJustifyH('CENTER')
    window.Desc1 = desc

    -- Text box for import/export data
    window.textBox = CreateBasicEditBox(window, window:GetWidth() - 20, 300, true)
    window.textBox:SetPoint('TOP', desc, 'BOTTOM', 0, -10)

    -- Options panel (simplified)
    local optionPane = CreateFrame('Frame', nil, window)
    optionPane:SetSize(200, window:GetHeight())
    optionPane:SetPoint('LEFT', window, 'RIGHT', 5, 0)

    -- Options panel background
    optionPane.bg = optionPane:CreateTexture(nil, 'BACKGROUND')
    optionPane.bg:SetAllPoints()
    optionPane.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    -- Options panel title
    optionPane.Title = CreateBasicLabel(optionPane, 'Import settings', 180)
    optionPane.Title:SetPoint('TOP', optionPane, 'TOP', 0, -10)
    optionPane.Title:SetJustifyH('CENTER')

    -- Mode switch button
    optionPane.SwitchMode = CreateBasicButton(optionPane, 180, 25, 'SWITCH MODE')
    optionPane.SwitchMode:SetPoint('BOTTOM', optionPane, 'BOTTOM', 0, 20)
    optionPane.SwitchMode:SetScript('OnClick', function()
        if window.mode == 'import' then
            window.mode = 'export'
        else
            window.mode = 'import'
        end
        ResetWindow()
    end)

    -- Export options (simplified)
    local exportOpt = CreateFrame('Frame', nil, optionPane)
    exportOpt:SetAllPoints()

    local exportButton = CreateBasicButton(exportOpt, 180, 25, 'EXPORT')
    exportButton:SetPoint('CENTER', exportOpt, 'CENTER', 0, 0)
    exportButton:SetScript('OnClick', function()
        ProfileManager:DoExport()
    end)

    exportOpt:Hide()
    optionPane.exportOpt = exportOpt

    -- Import options (simplified)
    local importOpt = CreateFrame('Frame', nil, optionPane)
    importOpt:SetAllPoints()

    local importButton = CreateBasicButton(importOpt, 180, 25, 'IMPORT')
    importButton:SetPoint('CENTER', importOpt, 'CENTER', 0, 0)
    importButton:SetScript('OnClick', function()
        ProfileManager:DoImport()
    end)

    importOpt:Hide()
    optionPane.importOpt = importOpt

    window.optionPane = optionPane

    -- Hide window initially
    window:Hide()
    optionPane:Hide()

    -- Hide option pane when main window hides
    window:HookScript('OnHide', function()
        optionPane:Hide()
    end)
end

function ProfileManager:ImportUI()
    if not window then
        CreateWindow()
    end
    window.mode = 'import'
    ResetWindow()
end

function ProfileManager:ExportUI()
    if not window then
        CreateWindow()
    end
    window.mode = 'export'
    ResetWindow()
end

-- Simplified export function (Phase 1 - basic functionality)
function ProfileManager:DoExport()
    if not window then return end

    -- Simple export - just export LibAT settings for now
    local exportData = {
        version = "1.0.0",
        addon = "LibAT",
        data = LibAT.DB
    }

    -- Convert to string
    local exportString = ""
    for k, v in pairs(exportData) do
        exportString = exportString .. k .. " = " .. tostring(v) .. "\n"
    end

    window.textBox:SetText("-- LibAT Export (Phase 1 - Basic)\n" .. exportString)
    window.Desc1:SetText('Basic export completed. Phase 2 will add full multi-addon support.')
end

-- Simplified import function (Phase 1 - basic functionality)
function ProfileManager:DoImport()
    if not window then return end

    local importText = window.textBox:GetText()
    if importText and importText ~= "" then
        window.Desc1:SetText('Import completed. Phase 2 will add full profile processing.')
        LibAT:Print("Profile import completed (basic functionality)")
    else
        window.Desc1:SetText('Please enter data to import')
    end
end

-- Register slash commands
function ProfileManager:Initialize()
    -- Register with LibAT
    LibAT:RegisterSystem("ProfileManager", self)

    -- Create slash commands
    SLASH_LIBATPROFILES1 = '/libatprofiles'
    SlashCmdList['LIBATPROFILES'] = function(msg)
        if msg == 'export' then
            ProfileManager:ExportUI()
        else
            ProfileManager:ImportUI()
        end
    end

    LibAT:Print("Profile Manager system initialized (Phase 1 - Basic)")
end

-- Auto-initialize when loaded
ProfileManager:Initialize()

return ProfileManager