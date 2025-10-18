ClientUtils = {}

-- Calcul de distance
function ClientUtils.GetDistance(coords1, coords2)
    if type(coords1) == "vector3" and type(coords2) == "vector3" then
        return #(coords1 - coords2)
    end
    return #(vector3(coords1.x, coords1.y, coords1.z) - vector3(coords2.x, coords2.y, coords2.z))
end

-- Notification
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

-- Progress bar
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

-- Animation avec gestion automatique du dictionnaire
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
            print('[INTERIM] Failed to load animation dictionary: ' .. dict)
            return false
        end
    end
    return false
end

-- Stop toutes les animations
function ClientUtils.StopAnimation()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
end

-- Affichage de texte 3D
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

-- Spawn PNJ avec gestion du modèle
function ClientUtils.SpawnNPC(model, coords, heading, scenario, freeze)
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(hash) then
        print('[INTERIM] Failed to load NPC model: ' .. model)
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
        print('[INTERIM] Failed to create NPC entity')
        return nil
    end
end

-- Suppression PNJ
function ClientUtils.DeleteNPC(npc)
    if DoesEntityExist(npc) then
        DeleteEntity(npc)
    end
end

-- Spawn véhicule avec callback
function ClientUtils.SpawnVehicle(model, coords, heading, callback)
    local hash = GetHashKey(model)
    
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 10000 do
        Wait(100)
        timeout = timeout + 100
    end
    
    if not HasModelLoaded(hash) then
        print('[INTERIM] Failed to load vehicle model: ' .. model)
        if callback then callback(nil) end
        return nil
    end
    
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    
    if DoesEntityExist(vehicle) then
        SetVehicleNumberPlateText(vehicle, "INTERIM")
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
        print('[INTERIM] Failed to create vehicle entity')
        if callback then callback(nil) end
        return nil
    end
end

-- Suppression véhicule proprement
function ClientUtils.DeleteVehicle(vehicle)
    if DoesEntityExist(vehicle) then
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
    end
end

-- Spawn trailer pour les camions
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

-- Attacher trailer au camion
function ClientUtils.AttachTrailer(truck, trailer)
    if DoesEntityExist(truck) and DoesEntityExist(trailer) then
        AttachVehicleToTrailer(truck, trailer, 1.0)
        return true
    end
    return false
end

-- Vérification si le joueur a un item
function ClientUtils.HasItem(item, amount)
    local count = exports.ox_inventory:Search('count', item)
    return count >= (amount or 1)
end

-- Obtenir le nombre d'items
function ClientUtils.GetItemCount(item)
    return exports.ox_inventory:Search('count', item) or 0
end

-- Marker avec couleur personnalisable
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

-- Blip creation avec plus d'options
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

-- Suppression blip
function ClientUtils.RemoveBlip(blip)
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
end

-- Créer un blip de route vers des coordonnées
function ClientUtils.SetWaypoint(coords, label)
    SetNewWaypoint(coords.x, coords.y)
    if label then
        ClientUtils.Notify('Direction définie vers ' .. label, 'info', 3000)
    end
end

-- Vérifier si le joueur est dans un véhicule
function ClientUtils.IsInVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

-- Obtenir le véhicule du joueur
function ClientUtils.GetVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return GetVehiclePedIsIn(ped, false)
    end
    return nil
end

-- Obtenir les coordonnées du joueur
function ClientUtils.GetPlayerCoords()
    return GetEntityCoords(PlayerPedId())
end

-- Téléporter le joueur
function ClientUtils.TeleportPlayer(coords, heading)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    if heading then
        SetEntityHeading(ped, heading)
    end
end

-- Forcer le joueur à sortir du véhicule
function ClientUtils.ExitVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
    end
end

-- Format argent
function ClientUtils.FormatMoney(amount)
    return string.format("$%s", lib.math.groupdigits(amount))
end

-- Choix aléatoire dans une table
function ClientUtils.RandomChoice(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

-- Attendre qu'une condition soit vraie avec timeout
function ClientUtils.WaitFor(condition, timeout)
    local timer = 0
    timeout = timeout or 5000
    
    while not condition() and timer < timeout do
        Wait(100)
        timer = timer + 100
    end
    
    return condition()
end

-- Charger un prop et l'attacher au joueur
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

-- Supprimer un prop
function ClientUtils.DeleteProp(prop)
    if DoesEntityExist(prop) then
        DeleteObject(prop)
    end
end

-- Désactiver les contrôles
function ClientUtils.DisableControls(disableMovement, disableCarMovement, disableMouse)
    DisableControlAction(0, 1, disableMouse) -- LookLeftRight
    DisableControlAction(0, 2, disableMouse) -- LookUpDown
    DisableControlAction(0, 24, true) -- Attack
    DisableControlAction(0, 25, true) -- Aim
    DisableControlAction(0, 47, true) -- Weapon
    DisableControlAction(0, 58, true) -- Weapon
    DisableControlAction(0, 263, true) -- Melee Attack 1
    DisableControlAction(0, 264, true) -- Melee Attack 2
    DisableControlAction(0, 257, true) -- Attack 2
    DisableControlAction(0, 140, true) -- Melee Attack Light
    DisableControlAction(0, 141, true) -- Melee Attack Heavy
    DisableControlAction(0, 142, true) -- Melee Attack Alternate
    DisableControlAction(0, 143, true) -- Melee Block
    DisableControlAction(0, 37, disableCarMovement) -- Select Weapon
    DisableControlAction(0, 99, disableCarMovement) -- VehicleSelectNextWeapon
    DisableControlAction(0, 100, disableCarMovement) -- VehicleSelectPrevWeapon
    DisableControlAction(0, 115, disableCarMovement) -- VehicleFlyThrottleUp
    DisableControlAction(0, 116, disableCarMovement) -- VehicleFlyThrottleDown
    DisableControlAction(0, 117, disableCarMovement) -- VehicleFlyYawLeft
    DisableControlAction(0, 118, disableCarMovement) -- VehicleFlyYawRight
    DisableControlAction(0, 30, disableMovement) -- MoveLeftRight
    DisableControlAction(0, 31, disableMovement) -- MoveUpDown
    DisableControlAction(0, 36, disableMovement) -- Duck
    DisableControlAction(0, 21, disableMovement) -- Sprint
end

return ClientUtils