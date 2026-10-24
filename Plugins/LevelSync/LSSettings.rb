class SyncConstants
  def self.load_ls_metadata(file_path)
    metadata = {}
    return metadata unless File.exist?(file_path)

    File.foreach(file_path) do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      next unless line.include?("=")

      key, value = line.split("=", 2)
      metadata[key.strip] = value.strip
    end

    return metadata
  end

  def self.parse_list(value)
    return [] if value.nil? || value.empty?
    value.split(",").map { |v| v.strip }.reject { |v| v.empty? }
  end

  def self.parse_int_list(value)
    parse_list(value).map { |v| v.to_i }
  end

  def self.parse_color(value)
    parts = parse_int_list(value)
    return nil if parts.length < 3
    return Color.new(parts[0], parts[1], parts[2])
  end

  attr_accessor :LSEnabled
  attr_accessor :LSEnabledGlobal
  attr_accessor :LSWildPokemonGlobal
  attr_accessor :LSTrainerPokemonGlobal
  attr_accessor :LSLevel
  attr_accessor :LSIVs
  attr_accessor :LSEVs
  attr_accessor :LSMoveBP
  attr_accessor :LSBaseStats
  attr_accessor :LSExperience
  attr_reader :LSEnableUser
  attr_accessor :LSEnableUser
  attr_reader :LSMode
  attr_accessor :LSModeEnabled
  attr_accessor :LSMaxLevel
  attr_accessor :LSMaxEV
  attr_accessor :LSMaxIV
  attr_accessor :LSMaxBP
  attr_accessor :LSMaxHPBaseStat
  attr_accessor :LSMaxAttackBaseStat
  attr_accessor :LSMaxDefenseBaseStat
  attr_accessor :LSMaxSpecialAttackBaseStat
  attr_accessor :LSMaxSpecialDefenseBaseStat
  attr_accessor :LSMaxSpeedBaseStat
  attr_reader   :LSDisplayWarning
  attr_reader   :LSWarningText
  attr_reader   :LSTextColor
  attr_reader   :LSTextShadowColor
  attr_accessor :LSSpecificWild
  attr_accessor :LSSpecificTrainers
  attr_accessor :LSTrainerTypes
  attr_accessor :LSLevelTrainers
  attr_accessor :LSLevelEncounters
  attr_accessor :LSMapsTrainers
  attr_accessor :LSMapsWild
  attr_accessor :LSByBadgeCount
  attr_accessor :LSLevelByBadgeCount
  attr_accessor :LSMapsTrainersArr
  attr_accessor :LSMapsWildArr
  attr_accessor :LSSyncExpMode

    metadata = load_ls_metadata("Plugins/LevelSync/lsmetadata.txt")
    WarningText = metadata["WarningText"] || "Level Sync is enabled."
    MainColor = parse_color(metadata["MainColor"])
    ShadowColor = parse_color(metadata["ShadowColor"])
    BattleMessage = metadata["BattleMessage"] || "Level Sync is now in effect!"
    WildEncoutnerList = parse_list(metadata["WildEncounters"])
    WildMapList = parse_int_list(metadata["WildMaps"])
    TrainerMapList = parse_int_list(metadata["TrainerMaps"])
    TrainerIDList = parse_list(metadata["TrainerIDs"])
    TrainerTypeList = parse_list(metadata["TrainerTypes"])
    LevelCapsByBadgeCount = parse_int_list(metadata["LevelCapsByBadgeCount"])

  def initialize
    # Display Level Sync activation message.
    # Developers may customize this text to better fit their game's tone.

    @LSWarningText = _INTL(WarningText)

    #These settings are altered with the options menu and unless you know exactly all of the 
    #variable types and useage please do not change these as it may cause unintended consequences. 
    #If you want to change the default settings, it's recommended to do so through the debug menu in-game.
    @LSEnabled = true
    @LSEnabledGlobal = true
    @LSWildPokemonGlobal = true
    @LSTrainerPokemonGlobal = true
    @LSLevel = true
    @LSIVs = true
    @LSEVs = true
    @LSMoveBP = true
    @LSBaseStats = true
    @LSExperience = true
    @LSEnableUser = true
    @LSMode = [:Max, :Min, :Random, :BadgeCount, :UserValue]
    @LSModeEnabled = :Max #default is :Max, which syncs the Pokemon's stats to the maximum possible values based on the trainer's Pokemon.
    @LSMaxLevel = 100  
    @LSMaxEV = 252      
    @LSMaxIV = 31       
    @LSMaxBP= 999
    @LSMaxHPBaseStat = 255
    @LSMaxAttackBaseStat = 255
    @LSMaxDefenseBaseStat = 255
    @LSMaxSpecialAttackBaseStat = 255
    @LSMaxSpecialDefenseBaseStat = 255
    @LSMaxSpeedBaseStat = 255
    @LSDisplayWarning = true
    @LSTextColor = MainColor || Color.new(255, 120, 0)
    @LSTextShadowColor = ShadowColor || Color.new(0, 0, 0)
    @LSSpecificWild = :Encounters
    @LSSpecificTrainers = :Trainers
    @LSTrainerTypes = TrainerTypeList || []
    @LSLevelTrainers = TrainerIDList || []
    @LSLevelEncounters = WildEncoutnerList || []
    @LSMapsWildArr = WildMapList || []
    @LSMapsTrainersArr = TrainerMapList || []
    @LSByBadgeCount = false
    @LSLevelByBadgeCount = LevelCapsByBadgeCount || []
    @LSSyncExpMode = :Reduced
  end


  def LSBattleMessage
  @LSBattleMessage = _INTL(BattleMessage) ||  _INTL("Level Sync is now in effect!")
  end

end

#===============================================================================
#
#===============================================================================
module PropertyMixin
  attr_reader :name

  def get
    return @get_proc&.call
  end

  def set(*args)
    @set_proc&.call(*args)
  end
end

#===============================================================================
#
#===============================================================================
class EnumOption
  include PropertyMixin
  attr_reader :values

  def initialize(name, values, get_proc, set_proc)
    @name     = name
    @values   = values.map { |val| _INTL(val) }
    @get_proc = get_proc
    @set_proc = set_proc
  end

  def next(current)
    index = current + 1
    index = @values.length - 1 if index > @values.length - 1
    return index
  end

  def prev(current)
    index = current - 1
    index = 0 if index < 0
    return index
  end
end

#===============================================================================
#
#===============================================================================
class NumberOption
  include PropertyMixin
  attr_reader :lowest_value
  attr_reader :highest_value

  def initialize(name, range, get_proc, set_proc)
    @name = name
    case range
    when Range
      @lowest_value  = range.begin
      @highest_value = range.end
    when Array
      @lowest_value  = range[0]
      @highest_value = range[1]
    end
    @get_proc = get_proc
    @set_proc = set_proc
  end

  def next(current)
    index = current + @lowest_value
    index += 1
    index = @lowest_value if index > @highest_value
    return index - @lowest_value
  end

  def prev(current)
    index = current + @lowest_value
    index -= 1
    index = @highest_value if index < @lowest_value
    return index - @lowest_value
  end
end

#===============================================================================
#
#===============================================================================
class SliderOption
  include PropertyMixin
  attr_reader :lowest_value
  attr_reader :highest_value

  def initialize(name, range, get_proc, set_proc)
    @name          = name
    @lowest_value  = range[0]
    @highest_value = range[1]
    @interval      = range[2]
    @get_proc      = get_proc
    @set_proc      = set_proc
  end

  def next(current)
    index = current + @lowest_value
    index += @interval
    index = @highest_value if index > @highest_value
    return index - @lowest_value
  end

  def prev(current)
    index = current + @lowest_value
    index -= @interval
    index = @lowest_value if index < @lowest_value
    return index - @lowest_value
  end
end

class Window_MultiSelect < Window_DrawableCommand
  attr_reader :selected

  CHECK_COLOR      = Color.new(80, 200, 120)
  CHECK_SHADOW     = Color.new(40, 120, 80)

  def initialize(values, selected, name_proc = nil)
    @values     = values
    @selected   = selected.clone
    @name_proc  = name_proc
    super(0, 0, Graphics.width, Graphics.height)
    self.index = 0
  end

  def itemCount
    return @values.length + 3  # Select All, Clear All, Confirm
  end

  def drawItem(index, _count, rect)
    rect = drawCursor(index, rect)

    if index < @values.length
      value = @values[index]
      name  = display_name(value)
      checked = @selected.include?(value)
      text = checked ? "✔ #{name}" : name

      pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                       text,
                       checked ? CHECK_COLOR : self.baseColor,
                       checked ? CHECK_SHADOW : self.shadowColor)
    elsif index == @values.length
      draw_special(rect, _INTL("Select All"))
    elsif index == @values.length + 1
      draw_special(rect, _INTL("Clear All"))
    else
      draw_special(rect, _INTL("Confirm"))
    end
  end

  def draw_special(rect, text)
    pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
                     text, self.baseColor, self.shadowColor)
  end

  def update
    super
    if Input.trigger?(Input::USE)
      handle_selection
    end
  end

  def handle_selection
    if self.index < @values.length
      value = @values[self.index]
      if @selected.include?(value)
        @selected.delete(value)
      else
        @selected << value
      end
      refresh
    elsif self.index == @values.length
      @selected = @values.clone
      refresh
    elsif self.index == @values.length + 1
      @selected.clear
      refresh
    else
      @done = true
    end
  end

  def done?
    return @done
  end

  private

  def display_name(value)
    return @name_proc.call(value) if @name_proc
    return value.respond_to?(:real_name) ? value.real_name : value.to_s
  end
end

class MultiSelectOption
  include PropertyMixin

  def initialize(name, parameters, get_proc, set_proc)
    @name        = name
    @values_proc = parameters[0]
    @name_proc   = parameters[1]
    @get_proc    = get_proc
    @set_proc    = set_proc
  end

  # Window expects integer
  def get
    return 0
  end

  # DO NOTHING HERE
  def set(value, scene = nil)
  end

  # LEFT
def prev(current)
  changed = open_multi_select
  return current
end

def next(current)
  changed = open_multi_select
  return current
end

  def values
    [display_text]
  end

  private

  def open_multi_select
  return false unless @values_proc
  return false unless @get_proc
  return false unless @set_proc

  values   = @values_proc.call
  selected = (@get_proc.call || []).clone

  viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  viewport.z = 99999

  window = Window_MultiSelect.new(values, selected, @name_proc)
  window.viewport = viewport
  window.active = true

  loop do
    Graphics.update
    Input.update
    window.update
    break if window.done?
  end

  old = (@get_proc.call || []).clone
  @set_proc.call(window.selected)
  new = (@get_proc.call || []).clone

  window.dispose
  viewport.dispose

  return old != new
end

  def display_text
    list = @get_proc.call || []
    all  = @values_proc.call

    return _INTL("None") if list.empty?
    return _INTL("All")  if list.length == all.length
    return _INTL("{1} selected", list.length)
  end
end

#===============================================================================
# Main options list
#===============================================================================
class Window_LevelSyncSettings < Window_DrawableCommand
  attr_reader :value_changed

  SEL_NAME_BASE_COLOR    = Color.new(192, 120, 0)
  SEL_NAME_SHADOW_COLOR  = Color.new(248, 176, 80)
  SEL_VALUE_BASE_COLOR   = Color.new(248, 48, 24)
  SEL_VALUE_SHADOW_COLOR = Color.new(248, 136, 128)

  def initialize(options, x, y, width, height)
    @options = options
    @values = []
    @value_changed = false
    @options.length.times { |i| @values[i] = 0 }
    super(x, y, width, height)
  end

  def [](i)
    return @values[i]
  end

  def []=(i, value)
    @values[i] = value
    refresh
  end

  def setValueNoRefresh(i, value)
    @values[i] = value
  end

  def itemCount
    return @options.length + 1
  end

 def drawItem(index, _count, rect)
  rect = drawCursor(index, rect)
  return draw_close(rect) if index == @options.length

  option = @options[index]
  optionwidth = rect.width * 9 / 20
  sel_index = self.index

  # Draw option name
  pbDrawShadowText(self.contents, rect.x, rect.y, optionwidth, rect.height,
    option.name,
    (index == sel_index) ? SEL_NAME_BASE_COLOR : self.baseColor,
    (index == sel_index) ? SEL_NAME_SHADOW_COLOR : self.shadowColor)

  # Draw option value
  case option
  when EnumOption
    value = option.values[self[index]]
    xpos = optionwidth + rect.x
    pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height,
      value,
      SEL_VALUE_BASE_COLOR,
      SEL_VALUE_SHADOW_COLOR)

  when SliderOption
    value = (@options[index].lowest_value + self[index]).to_s
    xpos = optionwidth + rect.x
    pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height,
      value,
      SEL_VALUE_BASE_COLOR,
      SEL_VALUE_SHADOW_COLOR)

  when NumberOption
    value = (@options[index].lowest_value + self[index]).to_s
    xpos = optionwidth + rect.x
    pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height,
      value,
      SEL_VALUE_BASE_COLOR,
      SEL_VALUE_SHADOW_COLOR)

  else
    # MultiSelectOption
    value = option.values[0]
    xpos = optionwidth + rect.x
    pbDrawShadowText(self.contents, xpos, rect.y, optionwidth, rect.height,
      value,
      SEL_VALUE_BASE_COLOR,
      SEL_VALUE_SHADOW_COLOR)
  end
end

  def draw_close(rect)
    pbDrawShadowText(self.contents, rect.x, rect.y, rect.width, rect.height,
      _INTL("Close"),
      self.baseColor,
      self.shadowColor)
  end

  def update
    oldindex = self.index
    @value_changed = false
    super

    if self.active && self.index < @options.length
      if Input.repeat?(Input::LEFT)
      current = self[self.index] || 0
      current = 0 if current >= @options[self.index].values.length rescue current
      self[self.index] = @options[self.index].prev(current)        
      @value_changed = true
      elsif Input.repeat?(Input::RIGHT)
      current = self[self.index] || 0
      current = 0 if current >= @options[self.index].values.length rescue current
      self[self.index] = @options[self.index].next(current)
      @value_changed = true
      end
    end

    refresh if oldindex != self.index
  end
end

#===============================================================================
# Options main screen
#===============================================================================
class Debug_OptionsScreen
  def initialize(scene)
    @scene = scene
  end

  attr_reader :sprites
  attr_reader :in_load_screen
  def pbStartScreen
    @scene.pbStartScene
    @scene.pbOptions
    @scene.pbEndScene
  end
end

MenuHandlers.add(:debug_menu, :ilevel_sync_options, {
  "name"        => _INTL("Edit Level Sync Options"),
  "parent"      => :editors_menu,
  "description" => _INTL("Edit Level Sync options."),
  "effect"      => proc {
    pbEditLevelSyncOptions
  }
})

def pbEditLevelSyncOptions
  scene = LevelSyncSettings_Scene.new
  screen = LevelSyncSettingsScreen.new(scene)
  screen.pbStartScreen
end

class LevelSyncSettings_Scene
  attr_reader :sprites
  attr_reader :in_load_screen

def pbStartScene(in_load_screen = false)
  @in_load_screen = in_load_screen

  # Build options
  @options = []
  @hashes  = []

  MenuHandlers.each_available(:ls_options_menu) do |key, hash, name|
    next unless key.to_s.start_with?("LS_")
    @options << hash["type"].new(
      name,
      hash["parameters"],
      hash["get_proc"],
      hash["set_proc"]
    )
    @hashes << hash
  end

  # Create viewport and sprites
  @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
  @viewport.z = 99999
  @sprites = {}

  addBackgroundOrColoredPlane(@sprites, "bg", "optionsbg",
    Color.new(192, 200, 208), @viewport)

  @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
    _INTL("Options"), 0, -16, Graphics.width, 64, @viewport
  )
  @sprites["title"].back_opacity = 0

  @sprites["textbox"] = pbCreateMessageWindow
  pbSetSystemFont(@sprites["textbox"].contents)

  # Create option window
  @sprites["option"] = Window_LevelSyncSettings.new(
    @options,
    0,
    @sprites["title"].y + @sprites["title"].height - 16,
    Graphics.width,
    Graphics.height - (@sprites["title"].y + @sprites["title"].height - 16) - @sprites["textbox"].height
  )
  @sprites["option"].viewport = @viewport
  @sprites["option"].visible  = true

  # NOW initialize stored values correctly
  @options.length.times do |i|
    val = @options[i].get || 0

    if @options[i].is_a?(SliderOption)
      val = val - @options[i].lowest_value
    end

    @sprites["option"].setValueNoRefresh(i, val)
  end

  @sprites["option"].refresh
  pbChangeSelection
  pbDeactivateWindows(@sprites)
  pbFadeInAndShow(@sprites) { pbUpdate }
end

def pbChangeSelection
  index = @sprites["option"].index
  option_list = []

  hash = visible_option_hashes[index]

  @sprites["textbox"].letterbyletter = false

  description = ""
  if hash
    if hash["description"].is_a?(Proc)
      description = hash["description"].call
    elsif hash["description"]
      description = _INTL(hash["description"])
    end
  else
    description = _INTL("Close the screen.")
  end

  @sprites["textbox"].text = description
end

def visible_option_hashes
  list = []
  MenuHandlers.each_available(:ls_options_menu) do |key, hash, name|
    next unless key.to_s.start_with?("LS_")
    list << hash
  end
  return list
end

def pbOptions
  pbActivateWindow(@sprites, "option") do
    loop do
      Graphics.update
      Input.update
      pbUpdate

      if @sprites["option"].value_changed
        index = @sprites["option"].index
        @options[index].set(@sprites["option"][index], self)

        # Rebuild menu when options change that may affect conditional visibility
        if @options[index].is_a?(MultiSelectOption) || @options[index].is_a?(EnumOption)
          rebuild_options
          pbChangeSelection
        end
      end

      break if Input.trigger?(Input::BACK)
      break if Input.trigger?(Input::USE) &&
               @sprites["option"].index == @options.length
    end
  end
end

  def rebuild_options
  old_index = @sprites["option"].index

  @options.clear
  @hashes.clear

  MenuHandlers.each_available(:ls_options_menu) do |key, hash, name|
    next unless key.to_s.start_with?("LS_")
    @options << hash["type"].new(
      name,
      hash["parameters"],
      hash["get_proc"],
      hash["set_proc"]
    )
    @hashes << hash
  end

  @sprites["option"].dispose

  @sprites["option"] = Window_LevelSyncSettings.new(
    @options,
    0,
    @sprites["title"].y + @sprites["title"].height - 16,
    Graphics.width,
    Graphics.height - (@sprites["title"].y + @sprites["title"].height - 16) - @sprites["textbox"].height
  )
  @sprites["option"].viewport = @viewport

  @options.length.times do |i|
    val = @options[i].get || 0
    val -= @options[i].lowest_value if @options[i].is_a?(SliderOption)
    @sprites["option"].setValueNoRefresh(i, val)
  end

  @sprites["option"].index = [old_index, @options.length - 1].min
  @sprites["option"].refresh
end

  def pbEndScene
    pbPlayCloseMenuSE
    pbFadeOutAndHide(@sprites) { pbUpdate }
    pbDisposeMessageWindow(@sprites["textbox"])
    pbDisposeSpriteHash(@sprites)
    pbUpdateSceneMap
    @viewport.dispose
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end
end
#===============================================================================
#
#===============================================================================
class LevelSyncSettingsScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen(in_load_screen = false)
    @scene.pbStartScene(in_load_screen)
    @scene.pbOptions
    @scene.pbEndScene
  end
end

#===============================================================================
# Options Menu commands
#===============================================================================
MenuHandlers.add(:ls_options_menu, :LS_Enable, {
  "name"        => _INTL("Level Sync"),
  "order"       => 10,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Enable or disable Level Sync. Please note that changing this setting will only affect battles that start after changing it, and won't affect battles that are already in progress."),
  "get_proc"    => proc { next $LSSettings.LSEnabled ? 1 : 0 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSEnabled == (value == 1)
    $LSSettings.LSEnabled = (value == 1)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Global, {
  "name"        => _INTL("Global Level Sync"),
  "order"       => 20,
  "type"        => EnumOption,
  "condition"   => proc { next $LSSettings.LSEnabled },
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Enables or disables level sync for ALL battles."),
  "get_proc"    => proc { next $LSSettings.LSEnabledGlobal ? 1 : 0 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSEnabledGlobal == (value == 1)
    $LSSettings.LSEnabledGlobal = (value == 1)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_StatOverride, {
  "name"        => _INTL("Synced Stat Selection"),
  "order"       => 21,
  "type"        => MultiSelectOption,
  "condition"   => proc { next $LSSettings.LSEnabled && !$LSSettings.LSEnabledGlobal },
  "parameters"  => [
    proc { [:Level, :IVs, :EVs, :MoveBP, :BaseStats, :Experience] },
    proc { |sym| sym.to_s }
  ],
  "description" => _INTL("Choose which stats Level Sync will sync."),
  "get_proc"    => proc {
    list = []
    list << :Level      if $LSSettings.LSLevel
    list << :IVs        if $LSSettings.LSIVs
    list << :EVs        if $LSSettings.LSEVs
    list << :MoveBP     if $LSSettings.LSMoveBP
    list << :BaseStats  if $LSSettings.LSBaseStats
    list << :Experience if $LSSettings.LSExperience
    next list
  },
  "set_proc"    => proc { |selected|
    $LSSettings.LSLevel      = selected.include?(:Level)
    $LSSettings.LSIVs        = selected.include?(:IVs)
    $LSSettings.LSEVs        = selected.include?(:EVs)
    $LSSettings.LSMoveBP     = selected.include?(:MoveBP)
    $LSSettings.LSBaseStats  = selected.include?(:BaseStats)
    $LSSettings.LSExperience = selected.include?(:Experience)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Wild, {
  "name"        => _INTL("Wild Battles Level Sync"),
  "order"       => 22,
  "type"        => EnumOption,
  "condition"   => proc { next !$LSSettings.LSEnabledGlobal },
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Enable or disable Level Sync for ALL Wild Battles."),
  "get_proc"    => proc { next $LSSettings.LSWildPokemonGlobal ? 1 : 0 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSWildPokemonGlobal == (value == 1)
    $LSSettings.LSWildPokemonGlobal = (value == 1)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Specific_Wild, {
  "name"        => _INTL("Specific Wild Battles"),
  "order"       => 23,
  "type"        => EnumOption,
  "condition"   => proc { next !$LSSettings.LSWildPokemonGlobal && !$LSSettings.LSEnabledGlobal },
  "parameters"  => [_INTL("Encounters"), _INTL("Maps")],
  "description" => _INTL("Level Sync specific wild battles by encounter type or map."),
  "get_proc"    => proc { 
    case $LSSettings.LS_Specific_Wild
    when :Encounters then next 0
    when :Maps then next 1
    end
  },
  "set_proc"    => proc { |value, scene|
    new_value = (value == 0 ? :Encounters : value == 1 ? :Maps : :All)
    next if $LSSettings.LS_Specific_Wild == new_value
    $LSSettings.LS_Specific_Wild = new_value
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Encounters, {
  "name"        => _INTL("Encounter Type Sync"),
  "order"       => 24,
  "type"        => MultiSelectOption,
  "parameters"  => [
    proc { GameData::EncounterType::DATA.keys },
    proc { |id| GameData::EncounterType.get(id).real_name }
  ],
  "get_proc"    => proc { $LSSettings.LSLevelEncounters ||= [] },
  "set_proc"    => proc { |val| $LSSettings.LSLevelEncounters = val },
  "condition"   => proc {
    next $LSSettings.LSEnabledGlobal && 
        !$LSSettings.LSWildPokemonGlobal &&
         $LSSettings.LS_Specific_Wild == :Encounters
  },
  "description" => _INTL("Enable Level Sync for specific wild encounter types.")
})

MenuHandlers.add(:ls_options_menu, :LS_Maps_Wild, {
  "name"        => _INTL("Map-Based Sync"),
  "order"       => 25,
  "type"        => MultiSelectOption,
  "parameters"  => [
    proc { GameData::EncounterType::DATA.keys() },
    proc { |id| GameData::EncounterType.get(id).real_name }
  ],
  "get_proc"    => proc { $LSSettings.LSMapsWild ||= [] },
  "set_proc"    => proc { |val| $LSSettings.LSMapsWild = val },
  "condition"   => proc { 
    next ($LSSettings.LSSpecificWild == :Maps)
  },
  "description" => _INTL("Enable Level Sync for specific maps."),
})

MenuHandlers.add(:ls_options_menu, :LS_Trainers, {
  "name"        => _INTL("Trainer Battles Level Sync"),
  "order"       => 26,
  "type"        => EnumOption,
  "condition"   => proc { next !$LSSettings.LSEnabledGlobal },
  "parameters"  => [_INTL("Off"), _INTL("On")],
  "description" => _INTL("Enable or disable Level Sync for ALL Trainer Battles."),
  "get_proc"    => proc { next $LSSettings.LSTrainerPokemonGlobal ? 1 : 0 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSTrainerPokemonGlobal == (value == 1)
    $LSSettings.LSTrainerPokemonGlobal = (value == 1)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Specific_Trainers, {
  "name"        => _INTL("Specific Trainer Types"),
  "order"       => 27,
  "type"        => EnumOption,
  "condition"   => proc { next !$LSSettings.LSEnabledGlobal && !$LSSettings.LSTrainerPokemonGlobal },
  "parameters"  => [_INTL("Class"), _INTL("Maps")],
  "description" => _INTL("Enable Level Sync for specific trainer types or all trainers on specified maps."),
  "get_proc"    => proc { next $LSSettings.LSTrainerTypes ? 1 : 0 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSSpecificTrainers == (value == 0 ? :Class : :Maps)
    $LSSettings.LSSpecificTrainers = (value == 0 ? :Class : value == 1 ? :Maps : :All)
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Maps_Trainers, {
  "name"        => _INTL("Map-Based Sync"),
  "order"       => 28,
  "type"        => MultiSelectOption,
  "parameters"  => [
    proc { GameData::EncounterType::DATA.keys() },
    proc { |id| GameData::EncounterType.get(id).real_name }
  ],
  "get_proc"    => proc { $LSSettings.LSMapsTrainers ||= [] },
  "set_proc"    => proc { |val| $LSSettings.LSMapsTrainers = val },
  "condition"   => proc { 
    next ($LSSettings.LSSpecificTrainers == :Maps)
  },
  "description" => _INTL("Enable Level Sync for specific maps."),
})

MenuHandlers.add(:ls_options_menu, :LS_Trainer_Classes, {
  "name"        => _INTL("Trainer Class Sync"),
  "order"       => 29,
  "type"        => MultiSelectOption,
  "parameters"  => [
    proc { GameData::TrainerType::DATA.keys },
    proc { |id| GameData::TrainerType.get(id).real_name },
    proc { |list|
      return _INTL("None") if list.empty?
      list.map { |id| GameData::TrainerType.get(id).real_name }.join(", ")
    }
  ],
  "get_proc"    => proc { $LSSettings.LSTrainerClasses ||= [] },
  "set_proc"    => proc { |val| $LSSettings.LSTrainerClasses = val },
  "condition"   => proc {
    next $LSSettings.LSTrainerPokemonGlobal &&
         $LSSettings.LSSpecificTrainers == :Encounters
  },
  "description" => _INTL("Enable Level Sync for specific trainer classes.")
})



MenuHandlers.add(:ls_options_menu, :LS_Mode_Selection, {
  "name"        => _INTL("Mode Selection"),
  "order"       => 30,
  "type"        => EnumOption,
  "parameters"  => [_INTL("Max"), _INTL("Min"), _INTL("Random"), _INTL("Badge Count"), _INTL("User Value")],
  "description" => _INTL("Choose how the game picks the pokemon on the opposing side to sync."),
  "get_proc"    => proc { 
    case $LSSettings.LSModeEnabled
    when :Max then next 0
    when :Min then next 1
    when :Random then next 2
    when :BadgeCount then next 3
    when :UserValue then next 4
    else next 0
    end
  },
  "set_proc"    => proc { |value, scene|
    new_mode = case value
    when 0 then :Max
    when 1 then :Min
    when 2 then :Random
    when 3 then :BadgeCount
    when 4 then :UserValue
    else :Max
    end
    next if new_mode == $LSSettings.LSModeEnabled
    $LSSettings.LSModeEnabled = new_mode
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Max_Level, {
  "name"        => _INTL("Max Level"),
  "order"       => 31,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue },
  "parameters"  => [1, 100, 1],
  "description" => _INTL("Set the maximum level that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxLevel },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxLevel
    $LSSettings.LSMaxLevel = value
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Max_EV, {
  "name"        => _INTL("Max EV"),
  "order"       => 32,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue },
  "parameters"  => [0, 252, 4],
  "description" => _INTL("Set the maximum EVs that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxEV },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxEV
    $LSSettings.LSMaxEV = value
  }
})

MenuHandlers.add(:ls_options_menu, :LS_Max_IV, {
  "name"        => _INTL("Max IV"),
  "order"       => 33,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue },
  "parameters"  => [0, 31, 1],
  "description" => _INTL("Set the maximum IVs that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxIV },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxIV
    $LSSettings.LSMaxIV = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxBP, {
  "name"        => _INTL("Max BP"),
  "order"       => 34,
  "type"        => SliderOption,
  "condition"   => proc { 
    next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSMoveBP },
  "parameters"  => [0, 990, 10],
  "description" => _INTL("Set the maximum BP that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxBP },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxBP
    $LSSettings.LSMaxBP = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxHPBaseStat, {
  "name"        => _INTL("Max HP Base Stat"),
  "order"       => 35,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum HP base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxHPBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxHPBaseStat
    $LSSettings.LSMaxHPBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxAttackBaseStat, {
  "name"        => _INTL("Max Attack Base Stat"),
  "order"       => 36,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum Attack base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxAttackBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxAttackBaseStat
    $LSSettings.LSMaxAttackBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxDefenseBaseStat, {
  "name"        => _INTL("Max Defense Base Stat"),
  "order"       => 37,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum Defense base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxDefenseBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxDefenseBaseStat
    $LSSettings.LSMaxDefenseBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxSpecialAttackBaseStat, {
  "name"        => _INTL("Max Special Attack Base Stat"),
  "order"       => 38,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum Special Attack base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxSpecialAttackBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxSpecialAttackBaseStat
    $LSSettings.LSMaxSpecialAttackBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxSpecialDefenseBaseStat, {
  "name"        => _INTL("Max Special Defense Base Stat"),
  "order"       => 39,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum Special Defense base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxSpecialDefenseBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxSpecialDefenseBaseStat
    $LSSettings.LSMaxSpecialDefenseBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LSMaxSpeedBaseStat, {
  "name"        => _INTL("Max Speed Base Stat"),
  "order"       => 40,
  "type"        => SliderOption,
  "condition"   => proc { next $LSSettings.LSModeEnabled == :UserValue && $LSSettings.LSBaseStats },
  "parameters"  => [1, 255, 1],
  "description" => _INTL("Set the maximum Speed base stat that Level Sync can sync to. Only available in User Value mode."),
  "get_proc"    => proc { next $LSSettings.LSMaxSpeedBaseStat },
  "set_proc"    => proc { |value, scene|
    next if value == $LSSettings.LSMaxSpeedBaseStat
    $LSSettings.LSMaxSpeedBaseStat = value
  }
})

MenuHandlers.add(:ls_options_menu, :LS_ExperienceMode, {
  "name"        => _INTL("Experience Level Sync Options"),
  "order"       => 41,
  "type"        => EnumOption,
  "condition"   => proc { next $LSSettings.LSEnabled && $LSSettings.LSExperience },
  "parameters"  => [_INTL("Reduced"), _INTL("Skip")],
  "description" => _INTL("Reduce the amount of experience gained from synced battles, or skip experience gain entirely."),
  "get_proc"    => proc { next $LSSettings.LSSyncExpMode == :Reduced ? 0 : 1 },
  "set_proc"    => proc { |value, scene|
    next if $LSSettings.LSSyncExpMode == (value == 0 ? :Reduced : :Skip)
    $LSSettings.LSSyncExpMode = (value == 0 ? :Reduced : :Skip)
  }
})

# Create alias so SaveData can find "LSSettings" class constant
LSSettings = SyncConstants