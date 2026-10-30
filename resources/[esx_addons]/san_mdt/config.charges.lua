-- Sigtelser i MDT — synkroniseres til databasen ved opstart.
-- Matcher San Andreas' Grundlov (identity.dk/lovgivning) + San Andreas Straffelov (bilag A).

Config.ChargeCatalogVersion = 'grundlov-1'

-- Gamle standard-sigtelser (1.1, 2.4 osv.) fjernes ved katalog-opdatering.
Config.LegacyChargeParagraphs = {
    '1.1', '2.1', '2.4', '2.8', '3.2', '3.4', '4.1', '5.1', '5.4', '6.1', '6.5', '7.2',
}

-- law_group: straffelov | vaabenlov | narkoloven | trafikloven | erhvervsloven | luftfartoej | vagtloven
-- category: green | yellow | orange | red | blue
-- jail = måneder (mdr)

Config.DefaultCharges = {
    -- San Andreas Straffelov (Grundlov Kap. 6 — straffelov henvisning)
    { paragraph = '7', law_group = 'straffelov', name = 'Trusler', description = 'Trusler om vold, frihedsberøvelse eller alvorlig skade, når modtageren med rimelighed kan frygte udførelse.', category = 'green', jail = 2, fine = 10000, points = 0, revocation = '' },
    { paragraph = '8', law_group = 'straffelov', name = 'Overfald', description = 'Ulovlig fysisk vold mod person uden legitimt formål.', category = 'orange', jail = 4, fine = 17500, points = 0, revocation = '' },
    { paragraph = '9', law_group = 'straffelov', name = 'Grov vold', description = 'Særlig brutal, gentagen eller gruppebaseret vold; våben mod person; vold mod tjenestemand.', category = 'red', jail = 12, fine = 25000, points = 0, revocation = '' },
    { paragraph = '10', law_group = 'straffelov', name = 'Mord', description = 'Forsætligt at berøve en anden livet.', category = 'red', jail = 32, fine = 0, points = 0, revocation = '' },
    { paragraph = '11', law_group = 'straffelov', name = 'Manddrab', description = 'At berøve en anden livet uden at opfylde betingelserne for mord.', category = 'red', jail = 18, fine = 0, points = 0, revocation = '' },
    { paragraph = '12', law_group = 'straffelov', name = 'Gidseltagning', description = 'Ulovlig frihedsberøvelse for løsepenge, flugt eller anden fordel.', category = 'red', jail = 22, fine = 0, points = 0, revocation = '' },
    { paragraph = '13', law_group = 'straffelov', name = 'Kidnapning', description = 'Gidseltagning med våben, transport over distriktsgrænse eller særlig fare for offeret.', category = 'red', jail = 28, fine = 0, points = 0, revocation = '' },
    { paragraph = '15', law_group = 'straffelov', name = 'Tyveri', description = 'Tilægnelse af andres løsøre uden samtykke.', category = 'orange', jail = 3, fine = 12500, points = 0, revocation = '' },
    { paragraph = '16', law_group = 'straffelov', name = 'Hæleri', description = 'Besiddelse eller salg af gods med kriminel oprindelse.', category = 'orange', jail = 5, fine = 20000, points = 0, revocation = '' },
    { paragraph = '17', law_group = 'straffelov', name = 'Indbrud', description = 'Ulovlig adgang til lukket bygning eller virksomhed med henblik på tyveri eller skade.', category = 'orange', jail = 7, fine = 15000, points = 0, revocation = '' },
    { paragraph = '18', law_group = 'straffelov', name = 'Røveri', description = 'Tyveri ved vold eller trussel om vold, herunder butiksrøveri.', category = 'red', jail = 14, fine = 30000, points = 0, revocation = '' },
    { paragraph = '19', law_group = 'straffelov', name = 'Institutionelt røveri', description = 'Planlagt røveri mod bank, juvelér, våbenforretning eller værditransport.', category = 'red', jail = 22, fine = 50000, points = 0, revocation = '' },
    { paragraph = '20', law_group = 'straffelov', name = 'Biltyveri', description = 'Ulovligt at tage andres motorkøretøj i brug.', category = 'orange', jail = 4, fine = 16500, points = 0, revocation = '' },
    { paragraph = '21', law_group = 'straffelov', name = 'Hærværk', description = 'Forsætlig beskadigelse af ejendom, køretøj eller offentlig infrastruktur.', category = 'green', jail = 3, fine = 12500, points = 0, revocation = '' },
    { paragraph = '23', law_group = 'straffelov', name = 'Bedrageri', description = 'Snyd ved falsk fremstilling, identitetssvindel eller bevidst vildledning.', category = 'orange', jail = 8, fine = 32500, points = 0, revocation = '' },
    { paragraph = '24', law_group = 'straffelov', name = 'Dokumentfalsk', description = 'Falsk ID, licens, kontrakt eller officielt dokument med henblik på vildledning.', category = 'blue', jail = 10, fine = 20000, points = 0, revocation = '' },
    { paragraph = '25', law_group = 'straffelov', name = 'Hvidvask', description = 'Modtagelse eller brug af penge/værdier med kriminel oprindelse.', category = 'red', jail = 18, fine = 40000, points = 0, revocation = '' },
    { paragraph = '26', law_group = 'straffelov', name = 'Korruption', description = 'Bestikkelse af offentlig tjenestemand, dommer eller politi.', category = 'red', jail = 20, fine = 0, points = 0, revocation = '' },
    { paragraph = '53', law_group = 'straffelov', name = 'Forstyrrelse af offentlig orden', description = 'Råben, slagsmål, chikane eller støj der forstyrrer offentligheden uden lovlig grund.', category = 'green', jail = 1, fine = 6500, points = 0, revocation = '' },
    { paragraph = '54', law_group = 'straffelov', name = 'Nægtelse af legitim ordre', description = 'Nægter at efterkomme lovlig ordre fra politiet under lovlig kontakt.', category = 'green', jail = 2, fine = 10000, points = 0, revocation = '' },
    { paragraph = '55', law_group = 'straffelov', name = 'Obstruktion af tjenestemand', description = 'Fysisk eller verbal forhindring af politi, ambulance eller brand under tjeneste.', category = 'orange', jail = 6, fine = 15000, points = 0, revocation = '' },
    { paragraph = '56', law_group = 'straffelov', name = 'Maskering', description = 'Fuld ansigtsmaskering i det offentlige rum uden saglig grund.', category = 'green', jail = 0, fine = 12500, points = 0, revocation = '' },
    { paragraph = '58', law_group = 'straffelov', name = 'Trusler mod embedsmand', description = 'Trusler rettet mod politi, dommer, læge eller brandmand under tjeneste.', category = 'red', jail = 10, fine = 20000, points = 0, revocation = '' },
    { paragraph = '59', law_group = 'straffelov', name = 'Falsk alarm', description = 'Bevidst falsk nødopkald eller udløsning af alarm uden grund.', category = 'orange', jail = 5, fine = 20000, points = 0, revocation = '' },
    { paragraph = '60', law_group = 'straffelov', name = 'Indtrængen i sikret område', description = 'Ulovlig adgang til politistation, fængsel, hospital, domstol eller militært område.', category = 'orange', jail = 8, fine = 15000, points = 0, revocation = '' },
    { paragraph = '607', law_group = 'straffelov', name = 'Gæld til staten', description = 'Gæld til staten over 200.000 kr. ved erkendt sigtelse med fængselsstraf.', category = 'red', jail = 250, fine = 0, points = 0, revocation = '' },

    -- Grundlov Kap. 7 — Våbenloven
    { paragraph = '701', law_group = 'vaabenlov', name = 'Besiddelse — Klasse A', description = 'Besiddelse eller bæring af fuldautomatiske skydevåben eller rifler uden tilladelse.', category = 'red', jail = 25, fine = 35000, points = 0, revocation = '' },
    { paragraph = '702', law_group = 'vaabenlov', name = 'Besiddelse — Klasse B', description = 'Besiddelse eller bæring af semi-automatiske skydevåben uden tilladelse.', category = 'red', jail = 10, fine = 30000, points = 0, revocation = '' },
    { paragraph = '703', law_group = 'vaabenlov', name = 'Bæring — Klasse C/D', description = 'Bæring af kniv, økse, bat eller slagvåben i det offentlige rum uden saglig grund.', category = 'orange', jail = 5, fine = 20000, points = 0, revocation = '' },
    { paragraph = '704', law_group = 'vaabenlov', name = 'Ulovlig våbenhandel', description = 'Salg, smugling eller videresalg af våben uden autoriseret forhandler.', category = 'red', jail = 21, fine = 45000, points = 0, revocation = '' },

    -- Grundlov Kap. 8 — Narkotikaloven
    { paragraph = '801', law_group = 'narkoloven', name = 'Besiddelse — Klasse A (Meth)', description = 'Besiddelse eller fremstilling af meth uanset mængde.', category = 'red', jail = 25, fine = 40000, points = 0, revocation = '' },
    { paragraph = '802', law_group = 'narkoloven', name = 'Besiddelse — Klasse B (Kokain)', description = 'Besiddelse eller fremstilling af kokain uanset mængde.', category = 'red', jail = 12, fine = 25000, points = 0, revocation = '' },
    { paragraph = '803', law_group = 'narkoloven', name = 'Besiddelse — Klasse C (Marihuana)', description = 'Besiddelse af marihuana i det offentlige rum. Op til 2 gram på privat grund er lovligt.', category = 'orange', jail = 2, fine = 10000, points = 0, revocation = '' },
    { paragraph = '804', law_group = 'narkoloven', name = 'Besiddelse — Klasse D', description = 'Besiddelse af euforiserende lægemidler uden lægeerklæring.', category = 'orange', jail = 3, fine = 12000, points = 0, revocation = '' },
    { paragraph = '805', law_group = 'narkoloven', name = 'Salg af narkotika', description = 'Salg, udlevering eller distribution af narkotika — alle klasser.', category = 'red', jail = 18, fine = 50000, points = 0, revocation = '' },
    { paragraph = '806', law_group = 'narkoloven', name = 'Produktion af narkotika', description = 'Dyrkning, fremstilling eller drift af laboratorie til narkotika.', category = 'red', jail = 25, fine = 60000, points = 0, revocation = '' },

    -- Grundlov Kap. 9 — Trafikloven
    { paragraph = '900', law_group = 'trafikloven', name = 'Manipuleret stelnummer', description = 'Køretøj med manipuleret stelnummer kan konfiskeres uden yderligere begrundelse.', category = 'yellow', jail = 0, fine = 15000, points = 0, revocation = 'Konfiskation' },
    { paragraph = '901', law_group = 'trafikloven', name = 'Hasarderet kørsel', description = 'Uansvarlig kørsel med fare for liv eller førlighed.', category = 'yellow', jail = 2, fine = 16500, points = 1, revocation = 'Mulig betinget frakendelse' },
    { paragraph = '902', law_group = 'trafikloven', name = 'Kørsel uden kørekort', description = 'Fører motorkøretøj uden gyldigt kørekort eller under karantæne.', category = 'yellow', jail = 0, fine = 10000, points = 0, revocation = '' },
    { paragraph = '903', law_group = 'trafikloven', name = 'Flugt fra politiet', description = 'Bevidst unddragelse af lovlig politikontakt ved farlig kørsel.', category = 'orange', jail = 8, fine = 15000, points = 2, revocation = 'Mulig frakendelse' },
    { paragraph = '904', law_group = 'trafikloven', name = 'Kørsel i påvirket tilstand', description = 'Kørsel under påvirkning af alkohol, narkotika eller medicin.', category = 'yellow', jail = 4, fine = 20000, points = 2, revocation = 'Mulig frakendelse' },
    { paragraph = '905', law_group = 'trafikloven', name = 'Ulykkesflugt', description = 'Forlader ulykkessted uden hjælp eller oplysning af sig.', category = 'orange', jail = 10, fine = 25000, points = 2, revocation = 'Mulig frakendelse' },
    { paragraph = '906', law_group = 'trafikloven', name = 'Overtrædelse af fartgrænse', description = 'Kørsel over gældende fartgrænse: 80 km/t by, 100 km/t landevej, 150 km/t motorvej.', category = 'yellow', jail = 0, fine = 7500, points = 1, revocation = '' },
    { paragraph = '1235', law_group = 'trafikloven', name = 'Frue-Fri-Fredag', description = 'Privat kørsel i motorkøretøj fredag kl. 20–21 i strid med Grundlov § 903.', category = 'yellow', jail = 0, fine = 10000, points = 1, revocation = '' },

    -- Grundlov Kap. 11 — Virksomhed
    { paragraph = '1100', law_group = 'erhvervsloven', name = 'Drift uden erhvervslicens', description = 'Virksomhed drevet uden godkendelse fra Hertugen.', category = 'blue', jail = 0, fine = 50000, points = 0, revocation = 'Lukningspåbud' },
    { paragraph = '1102', law_group = 'erhvervsloven', name = 'Ulovlig udlejning', description = 'Udlejning i strid med Udlejningsloven.', category = 'blue', jail = 0, fine = 25000, points = 0, revocation = '' },
    { paragraph = '1103', law_group = 'erhvervsloven', name = 'Beskyttelsesracket', description = 'Kræver betaling for beskyttelse mod skade man selv står bag.', category = 'red', jail = 18, fine = 35000, points = 0, revocation = '' },

    -- Grundlov Kap. 12 — Luftfartøj
    { paragraph = '1211', law_group = 'luftfartoej', name = 'Flyvning uden luftfartøj', description = 'Flyvning uden at være registreret ejer af luftfartøj.', category = 'yellow', jail = 4, fine = 20000, points = 0, revocation = '' },
    { paragraph = '1231', law_group = 'luftfartoej', name = 'Farlig flyvning', description = 'Hensynsløs eller farlig flyvning med unødig fare for borgere eller ejendom.', category = 'orange', jail = 8, fine = 30000, points = 0, revocation = '' },
    { paragraph = '1202', law_group = 'luftfartoej', name = 'Overtrædelse af flyveforbud', description = 'Flyvning i område med midlertidigt flyveforbud fra politiet.', category = 'orange', jail = 6, fine = 25000, points = 0, revocation = 'Konfiskation mulig' },

    -- Grundlov Kap. 13 — Vagtloven
    { paragraph = '1300', law_group = 'vagtloven', name = 'Ulovlig vagtvirksomhed', description = 'Vagtvirksomhed uden autorisation fra Politiet.', category = 'blue', jail = 4, fine = 27500, points = 0, revocation = '' },
    { paragraph = '1303', law_group = 'vagtloven', name = 'Vagtfunktionær overtræder beføjelser', description = 'Vagt agerer som politi eller foretager ulovlig efterforskning.', category = 'orange', jail = 6, fine = 20000, points = 0, revocation = '' },
}
