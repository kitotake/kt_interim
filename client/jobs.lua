local jobVehicle = nil
local jobTrailer = nil
local jobBlip = nil
local jobNPC = nil
local jobProp = nil
local collectedItems = 0
local deliveryPoint = nil
local pickupPoint = nil

RegisterNetEvent('kt_interim:startJob', function(jobName, jobConfig)
    if jobName == 'construction' then
        StartConstructionJob(jobConfig)
    elseif jobName == 'cleaning' then
        StartCleaningJob(jobConfig)
    elseif jobName == 'delivery' then
        StartDeliveryJob(jobConfig)
    elseif jobName == 'shop_logistics' then
        StartShopLogisticsJob(jobConfig)
    elseif jobName == 'taxi' then
        StartTaxiJob(jobConfig)
    elseif jobName == 'trucker' then
        StartTruckerJob(jobConfig)
    end
end)

RegisterNetEvent('kt_interim:cancelJob', function()
    CleanupJobResources()
end)

function StartConstructionJob(config)
    collectedItems = 0
    
    jobBlip = ClientUtils.CreateBlip(
        config.collectPoint.coords,
        1,
        47,
        0.8,
        'Point de collecte - Briques'
    )
    
    ClientUtils.Notify('Allez collecter des briques au point marqué', 'info')
    
    CreateThread(function()
        print('Starting Construction Job Thread')
        print('Collect Point Coords: ' .. tostring(config.collectPoint.coords))
        print('Item Amount: ' .. tostring(config.item.amount))
       print('IsJobActive: ' .. tostring(IsJobActive()))
          
        while IsJobActive and collectedItems < config.item.amount do
           
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Collecter des briques')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        CollectConstructionItem(config)
                    end
                end
            end
            
            Wait(0)
        end
        
        if collectedItems >= config.item.amount then
            StartConstructionDeposit(config)
        end
    end)
end

function CollectConstructionItem(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Collecte de briques...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        collectedItems = collectedItems + 1
        ClientUtils.Notify('Briques collectées: ' .. collectedItems .. '/' .. config.item.amount, 'success')
        
        TriggerServerEvent('kt_interim:addItem', config.item.name, 1)
    end
end

function StartConstructionDeposit(config)
    ClientUtils.RemoveBlip(jobBlip)
    
    jobBlip = ClientUtils.CreateBlip(
        config.depositPoint.coords,
        1,
        2,
        0.8,
        'Point de dépôt - Briques'
    )
    
    ClientUtils.Notify('Allez déposer les briques au point marqué', 'info')
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Déposer les briques')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        DepositConstructionItems(config)
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function DepositConstructionItems(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des briques...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'construction', config.item.name, collectedItems, config.rewards.amount)
        CleanupJobResources()
    end
end

function StartCleaningJob(config)
    collectedItems = 0
    local currentPointIndex = 1
    
    local function SetupNextCollectPoint()
        if currentPointIndex > #config.collectPoints then
            StartCleaningDeposit(config)
            return
        end
        
        local point = config.collectPoints[currentPointIndex]
        
        ClientUtils.RemoveBlip(jobBlip)
        jobBlip = ClientUtils.CreateBlip(
            point.coords,
            1,
            2,
            0.8,
            'Poubelle ' .. currentPointIndex
        )
        
        ClientUtils.Notify('Allez collecter la poubelle #' .. currentPointIndex, 'info')
        
        CreateThread(function()
            while IsJobActive and collectedItems < config.item.amount do
                local playerCoords = ClientUtils.GetPlayerCoords()
                local distance = #(playerCoords - point.coords)
                
                if distance < 20.0 then
                    ClientUtils.DrawMarker(point.coords, 1, {r = 255, g = 165, b = 0})
                    
                    if distance < 2.0 then
                        ClientUtils.DrawText3D(point.coords, '[E] Collecter la poubelle')
                        
                        if IsControlJustPressed(0, 38) then -- E
                            CollectCleaningItem(config, point)
                            currentPointIndex = currentPointIndex + 1
                            SetupNextCollectPoint()
                            break
                        end
                    end
                end
                
                Wait(0)
            end
        end)
    end
    
    SetupNextCollectPoint()
end

function CollectCleaningItem(config, point)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Collecte de la poubelle...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        collectedItems = collectedItems + 1
        ClientUtils.Notify('Poubelles collectées: ' .. collectedItems .. '/' .. config.item.amount, 'success')
        TriggerServerEvent('kt_interim:addItem', config.item.name, 1)
    end
end

function StartCleaningDeposit(config)
    ClientUtils.RemoveBlip(jobBlip)
    
    jobBlip = ClientUtils.CreateBlip(
        config.depositPoint.coords,
        1,
        2,
        0.8,
        'Déchetterie'
    )
    
    ClientUtils.Notify('Allez déposer les poubelles à la déchetterie', 'info')
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Jeter les poubelles')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        DepositCleaningItems(config)
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function DepositCleaningItems(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des poubelles...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'cleaning', config.item.name, collectedItems, config.rewards.amount)
        CleanupJobResources()
    end
end

function StartDeliveryJob(config)
    jobBlip = ClientUtils.CreateBlip(
        config.collectPoint.coords,
        1,
        47,
        0.8,
        'Point de collecte - Colis'
    )
    
    ClientUtils.Notify('Allez collecter un colis au point marqué', 'info')
    
    CreateThread(function()
        while IsJobActive and collectedItems == 0 do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Prendre un colis')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        CollectDeliveryPackage(config)
                    end
                end
            end
            
            Wait(0)
        end
        
        if collectedItems > 0 then
            StartDeliveryRoute(config)
        end
    end)
end

function CollectDeliveryPackage(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement du colis...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        collectedItems = 1
        TriggerServerEvent('kt_interim:addItem', config.item.name, 1)
        ClientUtils.Notify('Colis récupéré !', 'success')
    end
end

function StartDeliveryRoute(config)
    deliveryPoint = ClientUtils.RandomChoice(config.deliveryPoints)
    
    ClientUtils.RemoveBlip(jobBlip)
    jobBlip = ClientUtils.CreateBlip(
        deliveryPoint.coords,
        1,
        2,
        0.8,
        'Point de livraison'
    )
    
    ClientUtils.SetWaypoint(deliveryPoint.coords, 'Point de livraison')
    ClientUtils.Notify('Livrez le colis au point marqué', 'info')
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0})
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(deliveryPoint.coords, '[E] Livrer le colis')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        DeliverPackage(config)
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function DeliverPackage(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Livraison du colis...', config.animation.delivery.duration, {
        anim = {dict = config.animation.delivery.dict, clip = config.animation.delivery.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'delivery', config.item.name, 1, config.rewards.amount)
        CleanupJobResources()
    end
end


function StartShopLogisticsJob(config)
    collectedItems = 0
    
    jobBlip = ClientUtils.CreateBlip(
        config.collectPoint.coords,
        1,
        47,
        0.8,
        'Point de collecte - Cartons'
    )
    
    ClientUtils.Notify('Allez collecter des cartons au point marqué', 'info')
    
    CreateThread(function()
        while IsJobActive and collectedItems < config.item.amount do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Prendre un carton')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        CollectShopBox(config)
                    end
                end
            end
            
            Wait(0)
        end
        
        if collectedItems >= config.item.amount then
            StartShopDeposit(config)
        end
    end)
end

function CollectShopBox(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement du carton...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        collectedItems = collectedItems + 1
        ClientUtils.Notify('Cartons collectés: ' .. collectedItems .. '/' .. config.item.amount, 'success')
        TriggerServerEvent('kt_interim:addItem', config.item.name, 1)
    end
end

function StartShopDeposit(config)
    ClientUtils.RemoveBlip(jobBlip)
    
    jobBlip = ClientUtils.CreateBlip(
        config.depositPoint.coords,
        1,
        2,
        0.8,
        'Point de dépôt - Cartons'
    )
    
    ClientUtils.Notify('Allez déposer les cartons au point marqué', 'info')
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 2.0 then
                    ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Déposer les cartons')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        DepositShopBoxes(config)
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function DepositShopBoxes(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des cartons...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'shop_logistics', config.item.name, collectedItems, config.rewards.amount)
        CleanupJobResources()
    end
end


function StartTaxiJob(config)
    ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(vehicle)
        if vehicle then
            jobVehicle = vehicle
            TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
            
            pickupPoint = ClientUtils.RandomChoice(config.pickupPoints)
            
            jobBlip = ClientUtils.CreateBlip(
                pickupPoint.coords,
                1,
                5,
                0.8,
                'Client - ' .. pickupPoint.label
            )
            
            ClientUtils.SetWaypoint(pickupPoint.coords, pickupPoint.label)
            ClientUtils.Notify('Allez chercher le client à ' .. pickupPoint.label, 'info')
            
            StartTaxiPickup(config)
        else
            ClientUtils.Notify('Erreur lors du spawn du véhicule', 'error')
            CleanupJobResources()
        end
    end)
end

function StartTaxiPickup(config)
    CreateThread(function()
        while IsJobActive and not jobNPC do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - pickupPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(pickupPoint.coords, 1, {r = 255, g = 255, b = 0})
                
                if distance < 5.0 and ClientUtils.IsInVehicle() then
                    local passengerModel = ClientUtils.RandomChoice(config.npcPassenger.models)
                    jobNPC = ClientUtils.SpawnNPC(passengerModel, pickupPoint.coords, 0.0, nil, true)
                    
                    if jobNPC then
                        TaskEnterVehicle(jobNPC, jobVehicle, 10000, 1, 1.0, 1, 0)
                        Wait(3000)
                        
                        deliveryPoint = ClientUtils.RandomChoice(config.destinationPoints)
                        
                        ClientUtils.RemoveBlip(jobBlip)
                        jobBlip = ClientUtils.CreateBlip(
                            deliveryPoint.coords,
                            1,
                            2,
                            0.8,
                            'Destination - ' .. deliveryPoint.label
                        )
                        
                        ClientUtils.SetWaypoint(deliveryPoint.coords, deliveryPoint.label)
                        ClientUtils.Notify('Amenez le client à ' .. deliveryPoint.label, 'info')
                        
                        StartTaxiDelivery(config)
                        break
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function StartTaxiDelivery(config)
    local startCoords = ClientUtils.GetPlayerCoords()
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0})
                
                if distance < 5.0 and ClientUtils.IsInVehicle() then
                    local travelDistance = #(startCoords - deliveryPoint.coords)
                    local reward = config.rewards.baseAmount + math.floor(travelDistance * config.rewards.perMeterRate)
                    
                    TaskLeaveVehicle(jobNPC, jobVehicle, 0)
                    Wait(2000)
                    
                    ClientUtils.Notify('Course terminée ! Distance: ' .. math.floor(travelDistance) .. 'm', 'success')
                    
                    TriggerServerEvent('kt_interim:completeJob', 'taxi', reward)
                    CleanupJobResources()
                    break
                end
            end
            
            Wait(0)
        end
    end)
end

function StartTruckerJob(config)
    ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(truck)
        if truck then
            jobVehicle = truck
            
            if config.vehicleSpawn.trailer then
                local trailerCoords = config.vehicleSpawn.coords - vector3(10.0, 0.0, 0.0)
                jobTrailer = ClientUtils.SpawnTrailer(config.vehicleSpawn.trailer, trailerCoords, config.vehicleSpawn.coords.w)
                
                if jobTrailer then
                    Wait(500)
                    ClientUtils.AttachTrailer(truck, jobTrailer)
                end
            end
            
            TaskWarpPedIntoVehicle(PlayerPedId(), truck, -1)
            
            jobBlip = ClientUtils.CreateBlip(
                config.collectPoint.coords,
                1,
                47,
                0.8,
                'Point de chargement'
            )
            
            ClientUtils.SetWaypoint(config.collectPoint.coords, 'Point de chargement')
            ClientUtils.Notify('Allez charger les marchandises au point marqué', 'info')
            
            StartTruckerCollect(config)
        else
            ClientUtils.Notify('Erreur lors du spawn du camion', 'error')
            CleanupJobResources()
        end
    end)
end

function StartTruckerCollect(config)
    collectedItems = 0
    
    CreateThread(function()
        while IsJobActive and collectedItems < config.item.amount do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 5.0 then
                    ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Charger les caisses')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        CollectTruckerCrate(config)
                    end
                end
            end
            
            Wait(0)
        end
        
        if collectedItems >= config.item.amount then
            StartTruckerDelivery(config)
        end
    end)
end

function CollectTruckerCrate(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement des caisses...', 3000, {
        anim = {dict = 'anim@heists@box_carry@', clip = 'idle'}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        collectedItems = collectedItems + 1
        ClientUtils.Notify('Caisses chargées: ' .. collectedItems .. '/' .. config.item.amount, 'success')
        TriggerServerEvent('kt_interim:addItem', config.item.name, 1)
    end
end

function StartTruckerDelivery(config)
    deliveryPoint = ClientUtils.RandomChoice(config.depositPoints)
    
    ClientUtils.RemoveBlip(jobBlip)
    jobBlip = ClientUtils.CreateBlip(
        deliveryPoint.coords,
        1,
        2,
        0.8,
        'Point de livraison - ' .. deliveryPoint.label
    )
    
    ClientUtils.SetWaypoint(deliveryPoint.coords, deliveryPoint.label)
    ClientUtils.Notify('Livrez les marchandises à ' .. deliveryPoint.label, 'info')
    
    CreateThread(function()
        while IsJobActive do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 30.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0}, {x = 3.0, y = 3.0, z = 1.0})
                
                if distance < 10.0 then
                    ClientUtils.DrawText3D(deliveryPoint.coords, '[E] Décharger les caisses')
                    
                    if IsControlJustPressed(0, 38) then -- E
                        DeliverTruckerCrates(config)
                    end
                end
            end
            
            Wait(0)
        end
    end)
end

function DeliverTruckerCrates(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Déchargement des caisses...', 5000, {
        anim = {dict = 'anim@heists@box_carry@', clip = 'idle'}
    })
    
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'trucker', config.item.name, collectedItems, config.rewards.amount)
        CleanupJobResources()
    end
end

function CleanupJobResources()
    if jobBlip then
        ClientUtils.RemoveBlip(jobBlip)
        jobBlip = nil
    end
    
    if jobVehicle then
        ClientUtils.DeleteVehicle(jobVehicle)
        jobVehicle = nil
    end
    
    if jobTrailer then
        ClientUtils.DeleteVehicle(jobTrailer)
        jobTrailer = nil
    end
    
    if jobNPC then
        ClientUtils.DeleteNPC(jobNPC)
        jobNPC = nil
    end
    
    if jobProp then
        ClientUtils.DeleteProp(jobProp)
        jobProp = nil
    end
    
    collectedItems = 0
    deliveryPoint = nil
    pickupPoint = nil
end

