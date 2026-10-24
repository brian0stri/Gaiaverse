module ProcWild
class Chunk

    # Generate continuous cliff paths across the requested group of chunks.
    # Chunk owns the geometry; WorldGenerator only coordinates map assembly.
    def self.generate_world_cliff_paths(grid, center_x, center_y, radius)
      size = ProcWild::CHUNK_SIZE

      min_x = (center_x - radius) * size
      max_x = (center_x + radius + 1) * size - 1
      min_y = (center_y - radius) * size
      max_y = (center_y + radius + 1) * size - 1

      chunks = {}

      # Fetch and generate every chunk before scanning heights or drawing paths.
      (center_x - radius).upto(center_x + radius) do |cx|
        (center_y - radius).upto(center_y + radius) do |cy|
          chunk = grid.get_chunk(cx, cy)
          chunks[[cx, cy]] = chunk

          size.times do |x|
            size.times do |y|
              chunk.cliffPath[x][y] = []
            end
          end
        end
      end

      # The number of continuous paths equals the highest elevation in this area.
      max_height = 0
      chunks.each_value do |chunk|
        size.times do |x|
          size.times do |y|
            tile_height = chunk.height[x][y]
            next if tile_height.nil?
            max_height = tile_height if tile_height > max_height
          end
        end
      end

      path_count = max_height.to_i
      echoln "WORLD CLIFF PATHS: seeds=#{path_count}"

      chunk_at = lambda do |wx, wy|
        chunks[[wx.div(size), wy.div(size)]]
      end

      # Water blocks paths. Roads and forest do not constrain cliff geometry.
      blocked = lambda do |wx, wy|
        if wx < min_x || wx > max_x || wy < min_y || wy > max_y
          true
        else
          chunk = chunk_at.call(wx, wy)
          if chunk.nil?
            true
          else
            lx = wx % size
            ly = wy % size
            chunk.terrain[lx][ly] == ProcWild::TERRAIN_WATER
          end
        end
      end

      noise_at = lambda do |wx, wy|
        chunk = chunk_at.call(wx, wy)
        if chunk
          chunk.instance_variable_get(:@heightmap).height_at(wx, wy).to_f
        else
          0.0
        end
      end

      # Preserve markers from every path where paths intersect.
      write_marker = lambda do |wx, wy, marker|
        chunk = chunk_at.call(wx, wy)
        next unless chunk

        lx = wx % size
        ly = wy % size
        existing = chunk.cliffPath[lx][ly] || []
        existing = [existing] unless existing.is_a?(Array)
        incoming = marker.nil? ? [] : (marker.is_a?(Array) ? marker : [marker])
        merged = (existing + incoming).compact.uniq
        chunk.cliffPath[lx][ly] = merged
      end

      # Give each path its own deterministic random stream.
      seed = ProcWild::WORLD_SEED.to_i
      path_count.times do |path_index|
        path_rng = Random.new(seed + (path_index + 1) * 104729)

        path = ProcWild::CliffPathBuilder.generate(
          min_x,
          max_x,
          min_y,
          max_y,
          path_rng,
          blocked,
          noise_at,
          write_marker
        )

        tile_count = path.respond_to?(:length) ? path.length : 0
        echoln(
          "WORLD CLIFF PATH: index=#{path_index + 1}/#{path_count} " +
          "tiles=#{tile_count} area=#{max_x - min_x + 1}x#{max_y - min_y + 1}"
        )
      end
    end


    attr_reader :cx
    attr_reader :cy
    attr_accessor :tiles
    attr_accessor :terrain
    attr_accessor :zone_type
    attr_accessor :chunk_size
    attr_accessor :biome
    attr_accessor :landmarks
    attr_accessor :encounters
    attr_accessor :grass
    attr_accessor :TERRAIN_GRASS
    attr_accessor :TERRAIN_FOREST
    attr_accessor :TERRAIN_WATER
    attr_accessor :path
    attr_accessor :path_start
    attr_accessor :path_end
    attr_reader :rng
    attr_accessor :north_entry
    attr_accessor :west_entry
    attr_accessor :south_entry
    attr_accessor :east_exit
    attr_accessor :north_exit
    attr_accessor :south_exit
    attr_accessor :generated
    attr_accessor :height
    attr_accessor :bridgePath
    attr_accessor :cliffPath
    attr_accessor :roadMask

    def initialize(cx, cy, biome)
      @cx = cx
      @cy = cy
      @biome = biome
      @landmarks = []
      @encounters = []
      @tiles = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE) }
      @terrain = Array.new(CHUNK_SIZE) do Array.new(CHUNK_SIZE, TERRAIN_GRASS)end
      @events = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE) }
      @grass = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, false) }
      @path = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, false) }
      @rng = set_new_seed()
      @start_y = @rng.rand(ProcWild::CHUNK_SIZE)
      @path_start = nil
      @target_y = @rng.rand(ProcWild::CHUNK_SIZE)
      @path_end = nil
      @north_entry = nil
      @south_entry = nil
      @west_entry = nil
      @east_exit= nil
      @south_exit = nil
      @north_exit = nil
      @generated = false
      @heightmap = HeightMap.new(seed)
      @height = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, nil) }
      @bridgePath = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, false) }
      @cliffPath = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE) { [] } }      
      @roadMask = Array.new(CHUNK_SIZE) { Array.new(CHUNK_SIZE, false) }
    end

  def seed
  return ProcWild::WORLD_SEED + (@cx * 928371) + (@cy * 123123)
  end

def set_new_seed()
  @rng = Random.new(seed)
end

def generate()
  return if generated
  fill(TERRAIN_GRASS)
    @generated = false

    generate_terrain
    generate_heightmap

    counts = Hash.new(0)

    @height.each do |column|
      column.each do |h|
        counts[h] += 1
      end
    end

    echoln "HEIGHT DISTRIBUTION: #{counts.sort.inspect}"

    smooth_terrain
    smooth_terrain
    generate_path(@rng)
    apply_switchbacks
    smooth_road_heights
    build_road_mask
    
    generate_grass_patches(@rng)
    generate_landmarks
    generate_encounters
    @generated = true
end

def generate_terrain
  echoln "Generating chunk biome #{@biome}"

  case @biome

  when ProcWild::BIOME_FOREST
    generate_forest(@rng)

  when ProcWild::BIOME_PLAINS
    generate_plains(@rng)

  when ProcWild::BIOME_WETLAND
    generate_wetlands(@rng)

  when ProcWild::BIOME_HILLS
    generate_hills(@rng)

  end

end

def generate_heightmap
  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|
      wx = @cx * ProcWild::CHUNK_SIZE + x
      wy = @cy * ProcWild::CHUNK_SIZE + y
      height = @heightmap.height_at(wx, wy)
      @height[x][y] = height
    end
  end

  apply_water_height_constraints
end

def apply_water_height_constraints
  size = ProcWild::CHUNK_SIZE
  adjusted = Marshal.load(Marshal.dump(@height))

  size.times do |x|
    size.times do |y|
      next unless @terrain[x][y] == TERRAIN_WATER

      # Keep water basins low so water tiles don't sit on cliff-top elevations.
      adjusted[x][y] = [adjusted[x][y], 0].min
    end
  end

  size.times do |x|
    size.times do |y|
      next if @terrain[x][y] == TERRAIN_WATER
      next unless adjacent_to_water?(x, y)

      # Soften coastlines to reduce abrupt side-cliff noise next to water.
      adjusted[x][y] = [adjusted[x][y], 2].min
    end
  end

  @height = adjusted
end

def adjacent_to_water?(x, y)
  [[1,0],[-1,0],[0,1],[0,-1]].each do |dx, dy|
    nx = x + dx
    ny = y + dy

    next if nx < 0 || ny < 0
    next if nx >= ProcWild::CHUNK_SIZE || ny >= ProcWild::CHUNK_SIZE

    return true if @terrain[nx][ny] == TERRAIN_WATER
  end

  false
end



# Generate one continuous, non-branching cliff path on a blank grid.
# Penalizes self-coiling and extends stranded paths to the nearest reachable edge.
# Path geometry is created first; markers are assigned afterward.
# def generate_cliff_paths(rng = @rng)
#   size = ProcWild::CHUNK_SIZE
#   @cliffPath = Array.new(size) { Array.new(size) { [] } }

#   directions = [
#     [:north,  0, -1],
#     [:south,  0,  1],
#     [:west,  -1,  0],
#     [:east,   1,  0]
#   ]

#   opposite = {
#     :north => :south,
#     :south => :north,
#     :west  => :east,
#     :east  => :west
#   }

#   blocked = lambda do |x, y|
#     x < 0 || y < 0 || x >= size || y >= size ||
#       @path[x][y] || @terrain[x][y] == TERRAIN_WATER ||
#       (@bridgePath && @bridgePath[x][y])
#   end

#   on_edge = lambda do |x, y|
#     x == 0 || y == 0 || x == size - 1 || y == size - 1
#   end

#   noise_at = lambda do |x, y|
#     wx = @cx * size + x
#     wy = @cy * size + y
#     @heightmap.height_at(wx, wy).to_f
#   end

#   # Find a viable starting tile.
#   starts = []
#   size.times do |x|
#     size.times do |y|
#       next if blocked.call(x, y)

#       has_neighbor = directions.any? do |_dir, dx, dy|
#         !blocked.call(x + dx, y + dy)
#       end

#       starts << [x, y] if has_neighbor
#     end
#   end

#   return if starts.empty?

#   start_x, start_y = starts[rng.rand(starts.length)]
#   path = [[start_x, start_y]]
#   visited = { [start_x, start_y] => true }

#   current_x, current_y = start_x, start_y
#   closed_loop = false
#   reached_edge = on_edge.call(current_x, current_y)

#   # Recent direction history provides a net directional tendency.
#   direction_history = []
#   last_direction = nil
#   run_length = 0
#   max_history = 16

#   max_steps = size * size * 2

#   max_steps.times do
#     break if reached_edge

#     candidates = []

#     directions.each do |dir, dx, dy|
#       nx = current_x + dx
#       ny = current_y + dy

#       next if nx < 0 || ny < 0 || nx >= size || ny >= size

#       # A return to the starting tile is allowed only to close a meaningful loop.
#       if nx == start_x && ny == start_y
#         if path.length >= 8
#           candidates << {
#             :x => nx, :y => ny, :dir => dir,
#             :closes_loop => true, :weight => 0.8
#           }
#         end
#         next
#       end

#       next if blocked.call(nx, ny)
#       next if visited[[nx, ny]]

#       candidates << {
#         :x => nx, :y => ny, :dir => dir,
#         :closes_loop => false, :noise => noise_at.call(nx, ny)
#       }
#     end

#     break if candidates.empty?

#     ordinary = candidates.reject { |c| c[:closes_loop] }

#     unless ordinary.empty?
#       noises = ordinary.map { |c| c[:noise] }
#       min_noise = noises.min

#       ordinary.each do |candidate|
#         dir = candidate[:dir]
#         nx = candidate[:x]
#         ny = candidate[:y]

#         # Base Perlin weight, shifted positive.
#         weight = 1.0 + candidate[:noise] - min_noise

#         # Favor the overall direction of travel without forbidding turns.
#         if direction_history.length > 0
#           same_count = direction_history.count { |d| d == dir }
#           reverse_count = direction_history.count { |d| d == opposite[dir] }
#           net_bias = (same_count - reverse_count).to_f /
#                      direction_history.length

#           weight *= (1.0 + 0.75 * net_bias)
#         end

#         # Prefer continuing straight, but allow a turn when needed.
#         if last_direction == dir
#           weight *= 1.35
#         elsif last_direction && opposite[last_direction] == dir
#           # Discourage immediate reversals unless we've already travelled
#           # a few tiles in the current direction.
#           weight *= (run_length < 3 ? 0.25 : 0.65)
#         end

#         # Reject candidates that touch older path sections.
#         # The most recent tile is the normal incoming connection.
#         too_close = false

#         path[0, [path.length - 2, 0].max].each do |px, py|
#           distance = (px - nx).abs + (py - ny).abs

#           if distance <= 1
#             too_close = true
#             break
#           end
#         end

#         next if too_close

#         # Keep every legal move possible, even when several penalties overlap.
#         candidate[:weight] = [weight, 0.02].max
#       end
#     end

#     total_weight = candidates.inject(0.0) do |sum, candidate|
#       sum + (candidate[:weight] || 0.0)
#     end

#     break if total_weight <= 0.0

#     roll = rng.rand * total_weight
#     chosen = candidates.find do |candidate|
#       roll -= (candidate[:weight] || 0.0)
#       roll < 0
#     end || candidates.last

#     if chosen[:closes_loop]
#       closed_loop = true
#       break
#     end

#     current_x, current_y = chosen[:x], chosen[:y]
#     path << [current_x, current_y]
#     visited[[current_x, current_y]] = true
#     reached_edge = on_edge.call(current_x, current_y)

#     if last_direction == chosen[:dir]
#       run_length += 1
#     else
#       last_direction = chosen[:dir]
#       run_length = 1
#     end

#     direction_history << chosen[:dir]
#     direction_history.shift while direction_history.length > max_history
#   end

#   # If growth stopped inside the chunk, find the shortest legal continuation
#   # to any reachable edge. BFS avoids existing path tiles and blocked terrain.
#   edge_extended = false

#   unless closed_loop || reached_edge
#     queue = [[current_x, current_y]]
#     queue_index = 0
#     parent = { [current_x, current_y] => nil }
#     edge_target = nil

#     while queue_index < queue.length
#       x, y = queue[queue_index]
#       queue_index += 1

#       if on_edge.call(x, y)
#         edge_target = [x, y]
#         break
#       end

#       directions.each do |_dir, dx, dy|
#         nx = x + dx
#         ny = y + dy
#         point = [nx, ny]

#         next if nx < 0 || ny < 0 || nx >= size || ny >= size
#         next if parent.has_key?(point)
#         next if blocked.call(nx, ny)
#         next if visited[point] && point != [current_x, current_y]

#         parent[point] = [x, y]
#         queue << point
#       end
#     end

#     if edge_target
#       extension = []
#       point = edge_target

#       while point && point != [current_x, current_y]
#         extension << point
#         point = parent[point]
#       end

#       extension.reverse.each do |x, y|
#         path << [x, y]
#         visited[[x, y]] = true
#       end

#       current_x, current_y = edge_target
#       reached_edge = true
#       edge_extended = !extension.empty?
#     end
#   end

#   # Assign markers from the actual path sequence, not every adjacent tile.
#   path.length.times do |i|
#     x, y = path[i]
#     connections = []

#     # Connect to the previous tile in the sequence.
#     if i > 0
#       px, py = path[i - 1]
#       dx = px - x
#       dy = py - y

#       if dx == 1
#         connections << :east
#       elsif dx == -1
#         connections << :west
#       elsif dy == 1
#         connections << :south
#       elsif dy == -1
#         connections << :north
#       end
#     elsif closed_loop
#       # First tile connects back to the last tile when the path loops.
#       px, py = path[-1]
#       dx = px - x
#       dy = py - y

#       if dx == 1
#         connections << :east
#       elsif dx == -1
#         connections << :west
#       elsif dy == 1
#         connections << :south
#       elsif dy == -1
#         connections << :north
#       end
#     end

#     # Connect to the next tile in the sequence.
#     if i < path.length - 1
#       nx, ny = path[i + 1]
#       dx = nx - x
#       dy = ny - y

#       if dx == 1
#         connections << :east
#       elsif dx == -1
#         connections << :west
#       elsif dy == 1
#         connections << :south
#       elsif dy == -1
#         connections << :north
#       end
#     elsif closed_loop
#       # Last tile connects back to the first tile when the path loops.
#       nx, ny = path[0]
#       dx = nx - x
#       dy = ny - y

#       if dx == 1
#         connections << :east
#       elsif dx == -1
#         connections << :west
#       elsif dy == 1
#         connections << :south
#       elsif dy == -1
#         connections << :north
#       end
#     end

#     # Preserve the existing marker convention for straight segments.
#     if connections.include?(:north) && connections.include?(:south)
#       connections = [:north]
#     elsif connections.include?(:east) && connections.include?(:west)
#       connections = [:east]
#     end

#     @cliffPath[x][y] = connections
#   end


#   echoln(
#     "CLIFF PATH: tiles=#{path.length} " +
#     "loop=#{closed_loop} edge=#{reached_edge} " +
#     "extended=#{edge_extended} start=(#{start_x},#{start_y})"
#   )
# end


def apply_switchbacks
  size = ProcWild::CHUNK_SIZE
  new_path = Marshal.load(Marshal.dump(@path))

  size.times do |x|
    size.times do |y|
      next unless @path[x][y]

      h = @height[x][y]

      # check vertical climb chain
      if y < size - 2
        h1 = @height[x][y+1]
        h2 = @height[x][y+2]

        if h1 == h + 1 && h2 == h + 2
          # steep climb detected → reroute sideways
          try_switchback(new_path, x, y, 1)
        end
      end

      # check horizontal climb chain
      if x < size - 2
        h1 = @height[x+1][y]
        h2 = @height[x+2][y]

        if h1 == h + 1 && h2 == h + 2
          try_switchback(new_path, x, y, 0)
        end
      end
    end
  end

  @path = new_path
end

def try_switchback(new_path, x, y, axis)
  offsets = axis == 1 ? [[1,0],[-1,0]] : [[0,1],[0,-1]]

  offsets.each do |dx, dy|
    nx = x + dx
    ny = y + dy

    next if nx < 0 || ny < 0
    next if nx >= ProcWild::CHUNK_SIZE || ny >= ProcWild::CHUNK_SIZE

    next unless @terrain[nx][ny] != TERRAIN_WATER

    # carve sideways
    new_path[nx][ny] = true

    # then reconnect upward
    if axis == 1
      new_path[nx][ny+1] = true if ny+1 < ProcWild::CHUNK_SIZE
    else
      new_path[nx+1][ny] = true if nx+1 < ProcWild::CHUNK_SIZE
    end

    break
  end
end

def switchback_midpoint(from, to)
  fx, fy = from
  tx, ty = to

  dx = tx - fx
  dy = ty - fy

  # perpendicular direction
  if dx.abs > dy.abs
    # mostly horizontal → zig vertically
    offset = (dy >= 0 ? 1 : -1)
    mid = [fx, fy + offset * 4]
  else
    # mostly vertical → zig horizontally
    offset = (dx >= 0 ? 1 : -1)
    mid = [fx + offset * 4, fy]
  end

  clamp_to_chunk_interior(mid[0], mid[1])
end

def generate_forest(rng)

  fill(ProcWild::TERRAIN_GRASS)
  echoln "Generating forest chunk"

  6.times do
    cx = rng.rand(ProcWild::CHUNK_SIZE)
    cy = rng.rand(ProcWild::CHUNK_SIZE)
    radius = rng.rand(4..7)

    paint_circle(cx, cy, radius, ProcWild::TERRAIN_FOREST)
  end

end

def generate_wetlands(rng)
  echoln "Generating wetlands chunk"

  fill(ProcWild::TERRAIN_GRASS)

  8.times do
    cx = rng.rand(ProcWild::CHUNK_SIZE)
    cy = rng.rand(ProcWild::CHUNK_SIZE)
    radius = rng.rand(3..6)

    paint_circle(cx, cy, radius, ProcWild::TERRAIN_WATER)
  end

end

def generate_plains(rng)

  fill(ProcWild::TERRAIN_GRASS)

  # sparse trees
  3.times do
    cx = rng.rand(ProcWild::CHUNK_SIZE)
    cy = rng.rand(ProcWild::CHUNK_SIZE)
    radius = rng.rand(2..4)

    paint_circle(cx, cy, radius, ProcWild::TERRAIN_FOREST)
  end

end

def generate_hills(rng)

  fill(ProcWild::TERRAIN_GRASS)

  # sparse trees
  3.times do
    cx = rng.rand(ProcWild::CHUNK_SIZE)
    cy = rng.rand(ProcWild::CHUNK_SIZE)
    radius = rng.rand(2..4)

    paint_circle(cx, cy, radius, ProcWild::TERRAIN_FOREST)
  end

end

def generate_grass_patches(rng)

  patches = rng.rand(2..4)

  patches.times do
    cx = rng.rand(CHUNK_SIZE)
    cy = rng.rand(CHUNK_SIZE)
    radius = rng.rand(3..6)

    CHUNK_SIZE.times do |x|
      CHUNK_SIZE.times do |y|

        dx = x - cx
        dy = y - cy

        next unless dx*dx + dy*dy <= radius*radius
        next unless @terrain[x][y] == TERRAIN_GRASS

        if near_path?(x,y,3)
          chance = 0.6
        else
          chance = 0.25
        end

        @grass[x][y] = true if rng.rand < chance

      end
    end
  end
end

def search_neighbors(x, y, radius)
   (-radius..radius).each do |dx|
    (-radius..radius).each do |dy|

      nx = x + dx
      ny = y + dy

      next if nx < 0 || ny < 0
      next if nx >= ProcWild::CHUNK_SIZE
      next if ny >= ProcWild::CHUNK_SIZE

      return true if yield(nx, ny)
    end
  end
  return false
end

def fill(terrain)

  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|
      @terrain[x][y] = terrain
    end
  end

end

def smooth_terrain

  new_map = Marshal.load(Marshal.dump(@terrain))

  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|

      counts = Hash.new(0)

      search_neighbors(x, y, 1) do |nx, ny|
        terrain = @terrain[nx][ny]
        counts[terrain] += 1
        false
      end

      new_map[x][y] = counts.max_by { |k,v| v }[0]

    end
  end

  @terrain = new_map

end

def paint_circle(cx, cy, radius, terrain)

  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|

      dx = x - cx
      dy = y - cy

      if dx*dx + dy*dy <= radius*radius
        @terrain[x][y] = terrain
      end

    end
  end

end

def generate_landmarks

  rng = Random.new(seed + 999)

  case @biome

  when ProcWild::BIOME_FOREST
    try_landmark(rng, :berry_grove, 0.15)
    try_landmark(rng, :ruins, 0.05)

  when ProcWild::BIOME_WETLAND
    try_landmark(rng, :pond, 0.25)
    try_landmark(rng, :swamp_tree, 0.10)

  when ProcWild::BIOME_PLAINS
    try_landmark(rng, :pond, 0.10)
    try_landmark(rng, :trainer_camp, 0.05)

  when ProcWild::BIOME_HILLS
    try_landmark(rng, :cave, 0.15)

  end
end

  def try_landmark(rng, type, chance)

  return unless rng.rand < chance

  x = rng.rand(ProcWild::CHUNK_SIZE)
  y = rng.rand(ProcWild::CHUNK_SIZE)

  @landmarks << {type: type, x: x, y: y}

end


def generate_encounters

  rng = Random.new(seed + 5000)

  case @biome

  when ProcWild::BIOME_FOREST
    add_encounter_zone(rng, :grass_patch, 4)

  when ProcWild::BIOME_WETLAND
    add_encounter_zone(rng, :deep_water, 3)

  when ProcWild::BIOME_PLAINS
    add_encounter_zone(rng, :grass_patch, 2)

  when ProcWild::BIOME_HILLS
    add_encounter_zone(rng, :rocky_patch, 2)

  end

end

def add_encounter_zone(rng, type, count)

  count.times do

    x = rng.rand(ProcWild::CHUNK_SIZE)
    y = rng.rand(ProcWild::CHUNK_SIZE)
    radius = rng.rand(3..6)

    @encounters << {
      type: type,
      x: x,
      y: y,
      radius: radius
    }

  end

end


def cliff_marker_counts
  counts = Hash.new(0)

  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|
      marker = @cliffPath[x][y]

      if marker.nil? || marker.empty?
        counts[:empty] += 1
      elsif marker.is_a?(Array)
        counts[marker.length] += 1
      else
        counts[:single_symbol] += 1
      end
    end
  end

  counts
end

end
end