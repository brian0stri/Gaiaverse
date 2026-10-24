class GameStats
  attr_accessor :foundOddKeystone
  attr_accessor :expeditionRanks
  attr_accessor :currentRegion
  attr_accessor :playerStarterLiscenses

  alias gv_player_stats_initialize initialize unless method_defined?(:gv_player_stats_initialize)
  def initialize(*args)
    gv_player_stats_initialize(*args)
    @foundOddKeystone = false
    @playerStarterLiscenses = []
    @currentRegion = nil
    @expeditionRanks = []
    @collectedRedOrb = false
    @collectedBlueOrb = false
    @expeditionPoints = []
  end
end

class Player < Trainer
  attr_accessor :foundOddKeystone
  attr_accessor :expeditionRanks
  attr_accessor :currentRegion
  attr_accessor :playerStarterLiscenses

  alias gv_player_initialize initialize unless method_defined?(:gv_player_initialize)
  def initialize(name, trainer_type)
    gv_player_initialize(name, trainer_type)
    @foundOddKeystone = false
    @playerStarterLiscenses = []
    @currentRegion = nil
    @expeditionRanks = [0,0,0,0]
    @expeditionPoints = [0,0,0,0]
    @collectedRedOrb = false
    @collectedBlueOrb = false
    @collectedLustrousOrb = false
    @collectedGriseousOrb = false
    @collectedAdamantOrb = false
    @inWuldZone = false
    @HMFieldPointBonusTimerEnabled = true
    @HMFieldPointBonusTimer = 180
    @HMFieldPointBonusTimerMax = 180
  end

  def ensure_expedition_data
    @foundOddKeystone = false if !instance_variable_defined?(:@foundOddKeystone)
    @playerStarterLiscenses ||= []
    @currentRegion = nil if !instance_variable_defined?(:@currentRegion)
    @current_region = @currentRegion if !instance_variable_defined?(:@current_region)
    @expeditionRanks ||= [0,0,0,0]
    @expeditionPoints ||= [0,0,0,0]
    4.times do |i|
      @expeditionRanks[i] ||= 0
      @expeditionPoints[i] ||= 0
    end
    @collectedRedOrb = false if !instance_variable_defined?(:@collectedRedOrb)
    @collectedBlueOrb = false if !instance_variable_defined?(:@collectedBlueOrb)
    @collectedLustrousOrb = false if !instance_variable_defined?(:@collectedLustrousOrb)
    @collectedGriseousOrb = false if !instance_variable_defined?(:@collectedGriseousOrb)
    @collectedAdamantOrb = false if !instance_variable_defined?(:@collectedAdamantOrb)
    @inWildZone = false if !instance_variable_defined?(:@inWildZone)
    @inWuldZone = @inWildZone if !instance_variable_defined?(:@inWuldZone)
    @HMFieldPointBonusTimerEnabled = true if !instance_variable_defined?(:@HMFieldPointBonusTimerEnabled)
    @HMFieldPointBonusTimer = 180 if !instance_variable_defined?(:@HMFieldPointBonusTimer)
    @HMFieldPointBonusTimerMax = 180 if !instance_variable_defined?(:@HMFieldPointBonusTimerMax)
  end

  def expedition_ranks
    ensure_expedition_data
    return @expeditionRanks
  end

  def expedition_points(region = nil)
    ensure_expedition_data
    return @expeditionPoints if region.nil?
    return @expeditionPoints[region] || 0
  end

  def expedition_rank(region)
    return get_current_expedition_rank(region)
  end

  def get_current_region()
    ensure_expedition_data
    map_id = $game_map&.map_id
    metadata = GameData::MapMetadata.try_get(map_id)
    @current_region = metadata&.town_map_position&.[](0)
    
    return  @current_region || 0
  end

  def starterUnlocked?(starter)
    ensure_expedition_data
    return @playerStarterLiscenses.include?(starter)
  end

  def start_HM_bonus_timer()
    ensure_expedition_data
    while @HMFieldPointBonusTimer > 0
      Graphics.update
      Input.update
      @HMFieldPointBonusTimer -= 1
    end
    stop_HM_bonus_timer()
  end

  def stop_HM_bonus_timer()
    ensure_expedition_data
    pbMessage(_INTL("You may now gain points for using HMs in Wild Areas!"))
    @HMFieldPointBonusTimer = 0
  end

  def reset_HM_bonus_timer()
    ensure_expedition_data
    if @HMFieldPointBonusTimerEnabled
      @HMFieldPointBonusTimer = @HMFieldPointBonusTimerMax
    end
    start_HM_bonus_timer()
  end

  def pbHMPointBonus(move)
    ensure_expedition_data
    if @inWildZone
        if !@HMFieldPointBonusTimerEnabled || (@HMFieldPointBonusTimerEnabled && @HMFieldPointBonusTimer == 0)
          pbAddExpeditionPoints(get_current_region(), Settings::EXPEDITION_POINT_VALUES[move])
          reset_HM_bonus_timer()
        end
      end
    end

  def increment_expedition_rank(region)
    ensure_expedition_data
    @expeditionRanks[region] += 1
    if @expeditionRanks[region] >= $game_settings.EXPEDITION_RANK_CAP
      @expeditionRanks[region] = $game_settings.EXPEDITION_RANK_CAP
    end
  end

  def get_current_expedition_rank(region)
    ensure_expedition_data
    return @expeditionRanks[region] || 0
  end

  def get_expedition_points(region)
    ensure_expedition_data
    return @expeditionPoints[region] || 0
  end

  def expedition_progress(region)
    ensure_expedition_data
    current_points = get_expedition_points(region)
    current_rank = get_current_expedition_rank(region)
    next_rank_points = $game_settings.EXPEDITION_POINTS_PER_RANK[current_rank + 1] || $game_settings.EXPEDITION_POINTS_PER_RANK.last
    return ((current_points.to_f / next_rank_points) * 100).round if current_rank < $game_settings.EXPEDITION_RANK_CAP
    return "--"
  end

  def pbAddExpeditionPoints(region, points)
    ensure_expedition_data
    pts = @expeditionPoints[region] + points 
    if pts <= $game_settings.MAX_EXPEDITION_POINTS
      @expeditionPoints[region] = pts
      increment_expedition_rank(region) if pts >= $game_settings.EXPEDITION_POINTS_PER_RANK[self.get_current_expedition_rank(region)+1]
    else
      @expeditionPoints[region] = $game_settings.MAX_EXPEDITION_POINTS
    end
  end

end

