# === DEBUG TILE HOOK ===
class Table
  alias_method :old_set, :[]= unless method_defined?(:old_set)

  def []=(*args)
    unless $printed_tile_trace
      echoln "=== FIRST TILE WRITE DETECTED ==="
      caller[0..10].each { |c| echoln c }
      $printed_tile_trace = true
    end
    old_set(*args)
  end
end

module ProcWild

  TILE_SIZE = 32
  CHUNK_SIZE = 32
  WORLD_SEED = rand(1_000_000)

  TERRAIN_GRASS  = :grass
  TERRAIN_FOREST = :forest
  TERRAIN_WATER  = :water

  BIOME_FOREST  = :forest
  BIOME_PLAINS  = :plains
  BIOME_WETLAND = :wetland
  BIOME_HILLS   = :hills

  # When true, road generation enforces a single connected road network
  # (useful for deterministic test maps).
  STRICT_ROUTE_CONNECTIVITY = true

  # Stability toggle for stair generation/rendering.
  ENABLE_STAIRS = true

  #CONFIG = JSON.parse(File.read("Plugins/ProcGen/zone_config.json"))

  CHUNK_ID = [:SMALL, :MEDIUM, :LARGE, :EXTRA_LARGE]

  def check_chunk_size_from_ID
    case chunk_id
    when :SMALL
      return 3
    when :MEDIUM
      return 5
    when :LARGE
      return 8
    when :EXTRA_LARGE
      return 13
    else
      raise "Invalid chunk ID: #{chunk_id}"
    end
  end

  def self.test
    grid = Grid.new

    chunk = grid.get_chunk(0,0)

    p "Chunk created at #{chunk.cx}, #{chunk.cy}"
    debug_chunk(chunk)
  end

 def self.debug_chunk(chunk)

  output = ""

  ProcWild::CHUNK_SIZE.times do |y|

    row = ""

    ProcWild::CHUNK_SIZE.times do |x|

      t = chunk.terrain[x][y]

      row += case t
      when :grass  then "."
      when :forest then "T"
      when :water  then "~"
      else "?"
      end

    end

    output += row + "\n"

  end

  echoln output

end

def self.debug_biomes

  grid = Grid.new

  size = 4   # how far from center

  (-size..size).each do |y|

    row = ""

    (-size..size).each do |x|

      biome = grid.biome_at(x,y)

      row += case biome
      when :forest  then "F "
      when :plains  then "P "
      when :wetland then "W "
      when :hills   then "H "
      else "? "
      end

    end

    echoln row

  end

end


def self.test_area
  grid = Grid.new
  gen  = WorldGenerator.new

  gen.generate_world_cliff_paths(grid, 0, 0, 1)
  map = gen.build_area_map(grid, 0, 0, 1)

  echoln "Generated map #{map.width}x#{map.height}"
  load_generated_map(map)
end


   def self.load_generated_map(map)

    $game_map.instance_variable_set(:@map, map)

    $game_map.instance_variable_set(:@width, map.width)
    $game_map.instance_variable_set(:@height, map.height)

    $game_map.instance_variable_set(:@display_x, 0)
    $game_map.instance_variable_set(:@display_y, 0)

    $game_map.refresh

  end

end