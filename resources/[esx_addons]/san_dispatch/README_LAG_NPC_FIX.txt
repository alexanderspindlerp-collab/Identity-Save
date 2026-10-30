SAN Dispatch lag/NPC fix
- Ingen fallback-vidner: hvis der ikke findes faktiske NPC-peds i området, sendes der ikke dispatch.
- Tomme/streamede biler tæller ikke længere som vidner.
- Main loop scanner ikke længere hver frame, men ca. hvert 200ms.
- Radius/cooldowns er gjort mere rolige for at stoppe spam.
- Fotos er slået fra som standard for performance. Dispatch virker uden screenshot-basic.
