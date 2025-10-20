local activeJobs = {}
local playerActionLimiter = {}

CreateThread(function()
    print('^2[KT_INTERIM]^7 Server initializing...')

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
    else
        print('^3[KT_INTERIM]^7 Warning: oxmysql not found, database features disabled')
    end

    print('^2[KT_INTERIM]^7 Server initialized successfully')
end)

local function CanPerformAction(source, actionType, cooldown)
    cooldown = cooldown or 2000

    if not playerActionLimiter[source] then
        playerActionLimiter[source] = {}
    end

    local currentTime = GetGameTimer()
    local lastTime = playerActionLimiter[source][actionType] or 0
    local timeDiff = currentTime - lastTime

    if timeDiff < cooldown then
        if timeDiff < cooldown / 2 then
            ServerUtils.Log(string.format(
                'Spam detected: %s (%.2fs ago)',
                actionType,
                timeDiff / 1000
            ), 'WARN', source)
        end
        return false
    end

    playerActionLimiter[source][actionType] = currentTime
    return true
end

RegisterNetEvent('kt_interim:addItem', function(item, amount)
    local source = source

    if not ServerUtils.PlayerExists(source) then
        return
    end

    if not CanPerformAction(source, 'addItem', 1000) then
        ServerUtils.Log('Player spamming addItem event', 'WARN', source)
        return
    end

    if not activeJobs[source] then
        ServerUtils.Log('Attempt to add item without active job', 'WARN', source)
        return
    end

    if not ServerUtils.CanCarryItem(source, item, amount) then
        ServerUtils.Notify(source, 'Vous ne pouvez pas porter plus d\'items !', 'error')
        return
    end

    local success = ServerUtils.AddItem(source, item, amount)

    if not success then
        ServerUtils.Notify(source, 'Erreur lors de l\'ajout de l\'item', 'error')
    end
end)

RegisterNetEvent('kt_interim:depositItems', function(jobType, itemName, reward)
    local source = source

    if not ServerUtils.PlayerExists(source) then return end

    local identifier = ServerUtils.GetIdentifier(source)
    if not identifier then return end

    if not activeJobs[source] or activeJobs[source] ~= jobType then
        ServerUtils.Log('Attempt to deposit items without active job or wrong job type', 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    if not ServerUtils.CheckJobCooldown(source, jobType, 5000) then
        ServerUtils.Notify(source, 'Vous devez attendre avant de refaire cette action', 'error')
        return
    end

    local config = Config.Jobs[jobType]
    if not config or not config.enabled then
        ServerUtils.Notify(source, 'Job non disponible', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    local itemAmount = ServerUtils.GetItemCount(source, itemName)

    print('Debug: Player has ' .. itemAmount .. ' of item ' .. itemName .. ' for job ' .. jobType)

    print('Debug: Expected item for job ' .. jobType .. ' is ' .. (config.item and config.item.name or 'N/A'))

    print(itemAmount)
    if itemAmount <= 0 then
        ServerUtils.Notify(source, 'Vous n\'avez pas les items requis !', 'error')
        ServerUtils.Log('Player tried to deposit 0 items for job: ' .. jobType, 'WARN', source)
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    -- Calcul du gain basé sur les items réellement déposés
    local baseRewardPerItem = config.salary / (config.item and config.item.amount or 1)
    local expectedReward = math.floor(baseRewardPerItem * itemAmount)
    local maxReward = expectedReward * 1.5
    local minReward = expectedReward * 0.5

    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d for %d items)',
            reward, minReward, maxReward, itemAmount), 'WARN', source)
        ServerUtils.Notify(source, 'Récompense invalide', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    -- Validation spécifique au job
    local validationFunctions = {
        construction = exports['kt_interim'].ValidateConstructionJob,
        cleaning = exports['kt_interim'].ValidateCleaningJob,
        delivery = exports['kt_interim'].ValidateDeliveryJob,
        shop_logistics = exports['kt_interim'].ValidateShopLogisticsJob,
        trucker = exports['kt_interim'].ValidateTruckerJob,
    }

    if validationFunctions[jobType] then
        local valid, errorMsg = validationFunctions[jobType](source, itemAmount)
        if not valid then
            ServerUtils.Notify(source, errorMsg or 'Validation échouée', 'error')
            TriggerClientEvent('kt_interim:forceStopJob', source)
            return
        end
    end

    -- Retrait des items du joueur
    if not ServerUtils.RemoveItem(source, itemName, itemAmount) then
        ServerUtils.Notify(source, 'Erreur lors du retrait des items', 'error')
        return
    end

    -- Paiement du joueur
    if ServerUtils.AddMoney(source, reward) then
        ServerUtils.Notify(source, 'Mission terminée ! Vous avez reçu ' .. ServerUtils.FormatMoney(reward), 'success')
        SaveJobCompletion(identifier, jobType, { reward = reward, itemsDeposited = itemAmount })
        ServerUtils.Log(string.format('Job completed: %s | Reward: $%d | Items: %d', jobType, reward, itemAmount),
            'SUCCESS', source)

        TriggerEvent('kt_interim:addReputation', source, jobType)
        TriggerEvent('kt_interim:updateQuest', source, jobType)
        TriggerEvent('kt_interim:applyBonus', source, jobType, reward)
    else
        -- Restaure les items si paiement échoue
        ServerUtils.AddItem(source, itemName, itemAmount)
        ServerUtils.Notify(source, 'Erreur lors du paiement', 'error')
    end
end)


RegisterNetEvent('kt_interim:completeJob', function(jobType, reward)
    local source = source

    if not ServerUtils.PlayerExists(source) then
        return
    end

    local identifier = ServerUtils.GetIdentifier(source)
    if not identifier then
        return
    end

    if not ServerUtils.CheckJobCooldown(source, jobType, 5000) then
        ServerUtils.Notify(source, 'Vous devez attendre avant de refaire cette action', 'error')
        ServerUtils.Log('Cooldown violation for job: ' .. jobType, 'WARN', source)
        return
    end

    if not activeJobs[source] or activeJobs[source] ~= jobType then
        ServerUtils.Log('Job completion without active job: ' .. jobType, 'WARN', source)
        return
    end

    local config = Config.Jobs[jobType]
    if not config or not config.enabled then
        ServerUtils.Notify(source, 'Job non disponible', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    local maxReward = config.salary * 2.5
    local minReward = config.salary * 0.5

    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d)',
            reward, minReward, maxReward), 'WARN', source)
        ServerUtils.Notify(source, 'Récompense invalide', 'error')
        TriggerClientEvent('kt_interim:forceStopJob', source)
        return
    end

    local rewarded = ServerUtils.AddMoney(source, reward)

    if rewarded then
        ServerUtils.Notify(source, 'Mission terminée ! Vous avez reçu ' .. ServerUtils.FormatMoney(reward), 'success')

        SaveJobCompletion(identifier, jobType, {
            reward = reward
        })

        ServerUtils.Log(string.format('Job completed: %s | Reward: $%d', jobType, reward), 'SUCCESS', source)

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

    if not Config.Jobs[jobType].enabled then
        ServerUtils.Notify(source, 'Ce job n\'est pas disponible actuellement', 'error')
        return
    end

    activeJobs[source] = jobType
    ServerUtils.Log('Job started: ' .. jobType, 'INFO', source)
end)

RegisterNetEvent('kt_interim:cancelJob', function()
    local source = source

    if activeJobs[source] then
        local jobType = activeJobs[source]
        ServerUtils.Log('Player cancelled job: ' .. jobType, 'INFO', source)
        activeJobs[source] = nil
    end
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

RegisterCommand('interimstats', function(source, args)
    if source == 0 then
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
            else
                print('^1[KT_INTERIM]^7 Player not found')
            end
        else
            print('^3[KT_INTERIM]^7 Usage: interimstats <player_id>')
        end
    else
        local identifier = ServerUtils.GetIdentifier(source)
        GetPlayerJobStats(identifier, function(stats)
            if stats and #stats > 0 then
                TriggerClientEvent('chat:addMessage', source, {
                    color = { 0, 255, 0 },
                    multiline = true,
                    args = { 'Interim Stats', 'Vos statistiques de jobs:' }
                })
                for _, stat in ipairs(stats) do
                    TriggerClientEvent('chat:addMessage', source, {
                        args = { '', string.format('%s: %d missions | $%d gagnés',
                            stat.job_type, stat.count, stat.total_earned or 0) }
                    })
                end
            else
                ServerUtils.Notify(source, 'Vous n\'avez pas encore complété de missions', 'info')
            end
        end)
    end
end, false)

local function IsAdmin(xPlayer)
    return xPlayer and (xPlayer.getGroup() == 'admin' or xPlayer.getGroup() == 'superadmin')
end

RegisterCommand('interim_reset', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not IsAdmin(xPlayer) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^1[KT_INTERIM]', 'Tu n’as pas la permission d’utiliser cette commande.' }
            })
        end
        return
    end

    if args[1] then
        local targetSource = tonumber(args[1])
        if ServerUtils.PlayerExists(targetSource) then
            if activeJobs[targetSource] then
                local jobType = activeJobs[targetSource]
                activeJobs[targetSource] = nil
                print(('^2[KT_INTERIM]^7 Reset job for player: %s (Job: %s)'):format(GetPlayerName(targetSource), jobType))
            else
                print('^1[KT_INTERIM]^7 Player has no active job')
            end
        else
            print('^1[KT_INTERIM]^7 Player not found')
        end
    else
        print('^3[KT_INTERIM]^7 Usage: /interim_reset <player_id>')
    end
end, false)

RegisterCommand('interim_stop', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not IsAdmin(xPlayer) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^1[KT_INTERIM]', 'Tu n’as pas la permission d’utiliser cette commande.' }
            })
        end
        return
    end

    if args[1] then
        local targetSource = tonumber(args[1])
        if ServerUtils.PlayerExists(targetSource) then
            if activeJobs[targetSource] then
                local jobType = activeJobs[targetSource]
                activeJobs[targetSource] = nil
                TriggerClientEvent('kt_interim:forceStopJob', targetSource)
                print(('^2[KT_INTERIM]^7 Force stopped job for player: %s (Job: %s)'):format(GetPlayerName(targetSource),
                    jobType))
            else
                print('^1[KT_INTERIM]^7 Player has no active job')
            end
        else
            print('^1[KT_INTERIM]^7 Player not found')
        end
    else
        print('^3[KT_INTERIM]^7 Usage: /interim_stop <player_id>')
    end
end, false)

RegisterCommand('interim_list', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not IsAdmin(xPlayer) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^1[KT_INTERIM]', 'Tu n’as pas la permission d’utiliser cette commande.' }
            })
        end
        return
    end

    local count = 0
    print('^2[KT_INTERIM]^7 Active jobs:')
    for playerId, jobType in pairs(activeJobs) do
        if ServerUtils.PlayerExists(playerId) then
            count = count + 1
            print(string.format('  [%d] %s - Job: %s', playerId, GetPlayerName(playerId), jobType))
        end
    end

    if count == 0 then
        print('^3[KT_INTERIM]^7 No active jobs')
    else
        print(('^2[KT_INTERIM]^7 Total: %d active job(s)'):format(count))
    end
end, false)

RegisterCommand('interim_cleanup', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not IsAdmin(xPlayer) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^1[KT_INTERIM]', 'Tu n’as pas la permission d’utiliser cette commande.' }
            })
        end
        return
    end

    local cleaned = 0
    for playerId, jobType in pairs(activeJobs) do
        if not ServerUtils.PlayerExists(playerId) then
            activeJobs[playerId] = nil
            cleaned = cleaned + 1
        end
    end
    print(('^2[KT_INTERIM]^7 Cleaned up %d orphaned job(s)'):format(cleaned))
end, false)

RegisterCommand('interim_debug', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer or not IsAdmin(xPlayer) then
        if source > 0 then
            TriggerClientEvent('chat:addMessage', source, {
                args = { '^1[KT_INTERIM]', 'Tu n’as pas la permission d’utiliser cette commande.' }
            })
        end
        return
    end

    if args[1] then
        local targetSource = tonumber(args[1])
        if ServerUtils.PlayerExists(targetSource) then
            local identifier = ServerUtils.GetIdentifier(targetSource)
            local jobType = activeJobs[targetSource]

            print('^2[KT_INTERIM DEBUG]^7 Player: ' .. GetPlayerName(targetSource))
            print('  Source: ' .. targetSource)
            print('  Identifier: ' .. (identifier or 'N/A'))
            print('  Active Job: ' .. (jobType or 'None'))
            print('  Action Limiter: ' .. (playerActionLimiter[targetSource] and 'Yes' or 'No'))
        else
            print('^1[KT_INTERIM]^7 Player not found')
        end
    else
        print('^3[KT_INTERIM]^7 Usage: /interim_debug <player_id>')
    end
end, false)


AddEventHandler('playerDropped', function(reason)
    local source = source

    if activeJobs[source] then
        ServerUtils.Log('Player disconnected during job: ' .. activeJobs[source], 'INFO', source)
        activeJobs[source] = nil
    end

    if playerActionLimiter[source] then
        playerActionLimiter[source] = nil
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^3[KT_INTERIM]^7 Resource stopping - Cleaning up active jobs')

        for playerId, jobType in pairs(activeJobs) do
            if ServerUtils.PlayerExists(playerId) then
                TriggerClientEvent('kt_interim:forceStopJob', playerId)
                ServerUtils.Notify(playerId, 'Le système d\'intérim redémarre. Votre job a été annulé.', 'error')
            end
        end

        activeJobs = {}
        playerActionLimiter = {}

        print('^2[KT_INTERIM]^7 Cleanup completed')
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print('^2[KT_INTERIM]^7 Resource started')

        activeJobs = {}
        playerActionLimiter = {}
    end
end)



if Config.Debug then
    CreateThread(function()
        while true do
            Wait(60000)

            local activeCount = 0
            for playerId, jobType in pairs(activeJobs) do
                if ServerUtils.PlayerExists(playerId) then
                    activeCount = activeCount + 1
                else
                    activeJobs[playerId] = nil
                    ServerUtils.Log('Cleaned up orphaned job for disconnected player', 'WARN')
                end
            end

            if activeCount > 0 then
                print(string.format('^2[KT_INTERIM]^7 Monitor: %d active job(s)', activeCount))
            end
        end
    end)
end

exports('IsPlayerOnJob', function(source)
    return activeJobs[source] ~= nil
end)

exports('GetPlayerActiveJob', function(source)
    return activeJobs[source]
end)

exports('ForceStopJob', function(source)
    if activeJobs[source] then
        local jobType = activeJobs[source]
        activeJobs[source] = nil
        TriggerClientEvent('kt_interim:forceStopJob', source)
        ServerUtils.Log('Job force stopped: ' .. jobType, 'INFO', source)
        return true
    end
    return false
end)

exports('GetActiveJobsCount', function()
    local count = 0
    for _ in pairs(activeJobs) do
        count = count + 1
    end
    return count
end)

exports('GetAllActiveJobs', function()
    local jobs = {}
    for playerId, jobType in pairs(activeJobs) do
        if ServerUtils.PlayerExists(playerId) then
            table.insert(jobs, {
                playerId = playerId,
                playerName = GetPlayerName(playerId),
                jobType = jobType
            })
        end
    end
    return jobs
end)

print('^2[KT_INTERIM]^7 Server main script loaded successfully')
