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
        today = { Pushups = 0, Squats = 0, Situps = 0, Plank = 0, total = 0, points = 0 },
        week = { Pushups = 0, Squats = 0, Situps = 0, Plank = 0, total = 0, points = 0 },
        month = { Pushups = 0, Squats = 0, Situps = 0, Plank = 0, total = 0, points = 0 },
        allTime = { Pushups = 0, Squats = 0, Situps = 0, Plank = 0, total = 0, points = 0 }
    }
    
    -- Point values for each exercise type
    local pointValues = {
        Pushups = 4,  -- 4 points per push-up
        Squats = 2,   -- 2 points per squat
        Situps = 1,   -- 1 point per sit-up
        Plank = 3     -- 3 points per plank
    }
    
    -- Always return initialized stats even if no data exists yet
    if not LP.db or not LP.db.stats then 
        LP:DebugPrint("No stats data found, returning zeros")
        return stats 
    end
    
    -- Ensure all exercise types exist in stats
    LP.db.stats.Pushups = LP.db.stats.Pushups or {}
    LP.db.stats.Squats = LP.db.stats.Squats or {}
    LP.db.stats.Situps = LP.db.stats.Situps or {}
    LP.db.stats.Plank = LP.db.stats.Plank or {}
    
    LP:DebugPrint("Calculating stats from " .. 
                 #LP.db.stats.Pushups .. " pushups, " ..
                 #LP.db.stats.Squats .. " squats, " ..
                 #LP.db.stats.Situps .. " situps, " ..
                 #LP.db.stats.Plank .. " planks")
    
    for exType, timestamps in pairs(LP.db.stats) do
        for _, timestamp in ipairs(timestamps) do
            -- Determine the multiplier based on exercise type
            local multiplier = (exType == "Plank") and 1 or 10  -- Plank is already per unit, others are counted in sets of 10
            
            -- All time
            stats.allTime[exType] = stats.allTime[exType] + 1
            stats.allTime.total = stats.allTime.total + 1
            stats.allTime.points = stats.allTime.points + (pointValues[exType] or 0) * multiplier
            
            -- Today
            if LP:IsWithinTimePeriod(timestamp, "today") then
                stats.today[exType] = stats.today[exType] + 1
                stats.today.total = stats.today.total + 1
                stats.today.points = stats.today.points + (pointValues[exType] or 0) * multiplier
            end
            
            -- This week
            if LP:IsWithinTimePeriod(timestamp, "week") then
                stats.week[exType] = stats.week[exType] + 1
                stats.week.total = stats.week.total + 1
                stats.week.points = stats.week.points + (pointValues[exType] or 0) * multiplier
            end
            
            -- This month
            if LP:IsWithinTimePeriod(timestamp, "month") then
                stats.month[exType] = stats.month[exType] + 1
                stats.month.total = stats.month.total + 1
                stats.month.points = stats.month.points + (pointValues[exType] or 0) * multiplier
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
    
    -- Plank button
    local plankButton = CreateFrame("Button", "LossPunishmentHistoryPlankButton", filterFrame, "UIPanelButtonTemplate")
    plankButton:SetSize(70, 25)
    plankButton:SetPoint("LEFT", situpsButton, "RIGHT", 10, 0)
    plankButton:SetText("Plank")
    
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
    exerciseHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 75, 0)
    exerciseHeader:SetText("Exercise")
    exerciseHeader:SetWidth(80)
    
    local pointsHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pointsHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 160, 0)
    pointsHeader:SetText("Points")
    pointsHeader:SetWidth(50)
    
    local dateHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dateHeader:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 210, 0)
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
                LP.db.stats = { Pushups = {}, Squats = {}, Situps = {}, Plank = {} }
                
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
        
        -- Point values for each exercise type
        local pointValues = {
            Pushups = 4,  -- 4 points per push-up
            Squats = 2,   -- 2 points per squat
            Situps = 1,   -- 1 point per sit-up
            Plank = 3     -- 3 points per plank
        }
        
        -- Collect all entries based on filter
        local entries = {}
        
        -- Ensure database exists
        if not LP.db then
            LP.db = {}
        end
        
        if not LP.db.stats then
            LP.db.stats = { Pushups = {}, Squats = {}, Situps = {}, Plank = {} }
        end
        
        for exType, timestamps in pairs(LP.db.stats) do
            if filter == "All" or filter == exType then
                for i, timestamp in ipairs(timestamps) do
                    -- Determine if the exercise is measured in time or reps
                    local isTimeBased = (exType == "Plank")
                    local multiplier = isTimeBased and 1 or 10
                    
                    table.insert(entries, {
                        exType = exType,
                        timestamp = timestamp,
                        index = i,
                        isTimeBased = isTimeBased,
                        points = (pointValues[exType] or 0) * multiplier -- Calculate points
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
                numberText:SetPoint("LEFT", row, "LEFT", 75, 0)
                numberText:SetWidth(80)
                row.numberText = numberText
                
                -- Points
                local pointsText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                pointsText:SetPoint("LEFT", row, "LEFT", 160, 0)
                pointsText:SetWidth(50)
                row.pointsText = pointsText
                
                -- Timestamp
                local timeText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
                timeText:SetPoint("LEFT", row, "LEFT", 210, 0)
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
            
            -- Display either reps or seconds based on exercise type
            if entry.isTimeBased then
                row.numberText:SetText("20 Seconds " .. entry.exType)
            else
                row.numberText:SetText("10 " .. entry.exType)
            end
            
            row.pointsText:SetText(entry.points .. " pts")
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
    plankButton:SetScript("OnClick", function() window:PopulateHistoryList("Plank") end)
    
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
        LP.db.stats = { Pushups = {}, Squats = {}, Situps = {}, Plank = {} }
    end
    
    -- Ensure all exercise types exist in stats
    LP.db.stats.Pushups = LP.db.stats.Pushups or {}
    LP.db.stats.Squats = LP.db.stats.Squats or {}
    LP.db.stats.Situps = LP.db.stats.Situps or {}
    LP.db.stats.Plank = LP.db.stats.Plank or {}
    
    -- Initialize enabled exercises if they don't exist
    if not LP.db.enabledExercises then
        LP.db.enabledExercises = { Pushups = true, Squats = true, Situps = true, Plank = true }
    end
    
    -- Pre-calculate stats once to have them ready
    LP.cachedStats = LP:CalculateStats()
    LP:DebugPrint("Pre-calculated stats for faster panel loading")
    
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
    pushupsCheckbox.text:SetText("Enable Pushups (4 pts per rep)")
    pushupsCheckbox:SetChecked(LP.db.enabledExercises.Pushups)
    pushupsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Pushups = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Squats checkbox
    local squatsCheckbox = CreateFrame("CheckButton", "LossPunishmentSquatsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    squatsCheckbox:SetPoint("TOPLEFT", pushupsCheckbox, "BOTTOMLEFT", 0, -5)
    squatsCheckbox.text = _G[squatsCheckbox:GetName() .. "Text"]
    squatsCheckbox.text:SetText("Enable Squats (2 pts per rep)")
    squatsCheckbox:SetChecked(LP.db.enabledExercises.Squats)
    squatsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Squats = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Situps checkbox
    local situpsCheckbox = CreateFrame("CheckButton", "LossPunishmentSitupsCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    situpsCheckbox:SetPoint("TOPLEFT", squatsCheckbox, "BOTTOMLEFT", 0, -5)
    situpsCheckbox.text = _G[situpsCheckbox:GetName() .. "Text"]
    situpsCheckbox.text:SetText("Enable Situps (1 pt per rep)")
    situpsCheckbox:SetChecked(LP.db.enabledExercises.Situps)
    situpsCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Situps = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Plank checkbox (time-based exercise)
    local plankCheckbox = CreateFrame("CheckButton", "LossPunishmentPlankCheckbox", panel, "InterfaceOptionsCheckButtonTemplate")
    plankCheckbox:SetPoint("TOPLEFT", situpsCheckbox, "BOTTOMLEFT", 0, -5)
    plankCheckbox.text = _G[plankCheckbox:GetName() .. "Text"]
    plankCheckbox.text:SetText("Enable Plank (3 pts per 20 seconds)")
    plankCheckbox:SetChecked(LP.db.enabledExercises.Plank)
    plankCheckbox:SetScript("OnClick", function(self)
        LP.db.enabledExercises.Plank = self:GetChecked()
        LP:UpdateExercisesList()
    end)
    
    -- Section Title: Statistics
    local statsTitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    statsTitle:SetPoint("TOPLEFT", plankCheckbox, "BOTTOMLEFT", 0, -20)
    statsTitle:SetText("Exercise Statistics")
    
    -- Add point system explanation
    local pointsExplanation = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    pointsExplanation:SetPoint("TOPLEFT", statsTitle, "BOTTOMLEFT", 0, -5)
    pointsExplanation:SetText("(Push-ups = 4 pts, Squats = 2 pts, Sit-ups = 1 pt per rep, Plank = 3 pts per 20 sec)")
    pointsExplanation:SetJustifyH("LEFT")
    pointsExplanation:SetWidth(400)
    
    -- Statistics summary frame
    local statsFrame = CreateFrame("Frame", "LossPunishmentStatsFrame", panel, "InsetFrameTemplate")
    statsFrame:SetPoint("TOPLEFT", pointsExplanation, "BOTTOMLEFT", 0, -10)
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
    
    -- Exercise types with point values
    local exerciseTypes = {"Pushups", "Squats", "Situps", "Plank"}
    local exerciseLabels = {"Push-ups (4 pts)", "Squats (2 pts)", "Sit-ups (1 pt)", "Plank (3 pts)"}
    local statsLabels = {}
    local statsValues = {}
    
    for i, exType in ipairs(exerciseTypes) do
        -- Create label
        statsLabels[i] = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        statsLabels[i]:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 20, -40 - (i-1) * 25)
        statsLabels[i]:SetText(exerciseLabels[i] .. ":")
        statsLabels[i]:SetJustifyH("LEFT")
        statsLabels[i]:SetWidth(90)
        
        -- Create values for each time period
        statsValues[exType] = {}
        for j, period in ipairs(periodLabels) do
            local valueText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            valueText:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 110 + (j-1) * 70, -40 - (i-1) * 25)
            valueText:SetJustifyH("CENTER")
            valueText:SetWidth(60)
            statsValues[exType][period] = valueText
            
            -- Set initial values from cache (important for first-time display)
            if LP.cachedStats then
                local value = 0
                if period == "Today" then value = LP.cachedStats.today[exType] * 10
                elseif period == "This Week" then value = LP.cachedStats.week[exType] * 10
                elseif period == "This Month" then value = LP.cachedStats.month[exType] * 10
                elseif period == "All Time" then value = LP.cachedStats.allTime[exType] * 10
                end
                valueText:SetText(value .. " reps")
            else
                valueText:SetText("0 reps")
            end
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
    totalLabel:SetText("TOTAL POINTS:")
    totalLabel:SetJustifyH("LEFT")
    totalLabel:SetWidth(90)
    
    -- Total values for each period
    local totalValues = {}
    for j, period in ipairs(periodLabels) do
        local valueText = statsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
        valueText:SetPoint("TOPLEFT", statsFrame, "TOPLEFT", 110 + (j-1) * 70, -75 - (#exerciseTypes-1) * 25)
        valueText:SetJustifyH("CENTER")
        valueText:SetWidth(60)
        totalValues[period] = valueText
        
        -- Set initial total values from cache
        if LP.cachedStats then
            local value = 0
            if period == "Today" then value = LP.cachedStats.today.points
            elseif period == "This Week" then value = LP.cachedStats.week.points
            elseif period == "This Month" then value = LP.cachedStats.month.points
            elseif period == "All Time" then value = LP.cachedStats.allTime.points
            end
            valueText:SetText(value .. " pts")
        else
            valueText:SetText("0 pts")
        end
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
    
    -- Store references globally for the refresh function
    panel.statsValues = statsValues
    panel.totalValues = totalValues
    panel.exerciseTypes = exerciseTypes
    panel.periodLabels = periodLabels
    panel.pushupsCheckbox = pushupsCheckbox
    panel.squatsCheckbox = squatsCheckbox
    panel.situpsCheckbox = situpsCheckbox
    panel.plankCheckbox = plankCheckbox
    
    -- Panel refresh function
    panel.refresh = function()
        LP:DebugPrint("Options panel refresh called")
        
        -- Update checkboxes
        panel.pushupsCheckbox:SetChecked(LP.db.enabledExercises.Pushups)
        panel.squatsCheckbox:SetChecked(LP.db.enabledExercises.Squats)
        panel.situpsCheckbox:SetChecked(LP.db.enabledExercises.Situps)
        panel.plankCheckbox:SetChecked(LP.db.enabledExercises.Plank)
        
        -- Calculate stats for all time periods
        local stats = LP:CalculateStats()
        LP.cachedStats = stats -- Update the cache
        
        -- Exercise counts - show in reps or seconds based on exercise type
        for i, exType in ipairs(panel.exerciseTypes) do
            if panel.statsValues[exType] then
                local isTimeBased = (exType == "Plank")
                local unit = isTimeBased and " sec" or " reps"
                local multiplier = isTimeBased and 20 or 10
                
                panel.statsValues[exType]["Today"]:SetText(stats.today[exType] * multiplier .. unit)
                panel.statsValues[exType]["This Week"]:SetText(stats.week[exType] * multiplier .. unit)
                panel.statsValues[exType]["This Month"]:SetText(stats.month[exType] * multiplier .. unit)
                panel.statsValues[exType]["All Time"]:SetText(stats.allTime[exType] * multiplier .. unit)
                LP:DebugPrint("Set " .. exType .. " stats: " .. 
                             (stats.today[exType] * multiplier) .. " today, " ..
                             (stats.week[exType] * multiplier) .. " week, " ..
                             (stats.month[exType] * multiplier) .. " month, " ..
                             (stats.allTime[exType] * multiplier) .. " all time")
            else
                LP:DebugPrint("Missing statsValues for " .. exType)
            end
        end
        
        -- Total exercises in points
        if panel.totalValues then
            panel.totalValues["Today"]:SetText(stats.today.points .. " pts")
            panel.totalValues["This Week"]:SetText(stats.week.points .. " pts")
            panel.totalValues["This Month"]:SetText(stats.month.points .. " pts")
            panel.totalValues["All Time"]:SetText(stats.allTime.points .. " pts")
            LP:DebugPrint("Set total points: " .. 
                         stats.today.points .. " today, " ..
                         stats.week.points .. " week, " ..
                         stats.month.points .. " month, " ..
                         stats.allTime.points .. " all time")
        else
            LP:DebugPrint("Missing totalValues")
        end
    end
    
    -- Multi-refresh attempt on show for maximum reliability
    panel:SetScript("OnShow", function()
        LP:DebugPrint("Options panel OnShow triggered - starting multi-refresh")
        
        -- Immediate refresh
        panel.refresh()
        
        -- Additional refresh attempts with increasing delays
        C_Timer.After(0.1, function() panel.refresh() end)
        C_Timer.After(0.5, function() panel.refresh() end)
        C_Timer.After(1.0, function() panel.refresh() end)
    end)
    
    -- Store the panel reference
    LP.optionsPanel = panel
    
    -- Register the panel with Interface Options
    if Settings and Settings.RegisterCanvasLayoutCategory then
        -- Use the new Settings API for Dragonflight and later
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        LP.optionsCategory = category
        
        -- Make sure stats calculate even on first open for Dragonflight
        category:SetCallback("OnRefresh", panel.refresh)
    else
        -- Fallback for older versions of WoW
        InterfaceOptions_AddCategory(panel)
    end
    
    -- Force multiple refresh attempts after creation with increasing delays
    C_Timer.After(0.1, function() if panel.refresh then panel.refresh() end end)
    C_Timer.After(0.5, function() if panel.refresh then panel.refresh() end end)
    C_Timer.After(1.0, function() if panel.refresh then panel.refresh() end end)
    
    print(addonName .. ": Options panel created with statistical data.")
end

-- Add a separate function to open the options panel properly
function LP:OpenOptionsPanel()
    -- Pre-calculate stats before opening the panel
    LP.cachedStats = LP:CalculateStats()
    LP:DebugPrint("Pre-calculated stats before opening options panel")
    
    -- Force a full refresh of the panel if it exists
    if LP.optionsPanel and LP.optionsPanel.refresh then
        LP.optionsPanel.refresh()
    end
    
    if Settings and Settings.OpenToCategory and LP.optionsCategory then
        -- Use the new Settings API for Dragonflight or later
        Settings.OpenToCategory(LP.optionsCategory:GetID())
        
        -- Force multiple refresh attempts after opening with increasing delays
        C_Timer.After(0.1, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(0.3, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(0.6, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(1.0, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
    elseif InterfaceOptionsFrame_OpenToCategory and LP.optionsPanel then
        -- Fallback for older versions of WoW
        InterfaceOptionsFrame_OpenToCategory(LP.optionsPanel)
        -- Call it twice due to a known bug in the Blizzard UI
        InterfaceOptionsFrame_OpenToCategory(LP.optionsPanel)
        
        -- Force multiple refresh attempts after opening with increasing delays
        C_Timer.After(0.1, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(0.3, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(0.6, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
        C_Timer.After(1.0, function() if LP.optionsPanel and LP.optionsPanel.refresh then LP.optionsPanel.refresh() end end)
    else
        print(addonName .. ": Unable to open options panel.")
    end
end 