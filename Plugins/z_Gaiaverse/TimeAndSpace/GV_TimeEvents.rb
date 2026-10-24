class PokemonGlobalMetadata
  attr_accessor :gv_unlocked_clocks
  attr_accessor :gv_maps_seen

  def gv_unlocked_clocks
    @gv_unlocked_clocks = {} if !@gv_unlocked_clocks.is_a?(Hash)
    return @gv_unlocked_clocks
  end

  def gv_maps_seen
    @gv_maps_seen = {} if !@gv_maps_seen.is_a?(Hash)
    return @gv_maps_seen
  end
end

class Scene_Map
  alias gv_clock_unlock_transfer transfer_player unless method_defined?(:gv_clock_unlock_transfer)

  def transfer_player(cancelVehicles = false)
    gv_clock_unlock_transfer(cancelVehicles)

    GV_TimeEvents.check_clock_unlock_on_map_enter
  end
end

module GV_TimeEvents

def self.skip_to_hour(target_hour)
  time = pbGetTimeNow

  new_time = Time.new(
    time.year,
    time.month,
    time.day,
    target_hour,
    0,
    0
  )

  new_time += 86400 if new_time <= time  # push to next day if needed

  pbSetTimeNow(new_time)
end

def self.skip_hours(hours)
  time = pbGetTimeNow
  pbSetTimeNow(time + (hours * 3600))
end

def self.pbGetWorldState(lat, tz)
  time = pbGetTimeNow

  state = SimulatedTime.calculateEffecitveHourUI(
    lat,
    time.year,
    time.month,
    time.yday,
    time.hour,
    time.min,
    time.sec,
    tz
  )

  tod = pbGetTODFromEffectiveHour(
    state[:effective_hour],
    state[:sun_state]
  )

  return {
    :tod => tod,
    :sun_state => state[:sun_state]
  }
end

 def self.skip_to_tod(target_tod, lat, tz)
    time = pbGetTimeNow

    1.upto(48) do |h|
      test_time = time + (h * 3600)

      state = SimulatedTime.calculateEffecitveHourUI(
        lat,
        test_time.year,
        test_time.month,
        test_time.yday,
        test_time.hour,
        test_time.min,
        test_time.sec,
        tz
      )

      tod = pbGetTODFromEffectiveHour(
        state[:effective_hour],
        state[:sun_state]
      )

      if tod == target_tod
        pbSetTimeNow(test_time)
        return
      end
    end
  end

  def self.unlock_clock(id)
    $PokemonGlobal.gv_unlocked_clocks[id] = true

    # optional switch hook
    # $game_switches[123] = true

    GV_ClockUnlockUI.show(id)
  end

  def self.check_clock_unlock_on_map_enter
    return if !$game_map || !$PokemonGlobal
    map_id = $game_map.map_id
    return if map_id.nil?

    # 👇 FIRST TIME CHECK
    first_time = !$PokemonGlobal.gv_maps_seen[map_id]
    $PokemonGlobal.gv_maps_seen[map_id] = true

    return if !first_time

    metadata = GameData::MapMetadata.try_get(map_id)
    return if !metadata

    data = metadata.gv_clock_unlock_data
    return if !data

    id = data[:id]
    return if id.nil? || id.to_s.empty?
    return if $PokemonGlobal.gv_unlocked_clocks[id]

    $PokemonGlobal.gv_unlocked_clocks[id] = true

    if data[:switch] && data[:switch] > 0
      $game_switches[data[:switch]] = true
    end

    GV_ClockUnlockUI.show(data[:message] || "New Clock Added!")
    end

end