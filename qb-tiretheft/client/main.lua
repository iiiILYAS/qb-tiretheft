local QBCore = exports['qb-core']:GetCoreObject()

local busy = false
local carrying = nil
local buyerPed = nil
local buyerBlip = nil
local buyerInteraction = nil
local trunkCounts = {}
local trunkProps = {}
local theftSceneProps = {}
local theftCam = nil

local function notify(message, messageType)
    QBCore.Functions.Notify(message, messageType or 'primary')
end

local function awaitCallback(name, ...)
    local p = promise.new()
    QBCore.Functions.TriggerCallback(name, function(...)
        p:resolve({ ... })
    end, ...)
    local result = Citizen.Await(p)
    return table.unpack(result)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    return hash
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function deleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

local function getVehicleNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then
        netId = VehToNet(vehicle)
    end

    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
        return netId
    end

    return nil
end

local function isValidVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if Config.BlacklistedVehicleClasses[GetVehicleClass(vehicle)] then return false end
    return true
end

local function getClosestWheel(vehicle)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local closest = nil
    local closestDistance = Config.TargetDistance + 0.5

    for _, boneName in ipairs(Config.WheelBones) do
        local boneIndex = GetEntityBoneIndexByName(vehicle, boneName)
        if boneIndex ~= -1 then
            local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
            local distance = #(pedCoords - boneCoords)

            if distance < closestDistance then
                closestDistance = distance
                closest = {
                    bone = boneName,
                    coords = boneCoords,
                    index = Config.WheelIndexes[boneName]
                }
            end
        end
    end

    return closest
end

local function clearTheftScene()
    for _, prop in ipairs(theftSceneProps) do
        deleteEntity(prop)
    end

    theftSceneProps = {}
end

local function getWheelLocalData(vehicle, wheel)
    local localCoords = GetOffsetFromEntityGivenWorldCoords(vehicle, wheel.coords.x, wheel.coords.y, wheel.coords.z)
    local side = localCoords.x < 0.0 and -1.0 or 1.0
    local lengthSide = localCoords.y < 0.0 and -1.0 or 1.0

    return localCoords, side, lengthSide
end

local function stopTheftCamera(easeTime)
    if not theftCam then return end

    local cam = theftCam
    local duration = easeTime or Config.TheftCamera.easeOut

    RenderScriptCams(false, true, duration, true, true)
    SetCamActive(cam, false)
    DestroyCam(cam, false)
    theftCam = nil
end

local function startTheftCamera(vehicle, wheel)
    local camConfig = Config.TheftCamera
    if not camConfig or not camConfig.enabled then return end

    stopTheftCamera(0)

    local localCoords, side, lengthSide = getWheelLocalData(vehicle, wheel)
    local camLocal = vector3(
        localCoords.x + (side * camConfig.sideDistance),
        localCoords.y + (lengthSide * camConfig.frontBackOffset),
        localCoords.z + camConfig.heightOffset
    )
    local lookLocal = vector3(
        localCoords.x + camConfig.lookAtOffset.x,
        localCoords.y + camConfig.lookAtOffset.y,
        localCoords.z + camConfig.lookAtOffset.z
    )
    local camCoords = GetOffsetFromEntityInWorldCoords(vehicle, camLocal.x, camLocal.y, camLocal.z)
    local lookCoords = GetOffsetFromEntityInWorldCoords(vehicle, lookLocal.x, lookLocal.y, lookLocal.z)

    theftCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        camCoords.x,
        camCoords.y,
        camCoords.z,
        0.0,
        0.0,
        0.0,
        camConfig.fov,
        false,
        2
    )

    PointCamAtCoord(theftCam, lookCoords.x, lookCoords.y, lookCoords.z)
    SetCamActive(theftCam, true)
    RenderScriptCams(true, true, camConfig.easeIn, true, true)
end

local function createSceneObject(modelName, coords, heading)
    local model = loadModel(modelName)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)

    SetEntityHeading(prop, heading)
    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    SetEntityCollision(prop, false, false)
    SetModelAsNoLongerNeeded(model)

    theftSceneProps[#theftSceneProps + 1] = prop
    return prop
end

local function createTheftScene(vehicle, wheel)
    clearTheftScene()

    local scene = Config.TheftScene
    if not scene then return end

    local localCoords, side, lengthSide = getWheelLocalData(vehicle, wheel)
    local heading = GetEntityHeading(vehicle)

    if scene.showJacks then
        local standLocal = vector3(
            localCoords.x - (side * scene.sideDistance),
            localCoords.y,
            localCoords.z + scene.axleStandOffset.z + scene.groundLift
        )
        local jackLocal = vector3(
            localCoords.x - (side * (scene.sideDistance + 0.08)),
            localCoords.y + (lengthSide * scene.jackOffset.y),
            localCoords.z + scene.jackOffset.z + scene.groundLift
        )

        createSceneObject(Config.Models.AxleStand, GetOffsetFromEntityInWorldCoords(vehicle, standLocal.x, standLocal.y, standLocal.z), heading)
        createSceneObject(Config.Models.CarJack, GetOffsetFromEntityInWorldCoords(vehicle, jackLocal.x, jackLocal.y, jackLocal.z), heading)
    end

    if scene.drillAtWheel then
        local model = loadModel(Config.Models.Drill)
        local drillLocal = vector3(
            localCoords.x - (side * 0.08) + scene.drillOffset.x,
            localCoords.y + scene.drillOffset.y,
            localCoords.z + scene.drillOffset.z
        )
        local rotZ = side < 0.0 and 90.0 or -90.0
        local prop = CreateObject(model, wheel.coords.x, wheel.coords.y, wheel.coords.z, false, false, false)

        SetEntityCollision(prop, false, false)
        AttachEntityToEntity(
            prop,
            vehicle,
            0,
            drillLocal.x,
            drillLocal.y,
            drillLocal.z,
            scene.drillRot.x,
            scene.drillRot.y,
            rotZ,
            false,
            false,
            false,
            false,
            2,
            true
        )

        SetModelAsNoLongerNeeded(model)
        theftSceneProps[#theftSceneProps + 1] = prop
    end
end

local function drawWheelMinigame(isGreen, round, wheelCoords)
    if not HasStreamedTextureDictLoaded('shared') then
        RequestStreamedTextureDict('shared', true)
    end

    local hudCoords = wheelCoords + Config.Minigame.hubOffset
    local onScreen, screenX, screenY = World3dToScreen2d(hudCoords.x, hudCoords.y, hudCoords.z)

    if not onScreen then return end

    local green = isGreen and 235 or 85

    DrawSprite('shared', 'emptydot_32', screenX, screenY, 0.040, 0.065, 0.0, 0, 0, 0, 135)
    DrawSprite('shared', 'emptydot_32', screenX, screenY, 0.027, 0.045, 0.0, 245, 245, 245, 245)
    DrawSprite('shared', 'emptydot_32', screenX + 0.006, screenY - 0.004, 0.018, 0.030, 0.0, 69, green, 103, 245)

    SetTextFont(4)
    SetTextScale(0.24, 0.24)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(('%s %s/%s'):format(Config.Minigame.text, round, Config.Minigame.rounds))
    EndTextCommandDisplayText(screenX, screenY + 0.038)
end

local function playMinigame(wheel)
    for round = 1, Config.Minigame.rounds do
        local startTime = GetGameTimer()
        local greenStart = startTime + math.random(450, Config.Minigame.failTime - Config.Minigame.greenWindow - 100)
        local greenEnd = greenStart + Config.Minigame.greenWindow
        local passed = false

        while GetGameTimer() - startTime < Config.Minigame.failTime do
            Wait(0)

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)
            DisableControlAction(0, 34, true)
            DisableControlAction(0, 35, true)

            local now = GetGameTimer()
            local isGreen = now >= greenStart and now <= greenEnd
            drawWheelMinigame(isGreen, round, wheel.coords)

            if IsControlJustPressed(0, 38) then
                passed = isGreen
                break
            end
        end

        if not passed then
            return false
        end

        Wait(250)
    end

    return true
end

local function createDrillProp(ped)
    local drill = Config.Drill
    local model = loadModel(Config.Models.Drill)
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, drill.bone),
        drill.pos.x,
        drill.pos.y,
        drill.pos.z,
        drill.rot.x,
        drill.rot.y,
        drill.rot.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    SetModelAsNoLongerNeeded(model)
    return prop
end

local function startCarryingTire(origin)
    if carrying then return false end

    local ped = PlayerPedId()
    local carry = Config.Carry
    local model = loadModel(Config.Models.Tire)
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    loadAnim(carry.animDict)
    TaskPlayAnim(ped, carry.animDict, carry.anim, 8.0, -8.0, -1, 51, 0.0, false, false, false)

    AttachEntityToEntity(
        prop,
        ped,
        GetPedBoneIndex(ped, carry.bone),
        carry.pos.x,
        carry.pos.y,
        carry.pos.z,
        carry.rot.x,
        carry.rot.y,
        carry.rot.z,
        true,
        true,
        false,
        true,
        1,
        true
    )

    SetModelAsNoLongerNeeded(model)
    carrying = { prop = prop, origin = origin }

    CreateThread(function()
        while carrying do
            Wait(0)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)

            if not IsEntityPlayingAnim(ped, carry.animDict, carry.anim, 3) then
                TaskPlayAnim(ped, carry.animDict, carry.anim, 8.0, -8.0, -1, 51, 0.0, false, false, false)
            end
        end
    end)

    return true
end

local function stopCarryingTire()
    if not carrying then return end

    deleteEntity(carrying.prop)
    carrying = nil
    ClearPedTasks(PlayerPedId())
end

local function clearTrunkProps(netId)
    if not trunkProps[netId] then return end

    for _, prop in ipairs(trunkProps[netId]) do
        deleteEntity(prop)
    end

    trunkProps[netId] = nil
end

local function rebuildTrunkProps(netId, count)
    clearTrunkProps(netId)

    count = tonumber(count) or 0
    if count <= 0 then return end

    local vehicle = NetToVeh(netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    local model = loadModel(Config.Models.Tire)
    local vehicleCoords = GetEntityCoords(vehicle)
    trunkProps[netId] = {}

    for i = 1, math.min(count, #Config.TrunkTireOffsets) do
        local offset = Config.TrunkTireOffsets[i]
        local prop = CreateObject(model, vehicleCoords.x, vehicleCoords.y, vehicleCoords.z, false, false, false)

        SetEntityCollision(prop, false, false)
        AttachEntityToEntity(
            prop,
            vehicle,
            0,
            offset.pos.x,
            offset.pos.y,
            offset.pos.z,
            offset.rot.x,
            offset.rot.y,
            offset.rot.z,
            false,
            false,
            false,
            false,
            2,
            true
        )

        trunkProps[netId][#trunkProps[netId] + 1] = prop
    end

    SetModelAsNoLongerNeeded(model)
end

local function getStoredCount(vehicle)
    local netId = getVehicleNetId(vehicle)
    if not netId then return 0 end
    return trunkCounts[netId] or 0
end

local function doProgress(name, label, duration, animDict, anim)
    local p = promise.new()
    local animData = {}

    if animDict and anim then
        animData = {
            animDict = animDict,
            anim = anim,
            flags = 49
        }
    end

    QBCore.Functions.Progressbar(name, label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true
    }, animData, {}, {}, function()
        p:resolve(true)
    end, function()
        p:resolve(false)
    end)

    return Citizen.Await(p)
end

local function startWheelTheft(vehicle)
    if busy then return end
    if carrying then
        notify('Put the tire in a trunk first.', 'error')
        return
    end

    if not isValidVehicle(vehicle) or IsPedInAnyVehicle(PlayerPedId(), false) then return end

    local wheel = getClosestWheel(vehicle)
    if not wheel or wheel.index == nil then
        notify('Move closer to a wheel.', 'error')
        return
    end

    local netId = getVehicleNetId(vehicle)
    if not netId then
        notify('Could not read vehicle network id.', 'error')
        return
    end

    local allowed, message = awaitCallback('qb-tiretheft:server:startWheel', netId, wheel.index)
    if not allowed then
        notify(message or 'You cannot remove this tire.', 'error')
        return
    end

    busy = true

    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, wheel.coords.x, wheel.coords.y, wheel.coords.z, 750)
    Wait(750)

    loadAnim(Config.Drill.animDict)
    TaskPlayAnim(ped, Config.Drill.animDict, Config.Drill.anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)

    createTheftScene(vehicle, wheel)
    startTheftCamera(vehicle, wheel)
    local drillProp = nil

    if not Config.TheftScene or not Config.TheftScene.drillAtWheel then
        drillProp = createDrillProp(ped)
    end

    local success = playMinigame(wheel)

    StopAnimTask(ped, Config.Drill.animDict, Config.Drill.anim, 1.0)
    deleteEntity(drillProp)
    stopTheftCamera()
    clearTheftScene()

    if success then
        SetVehicleTyreBurst(vehicle, wheel.index, true, 1000.0)
        TriggerServerEvent('qb-tiretheft:server:finishWheel', netId, wheel.index, true)
        startCarryingTire('wheel')
        notify('Tire removed. Put it in a trunk.', 'success')
    else
        TriggerServerEvent('qb-tiretheft:server:finishWheel', netId, wheel.index, false)
        notify('You failed the drilling minigame.', 'error')
    end

    busy = false
end

local function placeTireInTrunk(vehicle)
    if busy then return end
    if not carrying then
        notify('You are not carrying a tire.', 'error')
        return
    end

    if not isValidVehicle(vehicle) then return end

    local netId = getVehicleNetId(vehicle)
    if not netId then
        notify('Could not read vehicle network id.', 'error')
        return
    end

    if (trunkCounts[netId] or 0) >= Config.MaxTiresPerVehicle then
        notify('The trunk is full.', 'error')
        return
    end

    busy = true
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 750)
    SetVehicleDoorOpen(vehicle, 5, false, false)

    local done = doProgress(
        'tiretheft_store',
        'Putting tire in trunk',
        Config.Progress.placeInTrunk,
        Config.Drill.animDict,
        Config.Drill.anim
    )

    if done then
        local ok, messageOrCount = awaitCallback('qb-tiretheft:server:storeTire', netId)
        if ok then
            stopCarryingTire()
            notify(('Tire stored. Trunk: %s/%s'):format(messageOrCount, Config.MaxTiresPerVehicle), 'success')
        else
            notify(messageOrCount or 'Could not store tire.', 'error')
        end
    end

    SetVehicleDoorShut(vehicle, 5, false)
    busy = false
end

local function takeTireFromTrunk(vehicle)
    if busy then return end
    if carrying then
        notify('You are already carrying a tire.', 'error')
        return
    end

    if not isValidVehicle(vehicle) then return end

    local netId = getVehicleNetId(vehicle)
    if not netId then
        notify('Could not read vehicle network id.', 'error')
        return
    end

    if (trunkCounts[netId] or 0) <= 0 then
        notify('There are no tires in this trunk.', 'error')
        return
    end

    busy = true
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 750)
    SetVehicleDoorOpen(vehicle, 5, false, false)

    local done = doProgress(
        'tiretheft_take',
        'Taking tire from trunk',
        Config.Progress.takeFromTrunk,
        Config.Drill.animDict,
        Config.Drill.anim
    )

    if done then
        local ok, message = awaitCallback('qb-tiretheft:server:takeTire', netId)
        if ok then
            startCarryingTire('trunk')
            notify('Take the tire to the buyer.', 'success')
        else
            notify(message or 'Could not take tire.', 'error')
        end
    end

    SetVehicleDoorShut(vehicle, 5, false)
    busy = false
end

local function sellTire()
    if busy then return end
    if not carrying then
        notify('Bring me a tire first.', 'error')
        return
    end

    busy = true

    local done = doProgress(
        'tiretheft_sell',
        'Selling tire',
        Config.Progress.sell,
        'mp_common',
        'givetake1_a'
    )

    if done then
        local ok, messageOrAmount = awaitCallback('qb-tiretheft:server:sellTire')
        if ok then
            stopCarryingTire()
            notify(('Sold tire for $%s.'):format(messageOrAmount), 'success')
        else
            notify(messageOrAmount or 'Could not sell tire.', 'error')
        end
    end

    busy = false
end

local function registerTargets()
    exports['qb-target']:AddTargetBone(Config.WheelBones, {
        options = {
            {
                icon = 'fas fa-circle-dot',
                label = 'Steal Tire',
                item = Config.RequiredItem,
                canInteract = function(entity)
                    return not busy and not carrying and isValidVehicle(entity) and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                action = function(entity)
                    startWheelTheft(entity)
                end
            }
        },
        distance = Config.TargetDistance
    })

    exports['qb-target']:AddTargetBone(Config.TrunkBones, {
        options = {
            {
                icon = 'fas fa-box-open',
                label = 'Place Tire In Trunk',
                canInteract = function(entity)
                    return not busy and carrying and isValidVehicle(entity) and getStoredCount(entity) < Config.MaxTiresPerVehicle
                end,
                action = function(entity)
                    placeTireInTrunk(entity)
                end
            },
            {
                icon = 'fas fa-dolly',
                label = 'Take Tire From Trunk',
                canInteract = function(entity)
                    return not busy and not carrying and isValidVehicle(entity) and getStoredCount(entity) > 0
                end,
                action = function(entity)
                    takeTireFromTrunk(entity)
                end
            }
        },
        distance = Config.TrunkDistance
    })
end

local function createBuyer()
    local buyer = Config.Buyer
    local model = loadModel(Config.Models.Buyer)

    buyerPed = CreatePed(0, model, buyer.coords.x, buyer.coords.y, buyer.coords.z - 1.0, buyer.coords.w, false, true)
    SetEntityInvincible(buyerPed, true)
    SetBlockingOfNonTemporaryEvents(buyerPed, true)
    FreezeEntityPosition(buyerPed, true)

    if buyer.scenario then
        TaskStartScenarioInPlace(buyerPed, buyer.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(model)

    buyerInteraction = exports.interact:AddInteraction({
        coords = vector3(buyer.coords.x, buyer.coords.y, buyer.coords.z),
        distance = buyer.distance,
        interactDst = buyer.interactDst,
        name = 'qb-tiretheft-buyer',
        options = {
            {
                label = ('Sell Tire ($%s)'):format(Config.RewardPerTire),
                canInteract = function()
                    return carrying ~= nil and not busy
                end,
                action = function()
                    sellTire()
                end
            }
        }
    })

    if buyer.blip and buyer.blip.enabled then
        buyerBlip = AddBlipForCoord(buyer.coords.x, buyer.coords.y, buyer.coords.z)
        SetBlipSprite(buyerBlip, buyer.blip.sprite)
        SetBlipColour(buyerBlip, buyer.blip.color)
        SetBlipScale(buyerBlip, buyer.blip.scale)
        SetBlipAsShortRange(buyerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(buyer.blip.label)
        EndTextCommandSetBlipName(buyerBlip)
    end
end

RegisterNetEvent('qb-tiretheft:client:updateTrunkTires', function(netId, count)
    trunkCounts[netId] = count > 0 and count or nil
    rebuildTrunkProps(netId, count)
end)

RegisterNetEvent('qb-tiretheft:client:syncTrunkTires', function(counts)
    trunkCounts = {}

    for netId, count in pairs(counts or {}) do
        netId = tonumber(netId) or netId
        trunkCounts[netId] = count
        rebuildTrunkProps(netId, count)
    end
end)

CreateThread(function()
    Wait(1000)
    registerTargets()
    createBuyer()
    TriggerServerEvent('qb-tiretheft:server:requestSync')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    stopTheftCamera(0)
    clearTheftScene()
    stopCarryingTire()
    deleteEntity(buyerPed)

    if buyerBlip then
        RemoveBlip(buyerBlip)
    end

    for netId in pairs(trunkProps) do
        clearTrunkProps(netId)
    end

    if buyerInteraction then
        pcall(function()
            exports.interact:RemoveInteraction(buyerInteraction)
        end)
    end
end)
