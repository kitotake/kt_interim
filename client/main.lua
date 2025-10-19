-- Variables locales
local activeJob = nil
local currentJobData = nil
local jobBlips = {}
local jobNPCs = {}
local isJobActive = false

-- Initialisation du script
CreateThread(function()
    Wait(1000)
    InitializeJobs()
end)

-- Initialiser tous les jobs
function InitializeJobs()
    for jobName, jobConfig in pairs(Config.Jobs) do
        if jobConfig.enabled then
            -- Créer les blips
            if Config.ShowBlips and jobConfig.blip then
                CreateJobBlip(jobName, jobConfig)
            end
            
            -- Spawn les NPCs
            if jobConfig.npc then
                SpawnJobNPC(jobName, jobConfig)
            end
        end
    end
    
    print('[KT_INTERIM] Jobs initialized successfully')
end

-- Créer un blip pour un job
function CreateJobBlip(jobName, jobConfig)
    local blip = ClientUtils.CreateBlip(
        jobConfig.blip.coords,
        jobConfig.blip.sprite,
        jobConfig.blip.color,
        jobConfig.blip.scale,
        jobConfig.label
    )
    
    jobBlips[jobName] = blip
end

-- Spawn un NPC pour un job
function SpawnJobNPC(jobName, jobConfig)
    local npc = ClientUtils.SpawnNPC(
        jobConfig.npc.model,
        jobConfig.npc.coords,
        jobConfig.npc.coords.w or 0.0,
        jobConfig.npc.scenario,
        true
    )
    
    if npc then
        jobNPCs[jobName] = npc
        
        -- Interaction avec ox_target
        if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
            exports.ox_target:addLocalEntity(npc, {
                {
                    name = 'interim_' .. jobName,
                    icon = 'fas fa-briefcase',
                    label = 'Parler à ' .. jobConfig.label,
                    onSelect = function()
                        OpenJobMenu(jobName, jobConfig)
                    end,
                    distance = 2.5
                }
            })
        end
    end
end

-- Boucle de détection des NPCs (si ox_target n'est pas utilisé)
if not Config.UseOxTarget then
    CreateThread(function()
        while true do
            local sleep = 1000
            local playerCoords = ClientUtils.GetPlayerCoords()
            
            for jobName, npc in pairs(jobNPCs) do
                if DoesEntityExist(npc) then
                    local npcCoords = GetEntityCoords(npc)
                    local distance = #(playerCoords - npcCoords)
                    
                    if distance < 10.0 then
                        sleep = 0
                        
                        if distance < 2.5 then
                            ClientUtils.DrawText3D(npcCoords + vector3(0.0, 0.0, 1.0), '[E] Parler')
                            
                            if IsControlJustPressed(0, 38) then -- E
                                OpenJobMenu(jobName, Config.Jobs[jobName])
                            end
                        end
                    end
                end
            end
            
            Wait(sleep)
        end
    end)
end

-- Ouvrir le menu d'un job
function OpenJobMenu(jobName, jobConfig)
    if isJobActive then
        ClientUtils.Notify('Vous avez déjà un job en cours !', 'error')
        return
    end
    
    local menuOptions = {
        {
            title = jobConfig.label,
            description = jobConfig.description,
            icon = 'briefcase',
            disabled = true
        },
        {
            title = 'Salaire',
            description = 'Gain par mission: ' .. ClientUtils.FormatMoney(jobConfig.salary),
            icon = 'dollar-sign',
            disabled = true
        },
        {
            title = 'Commencer le travail',
            description = 'Démarrer une mission',
            icon = 'play',
            onSelect = function()
                StartJob(jobName, jobConfig)
            end
        },
        {
            title = 'Annuler',
            description = 'Fermer le menu',
            icon = 'times',
            onSelect = function()
                lib.hideContext()
            end
        }
    }
    
    lib.registerContext({
        id = 'interim_menu_' .. jobName,
        title = 'Agence d\'intérim',
        options = menuOptions
    })
    
    lib.showContext('interim_menu_' .. jobName)
end

-- Démarrer un job
function StartJob(jobName, jobConfig)
    if isJobActive then
        ClientUtils.Notify('Vous avez déjà un job en cours !', 'error')
        return
    end
    
    activeJob = jobName
    currentJobData = jobConfig
    isJobActive = true
    
    ClientUtils.Notify('Mission commencée: ' .. jobConfig.label, 'success')
    
    -- Notifier le serveur
    TriggerServerEvent('kt_interim:startJob', jobName)
    
    -- Déclencher la logique spécifique du job
    TriggerEvent('kt_interim:startJob', jobName, jobConfig)
end

-- Terminer un job
function CompleteJob(reward)
    if not isJobActive then return end
    
    local jobName = activeJob
    local jobConfig = currentJobData
    
    -- Réinitialiser les variables
    activeJob = nil
    currentJobData = nil
    isJobActive = false
    
    ClientUtils.Notify('Mission terminée ! Récompense: ' .. ClientUtils.FormatMoney(reward), 'success')
end

-- Annuler un job
function CancelJob()
    if not isJobActive then return end
    
    local jobName = activeJob
    
    activeJob = nil
    currentJobData = nil
    isJobActive = false
    
    ClientUtils.Notify('Mission annulée', 'error')
    
    -- Nettoyer les ressources côté client
    TriggerEvent('kt_interim:cancelJob')
    
    -- Notifier le serveur
    TriggerServerEvent('kt_interim:playerCancelJob', jobName)
end

-- Obtenir le job actif
function GetActiveJob()
    return activeJob, currentJobData
end

-- Vérifier si un job est actif
function IsJobActive()
    return isJobActive
end

-- Event pour forcer l'arrêt d'un job (depuis le serveur)
RegisterNetEvent('kt_interim:forceStopJob', function()
    if isJobActive then
        activeJob = nil
        currentJobData = nil
        isJobActive = false
        
        print('[KT_INTERIM] Job forcibly stopped by server')
        print(isJobActive)
        print(activeJob)
        print(currentJobData)

        print('[KT_INTERIM] Triggering client cleanup for forced job stop')
        ClientUtils.Notify('Job interim forcé à s\'arrêter', 'error')
        
        -- Appeler le cleanup côté client
        TriggerEvent('kt_interim:cancelJob')
    end
end)

-- Commande pour annuler un job
RegisterCommand('cancelinterim', function()
    if isJobActive then
        CancelJob()
    else
        ClientUtils.Notify('Vous n\'avez pas de job en cours', 'error')
    end
end, false)

-- Event pour notification depuis le serveur
RegisterNetEvent('kt_interim:notify', function(message, type, duration)
    ClientUtils.Notify(message, type, duration)
end)

-- Cleanup quand le joueur quitte
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Supprimer les blips
        for _, blip in pairs(jobBlips) do
            ClientUtils.RemoveBlip(blip)
        end
        
        -- Supprimer les NPCs
        for _, npc in pairs(jobNPCs) do
            ClientUtils.DeleteNPC(npc)
        end
        
        -- Annuler le job actif
        if isJobActive then
            TriggerServerEvent('kt_interim:playerQuit', activeJob)
        end
    end
end)

-- Exports
exports('GetActiveJob', GetActiveJob)
exports('IsJobActive', IsJobActive)
exports('CancelJob', CancelJob)

