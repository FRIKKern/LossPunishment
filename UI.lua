local addonName, addonTable = ...

-- Ensure the addon's namespace exists
LossPunishment = LossPunishment or {}
local LP = LossPunishment

-- UI specific functions and logic will go here
LP.ExerciseFrame = nil -- Store reference to the frame
LP.fadeTimer = nil -- Timer for fading

-- Function to create the exercise prompt frame with improved styling
function LP:CreateExerciseFrame()
    if LP.ExerciseFrame then return end -- Don't create if it already exists

    local frame = CreateFrame("Frame", "LossPunishmentExerciseFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(350, 150)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("HIGH") -- Ensure it's above most default UI
    frame:SetFrameLevel(100)     -- High frame level to be on top
    frame:SetClampedToScreen(true) -- Prevent it from moving off-screen
    
    -- Add a fade-in animation
    frame.fadeIn = frame:CreateAnimationGroup()
    local fadeIn = frame.fadeIn:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.5)
    fadeIn:SetSmoothing("OUT")
    
    -- Set initial alpha to 0 for fade-in effect
    frame:SetAlpha(0)
    
    -- Handle animation finish
    frame.fadeIn:SetScript("OnFinished", function()
        frame:SetAlpha(1)
    end)

    -- Title Text
    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFontObject("GameFontHighlight")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -5)
    frame.title:SetText("Loss Punishment")

    -- Add challenge level display
    frame.challengeLevel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.challengeLevel:SetPoint("TOPRIGHT", frame.InsetBg, "TOPRIGHT", -10, -10)
    frame.challengeLevel:SetJustifyH("RIGHT")
    frame.challengeLevel:SetTextColor(0.8, 0.8, 0.2) -- Gold color
    frame.challengeLevel:SetText("Challenge Level: Loading...")
    
    -- Points value display
    frame.pointsValue = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.pointsValue:SetPoint("TOP", frame.challengeLevel, "BOTTOM", 0, -2)
    frame.pointsValue:SetJustifyH("RIGHT")
    frame.pointsValue:SetTextColor(0, 0.8, 0) -- Green color
    frame.pointsValue:SetText("Points: --")

    -- Left Arrow Button
    frame.leftArrow = CreateFrame("Button", "LossPunishmentLeftArrow", frame)
    frame.leftArrow:SetSize(24, 24)
    frame.leftArrow:SetPoint("RIGHT", frame, "CENTER", -60, 20)
    frame.leftArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    frame.leftArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
    frame.leftArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
    frame.leftArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    frame.leftArrow:SetScript("OnClick", function()
        LP:CycleExercise(-1) -- Go to previous exercise
    end)

    -- Exercise Text Area with better styling
    frame.exerciseText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.exerciseText:SetPoint("CENTER", frame, "CENTER", 0, 20)
    frame.exerciseText:SetJustifyH("CENTER")
    frame.exerciseText:SetText("Placeholder exercise text will go here...")

    -- Right Arrow Button
    frame.rightArrow = CreateFrame("Button", "LossPunishmentRightArrow", frame)
    frame.rightArrow:SetSize(24, 24)
    frame.rightArrow:SetPoint("LEFT", frame, "CENTER", 60, 20)
    frame.rightArrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    frame.rightArrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
    frame.rightArrow:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
    frame.rightArrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    frame.rightArrow:SetScript("OnClick", function()
        LP:CycleExercise(1) -- Go to next exercise
    end)

    -- Notification about what happened
    frame.notificationText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.notificationText:SetPoint("TOP", frame.exerciseText, "BOTTOM", 0, -10)
    frame.notificationText:SetJustifyH("CENTER")
    frame.notificationText:SetTextColor(1, 0.5, 0) -- Orange color
    frame.notificationText:SetText("Loss detected in PvP! Time to exercise!")

    -- "Am weak" Button (left)
    frame.skipButton = CreateFrame("Button", "LossPunishmentSkipButton", frame, "GameMenuButtonTemplate")
    frame.skipButton:SetSize(100, 25)
    frame.skipButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 15, 15)
    frame.skipButton:SetText("Am weak")
    frame.skipButton:SetNormalFontObject("GameFontNormal")
    frame.skipButton:SetHighlightFontObject("GameFontHighlight")
    frame.skipButton:SetScript("OnClick", function(self)
        print(addonName .. ": Exercise skipped. Don't skip leg day too often!")
        
        -- Hide the frame with animation
        LP:HideExerciseFrame()
    end)

    -- "Complete" Button (right)
    frame.ackButton = CreateFrame("Button", "LossPunishmentAckButton", frame, "GameMenuButtonTemplate")
    frame.ackButton:SetSize(100, 25)
    frame.ackButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -15, 15)
    frame.ackButton:SetText("Complete")
    frame.ackButton:SetNormalFontObject("GameFontNormal")
    frame.ackButton:SetHighlightFontObject("GameFontHighlight")
    frame.ackButton:SetScript("OnClick", function(self)
        local parentFrame = self:GetParent()
        local completedExercise = parentFrame.currentExercise -- Get the stored exercise

        if completedExercise and LP.RecordExerciseCompletion then
             LP:RecordExerciseCompletion(completedExercise) -- Call Core function
             print(addonName .. ": Great job! Recorded completion for: " .. completedExercise)
        else
             print(addonName .. ": Could not record exercise completion. Exercise: " .. tostring(completedExercise))
        end
        
        -- Hide the frame with animation
        LP:HideExerciseFrame()
    end)

    frame:Hide() -- Start hidden
    LP.ExerciseFrame = frame -- Store reference
    print(addonName .. ": Exercise frame created.")
end

-- Function to show the frame with specific exercise text
function LP:ShowExercisePrompt(exerciseText, instanceType)
    if not LP.ExerciseFrame then
        LP:CreateExerciseFrame()
    end

    -- Cancel any existing fade timer
    if LP.fadeTimer then
        LP.fadeTimer:Cancel()
        LP.fadeTimer = nil
    end

    if LP.ExerciseFrame then
        local displayString = exerciseText or "Error: No exercise provided."
        LP.ExerciseFrame.exerciseText:SetText(displayString)
        LP.ExerciseFrame.currentExercise = displayString -- Store the text on the frame
        LP.ExerciseFrame.instanceType = instanceType -- Store instance type for snooze function
        
        -- Set a more specific notification based on the instance type
        if instanceType then
            if instanceType == "arena" then
                LP.ExerciseFrame.notificationText:SetText("Arena loss detected! Time to exercise!")
            elseif instanceType == "battleground" then
                LP.ExerciseFrame.notificationText:SetText("Battleground loss detected! Time to exercise!")
            else
                LP.ExerciseFrame.notificationText:SetText("PvP loss detected! Time to exercise!")
            end
        else
            LP.ExerciseFrame.notificationText:SetText("Time for an exercise!")
        end
        
        -- Update challenge level and points information
        local currentLevel = LP.challengeLevels[LP.db.challengeLevel]
        LP.ExerciseFrame.challengeLevel:SetText("Challenge Level: " .. currentLevel.name)
        
        -- Calculate points for this exercise
        local exerciseType
        local pointsText = "Points: "
        
        if string.find(displayString, "Second Plank") then
            exerciseType = "Plank"
            local seconds = tonumber(string.match(displayString, "(%d+) Second"))
            local points = math.floor(seconds * LP.exerciseProperties[exerciseType].points * currentLevel.pointMultiplier)
            pointsText = pointsText .. points .. " pts"
        else
            exerciseType = string.match(displayString, "%d+ (.*)$")
            if exerciseType and LP.exerciseProperties[exerciseType] then
                local reps = tonumber(string.match(displayString, "(%d+) "))
                local points = math.floor(reps * LP.exerciseProperties[exerciseType].points * currentLevel.pointMultiplier)
                pointsText = pointsText .. points .. " pts"
            else
                pointsText = pointsText .. "unknown"
            end
        end
        
        LP.ExerciseFrame.pointsValue:SetText(pointsText)
        
        -- Play a sound to get attention
        PlaySound(SOUNDKIT.READY_CHECK)
        
        -- Ensure alpha is reset for animation
        LP.ExerciseFrame:SetAlpha(0)
        LP.ExerciseFrame:Show()
        
        -- Play fade-in animation
        LP.ExerciseFrame.fadeIn:Play()
    else
        print(addonName .. ": Error - Could not create or find Exercise Frame.")
    end
end

-- Function to cycle through exercises without completing them
function LP:CycleExercise(direction)
    if not LP.exercises or #LP.exercises == 0 or not LP.ExerciseFrame then
        return
    end
    
    -- Get current index
    local currentExerciseText = LP.ExerciseFrame.currentExercise
    local currentIndex = 1 -- Default to first exercise
    
    -- Find the current index in the exercises array
    for i, exerciseText in ipairs(LP.exercises) do
        if exerciseText == currentExerciseText then
            currentIndex = i
            break
        end
    end
    
    -- Calculate new index with wrapping
    local newIndex = currentIndex + direction
    if newIndex < 1 then
        newIndex = #LP.exercises
    elseif newIndex > #LP.exercises then
        newIndex = 1
    end
    
    -- Get the base exercise
    local baseExercise = LP.exercises[newIndex]
    
    -- Get the current challenge level
    local currentLevel = LP.challengeLevels[LP.db.challengeLevel]
    local repMultiplier = currentLevel.repMultiplier or 1.0
    local pointMultiplier = currentLevel.pointMultiplier or 1.0
    
    -- Determine the exercise type and adjust the count based on challenge level
    local exerciseType, originalCount
    if string.find(baseExercise, "Second Plank") then
        exerciseType = "Plank"
        originalCount = 20 -- 20 seconds for Plank
    else
        exerciseType, originalCount = string.match(baseExercise, "(%d+) (.*)$")
        originalCount = tonumber(exerciseType) -- The capture is flipped, exerciseType has the number
        exerciseType = string.match(baseExercise, "%d+ (.*)$")
    end
    
    -- Calculate adjusted count based on challenge level
    local adjustedCount = math.floor(originalCount * repMultiplier)
    if adjustedCount < 1 then adjustedCount = 1 end -- Ensure minimum of 1
    
    -- Format the exercise string with the adjusted count
    local adjustedExercise
    if exerciseType == "Plank" then
        adjustedExercise = adjustedCount .. " Second Plank"
    else
        adjustedExercise = adjustedCount .. " " .. exerciseType
    end
    
    -- Update displayed exercise
    LP.ExerciseFrame.exerciseText:SetText(adjustedExercise)
    LP.ExerciseFrame.currentExercise = adjustedExercise
    
    -- Calculate points for the new exercise
    local basePoints = LP.exerciseProperties[exerciseType].points
    local countMultiplier = (exerciseType == "Plank") and 20 or 10 -- Full set of reps or seconds
    local pointsForExercise = math.floor(countMultiplier * basePoints * pointMultiplier)
    
    -- Update points tooltip
    local pointsText = "Points: " .. pointsForExercise .. " pts"
    LP.ExerciseFrame.pointsValue:SetText(pointsText)
    
    print(addonName .. ": Switched to exercise: " .. adjustedExercise)
end

-- Function to hide the exercise frame with a fade out animation
function LP:HideExerciseFrame()
    if not LP.ExerciseFrame then return end
    
    -- Create a smooth fade-out effect
    UIFrameFadeOut(LP.ExerciseFrame, 0.5, 1, 0)
    
    -- After fade completes, hide the frame
    LP.fadeTimer = C_Timer.NewTimer(0.5, function()
        LP.ExerciseFrame:Hide()
        LP.fadeTimer = nil
    end)
end

-- Example: Function to create a simple frame (uncomment and expand later)
-- function LP:CreateMyFrame()
--     local frame = CreateFrame("Frame", "LossPunishmentFrame", UIParent)
--     frame:SetSize(200, 100)
--     frame:SetPoint("CENTER")
--     frame:SetBackdrop({bgFile = "Interface/DialogFrame/UI-DialogBox-Background", edgeFile = "Interface/DialogFrame/UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 }})
--     frame:SetBackdropColor(0,0,0,0.8)
--     frame:SetMovable(true)
--     frame:EnableMouse(true)
--     frame:RegisterForDrag("LeftButton")
--     frame:SetScript("OnDragStart", frame.StartMoving)
--     frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
--
--     local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
--     title:SetPoint("TOP", 0, -15)
--     title:SetText("LossPunishment")
-- end

-- Call UI creation functions when needed, perhaps during Initialize in Core.lua
-- LP:CreateMyFrame() 