-- Table pour tracker les jobs actifs des joueurs
local activeJobs = {}
local lastActionTime = {}

-- Initialisation
CreateThread(function()
    print('^2[KT_INTERIM]^7 Server initialized successfully')
    
    -- Créer la table MySQL si nécessaire
    if GetResourceState('oxmysql') == 'started' then
        MySQL.Async.execute([[
            CREATE TABLE IF NOT EXISTS `kt_interim` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `identifier` VARCHAR(50) NOT NULL,
                `job_type` VARCHAR(50) NOT NULL,
                `data` TEXT,
                `reward` INT DEFAULT 0,
                `completed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX `idx_identifier` (`identifier`),
                INDEX `idx_job_type` (`job_type`)
            )
        ]], {}, function()
            print('^2[KT_INTERIM]^7 Database table checked/created')
        end)
    end
end)

-- Protection anti-spam
local function CanPerformAction(source, actionType, cooldown)
    cooldown = cooldown or 2000
    
    if not lastActionTime[source] then
        lastActionTime[source] = {}
    end
    
    local currentTime = GetGameTimer()
    local lastTime = lastActionTime[source][actionType] or 0
    
    if (currentTime - lastTime) < cooldown then
        return false
    end
    
    lastActionTime[source][actionType] = currentTime
    return true
end

-- Event: Ajouter un item pendant la collecte
RegisterNetEvent('kt_interim:addItem', function(item, amount)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
        return
    end
    
    -- Protection anti-spam
    if not CanPerformAction(source, 'addItem', 1000) then
        ServerUtils.Log('Player spamming addItem event', 'WARN', source)
        return
    end
    
    -- Vérifier si le joueur a un job actif
    if not activeJobs[source] then
        ServerUtils.Log('Attempt to add item without active job', 'WARN', source)
        return
    end
    
    -- Vérifier si le joueur peut porter l'item
    if not ServerUtils.CanCarryItem(source, item, amount) then
        ServerUtils.Notify(source, 'Vous ne pouvez pas porter plus d\'items !', 'error')
        return
    end
    
    -- Ajouter l'item
    local success = ServerUtils.AddItem(source, item, amount)
    
    if not success then
        ServerUtils.Notify(source, 'Erreur lors de l\'ajout de l\'item', 'error')
    end
end)

-- Event: Déposer les items et recevoir la récompense
RegisterNetEvent('kt_interim:depositItems', function(jobType, itemName, itemAmount, reward)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
        ServerUtils.Log('Player does not exist', 'ERROR', source)
        return
    end
    
    local identifier = ServerUtils.GetIdentifier(source)
    
    -- Vérifier que le joueur a un job actif
    if not activeJobs[source] or activeJobs[source] ~= jobType then
        ServerUtils.Log('Attempt to deposit items without active job or wrong job type', 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Anti-cheat: Vérifier le cooldown
    if not ServerUtils.CheckJobCooldown(source, jobType, 10000) then
        ServerUtils.Notify(source, 'Vous devez attendre avant de refaire cette mission', 'error')
        ServerUtils.Log('Cooldown violation for job: ' .. jobType, 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Vérifier que le joueur a bien les items
    if not ServerUtils.HasItem(source, itemName, itemAmount) then
        ServerUtils.Notify(source, 'Vous n\'avez pas les items requis !', 'error')
        ServerUtils.Log('Item check failed for job: ' .. jobType, 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Validation spécifique au job
    local validationFunc = {
    construction = exports['kt_interim'].ValidateConstructionJob,
    cleaning = exports['kt_interim'].ValidateCleaningJob,
    delivery = exports['kt_interim'].ValidateDeliveryJob,
    shop_logistics = exports['kt_interim'].ValidateShopLogisticsJob,
    taxi = exports['kt_interim'].ValidateTaxiJob,
    trucker = exports['kt_interim'].ValidateTruckerJob,
}
    -- Validation basique commune
    local config = Config.Jobs[jobType]
    if not config or not config.enabled then
        ServerUtils.Notify(source, 'Job non disponible', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Vérifier le montant de la récompense (tolérance de 50%)
    local maxReward = config.salary * 1.5
    local minReward = config.salary * 0.5
    
    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d)', reward, minReward, maxReward), 'WARN', source)
        ServerUtils.Notify(source, 'Récompense invalide', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Vérifier la quantité d'items si applicable
    if config.item and config.item.amount and itemAmount > 0 then
        if itemAmount < config.item.amount then
            ServerUtils.Log(string.format('Insufficient item amount: %d (expected at least %d)', itemAmount, config.item.amount), 'WARN', source)
            ServerUtils.Notify(source, 'Vous n\'avez pas assez d\'items !', 'error')
            TriggerClientEvent('kt_interim:forceStopJob', source)
            return
        end
        -- Si le joueur a plus d'items que nécessaire, on retire seulement la quantité requise
        if itemAmount > config.item.amount then
            itemAmount = config.item.amount
        end
    end
    
    -- Validation spécifique au type de job (optionnel)
    if validationFunc[jobType] then
        local valid, errorMsg = validationFunc[jobType](source, itemAmount)
        if not valid then
            ServerUtils.Notify(source, errorMsg or 'Validation échouée', 'error')
            TriggerClientEvent('kt_interim:forceStopJob', source)
            return
        end
    end
    
    -- Retirer les items
    local removed = ServerUtils.RemoveItem(source, itemName, itemAmount)
    
    if not removed then
        ServerUtils.Notify(source, 'Erreur lors du retrait des items', 'error')
        return
    end
    
    -- Donner la récompense
    local rewarded = ServerUtils.AddMoney(source, reward)
    
    if rewarded then
        ServerUtils.Notify(source, 'Mission terminée ! Vous avez reçu ' .. ServerUtils.FormatMoney(reward), 'success')
        
        -- Sauvegarder dans la base de données
        SaveJobCompletion(identifier, jobType, {
            reward = reward,
            itemsDeposited = itemAmount
        })
        
        -- Log
        ServerUtils.Log(string.format('Job completed: %s | Reward: $%d | Items: %d', jobType, reward, itemAmount), 'SUCCESS', source)
        
        -- Retirer le job actif
        activeJobs[source] = nil
        
        -- Triggers additionnels (réputation, bonus, quêtes)
        TriggerEvent('kt_interim:addReputation', source, jobType)
        TriggerEvent('kt_interim:updateQuest', source, jobType)
        TriggerEvent('kt_interim:applyBonus', source, jobType, reward)
    else
        -- Rendre les items si le paiement échoue
        ServerUtils.AddItem(source, itemName, itemAmount)
        ServerUtils.Notify(source, 'Erreur lors du paiement', 'error')
    end
end)

-- Event: Compléter un job (pour les jobs sans items comme taxi)
RegisterNetEvent('kt_interim:completeJob', function(jobType, reward)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
        return
    end
    
    local identifier = ServerUtils.GetIdentifier(source)
    
    -- Anti-cheat: Vérifier le cooldown
    if not ServerUtils.CheckJobCooldown(source, jobType, 10000) then
        ServerUtils.Notify(source, 'Vous devez attendre avant de refaire cette mission', 'error')
        ServerUtils.Log('Cooldown violation for job: ' .. jobType, 'WARN', source)
        return
    end
    
    -- Vérifier que le joueur a bien un job actif
    if not activeJobs[source] or activeJobs[source] ~= jobType then
        ServerUtils.Log('Job completion without active job: ' .. jobType, 'WARN', source)
        return
    end
    
    -- Validation basique commune
    local config = Config.Jobs[jobType]
    if not config or not config.enabled then
        ServerUtils.Notify(source, 'Job non disponible', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Vérifier le montant de la récompense (tolérance de 100% pour taxi à cause de la distance)
    local maxReward = config.salary * 2.5
    local minReward = config.salary * 0.5
    
    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d)', reward, minReward, maxReward), 'WARN', source)
        ServerUtils.Notify(source, 'Récompense invalide', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end
    
    -- Donner la récompense
    local rewarded = ServerUtils.AddMoney(source, reward)
    
    if rewarded then
        ServerUtils.Notify(source, 'Mission terminée ! Vous avez reçu ' .. ServerUtils.FormatMoney(reward), 'success')
        
        -- Sauvegarder dans la base de données
        SaveJobCompletion(identifier, jobType, {
            reward = reward
        })
        
        -- Log
        ServerUtils.Log(string.format('Job completed: %s | Reward: $%d', jobType, reward), 'SUCCESS', source)
        
        -- Retirer le job actif
        activeJobs[source] = nil
        
        -- Triggers additionnels
        TriggerEvent('kt_interim:addReputation', source, jobType)
        TriggerEvent('kt_interim:updateQuest', source, jobType)
        TriggerEvent('kt_interim:applyBonus', source, jobType, reward)
    else
        ServerUtils.Notify(source, 'Erreur lors du paiement', 'error')
    end
end)

RegisterNetEvent('kt_interim:startJob', function(jobType)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
        return
    end
    
    if activeJobs[source] then
        ServerUtils.Notify(source, 'Vous avez déjà un job en cours !', 'error')
        return
    end
    
    if not Config.Jobs[jobType] then
        ServerUtils.Log('Invalid job type: ' .. jobType, 'ERROR', source)
        return
    end
    
    activeJobs[source] = jobType
    
    ServerUtils.Log('Job started: ' .. jobType, 'INFO', source)
end)

RegisterNetEvent('kt_interim:playerCancelJob', function(jobType)
    local source = source
    
    if activeJobs[source] then
        ServerUtils.Log('Player manually cancelled job: ' .. (jobType or 'unknown'), 'INFO', source)
        activeJobs[source] = nil
    end
end)

RegisterNetEvent('kt_interim:playerQuit', function(jobType)
    local source = source
    
    if activeJobs[source] then
        ServerUtils.Log('Player quit during job: ' .. (jobType or 'unknown'), 'INFO', source)
        activeJobs[source] = nil
    end
end)

function SaveJobCompletion(identifier, jobType, data)
    if GetResourceState('oxmysql') ~= 'started' then
        return
    end
    
    MySQL.Async.execute([[
        INSERT INTO kt_interim (identifier, job_type, data, reward, completed_at)
        VALUES (@identifier, @job_type, @data, @reward, NOW())
    ]], {
        ['@identifier'] = identifier,
        ['@job_type'] = jobType,
        ['@data'] = json.encode(data),
        ['@reward'] = data.reward or 0
    })
end

-- Commande pour obtenir les stats d'un joueur (admin)
RegisterCommand('interimstats', function(source, args)
    if source == 0 then -- Console
        if args[1] then
            local targetSource = tonumber(args[1])
            if ServerUtils.PlayerExists(targetSource) then
                local identifier = ServerUtils.GetIdentifier(targetSource)
                GetPlayerJobStats(identifier, function(stats)
                    if stats then
                        print('^2[KT_INTERIM STATS]^7 Player: ' .. GetPlayerName(targetSource))
                        for _, stat in ipairs(stats) do
                            print(string.format('  Job: %s | Completed: %d times | Total earned: $%d', 
                                stat.job_type, stat.count, stat.total_earned or 0))
                        end
                    else
                        print('^1[KT_INTERIM]^7 No stats found for player')
                    end
                end)
            end
        end
    else
        -- Pour les joueurs, afficher leurs propres stats
        local identifier = ServerUtils.GetIdentifier(source)
        GetPlayerJobStats(identifier, function(stats)
            if stats and #stats > 0 then
                ServerUtils.Notify(source, 'Consultez la console (F8) pour vos statistiques', 'info')
                TriggerClientEvent('chat:addMessage', source, {
                    color = {0, 255, 0},
                    multiline = true,
                    args = {'Interim Stats', 'Vos statistiques de jobs:'}
                })
                for _, stat in ipairs(stats) do
                    TriggerClientEvent('chat:addMessage', source, {
                        args = {'', string.format('%s: %d missions | $%d gagnés', 
                            stat.job_type, stat.count, stat.total_earned or 0)}
                    })
                end
            else
                ServerUtils.Notify(source, 'Vous n\'avez pas encore complété de missions', 'info')
            end
        end)
    end
end, false)

-- Fonction pour obtenir les stats d'un joueur
function GetPlayerJobStats(identifier, callback)
    if GetResourceState('oxmysql') ~= 'started' then
        if callback then callback(nil) end
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT 
            job_type, 
            COUNT(*) as count, 
            SUM(reward) as total_earned
        FROM kt_interim
        WHERE identifier = @identifier
        GROUP BY job_type
    ]], {
        ['@identifier'] = identifier
    }, function(result)
        if callback then
            callback(result)
        end
    end)
end

-- Commande pour reset le cooldown d'un joueur (admin)
RegisterCommand('interim_reset', function(source, args)
    if source == 0 then -- Console only
        if args[1] then
            local targetSource = tonumber(args[1])
            if ServerUtils.PlayerExists(targetSource) then
                if activeJobs[targetSource] then
                    activeJobs[targetSource] = nil
                    print('^2[KT_INTERIM]^7 Reset job for player: ' .. GetPlayerName(targetSource))
                else
                    print('^1[KT_INTERIM]^7 Player has no active job')
                end
            else
                print('^1[KT_INTERIM]^7 Player not found')
            end
        end
    end
end, false)

-- Nettoyage quand un joueur se déconnecte
AddEventHandler('playerDropped', function(reason)
    local source = source
    
    if activeJobs[source] then
        ServerUtils.Log('Player disconnected during job', 'INFO', source)
        activeJobs[source] = nil
    end
    
    if lastActionTime[source] then
        lastActionTime[source] = nil
    end
end)

exports('IsPlayerOnJob', function(source)
    return activeJobs[source] ~= nil
end)

exports('GetPlayerActiveJob', function(source)
    return activeJobs[source]
end)
