ServerUtils = {}

function ServerUtils.Log(message, logType, playerSource)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local logMessage = string.format('[%s] [KT_INTERIM] [%s] %s', timestamp, logType or 'INFO', message)
    

    print(logMessage)
    
    if playerSource then
        local playerName = GetPlayerName(playerSource)
        local identifier = ServerUtils.GetIdentifier(playerSource)
        logMessage = logMessage .. string.format(' | Player: %s (%s)', playerName, identifier)
    end
    
    -- TriggerEvent('yourDiscordLog', {
    --     title = 'Interim Log',
    --     message = logMessage,
    --     color = logType == 'ERROR' and 16711680 or logType == 'WARN' and 16776960 or 65280
    -- })
end

function ServerUtils.GetIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    
    for _, identifier in ipairs(identifiers) do
        if string.find(identifier, 'license:') then
            return identifier
        end
    end
    
    return nil
end

function ServerUtils.GetPlayerName(source)
    return GetPlayerName(source) or 'Unknown'
end

function ServerUtils.HasItem(source, item, amount)
    local count = exports.ox_inventory:Search(source, 'count', item)
    return count >= (amount or 1)
end

function ServerUtils.GetItemCount(source, item)
    return exports.ox_inventory:Search(source, 'count', item) or 0
end

function ServerUtils.AddItem(source, item, amount, metadata)
    local success = exports.ox_inventory:AddItem(source, item, amount or 1, metadata)
    
    if success then
        ServerUtils.Log(string.format('Added %dx %s to player', amount or 1, item), 'ITEM', source)
        return true
    else
        ServerUtils.Log(string.format('Failed to add %dx %s to player', amount or 1, item), 'ERROR', source)
        return false
    end
end

function ServerUtils.RemoveItem(source, item, amount, metadata)
    local success = exports.ox_inventory:RemoveItem(source, item, amount or 1, metadata)
    
    if success then
        ServerUtils.Log(string.format('Removed %dx %s from player', amount or 1, item), 'ITEM', source)
        return true
    else
        ServerUtils.Log(string.format('Failed to remove %dx %s from player', amount or 1, item), 'ERROR', source)
        return false
    end
end

function ServerUtils.CanCarryItem(source, item, amount)
    return exports.ox_inventory:CanCarryItem(source, item, amount or 1)
end

function ServerUtils.AddMoney(source, amount, moneyType)
    moneyType = moneyType or 'money'
    
    if GetResourceState('es_extended') == 'started' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(amount)
            ServerUtils.Log(string.format('Added $%d to player', amount), 'MONEY', source)
            return true
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.AddMoney('cash', amount)
            ServerUtils.Log(string.format('Added $%d to player', amount), 'MONEY', source)
            return true
        end
    end
    
    local success = exports.ox_inventory:AddItem(source, 'money', amount)
    if success then
        ServerUtils.Log(string.format('Added $%d to player via ox_inventory', amount), 'MONEY', source)
    end
    
    return success or false
end

function ServerUtils.RemoveMoney(source, amount, moneyType)
    moneyType = moneyType or 'money'
    
    if GetResourceState('es_extended') == 'started' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.removeMoney(amount)
            ServerUtils.Log(string.format('Removed $%d from player', amount), 'MONEY', source)
            return true
        end
    end
    
    if GetResourceState('qb-core') == 'started' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            Player.Functions.RemoveMoney('cash', amount)
            ServerUtils.Log(string.format('Removed $%d from player', amount), 'MONEY', source)
            return true
        end
    end
    
    local success = exports.ox_inventory:RemoveItem(source, 'money', amount)
    if success then
        ServerUtils.Log(string.format('Removed $%d from player via ox_inventory', amount), 'MONEY', source)
    end
    
    return success or false
end

function ServerUtils.GetMoney(source, moneyType)
    moneyType = moneyType or 'money'
    
    if GetResourceState('es_extended') == 'started' then
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.getMoney()
        end
    end
    
    if GetResourceState('qb-core') == 'started' then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            return Player.Functions.GetMoney('cash')
        end
    end
    
    return ServerUtils.GetItemCount(source, 'money')
end

function ServerUtils.PlayerExists(source)
    return GetPlayerName(source) ~= nil
end

function ServerUtils.GetDistance(coords1, coords2)
    if type(coords1) == "vector3" and type(coords2) == "vector3" then
        return #(coords1 - coords2)
    end
    return math.sqrt(
        (coords2.x - coords1.x)^2 +
        (coords2.y - coords1.y)^2 +
        (coords2.z - coords1.z)^2
    )
end

function ServerUtils.IsPlayerNearCoords(source, coords, maxDistance)
    local playerPed = GetPlayerPed(source)
    if not DoesEntityExist(playerPed) then
        return false
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    local distance = ServerUtils.GetDistance(playerCoords, coords)
    
    return distance <= maxDistance
end

function ServerUtils.FormatMoney(amount)
    local formatted = tostring(amount)
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return "$" .. formatted
end

function ServerUtils.GenerateUniqueId()
    local charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local id = ""
    for i = 1, 8 do
        local rand = math.random(1, #charset)
        id = id .. charset:sub(rand, rand)
    end
    return id .. "-" .. os.time()
end

function ServerUtils.SaveJobData(identifier, jobType, data)
    if GetResourceState('oxmysql') ~= 'started' then
        ServerUtils.Log('oxmysql not found, cannot save job data', 'WARN')
        return false
    end
    
    MySQL.Async.execute([[
        INSERT INTO kt_interim (identifier, job_type, data, completed_at)
        VALUES (@identifier, @job_type, @data, NOW())
        ON DUPLICATE KEY UPDATE data = @data, completed_at = NOW()
    ]], {
        ['@identifier'] = identifier,
        ['@job_type'] = jobType,
        ['@data'] = json.encode(data)
    })
    
    return true
end

function ServerUtils.GetJobData(identifier, jobType, callback)
    if GetResourceState('oxmysql') ~= 'started' then
        ServerUtils.Log('oxmysql not found, cannot get job data', 'WARN')
        if callback then callback(nil) end
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT * FROM kt_interim
        WHERE identifier = @identifier AND job_type = @job_type
        ORDER BY completed_at DESC LIMIT 1
    ]], {
        ['@identifier'] = identifier,
        ['@job_type'] = jobType
    }, function(result)
        if callback then
            if result and result[1] then
                callback(json.decode(result[1].data))
            else
                callback(nil)
            end
        end
    end)
end

function ServerUtils.GetPlayerStats(identifier, callback)
    if GetResourceState('oxmysql') ~= 'started' then
        ServerUtils.Log('oxmysql not found, cannot get player stats', 'WARN')
        if callback then callback(nil) end
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT job_type, COUNT(*) as count, SUM(JSON_EXTRACT(data, '$.reward')) as total_earned
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

function ServerUtils.SendDiscordWebhook(webhookUrl, title, message, color)
    if not webhookUrl or webhookUrl == '' then
        return
    end
    
    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color or 65280,
            ["footer"] = {
                ["text"] = "Interim System | " .. os.date('%Y-%m-%d %H:%M:%S')
            }
        }
    }
    
    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({
        username = 'Interim System',
        embeds = embed
    }), {['Content-Type'] = 'application/json'})
end

local playerJobCooldowns = {}

function ServerUtils.CheckJobCooldown(source, jobType, cooldownTime)
    cooldownTime = cooldownTime or 30000 -- 30 secondes par défaut
    
    if not playerJobCooldowns[source] then
        playerJobCooldowns[source] = {}
    end
    
    local lastJobTime = playerJobCooldowns[source][jobType]
    local currentTime = GetGameTimer()
    
    if lastJobTime and (currentTime - lastJobTime) < cooldownTime then
        ServerUtils.Log(string.format('Player tried to complete job too quickly: %s', jobType), 'WARN', source)
        return false
    end
    
    playerJobCooldowns[source][jobType] = currentTime
    return true
end

AddEventHandler('playerDropped', function()
    local source = source
    if playerJobCooldowns[source] then
        playerJobCooldowns[source] = nil
    end
end)

local bannedPlayers = {} 

function ServerUtils.IsPlayerBanned(identifier)
    return bannedPlayers[identifier] ~= nil
end

function ServerUtils.BanPlayer(identifier, reason, duration)
    bannedPlayers[identifier] = {
        reason = reason,
        bannedAt = os.time(),
        duration = duration or 0 -- 0 = permanent
    }
    
    ServerUtils.Log(string.format('Player banned: %s, Reason: %s', identifier, reason), 'BAN')
    
end

function ServerUtils.UnbanPlayer(identifier)
    if bannedPlayers[identifier] then
        bannedPlayers[identifier] = nil
        ServerUtils.Log(string.format('Player unbanned: %s', identifier), 'UNBAN')
        return true
    end
    return false
end

function ServerUtils.Round(num, decimals)
    local mult = 10^(decimals or 0)
    return math.floor(num * mult + 0.5) / mult
end

function ServerUtils.RandomChoice(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

function ServerUtils.ValidateCoords(coords)
    if type(coords) ~= "table" then return false end
    if not coords.x or not coords.y or not coords.z then return false end
    if type(coords.x) ~= "number" or type(coords.y) ~= "number" or type(coords.z) ~= "number" then return false end
    return true
end

function ServerUtils.Notify(source, message, type, duration)
    TriggerClientEvent('kt_interim:notify', source, message, type, duration)
end

return ServerUtils