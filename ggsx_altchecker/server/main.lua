--Performs http operation if passed in correctly...
local GetAlternativeAccounts = function(type, id, cb)
    print('reached')
    if type == "discord" then
        PerformHttpRequest(string.format('https://ggs.sx/api/v3/fivem/association/discord/%s?api_token=%s', id, Config.GGSX_API_KEY), cb, "GET")
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
    
    GetAlternativeAccounts("discord", "238235489432371201", function(err, responseText, headers)
        local data = json.decode(responseText) -- decode json into data object
        print(string.format('+ [GGS.SX] Identifier being read... %s', identifier))
        if data[1] ~= nil then
            local gtavLicenses = json.decode(data[1].gta_v_license)
            CheckBanList(src, gtavLicenses, function(results)
                Wait(0)
                DCLog(src, "GGS.SX - Banned Alt Detected", 'A banned alt account has been detected.. user cant join :)')
                deferrals.done(string.format("[%s] -> You have an alternative account which is banned from this server.. Bye bye!", Config.JoinMessage))
            end)    
        end
    end)

    deferrals.done()
end

--Discord shit
-- DISCORD LOGS
RegisterNetEvent("ggsx:dc_log")
AddEventHandler("ggsx:dc_log", function(user, title, desc)
    local author_url = "https://winaero.com/blog/wp-content/uploads/2018/08/Windows-10-user-icon-big.png"
    local discord, steamid
    for i, identifier in pairs(GetPlayerIdentifiers(user)) do
        if string.sub(identifier, 1, #"steam:") == "steam:" then
            local done
            local steamhex = string.sub(identifier, #"steam:" + 1, #identifier)
            steamid = tonumber(steamhex, 16)

            PerformHttpRequest("https://steamcommunity.com/profiles/" .. steamid, function(err, text, headers)
                if text then
                    imageurl = text:match('<meta name="twitter:image" content="(.-)"')
                    if imageurl then
                        author_url = imageurl
                    end
                end

                done = true
            end, "GET")

            while not done do
                Wait(250)
            end
        elseif string.sub(identifier, 1, #"discord:") == "discord:" then
            discord = "<@" .. string.sub(identifier, #"discord:" + 1, #identifier) .. ">"
        end
    end

    if discord and desc then desc = desc .. "\n" .. "Discord: " .. discord end
    if steamid and desc then desc = desc .. "\n" .. "[Steam profile](" .. "https://steamcommunity.com/profiles/" .. steamid .. ")" end

    PerformHttpRequest(Config.DiscordWebhook, function(err, text, headers) end, "POST", json.encode({
        username = "GGS.SX Alt Detector",
        embeds = {{
            ["color"] = color,
            ["author"] = {
                ["name"] = ".",
                ["icon_url"] = author_url
            },
            ["title"] = title or "No title",
            ["description"] = desc or "No description",
            ["timestamp"] = os.date('!%Y-%m-%dT%H:%M:%S.000Z'),
            ["footer"] = {
                ["text"] = GetCurrentResourceName(),
            },
        }},
        avatar_url = "https://winaero.com/blog/wp-content/uploads/2018/08/Windows-10-user-icon-big.png"
    }), {["Content-Type"] = "application/json"})
end)

DCLog = function(user, title, desc)
    if GetPlayerName(user) then
        TriggerEvent("ggsx:dc_log", user, title, desc)
    end
end


AddEventHandler("playerConnecting", OnPlayerConnecting)