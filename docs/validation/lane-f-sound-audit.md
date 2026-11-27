# Lane F sound fidelity audit

Compared with pret/pokered `af519899719f0754965776faac0e836a3b906e6d`. The port column is the score or cry `KantoAudio` plays.

**280 match, 4 mismatch.** Map headers are one row each. The other rows are the battle, victory, evolution, Hall of Fame, credits, fanfare, and cry triggers.

| Event | Pokered source and track | Port | Result |
| --- | --- | --- | --- |
| Map `PALLET_TOWN` | `data/maps/songs.asm:3` `MUSIC_PALLET_TOWN` (`Music_PalletTown`) | `pallet` | match |
| Map `VIRIDIAN_CITY` | `data/maps/songs.asm:4` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `PEWTER_CITY` | `data/maps/songs.asm:5` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `CERULEAN_CITY` | `data/maps/songs.asm:6` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `LAVENDER_TOWN` | `data/maps/songs.asm:7` `MUSIC_LAVENDER` (`Music_Lavender`) | `lavender` | match |
| Map `VERMILION_CITY` | `data/maps/songs.asm:8` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `CELADON_CITY` | `data/maps/songs.asm:9` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `FUCHSIA_CITY` | `data/maps/songs.asm:10` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `CINNABAR_ISLAND` | `data/maps/songs.asm:11` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `INDIGO_PLATEAU` | `data/maps/songs.asm:12` `MUSIC_INDIGO_PLATEAU` (`Music_IndigoPlateau`) | `indigo` | match |
| Map `SAFFRON_CITY` | `data/maps/songs.asm:13` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNUSED_MAP_0B` | `data/maps/songs.asm:14` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_1` | `data/maps/songs.asm:15` `MUSIC_ROUTES1` (`Music_Routes1`) | `route1` | match |
| Map `ROUTE_2` | `data/maps/songs.asm:16` `MUSIC_ROUTES1` (`Music_Routes1`) | `route1` | match |
| Map `ROUTE_3` | `data/maps/songs.asm:17` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_4` | `data/maps/songs.asm:18` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_5` | `data/maps/songs.asm:19` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_6` | `data/maps/songs.asm:20` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_7` | `data/maps/songs.asm:21` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_8` | `data/maps/songs.asm:22` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_9` | `data/maps/songs.asm:23` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_10` | `data/maps/songs.asm:24` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_11` | `data/maps/songs.asm:25` `MUSIC_ROUTES4` (`Music_Routes4`) | `routes4` | match |
| Map `ROUTE_12` | `data/maps/songs.asm:26` `MUSIC_ROUTES4` (`Music_Routes4`) | `routes4` | match |
| Map `ROUTE_13` | `data/maps/songs.asm:27` `MUSIC_ROUTES4` (`Music_Routes4`) | `routes4` | match |
| Map `ROUTE_14` | `data/maps/songs.asm:28` `MUSIC_ROUTES4` (`Music_Routes4`) | `routes4` | match |
| Map `ROUTE_15` | `data/maps/songs.asm:29` `MUSIC_ROUTES4` (`Music_Routes4`) | `routes4` | match |
| Map `ROUTE_16` | `data/maps/songs.asm:30` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_17` | `data/maps/songs.asm:31` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_18` | `data/maps/songs.asm:32` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_19` | `data/maps/songs.asm:33` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_20` | `data/maps/songs.asm:34` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_21` | `data/maps/songs.asm:35` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_22` | `data/maps/songs.asm:36` `MUSIC_ROUTES3` (`Music_Routes3`) | `routes3` | match |
| Map `ROUTE_23` | `data/maps/songs.asm:37` `MUSIC_INDIGO_PLATEAU` (`Music_IndigoPlateau`) | `indigo` | match |
| Map `ROUTE_24` | `data/maps/songs.asm:38` `MUSIC_ROUTES2` (`Music_Routes2`) | `routes2` | match |
| Map `ROUTE_25` | `data/maps/songs.asm:39` `MUSIC_ROUTES2` (`Music_Routes2`) | `routes2` | match |
| Map `REDS_HOUSE_1F` | `data/maps/songs.asm:40` `MUSIC_PALLET_TOWN` (`Music_PalletTown`) | `pallet` | match |
| Map `REDS_HOUSE_2F` | `data/maps/songs.asm:41` `MUSIC_PALLET_TOWN` (`Music_PalletTown`) | `pallet` | match |
| Map `BLUES_HOUSE` | `data/maps/songs.asm:42` `MUSIC_PALLET_TOWN` (`Music_PalletTown`) | `pallet` | match |
| Map `OAKS_LAB` | `data/maps/songs.asm:43` `MUSIC_OAKS_LAB` (`Music_OaksLab`) | `oaks_lab` | match |
| Map `VIRIDIAN_POKECENTER` | `data/maps/songs.asm:44` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `VIRIDIAN_MART` | `data/maps/songs.asm:45` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `VIRIDIAN_SCHOOL_HOUSE` | `data/maps/songs.asm:46` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `VIRIDIAN_NICKNAME_HOUSE` | `data/maps/songs.asm:47` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `VIRIDIAN_GYM` | `data/maps/songs.asm:48` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `DIGLETTS_CAVE_ROUTE_2` | `data/maps/songs.asm:49` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `VIRIDIAN_FOREST_NORTH_GATE` | `data/maps/songs.asm:50` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_2_TRADE_HOUSE` | `data/maps/songs.asm:51` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_2_GATE` | `data/maps/songs.asm:52` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `VIRIDIAN_FOREST_SOUTH_GATE` | `data/maps/songs.asm:53` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `VIRIDIAN_FOREST` | `data/maps/songs.asm:54` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `MUSEUM_1F` | `data/maps/songs.asm:55` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `MUSEUM_2F` | `data/maps/songs.asm:56` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `PEWTER_GYM` | `data/maps/songs.asm:57` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `PEWTER_NIDORAN_HOUSE` | `data/maps/songs.asm:58` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `PEWTER_MART` | `data/maps/songs.asm:59` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `PEWTER_SPEECH_HOUSE` | `data/maps/songs.asm:60` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `PEWTER_POKECENTER` | `data/maps/songs.asm:61` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `MT_MOON_1F` | `data/maps/songs.asm:62` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `MT_MOON_B1F` | `data/maps/songs.asm:63` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `MT_MOON_B2F` | `data/maps/songs.asm:64` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `CERULEAN_TRASHED_HOUSE` | `data/maps/songs.asm:65` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `CERULEAN_TRADE_HOUSE` | `data/maps/songs.asm:66` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `CERULEAN_POKECENTER` | `data/maps/songs.asm:67` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CERULEAN_GYM` | `data/maps/songs.asm:68` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `BIKE_SHOP` | `data/maps/songs.asm:69` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `CERULEAN_MART` | `data/maps/songs.asm:70` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `MT_MOON_POKECENTER` | `data/maps/songs.asm:71` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CERULEAN_TRASHED_HOUSE_COPY` | `data/maps/songs.asm:72` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `ROUTE_5_GATE` | `data/maps/songs.asm:73` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_5` | `data/maps/songs.asm:74` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `DAYCARE` | `data/maps/songs.asm:75` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_6_GATE` | `data/maps/songs.asm:76` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_6` | `data/maps/songs.asm:77` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_6_COPY` | `data/maps/songs.asm:78` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `ROUTE_7_GATE` | `data/maps/songs.asm:79` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_7` | `data/maps/songs.asm:80` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_7_COPY` | `data/maps/songs.asm:81` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `ROUTE_8_GATE` | `data/maps/songs.asm:82` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNDERGROUND_PATH_ROUTE_8` | `data/maps/songs.asm:83` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROCK_TUNNEL_POKECENTER` | `data/maps/songs.asm:84` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `ROCK_TUNNEL_1F` | `data/maps/songs.asm:85` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `POWER_PLANT` | `data/maps/songs.asm:86` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `ROUTE_11_GATE_1F` | `data/maps/songs.asm:87` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `DIGLETTS_CAVE_ROUTE_11` | `data/maps/songs.asm:88` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `ROUTE_11_GATE_2F` | `data/maps/songs.asm:89` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `ROUTE_12_GATE_1F` | `data/maps/songs.asm:90` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `BILLS_HOUSE` | `data/maps/songs.asm:91` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `VERMILION_POKECENTER` | `data/maps/songs.asm:92` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `POKEMON_FAN_CLUB` | `data/maps/songs.asm:93` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `VERMILION_MART` | `data/maps/songs.asm:94` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `VERMILION_GYM` | `data/maps/songs.asm:95` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `VERMILION_PIDGEY_HOUSE` | `data/maps/songs.asm:96` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `VERMILION_DOCK` | `data/maps/songs.asm:97` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_1F` | `data/maps/songs.asm:98` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_2F` | `data/maps/songs.asm:99` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_3F` | `data/maps/songs.asm:100` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_B1F` | `data/maps/songs.asm:101` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_BOW` | `data/maps/songs.asm:102` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_KITCHEN` | `data/maps/songs.asm:103` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_CAPTAINS_ROOM` | `data/maps/songs.asm:104` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_1F_ROOMS` | `data/maps/songs.asm:105` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_2F_ROOMS` | `data/maps/songs.asm:106` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `SS_ANNE_B1F_ROOMS` | `data/maps/songs.asm:107` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `UNUSED_MAP_69` | `data/maps/songs.asm:108` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `UNUSED_MAP_6A` | `data/maps/songs.asm:109` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `UNUSED_MAP_6B` | `data/maps/songs.asm:110` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `VICTORY_ROAD_1F` | `data/maps/songs.asm:111` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `UNUSED_MAP_6D` | `data/maps/songs.asm:112` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `UNUSED_MAP_6E` | `data/maps/songs.asm:113` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `UNUSED_MAP_6F` | `data/maps/songs.asm:114` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_70` | `data/maps/songs.asm:115` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `LANCES_ROOM` | `data/maps/songs.asm:116` `MUSIC_INDIGO_PLATEAU` (`Music_IndigoPlateau`) | `indigo` | match |
| Map `UNUSED_MAP_72` | `data/maps/songs.asm:117` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `UNUSED_MAP_73` | `data/maps/songs.asm:118` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `UNUSED_MAP_74` | `data/maps/songs.asm:119` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `UNUSED_MAP_75` | `data/maps/songs.asm:120` `MUSIC_SS_ANNE` (`Music_SSAnne`) | `anne` | match |
| Map `HALL_OF_FAME` | `data/maps/songs.asm:121` `MUSIC_PALLET_TOWN` (`Music_PalletTown`) | `pallet` | match |
| Map `UNDERGROUND_PATH_NORTH_SOUTH` | `data/maps/songs.asm:122` `MUSIC_ROUTES1` (`Music_Routes1`) | `route1` | match |
| Map `CHAMPIONS_ROOM` | `data/maps/songs.asm:123` `MUSIC_INDIGO_PLATEAU` (`Music_IndigoPlateau`) | `indigo` | match |
| Map `UNDERGROUND_PATH_WEST_EAST` | `data/maps/songs.asm:124` `MUSIC_ROUTES1` (`Music_Routes1`) | `route1` | match |
| Map `CELADON_MART_1F` | `data/maps/songs.asm:125` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MART_2F` | `data/maps/songs.asm:126` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MART_3F` | `data/maps/songs.asm:127` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MART_4F` | `data/maps/songs.asm:128` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MART_ROOF` | `data/maps/songs.asm:129` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MART_ELEVATOR` | `data/maps/songs.asm:130` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_MANSION_1F` | `data/maps/songs.asm:131` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_MANSION_2F` | `data/maps/songs.asm:132` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_MANSION_3F` | `data/maps/songs.asm:133` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_MANSION_ROOF` | `data/maps/songs.asm:134` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_MANSION_ROOF_HOUSE` | `data/maps/songs.asm:135` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_POKECENTER` | `data/maps/songs.asm:136` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CELADON_GYM` | `data/maps/songs.asm:137` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `GAME_CORNER` | `data/maps/songs.asm:138` `MUSIC_GAME_CORNER` (`Music_GameCorner`) | `game_corner` | match |
| Map `CELADON_MART_5F` | `data/maps/songs.asm:139` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `GAME_CORNER_PRIZE_ROOM` | `data/maps/songs.asm:140` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_DINER` | `data/maps/songs.asm:141` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_CHIEF_HOUSE` | `data/maps/songs.asm:142` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `CELADON_HOTEL` | `data/maps/songs.asm:143` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `LAVENDER_POKECENTER` | `data/maps/songs.asm:144` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `POKEMON_TOWER_1F` | `data/maps/songs.asm:145` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_2F` | `data/maps/songs.asm:146` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_3F` | `data/maps/songs.asm:147` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_4F` | `data/maps/songs.asm:148` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_5F` | `data/maps/songs.asm:149` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_6F` | `data/maps/songs.asm:150` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `POKEMON_TOWER_7F` | `data/maps/songs.asm:151` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Map `MR_FUJIS_HOUSE` | `data/maps/songs.asm:152` `MUSIC_LAVENDER` (`Music_Lavender`) | `lavender` | match |
| Map `LAVENDER_MART` | `data/maps/songs.asm:153` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `LAVENDER_CUBONE_HOUSE` | `data/maps/songs.asm:154` `MUSIC_LAVENDER` (`Music_Lavender`) | `lavender` | match |
| Map `FUCHSIA_MART` | `data/maps/songs.asm:155` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `FUCHSIA_BILLS_GRANDPAS_HOUSE` | `data/maps/songs.asm:156` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `FUCHSIA_POKECENTER` | `data/maps/songs.asm:157` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `WARDENS_HOUSE` | `data/maps/songs.asm:158` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `SAFARI_ZONE_GATE` | `data/maps/songs.asm:159` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `FUCHSIA_GYM` | `data/maps/songs.asm:160` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `FUCHSIA_MEETING_ROOM` | `data/maps/songs.asm:161` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `SEAFOAM_ISLANDS_B1F` | `data/maps/songs.asm:162` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `SEAFOAM_ISLANDS_B2F` | `data/maps/songs.asm:163` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `SEAFOAM_ISLANDS_B3F` | `data/maps/songs.asm:164` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `SEAFOAM_ISLANDS_B4F` | `data/maps/songs.asm:165` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `VERMILION_OLD_ROD_HOUSE` | `data/maps/songs.asm:166` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `FUCHSIA_GOOD_ROD_HOUSE` | `data/maps/songs.asm:167` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `POKEMON_MANSION_1F` | `data/maps/songs.asm:168` `MUSIC_CINNABAR_MANSION` (`Music_CinnabarMansion`) | `mansion` | match |
| Map `CINNABAR_GYM` | `data/maps/songs.asm:169` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `CINNABAR_LAB` | `data/maps/songs.asm:170` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `CINNABAR_LAB_TRADE_ROOM` | `data/maps/songs.asm:171` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `CINNABAR_LAB_METRONOME_ROOM` | `data/maps/songs.asm:172` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `CINNABAR_LAB_FOSSIL_ROOM` | `data/maps/songs.asm:173` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `CINNABAR_POKECENTER` | `data/maps/songs.asm:174` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CINNABAR_MART` | `data/maps/songs.asm:175` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `CINNABAR_MART_COPY` | `data/maps/songs.asm:176` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `INDIGO_PLATEAU_LOBBY` | `data/maps/songs.asm:177` `MUSIC_INDIGO_PLATEAU` (`Music_IndigoPlateau`) | `indigo` | match |
| Map `COPYCATS_HOUSE_1F` | `data/maps/songs.asm:178` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `COPYCATS_HOUSE_2F` | `data/maps/songs.asm:179` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `FIGHTING_DOJO` | `data/maps/songs.asm:180` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `SAFFRON_GYM` | `data/maps/songs.asm:181` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `SAFFRON_PIDGEY_HOUSE` | `data/maps/songs.asm:182` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `SAFFRON_MART` | `data/maps/songs.asm:183` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `SILPH_CO_1F` | `data/maps/songs.asm:184` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SAFFRON_POKECENTER` | `data/maps/songs.asm:185` `MUSIC_POKECENTER` (`Music_Pokecenter`) | `pokecenter` | match |
| Map `MR_PSYCHICS_HOUSE` | `data/maps/songs.asm:186` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_15_GATE_1F` | `data/maps/songs.asm:187` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_15_GATE_2F` | `data/maps/songs.asm:188` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_16_GATE_1F` | `data/maps/songs.asm:189` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_16_GATE_2F` | `data/maps/songs.asm:190` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_16_FLY_HOUSE` | `data/maps/songs.asm:191` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `ROUTE_12_SUPER_ROD_HOUSE` | `data/maps/songs.asm:192` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `ROUTE_18_GATE_1F` | `data/maps/songs.asm:193` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `ROUTE_18_GATE_2F` | `data/maps/songs.asm:194` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `SEAFOAM_ISLANDS_1F` | `data/maps/songs.asm:195` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `ROUTE_22_GATE` | `data/maps/songs.asm:196` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `VICTORY_ROAD_2F` | `data/maps/songs.asm:197` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `ROUTE_12_GATE_2F` | `data/maps/songs.asm:198` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `VERMILION_TRADE_HOUSE` | `data/maps/songs.asm:199` `MUSIC_VERMILION` (`Music_Vermilion`) | `vermilion` | match |
| Map `DIGLETTS_CAVE` | `data/maps/songs.asm:200` `MUSIC_DUNGEON2` (`Music_Dungeon2`) | `dungeon2` | match |
| Map `VICTORY_ROAD_3F` | `data/maps/songs.asm:201` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `ROCKET_HIDEOUT_B1F` | `data/maps/songs.asm:202` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `ROCKET_HIDEOUT_B2F` | `data/maps/songs.asm:203` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `ROCKET_HIDEOUT_B3F` | `data/maps/songs.asm:204` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `ROCKET_HIDEOUT_B4F` | `data/maps/songs.asm:205` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `ROCKET_HIDEOUT_ELEVATOR` | `data/maps/songs.asm:206` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `UNUSED_MAP_CC` | `data/maps/songs.asm:207` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `UNUSED_MAP_CD` | `data/maps/songs.asm:208` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `UNUSED_MAP_CE` | `data/maps/songs.asm:209` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `SILPH_CO_2F` | `data/maps/songs.asm:210` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_3F` | `data/maps/songs.asm:211` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_4F` | `data/maps/songs.asm:212` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_5F` | `data/maps/songs.asm:213` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_6F` | `data/maps/songs.asm:214` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_7F` | `data/maps/songs.asm:215` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_8F` | `data/maps/songs.asm:216` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `POKEMON_MANSION_2F` | `data/maps/songs.asm:217` `MUSIC_CINNABAR_MANSION` (`Music_CinnabarMansion`) | `mansion` | match |
| Map `POKEMON_MANSION_3F` | `data/maps/songs.asm:218` `MUSIC_CINNABAR_MANSION` (`Music_CinnabarMansion`) | `mansion` | match |
| Map `POKEMON_MANSION_B1F` | `data/maps/songs.asm:219` `MUSIC_CINNABAR_MANSION` (`Music_CinnabarMansion`) | `mansion` | match |
| Map `SAFARI_ZONE_EAST` | `data/maps/songs.asm:220` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_NORTH` | `data/maps/songs.asm:221` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_WEST` | `data/maps/songs.asm:222` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_CENTER` | `data/maps/songs.asm:223` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_CENTER_REST_HOUSE` | `data/maps/songs.asm:224` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_SECRET_HOUSE` | `data/maps/songs.asm:225` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_WEST_REST_HOUSE` | `data/maps/songs.asm:226` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_EAST_REST_HOUSE` | `data/maps/songs.asm:227` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `SAFARI_ZONE_NORTH_REST_HOUSE` | `data/maps/songs.asm:228` `MUSIC_SAFARI_ZONE` (`Music_SafariZone`) | `safari` | match |
| Map `CERULEAN_CAVE_2F` | `data/maps/songs.asm:229` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `CERULEAN_CAVE_B1F` | `data/maps/songs.asm:230` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `CERULEAN_CAVE_1F` | `data/maps/songs.asm:231` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `NAME_RATERS_HOUSE` | `data/maps/songs.asm:232` `MUSIC_CITIES2` (`Music_Cities2`) | `cities2` | match |
| Map `CERULEAN_BADGE_HOUSE` | `data/maps/songs.asm:233` `MUSIC_CITIES1` (`Music_Cities1`) | `cities1` | match |
| Map `UNUSED_MAP_E7` | `data/maps/songs.asm:234` `MUSIC_CINNABAR` (`Music_Cinnabar`) | `cinnabar` | match |
| Map `ROCK_TUNNEL_B1F` | `data/maps/songs.asm:235` `MUSIC_DUNGEON3` (`Music_Dungeon3`) | `dungeon3` | match |
| Map `SILPH_CO_9F` | `data/maps/songs.asm:236` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_10F` | `data/maps/songs.asm:237` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_11F` | `data/maps/songs.asm:238` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `SILPH_CO_ELEVATOR` | `data/maps/songs.asm:239` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_ED` | `data/maps/songs.asm:240` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_EE` | `data/maps/songs.asm:241` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `TRADE_CENTER` | `data/maps/songs.asm:242` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `COLOSSEUM` | `data/maps/songs.asm:243` `MUSIC_CELADON` (`Music_Celadon`) | `celadon` | match |
| Map `UNUSED_MAP_F1` | `data/maps/songs.asm:244` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_F2` | `data/maps/songs.asm:245` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_F3` | `data/maps/songs.asm:246` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `UNUSED_MAP_F4` | `data/maps/songs.asm:247` `MUSIC_SILPH_CO` (`Music_SilphCo`) | `silph` | match |
| Map `LORELEIS_ROOM` | `data/maps/songs.asm:248` `MUSIC_GYM` (`Music_Gym`) | `gym` | match |
| Map `BRUNOS_ROOM` | `data/maps/songs.asm:249` `MUSIC_DUNGEON1` (`Music_Dungeon1`) | `dungeon1` | match |
| Map `AGATHAS_ROOM` | `data/maps/songs.asm:250` `MUSIC_POKEMON_TOWER` (`Music_PokemonTower`) | `tower` | match |
| Wild battle | audio/play_battle_music.asm:32 `MUSIC_WILD_BATTLE` | `wild` when `trainerName` is nil or the class is missing | match |
| Trainer battle | audio/play_battle_music.asm:26 `MUSIC_TRAINER_BATTLE` | `trainer` | match |
| Gym leader battle | audio/play_battle_music.asm:13 `MUSIC_GYM_LEADER_BATTLE` when `wGymLeaderNo` is set | `gym_leader` for Brock, Misty, Surge, Erika, Koga, Blaine, and Sabrina | match |
| Lance battle | audio/play_battle_music.asm:23 `MUSIC_GYM_LEADER_BATTLE` for `OPP_LANCE` | `gym_leader` | match |
| Champion battle | audio/play_battle_music.asm:29 `MUSIC_FINAL_BATTLE` for `OPP_RIVAL3` | `final` | match |
| Giovanni outside Viridian Gym | audio/play_battle_music.asm:26 `MUSIC_TRAINER_BATTLE` while `wGymLeaderNo` is 0 | `trainer` unless the zone is `pokered:VIRIDIAN_GYM`, which plays `gym_leader` | match |
| Wild victory | engine/battle/core.asm:794 `MUSIC_DEFEATED_WILD_MON` | `defeated_wild` | match |
| Trainer victory | engine/battle/core.asm:921 `MUSIC_DEFEATED_TRAINER` | `defeated_trainer` | match |
| Gym and champion victory | engine/battle/core.asm:917 and :926 `MUSIC_DEFEATED_GYM_LEADER` | `defeated_gym` for a gym leader and for Rival3 | match |
| Evolution sparkle | engine/movie/evolution.asm:17 `SFX_TINK` | `tink` when the evolution phase is `announce` | match |
| Evolution cry of the old species | engine/movie/evolution.asm:42 `PlayCry` of `wEvoOldSpecies` | the cry of `evo.info.from` when the phase is `animate` | match |
| Evolution music | engine/movie/evolution.asm:45 `MUSIC_SAFARI_ZONE` | `safari` | match |
| Evolution result cry | engine/movie/evolution.asm:74 `PlayCry` of the species on screen | the new species after `complete`, the old species after `cancelled` | match |
| Hall of Fame music | engine/movie/hall_of_fame.asm:37 `MUSIC_HALL_OF_FAME` | `hall_of_fame` when the photo phase starts | match |
| Hall of Fame cry | engine/movie/hall_of_fame.asm:178 `PlayCry` | `entry.cry` once the name, level, and types are shown | match |
| Credits | engine/movie/credits.asm:27 `MUSIC_CREDITS` | `credits` when the phase is `credits` | match |
| Surf | home/audio.asm `MUSIC_SURFING` | `surfing` while traversal is surfing | match |
| Bicycle | home/audio.asm `MUSIC_BIKE_RIDING` | `bicycle` while traversal is bicycle | match |
| Meet evil trainer | home/trainers.asm:419 `MUSIC_MEET_EVIL_TRAINER` | `meet_evil` | match |
| Meet female trainer | home/trainers.asm:429 `MUSIC_MEET_FEMALE_TRAINER` | `meet_female` | match |
| Meet male trainer | home/trainers.asm:432 `MUSIC_MEET_MALE_TRAINER` | `meet_male` | match |
| Meet rival | scripts/OaksLab.asm:355 `MUSIC_MEET_RIVAL` (also the other rival scripts) | `meet_rival` when a rival battle is engaged. `PlayTrainerMusic` itself stays silent for rivals | match |
| Item fanfare | macros/scripts/text.asm `sound_get_item_1` → `SFX_GET_ITEM_1` | `item` for each receipt label with that command | match |
| Second item fanfare | macros/scripts/text.asm `sound_get_item_2` → `SFX_GET_ITEM_2` | `item2` | match |
| Key item fanfare | macros/scripts/text.asm `sound_get_key_item` → `SFX_GET_KEY_ITEM` | `key_item` | match |
| Center heal jingle | engine/overworld/healing_machine.asm:47 `MUSIC_PKMN_HEALED` | `heal`. It starts on the same update as the single machine sound | match |
| Wild battle cry | engine/battle/core.asm send-out `PlayCry` | the wild enemy species when the intro is ready | match |
| Player send-out cry | engine/battle/core.asm `PlayCry` | the species in `scene.playerShown` | match |
| Trainer send-out cry | engine/battle/core.asm `PlayCry` | the species in `scene.enemyShown` in a trainer battle | match |
| Oak speech Nidorina cry | home/text.asm `TX_SOUND_CRY_NIDORINA` | `nidorina` on the line that starts `For some people,` | match |
| Saffron Pidgeot cry | scripts/SaffronCity.asm `sound_cry_pidgeot` | `pidgeot` on a Saffron line that starts `PIDGEOT:` | match |
| Static legendary cry | scripts for Articuno, Zapdos, Moltres, and Mewtwo `PlayCry`, wild music | wild battle music and that species' cry. The id is below `OPP_ID_OFFSET` | match |
| Boulder Badge and Earth Badge | scripts/PewterGym.asm:158 and scripts/ViridianGym.asm:255. `sound_level_up` is `sound_get_item_1` (`macros/scripts/text.asm`), track `SFX_GET_ITEM_1` | the `badge` cue, whose score is `key_item` (`SFX_GET_KEY_ITEM`) | mismatch |
| Center heal machine | engine/overworld/healing_machine.asm:31 `SFX_HEALING_MACHINE` once per party member, then the heal jingle | one `healing_machine`, then `heal`, on the same update | mismatch |
| Pokédex page cry | engine/menus/pokedex.asm:506 `PlayCry` after the front sprite | no cry. `PokedexState` never calls `playCry` | mismatch |
| Overworld script cry | each `source-audio` step compiled from a script `PlayCry` | the step is stored on `audioGaps` and not played | mismatch |

## Mismatches

Each patch is unapplied. Its test fails on this tree and passes after `git apply`.

| Mismatch | Patch | Test |
| --- | --- | --- |
| Boulder Badge and Earth Badge play `SFX_GET_KEY_ITEM` instead of `SFX_GET_ITEM_1` | `tools/notes/lane-e-audio-badge-item.patch` | `LaneEAudioFidelityTests.test_boulder_and_earth_badges_play_the_item_fanfare` |
| The Center machine sound plays once, not once per party member | `tools/notes/lane-e-audio-heal-count.patch` | `LaneEAudioFidelityTests.test_center_heal_repeats_the_machine_once_per_party_member` |
| A Pokédex page does not cry | `tools/notes/lane-e-audio-pokedex-cry.patch` | `LaneEAudioFidelityTests.test_pokedex_entry_plays_the_shown_species_cry` |
| A script `PlayCry` step is recorded and not played | `tools/notes/lane-e-audio-source-cries.patch` | `LaneEAudioFidelityTests.test_source_audio_steps_play_the_script_cry` |

Other catalogued cues (collision, fly, the PC, move rows, and the rest of `Source/audio/events.lua`) play the track named on their citation. Those citations are the ones `test_cue_citations_are_in_the_pinned_files` checks. They are not a second copy of this table.

## Credits snapshot pin

`tools/notes/lane-e-credits-audio-snapshot-test.patch` makes `LaneECoverageFingerprintTests.test_snapshot_records_the_credits_path_audio` compare `docs/validation/coverage-current.json` `snapshot.source_sha256` with `tools.harness.run.fingerprint`. The check has no skip, no expected failure, and no second acceptable hash. It fails while the recorded pin is not the fingerprint of this `Source` tree, including when the credits-path audio changes and the pin is left as it was.

Regenerate the pin from the repository root after the `Source` tree to be pinned is the one on disk. Do not hand-edit the hash, and do not relabel a row.

1. Print the pin:

```bash
python3 -c "from pathlib import Path; from tools.harness.run import fingerprint; print(fingerprint(Path('.')))"
```

2. Nest the snapshot the way `ea32b553` did. Insert a new `snapshot` object in front of the current one, and add the matching closing brace so the current object becomes `previous_snapshot`. Set `source_sha256` to the printed fingerprint. Set `commit` to the commit whose `Source` that fingerprint describes. Keep `policy_date`, `source_revision`, `acceptance_context`, and `review_document`. Set `scope` to name this tree only, and end it with `Previous snapshot source_sha256` plus the hash that was just nested. Leave every row, evidence entry, and `accepted_milestone_rows` unchanged. Do not reformat the file with a JSON dump.

3. Confirm both of these exit 0:

```bash
python3 tools/check_coverage_matrix.py --project . --matrix docs/validation/coverage-current.json
python3 -m unittest tools.tests.test_lane_e_coverage_fingerprint.LaneECoverageFingerprintTests.test_snapshot_records_the_credits_path_audio
```

`check_coverage_matrix.py` asserts the same `fingerprint(project) == snapshot.source_sha256` comparison. The unit test is that comparison and nothing weaker.

