module GameData
  class WorldMap
    attr_reader :id
    attr_reader :name
    attr_reader :filename
    attr_reader :point
    attr_reader :time_zone
    attr_reader :pbs_file_suffix

    DATA = {}
    PBS_BASE_FILENAME = "world_map"

    SCHEMA = {
      "SectionName" => [:id,        "u"],
      "Name"        => [:name,      "s"],
      "Time Zone"   => [:time_zone, "f"] }

      def initialize(hash)
        @id = hash[:id]
        @name = hash[:name] || "???"
        @point =  []
        @time_zone = hash[:time_zone] || 0.0
        load_points_from_pbs
      end

        def load_points_from_pbs
          @point = []

          path = "PBS/world_map.txt"
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
              values = data.split(",").map(&:strip)

              @point << {
                x: values[0].to_i,
                y: values[1].to_i,
                time_zone: values[2].to_f,
                name: values[3]
              }
            end
          end
        end

        def self.load
          @data = {}

          path = "PBS/world_map.txt"
          current_section = nil
          current_map = nil

          File.foreach(path) do |line|
            line.strip!
            next if line.empty? || line.start_with?("#")

            if line[/\[(\d+)\]/]
              current_section = $1.to_i
              current_map = {
                id: current_section,
                name: "",
                point: []
              }
              @data[current_section] = current_map
              next
            end

            next if !current_map

            if line.start_with?("Name")
              current_map[:name] = line.split("=", 2)[1].strip
            elsif line.start_with?("RegionID")
              current_map[:region_id] = line.split("=", 2)[1].to_i
            elsif line.start_with?("Point")
              values = line.split("=", 2)[1].strip.split(",").map(&:strip)

              current_map[:point] << {
                x: values[0].to_i,
                y: values[1].to_i,
                time_zone: values[2].to_f,
                name: values[3]
              }
            end
          end
        end

        def self.each
          @data.each_value { |v| yield v }
        end

  end
end
      

