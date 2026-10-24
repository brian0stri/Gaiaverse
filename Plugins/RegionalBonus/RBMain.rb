class RegionBonusConstants
  # Multiplier for damage when regional bonus applies
  REGION_BONUS_MODE_ENABLED = true
  COMBAT_BONUS_MULTIPLIER = 1.05
  EXP_BONUS_MULTIPLIER = 1.2
end

class Pokemon
  attr_accessor :obtain_map
  attr_accessor :region_bonus_applied
  attr_accessor :cached_obtain_map_region

  alias rb_initialize initialize
  def initialize(*args)
    rb_initialize(*args)
    @region_bonus_applied = false
    @cached_obtain_map_region = nil
  end

  def get_obtain_map_region
    return @cached_obtain_map_region if @cached_obtain_map_region
    return nil unless obtain_map
    metadata = GameData::MapMetadata.try_get(obtain_map)
    @cached_obtain_map_region = metadata&.town_map_position&.[](0) # region is first element of map_position
    return @cached_obtain_map_region
  end

end

::Battle::Move.class_eval do
attr_accessor :rb_damage_multiplier

  alias rb_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    rb_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)

    return 1.0 unless user.pbOwnedByPlayer?
    multipliers[:final_damage_multiplier] *= user.determine_battle_regional_bonus
      
  end
end

::Battle::Battler.class_eval do
  attr_accessor :region_bonus_mode_enabled
  attr_accessor :region_bonus_multiplier
  attr_accessor :region_bonus_applied

 alias rb_initialize initialize
 def initialize(*args)
  rb_initialize(*args)
  @region_bonus_multiplier = 1.0
  @region_bonus_mode_enabled = RegionBonusConstants::REGION_BONUS_MODE_ENABLED
  echoln("Regional bonus mode enabled: #{@region_bonus_mode_enabled}") if $DEBUG
  @region_bonus_applied = false
  end

  def determine_battle_regional_bonus
   return 1.0 unless @region_bonus_mode_enabled
   return 1.0 unless $game_map.metadata&.town_map_position


   user_region = pokemon.get_obtain_map_region
   current_region = $game_map.metadata&.town_map_position&.[](0)
   return 1.0 unless user_region && current_region
   return 1.0 unless user_region == current_region

   echoln("User region: #{user_region}, Current region: #{current_region}")

   unless @region_bonus_applied
    @battle.scene.pbShowRegionPopup(self, "region_dmg")
    @region_bonus_applied = true
   end

   return RegionBonusConstants::COMBAT_BONUS_MULTIPLIER
  end
end

class Battle
    alias rb_pbGainExpOne pbGainExpOne
    def pbGainExpOne(*args)
    battler = @battlers[idexBattler]
    pkmn = battler.pokemon
    regional_multiplier = 1.0
    
    if battler.pbOwnedByPlayer?
      user_region = pkmn.get_obtain_map_region
      current_region = $game_map.metadata&.town_map_position&.[](0)
        echoln("User region: #{user_region}, Current region: #{current_region}") if $DEBUG
        if user_region && current_region && user_region == current_region
            regional_multiplier = RegionBonusConstants::EXP_BONUS_MULTIPLIER
            @scene.pbShowRegionPopup(battler, "region_exp")
        end
    end

    exp = (exp * regional_multiplier).to_i
    rb_pbGainExpOne(*args)
    end
end

::Battle::Scene.class_eval do
  def pbShowRegionPopup(battler, icon_name)
    return if !@sprites["pokemon_#{battler.index}"]

    sprite = @sprites["pokemon_#{battler.index}"]
    return if !sprite

    popup = Sprite.new(@viewport)
    popup.bitmap = Bitmap.new("Plugins/RegionalBonus/Graphics/#{icon_name}")
    popup.x = sprite.x
    popup.y = sprite.y - sprite.bitmap.height
    popup.z = 99999
    popup.opacity = 255

    72.times do |i|
      popup.y -= 0.5
      popup.opacity -= 3
      Graphics.update
    end

    popup.dispose
  end
end
