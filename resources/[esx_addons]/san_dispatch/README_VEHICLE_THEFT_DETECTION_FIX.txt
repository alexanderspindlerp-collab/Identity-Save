V106 vehicle theft fix
- Fjernet modulo-check der kunne misse hele biltyveri-vinduet.
- Registrerer bilen mens spilleren forsøger at gå ind, og sender dispatch når spilleren faktisk kommer ind.
- Carjacking/låst/occupied vehicle sender straks, parkeret ulåst bil sender ved entry.
- Kræver stadig rigtige NPC-vidner; ingen NPC'er = intet dispatch.
- Foto tages fortsat fra nærmeste NPC-vidnes vinkel, ikke spillerens egen POV.
