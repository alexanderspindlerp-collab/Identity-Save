# ya_interactions

Standalone F1 interaction-menu til FiveM (hold F1 for at åbne, slip for at lukke).

## Installation

1. Læg mappen `ya_interactions` i `resources/[standalone]`.
2. Tilføj i `server.cfg`:

```cfg
ensure ya_interactions
```

Den skal startes før scripts, der vil registrere interactions.

## Eksempel fra et andet client script

```lua
exports['ya_interactions']:registerInteraction({
    id = 'garage_san_andreas',
    label = 'Garage',
    coords = vec3(216.77, -788.77, 30.82),
    radius = 5.0,
    options = {
        {
            id = 'rent_vehicle',
            label = 'Lej køretøj',
            icon = 'car',
            event = 'my_garage:rent'
        },
        {
            id = 'open_garage',
            label = 'Åben Garage',
            icon = 'car',
            event = 'my_garage:open',
            onFootOnly = true
        },
        {
            id = 'park_vehicle',
            label = 'Parker køretøj',
            icon = 'car',
            event = 'my_garage:park',
            vehicleOnly = true
        }
    }
})
```

## Option fields

- `id`: unikt navn for knappen
- `label`: tekst i hjulet
- `icon`: `car`, `door` eller `briefcase`
- `event`: client event der skal trigges
- `serverEvent`: server event der skal trigges
- `callback`: Lua callback hvis det registreres direkte i samme resource
- `vehicleOnly`: knappen virker kun i køretøj
- `onFootOnly`: knappen virker kun udenfor køretøj
- `canInteract`: funktion der kan returnere true/false
