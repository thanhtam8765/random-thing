-- Roblox Lua script for automated targeting and attacking system
-- This script listens for commands from the local player and a specific player, targeting other players for melee attacks

-- Get the local player
local localPlayer = game.Players.LocalPlayer

-- Variables for character and humanoid root part
local character, humanoidRootPart

-- Safe position to retreat to after attacks
local safePosition = Vector3.new(-202, 67, 2524)

-- List of target names, active flag, and active coroutine
local targets = {}
local isActive = false
local activeCoroutine = nil

-- Command registry
local commands = {}

-- Function to register a new command
local function registerCommand(commandPrefix, handler)
    commands[commandPrefix] = handler
end

-- Function to handle incoming messages
local function handleMessage(message)
    for prefix, handler in pairs(commands) do
        if message:sub(1, #prefix) == prefix then
            local args = message:sub(#prefix + 1)
            handler(args)
            break
        end
    end
end

-- Function to set up character references
local function setupCharacter()
    character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
end

-- Initialize character setup
setupCharacter()

-- Connect to character added event to update references
localPlayer.CharacterAdded:Connect(setupCharacter)

-- Function to find player by partial name match
local function findPlayerByName(name)
    for _, player in pairs(game.Players:GetPlayers()) do
        if player.Name:lower():sub(1, #name) == name:lower() then
            return player
        end
    end
    return nil
end

-- Function to teleport to target position
local function teleportToTarget(target)
    if target and target.Character then
        local targetHumanoidRootPart = target.Character:FindFirstChild("HumanoidRootPart")
        if targetHumanoidRootPart then
            local position = targetHumanoidRootPart.Position + Vector3.new(0, -5, 0)
            if position.Y > -500 then
                -- Stand up if sitting
                if character:FindFirstChild("Humanoid") and character.Humanoid.Sit then
                    character.Humanoid.Sit = false
                end
                -- Teleport to position
                character:PivotTo(CFrame.new(position))
            end
        end
    end
end

-- Function to start attacking targets
local function startAttacking()
    -- Close any existing coroutine
    if activeCoroutine then
        coroutine.close(activeCoroutine)
    end
    isActive = true
    activeCoroutine = coroutine.create(function()
        while isActive and #targets > 0 do
            wait()
            -- Iterate through targets in reverse order
            for i = #targets, 1, -1 do
                local targetName = targets[i]
                local targetPlayer = findPlayerByName(targetName)
                if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid") then
                    -- Teleport to target
                    teleportToTarget(targetPlayer)
                    -- Attack loop while target is alive and no forcefield
                    while targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
                          and targetPlayer.Character.Humanoid.Health > 0
                          and not targetPlayer.Character:FindFirstChild("ForceField")
                          and character:FindFirstChild("Humanoid") do
                        -- Fire melee event
                        game.ReplicatedStorage.meleeEvent:FireServer(targetPlayer)
                        wait(0.01)
                        -- Re-teleport if still alive
                        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("Humanoid")
                           and targetPlayer.Character.Humanoid.Health > 0 then
                            teleportToTarget(targetPlayer)
                        end
                    end
                    -- Retreat to safe position
                    character:PivotTo(CFrame.new(safePosition))
                    wait(1)
                else
                    -- Remove invalid target
                    if not targetPlayer then
                        table.remove(targets, i)
                    end
                end
            end
        end
    end)
    coroutine.resume(activeCoroutine)
end

-- Function to stop attacking all targets
local function stopAttacking()
    isActive = false
    if activeCoroutine then
        coroutine.close(activeCoroutine)
    end
    activeCoroutine = nil
    targets = {}
end

-- Function to remove a specific target
local function removeTarget(name)
    for i, targetName in ipairs(targets) do
        if targetName:lower() == name:lower() then
            table.remove(targets, i)
            print("Removed " .. name)
            return true
        end
    end
    print("Target " .. name .. " not found")
    return false
end

-- Register default commands
registerCommand(":lk ", function(args)
    local name = args
    if not table.find(targets, name) then
        table.insert(targets, name)
        print("Added " .. name)
    end
    startAttacking()
end)

registerCommand(":unlk ", function(args)
    local name = args
    if name == "" then
        -- If no name provided, stop all attacking
        stopAttacking()
    else
        -- Remove specific target
        removeTarget(name)
        -- If no targets left, stop attacking
        if #targets == 0 then
            stopAttacking()
        end
    end
end)

-- Connect to local player's chat
localPlayer.Chatted:Connect(handleMessage)

-- Connect to chat events for the specific player
local specificPlayer = game.Players:FindFirstChild("thanhtam8765")
if specificPlayer then
    specificPlayer.Chatted:Connect(handleMessage)
end

-- Handle player joining
game.Players.PlayerAdded:Connect(function(joinedPlayer)
    if joinedPlayer.Name == "thanhtam8765" then
        joinedPlayer.Chatted:Connect(handleMessage)
    end
end)
