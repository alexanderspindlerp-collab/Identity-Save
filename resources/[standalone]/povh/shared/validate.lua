POVH = POVH or {}

local function trim(v)
    return tostring(v or ''):gsub('^%s*(.-)%s*$', '%1')
end

local function normalizeModel(name)
    return string.lower(trim(name))
end

function POVH.modelInList(modelHash, displayName, list)
    if not list then return false end
    displayName = normalizeModel(displayName)
    if displayName ~= '' and list[displayName] == true then return true end
    if modelHash then
        for modelName, enabled in pairs(list) do
            if enabled and GetHashKey(modelName) == modelHash then return true end
        end
    end
    return false
end

function POVH.modelService(modelHash, displayName, cfg)
    cfg = cfg or Config or {}
    if POVH.modelInList(modelHash, displayName, cfg.EMSVehicleModels) then return 'ems' end
    if POVH.modelInList(modelHash, displayName, cfg.PoliceVehicleModels) then return 'police' end
    return nil
end

function POVH.unitService(unit, cfg)
    cfg = cfg or Config or {}
    local service = normalizeModel(unit and (unit.service or unit.kind) or '')
    if service == 'ems' or service == 'ambulance' then return 'ems' end
    if service == 'police' or service == 'politi' then return 'police' end

    local model = normalizeModel(unit and unit.model or '')
    if POVH.modelInList(nil, model, cfg.EMSVehicleModels) then return 'ems' end
    if POVH.modelInList(nil, model, cfg.PoliceVehicleModels) then return 'police' end
    return nil
end

function POVH.isEmergencyUnit(unit, cfg)
    if not unit then return false end
    cfg = cfg or Config or {}
    local service = POVH.unitService(unit, cfg)
    if not service then return false end

    local model = normalizeModel(unit.model or '')
    if service == 'ems' then
        return POVH.modelInList(nil, model, cfg.EMSVehicleModels)
    end
    return POVH.modelInList(nil, model, cfg.PoliceVehicleModels)
end

function POVH.filterFleetUnits(units, cfg)
    cfg = cfg or Config or {}
    local filtered = {}
    for _, unit in ipairs(units or {}) do
        if POVH.isEmergencyUnit(unit, cfg) then
            unit.service = POVH.unitService(unit, cfg)
            filtered[#filtered + 1] = unit
        end
    end
    return filtered
end

function POVH.validateFleetPing(data, jobName, cfg)
    cfg = cfg or Config or {}
    data = data or {}
    jobName = tostring(jobName or '')

    local jobService
    if cfg.EMSJobs and cfg.EMSJobs[jobName] then jobService = 'ems' end
    if cfg.PoliceJobs and cfg.PoliceJobs[jobName] then jobService = 'police' end
    if not jobService then return false end

    local pingService = normalizeModel(data.service or jobService)
    if pingService == 'ambulance' then pingService = 'ems' end
    if pingService ~= jobService then return false end

    local model = normalizeModel(data.model or '')
    if jobService == 'ems' then
        return POVH.modelInList(nil, model, cfg.EMSVehicleModels)
    end
    return POVH.modelInList(nil, model, cfg.PoliceVehicleModels)
end
