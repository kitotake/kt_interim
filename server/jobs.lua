print('^2[KT_INTERIM]^7 Jobs server script loaded')

function ValidateJobCompletion(source, jobType, itemAmount, reward)
    local config = Config.Jobs[jobType]
    
    if not config or not config.enabled then
        ServerUtils.Log('Job not enabled: ' .. jobType, 'ERROR', source)
        return false, 'Job non disponible'
    end
    
    local maxReward = config.salary * 1.5
    local minReward = config.salary * 0.5
    
    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d)', reward, minReward, maxReward), 'WARN', source)
        return false, 'Récompense invalide'
    end
    
    if config.item and config.item.amount and itemAmount > 0 then
        if itemAmount == config.item.amount then
            print(itemAmount)
            print(config.item.amount)
            ServerUtils.Log(string.format('Invalid item amount: %d (expected %d)', itemAmount, config.item.amount), 'WARN', source)
            return false, 'Quantité d\'items invalide'
        end
    end
    
    if CheckPenalty and CheckPenalty(source) then
        return false, 'Vous avez trop de pénalités. Attendez avant de refaire un job.'
    end
    
    return true
end

function ValidateConstructionJob(source, itemAmount)
    local config = Config.Jobs['construction']
    
    if not config or not config.enabled then
        return false, 'Job non disponible'
    end
    
    if itemAmount == config.item.amount then
        ServerUtils.Log('Invalid item amount for construction job', 'WARN', source)
        return false, 'Quantité d\'items invalide'
    end
    
    return true
end

function ValidateCleaningJob(source, itemAmount)
    local config = Config.Jobs['cleaning']
    
    if not config or not config.enabled then
        return false, 'Job non disponible'
    end
    
    if itemAmount == config.item.amount then
        ServerUtils.Log('Invalid item amount for cleaning job', 'WARN', source)
        return false, 'Quantité d\'items invalide'
    end
    
    return true
end

function ValidateDeliveryJob(source)
    local config = Config.Jobs['delivery']
    
    if not config or not config.enabled then
        return false, 'Job non disponible'
    end
    
    local playerPed = GetPlayerPed(source)
    if not DoesEntityExist(playerPed) then
        return false, 'Joueur invalide'
    end
    
    return true
end

function ValidateShopLogisticsJob(source, itemAmount)
    local config = Config.Jobs['shop_logistics']
    
    if not config or not config.enabled then
        return false, 'Job non disponible'
    end
    
    if itemAmount == config.item.amount then
        ServerUtils.Log('Invalid item amount for shop logistics job', 'WARN', source)
        return false, 'Quantité d\'items invalide'
    end
    
    return true
end

function CalculateTaxiReward(distance, baseReward, perMeterRate)
    local reward = baseReward + math.floor(distance * perMeterRate)
    
    reward = math.max(reward, baseReward)
    reward = math.min(reward, baseReward * 3) 
    
    return reward
end

function ValidateTaxiJob(source, distance)
    local config = Config.Jobs['taxi']
    
    if not config or not config.enabled then
        return false, 'Job non disponible', 0
    end
    
    if distance < 50 or distance > 10000 then
        ServerUtils.Log('Suspicious taxi distance: ' .. distance, 'WARN', source)
        return false, 'Distance invalide', 0
    end
    
    local reward = CalculateTaxiReward(distance, config.rewards.baseAmount, config.rewards.perMeterRate)
    
    return true, nil, reward
end

function ValidateTruckerJob(source, itemAmount)
    local config = Config.Jobs['trucker']
    
    if not config or not config.enabled then
        return false, 'Job non disponible'
    end
    
    if itemAmount == config.item.amount then
        ServerUtils.Log('Invalid item amount for trucker job', 'WARN', source)
        return false, 'Quantité d\'items invalide'
    end
    
    return true
end

local playerBonusTracker = {}

function CheckPlayerBonus(identifier, jobType)
    if not playerBonusTracker[identifier] then
        playerBonusTracker[identifier] = {}
    end
    
    if not playerBonusTracker[identifier][jobType] then
        playerBonusTracker[identifier][jobType] = {
            count = 0,
            lastCompletion = 0
        }
    end
    
    local tracker = playerBonusTracker[identifier][jobType]
    local currentTime = os.time()
    
    if (currentTime - tracker.lastCompletion) > 86400 then
        tracker.count = 0
    end
    
    tracker.count = tracker.count + 1
    tracker.lastCompletion = currentTime
    
    if tracker.count % 5 == 0 then
        return true, tracker.count
    end
    
    return false, tracker.count
end

function CalculateBonusReward(baseReward, jobCount)
    local bonusMultiplier = 1.0
    
    if jobCount >= 5 and jobCount < 10 then
        bonusMultiplier = 1.1 -- +10%
    elseif jobCount >= 10 and jobCount < 20 then
        bonusMultiplier = 1.2 -- +20%
    elseif jobCount >= 20 then
        bonusMultiplier = 1.3 -- +30%
    end
    
    return math.floor(baseReward * bonusMultiplier)
end

RegisterNetEvent('kt_interim:applyBonus', function(source, jobType, baseReward)
    local identifier = ServerUtils.GetIdentifier(source)
    
    local hasBonus, jobCount = CheckPlayerBonus(identifier, jobType)
    
    if hasBonus then
        local bonusAmount = math.floor(baseReward * 0.15) -- Bonus de 15%
        ServerUtils.AddMoney(source, bonusAmount)
        ServerUtils.Notify(source, '🎉 Bonus de productivité: ' .. ServerUtils.FormatMoney(bonusAmount), 'success')
        ServerUtils.Log(string.format('Bonus applied: $%d for %d jobs completed', bonusAmount, jobCount), 'BONUS', source)
    end
end)

local playerReputation = {}

function GetPlayerReputation(identifier)
    if not playerReputation[identifier] then
        playerReputation[identifier] = {
            level = 1,
            xp = 0,
            totalJobs = 0
        }
    end
    return playerReputation[identifier]
end

function AddReputationXP(identifier, amount)
    local rep = GetPlayerReputation(identifier)
    rep.xp = rep.xp + amount
    rep.totalJobs = rep.totalJobs + 1
    
    local xpNeeded = rep.level * 100
    if rep.xp >= xpNeeded then
        rep.level = rep.level + 1
        rep.xp = rep.xp - xpNeeded
        return true, rep.level
    end
    
    return false, rep.level
end

RegisterNetEvent('kt_interim:addReputation', function(source, jobType)
    local identifier = ServerUtils.GetIdentifier(source)
    
    local xpGain = 10
    local config = Config.Jobs[jobType]
    if config then
        xpGain = math.floor(config.salary / 15) 
    end
    
    local leveledUp, currentLevel = AddReputationXP(identifier, xpGain)
    
    if leveledUp then
        ServerUtils.Notify(source, '⭐ Niveau de réputation augmenté: Niveau ' .. currentLevel, 'success')
        ServerUtils.Log(string.format('Reputation level up: Level %d', currentLevel), 'REP', source)
        
        local bonusReward = currentLevel * 50
        ServerUtils.AddMoney(source, bonusReward)
        ServerUtils.Notify(source, 'Bonus de montée de niveau: ' .. ServerUtils.FormatMoney(bonusReward), 'success')
    end
end)

RegisterCommand('interimrep', function(source)
    if source > 0 then
        local identifier = ServerUtils.GetIdentifier(source)
        local rep = GetPlayerReputation(identifier)
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 215, 0},
            multiline = true,
            args = {'Réputation Intérim', string.format('Niveau: %d | XP: %d/%d | Jobs totaux: %d', 
                rep.level, rep.xp, rep.level * 100, rep.totalJobs)}
        })
    end
end, false)

local playerPenalties = {}

function AddPenalty(source, reason)
    if not playerPenalties[source] then
        playerPenalties[source] = {
            count = 0,
            lastPenalty = 0
        }
    end
    
    playerPenalties[source].count = playerPenalties[source].count + 1
    playerPenalties[source].lastPenalty = os.time()
    
    ServerUtils.Log(string.format('Penalty added: %s | Total: %d', reason, playerPenalties[source].count), 'PENALTY', source)
    
    if playerPenalties[source].count >= 5 then
        local identifier = ServerUtils.GetIdentifier(source)
        ServerUtils.BanPlayer(identifier, 'Trop de pénalités (triche suspectée)', 3600) -- 1 heure
        DropPlayer(source, 'Vous avez été temporairement banni du système d\'intérim pour comportement suspect')
    end
end

function CheckPenalty(source)
    if not playerPenalties[source] then
        return false
    end
    
    local currentTime = os.time()
    local penalty = playerPenalties[source]
    
    if (currentTime - penalty.lastPenalty) > 3600 then
        playerPenalties[source] = nil
        return false
    end
    
    return penalty.count >= 3
end

RegisterNetEvent('kt_interim:reportSuspicious', function(reason)
    local source = source
    AddPenalty(source, reason)
    ServerUtils.Notify(source, 'Activité suspecte détectée. Attention aux pénalités !', 'error')
end)

local dailyQuests = {}

function GenerateDailyQuests()
    local quests = {}
    local jobTypes = {}
    
    for jobName, config in pairs(Config.Jobs) do
        if config.enabled then
            table.insert(jobTypes, jobName)
        end
    end
    
    -- Générer 5 quêtes aléatoires
    for i = 1, 5 do
        local jobType = ServerUtils.RandomChoice(jobTypes)
        local requiredAmount = math.random(3, 5)
        
        table.insert(quests, {
            jobType = jobType,
            requiredAmount = requiredAmount,
            reward = Config.Jobs[jobType].salary * requiredAmount * 1.2, -- 20% bonus
            completed = 0
        })
    end
    
    return quests
end

function InitializeDailyQuests()
    dailyQuests = GenerateDailyQuests()
    print('^2[KT_INTERIM]^7 Daily quests initialized')
end

function UpdateDailyQuest(identifier, jobType)
    for _, quest in ipairs(dailyQuests) do
        if quest.jobType == jobType then
            if not quest.completedBy then
                quest.completedBy = {}
            end
            
            if not quest.completedBy[identifier] then
                quest.completedBy[identifier] = 0
            end
            
            quest.completedBy[identifier] = quest.completedBy[identifier] + 1
            
            if quest.completedBy[identifier] >= quest.requiredAmount then
                return true, quest.reward
            end
            
            return false, quest.completedBy[identifier], quest.requiredAmount
        end
    end
    
    return false
end

-- Initialiser les quêtes au démarrage
CreateThread(function()
    Wait(2000)
    InitializeDailyQuests()
    
    -- Reset les quêtes toutes les 24h
    while true do
        Wait(86400000) -- 24 heures
        InitializeDailyQuests()
        print('^2[KT_INTERIM]^7 Daily quests reset')
    end
end)

RegisterNetEvent('kt_interim:updateQuest', function(source, jobType)
    local identifier = ServerUtils.GetIdentifier(source)
    
    local completed, rewardOrProgress, required = UpdateDailyQuest(identifier, jobType)
    
    if completed then
        ServerUtils.AddMoney(source, rewardOrProgress)
        ServerUtils.Notify(source, '🏆 Quête journalière complétée ! Bonus: ' .. ServerUtils.FormatMoney(rewardOrProgress), 'success')
        ServerUtils.Log(string.format('Daily quest completed: %s | Reward: $%d', jobType, rewardOrProgress), 'QUEST', source)
    elseif rewardOrProgress then
        ServerUtils.Notify(source, string.format('Progression quête: %d/%d', rewardOrProgress, required), 'info')
    end
end)

-- Commande pour voir les quêtes du jour
RegisterCommand('interimquests', function(source)
    if source > 0 then
        local identifier = ServerUtils.GetIdentifier(source)
        
        TriggerClientEvent('chat:addMessage', source, {
            color = {255, 165, 0},
            multiline = true,
            args = {'Quêtes Journalières', '--- Missions du jour ---'}
        })
        
        for i, quest in ipairs(dailyQuests) do
            local progress = 0
            if quest.completedBy and quest.completedBy[identifier] then
                progress = quest.completedBy[identifier]
            end
            
            local status = progress >= quest.requiredAmount and '✅ Complétée' or string.format('⏳ %d/%d', progress, quest.requiredAmount)
            
            TriggerClientEvent('chat:addMessage', source, {
                args = {'', string.format('%d. %s: %s | Récompense: $%d', 
                    i, quest.jobType, status, quest.reward)}
            })
            
            print('Sent quest info to player ' .. source)
           
            print(string.format('Quête %d | %s: %s | Récompense: $%d', i, quest.jobType, status, quest.reward))
       

        end
    end
end, false)

-- ========== SYSTÈME DE SALAIRE DYNAMIQUE ==========
local jobDemand = {}

function UpdateJobDemand(jobType)
    if not jobDemand[jobType] then
        jobDemand[jobType] = {
            completions = 0,
            lastReset = os.time()
        }
    end
    
    jobDemand[jobType].completions = jobDemand[jobType].completions + 1
    
    -- Reset toutes les heures
    local currentTime = os.time()
    if (currentTime - jobDemand[jobType].lastReset) > 3600 then
        jobDemand[jobType].completions = 0
        jobDemand[jobType].lastReset = currentTime
    end
end

function GetDynamicReward(jobType, baseReward)
    if not jobDemand[jobType] then
        return baseReward
    end
    
    local completions = jobDemand[jobType].completions
    local multiplier = 1.0
    
    -- Moins le job est fait, plus il paie
    if completions < 5 then
        multiplier = 1.3 -- +30%
    elseif completions < 10 then
        multiplier = 1.15 -- +15%
    elseif completions < 20 then
        multiplier = 1.0 -- Normal
    else
        multiplier = 0.85 -- -15% si trop de monde
    end
    
    return math.floor(baseReward * multiplier)
end

RegisterNetEvent('kt_interim:getDynamicReward', function(jobType, baseReward)
    local source = source
    UpdateJobDemand(jobType)
    local dynamicReward = GetDynamicReward(jobType, baseReward)
    
    if dynamicReward > baseReward then
        ServerUtils.Notify(source, '📈 Demande élevée ! Récompense augmentée: +' .. math.floor(((dynamicReward - baseReward) / baseReward) * 100) .. '%', 'success')
    elseif dynamicReward < baseReward then
        ServerUtils.Notify(source, '📉 Forte affluence. Récompense réduite: ' .. math.floor(((baseReward - dynamicReward) / baseReward) * 100) .. '%', 'warning')
    end
    
    TriggerClientEvent('kt_interim:receiveDynamicReward', source, dynamicReward)
end)

-- ========== EXPORTS ==========
exports('ValidateJobCompletion', ValidateJobCompletion)
exports('ValidateConstructionJob', ValidateConstructionJob)
exports('ValidateCleaningJob', ValidateCleaningJob)
exports('ValidateDeliveryJob', ValidateDeliveryJob)
exports('ValidateShopLogisticsJob', ValidateShopLogisticsJob)
exports('ValidateTaxiJob', ValidateTaxiJob)
exports('ValidateTruckerJob', ValidateTruckerJob)
exports('GetPlayerReputation', GetPlayerReputation)
exports('GetDynamicReward', GetDynamicReward)
