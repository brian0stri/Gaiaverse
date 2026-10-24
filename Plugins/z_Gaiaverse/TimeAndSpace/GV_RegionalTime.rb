module GameData
  class MapMetadata
    attr_accessor :latitude
    attr_accessor :timeZone

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
      "Latitude"          => [:latitude,             "s"],
      "TimeZone"          => [:timeZone,             "s"]
    }

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
        ["Latitude",          FloatProperty,           _INTL("The latitude of this map, used to determine time zone and regional tone adjustments.")],
        ["TimeZone",          FloatProperty,           _INTL("The time zone of this map, in hours offset from UGC. Used to determine regional tone adjustments.")]
      ]
    end

    alias gv_map_metadata_initialize initialize unless method_defined?(:gv_map_metadata_initialize)
    def initialize(hash)
      gv_map_metadata_initialize(hash)
      @latitude = (hash[:latitude].nil? || hash[:latitude] == "") ? 0.0 : hash[:latitude].to_f
      @timeZone = (hash[:timeZone].nil? || hash[:timeZone] == "") ? 0.0 : hash[:timeZone].to_f
    end

    # Missing/blank map time data falls back to neutral world values.
    def latitude
      return 0.0 if @latitude.nil? || @latitude == ""
      return @latitude.to_f
    end

    def timeZone
      return 0.0 if @timeZone.nil? || @timeZone == ""
      return @timeZone.to_f
    end

  end
end

class GameStats
  attr_accessor :simulated_start_time
  attr_accessor :last_simulated_time
  attr_writer :play_time

 alias gvrt_stats_initialize initialize unless method_defined?(:gvrt_stats_initialize)
 def initialize
  gvrt_stats_initialize
  ensure_simulated_time_data
 end

 def ensure_simulated_time_data
  @simulated_start_time ||= SimulatedTime::START_DATE
  @last_simulated_time ||= @simulated_start_time
 end
end

class Scene_Map
  alias gvrt_update update unless method_defined?(:gvrt_update)
  def update
    gvrt_update    
    return if !$player || !$game_map || !$game_map.metadata&.outdoor_map
    base_time = pbGetTimeNow
    return if base_time.nil?
    if Input.trigger?(Input::AUX1)
      t = base_time + (30*24*3600)   # +1 hour
    elsif Input.trigger?(Input::AUX2)
      t = base_time - 3600   # -1 hour
    elsif Input.trigger?(Input::USE)
      t = base_time + (6*3600*30*24)   # +6 hours
 # Jump to next morning
    else
      return
    end
      SimulatedTime.set_time(t.to_f)
      PBDayNight.instance_variable_set(:@dayNightToneLastUpdate, nil)
  end
end


module SimulatedTime
  # Simulates time passage in the game, allowing  different regions to have different times.
  # Each region can have a time offset from real time, creating a dynamic day/night cycle across regions.
  START_DATE = Time.new(1900, 1, 1, 0, 0, 0, "+00:00")
  SCALE_FACTOR = 60 # 1 real second = 1 simulated minute

  @solar_cache = {
    # Cache solar calculations to improve performance, as these can be expensive and are called frequently.
    # Keys will be [latitude, day_of_year, hour], values will be [declination, elevation]
    day: nil,
    sunrise: nil,
    sunset: nil,
    latitude: nil,
    polar: nil
  }
  @effective_cache ||= {key: nil, value: nil}
  # 25.2° chosen so latitude 62° experiences ~14-day polar periods, giving a noticeable but not extreme effect.
  @axial_tilt = 25.2
  @days_in_year = nil
  @summer_solstice = 172
  @offsets = {}

  class << self
    attr_accessor :hour, :day_of_year
    attr_accessor :solar_cache
    attr_accessor :sunset, :sunrise 
    attr_accessor :solstice_offset
    attr_accessor :axial_tilt
    attr_accessor :days_in_year

    def set_time(time)
      time = Time.at(time) if time.is_a?(Float)

      $stats.simulated_start_time = time
      $stats.last_simulated_time = time
      @solar_cache = {
        day: nil,
        sunrise: nil,
        sunset: nil,
        latitude: nil,
        polar: nil

      }
      @effective_cache = {key: nil, value: nil}
    end

    def elapsed_time(final_simulated_time, simulated_start, factor)
      elapsed_seconds = final_simulated_time - simulated_start
      return elapsed_seconds * factor
    end

      def current_time(stats, fallback_time)
        return fallback_time if !stats

        start_time = stats.simulated_start_time || START_DATE

        #  enforce type
        start_time = Time.at(start_time.to_f) unless start_time.is_a?(Time)

        return start_time + (stats.play_time.to_f * SCALE_FACTOR)
      end

    def calculate_days_in_year(time)
        year = time.year
        @days_in_year = (year % 4 == 0) ? 366 : 365
        return @days_in_year
    end

    def calculate_solar_declination(year, day_of_year, hour)
      return 12.0 if year.nil? || day_of_year.nil? || hour.nil?
      day_of_year += (hour / 24.0) # Treat each hour as a fraction of a day for smoother declination changes
      decl = @axial_tilt * Math.cos((2 * Math::PI / @days_in_year) * (day_of_year - @summer_solstice))
      return decl
    end

    def calculate_solar_elevation(latitude, declination, hour = 12.0)
      latitude_rad = latitude.to_f * Math::PI / 180.0
      declination_rad = declination.to_f * Math::PI / 180.0
      hour_angle_rad = ((hour.to_f - 12.0) * 15.0) * Math::PI / 180.0
      sin_elevation = (Math.sin(latitude_rad) * Math.sin(declination_rad)) +
                      (Math.cos(latitude_rad) * Math.cos(declination_rad) * Math.cos(hour_angle_rad))
      sin_elevation = [[sin_elevation, -1.0].max, 1.0].min
      return Math.asin(sin_elevation)
    end

    def find_sun_times(latitude, day, year)
        prev_elev = calculate_solar_elevation(latitude, calculate_solar_declination(year, day, 0), 0)
        sunrise = nil
        sunset  = nil

        (1..24).each do |hour|
          elev = calculate_solar_elevation(latitude, calculate_solar_declination(year, day, hour), hour)
          if prev_elev < 0 && elev >= 0
            sunrise = refine_crossing(latitude, calculate_solar_declination(year, day, hour), hour - 1, hour)
          elsif prev_elev >= 0 && elev < 0
            sunset = refine_crossing(latitude, calculate_solar_declination(year, day, hour), hour - 1, hour)
          end

          prev_elev = elev
        end
        #echoln "Calculated sun times for latitude #{latitude}°, day #{day}, year #{year}: sunrise=#{sunrise}, sunset=#{sunset}"

        if sunrise.nil? && sunset.nil?
          decl = calculate_solar_declination(year, day, 12.0)
          elev_noon = calculate_solar_elevation(latitude, decl, 12.0)

          if elev_noon > 0
            return 0.0, 24.0, :day   # polar day
          else
            return 0.0, 0.0, :night  # polar night
          end
        end

        return sunrise, sunset, :normal
      end

      def precompute_solstice_offsets(latitude, tilt, days_in_year, year)
          
        polarDays = []
        polarNights = []
        @offsets = {day: polarDays, night: polarNights}
        for day in 1..days_in_year
          decl = tilt * Math.cos((2 * Math::PI / days_in_year) * (day - @summer_solstice))
          polarlat = 90 - decl.abs

          if latitude.abs > polarlat
            is_day = (latitude * decl) > 0
            @offsets[is_day ? :day : :night] << day
          end
        end
        if @offsets[:day].empty? && @offsets[:night].empty?
          echoln "No polar days or nights this year at latitude #{latitude}°."
          return
        end
        @offsets[:day].each do |i|
          date_obj = Time.local(year,1,1)+(i - 1)*24*3600
          echoln "Polar Day on #{date_obj.month}/#{date_obj.day}"
        end
        @offsets[:night].each do |i|
          date_obj = Time.local(year,1,1)+(i - 1)*24*3600
          echoln "Polar Night on #{date_obj.month}/#{date_obj.day}"
        end
          echoln "There are #{@offsets[:day].length} polar days and #{@offsets[:night].length} polar nights this year."


      end

      def update_solar_cache(latitude, sim_time)
        if @solar_cache[:day] != sim_time.yday || @solar_cache[:latitude] != latitude
          @solar_cache[:latitude] = latitude
          decl = calculate_solar_declination(sim_time.year, sim_time.yday, 12.0)
          sunrise, sunset = find_sun_times(latitude, sim_time.yday, sim_time.year)
          if sunrise.nil? && sunset.nil?
            decl = calculate_solar_declination(sim_time.year, sim_time.yday, 12.0)
            elev_noon = calculate_solar_elevation(latitude, decl, 12.0)

            if elev_noon > 0
              @solar_cache[:polar] = :day
              @solar_cache[:sunrise] = 0.0
              @solar_cache[:sunset]  = 24.0
              #echoln "sunrise=#{@solar_cache[:sunrise]}, sunset=#{@solar_cache[:sunset]}"
              echoln sim_time.inspect
            else
              @solar_cache[:polar] = :night
              @solar_cache[:sunrise] = 0.0
              @solar_cache[:sunset]  = 0.0
              #echoln "sunrise=#{@solar_cache[:sunrise]}, sunset=#{@solar_cache[:sunset]}"
              echoln sim_time.inspect
            end
          else
            @solar_cache[:polar] = :nil
            @solar_cache[:sunrise] = sunrise
            @solar_cache[:sunset] = sunset
            #echoln "sunrise=#{@solar_cache[:sunrise]}, sunset=#{@solar_cache[:sunset]}"
          end
        end
        @solar_cache[:day] = sim_time.yday
      end

      def refine_crossing(latitude, declination, t1, t2)
        10.times do
          mid = (t1 + t2) / 2.0
          elev = calculate_solar_elevation(latitude, declination, mid)

          if elev > 0
            t2 = mid
          else
            t1 = mid
          end
        end

        return (t1 + t2) / 2.0
      end

    def remap_wrap(time, start_t, end_t, out_start, out_end)
      length = (end_t - start_t) % 24.0
      t = (time - start_t) % 24.0
      return out_start + (t / length) * (out_end - out_start)
    end

    def equivalent_hour(time, sunrise, sunset)
      anchors = {
      :morning_start   => 5,
      :morning_end     => 10,
      :afternoon_start => 14,
      :afternoon_end   => 17,
      :evening_start   => 17,
      :night_start     => 20}
      time = time % 24

      remap = lambda do |t, a1, a2, b1, b2|
        return b1 if a1 == a2
        b1 + (t-a1) * (b2 - b1).to_f / (a2 - a1)
      end

      remap_wrap = lambda do |t, start_t, end_t, b1, b2|
        length = (end_t - start_t) % 24.0
        t_rel = (t - start_t) % 24.0
        b1 + (t_rel / length) * (b2 - b1)
      end

      noon = ((sunrise + sunset) / 2.0)%24

      morning_end = (sunrise + noon) / 2.0
      afternoon_start = (noon + sunset) / 2.0

      if time >= sunrise && time < morning_end
        return remap.call(time, sunrise, morning_end, anchors[:morning_start], anchors[:morning_end])
      elsif time >= morning_end && time < afternoon_start
        return remap.call(time, morning_end, afternoon_start, anchors[:morning_end], anchors[:afternoon_start])
      elsif time >= afternoon_start && time < sunset
        return remap.call(time, afternoon_start, sunset, anchors[:afternoon_start], anchors[:night_start])
      else
        return remap_wrap.call(time, sunset, sunrise, anchors[:night_start], 30) % 24
      end
    end

    def wrap_hour(h)
      return h < 24 ? h : h - 24
    end

    def calculateEffectiveHour()
      sim_time = pbGetTimeNow
      time_in_hours = sim_time.hour + (sim_time.min / 60.0)
      return 12.0 if sim_time.nil? || !sim_time.respond_to?(:year)
      minute_key = sim_time.hour * 60 + sim_time.min
      latitude = $game_map&.metadata&.latitude || 0
      cache_key = [minute_key, sim_time.yday, latitude]
      

      if @effective_cache[:key] == cache_key
        return @effective_cache[:value]
      end
      update_solar_cache(latitude, sim_time)

      @sunrise = @solar_cache[:sunrise]
      @sunset  = @solar_cache[:sunset]

      if @sunrise.nil? || @sunset.nil?
        echoln "WARNING: sunrise/sunset nil, forcing cache update"
        update_solar_cache(latitude, sim_time)

        @sunrise = @solar_cache[:sunrise]
        @sunset  = @solar_cache[:sunset]

        # still nil? fallback safely
        if @sunrise.nil? || @sunset.nil?
          return time_in_hours   # fallback: real time
        end
      end 

      if @solar_cache[:polar] == :day
         # polar day
        decl = calculate_solar_declination(sim_time.year, sim_time.yday, time_in_hours)
        elev = calculate_solar_elevation(latitude, decl, time_in_hours)

        t = elev / (Math::PI / 2)  # 0..1
  
        result = 5 + t * 15
        @effective_cache[:key] = cache_key
        @effective_cache[:value] = result
        echoln "Stats: #{[time_in_hours, result].inspect}"
        return result  # map into 5–20 range
      elsif @solar_cache[:polar] == :night
        # polar night — use elevation curve
        decl = calculate_solar_declination(sim_time.year, sim_time.yday, time_in_hours)
        elev = calculate_solar_elevation(latitude, decl, time_in_hours)

        # normalize (-π/2 → 0) into night range (20 → 5)
        t = (elev + Math::PI / 2) / (Math::PI / 2)  # 0..1

        result = wrap_hour(20 + t * 9)  # map into 20–29 range, then wrap to 0–5
        @effective_cache[:key] = cache_key
        @effective_cache[:value] = result
        echoln "Stats: #{[time_in_hours, result].inspect}"
        return result
      end

      result = equivalent_hour(time_in_hours, @sunrise, @sunset)
      stats = [time_in_hours,
              result, sim_time.month, sim_time.day, @sunrise, @sunset]
      echoln "Stats: #{stats.inspect}"

      @effective_cache[:key] = cache_key
      @effective_cache[:value] = result

      return result
    end

    def calculateEffectiveHourUI(latitude, universal_time_year, universal_time_month, universal_time_day, universal_time_hour, universal_time_min, universal_time_sec, time_zone)
        time_in_hours = universal_time_hour + (universal_time_min / 60.0) + (universal_time_sec / 3600.0) + time_zone
        decl = calculate_solar_declination(universal_time_year, universal_time_day, 12.0)
        sunrise, sunset = find_sun_times(latitude, universal_time_day, universal_time_year)
        elev_noon = calculate_solar_elevation(latitude, decl, 12.0)
        state = {
          effective_hour: time_in_hours,
          sun_state: :normal
        }

        if sunrise == 0 && sunset == 24 && elev_noon > 0
         # polar day
          elev = calculate_solar_elevation(latitude, decl, time_in_hours)

          t = elev / (Math::PI / 2)  # 0..1
    
          result = 5 + t * 15
          echoln "Stats: #{[time_in_hours, result].inspect}"
          state[:effective_hour] = result
          state[:sun_state] = :polar_day
          return state  # map into 5–20 range
        elsif sunrise == 0 && sunset == 0 && elev_noon < 0
          # polar night — use elevation curve
          decl = calculate_solar_declination(universal_time_year, universal_time_day, time_in_hours)
          elev = calculate_solar_elevation(latitude, decl, time_in_hours)

          # normalize (-π/2 → 0) into night range (20 → 5)
          t = (elev + Math::PI / 2) / (Math::PI / 2)  # 0..1

          result = wrap_hour(20 + t * 9)  # map into 20–29 range, then wrap to 0–5
          #echoln "Stats: #{[time_in_hours, result].inspect}"
          state[:effective_hour] = result
          state[:sun_state] = :polar_night
          return state
        end

        result = equivalent_hour(time_in_hours, sunrise, sunset)
        stats = [time_in_hours,
                result, universal_time_month, universal_time_day, sunrise, sunset]
        #echoln "Stats: #{stats.inspect}"
        state[:effective_hour] = result
        state[:sun_state] = :normal

      return state
    end



    def sunrise
      @solar_cache[:sunrise]
    end

    def sunset
      @solar_cache[:sunset]
    end

    def describe_solar_state(latitude, time)
      decl = calculate_solar_declination(time.year, time.yday, hour)
      elev = calculate_solar_elevation(latitude, decl, hour)
      days_until_polar_night = offset = @offsets[:night].find { |d| d > time.yday } - time.yday
      days_until_polar_day = offset = @offsets[:day].find { |d| d > time.yday } - time.yday
      message = nil

      return message = "The sun never sets…" if polar_day?
      return message = "The sun never rises…" if polar_night?

      return message2 = "Dawn"      if elev.between?(-0.1, 0.1) && hour < 12
      return message2 = "Dusk"      if elev.between?(-0.1, 0.1)
      return message2 = "Daytime"   if elev > 0
      return message2 = "Night"     if elev < 0

      if days_until_polar_night < 3
        message = "The long night is almost here…"
      elsif days_until_polar_night < 10
        message = "The nights are getting longer…"
      end
      if days_until_polar_day < 3
        message = "The long day is almost here…"
      elsif days_until_polar_day < 10
        message = "The days are getting longer…"
      end
      return message, message2
    end

  end
end

alias gv_pbGetTimeNow pbGetTimeNow unless respond_to?(:gv_pbGetTimeNow, true)
def pbGetTimeNow
  base_time = gv_pbGetTimeNow || Time.new
  return base_time if !$player

  $stats&.ensure_simulated_time_data
  $player.ensure_expedition_data if $player.respond_to?(:ensure_expedition_data)
  region = ($player.respond_to?(:get_current_region)) ? $player.get_current_region : nil
  region = region.to_i if region.respond_to?(:to_i)
  SimulatedTime.days_in_year ||= SimulatedTime.calculate_days_in_year(base_time)
  latitude = ($game_map&.metadata&.latitude || 0.0).to_f
  time_zone = ($game_map&.metadata&.timeZone || 0.0).to_f
  if SimulatedTime.days_in_year && SimulatedTime.solar_cache[:latitude] != latitude
    SimulatedTime.precompute_solstice_offsets(latitude, SimulatedTime.axial_tilt, SimulatedTime.days_in_year, base_time.year)
  end
  current_time = SimulatedTime.current_time($stats, base_time)
  $stats.last_simulated_time = current_time if $stats
  current_time += (time_zone * 3600)

  adjusted_time = current_time
  # PBDayNight caches tint for 30s; invalidate when region or minute changes so
  # regional offsets are reflected immediately on map shading.
  minute_key = adjusted_time.hour * 60 + adjusted_time.min
  last_region = $game_temp&.instance_variable_get(:@gv_last_region_time)
  last_minute = $game_temp&.instance_variable_get(:@gv_last_minute_time)
  if $game_temp && (last_region != region || last_minute != minute_key)
    $game_temp.instance_variable_set(:@gv_last_region_time, region)
    $game_temp.instance_variable_set(:@gv_last_minute_time, minute_key)
    PBDayNight.instance_variable_set(:@dayNightToneLastUpdate, nil)
  end
  return Time.at(adjusted_time.to_f) unless adjusted_time.is_a?(Time)
  return adjusted_time
end

module PBDayNight
  REGIONAL_TONES = [
    Tone.new(-8,-2,+12,3), # Region Alpha: cold and mountainous, with a slightly later sunrise/sunset
    Tone.new(0,0,0,0),       # Region Beta: balanced region with no time offset
    Tone.new(+15,+4,-5,+3), # Region Gamma: warm and tropical, with a slightly earlier sunrise/sunset
    Tone.new(12,-4,-1,+12) # Region Delta: industrial and polluted, with a later sunrise/sunset and harsher night shading
  ]
  CACHED_TONE_LIFETIME = 10

  class << self
    alias gv_getTone getTone unless method_defined?(:gv_getTone)
    def getTone
      base_tone = gv_getTone
      $stats&.ensure_simulated_time_data
      return base_tone if !Settings::TIME_SHADING
      region = ($player && $player.respond_to?(:get_current_region)) ? $player.get_current_region.to_i : 0
      return base_tone if !region || region < 0 || region >= REGIONAL_TONES.length
      return base_tone if !$game_map || !$game_map.metadata&.outdoor_map

      regional_tone = REGIONAL_TONES[region]
      return Tone.new(
        base_tone.red + regional_tone.red,
        base_tone.green + regional_tone.green,
        base_tone.blue + regional_tone.blue,
        base_tone.gray + regional_tone.gray
      )
    end

    alias gv_getToneInternal getToneInternal unless method_defined?(:gv_getToneInternal)
    def getToneInternal
      
      latitude = $game_map&.metadata&.latitude || 0
      t = pbGetTimeNow
      time_in_hours = t.hour + t.min / 60.0

      decl = SimulatedTime.calculate_solar_declination(t.year, t.yday, time_in_hours)
      elev = SimulatedTime.calculate_solar_elevation(latitude, decl, time_in_hours)
      norm = Math.sin(elev)
      brightness = [[norm,0].max,1.0].min
      darkness = 1.0 - brightness
      strength = 0.3
      darkness *= strength

      gv_getToneInternal
      # Calculates the tone for the current frame, used for day/night effects
      effective_hour = SimulatedTime.calculateEffectiveHour()
      hour = effective_hour.floor % 24
      minute = ((effective_hour - hour) * 60).to_i
      minute = [[minute, 0].max, 59].min
      blend = (1 - Math.cos(minute / 60.0 * Math::PI)) / 2
      tone         = PBDayNight::HOURLY_TONES[hour] || Tone.new(0, 0, 0, 0)
      nexthourtone = PBDayNight::HOURLY_TONES[(hour + 1) % 24] || tone
      # Calculate current tint according to current and next hour's tint and
      # depending on current minute
      @cachedTone.red   = tone.red + (nexthourtone.red - tone.red) * blend
      @cachedTone.green = ((nexthourtone.green - tone.green) * blend) + tone.green
      @cachedTone.blue  = ((nexthourtone.blue - tone.blue) * blend) + tone.blue
      @cachedTone.gray  = ((nexthourtone.gray - tone.gray) * blend) + tone.gray

      @cachedTone.red -= darkness*10
      @cachedTone.green -= darkness*10
      @cachedTone.blue -= darkness*15
      @cachedTone.gray += darkness*20

      if elev > -0.1 && elev < 0.2
        @cachedTone.red   += 15
        @cachedTone.green += 5
      end
    end


    alias gv_isDay? isDay? unless method_defined?(:gv_isDay?)
    def isDay(time=nil)
     time = SimulatedTime.calculateEffectiveHour() if time.nil?
      return time >= 5 && time < 20
    end

    alias gv_isNight? isNight? unless method_defined?(:gv_isNight?)
      def isNight(time=nil)
        time = SimulatedTime.calculateEffectiveHour() if time.nil?
        return time >= 20 || time < 5
      end

    alias gv_isMorning? isMorning? unless method_defined?(:gv_isMorning?)
      def isMorning(time=nil)
        time = SimulatedTime.calculateEffectiveHour() if time.nil?
        hour = time.respond_to?(:hour) ? time.hour : time.to_i
        return (hour >= 5 && hour < 10)
      end

    alias gv_isAfternoon? isAfternoon? unless method_defined?(:gv_isAfternoon?)
      def isAfternoon(time=nil)
        time = SimulatedTime.calculateEffectiveHour() if time.nil?
        hour = time.respond_to?(:hour) ? time.hour : time.to_i
        return (hour >= 14 && hour < 17)
      end


    alias gv_isEvening? isEvening? unless method_defined?(:gv_isEvening?)
      def isEvening(time=nil)
        time = SimulatedTime.calculateEffectiveHour() if time.nil?
        hour = time.respond_to?(:hour) ? time.hour : time.to_i
        return (hour >= 17 && hour < 20)
      end

  end
end

class PokemonGlobalMetadata

  alias gvrt_global_metadata_initialize initialize unless method_defined?(:gvrt_global_metadata_initialize)
  def initialize
    gvrt_global_metadata_initialize
    @startTime = ($stats&.simulated_start_time) || SimulatedTime::START_DATE
  end

end