Config = {}

Config.AdminGroups = { 'admin', 'superadmin', 'owner' }

Config.Dealership = {
    MinNameLength = 3,
    MaxNameLength = 48,
    MaxMembers = 30,
    DefaultColor = '#1e3a5f',
}

Config.Plate = {
    Letters = 3,
    Numbers = 3,
    UseSpace = true,
}

Config.VehicleImageBase = 'https://docs.fivem.net/vehicles'

Config.Dealership.StartingBalance = 0

Config.Currency = 'DKK'
Config.VatRate = 0.25
Config.CompanyCvr = '12345678'

Config.DefaultRoles = {
    {
        key = 'owner',
        name = 'Ejer',
        isDefault = false,
        sortOrder = 1,
        permissions = {},
    },
    {
        key = 'manager',
        name = 'Manager',
        isDefault = false,
        sortOrder = 2,
        permissions = {
            view_dashboard = true,
            manage_members = true,
            manage_stock = true,
            sell_vehicles = true,
        },
    },
    {
        key = 'seller',
        name = 'Sælger',
        isDefault = true,
        sortOrder = 3,
        permissions = {
            view_dashboard = true,
            manage_stock = true,
            sell_vehicles = true,
        },
    },
}

Config.PermissionsCatalog = {
    { key = 'view_dashboard', label = 'Se overblik' },
    { key = 'manage_members', label = 'Administrer medlemmer' },
    { key = 'manage_roles', label = 'Administrer roller' },
    { key = 'manage_stock', label = 'Administrer lager' },
    { key = 'sell_vehicles', label = 'Sælg køretøjer' },
}
