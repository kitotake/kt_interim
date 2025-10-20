print('^2[KT_INTERIM]^7 Jobs server script loaded')

local function ValidateItemAmount(source, jobType, itemAmount)
    local config = Config.Jobs[jobType]

    if not config or not config.enabled then
        return false, 'Job non disponible'
    end

    if config.item and config.item.amount then
        if not itemAmount then
            ServerUtils.Log(('itemAmount manquant pour %s'):format(jobType), 'ERROR', source)
            return false, 'Données invalides'
        end

        if itemAmount < config.item.amount then
            ServerUtils.Log(('Quantité invalide pour %s: %d/%d'):format(
                jobType, itemAmount, config.item.amount), 'WARN', source)
            return false, 'Quantité d\'items invalide'
        end
    end

    return true
end

function ValidateJobCompletion(source, jobType, itemAmount, reward)
    local config = Config.Jobs[jobType]
    
    if not config or not config.enabled then
        ServerUtils.Log('Job not enabled: ' .. jobType, 'ERROR', source)
        return false, 'Job non disponible'
    end
    
    local maxReward = config.salary * 1.5
    local minReward = config.salary * 0.5
    
    if reward > maxReward or reward < minReward then
        ServerUtils.Log(string.format('Suspicious reward: $%d (expected $%d-$%d)', 
            reward, minReward, maxReward), 'WARN', source)
        return false, 'Récompense invalide'
    end
    
    if itemAmount and itemAmount > 0 then
        local valid, err = ValidateItemAmount(source, jobType, itemAmount)
        if not valid then
            return false, err
        end
    end
    
    if CheckPenalty(source) then
        return false, 'Vous avez trop de pénalités. Attendez avant de refaire un job.'
    end
    
    return true
end

function ValidateConstructionJob(source, itemAmount)
    return ValidateItemAmount(source, 'construction', itemAmount)
end

function ValidateCleaningJob(source, itemAmount)
    return ValidateItemAmount(source, 'cleaning', itemAmount)
end

function ValidateDeliveryJob(source, itemAmount)
    return ValidateItemAmount(source, 'delivery', itemAmount)
end

function ValidateShopLogisticsJob(source, itemAmount)
    return ValidateItemAmount(source, 'shop_logistics', itemAmount)
end

function ValidateTruckerJob(source, itemAmount)
    return ValidateItemAmount(source, 'trucker', itemAmount)
end

function ValidateTaxiJob(source, distance)
    local config = Config.Jobs['taxi']
    
    if not config or not config.enabled then
        return false, 'Job non disponible', 0
    end
    
    if not distance or distance < 50 or distance > 10000 then
        ServerUtils.Log('Suspicious taxi distance: ' .. tostring(distance), 'WARN', source)
        return false, 'Distance invalide', 0
    end
    
    local reward = CalculateTaxiReward(distance, config.rewards.baseAmount, config.rewards.perMeterRate)
    return true, nil, reward
end

function CalculateTaxiReward(distance, baseReward, perMeterRate)
    local reward = baseReward + math.floor(distance * perMeterRate)
    reward = math.max(reward, baseReward)
    reward = math.min(reward, baseReward * 3)
    return reward
end

function CalculateBonusReward(baseReward, jobCount)
    local bonusMultiplier = 1.0
    
    if jobCount >= 5 and jobCount < 10 then
        bonusMultiplier = 1.1
    elseif jobCount >= 10 and jobCount < 20 then
        bonusMultiplier = 1.2
    elseif jobCount >= 20 then
        bonusMultiplier = 1.3
    end
    
    return math.floor(baseReward * bonusMultiplier)
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

RegisterNetEvent('kt_interim:applyBonus', function(source, jobType, baseReward)
    local identifier = ServerUtils.GetIdentifier(source)
    if not identifier then return end
    
    local hasBonus, jobCount = CheckPlayerBonus(identifier, jobType)
    
    if hasBonus then
        local bonusAmount = math.floor(baseReward * 0.15)
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
    if not identifier then return end
    
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
        if not identifier then return end
        
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
        if identifier then
            ServerUtils.BanPlayer(identifier, 'Trop de pénalités (triche suspectée)', 3600)
            DropPlayer(source, 'Vous avez été temporairement banni du système d\'intérim pour comportement suspect')
        end
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

AddEventHandler('playerDropped', function()
    local source = source
    if playerPenalties[source] then
        playerPenalties[source] = nil
    end
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
    
    if #jobTypes == 0 then
        print('^3[KT_INTERIM]^7 Warning: No enabled jobs found for daily quests')
        return quests
    end
    
    for i = 1, math.min(5, #jobTypes) do
        local jobType = ServerUtils.RandomChoice(jobTypes)
        local requiredAmount = math.random(3, 5)
        
        table.insert(quests, {
            jobType = jobType,
            requiredAmount = requiredAmount,
            reward = math.floor(Config.Jobs[jobType].salary * requiredAmount * 1.2),
            completedBy = {}
        })
    end
    
    return quests
end

function InitializeDailyQuests()
    dailyQuests = GenerateDailyQuests()
    print('^2[KT_INTERIM]^7 Daily quests initialized (' .. #dailyQuests .. ' quests)')
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

CreateThread(function()
    Wait(2000)
    InitializeDailyQuests()
    
    while true do
        Wait(86400000) -- 24h
        InitializeDailyQuests()
        print('^2[KT_INTERIM]^7 Daily quests reset')
    end
end)

RegisterNetEvent('kt_interim:updateQuest', function(source, jobType)
    local identifier = ServerUtils.GetIdentifier(source)
    if not identifier then return end
    
    local completed, rewardOrProgress, required = UpdateDailyQuest(identifier, jobType)
    
    if completed then
        ServerUtils.AddMoney(source, rewardOrProgress)
        ServerUtils.Notify(source, '🏆 Quête journalière complétée ! Bonus: ' .. ServerUtils.FormatMoney(rewardOrProgress), 'success')
        ServerUtils.Log(string.format('Daily quest completed: %s | Reward: $%d', jobType, rewardOrProgress), 'QUEST', source)
    elseif rewardOrProgress then
        ServerUtils.Notify(source, string.format('Progression quête: %d/%d', rewardOrProgress, required), 'info')
    end
end)

RegisterCommand('interimquests', function(source)
    if source > 0 then
        local identifier = ServerUtils.GetIdentifier(source)
        if not identifier then return end
        
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
            
            local status = progress >= quest.requiredAmount 
                and '✅ Complétée' 
                or string.format('⏳ %d/%d', progress, quest.requiredAmount)
            
            TriggerClientEvent('chat:addMessage', source, {
                args = {'', string.format('%d. %s: %s | Récompense: $%d', 
                    i, quest.jobType, status, quest.reward)}
            })
        end
    end
end, false)

local jobDemand = {}

function UpdateJobDemand(jobType)
    if not jobDemand[jobType] then
        jobDemand[jobType] = {
            completions = 0,
            lastReset = os.time()
        }
    end
    
    jobDemand[jobType].completions = jobDemand[jobType].completions + 1
    
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
    
    if completions < 5 then
        multiplier = 1.3      -- +30% si peu de completions
    elseif completions < 10 then
        multiplier = 1.15     -- +15%
    elseif completions < 20 then
        multiplier = 1.0      -- Normal
    else
        multiplier = 0.85     -- -15% si trop de completions
    end
    
    return math.floor(baseReward * multiplier)
end

RegisterNetEvent('kt_interim:getDynamicReward', function(jobType, baseReward)
    local source = source
    
    UpdateJobDemand(jobType)
    local dynamicReward = GetDynamicReward(jobType, baseReward)
    
    if dynamicReward > baseReward then
        local percent = math.floor(((dynamicReward - baseReward) / baseReward) * 100)
        ServerUtils.Notify(source, '📈 Demande élevée ! Récompense augmentée: +' .. percent .. '%', 'success')
    elseif dynamicReward < baseReward then
        local percent = math.floor(((baseReward - dynamicReward) / baseReward) * 100)
        ServerUtils.Notify(source, '📉 Forte affluence. Récompense réduite: -' .. percent .. '%', 'warning')
    end
    
    TriggerClientEvent('kt_interim:receiveDynamicReward', source, dynamicReward)
end)


exports('ValidateJobCompletion', ValidateJobCompletion)
exports('ValidateConstructionJob', ValidateConstructionJob)
exports('ValidateCleaningJob', ValidateCleaningJob)
exports('ValidateDeliveryJob', ValidateDeliveryJob)
exports('ValidateShopLogisticsJob', ValidateShopLogisticsJob)
exports('ValidateTaxiJob', ValidateTaxiJob)
exports('ValidateTruckerJob', ValidateTruckerJob)
exports('GetPlayerReputation', GetPlayerReputation)
exports('GetDynamicReward', GetDynamicReward)
exports('CheckPenalty', CheckPenalty)
exports('AddPenalty', AddPenalty)

print('^2[KT_INTERIM]^7 Jobs validation system initialized')