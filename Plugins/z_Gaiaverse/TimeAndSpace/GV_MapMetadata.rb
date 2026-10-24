module GameData
  class MapMetadata
    attr_reader :gv_maps_seen

    # Returns custom clock unlock data from flags
    def gv_clock_unlock_data
      return nil if !@flags

      @flags.each do |flag|
        if flag.start_with?("ClockUnlock:")
          # Format: ClockUnlock:id:message:switch
          parts = flag.split(":")
          return {
            id: parts[1],
            message: parts[2],
            switch: parts[3]&.to_i
          }
        end
      end

      return nil
    end

  end

  def gv_maps_seen
    @gv_maps_seen = {} if !@gv_maps_seen.is_a?(Hash)
    return @gv_maps_seen
  end
end