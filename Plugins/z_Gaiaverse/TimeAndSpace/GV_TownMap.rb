module GameData
  class TownMap
    attr_reader :id
    attr_reader :real_name
    attr_reader :filename
    attr_reader :point
    attr_reader :flags
    attr_reader :pbs_file_suffix
    attr_reader :latitude
    attr_reader :time_zone
    attr_reader :start_x
    attr_reader :start_y
    attr_reader :end_x
    attr_reader :end_y
    attr_accessor :base_latitude_per_region
    attr_reader :point

  DATA = {}
  DATA_FILENAME = "town_map.dat"
  PBS_BASE_FILENAME = "town_map"

  SCHEMA = {
      "SectionName" => [:id,        "u"],
      "Name"        => [:real_name, "s"],
      "Filename"    => [:filename,  "s"],
      "Time Zone"     => [:time_zone,  "f"],
      "Flags"       => [:flags,     "*s"],
    }

    extend ClassMethodsIDNumbers
    include InstanceMethods

    alias gv_initialize initialize
    def initialize(hash)
      gv_initialize(hash)
      @id              = hash[:id]
      @real_name       = hash[:real_name]       || "???"
      @filename        = hash[:filename]
      @time_zone = hash[:time_zone] || 0.0
      @point           = []
      load_points_from_pbs
    end

    def calculate_latitude_per_point(y)
      height = (@end_y - @start_y).abs + 1
      normalized = (y - @start_y).to_f / height
      return @base_latitude_per_region - (normalized * height)
    end

    def calculate_tile_dimensions
      return [((@end_x - @start_x).abs + 1), ((@end_y - @start_y).abs + 1)]
    end

  def calculate_tile_area
    dimensions = calculate_tile_dimensions
    return dimensions[0] * dimensions[1]
  end


  def load_points_from_pbs
    @point = []

    path = "PBS/town_map.txt"
    current_section = nil

    File.foreach(path) do |line|
        echoln "RAW LINE: #{line}"

      line.strip!
      next if line.empty? || line.start_with?("#")
      if line[/\[(\d+)\]/]
        current_section = $1.to_i
        next
      end

      next if current_section != @id

      if line.start_with?("Point")
        data = line.split("=", 2)[1].strip
        #echoln "Processed point data: #{data}"
        @point << data
      end
    end
  end

  end
end