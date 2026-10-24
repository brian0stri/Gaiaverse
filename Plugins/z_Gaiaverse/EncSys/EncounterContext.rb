class EncounterContext
  attr_reader :habitat
  attr_reader :region
  attr_reader :rod
  attr_reader :time
  attr_accessor :spawn_cache

    def initialize()
        @region = $game_map.metadata&.town_map_position&.[](0) || 0
        @habitat = nil
        @rod = pbFishing(type)
        @time = encounter_time_category
        @spawn_cache = {}
    end

    def set_habitat(habitat)
        @habitat = habitat 
    end

    def context_key(species)
        return "#{@region}_#{@habitat}_#{@rod}_#{@time}"
    end

    def encounter_time_category
        return :morning if PBDayNight.isMorning?
        return :day if PBDayNight.isDay?
        return :evening if PBDayNight.isEvening?
        return :night if PBDayNight.isNight?
        return :unknown
    end

    def pbFishing(type)
        return :old if type == 1
        return :good if type == 2
        return :super if type == 3
        return :none
    end
end