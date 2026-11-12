# speedradar - Fartkontrols Udstyr

## Items til ox_inventory/data/items.lua

```lua
['fartkontrol_udstyr'] = {
    label = 'Fartkontrols Udstyr',
    weight = 2500,
    stack = false,
    close = true,
    consume = 0,
    image = 'fartkontrol_udstyr.png',
    client = {
        export = 'speedradar.useFartkontrol'
    }
},

['fartkontrol_udskrift'] = {
    label = 'Fartkontrol Udskrift',
    weight = 50,
    stack = false,
    close = true,
    consume = 0,
    image = 'fartkontrol_note.png',
    client = {
        export = 'speedradar.usePrintout'
    },
    buttons = {
        {
            label = 'Ødelæg udskrift',
            action = function(slot)
                TriggerServerEvent('speedradar:destroyPrintout', slot)
            end
        }
    }
},
```

## Brug

- Brug `Fartkontrols Udstyr` i inventory for at placere stativet.
- Brug øjet på stativet for at åbne fartkontrol, udskrive rapport eller pakke udstyret sammen.
- Venstreklik i kameraet gemmer fartmåling.
- Brug `Fartkontrol Udskrift` for at læse rapporten.
- Højreklik på `Fartkontrol Udskrift` i ox_inventory og vælg `Ødelæg udskrift` for at ødelægge papiret.

## Restart

```cfg
restart ox_inventory
restart speedradar
```

Hvis du kun har udskiftet speedradar-filerne og ikke ændret items.lua, er det nok med:

```cfg
restart speedradar
```
