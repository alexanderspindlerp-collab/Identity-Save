exports('FilterFleetUnits', function(units)
    return POVH.filterFleetUnits(units, Config)
end)

exports('ValidateFleetPing', function(data, jobName)
    return POVH.validateFleetPing(data, jobName, Config)
end)

exports('ModelService', function(modelHash, displayName)
    return POVH.modelService(modelHash, displayName, Config)
end)

exports('IsEmergencyUnit', function(unit)
    return POVH.isEmergencyUnit(unit, Config)
end)
