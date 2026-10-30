--- OFFICAL RPEMOTES REPOSITORY ---
--- BY TAYMCKENZIENZ, AvaN0x, MadsL, Mathu_lmn AND THE COMMUNITY ---
--- DO NOT REUPLOAD, SELL OR ENCRYPT. ---
--- IT IS FREE BY THE COMMUNITY, FOR THE COMMUNITY ---

Config = {
    -- MENU OPTIONS
    MenuLanguage = 'da', -- Dansk menu
    DebugDisplay = false,
    EnableCancelKeybind = true,
    CancelEmoteKey = 'x',
    MenuKeybindEnabled = true,
    MenuKeybind = 'f4', -- F4 = emote menu (F3 er ya_interactions)
    FavKeybindEnabled = true,
    FavKeybind = 'capital',
    SqlKeybinding = false,
    NotificationsAsChatMessage = false,
    Framework = false,
    Search = true,
    CancelPreviousEmote = false,

    MenuTitle = '', -- tom når CustomMenuEnabled — branding ligger i html/menu_banner.html
    MenuPosition = 'right',
    CustomMenuEnabled = true,
    MenuImage = '', -- tom = bruger html/menu_banner.html automatisk


	-- COMBAT CAR, AND PLAYER MOVEMENT OPTIONS
    DisarmPlayer = false, -- Set this to true if you want to disarm the player when they play an emote..
    AllowPunching = false, -- Set this to true if you want to allow people punching while emotes are playing
    AllowedInCars = true, -- Set this false if you want to disable emotes in cars.
    AllowInWater = false, -- If turned off, opening the menu and playing an emote will not be possible while swimming.
	
	
	-- RAGDOLL OPTIONS
    RagdollEnabled = false,     -- You can enable or disable the Ragdoll keybinding here.
    RagdollKeybind = 'u', -- Get the button string here https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/.
    RagdollAsToggle = true,  -- You can enable or disable Ragdoll as Toggle here. Only works if RagdollEnabled is set to true.


    -- EXPRESSIONS, WALKS, AND MORE MENU OPTIONS
    ExpressionsEnabled = true, -- You can disable the Facial Expressions menu here. 
    PersistentExpression = true, -- Saves expression style to client via KVP and applies them upon joining any server with RPEmotes installed.
    WalkingStylesEnabled = true, -- You can disable the Walking Styles menu here.
    PersistentWalk = true, -- Saves walkstyles style to client via KVP and applies them upon joining any server with RPEmotes installed. This is also reapplied upon exiting a vehicle.
    SharedEmotesEnabled = true, -- You can disable the Shared Emotes here.
    AdultEmotesDisabled = false, -- You can disable the Adult Emotes here. By default, this is set to false for obvious reasons.
    AnimalEmotesEnabled = true, -- You can disable the Animal Emotes here.
	
	
	-- HANDS UP OPTIONS 
    HandsupEnabled = false, -- You can enable / disable the handsup here / change the keybind. It is currently set to Y however disabled by default as to not conflict with qb-core servers.
    HandsupKeybind = 'Y', -- Get the button string here https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/.
    HandsupKeybindEnabled = false, -- Set this to false if you would for whatever reason prefer people use the chat commannd /handsup.
    HandsupKeybindInCarEnabled = false,
    PersistentEmoteAfterHandsup = true, -- If true, you will play the emote you were playing previously after you cancel your handsup animation. This is enabled by default with the 'true' value.


	-- POINTING OPTIONS
    PointingEnabled = false, -- You can enable / disable the finger pointing here / change the keybind. It is currently set to B however disabled by default as to not conflict with qb-core servers.
    PointingKeybindEnabled = true,
    PointingKeybind = 'B', -- Get the button string here https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/.
    PointingKeybindInCarEnabled = false,
    PersistentEmoteAfterPointing = true, -- If true, you will play the emote you were playing previously after you stop pointing.


	-- CROUCHING OPTIONS
    CrouchEnabled = true, -- Enabled by default as this is an integral part of RPEmotes
    CrouchKeybindEnabled = true, -- If true, crouching will use keybinds.
    CrouchKeybind = 'lcontrol', -- The default crouch keybind, get the button string here: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/
    CrouchOverride = false, -- If true, you won't enter stealth mode even if the crouch key and the "duck" key are the same.
    -- If crawling should be enabled.
    CrawlEnabled = true,
	
	-- CRAWLING OPTIONS
    CrawlEnabled = true, -- If crawling should be enabled.
    CrawlKeybindEnabled = true, -- If true, crawling will use keybinds.
    CrawlKeybind = 'rcontrol', -- The default crawl keybind, get the button string here: https://docs.fivem.net/docs/game-references/input-mapper-parameter-ids/keyboard/



	-- BINOCULAR OPTIONS
    BinocularsEnabled = true, -- Enable / disable the /binoculars command in chat. This is enabled by default as it is an integral part of RPEmotes
    AllowVisionsToggling = true, -- If set to true, you'll be able to toggle between different vision modes in the binoculars
    
    -- NEWS CAMERA OPTIONS
    NewscamEnabled = true, -- If set to true, the /newscam command will be enabled. This is enabled by default as it is an integral part of RPEmotes
	
	-- OFFICAL UPDATES CHECKER
	CheckForUpdates = false,
	

}

Config.KeybindKeys = {
    ['num4'] = 108,
    ['num5'] = 110,
    ['num6'] = 109,
    ['num7'] = 117,
    ['num8'] = 111,
    ['num9'] = 118
}
