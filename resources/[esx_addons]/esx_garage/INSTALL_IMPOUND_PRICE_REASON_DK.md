# Police impound med pris og beskrivelse

1. Importér `police_impound_price_reason.sql` i databasen.
2. Sørg for start-rækkefølge:

```cfg
ensure ox_lib
ensure ox_target
ensure esx_garage
ensure esx_policejob
ensure ya_interactions
```

3. Restart serveren eller disse resources.

Politiet kan nu bruge øjet på et køretøj og vælge **Beslaglæg køretøj**.
Der åbner en popup med pris i DKK og beskrivelse.
