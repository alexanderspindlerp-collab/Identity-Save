# esx_garage F3 version

Dette er en ren modificeret version af den originale ESX Legacy `esx_garage`.

Ændringer:

- Bruger `ox_lib` TextUI i højre side.
- Viser `[F3] Tryk for at åbne garage`, når du står tæt på en garage.
- Viser `[F3] Tryk for at parkere køretøjet`, når du sidder i bil ved en garage.
- Viser `[F3] Tryk for at åbne impound`, når du står ved impound.
- Interaktionsradius er sat til `6.0`, så man ikke skal ramme en lille 1-meter marker præcist.
- Ingen jobgarage-logik er tilføjet. Den bruger stadig original garage-opdeling fra `Config.Garages`.

## Installation

1. Stop serveren.
2. Tag backup af din originale:

```text
C:\Users\User\Desktop\txData\ESXLegacy_1054CE.base\resources\[esx_addons]\esx_garage
```

3. Erstat den gamle mappe med denne mappe.
4. Når den ligger i serveren, skal den hedde:

```text
esx_garage
```

5. Start serveren igen.

## Kræver

`ox_lib` skal starte før `esx_garage`. Din server har allerede `ox_lib` i `[standalone]`, og `server.cfg` starter `[standalone]` før `[esx_addons]`, så det passer.
