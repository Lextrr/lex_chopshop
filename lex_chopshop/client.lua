local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local isChopping = false
local lastChop = 0
local chopShopBlips = {}
local inChopShop = false
local currentChopShop = nil

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    CreateBlips()
    if Config.Debug then
        print('[LEX_CHOPSHOP] Player loaded')
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- Functions
local function DebugPrint(msg)
    if Config.Debug then
        print('[LEX_CHOPSHOP] ' .. msg)
    end
end

local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
    local factor = (string.len(text)) / 370
    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

local function HasRequiredJob()
    if not Config.RequireJob then return true end
    if not PlayerData.job then return false end
    
    for _, job in pairs(Config.AllowedJobs) do
        if PlayerData.job.name == job then
            return true
        end
    end
    return false
end

local function IsOnCooldown()
    return (GetGameTimer() - lastChop) < (Config.Cooldown * 1000)
end

local function GetCooldownTime()
    local remaining = (Config.Cooldown * 1000) - (GetGameTimer() - lastChop)
    return math.ceil(remaining / 1000)
end

local function IsVehicleAllowed(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    
    local class = GetVehicleClass(vehicle)
    for _, allowedClass in pairs(Config.AllowedVehicleClasses) do
        if class == allowedClass then return true end
    end
    return false
end

local function GetVehicleValue(vehicle)
    local model = GetEntityModel(vehicle)
    return GetVehicleModelValue(model) or 10000
end

local function Notify(message, type, duration)
    if GetResourceState('ox_lib') == 'started' then
        lib.notify({
            title = 'Chop Shop',
            description = message,
            type = type or 'inform',
            duration = duration or 5000
        })
    else
        QBCore.Functions.Notify(message, type or 'primary', duration or 5000)
    end
end

local function CreateBlips()
    for _, shop in pairs(Config.ChopShops) do
        if shop.blip.enabled then
            local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
            SetBlipSprite(blip, shop.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, shop.blip.scale)
            SetBlipColour(blip, shop.blip.color)
            SetBlipAsShortRange(blip, true)
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(shop.blip.label)
            EndTextCommandSetBlipName(blip)
            
            chopShopBlips[shop.id] = blip
            DebugPrint('Created blip for ' .. shop.label)
        end
    end
end

local function StartChopping(vehicle, shopId)
    if isChopping then return end
    
    isChopping = true
    local ped = PlayerPedId()
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    
    DebugPrint('Starting chop process for vehicle netId: ' .. netId)
    
    -- Exit vehicle if inside
    if GetVehiclePedIsIn(ped, false) == vehicle then
        TaskLeaveVehicle(ped, vehicle, 0)
        Wait(2000)
    end
    
    -- Animation
    local animDict = 'mini@repair'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    
    TaskPlayAnim(ped, animDict, 'fixing_a_player', 8.0, 8.0, -1, 1, 0, false, false, false)
    
    -- Progress
    local startTime = GetGameTimer()
    local chopTime = Config.ChopTime * 1000
    
    Notify('Chopping vehicle... (' .. Config.ChopTime .. 's)', 'inform')
    
    while GetGameTimer() - startTime < chopTime do
        Wait(100)
        
        -- Check if player moved away
        local pedCoords = GetEntityCoords(ped)
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(pedCoords - vehicleCoords)
        
        if distance > 5.0 then
            StopAnimTask(ped, animDict, 'fixing_a_player', 1.0)
            Notify('You moved too far away!', 'error')
            isChopping = false
            return
        end
        
        -- Allow cancel with X
        if IsControlJustReleased(0, 73) then
            StopAnimTask(ped, animDict, 'fixing_a_player', 1.0)
            Notify('Chopping cancelled', 'error')
            isChopping = false
            return
        end
    end
    
    StopAnimTask(ped, animDict, 'fixing_a_player', 1.0)
    
    -- Trigger server event
    TriggerServerEvent('lex_chopshop:server:chopVehicle', netId, shopId)
    lastChop = GetGameTimer()
    
    isChopping = false
end

local function ChopVehicle(shopData)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    -- Find closest vehicle if not in one
    if vehicle == 0 then
        vehicle = GetClosestVehicle(coords, 5.0, 0, 70)
    end
    
    if vehicle == 0 then
        Notify('No vehicle found nearby', 'error')
        return
    end
    
    -- Checks
    if not HasRequiredJob() then
        Notify('You don\'t have the required job', 'error')
        return
    end
    
    if IsOnCooldown() then
        Notify('You must wait ' .. GetCooldownTime() .. ' seconds', 'error')
        return
    end
    
    if not IsVehicleAllowed(vehicle) then
        Notify('This vehicle type cannot be chopped', 'error')
        return
    end
    
    local value = GetVehicleValue(vehicle)
    if value < Config.MinVehicleValue then
        Notify('This vehicle is not valuable enough', 'error')
        return
    end
    
    -- Get vehicle info for display
    local model = GetEntityModel(vehicle)
    local displayName = GetDisplayNameFromVehicleModel(model)
    local vehicleName = GetLabelText(displayName)
    
    DebugPrint('Chopping vehicle: ' .. vehicleName .. ' (Value: $' .. value .. ')')
    
    -- Confirmation
    if GetResourceState('ox_lib') == 'started' then
        local alert = lib.alertDialog({
            header = 'Chop Shop',
            content = 'Chop this ' .. vehicleName .. ' for parts?',
            centered = true,
            cancel = true
        })
        
        if alert == 'confirm' then
            StartChopping(vehicle, shopData.id)
        end
    else
        -- Fallback - just start chopping
        StartChopping(vehicle, shopData.id)
    end
end

-- Main thread for chop shop detection
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        
        for _, shop in pairs(Config.ChopShops) do
            local distance = #(coords - shop.coords)
            
            if distance < shop.radius then
                sleep = 0
                
                if not inChopShop then
                    inChopShop = true
                    currentChopShop = shop
                    DebugPrint('Entered chop shop: ' .. shop.label)
                end
                
                -- Draw 3D text
                DrawText3D(shop.coords.x, shop.coords.y, shop.coords.z + 1.0, '[E] Chop Vehicle')
                
                -- Check for key press
                if IsControlJustReleased(0, 38) then -- E key
                    ChopVehicle(shop)
                end
                
                break
            end
        end
        
        if sleep == 1000 and inChopShop then
            inChopShop = false
            currentChopShop = nil
            DebugPrint('Left chop shop area')
        end
        
        Wait(sleep)
    end
end)

-- Events from server
RegisterNetEvent('lex_chopshop:client:chopComplete', function(items)
    Notify('Vehicle chopped successfully!', 'success')
    
    if items and #items > 0 then
        local itemText = {}
        for _, item in pairs(items) do
            table.insert(itemText, item.amount .. 'x ' .. item.label)
        end
        Notify('Received: ' .. table.concat(itemText, ', '), 'inform', 8000)
    end
end)

RegisterNetEvent('lex_chopshop:client:error', function(message)
    Notify(message, 'error')
end)

-- Initialize
CreateThread(function()
    Wait(1000)
    if not PlayerData.citizenid then
        PlayerData = QBCore.Functions.GetPlayerData()
    end
    CreateBlips()
    DebugPrint('Client initialized')
end)