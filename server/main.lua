-- Table pour tracker les jobs actifs des joueurs
local activeJobs = {}

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

-- Event: Ajouter un item pendant la collecte
RegisterNetEvent('kt_interim:addItem', function(item, amount)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
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
        return
    end
    
    local identifier = ServerUtils.GetIdentifier(source)
    
    -- Anti-cheat: Vérifier le cooldown
    if not ServerUtils.CheckJobCooldown(source, jobType, 10000) then
        ServerUtils.Notify(source, 'Vous devez attendre avant de refaire cette mission', 'error')
        ServerUtils.Log('Cooldown violation for job: ' .. jobType, 'WARN', source)
        return
    end
    
    -- Vérifier que le joueur a bien les items
    if not ServerUtils.HasItem(source, itemName, itemAmount) then
        ServerUtils.Notify(source, 'Vous n\'avez pas les items requis !', 'error')
        ServerUtils.Log('Item check failed for job: ' .. jobType, 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
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
        ServerUtils.Log(string.format('Job completed: %s | Reward: $%d', jobType, reward), 'SUCCESS', source)
        
        -- Retirer le job actif
        if activeJobs[source] then
            activeJobs[source] = nil
        end
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
    else
        ServerUtils.Notify(source, 'Erreur lors du paiement', 'error')
    end
end)

-- Event: Démarrer un job (tracking)
RegisterNetEvent('kt_interim:startJob', function(jobType)
    local source = source
    
    if not ServerUtils.PlayerExists(source) then
        return
    end
    
    -- Vérifier si le joueur a déjà un job actif
    if activeJobs[source] then
        ServerUtils.Notify(source, 'Vous avez déjà un job en cours !', 'error')
        return
    end
    
    -- Vérifier si le job existe
    if not Config.Jobs[jobType] then
        ServerUtils.Log('Invalid job type: ' .. jobType, 'ERROR', source)
        return
    end
    
    -- Marquer le job comme actif
    activeJobs[source] = jobType
    
    ServerUtils.Log('Job started: ' .. jobType, 'INFO', source)
end)

-- Event: Joueur quitte pendant un job
RegisterNetEvent('kt_interim:playerQuit', function(jobType)
    local source = source
    
    if activeJobs[source] then
        ServerUtils.Log('Player quit during job: ' .. jobType, 'INFO', source)
        activeJobs[source] = nil
    end
end)

-- Fonction pour sauvegarder une complétion de job
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
RegisterCommand('interimreset', function(source, args)
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
end)

-- Export pour vérifier si un joueur a un job actif
exports('IsPlayerOnJob', function(source)
    return activeJobs[source] ~= nil
end)

exports('GetPlayerActiveJob', function(source)
    return activeJobs[source]
end)