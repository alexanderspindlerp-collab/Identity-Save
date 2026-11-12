SAN dispatch fix

- Dispatch-opkald er ikke længere afhængige af screenshot-basic.
- Config.EnableWitnessPhotos=false som standard.
- Hvis screenshot-basic fejler med Mixed Content/Failed to fetch, bliver dispatch stadig sendt.
- Ignored/cooldown logs vises kun når Config.Debug=true.
