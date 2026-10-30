# ya_idcard installation

## 1. Start resources i denne rækkefølge
```cfg
ensure oxmysql
ensure ox_lib
ensure es_extended
ensure ox_inventory
ensure ya_idcard
```

## 2. Item i ox_inventory/data/items.lua
VIGTIGT: `export = 'ya_idcard.useIdCard'` skal være med.

```lua
['id_card'] = {
    label = 'ID Kort',
    weight = 50,
    stack = false,
    close = true,
    consume = 0,
    description = 'San Andreas ID Kort',
    client = {
        export = 'ya_idcard.useIdCard',
        image = 'id_card.png'
    }
},
```

## 3. Restart
```cfg
restart ox_inventory
restart ya_idcard
```

## 4. Test
Brug kommandoen:
```txt
/testidcard
```
Hvis kortet kommer frem med /testidcard, men ikke ved Use i inventory, mangler `client.export` i items.lua.

## 5. Giv item
```txt
/giveitem 1 id_card 1
```
eller:
```txt
/giveidcard
```


## License fix
Kategori B/A/C læses direkte fra `user_licenses`. Hvis gamle ID-kort stadig viser forkert, fjern det gamle item og giv et nyt.
