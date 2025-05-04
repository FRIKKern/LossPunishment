local addonName, addonTable = ...

-- Ensure the addon's namespace exists
LossPunishment = LossPunishment or {}
local LP = LossPunishment

-- Helper function to check if a date is within a specific time period
function LP:IsWithinTimePeriod(timestamp, period)
    if not timestamp then return false end
    
    local now = time()
    local dateTable = date("*t", now)
    local today = time({year = dateTable.year, month = dateTable.month, day = dateTable.day, hour = 0, min = 0, sec = 0})
    
    -- Parse the timestamp (format: "YYYY-MM-DD HH:MM:SS")
    local year, month, day, hour, min, sec = timestamp:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if not year then return false end
    
    local timestampTime = time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
    
    if period == "today" then
        return timestampTime >= today
    elseif period == "week" then
        -- Start of the week (Monday)
        local dayOfWeek = dateTable.wday - 1 -- 0 (Sun) through 6 (Sat)
        if dayOfWeek == 0 then dayOfWeek = 7 end -- Convert Sunday from 0 to 7
        local startOfWeek = today - ((dayOfWeek - 1) * 86400) -- Convert to Monday
        return timestampTime >= startOfWeek
    elseif period == "month" then
        -- Start of the month
        local startOfMonth = time({year = dateTable.year, month = dateTable.month, day = 1, hour = 0, min = 0, sec = 0})
        return timestampTime >= startOfMonth
    else
        -- All time - always true
        return true
    end
end

-- Function to calculate statistics for different time periods
function LP:CalculateStats()
    local stats = {
        today = { Pushups = 0, Squats = 0, Situps = 0, total = 0 },
        week = { Pushups = 0, Squats = 0, Situps = 0, total = 0 },
        month = { Pushups = 0, Squats = 0, Situps = 0, total = 0 },
        allTime = { Pushups = 0, Squats = 0, Situps = 0, total = 0 }
    }
    
    -- Always return initialized stats even if no data exists yet
    if not LP.db or not LP.db.stats then return stats end
    
    -- Ensure all exercise types exist in stats
    LP.db.stats.Pushups = LP.db.stats.Pushups or {}
    LP.db.stats.Squats = LP.db.stats.Squats or {}
    LP.db.stats.Situps = LP.db.stats.Situps or {}
    
    for exType, timestamps in pairs(LP.db.stats) do
        for _, timestamp in ipairs(timestamps) do
            -- All time
            stats.allTime[exType] = stats.allTime[exType] + 1
            stats.allTime.total = stats.allTime.total + 1
            
            -- Today
            if LP:IsWithinTimePeriod(timestamp, "today") then
                stats.today[exType] = stats.today[exType] + 1
                stats.today.total = stats.today.total + 1
            end
            
            -- This week
            if LP:IsWithinTimePeriod(timestamp, "week") then
                stats.week[exType] = stats.week[exType] + 1
                stats.week.total = stats.week.total + 1
            end
            
            -- This month
            if LP:IsWithinTimePeriod(timestamp, "month") then
                stats.month[exType] = stats.month[exType] + 1
                stats.month.total = stats.month.total + 1
            end
        end
    end
    
    return stats
end

-- Function to create the history popup window
function LP:CreateHistoryWindow()
    if LP.historyWindow then return LP.historyWindow end -- Return if already exists
    
    -- Create the main window
    local window = CreateFrame("Frame", "LossPunishmentHistoryWindow", UIParent, "BasicFrameTemplateWithInset")
    window:SetSize(450, 500)
    window:SetPoint("CENTER")
    window:SetFrameStrata("HIGH")
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetClampedToScreen(true)
    window:Hide() -- Start hidden
    
    -- Set title
    window.TitleText:SetText("Exercise History")
    
    -- Filter Buttons
    local filterFrame = CreateFrame("Frame", "LossPunishmentHistoryFilterFrame", window)
    filterFrame:SetPoint("TOPLEFT", window.InsetBg, "TOPLEFT", 10, -10)
    filterFrame:SetSize(390, 30)

    -- All button
    local allButton = CreateFrame("Button", "LossPunishmentHistoryAllButton", filterFrame, "UIPanelButtonTemplate")
    allButton:SetSize(70, 25)
    allButton:SetPoint("LEFT", filterFrame, "LEFT", 0, 0)
    allButton:SetText("All")
    
    -- Pushups button
    local pushupsButton = CreateFrame("Button", "LossPunishmentHistoryPushupsButton", filterFrame, "UIPanelButtonTemplate")
    pushupsButton:SetSize(70, 25)
    pushupsButton:SetPoint("LEFT", allButton, "RIGHT", 10, 0)
    pushupsButton:SetText("Pushups")
    
    -- Squats button
    local squatsButton = CreateFrame("Button", "LossPunishmentHistorySquatsButton", filterFrame, "UIPanelButtonTemplate")
    squatsButton:SetSize(70, 25)
    squatsButton:SetPoint("LEFT", pushupsButton, "RIGHT", 10, 0)
    squatsButton:SetText("Squats")
    
    -- Situps button
    local situpsButton = CreateFrame("Button", "LossPunishmentHistorySitupsButton", filterFrame, "UIPanelButtonTemplate")
    situpsButton:SetSize(70, 25)
    situpsButton:SetPoint("LEFT", squatsButton, "RIGHT", 10, 0)
    situpsButton:SetText("Situps")
    
    -- Column Headers
    local headerFrame = CreateFrame("Frame", "LossPunishmentHistoryHeaderFrame", window)
    headerFrame:SetPoint("TOPLEFT", filterFrame, "BOTTOMLEFT", 0, -5)
    headerFrame:SetSize(390, 25)
    
    -- Headers
    local typeHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    typeHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 15, 0)
    typeHeader:SetText("Type")
    typeHeader:SetWidth(60)
    
    local exerciseHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    exerciseHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 95, 0)
    exerciseHeader:SetText("Exercise")
    exerciseHeader:SetWidth(80)
    
    local dateHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 195, 0)
    dateHeader:SetText("Date & Time")
    dateHeader:SetWidth(140)
    
    -- History List Frame (just border and background)
    local historyFrame = CreateFrame("Frame", "LossPunishmentHistoryListFrame", window, "InsetFrameTemplate")
    historyFrame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, -5)
    historyFrame:SetSize(390, 350)
    
    -- Create a ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "LossPunishmentHistoryScrollFrame", historyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", historyFrame, "TOPLEFT", 5, -5)
    scrollFrame:SetPoint("BOTTOMRIGHT", historyFrame, "BOTTOMRIGHT", -30, 5)
    
    -- Create the scrollable content frame
    local scrollChild = CreateFrame("Frame", "LossPunishmentHistoryScrollChild", scrollFrame)
    scrollFrame:SetScrollChild(scrollChild)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- Will be set dynamically based on content
    
    -- Reset button - Moved from options panel to history window
    local resetButton = CreateFrame("Button", "LossPunishmentHistoryResetButton", window, "UIPanelButtonTemplate")
    resetButton:SetSize(150, 25)
    resetButton:SetPoint("BOTTOM", window, "BOTTOM", 0, 15)
    resetButton:SetText("Reset All Statistics")
    resetButton:SetScript("OnClick", function()
        -- Show confirmation dialog
        StaticPopupDialogs["LOSSPUNISHMENT_CONFIRM_RESET"] = {
            text = "Are you sure you want to reset all exercise statistics?\nThis cannot be undone!",
            button1 = "Yes",
            button2 = "No",
            OnAccept = function()
                -- Reset all stats
                LP.db.stats = { Pushups = {}, Squats = {}, Situps = {} }
                
                -- Refresh the history window
                window:PopulateHistoryList(window.currentFilter or "All")
                
                -- Update the options panel if it's visible
                if LP.optionsPanel and LP.optionsPanel:IsVisible() then
                    LP.optionsPanel.refresh()
                end
                
                print(addonName .. ": Exercise statistics have been reset.")
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("LOSSPUNISHMENT_CONFIRM_RESET")
    end)
    
    -- Current filter
    window.currentFilter = "All"
    
    -- Function to populate history list
    function window:PopulateHistoryList(filter)
        -- Clear previous entries by hiding all existing rows
        if scrollChild.rows then
            for _, row in pairs(scrollChild.rows) do
                row:Hide()
            end
        else
            scrollChild.rows = {}
        end
        
        -- Collect all entries based on filter
        local entries = {}
        
        -- Ensure database exists
        if not LP.db then
            LP.db = {}
        end
        
        if not LP.db.stats then
            LP.db.stats = { Pushups = {}, Squats = {}, Situps = {} }
        end
        
        for exType, timestamps in pairs(LP.db.stats) do
            if filter == "All" or filter == exType then
                for i, timestamp in ipairs(timestamps) do
                    table.insert(entries, {
                        exType = exType,
                        timestamp = timestamp,
                        index = i
                    })
                end
            end
        end
        
        -- Sort entries by timestamp (newest first)
        table.sort(entries, function(a, b)
            return a.timestamp > b.timestamp
        end)
        
        -- Create/update entry rows
        local rowHeight = 20
        local totalHeight = #entries * rowHeight
        
        for i, entry in ipairs(entries) do
            -- Create row if it doesn't exist
            if not scrollChild.rows[i] then
                local row = CreateFrame("Frame", "LossPunishmentHistoryRow" .. i, scrollChild)
                row:SetSize(scrollChild:GetWidth(), rowHeight)
                
                -- Exercise Type
                local typeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                typeText:SetPoint("LEFT", row, "LEFT", 10, 0)
                typeText:SetWidth(60)
                row.typeText = typeText
                
                -- Exercise Number
                local numberText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                numberText:SetPoint("LEFT", row, "LEFT", 90, 0)
                numberText:SetWidth(80)
                row.numberText = numberText
                
                -- Timestamp
                local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                timeText:SetPoint("LEFT", row, "LEFT", 190, 0)
                timeText:SetWidth(140)
                row.timeText = timeText
                
                -- Alternate row coloring for readability
                if i % 2 == 0 then
                    local bg = row:CreateTexture(nil, "BACKGROUND")
                    bg:SetAllPoints()
                    bg:SetColorTexture(0.2, 0.2, 0.2, 0.2)
                end
                
                scrollChild.rows[i] = row
            end
            
            -- Update row data
            local row = scrollChild.rows[i]
            row:Show()
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -rowHeight * (i - 1))
            row.typeText:SetText(entry.exType)
            row.numberText:SetText("10 " .. entry.exType) -- Based on the standard format
            row.timeText:SetText(entry.timestamp)
        end
        
        -- Set scrollchild height
        scrollChild:SetHeight(math.max(totalHeight, 1))
        
        -- Update current filter text in the window title
        window.TitleText:SetText("Exercise History - " .. filter)
        window.currentFilter = filter
    end
    
    -- Set up filter button scripts
    allButton:SetScript("OnClick", function() window:PopulateHistoryList("All") end)
    pushupsButton:SetScript("OnClick", function() window:PopulateHistoryList("Pushups") end)
    squatsButton:SetScript("OnClick", function() window:PopulateHistoryList("Squats") end)
    situpsButton:SetScript("OnClick", function() window:PopulateHistoryList("Situps") end)
    
    -- Close on escape key
    window:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:Hide()
        end
    end)
    window:SetPropagateKeyboardInput(true)
    
    -- Store references
    window.scrollChild = scrollChild
    LP.historyWindow = window
    
    return window
end

-- Function to create the options panel
function LP:CreateOptionsPanel()
    if LP.optionsPanel then return end -- Don't create if it already exists
    
    -- Ensure the database exists and is properly initialized
    if not LP.db then
        LP.db = {}
    end
    
    -- Initialize stats tables if they don't exist
    if not LP.db.stats then
        LP.db.stats = { Pushups = {}, Squats = {}, Situps = {} }
    end
    
    -- Ensure all exercise types exist in stats
    LP.db.stats.Pushups = LP.db.stats.Pushups or {}
    LP.db.stats.Squats = LP.db.stats.Squats or {}
    LP.db.stats.Situps = LP.db.stats.Situps or {}
    
    -- Initialize enabled exercises if they don't exist
    if not LP.db.enabledExercises then
        LP.db.enabledExercises = { Pushups = true, Squats = true, Situps = true }
    end
    
    -- Create the main panel
    local panel = CreateFrame("Frame", "LossPunishmentOptionsPanel")
    panel.name = "LossPunishment"
    
    -- Title
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("LossPunishment Settings")
    
    -- Description
    local description = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetText("Configure exercise options and view your stats.")
    description:SetJustifyH("LEFT")
    
    -- Section Title: Exercise Settings
    local exerciseSettingsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    exerciseSettingsTitle:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -20)
    exerciseSettingsTitle:SetText("Exercise Settings")
    
    -- Pushups checkbox
    local pushupsCheckbox = CreateFrame("CheckButton", "LossPunishmentPushupsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    pushupsCheckbox:SetPoint("TOPLEFT", exerciseSettingsTitle, "BOTTOMLEFT", 0, -10)
    pushupsCheckbox.text = _G[pushupsCheckbox:GetName() .. "Text"]
    pushupsCheckbox.text:SetText("Enable Pushups")
    pushupsCheckbox:SetChecked(LP.db.enabledExercises.Pushups)
    pushupsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Pushups = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Squats checkbox
    local squatsCheckbox = CreateFrame("CheckButton", "LossPunishmentSquatsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    squatsCheckbox:SetPoint("TOPLEFT", pushupsCheckbox, "BOTTOMLEFT", 0, -5)
    squatsCheckbox.text = _G[squatsCheckbox:GetName() .. "Text"]
    squatsCheckbox.text:SetText("Enable Squats")
    squatsCheckbox:SetChecked(LP.db.enabledExercises.Squats)
    squatsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Squats = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Situps checkbox
    local situpsCheckbox = CreateFrame("CheckButton", "LossPunishmentSitupsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    situpsCheckbox:SetPoint("TOPLEFT", squatsCheckbox, "BOTTOMLEFT", 0, -5)
    situpsCheckbox.text = _G[situpsCheckbox:GetName() .. "Text"]
    situpsCheckbox.text:SetText("Enable Situps")
    situpsCheckbox:SetChecked(LP.db.enabledExercises.Situps)
    situpsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Situps = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Section Title: Statistics
    local statsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statsTitle:SetPoint("TOPLEFT", situpsCheckbox, "BOTTOMLEFT", 0, -20)
    statsTitle:SetText("Exercise Statistics (Reps Completed)")
    
    -- Statistics summary frame
    local statsFrame = CreateFrame("Frame", "LossPunishmentStatsFrame", panel, "InsetFrameTemplate")
    statsFrame:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -10)
    statsFrame:SetSize(400, 170) -- Reduced height as we're simplifying the display
    
    -- Create a grid background to help with alignment
    local gridBg = statsFrame:CreateTexture(nil, "BACKGROUND")
    gridBg:SetAllPoints()
    gridBg:SetColorTexture(0.1, 0.1, 0.1, 0.2) -- Very subtle grid background
    
    -- Create period headers
    local periodLabels = {"Today", "This Week", "This Month", "All Time"}
    local periodFontStrings = {}
    
    -- Add horizontal line after headers
    local headerSeparator = statsFrame:CreateTexture(nil, "ARTWORK")
    headerSeparator:SetSize(380, 1)
    headerSeparator:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 10, -30)
    headerSeparator:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    
    -- Exercise Types Column Header
    local typeHeader = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    typeHeader:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 20, -15)
    typeHeader:SetText("Exercise")
    typeHeader:SetJustifyH("LEFT")
    typeHeader:SetWidth(70)
    
    -- Period Headers
    for i, period in ipairs(periodLabels) do
        local periodHeader = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        periodHeader:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 110 + (i-1) * 70, -15)
        periodHeader:SetText(period)
        periodHeader:SetJustifyH("CENTER")
        periodHeader:SetWidth(60)
        periodFontStrings[period] = periodHeader
    end
    
    -- Exercise types
    local exerciseTypes = {"Pushups", "Squats", "Situps"}
    local statsLabels = {}
    local statsValues = {}
    
    for i, exType in ipairs(exerciseTypes) do
        -- Create label
        statsLabels[i] = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        statsLabels[i]:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 20, -40 - (i-1) * 25)
        statsLabels[i]:SetText(exType .. ":")
        statsLabels[i]:SetJustifyH("LEFT")
        statsLabels[i]:SetWidth(70)
        
        -- Create values for each time period
        statsValues[exType] = {}
        for j, period in ipairs(periodLabels) do
            local valueText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            valueText:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 110 + (j-1) * 70, -40 - (i-1) * 25)
            valueText:SetJustifyH("CENTER")
            valueText:SetWidth(60)
            statsValues[exType][period] = valueText
        end
        
        -- Add alternating row backgrounds
        if i % 2 == 1 then
            local rowBg = statsFrame:CreateTexture(nil, "BACKGROUND")
            rowBg:SetSize(380, 25)
            rowBg:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 10, -32 - (i-1) * 25)
            rowBg:SetColorTexture(0.2, 0.2, 0.2, 0.1)
        end
    end
    
    -- Horizontal line before total
    local totalSeparator = statsFrame:CreateTexture(nil, "ARTWORK")
    totalSeparator:SetSize(380, 1)
    totalSeparator:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 10, -40 - (#exerciseTypes * 25))
    totalSeparator:SetColorTexture(0.5, 0.5, 0.5, 0.5)
    
    -- Total row
    local totalLabel = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    totalLabel:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 20, -75 - (#exerciseTypes-1) * 25)
    totalLabel:SetText("TOTAL:")
    totalLabel:SetJustifyH("LEFT")
    totalLabel:SetWidth(70)
    
    -- Total values for each period
    local totalValues = {}
    for j, period in ipairs(periodLabels) do
        local valueText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        valueText:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 110 + (j-1) * 70, -75 - (#exerciseTypes-1) * 25)
        valueText:SetJustifyH("CENTER")
        valueText:SetWidth(60)
        totalValues[period] = valueText
    end
    
    -- View History button
    local viewHistoryButton = CreateFrame("Button", "LossPunishmentViewHistoryButton", panel, "UIPanelButtonTemplate")
    viewHistoryButton:SetSize(150, 25)
    viewHistoryButton:SetPoint("TOP", statsFrame, "BOTTOM", 0, -10)
    viewHistoryButton:SetText("View Detailed History")
    viewHistoryButton:SetScript("OnClick", function()
        -- Create history window if it doesn't exist
        local historyWindow = LP:CreateHistoryWindow()
        
        -- Populate and show the window
        historyWindow:PopulateHistoryList("All")
        historyWindow:Show()
        
        -- Let the window capture keypresses for escape
        historyWindow:SetPropagateKeyboardInput(false)
        historyWindow:EnableKeyboard(true)
        historyWindow:SetFrameStrata("HIGH")
    end)
    
    -- Panel refresh function
    panel.refresh = function()
        pushupsCheckbox:SetChecked(LP.db.enabledExercises.Pushups)
        squatsCheckbox:SetChecked(LP.db.enabledExercises.Squats)
        situpsCheckbox:SetChecked(LP.db.enabledExercises.Situps)
        
        -- Calculate stats for all time periods
        local stats = LP:CalculateStats()
        
        -- Exercise counts - show only the total reps (sessions * 10)
        for i, exType in ipairs(exerciseTypes) do
            statsValues[exType]["Today"]:SetText(stats.today[exType] * 10)
            statsValues[exType]["This Week"]:SetText(stats.week[exType] * 10)
            statsValues[exType]["This Month"]:SetText(stats.month[exType] * 10)
            statsValues[exType]["All Time"]:SetText(stats.allTime[exType] * 10)
        end
        
        -- Total exercises (sessions * 10)
        totalValues["Today"]:SetText(stats.today.total * 10)
        totalValues["This Week"]:SetText(stats.week.total * 10)
        totalValues["This Month"]:SetText(stats.month.total * 10)
        totalValues["All Time"]:SetText(stats.allTime.total * 10)
    end
    
    panel:SetScript("OnShow", panel.refresh)
    
    -- Store the panel reference
    LP.optionsPanel = panel
    
    -- Register the panel with Interface Options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Use the new Settings API for Dragonflight and later
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        LP.optionsCategory = category
    else
        -- Fallback for older versions of WoW
        InterfaceOptions_AddCategory(panel)
    end
    
    print(addonName .. ": Options panel created.")
end 