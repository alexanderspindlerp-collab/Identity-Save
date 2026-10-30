local recent = {}

local function dbg(...)
    if Config.Debug then print('[san_dispatch:server]', ...) end
end

local function validNumber(n)
    n = tonumber(n)
    return n and n == n and math.abs(n) < 100000.0
end

local function sanitize(data)
    if type(data) ~= 'table' then return nil end
    local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
    if not validNumber(x) or not validNumber(y) or not validNumber(z) then return nil end

    local out = {
        type = tostring(data.type or 'unknown'):sub(1, 40),
        title = tostring(data.title or 'Dispatch'):sub(1, 80),
        description = tostring(data.description or ''):sub(1, 300),
        street = tostring(data.street or 'Ukendt lokation'):sub(1, 80),
        x = x, y = y, z = z,
        priority = math.max(1, math.min(3, tonumber(data.priority or 3) or 3)),
        witnessCount = math.max(0, math.min(Config.MaxWitnesses or 5, tonumber(data.witnessCount or 0) or 0)),
        metadata = type(data.metadata) == 'table' and data.metadata or {}
    }

    -- No huge payloads. Photos must not be base64 in live dispatch.
    if out.metadata then
        out.metadata.photoBase64 = nil
        out.metadata.imageBase64 = nil
        out.metadata.screenshotBase64 = nil
        if type(out.metadata.witnessStatements) == 'table' then
            local clean = {}
            for i=1, math.min(Config.MaxWitnesses or 5, #out.metadata.witnessStatements) do
                clean[#clean+1] = tostring(out.metadata.witnessStatements[i]):sub(1, 180)
            end
            out.metadata.witnessStatements = clean
        end
    end

    return out
end

local function serverAreaKey(data)
    local g = tonumber(Config.AreaGrid or 180.0) or 180.0
    return ('%s:%s:%s'):format(data.type, math.floor(data.x / g), math.floor(data.y / g))
end

RegisterNetEvent('san_dispatch:report', function(data)
    local src = source
    local call = sanitize(data)
    if not call then
        dbg('invalid report from', src)
        return
    end

    local key = serverAreaKey(call)
    local cd = tonumber((Config.Cooldown or {})[call.type] or 30000) or 30000
    local t = GetGameTimer()
    if recent[key] and (t - recent[key]) < math.floor(cd * 0.45) then
        dbg('server cooldown', key)
        return
    end
    recent[key] = t

    dbg('forwarding', call.type, call.title, call.street)
    TriggerEvent(Config.MdtEvent or 'san_mdt:autoDispatchCall', call)
end)

if Config.EnableTestCommands then
    RegisterCommand('testdispatchserver', function(source)
        if source <= 0 then print('Brug ingame.'); return end
        local ped = GetPlayerPed(source)
        local c = GetEntityCoords(ped)
        local data = {
            type = 'shots_fired',
            title = 'TEST server dispatch',
            description = 'Server test af san_dispatch -> san_mdt',
            street = 'Test lokation',
            x = c.x, y = c.y, z = c.z,
            priority = 1,
            witnessCount = 1,
            metadata = {
                witnessStatements = {'TEST: san_dispatch server sender korrekt til MDT.'},
                witnesses = { total = 1 },
                noPhotoText = 'Intet foto modtaget fra vidne'
            }
        }
        TriggerEvent(Config.MdtEvent or 'san_mdt:autoDispatchCall', data)
        print('[san_dispatch] /testdispatchserver sendt til MDT')
    end, false)
end
