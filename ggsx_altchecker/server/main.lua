--Performs http operation if passed in correctly...
local GetAlternativeAccounts = function(type, id, cb)
    if type == "steam" then
        PerformHttpRequest(string.format('https://ggs.sx/api/v3/fivem/association/steam/%s?api_token=%s', id, Config.GGSX_API_KEY), cb, "GET")
    elseif type == "discord" then
        PerformHttpRequest(string.format('https://ggs.sx/api/v3/fivem/association/discord/%s?api_token=%s', id, Config.GGSX_API_KEY), cb, "GET")
    elseif type == "gtav" then 
        PerformHttpRequest(string.format('https://ggs.sx/api/v3/fivem/association/gtav/%s?api_token=%s', id, Config.GGSX_API_KEY), cb, "GET")
    end
end

local CheckBanList = function(player, licenses, cb)
    --SELECT * FROM bans WHERE LIKE bans.license IN ('')
    local stringBuilder = ""

    for k, v in pairs(licenses) do
        stringBuilder = string.format("%s'license:%s',", stringBuilder, v)
    end

    --Lets also add our current id to the array for a meme
    stringBuilder = stringBuilder .. "'license:"..ExtractIdentifiers(player).license:gsub("license:", "").."'"
  
    exports.oxmysql:execute('SELECT * FROM bans WHERE bans.license IN ('..stringBuilder..')', { }, function(results)
        if results[1] ~= nil then
            -- Banned alts? wow. lets ban current identifier and say get fucked.
            print('[GGS.SX] Banning user..')
            cb(results)
        else
            print('[GGS.SX] User is ok to proceed')
        end
    end)    
end

--Extracts identifiers.
function ExtractIdentifiers(src)
    local identifiers = {
        steam = "",
        ip = "",
        discord = "",
        license = "",
        xbl = "",
        live = ""
    }
  
    --Loop over all identifiers
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
  
        --Convert it to a nice table.
        if string.find(id, "steam") then
            identifiers.steam = id
        elseif string.find(id, "ip") then
            identifiers.ip = id
        elseif string.find(id, "discord") then
            identifiers.discord = id
        elseif string.find(id, "license") then
            identifiers.license = id
        elseif string.find(id, "xbl") then
            identifiers.xbl = id
        elseif string.find(id, "live") then
            identifiers.live = id
        end
    end
  
    return identifiers
  end

----- EVENTS ------
local function OnPlayerConnecting(name, setKickReason, deferrals)
    deferrals.defer()
    local src = source
    local identifier = ExtractIdentifiers(source).discord:gsub("discord:", "");

    deferrals.update(string.format("[%s] -> Hi %s, We're checking if you have alt accounts banned.", Config.JoinMessage, name))
    
    GetAlternativeAccounts(src, "discord", identifier, function(err, responseText, headers)
        local data = json.decode(responseText) -- decode json into data object
        print(string.format('+ [GGS.SX] Identifier being read... %s', identifier))
        if data[1] ~= nil then
            local gtavLicenses = json.decode(data[1].gta_v_license)
            CheckBanList(gtavLicenses, function(results)
                Wait(0)
                deferrals.done(string.format("[%s] -> You have an alternative account which is banned from this server.. Bye bye!", Config.JoinMessage))
            end)    
        end
    end)

    deferrals.done()
end

AddEventHandler("playerConnecting", OnPlayerConnecting)