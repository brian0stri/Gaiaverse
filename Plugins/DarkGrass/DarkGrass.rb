module GameData
  module GameData
  class Metadata
    attr_reader :dark_grass_encounter_bgm

    SCHEMA = {
      "SectionName"       => [:id,                   "u"],
      "StartMoney"        => [:start_money,          "u"],
      "StartItemStorage"  => [:start_item_storage,   "*e", :Item],
      "Home"              => [:home,                 "vuuu"],
      "StorageCreator"    => [:real_storage_creator, "s"],
      "WildBattleBGM"     => [:wild_battle_BGM,      "s"],
      "TrainerBattleBGM"  => [:trainer_battle_BGM,   "s"],
      "WildVictoryBGM"    => [:wild_victory_BGM,     "s"],
      "TrainerVictoryBGM" => [:trainer_victory_BGM,  "s"],
      "WildCaptureME"     => [:wild_capture_ME,      "s"],
      "SurfBGM"           => [:surf_BGM,             "s"],
      "BicycleBGM"        => [:bicycle_BGM,          "s"],
      "DarkGrassEncounterBGM" => [:dark_grass_BGM, "s"]

      extend ClassMethodsIDNumbers
    include InstanceMethods

    def self.editor_properties
      return [
        ["StartMoney",        LimitProperty.new(Settings::MAX_MONEY), _INTL("The amount of money that the player starts the game with.")],
        ["StartItemStorage",  GameDataPoolProperty.new(:Item),        _INTL("Items that are already in the player's PC at the start of the game.")],
        ["Home",              MapCoordsFacingProperty, _INTL("Map ID and X/Y coordinates of where the player goes after a loss if no Pokémon Center was visited.")],
        ["StorageCreator",    StringProperty,          _INTL("Name of the Pokémon Storage creator (the storage option is named \"XXX's PC\").")],
        ["WildBattleBGM",     BGMProperty,             _INTL("Default BGM for wild Pokémon battles.")],
        ["TrainerBattleBGM",  BGMProperty,             _INTL("Default BGM for Trainer battles.")],
        ["WildVictoryBGM",    BGMProperty,             _INTL("Default BGM played after winning a wild Pokémon battle.")],
        ["TrainerVictoryBGM", BGMProperty,             _INTL("Default BGM played after winning a Trainer battle.")],
        ["WildCaptureME",     MEProperty,              _INTL("Default ME played after catching a Pokémon.")],
        ["SurfBGM",           BGMProperty,             _INTL("BGM played while surfing.")],
        ["BicycleBGM",        BGMProperty,             _INTL("BGM played while on a bicycle.")],
        ["DarkGrassEncounterBGM", BGMProperty,         _INTL("BGM played during dark grass encounters.")]
      ]
    end

    def initialize
      @wildbattleBGM = hash[:dark_grass_BGM]
    }
  end

  class MapMetadata
    attr_reader :id
    attr_reader :real_name
    attr_reader :outdoor_map
    attr_reader :announce_location
    attr_reader :can_bicycle
    attr_reader :always_bicycle
    attr_reader :teleport_destination
    attr_reader :weather
    attr_reader :town_map_position
    attr_reader :dive_map_id
    attr_reader :dark_map
    attr_reader :safari_map
    attr_reader :snap_edges
    attr_reader :still_reflections
    attr_reader :random_dungeon
    attr_reader :battle_background
    attr_reader :wild_battle_BGM
    attr_reader :trainer_battle_BGM
    attr_reader :wild_victory_BGM
    attr_reader :trainer_victory_BGM
    attr_reader :wild_capture_ME
    attr_reader :town_map_size
    attr_reader :battle_environment
    attr_reader :dark_grass_encounter_BGM

     SCHEMA = {
      "SectionName"       => [:id,                   "u"],
      "Name"              => [:real_name,            "s"],
      "Outdoor"           => [:outdoor_map,          "b"],
      "ShowArea"          => [:announce_location,    "b"],
      "Bicycle"           => [:can_bicycle,          "b"],
      "BicycleAlways"     => [:always_bicycle,       "b"],
      "HealingSpot"       => [:teleport_destination, "vuu"],
      "Weather"           => [:weather,              "eu", :Weather],
      "MapPosition"       => [:town_map_position,    "uuu"],
      "DiveMap"           => [:dive_map_id,          "v"],
      "DarkMap"           => [:dark_map,             "b"],
      "SafariMap"         => [:safari_map,           "b"],
      "SnapEdges"         => [:snap_edges,           "b"],
      "StillReflections"  => [:still_reflections,    "b"],
      "Dungeon"           => [:random_dungeon,       "b"],
      "BattleBack"        => [:battle_background,    "s"],
      "WildBattleBGM"     => [:wild_battle_BGM,      "s"],
      "TrainerBattleBGM"  => [:trainer_battle_BGM,   "s"],
      "WildVictoryBGM"    => [:wild_victory_BGM,     "s"],
      "TrainerVictoryBGM" => [:trainer_victory_BGM,  "s"],
      "WildCaptureME"     => [:wild_capture_ME,      "s"],
      "MapSize"           => [:town_map_size,        "us"],
      "Environment"       => [:battle_environment,   "e", :Environment],
      "Flags"             => [:flags,                "*s"],
      "DarkGrassEncounterBGM" => [:dark_grass_encounter_BGM, "s"]
    }
end

 def self.editor_properties
      return [
        ["ID",                ReadOnlyProperty,        _INTL("ID number of this map.")],
        ["Name",              StringProperty,          _INTL("The name of the map, as seen by the player. Can be different to the map's name as seen in RMXP.")],
        ["Outdoor",           BooleanProperty,         _INTL("If true, this map is an outdoor map and will be tinted according to time of day.")],
        ["ShowArea",          BooleanProperty,         _INTL("If true, the game will display the map's name upon entry.")],
        ["Bicycle",           BooleanProperty,         _INTL("If true, the bicycle can be used on this map.")],
        ["BicycleAlways",     BooleanProperty,         _INTL("If true, the bicycle will be mounted automatically on this map and cannot be dismounted.")],
        ["HealingSpot",       MapCoordsProperty,       _INTL("Map ID of this Pokémon Center's town, and X and Y coordinates of its entrance within that town.")],
        ["Weather",           WeatherEffectProperty,   _INTL("Weather conditions in effect for this map.")],
        ["MapPosition",       RegionMapCoordsProperty, _INTL("Identifies the point on the regional map for this map.")],
        ["DiveMap",           MapProperty,             _INTL("Specifies the underwater layer of this map. Use only if this map has deep water.")],
        ["DarkMap",           BooleanProperty,         _INTL("If true, this map is dark and a circle of light appears around the player. Flash can be used to expand the circle.")],
        ["SafariMap",         BooleanProperty,         _INTL("If true, this map is part of the Safari Zone (both indoor and outdoor). Not to be used in the reception desk.")],
        ["SnapEdges",         BooleanProperty,         _INTL("If true, when the player goes near this map's edge, the game doesn't center the player as usual.")],
        ["StillReflections",  BooleanProperty,         _INTL("If true, reflections of events and the player will not ripple horizontally.")],
        ["Dungeon",           BooleanProperty,         _INTL("If true, this map has a randomly generated layout. See the wiki for more information.")],
        ["BattleBack",        StringProperty,          _INTL("PNG files named 'XXX_bg', 'XXX_base0', 'XXX_base1', 'XXX_message' in Battlebacks folder, where XXX is this property's value.")],
        ["WildBattleBGM",     BGMProperty,             _INTL("Default BGM for wild Pokémon battles on this map.")],
        ["TrainerBattleBGM",  BGMProperty,             _INTL("Default BGM for trainer battles on this map.")],
        ["WildVictoryBGM",    BGMProperty,             _INTL("Default BGM played after winning a wild Pokémon battle on this map.")],
        ["TrainerVictoryBGM", BGMProperty,             _INTL("Default BGM played after winning a Trainer battle on this map.")],
        ["WildCaptureME",     MEProperty,              _INTL("Default ME played after catching a wild Pokémon on this map.")],
        ["MapSize",           MapSizeProperty,         _INTL("The width of the map in Town Map squares, and a string indicating which squares are part of this map.")],
        ["Environment",       GameDataProperty.new(:Environment), _INTL("The default battle environment for battles on this map.")],
        ["Flags",             StringListProperty,      _INTL("Words/phrases that distinguish this map from others.")],
        ["DarkGrassEncounterBGM", BGMProperty,         _INTL("BGM played during dark grass encounters on this map.")]
      ]

      def initialize(hash)
      @id                   = hash[:id]
      @real_name            = hash[:real_name]
      @outdoor_map          = hash[:outdoor_map]
      @announce_location    = hash[:announce_location]
      @can_bicycle          = hash[:can_bicycle]
      @always_bicycle       = hash[:always_bicycle]
      @teleport_destination = hash[:teleport_destination]
      @weather              = hash[:weather]
      @town_map_position    = hash[:town_map_position]
      @dive_map_id          = hash[:dive_map_id]
      @dark_map             = hash[:dark_map]
      @safari_map           = hash[:safari_map]
      @snap_edges           = hash[:snap_edges]
      @still_reflections    = hash[:still_reflections]
      @random_dungeon       = hash[:random_dungeon]
      @battle_background    = hash[:battle_background]
      @wild_battle_BGM      = hash[:wild_battle_BGM]
      @trainer_battle_BGM   = hash[:trainer_battle_BGM]
      @wild_victory_BGM     = hash[:wild_victory_BGM]
      @trainer_victory_BGM  = hash[:trainer_victory_BGM]
      @wild_capture_ME      = hash[:wild_capture_ME]
      @town_map_size        = hash[:town_map_size]
      @battle_environment   = hash[:battle_environment]
      @flags                = hash[:flags]           || []
      @pbs_file_suffix      = hash[:pbs_file_suffix] || ""
      @dark_grass_encounter_BGM = hash[:dark_grass_encounter_BGM]
    end
    end

  class TerrainTag

    GameData::TerrainTag.register({
  :id                     => :DarkTallGrass,
  :id_number              => 10,
  :deep_bush              => false,
  :land_wild_encounters   => true,
  :double_wild_encounters => true,
  :battle_environment     => :DarkTallGrass,
  :must_walk              => false,
  :shows_grass_rustle     => true,
})
end
end

module GameData

  class EncounterType

  GameData::EncounterType.register({
  :id             => :DarkGrass_Day,
  :type           => :land,
  :trigger_chance => 21
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass_Night,
  :type           => :land,
  :trigger_chance => 21
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass_Morning,
  :type           => :land,
  :trigger_chance => 21
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass_Afternoon,
  :type           => :land,
  :trigger_chance => 21
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass_Evening,
  :type           => :land,
  :trigger_chance => 21
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass_PokeRadar,
  :type           => :land,
  :trigger_chance => 20
  })
  GameData::EncounterType.register({
  :id             => :DarkGrass,
  :type           => :land,
  :trigger_chance => 21
})

end
end

def pbGetWildBattleBGM(_wildParty)
  return $PokemonGlobal.nextBattleBGM.clone if $PokemonGlobal.nextBattleBGM
  ret = nil
  if !ret && $game_map.terraintag == :DarkTallGrass
    # Check map metadata
    music = $game_map.metadata&.dark_grass_battle_BGM
    ret = pbStringToAudioFile(music) if music && music != ""
    if !ret
      # Check global metadata
      music = GameData::Metadata.get.dark_grass_battle_BGM
      ret = pbStringToAudioFile(music) if music && music != ""
    end
    ret = pbStringToAudioFile("Battle wild") if !ret
  end

  else

    music = $game_map.metadata&.wild_battle_BGM
    ret = pbStringToAudioFile(music) if music && music != ""
  end
  if !ret
    # Check global metadata
    music = GameData::Metadata.get.wild_battle_BGM
    ret = pbStringToAudioFile(music) if music && music != ""
  end
  ret = pbStringToAudioFile("Battle wild") if !ret
  return ret
end
end
