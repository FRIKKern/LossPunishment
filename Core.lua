local addonName, addonTable = ...

-- Create a namespace for the addon
LossPunishment = LossPunishment or {}
local LP = LossPunishment
LP.Version = "0.1.5" -- Update version to match .toc file

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
            },
            debugMode = true -- Enable debug by default for first run
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
    elseif command == "test" then 
        -- Single test command for showing exercise prompt
        local nextExercise = LP:GetNextExercise()
        if LP.ShowExercisePrompt then
            LP:ShowExercisePrompt(nextExercise, "test")
            print(addonName .. ": Test exercise prompt: " .. nextExercise)
        else
            print(addonName .. ": Test exercise - " .. nextExercise)
        end
    elseif command == "loss" then
        -- Immediate exercise after a lost game (manual trigger)
        print(addonName .. ": Manual loss - triggering exercise.")
        local nextExercise = LP:GetNextExercise()
        if LP.ShowExercisePrompt then
            LP:ShowExercisePrompt(nextExercise, "manual")
        else
            print(addonName .. ": Your punishment is: " .. nextExercise)
        end
    elseif command == "win" then
        -- Manually mark an arena as won (to prevent exercise prompt)
        LP.db.lastArenaWasWin = true
        LP.hasLostCurrentInstance = false
        print(addonName .. ": Manually marked as a win - no exercise will be triggered.")
    elseif command == "options" or command == "config" then
        -- Open the options panel
        LP:OpenOptionsPanel()
    elseif command == "fix" then
        -- Force-update instance detection
        local inInstance, instanceType = LP:ForceDetection()
        if LP.isInPvPInstance then
            print(addonName .. ": Detection fixed! You are in " .. LP.currentInstanceType .. ".")
        else
            print(addonName .. ": You are not in a PvP instance (result: " .. tostring(inInstance) .. ", " .. tostring(instanceType) .. ").")
        end
    elseif command == "status" then
        -- Force a refresh of instance detection before showing status
        LP:ForceDetection()
        
        -- Show current tracking state
        local stateInfo = addonName .. " current state:"
        stateInfo = stateInfo .. "\n- In PvP instance: " .. tostring(LP.isInPvPInstance)
        stateInfo = stateInfo .. "\n- Instance type: " .. tostring(LP.currentInstanceType)
        stateInfo = stateInfo .. "\n- Loss detected: " .. tostring(LP.hasLostCurrentInstance)
        stateInfo = stateInfo .. "\n- Win detected: " .. tostring(LP.db.lastArenaWasWin)
        stateInfo = stateInfo .. "\n- Was in PvP: " .. tostring(LP.wasInPvPInstance)
        stateInfo = stateInfo .. "\n- Current instance data: " .. select(2, IsInInstance())
        
        print(stateInfo)
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
        print("  /lp test - Test the exercise prompt.")
        print("  /lp loss - Manually trigger an exercise prompt.")
        print("  /lp win - Mark the last arena as a win (prevents exercise).")
        print("  /lp fix - Fix detection if addon isn't recognizing you're in arena.")
        print("  /lp options - Opens the options panel.")
        print("  /lp status - Shows the current state of arena tracking.")
        print("  /lp stats - Shows exercise completion statistics.")
        print("  /lp debug - Toggles debug message printing.")
        print("  /lp help - Shows this help message.")
    else
        print(addonName .. ": Unknown command '" .. command .. "'. Type '/lp help' for options.")
    end
end

-- Add this helper function for safely registering events
function LP:SafeRegisterEvent(frame, event)
    local success, errorMsg = pcall(function() 
        frame:RegisterEvent(event)
    end)
    
    if success then
        LP:DebugPrint("Registered event: " .. event)
        return true
    else
        LP:DebugPrint("Could not register event '" .. event .. "' - not supported in this WoW version")
        return false
    end
end

-- Function to register WoW events
function LP:RegisterEvents()
    if LP.eventFrame then return end -- Already registered

    local frame = CreateFrame("Frame", "LossPunishmentEventFrame")
    LP.eventFrame = frame -- Store the frame reference

    -- Base events that should work in all WoW versions (register directly)
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("CHAT_MSG_SYSTEM")
    
    -- Events that might vary between WoW versions (register safely)
    LP:SafeRegisterEvent(frame, "PVP_MATCH_COMPLETE")
    LP:SafeRegisterEvent(frame, "UPDATE_BATTLEFIELD_STATUS")
    LP:SafeRegisterEvent(frame, "CHAT_MSG_BG_SYSTEM_NEUTRAL")
    LP:SafeRegisterEvent(frame, "CHAT_MSG_HONOR_GAIN")
    
    -- Potentially version-specific arena events (register safely)
    local hasArenaMatchEnd = LP:SafeRegisterEvent(frame, "ARENA_MATCH_END")
    
    -- Only try to register these if ARENA_MATCH_END was successful (likely same API era)
    if hasArenaMatchEnd then
        LP:SafeRegisterEvent(frame, "ARENA_TEAM_ROSTER_UPDATE")
        LP:SafeRegisterEvent(frame, "UPDATE_BATTLEFIELD_SCORE")
    end
    
    -- Version detection - store for future conditional logic
    LP.hasArenaMatchEndEvent = hasArenaMatchEnd
    
    -- Check if relevant battlefield functions exist (for version detection)
    LP.hasIsActiveBattlefieldArena = (IsActiveBattlefieldArena ~= nil)
    LP.hasGetBattlefieldWinner = (GetBattlefieldWinner ~= nil)
    
    LP:DebugPrint("API detection: IsActiveBattlefieldArena=" .. tostring(LP.hasIsActiveBattlefieldArena) .. 
                  ", GetBattlefieldWinner=" .. tostring(LP.hasGetBattlefieldWinner) ..
                  ", ARENA_MATCH_END=" .. tostring(LP.hasArenaMatchEndEvent))

    frame:SetScript("OnEvent", function(self, event, ...)
        -- Wrap the entire event handler logic in SafeCall, passing event and args
        LP:SafeCall(function(currentEvent, ...) -- Pass event and varargs as arguments
            LP:DebugPrint("Event received: " .. currentEvent)
            -- Any zone change event should trigger an instance check
            if currentEvent == "ZONE_CHANGED_NEW_AREA" or
               currentEvent == "ZONE_CHANGED" or
               currentEvent == "ZONE_CHANGED_INDOORS" then
                -- Force-refresh detection on any zone change
                LP:ForceDetection()
            elseif currentEvent == "PLAYER_ENTERING_WORLD" then
                -- Handle player entering world (instance transitions)
                LP:SafeCall(LP.HandlePlayerEnteringWorld, LP)
            elseif currentEvent == "CHAT_MSG_SYSTEM" then
                -- Only process system messages when in PvP instance
                if LP.isInPvPInstance then
                    -- Wrap the specific call, passing self (LP) and the message arguments (...)
                    LP:SafeCall(LP.ProcessSystemMessage, LP, ...) 
                end
            elseif currentEvent == "CHAT_MSG_BG_SYSTEM_NEUTRAL" then
                -- Handle neutral battleground/arena system messages
                local message = ...
                LP:DebugPrint("BG system message: " .. tostring(message))
                
                -- Parse for team victory messages that indicate win/loss
                if message then
                    local playerFaction = LP.playerFaction or UnitFactionGroup("player")
                    
                    -- Look for typical arena end messages
                    if LP.isInPvPInstance and LP.currentInstanceType == "arena" then
                        -- In arenas, the system often announces which team won
                        if string.find(message, "Alliance") or string.find(message, "Blue") or string.find(message, "1") then
                            if playerFaction == "Alliance" then
                                LP:DebugPrint("BG System: Your team (Alliance) won")
                                LP.db.lastArenaWasWin = true
                                print(addonName .. ": Alliance/Blue team victory detected - your team won!")
                            else
                                LP:DebugPrint("BG System: Enemy team (Alliance) won")
                                LP.hasLostCurrentInstance = true
                                print(addonName .. ": Alliance/Blue team victory detected - your team lost.")
                            end
                        elseif string.find(message, "Horde") or string.find(message, "Green") or string.find(message, "0") then
                            if playerFaction == "Horde" then
                                LP:DebugPrint("BG System: Your team (Horde) won")
                                LP.db.lastArenaWasWin = true
                                print(addonName .. ": Horde/Green team victory detected - your team won!")
                            else
                                LP:DebugPrint("BG System: Enemy team (Horde) won")
                                LP.hasLostCurrentInstance = true
                                print(addonName .. ": Horde/Green team victory detected - your team lost.")
                            end
                        end
                    end
                end
            elseif currentEvent == "PVP_MATCH_COMPLETE" then
                -- New event for retail arena end
                if LP.isInPvPInstance and LP.currentInstanceType == "arena" then
                    local winner = ...
                    local myTeam = LP:GetPlayerTeamIndex()
                    LP:DebugPrint("PVP match complete - winner team: " .. tostring(winner) .. ", my team: " .. tostring(myTeam))
                    
                    if winner == myTeam then
                        -- Player's team is the winner
                        LP:DebugPrint("Arena match complete, player's team WON")
                        LP.db.lastArenaWasWin = true
                        print(addonName .. ": Arena win detected from match complete! No punishment needed.")
                    elseif winner ~= 0 and winner ~= myTeam then 
                        -- Player's team isn't the winner and a team won (not a draw)
                        LP:DebugPrint("Arena match complete, player's team lost")
                        LP.hasLostCurrentInstance = true
                        print(addonName .. ": Arena loss detected. Punishment will be triggered when you leave the arena.")
                    end
                end
            elseif currentEvent == "UPDATE_BATTLEFIELD_STATUS" then
                -- Check if we're leaving a battlefield
                LP:SafeCall(LP.CheckBattlefieldStatus, LP)
            elseif currentEvent == "ARENA_MATCH_END" and LP.hasArenaMatchEndEvent then
                -- Only call this if we know the event exists (checked during registration)
                LP:SafeCall(LP.CheckArenaMatchResult, LP)
            elseif currentEvent == "UPDATE_BATTLEFIELD_SCORE" then
                -- Check scores for win indications
                LP:SafeCall(LP.CheckBattlefieldScore, LP)
            elseif currentEvent == "CHAT_MSG_HONOR_GAIN" then
                -- Honor gain often means a win
                if LP.isInPvPInstance and LP.currentInstanceType == "arena" then
                    local honorText = ...
                    LP:DebugPrint("Honor gain detected: " .. tostring(honorText))
                    -- Honor gain usually means a win
                    LP.db.lastArenaWasWin = true
                    print(addonName .. ": Arena win detected from honor gain! No punishment needed.")
                end
            end
        end, event, ...) -- Pass event and varargs from outer scope into SafeCall
    end)
    
    LP:DebugPrint("Base events registered.")
    
    -- Perform an immediate instance check after registering events
    LP:ForceDetection()
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

-- New helper function to get player's team index
function LP:GetPlayerTeamIndex()
    -- Try to determine player's team index (0 or 1)
    local myTeam = nil
    for i = 1, GetNumBattlefieldScores() do
        local name, _, _, _, _, team = GetBattlefieldScore(i)
        -- GetBattlefieldScore returns different values in different game versions
        -- so we'll handle various return formats
        
        -- In some versions, the player name is the first return
        if name == UnitName("player") then
            myTeam = team
            break
        end
        
        -- In other versions, the data might be structured differently
        -- Add more checks if needed based on testing
    end
    return myTeam
end

-- New function to check arena match result directly from the ARENA_MATCH_END event
function LP:CheckArenaMatchResult()
    if not LP.isInPvPInstance or LP.currentInstanceType ~= "arena" then
        return
    end
    
    LP:DebugPrint("Checking arena match result")
    
    -- First method: Check winner from API (most reliable)
    if LP.hasGetBattlefieldWinner and GetBattlefieldWinner then
        local success, winner = pcall(GetBattlefieldWinner)
        if success then
            LP:DebugPrint("GetBattlefieldWinner returned: " .. tostring(winner))
            
            if winner ~= nil then
                LP:DebugPrint("Match has finished with a result")
                
                -- Get player's team/faction for comparison
                local playerFaction = LP.playerFaction or UnitFactionGroup("player")
                local myTeam = LP:GetPlayerTeamIndex()
                
                -- Log team info for debugging
                LP:DebugPrint("Player faction: " .. tostring(playerFaction) .. ", team index: " .. tostring(myTeam))
                
                -- Different versions of WoW use different team indexes - try multiple approaches
                -- Some versions use 0=Horde/Green, 1=Alliance/Blue
                -- Others might use team indexes from GetBattlefieldScore
                
                -- Method 1: Direct team index comparison
                if myTeam ~= nil then
                    if winner == myTeam then
                        LP:DebugPrint("Arena win detected from GetBattlefieldWinner - team match")
                        LP.db.lastArenaWasWin = true
                        print(addonName .. ": Arena win detected! No punishment needed.")
                        return true
                    elseif winner ~= 255 then -- 255 is a draw
                        LP:DebugPrint("Arena loss detected from GetBattlefieldWinner - team mismatch")
                        LP.hasLostCurrentInstance = true
                        print(addonName .. ": Arena loss detected. Punishment will be triggered when you leave the arena.")
                        return false
                    end
                end
                
                -- Method 2: Faction-based comparison (more reliable in some WoW versions)
                if playerFaction then
                    if (winner == 0 and playerFaction == "Horde") or (winner == 1 and playerFaction == "Alliance") then
                        LP:DebugPrint("Arena win detected from GetBattlefieldWinner - faction match")
                        LP.db.lastArenaWasWin = true
                        print(addonName .. ": Arena win detected! No punishment needed.")
                        return true
                    elseif winner ~= 255 then -- Not a draw
                        LP:DebugPrint("Arena loss detected from GetBattlefieldWinner - faction mismatch")
                        LP.hasLostCurrentInstance = true
                        print(addonName .. ": Arena loss detected. Punishment will be triggered when you leave the arena.")
                        return false
                    end
                end
            end
        end
    end
    
    -- Second method: Check rating change directly
    if GetBattlefieldTeamInfo then
        -- Use pcall for safety
        local success, info = pcall(function() return {GetBattlefieldTeamInfo(0)} end)
        if success and info and #info >= 2 then
            local myRating, myRatingChange = info[1], info[2]
            LP:DebugPrint("Rating info - Current: " .. tostring(myRating) .. ", Change: " .. tostring(myRatingChange))
            
            if myRatingChange and myRatingChange > 0 then
                LP:DebugPrint("Positive rating change detected - definite win")
                LP.db.lastArenaWasWin = true
                print(addonName .. ": Arena win detected from rating gain! No punishment needed.")
                return true
            elseif myRatingChange and myRatingChange < 0 then
                LP:DebugPrint("Negative rating change detected - definite loss")
                LP.hasLostCurrentInstance = true
                print(addonName .. ": Arena loss detected from rating loss. Punishment will be triggered when you leave the arena.")
                return false
            end
        end
    end
    
    -- Third method: Check score data
    if GetTeamScore then
        local success, myTeam = pcall(LP.GetPlayerTeamIndex, LP)
        if success and myTeam then
            myTeam = myTeam or 0
            local enemyTeam = myTeam == 0 and 1 or 0
            
            -- Use pcall for safety
            local myTeamScore, enemyTeamScore
            pcall(function() myTeamScore = GetTeamScore(myTeam) end)
            pcall(function() enemyTeamScore = GetTeamScore(enemyTeam) end)
            
            LP:DebugPrint("Team scores - Mine: " .. tostring(myTeamScore) .. ", Enemy: " .. tostring(enemyTeamScore))
            
            if myTeamScore and enemyTeamScore then
                if myTeamScore > enemyTeamScore then
                    LP:DebugPrint("Win detected from team scores")
                    LP.db.lastArenaWasWin = true
                    print(addonName .. ": Arena win detected from team scores! No punishment needed.")
                    return true
                elseif enemyTeamScore > myTeamScore then 
                    LP:DebugPrint("Loss detected from team scores")
                    LP.hasLostCurrentInstance = true
                    print(addonName .. ": Arena loss detected from team scores. Punishment will be triggered when you leave the arena.")
                    return false
                end
            end
        end
    end
    
    -- No definitive outcome detected
    return nil
end

-- New function to check battlefield score data
function LP:CheckBattlefieldScore()
    if not LP.isInPvPInstance or LP.currentInstanceType ~= "arena" then
        return
    end
    
    -- Look for team scores that might indicate a win
    local myScore, enemyScore = 0, 0
    local myTeam = LP:GetPlayerTeamIndex()
    
    if not myTeam then
        LP:DebugPrint("Could not determine player's team")
        return
    end
    
    local enemyTeam = myTeam == 0 and 1 or 0
    
    -- Some versions of WoW have GetTeamScore API
    if GetTeamScore then
        myScore = GetTeamScore(myTeam)
        enemyScore = GetTeamScore(enemyTeam)
        
        LP:DebugPrint("Team scores - My team: " .. tostring(myScore) .. ", Enemy team: " .. tostring(enemyScore))
        
        if myScore > enemyScore then
            LP:DebugPrint("Win detected from team scores")
            LP.db.lastArenaWasWin = true
            print(addonName .. ": Arena win detected from scores! No punishment needed.")
        elseif enemyScore > myScore then
            LP:DebugPrint("Loss detected from team scores")
            LP.hasLostCurrentInstance = true
        end
    end
    
    -- Also check match statistics in case we can find wins from there
    local playerStats = {}
    for i = 1, GetNumBattlefieldScores() do
        local name, killingBlows, honorableKills, deaths, honorGained, _, _, _, _, teamIndex = GetBattlefieldScore(i)
        
        -- If we get honor but no team index, we might be in an older version
        -- In some versions, honorGained indicates a win
        if name == UnitName("player") and honorGained and honorGained > 0 then
            LP:DebugPrint("Player received honor - likely a win")
            LP.db.lastArenaWasWin = true
            print(addonName .. ": Arena win detected from honor gain! No punishment needed.")
            return
        end
    end
end

-- Function to process system messages for win/loss detection
function LP:ProcessSystemMessage(msg)
    if not LP.isInPvPInstance then
        return
    end

    LP:DebugPrint("Processing system message: " .. tostring(msg))
    
    -- Always log arena messages to help with debugging patterns
    if LP.currentInstanceType == "arena" then
        -- Log all arena messages even with debug off
        print("|cff00ffff[" .. addonName .. " Arena Message]|r: " .. tostring(msg))
    end

    -- Track wins explicitly to improve our fallback mechanism
    local winDetected = false

    -- Arena Win Detection - expanded patterns
    if LP.currentInstanceType == "arena" then
        local arenaWinPatterns = {
            -- Generic win patterns
            "You win", 
            "You are victorious",
            "Victory",
            "your team is victorious",
            "Your team is victorious",
            "You were awarded",
            "Victorious",
            "Winner",
            "Your team won",
            
            -- Score patterns
            "^(%d+)%s*%-%s*(%d+)",  -- Score pattern like "3-0" 
            "wins %d+%s*to%s*%d+",  -- Format: "Team X wins 3 to 0"
            
            -- Rating change indicators
            "You gain %d+ rating",
            "Your personal rating has increased by %d+",
            "rating changed .+ %+%d+",
            
            -- Match end with win context
            "won the Arena match",
            " has won the match",
            
            -- New patterns from ArenaAnalytics
            "Team score: %d+",     -- Score message
            "You gain %d+ honor",  -- Honor gain (almost always a win)
            "You gain conquest",   -- Conquest gain (always a win)
            "final score: %d+",    -- Final score message
            "Team %d defeated",    -- Team defeat message that isn't your team
            "winner! %d+",         -- Winner announcement 
            
            -- Some versions have these formats
            "Arena ended. You earn",
            "Arena battle won!"
        }
        
        for i, pattern in ipairs(arenaWinPatterns) do
            local match = string.match(msg, pattern)
            if match then
                -- Special handling for score pattern (e.g. "3 - 0")
                if i == 10 then -- This is the score pattern index (^(%d+)%s*%-%s*(%d+))
                    local score1, score2 = string.match(msg, "^(%d+)%s*%-%s*(%d+)")
                    if score1 and score2 then
                        local playerScore = tonumber(score1)
                        local enemyScore = tonumber(score2)
                        
                        -- In most formats, higher score means win
                        if playerScore > enemyScore then
                            LP:DebugPrint("Detected Arena WIN via score: " .. playerScore .. " - " .. enemyScore)
                            winDetected = true
                            LP.db.lastArenaWasWin = true
                            print(addonName .. ": Arena win detected from score! No punishment needed.")
                            return
                        end
                    end
                else
                    -- Regular pattern match
                    LP:DebugPrint("Detected Arena WIN via system message: " .. msg)
                    winDetected = true
                    LP.db.lastArenaWasWin = true
                    print(addonName .. ": Arena win detected! No punishment needed.")
                    return
                end
            end
        end
    end

    -- Already detected a loss for this instance
    if LP.hasLostCurrentInstance then
        return
    end

    -- Arena Loss Detection
    if LP.currentInstanceType == "arena" then
        -- Track arena end separately from win/loss for debugging
        if string.find(msg, "arena.*ended") or 
           string.find(msg, "match.*complete") or 
           string.find(msg, "battle.*ended") or
           string.find(msg, "victory") or 
           string.find(msg, "defeat") then
            LP:DebugPrint("Arena match end detected.")
            
            -- Try to get more specific arena information using multiple methods
            
            -- Method 1: GetBattlefieldTeamInfo
            local info = { GetBattlefieldTeamInfo(0) }
            local myRating, myRatingChange = unpack(info)
            LP:DebugPrint("Your team final info - Rating: " .. tostring(myRating) .. ", Change: " .. tostring(myRatingChange))
            
            if myRatingChange and myRatingChange > 0 then
                LP:DebugPrint("Positive rating change detected - marking as win")
                LP.db.lastArenaWasWin = true
                print(addonName .. ": Arena win detected from rating change! No punishment needed.")
                return
            end
            
            -- Method 2: Check winner directly
            local winner = GetBattlefieldWinner()
            local myTeam = LP:GetPlayerTeamIndex()
            LP:DebugPrint("Winner: " .. tostring(winner) .. ", My team: " .. tostring(myTeam))
            
            if winner == myTeam then
                LP:DebugPrint("Winner matches player team - marking as win")
                LP.db.lastArenaWasWin = true
                print(addonName .. ": Arena win detected from winner check! No punishment needed.")
                return
            end
            
            -- Method 3: Get scores
            if GetTeamScore then
                local myTeamScore = GetTeamScore(myTeam or 0)
                local otherTeamScore = GetTeamScore(myTeam == 0 and 1 or 0)
                LP:DebugPrint("Team scores - Mine: " .. tostring(myTeamScore) .. ", Other: " .. tostring(otherTeamScore))
                
                if myTeamScore and otherTeamScore and myTeamScore > otherTeamScore then
                    LP:DebugPrint("Higher score - marking as win")
                    LP.db.lastArenaWasWin = true
                    print(addonName .. ": Arena win detected from team scores! No punishment needed.")
                    return
                end
            end
        end
        
        -- Expanded patterns for Retail WoW arena loss messages
        local arenaLossPatterns = {
            "You lose", -- General pattern
            "You have lost the arena", -- Some versions
            "You were defeated", -- Retail common message
            "Your team has been defeated", -- Other versions
            "has defeated your team", -- Yet another variant
            "has won the arena match", -- When opponent team wins
            " wins!", -- Common retail message
            "The Arena battle has ended", -- End message that happens on both win/loss
            "Defeat", -- Retail defeat message
            "Match complete", -- General completion message
            "defeated by", -- Appears in many defeat messages
            "Lost:", -- Arena score message
            "%d+%s*%-%s*%d+", -- Score pattern like "0 - 3"
            "has ended", -- Generic end message
            "battle is over", -- Another end message
            "defeat", -- Lowercase defeat message
            "your team has lost", -- Specific loss message
            "your team was defeated", -- Another specific loss message
            "the opposing team is victorious", -- Opposition victory message
            "arena concluded" -- Generic conclusion message
        }
        
        for _, pattern in ipairs(arenaLossPatterns) do
            if string.find(msg, pattern) then
                -- For generic messages like "match complete" or "has ended"
                -- we shouldn't mark as loss immediately if they can also appear on wins
                local isGenericMessage = (pattern == "The Arena battle has ended" or 
                                         pattern == "Match complete" or 
                                         pattern == "has ended" or
                                         pattern == "battle is over" or
                                         pattern == "arena concluded")
                
                if isGenericMessage then
                    -- For generic messages, check if we've already detected a win
                    if not LP.db.lastArenaWasWin then
                        LP:DebugPrint("Generic arena end message detected, waiting for win confirmation: " .. msg)
                        
                        -- Set timer to check if we need to assume a loss
                        C_Timer.After(3.0, function()
                            if LP.isInPvPInstance and not LP.db.lastArenaWasWin and not LP.hasLostCurrentInstance then
                                LP:DebugPrint("No explicit win detected after arena end message - assuming loss")
                                LP.hasLostCurrentInstance = true
                            end
                        end)
                    end
                else
                    -- For specific loss messages
                    LP:DebugPrint("Detected Arena Loss via system message: " .. msg)
                    LP.hasLostCurrentInstance = true
                    LP.db.lastArenaWasWin = false
                    print(addonName .. ": Arena loss detected. Punishment will be triggered when you leave the arena.")
                    return
                end
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
    LP:DebugPrint("Win state: " .. tostring(LP.db.lastArenaWasWin))
    
    -- If available, use IsActiveBattlefieldArena for more reliable detection
    local isArena, isRegistered = false, false
    if LP.hasIsActiveBattlefieldArena and IsActiveBattlefieldArena then
        local success
        success, isArena, isRegistered = pcall(IsActiveBattlefieldArena)
        if success then
            LP:DebugPrint("IsActiveBattlefieldArena check: isArena=" .. tostring(isArena) .. ", isRegistered=" .. tostring(isRegistered))
        end
    end
    
    -- Check if we've just left an arena
    if (not inInstance and LP.wasInPvPInstance) or (LP.wasInPvPInstance and not isArena and LP.currentInstanceType == "arena") then
        -- Player has just left a PvP instance or arena match
        local lossDetected = LP.hasLostCurrentInstance
        local previousInstanceType = LP.currentInstanceType
        local savedInstanceType = LP.currentInstanceType -- Save for later use
        
        LP:DebugPrint("Detected exit from PvP instance. Type: " .. tostring(savedInstanceType) .. ", Loss detected: " .. tostring(lossDetected))
        LP:DebugPrint("Win state on exit: " .. tostring(LP.db.lastArenaWasWin))
        
        -- One last check for winner before we reset tracking
        if savedInstanceType == "arena" and LP.hasGetBattlefieldWinner and GetBattlefieldWinner then
            -- Safe call with pcall
            local success, winner = pcall(GetBattlefieldWinner)
            if success and winner ~= nil then
                -- Match definitely over, check result
                local didWin = LP:CheckArenaMatchResult()
                if didWin ~= nil then
                    lossDetected = not didWin
                    LP:DebugPrint("Final arena check on exit - win: " .. tostring(didWin) .. ", loss: " .. tostring(lossDetected))
                end
            end
        end
        
        -- Reset tracking variables AFTER saving what we need
        LP.wasInPvPInstance = false
        LP.isInPvPInstance = false
        LP.currentInstanceType = nil
        LP.currentInstanceID = nil
        
        -- Unregister system message events when exiting PvP instance
        if LP.eventFrame then
            LP.eventFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
            pcall(function() LP.eventFrame:UnregisterEvent("CHAT_MSG_BG_SYSTEM_NEUTRAL") end)
            LP:DebugPrint("Unregistered system message events")
        end
        
        if lossDetected then
            -- Use C_Timer to slightly delay the popup to ensure it appears after leaving instance
            C_Timer.After(1.0, function()
                print(addonName .. ": Loss detected - triggering exercise.")
                local nextExercise = LP:GetNextExercise()
                if LP.ShowExercisePrompt then
                    LP:ShowExercisePrompt(nextExercise, previousInstanceType)
                else
                    print(addonName .. ": Your punishment is: " .. nextExercise)
                end
                -- NOW reset this flag after we've used it
                LP.hasLostCurrentInstance = false
            end)
        else
            -- For arenas, ALWAYS assume loss unless we explicitly detected a win
            if savedInstanceType == "arena" then
                -- Only skip triggering an exercise if we explicitly detected a win
                if LP.db.lastArenaWasWin then
                    LP:DebugPrint("Arena exit after win - no exercise needed")
                    print(addonName .. ": You won the arena! No exercise needed.")
                    LP.db.lastArenaWasWin = false -- Reset the win state
                else
                    -- Final attempt to check for rating gain on exit (if the API exists)
                    local currentRating = 0
                    if GetPersonalRatedInfo then
                        pcall(function() currentRating = select(1, GetPersonalRatedInfo()) or 0 end)
                    end
                    local oldRating = LP.db.lastArenaRating or 0
                    
                    if currentRating > oldRating and oldRating > 0 then
                        LP:DebugPrint("Last-chance win detection: Rating increased from " .. oldRating .. " to " .. currentRating)
                        print(addonName .. ": Win detected from rating increase! No exercise needed.")
                    else
                        print(addonName .. ": Arena loss - triggering exercise.")
                        
                        -- Trigger the exercise prompt with a slight delay
                        C_Timer.After(1.0, function()
                            local nextExercise = LP:GetNextExercise()
                            if LP.ShowExercisePrompt then
                                LP:ShowExercisePrompt(nextExercise, "arena")
                            else
                                print(addonName .. ": Your punishment is: " .. nextExercise)
                            end
                        end)
                    end
                end
            end
            
            -- Reset the flag if we didn't lose
            LP.hasLostCurrentInstance = false
        end
    elseif (inInstance and (instanceType == "arena" or instanceType == "pvp")) or isArena then
        -- Player has entered a PvP instance
        LP.wasInPvPInstance = true
        LP.isInPvPInstance = true
        
        -- Use the most reliable source for instance type
        if isArena then
            LP.currentInstanceType = "arena"
        else
            LP.currentInstanceType = instanceType == "arena" and "arena" or "battleground"
        end
        
        LP.currentInstanceID = select(8, GetInstanceInfo()) -- Get instance ID
        LP.hasLostCurrentInstance = false
        
        -- Reset win state when entering a new arena
        if LP.currentInstanceType == "arena" then
            LP.db.lastArenaWasWin = false
            
            -- Store current rating for comparison on exit (if the API exists)
            if GetPersonalRatedInfo then
                pcall(function() 
                    LP.db.lastArenaRating = select(1, GetPersonalRatedInfo()) or 0
                    LP:DebugPrint("Stored arena entry rating: " .. LP.db.lastArenaRating)
                end)
            end
            
            -- Store player faction for later comparison
            LP.playerFaction = UnitFactionGroup("player")
            LP:DebugPrint("Stored player faction: " .. tostring(LP.playerFaction))
            
            print(addonName .. ": Now tracking arena outcomes...")
        end
        
        -- Register system message events when entering PvP instance
        if LP.eventFrame then
            LP.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
            LP:SafeRegisterEvent(LP.eventFrame, "CHAT_MSG_BG_SYSTEM_NEUTRAL")
            LP:DebugPrint("Registered system message events")
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

-- New function to check battlefield status
function LP:CheckBattlefieldStatus()
    if not LP.isInPvPInstance then return end
    
    -- Check if we're in the process of leaving a battlefield
    for i=1, GetMaxBattlefieldID() do
        local status, _, _, _, _, _, _, _, _, bgType = GetBattlefieldStatus(i)
        if (status == "active" and (bgType == "ARENA" or bgType == "BATTLEGROUND")) then
            -- We're still in a battlefield
            return
        end
    end
    
    -- No active battlefields found, but we think we're in one - might be leaving
    LP:DebugPrint("Battlefield status change detected, might be leaving")
end

-- Add a new function for force-updating instance detection
function LP:ForceDetection()
    local inInstance, instanceType = IsInInstance()
    local wasInPvp = LP.isInPvPInstance
    local isArena, isRegistered = false, false
    
    -- Use IsActiveBattlefieldArena if available (more reliable API)
    if LP.hasIsActiveBattlefieldArena and IsActiveBattlefieldArena then
        -- Use pcall to safely call the function in case of errors
        local success, result1, result2 = pcall(function() return IsActiveBattlefieldArena() end)
        if success then
            isArena, isRegistered = result1, result2
            LP:DebugPrint("IsActiveBattlefieldArena check: isArena=" .. tostring(isArena) .. ", isRegistered=" .. tostring(isRegistered))
            
            -- IsActiveBattlefieldArena is the most reliable, so prioritize it
            if isArena then
                LP.isInPvPInstance = true
                LP.currentInstanceType = "arena"
                LP.currentInstanceID = select(8, GetInstanceInfo())
                -- No need to check further if we're definitely in an arena
            end
        else
            LP:DebugPrint("Error calling IsActiveBattlefieldArena")
        end
    end
    
    -- If not detected as arena via API, use the fallback method
    if not isArena then
        -- Update state based on instance information
        LP.isInPvPInstance = (inInstance and (instanceType == "arena" or instanceType == "pvp"))
        LP.currentInstanceType = LP.isInPvPInstance and (instanceType == "arena" and "arena" or "battleground") or nil
    end
    
    -- Always check for GetBattlefieldWinner to detect end of match
    if LP.isInPvPInstance and LP.currentInstanceType == "arena" and LP.hasGetBattlefieldWinner and GetBattlefieldWinner then
        -- Use pcall for safety
        local success, winner = pcall(GetBattlefieldWinner)
        if success and winner ~= nil then
            -- Match has ended, check for win/loss
            LP:CheckArenaMatchResult()
        end
    end
    
    if LP.isInPvPInstance and not wasInPvp then
        -- We weren't tracking but should be - update other flags
        LP.wasInPvPInstance = true
        LP.hasLostCurrentInstance = false
        
        -- Reset win state when entering a new arena
        if LP.currentInstanceType == "arena" then
            LP.db.lastArenaWasWin = false
            
            -- Store current rating for comparison on exit (if the API exists)
            if GetPersonalRatedInfo then
                local success, rating = pcall(function() return select(1, GetPersonalRatedInfo()) end)
                if success then
                    LP.db.lastArenaRating = rating or 0
                    LP:DebugPrint("Stored arena entry rating: " .. LP.db.lastArenaRating)
                end
            end
            
            -- Get player's faction and team for later comparison
            LP.playerFaction = UnitFactionGroup("player")
            LP:DebugPrint("Player faction: " .. tostring(LP.playerFaction))
            
            print(addonName .. ": Fixed detection - now tracking arena outcomes...")
        end
        
        -- Register system messages for match outcome detection
        if LP.eventFrame then
            LP.eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
            if LP:SafeRegisterEvent(LP.eventFrame, "CHAT_MSG_BG_SYSTEM_NEUTRAL") then
                LP:DebugPrint("Force-registered system message events")
            end
        end
    end
    
    return inInstance, instanceType
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
