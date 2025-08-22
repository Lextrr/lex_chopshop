local QBCore = exports['qb-core']:GetCoreObject()
local cooldowns = {}

-- Functions
local function DebugPrint(msg)
    if Config.Debug then
        print('[LEX_CHOPSHOP] ' .. msg)
    end
end

local function IsOnCooldown(playerId)
    if not cooldowns[playerId] then return false end
    local timePassed = os.time() - cooldowns[playerId]
    return timePassed < Config.Cooldown
end

local function HasRequiredJob(Player)
    if not Config.RequireJob then return true end
    if not Player.PlayerData.job then return false end
    
    for _, job in pairs(Config.AllowedJobs) do
        if Player.PlayerData.job.name == job then
            return true
        end
    end
    return false
end

local function GetRandomReward()
    local rand = math.random(100)
    local rewardType = 'common'
    
    if rand <= Config.Rewards.rare.chance then
        rewardType = 'rare'
    elseif rand <= Config.Rewards.rare.chance + Config.Rewards.uncommon.chance then
        rewardType = 'uncommon'
    end
    
    local rewards = {}
    local selectedReward = Config.Rewards[rewardType]
    
    for _, item in pairs(selectedReward.items) do
        local amount = math.random(item.amount[1], item.amount[2])
        table.insert(rewards, {
            name = item.item,
            amount = amount
        })
    end
    
    DebugPrint('Generated ' .. rewardType .. ' rewards')
    return rewards, rewardType
end

local function GetItemLabel(itemName)
    local item = exports.ox_inventory:Items(itemName)
    return item and item.label or itemName
end

-- Events
RegisterNetEvent('lex_chopshop:server:chopVehicle', function(netId, shopId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        DebugPrint('Player not found: ' .. src)
        return
    end
    
    DebugPrint('Chop request from player: ' .. Player.PlayerData.name .. ' (' .. src .. ')')
    
    -- Check cooldown
    if IsOnCooldown(src) then
        TriggerClientEvent('lex_chopshop:client:error', src, 'You are on cooldown')
        DebugPrint('Player ' .. src .. ' is on cooldown')
        return
    end
    
    -- Check job
    if not HasRequiredJob(Player) then
        TriggerClientEvent('lex_chopshop:client:error', src, 'You don\'t have the required job')
        DebugPrint('Player ' .. src .. ' doesn\'t have required job')
        return
    end
    
    -- Get vehicle
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(vehicle) then
        TriggerClientEvent('lex_chopshop:client:error', src, 'Vehicle not found')
        DebugPrint('Vehicle not found for netId: ' .. netId)
        return
    end
    
    -- Generate rewards
    local rewards, rewardType = GetRandomReward()
    local itemsGiven = {}
    
    -- Give items
    for _, reward in pairs(rewards) do
        local success = exports.ox_inventory:AddItem(src, reward.name, reward.amount)
        if success then
            table.insert(itemsGiven, {
                name = reward.name,
                amount = reward.amount,
                label = GetItemLabel(reward.name)
            })
            DebugPrint('Gave ' .. reward.amount .. 'x ' .. reward.name .. ' to player ' .. src)
        else
            DebugPrint('Failed to give ' .. reward.name .. ' to player ' .. src)
        end
    end
    
    -- Delete vehicle
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
        DebugPrint('Vehicle deleted')
    end
    
    -- Set cooldown
    cooldowns[src] = os.time()
    
    -- Notify success
    TriggerClientEvent('lex_chopshop:client:chopComplete', src, itemsGiven)
    
    DebugPrint('Player ' .. src .. ' successfully chopped vehicle (Type: ' .. rewardType .. ')')
end)

-- Cleanup on disconnect
RegisterNetEvent('QBCore:Server:OnPlayerUnload', function(src)
    if cooldowns[src] then
        cooldowns[src] = nil
        DebugPrint('Cleaned cooldown for player: ' .. src)
    end
end)

DebugPrint('Server initialized')