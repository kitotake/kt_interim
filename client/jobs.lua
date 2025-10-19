local jobVehicle = nil
local jobTrailer = nil
local jobBlip = nil
local jobNPC = nil
local jobProp = nil
local collectedItems = 0
local deliveryPoint = nil
local pickupPoint = nil
local activeThreads = {}
local vehicleReturnZone = nil

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

local function IsJobActive()
    return exports['kt_interim']:IsJobActive()
end

local function CancelJob()
    TriggerServerEvent('kt_interim:cancelJob')
end

local function StopActiveThreads()
    for _, thread in pairs(activeThreads) do
        if thread then
            -- Les threads se termineront naturellement avec IsJobActive() = false
        end
    end
    activeThreads = {}
end

local function IsInJobVehicle()
    if not jobVehicle or not DoesEntityExist(jobVehicle) then
        return false
    end
    local playerPed = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(playerPed, false)
    return vehicle == jobVehicle
end

local function StartVehicleReturn(spawnCoords, jobName)
    ClientUtils.RemoveBlip(jobBlip)
    
    jobBlip = ClientUtils.CreateBlip(
        spawnCoords,
        1,
        50,
        0.8,
        'Retour véhicule - ' .. jobName
    )
    
    ClientUtils.SetWaypoint(spawnCoords, 'Zone de retour véhicule')
    ClientUtils.Notify('Ramenez le véhicule à la zone de départ', 'warning')
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() and jobVehicle and DoesEntityExist(jobVehicle) do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - spawnCoords)
            
            if distance < 30.0 then
                ClientUtils.DrawMarker(spawnCoords, 1, {r = 0, g = 255, b = 255, a = 100}, {x = 5.0, y = 5.0, z = 1.0})
                
                if distance < 5.0 and IsInJobVehicle() then
                    ClientUtils.DrawText3D(spawnCoords, '[E] Rendre le véhicule')
                    
                    if IsControlJustPressed(0, 38) then
                        ReturnVehicle()
                        return
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function ReturnVehicle()
    if not jobVehicle or not DoesEntityExist(jobVehicle) then
        return
    end
    
    ClientUtils.Notify('Véhicule rendu ! Il sera récupéré dans 1 minute...', 'success')
    
    local playerPed = PlayerPedId()
    TaskLeaveVehicle(playerPed, jobVehicle, 0)
    Wait(2000)
    
    SetEntityAlpha(jobVehicle, 255, false)
    if jobTrailer and DoesEntityExist(jobTrailer) then
        SetEntityAlpha(jobTrailer, 255, false)
    end
    
    CreateThread(function()
        local startTime = GetGameTimer()
        local duration = 60000
        
        while GetGameTimer() - startTime < duration do
            local elapsed = GetGameTimer() - startTime
            local alpha = math.floor(255 - (255 * (elapsed / duration)))
            
            if jobVehicle and DoesEntityExist(jobVehicle) then
                SetEntityAlpha(jobVehicle, alpha, false)
            end
            
            if jobTrailer and DoesEntityExist(jobTrailer) then
                SetEntityAlpha(jobTrailer, alpha, false)
            end
            
            Wait(1000)
        end
        
        if jobVehicle and DoesEntityExist(jobVehicle) then
            ClientUtils.DeleteVehicle(jobVehicle)
            jobVehicle = nil
        end
        
        if jobTrailer and DoesEntityExist(jobTrailer) then
            ClientUtils.DeleteVehicle(jobTrailer)
            jobTrailer = nil
        end
        
        ClientUtils.Notify('Le véhicule a été récupéré', 'info')
        CleanupJobResources()
    end)
end

-- ========================================
-- JOB: CONSTRUCTION
-- ========================================

function StartConstructionJob(config)
    collectedItems = 0
    vehicleReturnZone = config.vehicleSpawn and config.vehicleSpawn.coords or nil
    
    if config.vehicleSpawn then
        ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(vehicle)
            if vehicle then
                jobVehicle = vehicle
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                jobBlip = ClientUtils.CreateBlip(
                    config.collectPoint.coords,
                    1,
                    47,
                    0.8,
                    'Point de collecte - Briques'
                )
                
                ClientUtils.Notify('Allez collecter des briques au point marqué avec le véhicule', 'info')
                StartConstructionCollect(config)
            else
                ClientUtils.Notify('Erreur lors du spawn du véhicule', 'error')
                CleanupJobResources()
            end
        end)
    else
        jobBlip = ClientUtils.CreateBlip(
            config.collectPoint.coords,
            1,
            47,
            0.8,
            'Point de collecte - Briques'
        )
        
        ClientUtils.Notify('Allez collecter des briques au point marqué', 'info')
        StartConstructionCollect(config)
    end
end

function StartConstructionCollect(config)
    local threadId = CreateThread(function()
        while IsJobActive() and collectedItems < config.item.amount do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 5.0 then
                    if not IsInJobVehicle() and config.vehicleSpawn then
                        ClientUtils.DrawText3D(config.collectPoint.coords, '⚠️ Vous devez quitter votre le véhicule !')
                    else
                        ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Collecter des briques')
                        
                        if IsControlJustPressed(0, 38) then
                            CollectConstructionItem(config)
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        if IsJobActive() and collectedItems >= config.item.amount then
            StartConstructionDeposit(config)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function CollectConstructionItem(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Collecte de briques...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
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
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 5.0 then
                    if not IsInJobVehicle() and config.vehicleSpawn then
                        ClientUtils.DrawText3D(config.depositPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Déposer les briques')
                        
                        if IsControlJustPressed(0, 38) then
                            DepositConstructionItems(config)
                            return
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function DepositConstructionItems(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des briques...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'construction', config.item.name, collectedItems, config.rewards.amount)
        
        collectedItems = 0
        
        local alert = lib.alertDialog({
            header = 'Continuer le travail ?',
            content = 'Voulez-vous collecter plus de briques ?\n\n✅ Oui - Retourner au point de collecte\n❌ Non - Terminer et rendre le véhicule',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Oui, continuer',
                cancel = 'Non, terminer'
            }
        })
        
        if alert == 'confirm' then
            ClientUtils.RemoveBlip(jobBlip)
            jobBlip = ClientUtils.CreateBlip(
                config.collectPoint.coords,
                1,
                47,
                0.8,
                'Point de collecte - Briques'
            )
            ClientUtils.Notify('Retournez au point de collecte', 'info')
            StartConstructionCollect(config)
        else
            if config.vehicleSpawn then
                StartVehicleReturn(vehicleReturnZone, 'Construction')
            else
                CleanupJobResources()
            end
        end
    end
end

-- ========================================
-- JOB: CLEANING
-- ========================================

function StartCleaningJob(config)
    collectedItems = 0
    vehicleReturnZone = config.vehicleSpawn and config.vehicleSpawn.coords or nil
    
    if config.vehicleSpawn then
        ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(vehicle)
            if vehicle then
                jobVehicle = vehicle
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                ClientUtils.Notify('Utilisez le véhicule pour collecter les poubelles', 'info')
                StartCleaningCollectSequence(config)
            else
                ClientUtils.Notify('Erreur lors du spawn du véhicule', 'error')
                CleanupJobResources()
            end
        end)
    else
        StartCleaningCollectSequence(config)
    end
end

function StartCleaningCollectSequence(config)
    local currentPointIndex = 1
    
    local function SetupNextCollectPoint()
        if not IsJobActive() then
            return
        end
        
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
        
        StopActiveThreads()
        
        local threadId = CreateThread(function()
            while IsJobActive() and collectedItems < config.item.amount do
                local playerCoords = ClientUtils.GetPlayerCoords()
                local distance = #(playerCoords - point.coords)
                
                if distance < 20.0 then
                    ClientUtils.DrawMarker(point.coords, 1, {r = 255, g = 165, b = 0})
                    
                    if distance < 5.0 then
                        if config.vehicleSpawn and not IsInJobVehicle() then
                            ClientUtils.DrawText3D(point.coords, '⚠️ Vous devez être dans le véhicule de job !')
                        else
                            ClientUtils.DrawText3D(point.coords, '[E] Collecter la poubelle')
                            
                            if IsControlJustPressed(0, 38) then
                                CollectCleaningItem(config, point)
                                currentPointIndex = currentPointIndex + 1
                                SetupNextCollectPoint()
                                return
                            end
                        end
                    end
                end
                
                Wait(0)
            end
        end)
        
        table.insert(activeThreads, threadId)
    end
    
    SetupNextCollectPoint()
end

function CollectCleaningItem(config, point)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Collecte de la poubelle...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
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
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 5.0 then
                    if config.vehicleSpawn and not IsInJobVehicle() then
                        ClientUtils.DrawText3D(config.depositPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Jeter les poubelles')
                        
                        if IsControlJustPressed(0, 38) then
                            DepositCleaningItems(config)
                            return
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function DepositCleaningItems(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des poubelles...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'cleaning', config.item.name, collectedItems, config.rewards.amount)
        
        collectedItems = 0
        
        local alert = lib.alertDialog({
            header = 'Continuer le travail ?',
            content = 'Voulez-vous collecter plus de poubelles ?\n\n✅ Oui - Recommencer la collecte\n❌ Non - Terminer et rendre le véhicule',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Oui, continuer',
                cancel = 'Non, terminer'
            }
        })
        
        if alert == 'confirm' then
            StartCleaningJob(config)
        else
            if config.vehicleSpawn then
                StartVehicleReturn(vehicleReturnZone, 'Nettoyage')
            else
                CleanupJobResources()
            end
        end
    end
end

-- ========================================
-- JOB: DELIVERY
-- ========================================

function StartDeliveryJob(config)
    collectedItems = 0
    vehicleReturnZone = config.vehicleSpawn and config.vehicleSpawn.coords or nil
    
    if config.vehicleSpawn then
        ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(vehicle)
            if vehicle then
                jobVehicle = vehicle
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                jobBlip = ClientUtils.CreateBlip(
                    config.collectPoint.coords,
                    1,
                    47,
                    0.8,
                    'Point de collecte - Colis'
                )
                
                ClientUtils.Notify('Allez collecter un colis au point marqué', 'info')
                StartDeliveryCollect(config)
            else
                ClientUtils.Notify('Erreur lors du spawn du véhicule', 'error')
                CleanupJobResources()
            end
        end)
    else
        jobBlip = ClientUtils.CreateBlip(
            config.collectPoint.coords,
            1,
            47,
            0.8,
            'Point de collecte - Colis'
        )
        
        ClientUtils.Notify('Allez collecter un colis au point marqué', 'info')
        StartDeliveryCollect(config)
    end
end

function StartDeliveryCollect(config)
    local threadId = CreateThread(function()
        while IsJobActive() and collectedItems == 0 do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 5.0 then
                    if config.vehicleSpawn and not IsInJobVehicle() then
                        ClientUtils.DrawText3D(config.collectPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Prendre un colis')
                        
                        if IsControlJustPressed(0, 38) then
                            CollectDeliveryPackage(config)
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        if IsJobActive() and collectedItems > 0 then
            StartDeliveryRoute(config)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function CollectDeliveryPackage(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement du colis...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
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
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0})
                
                if distance < 5.0 then
                    if config.vehicleSpawn and not IsInJobVehicle() then
                        ClientUtils.DrawText3D(deliveryPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(deliveryPoint.coords, '[E] Livrer le colis')
                        
                        if IsControlJustPressed(0, 38) then
                            DeliverPackage(config)
                            return
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function DeliverPackage(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Livraison du colis...', config.animation.delivery.duration, {
        anim = {dict = config.animation.delivery.dict, clip = config.animation.delivery.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'delivery', config.item.name, 1, config.rewards.amount)
        
        collectedItems = 0
        
        local alert = lib.alertDialog({
            header = 'Continuer le travail ?',
            content = 'Voulez-vous livrer un autre colis ?\n\n✅ Oui - Retourner au dépôt\n❌ Non - Terminer et rendre le véhicule',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Oui, continuer',
                cancel = 'Non, terminer'
            }
        })
        
        if alert == 'confirm' then
            ClientUtils.RemoveBlip(jobBlip)
            jobBlip = ClientUtils.CreateBlip(
                config.collectPoint.coords,
                1,
                47,
                0.8,
                'Point de collecte - Colis'
            )
            ClientUtils.Notify('Retournez au dépôt', 'info')
            StartDeliveryCollect(config)
        else
            if config.vehicleSpawn then
                StartVehicleReturn(vehicleReturnZone, 'Livraison')
            else
                CleanupJobResources()
            end
        end
    end
end

-- ========================================
-- JOB: SHOP LOGISTICS
-- ========================================

function StartShopLogisticsJob(config)
    collectedItems = 0
    vehicleReturnZone = config.vehicleSpawn and config.vehicleSpawn.coords or nil
    
    if config.vehicleSpawn then
        ClientUtils.SpawnVehicle(config.vehicleSpawn.model, config.vehicleSpawn.coords, config.vehicleSpawn.coords.w, function(vehicle)
            if vehicle then
                jobVehicle = vehicle
                TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
                
                jobBlip = ClientUtils.CreateBlip(
                    config.collectPoint.coords,
                    1,
                    47,
                    0.8,
                    'Point de collecte - Cartons'
                )
                
                ClientUtils.Notify('Allez collecter des cartons au point marqué', 'info')
                StartShopCollect(config)
            else
                ClientUtils.Notify('Erreur lors du spawn du véhicule', 'error')
                CleanupJobResources()
            end
        end)
    else
        jobBlip = ClientUtils.CreateBlip(
            config.collectPoint.coords,
            1,
            47,
            0.8,
            'Point de collecte - Cartons'
        )
        
        ClientUtils.Notify('Allez collecter des cartons au point marqué', 'info')
        StartShopCollect(config)
    end
end

function StartShopCollect(config)
    local threadId = CreateThread(function()
        while IsJobActive() and collectedItems < config.item.amount do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 5.0 then
                    if config.vehicleSpawn and not IsInJobVehicle() then
                        ClientUtils.DrawText3D(config.collectPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Prendre un carton')
                        
                        if IsControlJustPressed(0, 38) then
                            CollectShopBox(config)
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        if IsJobActive() and collectedItems >= config.item.amount then
            StartShopDeposit(config)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function CollectShopBox(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement du carton...', config.animation.collect.duration, {
        anim = {dict = config.animation.collect.dict, clip = config.animation.collect.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
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
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.depositPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.depositPoint.coords, config.depositPoint.markerType, config.depositPoint.markerColor)
                
                if distance < 5.0 then
                    if config.vehicleSpawn and not IsInJobVehicle() then
                        ClientUtils.DrawText3D(config.depositPoint.coords, '⚠️ Vous devez être dans le véhicule de job !')
                    else
                        ClientUtils.DrawText3D(config.depositPoint.coords, '[E] Déposer les cartons')
                        
                        if IsControlJustPressed(0, 38) then
                            DepositShopBoxes(config)
                            return
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function DepositShopBoxes(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Dépôt des cartons...', config.animation.deposit.duration, {
        anim = {dict = config.animation.deposit.dict, clip = config.animation.deposit.anim}
    })
    
    ClientUtils.DisableControls(false, false, false)
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'shop_logistics', config.item.name, collectedItems, config.rewards.amount)
        
        collectedItems = 0
        
        local alert = lib.alertDialog({
            header = 'Continuer le travail ?',
            content = 'Voulez-vous transporter plus de cartons ?\n\n✅ Oui - Retourner au point de collecte\n❌ Non - Terminer et rendre le véhicule',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Oui, continuer',
                cancel = 'Non, terminer'
            }
        })
        
        if alert == 'confirm' then
            ClientUtils.RemoveBlip(jobBlip)
            jobBlip = ClientUtils.CreateBlip(
                config.collectPoint.coords,
                1,
                47,
                0.8,
                'Point de collecte - Cartons'
            )
            ClientUtils.Notify('Retournez au point de collecte', 'info')
            StartShopCollect(config)
        else
            if config.vehicleSpawn then
                StartVehicleReturn(vehicleReturnZone, 'Logistique')
            else
                CleanupJobResources()
            end
        end
    end
end

-- ========================================
-- JOB: TAXI
-- ========================================

function StartTaxiJob(config)
    vehicleReturnZone = config.vehicleSpawn.coords
    
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
    local threadId = CreateThread(function()
        while IsJobActive() and not jobNPC do
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
                        return
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function StartTaxiDelivery(config)
    local startCoords = ClientUtils.GetPlayerCoords()
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0})
                
                if distance < 5.0 and ClientUtils.IsInVehicle() then
                    local travelDistance = #(startCoords - deliveryPoint.coords)
                    local reward = config.rewards.baseAmount + math.floor(travelDistance * config.rewards.perMeterRate)
                    
                    TaskLeaveVehicle(jobNPC, jobVehicle, 0)
                    Wait(2000)
                    
                    ClientUtils.DeleteNPC(jobNPC)
                    jobNPC = nil
                    
                    ClientUtils.Notify('Course terminée ! Distance: ' .. math.floor(travelDistance) .. 'm', 'success')
                    
                    TriggerServerEvent('kt_interim:completeJob', 'taxi', reward)
                    
                    local alert = lib.alertDialog({
                        header = 'Continuer le travail ?',
                        content = 'Voulez-vous prendre un autre client ?\n\n✅ Oui - Chercher un nouveau client\n❌ Non - Terminer et rendre le véhicule',
                        centered = true,
                        cancel = true,
                        labels = {
                            confirm = 'Oui, continuer',
                            cancel = 'Non, terminer'
                        }
                    })
                    
                    if alert == 'confirm' then
                        pickupPoint = ClientUtils.RandomChoice(config.pickupPoints)
                        
                        ClientUtils.RemoveBlip(jobBlip)
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
                        StartVehicleReturn(vehicleReturnZone, 'Taxi')
                    end
                    
                    return
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

-- ========================================
-- JOB: TRUCKER
-- ========================================

function StartTruckerJob(config)
    vehicleReturnZone = config.vehicleSpawn.coords
    
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
    
    local threadId = CreateThread(function()
        while IsJobActive() and collectedItems < config.item.amount do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - config.collectPoint.coords)
            
            if distance < 20.0 then
                ClientUtils.DrawMarker(config.collectPoint.coords, config.collectPoint.markerType, config.collectPoint.markerColor)
                
                if distance < 5.0 then
                    if not IsInJobVehicle() then
                        ClientUtils.DrawText3D(config.collectPoint.coords, '⚠️ Vous devez être dans le camion de job !')
                    else
                        ClientUtils.DrawText3D(config.collectPoint.coords, '[E] Charger les caisses')
                        
                        if IsControlJustPressed(0, 38) then
                            CollectTruckerCrate(config)
                        end
                    end
                end
            end
            
            Wait(0)
        end
        
        if IsJobActive() and collectedItems >= config.item.amount then
            StartTruckerDelivery(config)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function CollectTruckerCrate(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Chargement des caisses...', 3000, {
        anim = {dict = 'anim@heists@box_carry@', clip = 'idle'}
    })
    
    ClientUtils.DisableControls(false, false, false)
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
    
    StopActiveThreads()
    
    local threadId = CreateThread(function()
        while IsJobActive() do
            local playerCoords = ClientUtils.GetPlayerCoords()
            local distance = #(playerCoords - deliveryPoint.coords)
            
            if distance < 30.0 then
                ClientUtils.DrawMarker(deliveryPoint.coords, 1, {r = 0, g = 255, b = 0}, {x = 3.0, y = 3.0, z = 1.0})
                
                if distance < 10.0 then
                    if not IsInJobVehicle() then
                        ClientUtils.DrawText3D(deliveryPoint.coords, '⚠️ Vous devez être dans le camion de job !')
                    else
                        ClientUtils.DrawText3D(deliveryPoint.coords, '[E] Décharger les caisses')
                        
                        if IsControlJustPressed(0, 38) then
                            DeliverTruckerCrates(config)
                            return
                        end
                    end
                end
            end
            
            Wait(0)
        end
    end)
    
    table.insert(activeThreads, threadId)
end

function DeliverTruckerCrates(config)
    ClientUtils.DisableControls(true, true, false)
    
    local success = ClientUtils.ProgressBar('Déchargement des caisses...', 5000, {
        anim = {dict = 'anim@heists@box_carry@', clip = 'idle'}
    })
    
    ClientUtils.DisableControls(false, false, false)
    ClientUtils.StopAnimation()
    
    if success then
        TriggerServerEvent('kt_interim:depositItems', 'trucker', config.item.name, collectedItems, config.rewards.amount)
        
        collectedItems = 0
        
        local alert = lib.alertDialog({
            header = 'Continuer le travail ?',
            content = 'Voulez-vous faire une nouvelle livraison ?\n\n✅ Oui - Retourner au point de chargement\n❌ Non - Terminer et rendre le camion',
            centered = true,
            cancel = true,
            labels = {
                confirm = 'Oui, continuer',
                cancel = 'Non, terminer'
            }
        })
        
        if alert == 'confirm' then
            ClientUtils.RemoveBlip(jobBlip)
            jobBlip = ClientUtils.CreateBlip(
                config.collectPoint.coords,
                1,
                47,
                0.8,
                'Point de chargement'
            )
            ClientUtils.SetWaypoint(config.collectPoint.coords, 'Point de chargement')
            ClientUtils.Notify('Retournez au point de chargement', 'info')
            StartTruckerCollect(config)
        else
            StartVehicleReturn(vehicleReturnZone, 'Camionneur')
        end
    end
end

-- ========================================
-- CLEANUP
-- ========================================

function CleanupJobResources()
    StopActiveThreads()
    CancelJob()
    
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
    vehicleReturnZone = nil
end

