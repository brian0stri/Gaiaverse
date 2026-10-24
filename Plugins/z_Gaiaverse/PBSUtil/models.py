from enum import Enum

class Availability(Enum):
    STARTER = "starter"
    AVAILABLE = "available"
    IN_DEX = "in dex"
    EVOLUTION = "evolution"
    UNKNOWN = "unknown"
    UNAVAILABLE = "unavailable"
    IN_PARADOX = "in paradox"

class Habitat(Enum):

    GRASSLAND = "grassland"
    REIVERSEDGE = "riveredge"
    FOREST = "forest"
    JUNGLE = "jungle"
    MOUNTAIN = "mountain"
    CAVE = "cave"
    LAVACAVE = "lavacave"
    DESERT = "desert"
    TUNDRA = "tundra"
    SWAMP = "swamp"
    FARM = "farm"
    BADLANDS = "badlands"
    VOLCANO = "volcano"
    ORICORIOGRASS = "oricoriograss"
    MAGICFOREST = "magicforest"
    ICYBEACH = "icybeach"
    PARADOX1 = "paradox1"
    PARADOX2 = "paradox2"
    PARADOX3 = "paradox3"
    BAMBOOJUNGLE = "bamboojungle"
    ROUTE1 = "route1"
    LAKEISLAND = "lakeisland"

    RIVER = "river"
    BEACH = "beach"
    LAKE = "lake"
    CAVELAKE = "cavelake"
    OCEAN = "ocean"
    REEF = "reef"
    LAKEA = "lakeA"
    ICYOCEAN = "icyocean"
    FEEBASSTILE = "feebasstile"
    PARADOXLAKE = "paradoxlake"


    URBAN = "urban"
    FACILITY = "facility"
    CYBERSPACE = "cyberspace"
    RUINS = "ruins"
    RUINSU = "ruinsU"

    HEADBUTT = "headbutt"
    FRESHFISHING = "fishing"
    OCEANFISHING = "oceanfishing"
    ICYOCEANFISHING = "icyoceanfishing"
    CAVEFISHING = "cavefishing"
    LAVAFISHING = "lavafishing"
    LAKEFISHING = "lakefishing"
    ROCK_SMASH = "rocksmash"
    PARADOXLAKEFISHING = "paradoxlakefishing"
    DUSTCLOUD = "dustcloud"

    UNKNOWN = "unknown"

    ALLLAND = "All Land"

    ALLLANDCONTAINER = {URBAN, FACILITY, RUINS, GRASSLAND, FOREST, REIVERSEDGE, JUNGLE, MOUNTAIN, CAVE, LAVACAVE, DESERT, LAKEISLAND,
                        TUNDRA, SWAMP, FARM, BADLANDS, VOLCANO, ORICORIOGRASS, MAGICFOREST, ICYBEACH, PARADOX1, PARADOX2, PARADOX3, BAMBOOJUNGLE}
    

    FISHINGCONTAINER = {FRESHFISHING, OCEANFISHING, ICYOCEANFISHING, CAVEFISHING, LAVAFISHING, LAKEFISHING, PARADOXLAKEFISHING}

    HABITAT_FALLBACKS = {
        "swamp" : "forest",
        "badlands" : "desert",
        "volcano" : "mountain",
        "magicforest" : "forest",
        "icybeach" : "beach",
        "bamboojungle" : "jungle",
        "lakeisland" : "lake",
        "riveredge" : "grassland",
        "tundra" : "mountain",
        "facility" : "urban",
        "cyberspace" : "urban",
        "ruins" : "urban",
        "ruinsU" : "urban",
    }

class Rod(Enum):
    OLD = "oldrod"
    GOOD = "goodrod"
    SUPER = "superrod"

class Rarity(Enum):
    COMMON = "common"
    UNCOMMON = "uncommon"
    RARE = "rare"
    ULTRA_RARE = "ultra_rare"