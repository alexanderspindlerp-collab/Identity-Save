# Identity – custom ESX Legacy-template

Klar til repository `alexanderspindlerp-collab/Identity-Save`, branch `main`.

## Upload nu

1. Pak ZIP-filen ud.
2. Åbn `Identity-GitHub-Klar` på computeren.
3. Upload indholdet til roden af dit GitHub-repository. Erstat de eksisterende `recipe.yaml`, `server.cfg` og eventuelt `README.md` med disse versioner.
4. Sørg for, at `config`-mappen også bliver uploadet. Upload selve indholdet – ikke ZIP-filen og ikke en ekstra overordnet mappe.
5. Gem med **Commit changes** på `main`.

GitHub skal herefter vise `recipe.yaml`, `server.cfg`, `README.md`, `dependency-lock.json` og mappen `config` direkte i roden.

## Link til txAdmin

https://raw.githubusercontent.com/alexanderspindlerp-collab/Identity-Save/main/recipe.yaml

Vælg en remote/custom recipe i txAdmin, og indsæt linket. Brug opdaterede FXServer-artifacts, mindst build **12913**, samt en ny, tom database. Indtast databaseoplysninger og en ny Cfx-servernøgle i txAdmin.

## Hvad bliver installeret automatisk?

- ESX Legacy 1.13.5 med karakteroprettelse og udvalgte supportressourcer.
- oxmysql, ox_lib med cfxlua-require, ox_target og ox_inventory.
- pma-voice, ox_fuel og PolyZone.
- Din Identity-serverkonfiguration og tomme custom-startkonfiguration.

De faktiske filer hentes fra officielle kilder med de versioner/commits, der er registreret i `dependency-lock.json`. Den tidligere store ZIP-pakke er ikke nødvendig for denne baseinstallation. SQL ligger i det officielle ESX-arkiv og importeres af recipen; du skal ikke uploade SQL separat til denne version.

## Dine custom scripts

Denne upload installerer basen og dens gratis afhængigheder. De købte scripts, YA-pakken, MLO'er og andre Drive-filer er ikke med i denne lille upload. De skal installeres som komplette originale ressourcer med deres relevante SQL/items og licenser.

Brug den tidligere leverede `Identity-ESX-Setup.zip` til konfigurationsrettelserne, Lation/san_dispatch-adapteren og oversigten over manglende filer. Tilføj derefter de relevante startlinjer i `config/custom.cfg`. Rækkefølgen er vist i `config/custom.example.cfg`; eksempel-linjerne er slået fra, indtil de faktiske scripts er installeret.

Betalte/private scripts må kun lægges offentligt, hvis du har ret til at dele dem. En offentlig txAdmin-recipe kan ikke automatisk hente private filer uden en særskilt fungerende downloadløsning.

## Kontrol og grænser

YAML, kildestierne i de downloadede ESX-arkiver, versionerne og basens afhængighedsrækkefølge er kontrolleret. Der er ikke gennemført en rigtig txAdmin-deployment eller en FXServer-/MySQL-/spiltest. Serveren er ikke blevet publiceret eller din host nulstillet herfra.

Recipen importerer standard-ESX-tabeller og skal kun bruges mod en tom database. Dit nuværende repository ændres først, når du uploader filerne. Indsæt aldrig databasekodeord, API-nøgler eller rigtige servernøgler i offentlige filer.
