local addonName, addonTable = ...

-- Create a namespace for the addon
LossPunishment = LossPunishment or {}
local LP = LossPunishment
LP.Version = "0.1.0" -- Define version, keep in sync with .toc

-- List of exercises
LP.exercises = {
    "10 Pushups",
    "10 Squats",
    "10 Situps"
}

-- Database for storing loss records (will be loaded from SavedVariables)
LP.db = {}
LP.debugMode = false -- Add debug mode flag
LP.eventFrame = nil -- Store reference to the event frame

-- State variables for instance tracking
LP.isInPvPInstance = false
LP.currentInstanceType = nil -- "arena", "battleground", or nil
LP.currentInstanceID = nil -- Unique ID for the instance
LP.hasLostCurrentInstance = false -- Tracks if a loss was detected in the current instance
LP.wasInPvPInstance = false -- Add this flag

-- Helper function for debug printing
function LP:DebugPrint(...)
    if LP.debugMode then
        print("|cffeda55f[" .. addonName .. " Debug]|r:", ...)
    end
end

-- Safe call wrapper using pcall
function LP:SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        print("|cffff0000[" .. addonName .. " Error]|r: Error in function call: " .. tostring(result))
        -- Potentially print more debug info if needed
        -- debugstack() might be useful here but can be spammy
    end
    return success, result
end

-- Initialization function
function LP:Initialize()
    LP:DebugPrint("Initializing...") -- Use DebugPrint
    -- Load saved data if it exists
    if LossPunishmentDB then
        LP.db = LossPunishmentDB
    else
        -- Initialize default database structure if no saved data
        LP.db = {
            losses = {}, -- Example structure
            lastExerciseIndex = 0, -- Initialize index for rotation
            -- Change stats to store lists of timestamps
            stats = { Pushups = {}, Squats = {}, Situps = {} },
            -- Add settings for exercise toggling
            enabledExercises = {
                Pushups = true,
                Squats = true,
                Situps = true
            }
        }
        LossPunishmentDB = LP.db -- Assign to global for saving
    end

    -- Ensure essential db fields exist
    LP.db.lastExerciseIndex = LP.db.lastExerciseIndex or 0
    -- Ensure stats table and exercise lists exist (with basic backward compatibility)
    if type(LP.db.stats) ~= "table" then 
        LP.db.stats = { Pushups = {}, Squats = {}, Situps = {} }
    end
    LP.db.stats.Pushups = type(LP.db.stats.Pushups) == "table" and LP.db.stats.Pushups or {}
    LP.db.stats.Squats = type(LP.db.stats.Squats) == "table" and LP.db.stats.Squats or {}
    LP.db.stats.Situps = type(LP.db.stats.Situps) == "table" and LP.db.stats.Situps or {}
    
    -- Ensure enabled exercises settings exist
    if type(LP.db.enabledExercises) ~= "table" then
        LP.db.enabledExercises = { Pushups = true, Squats = true, Situps = true }
    end

    -- Update exercises list based on enabled settings
    LP:UpdateExercisesList()

    LP.debugMode = LP.db.debugMode or false -- Load debug mode state

    -- Add wasInPvPInstance flag to track instance transitions more reliably
    LP.wasInPvPInstance = false

    -- Initial check for instance status (wrapped in SafeCall)
    LP:SafeCall(LP.CheckInstanceStatus, LP)

    -- Create UI elements
    if LP.CreateExerciseFrame then
        LP:SafeCall(LP.CreateExerciseFrame, LP)
    else
        print(addonName .. ": Warning - UI.lua might not be loaded correctly, cannot create frame.")
    end
    
    -- Create options panel 
    if LP.CreateOptionsPanel then
        LP:SafeCall(LP.CreateOptionsPanel, LP)
    else
        print(addonName .. ": Warning - Options.lua might not be loaded, cannot create options panel.")
    end

    -- Register events needed
    LP:SafeCall(LP.RegisterEvents, LP)

    -- Register Slash Command
    SLASH_LOSSPUNISH1 = "/losspunish"
    SLASH_LOSSPUNISH2 = "/lp" -- Add alias
    SlashCmdList["LOSSPUNISH"] = function(msg)
        LP:SafeCall(LP.ProcessSlashCommand, LP, msg)
    end

    LP:DebugPrint("Initialization complete.")
end

-- Function to record the completion of an exercise with a timestamp
function LP:RecordExerciseCompletion(exerciseText)
    if not exerciseText or not LP.db or not LP.db.stats then
        LP:DebugPrint("Cannot record completion: Invalid input or DB structure.")
        return
    end

    local exerciseType = string.match(exerciseText, "%d+ (.*)$")
    if exerciseType and LP.db.stats[exerciseType] then
        local timestamp = date("%Y-%m-%d %H:%M:%S") -- Get current date and time
        table.insert(LP.db.stats[exerciseType], timestamp) -- Add timestamp to the list
        LP:DebugPrint("Recorded completion for", exerciseType, "at", timestamp, "Total:", #LP.db.stats[exerciseType])
    else
        LP:DebugPrint("Cannot record completion: Could not parse exercise type from", exerciseText)
    end
end

-- Function to handle slash commands
function LP:ProcessSlashCommand(msg)
    local command = strlower(string.trim(msg or ""))

    LP:DebugPrint("Processing slash command: ", command)

    if command == "debug" then
        LP.debugMode = not LP.debugMode
        LP.db.debugMode = LP.debugMode -- Save state
        print(addonName .. ": Debug mode " .. (LP.debugMode and "enabled" or "disabled") .. ".")
    elseif command == "testprompt" or command == "show" then -- Added "show"
        -- Show the prompt with the current exercise (without advancing rotation)
        local currentExerciseIndex = LP.db.lastExerciseIndex or 0
        if currentExerciseIndex == 0 then currentExerciseIndex = #LP.exercises end -- Handle initial state before first rotation
        local currentExercise = LP.exercises[currentExerciseIndex]

        if LP.ShowExercisePrompt then
             LP:ShowExercisePrompt(currentExercise or "No exercise selected yet.")
             print(addonName .. ": Showing current exercise prompt: " .. (currentExercise or "N/A"))
        else
             print(addonName .. ": Error - ShowExercisePrompt function not found.")
        end
    elseif command == "options" or command == "config" then
        -- Open the options panel
        LP:OpenOptionsPanel()
    elseif command == "forcepopup" then
        -- Force a popup with debug info about current state
        local debugInfo = "Debug State:\n"
        debugInfo = debugInfo .. "wasInPvPInstance: " .. tostring(LP.wasInPvPInstance) .. "\n"
        debugInfo = debugInfo .. "isInPvPInstance: " .. tostring(LP.isInPvPInstance) .. "\n"
        debugInfo = debugInfo .. "hasLostCurrentInstance: " .. tostring(LP.hasLostCurrentInstance) .. "\n"
        debugInfo = debugInfo .. "currentInstanceType: " .. tostring(LP.currentInstanceType)
        
        print(addonName .. ": Forcing popup with debug info")
        
        -- Force the popup
        LP.hasLostCurrentInstance = true
        LP.wasInPvPInstance = true
        LP.isInPvPInstance = false
        LP.currentInstanceType = "arena"
        
        -- Simulate the exit code
        LP:HandlePlayerEnteringWorld()
    elseif command == "next" then
        -- Advance rotation and show the new exercise prompt
        local nextExercise = LP:GetNextExercise() -- This advances the index
        if LP.ShowExercisePrompt then
            LP:ShowExercisePrompt(nextExercise)
            print(addonName .. ": Advanced to next exercise and shown prompt: " .. nextExercise)
        else
            print(addonName .. ": Error - ShowExercisePrompt function not found, but rotation advanced.")
        end
    elseif command == "test arena" or command == "testarena" then
        -- Test the arena loss prompt
        local nextExercise = LP:GetNextExercise() -- This advances the index
        if LP.ShowExercisePrompt then
            LP:ShowExercisePrompt(nextExercise, "arena")
            print(addonName .. ": Simulating arena loss with exercise: " .. nextExercise)
        else
            print(addonName .. ": Error - ShowExercisePrompt function not found.")
        end
    elseif command == "test bg" or command == "testbg" then
        -- Test the battleground loss prompt
        local nextExercise = LP:GetNextExercise() -- This advances the index
        if LP.ShowExercisePrompt then
            LP:ShowExercisePrompt(nextExercise, "battleground")
            print(addonName .. ": Simulating battleground loss with exercise: " .. nextExercise)
        else
            print(addonName .. ": Error - ShowExercisePrompt function not found.")
        end
    elseif command == "reset" then
        -- Reset the rotation index
        LP.db.lastExerciseIndex = 0
        print(addonName .. ": Exercise rotation reset. Next exercise will be the first one.")
    elseif command == "stats" then
        if LP.db and LP.db.stats then
            print(addonName .. " Exercise Stats:")
            local totalCompletions = 0
            for exType, timestamps in pairs(LP.db.stats) do
                local count = #timestamps
                totalCompletions = totalCompletions + count
                local lastTime = count > 0 and timestamps[count] or "Never"
                print(string.format("  - %s: %d (Last: %s)", exType, count, lastTime))
            end
            print("  Total Completions: " .. totalCompletions)
        else
            print(addonName .. ": Statistics data not found.")
        end
    elseif command == "help" or command == "" then -- Show help if empty or "help"
        print(addonName .. " v" .. LP.Version .. ": Available commands:")
        print("  /lp show - Shows the current exercise prompt without advancing rotation.")
        print("  /lp next - Advances to the next exercise and shows the prompt.")
        print("  /lp testarena - Simulates an arena loss and shows an exercise prompt.")
        print("  /lp testbg - Simulates a battleground loss and shows an exercise prompt.")
        print("  /lp forcepopup - Forces the popup with debug state info (use if popup isn't showing).")
        print("  /lp options - Opens the options panel.")
        print("  /lp reset - Resets the exercise rotation sequence.")
        print("  /lp stats - Shows the count for each assigned exercise.")
        print("  /lp debug - Toggles debug message printing.")
        print("  /lp help - Shows this help message.")
    else
        print(addonName .. ": Unknown command '" .. command .. "'. Type '/lp help' for options.")
    end
end

-- Function to register WoW events
function LP:RegisterEvents()
    if LP.eventFrame then return end -- Already registered

    local frame = CreateFrame("Frame", "LossPunishmentEventFrame")
    LP.eventFrame = frame -- Store the frame reference

    -- Register for zone changes and player entering world (important for instance exits)
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- Add this key event
    -- CHAT_MSG_SYSTEM is registered/unregistered dynamically

    frame:SetScript("OnEvent", function(self, event, ...)
        -- Wrap the entire event handler logic in SafeCall, passing event and args
        LP:SafeCall(function(currentEvent, ...) -- Pass event and varargs as arguments
            LP:DebugPrint("Event received: ", currentEvent)
            if currentEvent == "ZONE_CHANGED_NEW_AREA" then
                 -- Wrap the specific call
                 LP:SafeCall(LP.CheckInstanceStatus, LP)
            elseif currentEvent == "PLAYER_ENTERING_WORLD" then
                -- Handle player entering world (instance transitions)
                LP:SafeCall(LP.HandlePlayerEnteringWorld, LP)
            elseif currentEvent == "CHAT_MSG_SYSTEM" then
                if LP.isInPvPInstance then
                    -- Wrap the specific call, passing self (LP) and the message arguments (...)
                    LP:SafeCall(LP.ProcessSystemMessage, LP, ...) 
                end
            end
            -- Handle other registered events here
        end, event, ...) -- Pass event and varargs from outer scope into SafeCall
    end)
    LP:DebugPrint("Base events registered.")
end

-- Helper function to check if in an Arena
function LP:IsInArena()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "arena"
end

-- Helper function to check if in a Battleground
function LP:IsInBattleground()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "pvp" -- "pvp" is the type for Battlegrounds
end

-- Function to check and update instance status
function LP:CheckInstanceStatus()
    local inInstance, instanceType = IsInInstance()
    LP:DebugPrint("Check instance status - inInstance: " .. tostring(inInstance) .. ", type: " .. tostring(instanceType))
    
    -- This function now mainly serves as a backup check
    -- Most of the instance change logic is in HandlePlayerEnteringWorld
    if inInstance then
        if (instanceType == "arena" or instanceType == "pvp") and not LP.isInPvPInstance then
            LP.isInPvPInstance = true
            LP.wasInPvPInstance = true
            LP.currentInstanceType = instanceType == "arena" and "arena" or "battleground"
            LP.currentInstanceID = select(8, GetInstanceInfo())
            LP.hasLostCurrentInstance = false
            
            -- Register CHAT_MSG_SYSTEM only when entering PvP instance
            if LP.eventFrame then
                LP.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
                LP:DebugPrint("Registered CHAT_MSG_SYSTEM")
            end
        end
    else
        if LP.isInPvPInstance then
            -- This will be handled more thoroughly in HandlePlayerEnteringWorld
            -- Just reset the flag here in case HandlePlayerEnteringWorld missed it
            LP.isInPvPInstance = false
        end
    end
end

-- Function to get the next exercise in the rotation
function LP:GetNextExercise()
    if not LP.db or not LP.exercises or #LP.exercises == 0 then
        return "Error: Exercises not configured."
    end

    -- Increment index, wrap around using modulo
    LP.db.lastExerciseIndex = (LP.db.lastExerciseIndex or 0) % #LP.exercises + 1
    local nextExerciseIndex = LP.db.lastExerciseIndex
    local nextExercise = LP.exercises[nextExerciseIndex]

    -- Stat incrementing is removed, happens on completion now

    LP:DebugPrint("Next exercise index: " .. nextExerciseIndex)
    return nextExercise
end

-- Function to process system messages for win/loss detection
function LP:ProcessSystemMessage(msg)
    if not LP.isInPvPInstance or LP.hasLostCurrentInstance then
        return
    end

    LP:DebugPrint("Processing system message: " .. tostring(msg))

    -- Arena Loss Detection
    if LP.currentInstanceType == "arena" then
        -- More comprehensive patterns for Classic Era and other versions
        local arenaLossPatterns = {
            "You lose", -- General pattern
            "You have lost the arena", -- Some versions
            "Your team has been defeated", -- Other versions
            "has defeated your team", -- Yet another variant
            "has won the arena match" -- When opponent team wins
        }
        
        for _, pattern in ipairs(arenaLossPatterns) do
            if string.find(msg, pattern) then
                LP:DebugPrint("Detected Arena Loss via system message: " .. msg)
                LP.hasLostCurrentInstance = true
                print(addonName .. ": Arena loss detected. Punishment will be triggered when you leave the arena.")
                return
            end
        end
    end

    -- Battleground Loss Detection
    if LP.currentInstanceType == "battleground" then
        local playerFaction = UnitFactionGroup("player") -- "Horde" or "Alliance"
        
        -- More comprehensive BG loss patterns
        local bgLossPatterns = {}
        
        if playerFaction == "Horde" then
            bgLossPatterns = {
                "The Alliance wins", -- General win message
                "Alliance victories", -- Wins counter
                "Alliance gains", -- Resource gain
                "Alliance captured.+wins" -- Capture-based win, like flags
            }
        else -- Alliance
            bgLossPatterns = {
                "The Horde wins", -- General win message
                "Horde victories", -- Wins counter
                "Horde gains", -- Resource gain
                "Horde captured.+wins" -- Capture-based win, like flags
            }
        end
        
        for _, pattern in ipairs(bgLossPatterns) do
            if string.find(msg, pattern) then
                LP:DebugPrint("Detected Battleground Loss via system message: " .. msg)
                LP.hasLostCurrentInstance = true
                print(addonName .. ": Battleground loss detected. Punishment will be triggered when you leave the battleground.")
                return
            end
        end
    end
end

-- Add a new function to handle player entering world (similar to AutoQue)
function LP:HandlePlayerEnteringWorld()
    local inInstance, instanceType = IsInInstance()
    
    LP:DebugPrint("Player entering world. inInstance: " .. tostring(inInstance) .. ", instanceType: " .. tostring(instanceType))
    LP:DebugPrint("Previous state - wasInPvP: " .. tostring(LP.wasInPvPInstance) .. ", hasLost: " .. tostring(LP.hasLostCurrentInstance))
    
    if not inInstance and LP.wasInPvPInstance then
        -- Player has just left a PvP instance
        local lossDetected = LP.hasLostCurrentInstance
        local previousInstanceType = LP.currentInstanceType
        
        LP:DebugPrint("Detected exit from PvP instance. Loss detected: " .. tostring(lossDetected))
        
        -- Reset tracking variables AFTER saving what we need
        LP.wasInPvPInstance = false
        LP.isInPvPInstance = false
        LP.currentInstanceType = nil
        LP.currentInstanceID = nil
        
        -- Important: Don't reset hasLostCurrentInstance until after we've used it
        
        -- Unregister CHAT_MSG_SYSTEM when exiting PvP instance
        if LP.eventFrame then
            LP.eventFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
            LP:DebugPrint("Unregistered CHAT_MSG_SYSTEM")
        end
        
        if lossDetected then
            -- Use C_Timer to slightly delay the popup to ensure it appears after leaving instance
            C_Timer.After(1.0, function()
                print(addonName .. ": Loss was recorded for the previous instance. Triggering punishment.")
                local nextExercise = LP:GetNextExercise()
                if LP.ShowExercisePrompt then
                    LP:ShowExercisePrompt(nextExercise, previousInstanceType)
                else
                    print(addonName .. ": Error - ShowExercisePrompt function not found.")
                end
                -- NOW reset this flag after we've used it
                LP.hasLostCurrentInstance = false
            end)
        else
            -- Reset the flag if we didn't lose
            LP.hasLostCurrentInstance = false
        end
    elseif inInstance and (instanceType == "arena" or instanceType == "pvp") then
        -- Player has entered a PvP instance
        LP.wasInPvPInstance = true
        LP.isInPvPInstance = true
        LP.currentInstanceType = instanceType == "arena" and "arena" or "battleground"
        LP.currentInstanceID = select(8, GetInstanceInfo()) -- Get instance ID
        LP.hasLostCurrentInstance = false
        
        LP:DebugPrint("Entered PvP instance: " .. LP.currentInstanceType)
        
        -- Register CHAT_MSG_SYSTEM only when entering PvP instance
        if LP.eventFrame then
            LP.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
            LP:DebugPrint("Registered CHAT_MSG_SYSTEM")
        end
    end
end

-- Function to update the exercises list based on enabled settings
function LP:UpdateExercisesList()
    -- Reset the exercises list
    LP.exercises = {}
    
    -- Add each exercise if it's enabled
    if LP.db.enabledExercises.Pushups then
        table.insert(LP.exercises, "10 Pushups")
    end
    
    if LP.db.enabledExercises.Squats then
        table.insert(LP.exercises, "10 Squats")
    end
    
    if LP.db.enabledExercises.Situps then
        table.insert(LP.exercises, "10 Situps")
    end
    
    -- If no exercises are enabled, enable pushups as a fallback
    if #LP.exercises == 0 then
        LP.db.enabledExercises.Pushups = true
        table.insert(LP.exercises, "10 Pushups")
    end
    
    LP:DebugPrint("Updated exercises list. Total exercises: " .. #LP.exercises)
end

-- Function to open the options panel
function LP:OpenOptionsPanel()
    if Settings and Settings.OpenToCategory and LP.optionsCategory then
        -- Use the new Settings API for Dragonflight or later
        Settings.OpenToCategory(LP.optionsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory and LP.optionsPanel then
        -- Fallback for older versions of WoW
        InterfaceOptionsFrame_OpenToCategory(LP.optionsPanel)
        -- Call it twice due to a known bug in the Blizzard UI
        InterfaceOptionsFrame_OpenToCategory(LP.optionsPanel)
    else
        print(addonName .. ": Unable to open options panel.")
    end
end

-- Create a loader frame at the file level (outside any functions)
local loaderFrame = CreateFrame("Frame")

-- Setup the ADDON_LOADED event handler
loaderFrame:SetScript("OnEvent", function(self, event, loadedAddonName)
    if event == "ADDON_LOADED" and loadedAddonName == addonName then
        LP:DebugPrint("Addon loaded event processed.")
        LP:Initialize() -- Call Initialize when our addon loads
        self:UnregisterEvent("ADDON_LOADED") -- Unregister after loading
    end
end)

-- Register for ADDON_LOADED immediately
loaderFrame:RegisterEvent("ADDON_LOADED") 