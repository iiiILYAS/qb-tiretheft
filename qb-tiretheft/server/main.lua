local QBCore = exports['qb-core']:GetCoreObject()

local storedTires = {}
local stolenWheels = {}
local wheelReservations = {}
local playerCarrying = {}

local function hasItem(src, itemName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end

    local item = Player.Functions.GetItemByName(itemName)
    return item and (item.amount or 0) > 0
end

local function wheelKey(netId, wheelIndex)
    return ('%s:%s'):format(netId, wheelIndex)
end

QBCore.Functions.CreateCallback('qb-tiretheft:server:startWheel', function(source, cb, netId, wheelIndex)
    if not netId or not wheelIndex then
        cb(false, 'Invalid vehicle.')
        return
    end

    if playerCarrying[source] then
        cb(false, 'You are already carrying a tire.')
        return
    end

    if not hasItem(source, Config.RequiredItem) then
        cb(false, 'You need a drill.')
        return
    end

    local vehicleKey = tostring(netId)
    stolenWheels[vehicleKey] = stolenWheels[vehicleKey] or {}

    if stolenWheels[vehicleKey][wheelIndex] then
        cb(false, 'This tire is already removed.')
        return
    end

    local key = wheelKey(netId, wheelIndex)
    if wheelReservations[key] and wheelReservations[key] ~= source then
        cb(false, 'Someone is already removing this tire.')
        return
    end

    wheelReservations[key] = source
    cb(true)
end)

RegisterNetEvent('qb-tiretheft:server:finishWheel', function(netId, wheelIndex, success)
    local src = source
    local key = wheelKey(netId, wheelIndex)

    if wheelReservations[key] ~= src then return end
    wheelReservations[key] = nil

    if success then
        local vehicleKey = tostring(netId)
        stolenWheels[vehicleKey] = stolenWheels[vehicleKey] or {}
        stolenWheels[vehicleKey][wheelIndex] = true
        playerCarrying[src] = true
    end
end)

QBCore.Functions.CreateCallback('qb-tiretheft:server:storeTire', function(source, cb, netId)
    if not playerCarrying[source] then
        cb(false, 'You are not carrying a tire.')
        return
    end

    if not netId then
        cb(false, 'Invalid vehicle.')
        return
    end

    local vehicleKey = tostring(netId)
    local count = storedTires[vehicleKey] or 0

    if count >= Config.MaxTiresPerVehicle then
        cb(false, 'The trunk is full.')
        return
    end

    count = count + 1
    storedTires[vehicleKey] = count
    playerCarrying[source] = nil

    TriggerClientEvent('qb-tiretheft:client:updateTrunkTires', -1, netId, count)
    cb(true, count)
end)

QBCore.Functions.CreateCallback('qb-tiretheft:server:takeTire', function(source, cb, netId)
    if playerCarrying[source] then
        cb(false, 'You are already carrying a tire.')
        return
    end

    if not netId then
        cb(false, 'Invalid vehicle.')
        return
    end

    local vehicleKey = tostring(netId)
    local count = storedTires[vehicleKey] or 0

    if count <= 0 then
        cb(false, 'There are no tires in this trunk.')
        return
    end

    count = count - 1
    storedTires[vehicleKey] = count > 0 and count or nil
    playerCarrying[source] = true

    TriggerClientEvent('qb-tiretheft:client:updateTrunkTires', -1, netId, count)
    cb(true, count)
end)

QBCore.Functions.CreateCallback('qb-tiretheft:server:sellTire', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(false, 'Player not found.')
        return
    end

    if not playerCarrying[source] then
        cb(false, 'You are not carrying a tire.')
        return
    end

    playerCarrying[source] = nil
    Player.Functions.AddMoney(Config.MoneyAccount, Config.RewardPerTire, 'sold-stolen-tire')
    cb(true, Config.RewardPerTire)
end)

RegisterNetEvent('qb-tiretheft:server:requestSync', function()
    TriggerClientEvent('qb-tiretheft:client:syncTrunkTires', source, storedTires)
end)

AddEventHandler('playerDropped', function()
    local src = source
    playerCarrying[src] = nil

    for key, owner in pairs(wheelReservations) do
        if owner == src then
            wheelReservations[key] = nil
        end
    end
end)
