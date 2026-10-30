local ESX = exports['es_extended']:getSharedObject()

local NumberCharset = {}
local Charset = {}

for i = 48, 57 do table.insert(NumberCharset, string.char(i)) end
for i = 65, 90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

local function getRandomNumber(length)
    if length <= 0 then return '' end
    return getRandomNumber(length - 1) .. NumberCharset[math.random(1, #NumberCharset)]
end

local function getRandomLetter(length)
    if length <= 0 then return '' end
    return getRandomLetter(length - 1) .. Charset[math.random(1, #Charset)]
end

local function isPlateTaken(plate)
    local p = promise.new()
    ESX.TriggerServerCallback('ya_cardealer:isPlateTaken', function(taken)
        p:resolve(taken == true)
    end, plate)
    return Citizen.Await(p)
end

function GeneratePlate()
    math.randomseed(GetGameTimer())
    local cfg = Config.Plate or {}
    local letters = tonumber(cfg.Letters) or 3
    local numbers = tonumber(cfg.Numbers) or 3
    local space = cfg.UseSpace ~= false and ' ' or ''
    local generatedPlate = string.upper(getRandomLetter(letters) .. space .. getRandomNumber(numbers))
    if isPlateTaken(generatedPlate) then
        return GeneratePlate()
    end
    return generatedPlate
end

exports('GeneratePlate', GeneratePlate)
