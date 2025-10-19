ClientUtils = {}

function ClientUtils.GetDistance(coords1, coords2)
    if type(coords1) == "vector3" and type(coords2) == "vector3" then
        return #(coords1 - coords2)
    end
    return #(vector3(coords1.x, coords1.y, coords1.z) - vector3(coords2.x, coords2.y, coords2.z))
end

function ClientUtils.Notify(message, type, duration)
    if Config.Notification == 'ox_lib' then
        lib.notify({
            title = 'Intérim',
            description = message,
            type = type or 'info',
            duration = duration or 5000,
            position = 'top'
        })
    elseif Config.Notification == 'esx' then
        ESX.ShowNotification(message)
    elseif Config.Notification == 'qb' then
        QBCore.Functions.Notify(message, type)
    end
end

function ClientUtils.ProgressBar(label, duration, options)
    if Config.ProgressBar == 'ox_lib' then
        local success = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = options and options.disableCar or true,
                move = options and options.disableMove or true,
                combat = true,
                sprint = true,
                mouse = false
            },
            anim = options and options.anim or nil,
            prop = options and options.prop or nil
        })
        return success
    elseif Config.ProgressBar == 'esx' then
        ESX.Progressbar(label, duration)
        return true
    elseif Config.ProgressBar == 'qb' then
        QBCore.Functions.Progressbar(label, label, duration, false, true)
        return true
    end
    return true
end

function ClientUtils.PlayAnimation(dict, anim, duration, flag, task)
    local ped = PlayerPedId()
    
    if dict and anim then
        RequestAnimDict(dict)
        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 5000 do
            Wait(100)
            timeout = timeout + 100
        end
        
        if HasAnimDictLoaded(dict) then
            if task then
                TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration or -1, flag or 1, 0, false, false, false)
            else
                TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag or 1, 0, false, false, false)
            end
            return true
        else
            print('[KT_INTERIM] Failed to load animation dictionary: ' .. dict)
            return false
        end
    end
    return false
end

function ClientUtils.StopAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
end

function ClientUtils.DrawText3D(coords, text, size)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local camCoords = GetGameplayCamCoords()
    local dist = #(camCoords - coords)
    
    local scale = (size or 1) / dist * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(x, y)
    end
end

function ClientUtils.SpawnNPC(model, coords, heading, scenario, freeze)
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(hash) then
        print('[KT_INTERIM] Failed to load NPC model: ' .. model)
        return nil
    end
    
    local npc = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, false, true)
    
    if DoesEntityExist(npc) then
        SetEntityHeading(npc, heading)
        FreezeEntityPosition(npc, freeze ~= false)
        SetEntityInvincible(npc, true)
        SetBlockingOfNonTemporaryEvents(npc, true)
        SetPedDiesWhenInjured(npc, false)
        SetPedCanPlayAmbientAnims(npc, true)
        SetPedCanRagdollFromPlayerImpact(npc, false)
        SetEntityCanBeDamaged(npc, false)
        
        if scenario then
            TaskStartScenarioInPlace(npc, scenario, 0, true)
        end
        
        SetModelAsNoLongerNeeded(hash)
        return npc
    else
        print('[KT_INTERIM] Failed to create NPC entity')
        return nil
    end
end

function ClientUtils.DeleteNPC(npc)
    if DoesEntityExist(npc) then
        DeleteEntity(npc)
    end
end

function ClientUtils.GenerateTempPlate()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    math.randomseed(GetGameTimer())

    local plate = ""
    for i = 1, 8 do
        local rand = math.random(1, #charset)
        plate = plate .. charset:sub(rand, rand)
    end

    return plate
end

function ClientUtils.SpawnVehicle(model, coords, heading, callback)
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(hash) then
        print('[KT_INTERIM] Failed to load vehicle model: ' .. model)
        if callback then callback(nil) end
        return nil
    end
    
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    
    if DoesEntityExist(vehicle) then
        SetVehicleNumberPlateText(vehicle, ClientUtils.GenerateTempPlate())
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleHasBeenOwnedByPlayer(vehicle, true)
        SetVehicleNeedsToBeHotwired(vehicle, false)
        SetVehRadioStation(vehicle, 'OFF')
        SetVehicleFuelLevel(vehicle, 100.0)
        DecorSetFloat(vehicle, "_FUEL_LEVEL", 100.0)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleDirtLevel(vehicle, 0.0)
        
        SetModelAsNoLongerNeeded(hash)
        
        if callback then
            callback(vehicle)
        end
        
        return vehicle
    else
        print('[KT_INTERIM] Failed to create vehicle entity')
        if callback then callback(nil) end
        return nil
    end
end

function ClientUtils.DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

function ClientUtils.SpawnTrailer(model, coords, heading)
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if HasModelLoaded(hash) then
        local trailer = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
        SetModelAsNoLongerNeeded(hash)
        return trailer
    end
    
    return nil
end

function ClientUtils.AttachTrailer(truck, trailer)
    if DoesEntityExist(truck) and DoesEntityExist(trailer) then
        AttachVehicleToTrailer(truck, trailer, 1.0)
        return true
    end
    return false
end

function ClientUtils.HasItem(item, amount)
    local count = exports.ox_inventory:Search('count', item)
    return count >= (amount or 1)
end

function ClientUtils.GetItemCount(item)
    return exports.ox_inventory:Search('count', item) or 0
end

function ClientUtils.DrawMarker(coords, markerType, color, scale)
    markerType = markerType or 1
    color = color or {r = 255, g = 255, b = 255, a = 100}
    scale = scale or {x = 1.5, y = 1.5, z = 1.0}
    
    DrawMarker(
        markerType,
        coords.x, coords.y, coords.z - 1.0,
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        scale.x, scale.y, scale.z,
        color.r, color.g, color.b, color.a or 100,
        false, true, 2, false, nil, nil, false
    )
end

function ClientUtils.CreateBlip(coords, sprite, color, scale, label, shortRange)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, scale or 0.8)
    SetBlipColour(blip, color or 1)
    SetBlipAsShortRange(blip, shortRange ~= false)
    
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label or "Point d'intérêt")
    EndTextCommandSetBlipName(blip)
    
    return blip
end

function ClientUtils.RemoveBlip(blip)
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

function ClientUtils.SetWaypoint(coords, label)
    SetNewWaypoint(coords.x, coords.y)
    if label then
        ClientUtils.Notify('Direction définie vers ' .. label, 'info', 3000)
    end
end

function ClientUtils.IsInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

function ClientUtils.GetVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

function ClientUtils.GetPlayerCoords()
    return GetEntityCoords(PlayerPedId())
end

function ClientUtils.TeleportPlayer(coords, heading)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    if heading then
        SetEntityHeading(ped, heading)
    end
end

function ClientUtils.ExitVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    end
end

function ClientUtils.FormatMoney(amount)
    return string.format("$%s", lib.math.groupdigits(amount))
end

function ClientUtils.RandomChoice(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

function ClientUtils.WaitFor(condition, timeout)
    local timer = 0
    timeout = timeout or 5000
    
    while not condition() and timer < timeout do
        Wait(100)
        timer = timer + 100
    end
    
    return condition()
end

function ClientUtils.AttachProp(prop, bone, offset, rotation)
    local ped = PlayerPedId()
    local boneIndex = GetPedBoneIndex(ped, bone or 28422)
    
    RequestModel(GetHashKey(prop))
    while not HasModelLoaded(GetHashKey(prop)) do
        Wait(10)
    end
    
    local object = CreateObject(GetHashKey(prop), 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        object, ped, boneIndex,
        offset.x or 0.0, offset.y or 0.0, offset.z or 0.0,
        rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0,
        true, true, false, true, 1, true
    )
    
    return object
end

function ClientUtils.DeleteProp(prop)
    if DoesEntityExist(prop) then
        DeleteObject(prop)
    end
end

function ClientUtils.DisableControls(disableMovement, disableCarMovement, disableMouse)
    local mouseControls = {1, 2}
    for i = 1, #mouseControls do
        DisableControlAction(0, mouseControls[i], disableMouse)
    end

    local combatControls = {24, 25, 47, 58, 263, 264, 257, 140, 141, 142, 143}
    for i = 1, #combatControls do
        DisableControlAction(0, combatControls[i], true)
    end

    local carControls = {37, 99, 100, 115, 116, 117, 118}
    for i = 1, #carControls do
        DisableControlAction(0, carControls[i], disableCarMovement)
    end

    local movementControls = {30, 31, 36, 21}
    for i = 1, #movementControls do
        DisableControlAction(0, movementControls[i], disableMovement)
    end
end


return ClientUtils
