module ProcWild

class WorldGenerator
TILE_GRASS  = 385
TILE_GRASS2 = 386
TILE_GRASS3 = 387
TILE_GRASS4 = 388
TILE_GRASS5 = 389
TILE_WATER  = 1097
TILE_TREE   = 450
TILE_TALL_GRASS = 390
TILE_LIGHTGRASS = 401
TILE_DEBUG =500
TILE_CLIFF_TL = 1168
TILE_CLIFF_N = 1169
TILE_CLIFF_TR = 1170
TILE_CLIFF_E = 1176
TILE_CLIFF_TOP = 1177
TILE_CLIFF_W = 1178
TILE_CLIFF_BR = 1184
TILE_CLIFF_S = 1185
TILE_CLIFF_BL = 1186
TILE_CLIFF_CORNER_1 = 1192
TILE_CLIFF_CORNER_2 = 1193
TILE_CLIFF_CORNER_3 = 1200
TILE_CLIFF_CORNER_4 = 1201
TILE_DIRTROAD = 546
TILE_STAIR = 1162

  def pick_random_grass_tile()
    r = rand(100)
    if r < 20
      return TILE_GRASS2
    elsif r < 40
      return TILE_GRASS3
    elsif r < 60
      return TILE_GRASS4
    elsif r < 80
      return TILE_GRASS5
    else
      return TILE_GRASS
    end
  end

  

def generate_area(grid, center_x, center_y, radius)
  echoln "GENERATE_AREA ENTERED: center=#{center_x},#{center_y} radius=#{radius}"

  (-radius..radius).each do |dx|
    (-radius..radius).each do |dy|
      grid.get_chunk(center_x + dx, center_y + dy)
    end
  end

  echoln "GENERATE_AREA: chunks generated; calling world cliffs"
  generate_world_cliff_paths(grid, center_x, center_y, radius)
  echoln "GENERATE_AREA: world cliffs finished"
end



def cliff_tile_for(marker, _chunk = nil, _x = nil, _y = nil)
  dirs = marker.is_a?(Array) ? marker.compact.uniq : [marker].compact.uniq

  north = dirs.include?(:north)
  south = dirs.include?(:south)
  west  = dirs.include?(:west)
  east  = dirs.include?(:east)

  # Markers now describe path geometry, not elevation boundaries.
  # Straight paths are normalized to one representative axis marker by Chunk.
  return TILE_CLIFF_TL if north && west && !east && !south
  return TILE_CLIFF_TR if north && east && !west && !south
  return TILE_CLIFF_BL if south && west && !north && !east
  return TILE_CLIFF_BR if south && east && !north && !west

  return TILE_CLIFF_N if north && !south && !east && !west
  return TILE_CLIFF_S if south && !north && !east && !west
  return TILE_CLIFF_W if west && !east && !north && !south
  return TILE_CLIFF_E if east && !west && !north && !south

  nil
end

  def road_tile?(chunk, x, y)
    return false if x < 0 || y < 0
    return false if x >= ProcWild::CHUNK_SIZE || y >= ProcWild::CHUNK_SIZE
    return chunk.roadMask[x][y] if !chunk.roadMask.nil? && !chunk.roadMask[x].nil?
    chunk.path[x][y]
  end

def build_RMXP_map(chunk)
  echoln "USING build_RMXP_map"

  map = RPG::Map.new(ProcWild::CHUNK_SIZE, ProcWild::CHUNK_SIZE)

  ProcWild::CHUNK_SIZE.times do |x|
    ProcWild::CHUNK_SIZE.times do |y|
      terrain = chunk.terrain[x][y] 

      # Traversal intent should win: roads override blockers/biome visuals.
      if road_tile?(chunk, x, y)
        tile_id = TILE_DIRTROAD
      elsif terrain == ProcWild::TERRAIN_WATER
        tile_id = TILE_WATER
      elsif chunk.cliffPath[x][y] && !chunk.cliffPath[x][y].empty?
        tile_id = cliff_tile_for(chunk.cliffPath[x][y])
      elsif chunk.height[x][y] >= 3
        tile_id = TILE_CLIFF_TOP
      elsif terrain == ProcWild::TERRAIN_GRASS
        if chunk.grass[x][y]
          tile_id = TILE_TALL_GRASS
        else
          tile_id = pick_random_grass_tile()
        end
      elsif terrain == ProcWild::TERRAIN_FOREST
        tile_id = pick_random_grass_tile()
        map.data[x,y,1] = TILE_TREE
      else
        tile_id = pick_random_grass_tile()
      end

      map.data[x,y,0] = tile_id

    end
  end

  return map

end

def build_area_map(grid, center_x, center_y, radius)
  chunk_size = ProcWild::CHUNK_SIZE
  chunks_across = radius * 2 + 1

  map_width  = chunks_across * chunk_size
  map_height = chunks_across * chunk_size

  map = RPG::Map.new(map_width, map_height)

  (-radius..radius).each do |cx|
    (-radius..radius).each do |cy|
      chunk = grid.get_chunk(center_x + cx, center_y + cy)

      offset_x = (cx + radius) * chunk_size
      offset_y = (cy + radius) * chunk_size

      chunk_size.times do |x|
        chunk_size.times do |y|
          terrain = chunk.terrain[x][y]
          map_x = offset_x + x
          map_y = offset_y + y

          # Layer 0: underlying ground and roads only.
          if road_tile?(chunk, x, y)
            ground_tile = TILE_DIRTROAD
          elsif terrain == ProcWild::TERRAIN_WATER
            ground_tile = TILE_WATER
          elsif terrain == ProcWild::TERRAIN_GRASS
            if chunk.grass[x][y]
              ground_tile = TILE_TALL_GRASS
            else
              ground_tile = pick_random_grass_tile()
            end
          elsif terrain == ProcWild::TERRAIN_FOREST
            ground_tile = pick_random_grass_tile()
          else
            ground_tile = pick_random_grass_tile()
          end

          map.data[map_x, map_y, 0] = ground_tile
          # Layer 1: cliff overlay only where a boundary exists.

          if chunk.cliffPath[x][y] &&
            !chunk.cliffPath[x][y].empty?
            debug_cliff_cell(chunk, x, y)
          end

          render_cliff_overlay(map, chunk, x, y, map_x, map_y)
          # Preserve existing forest tree rendering.
          if terrain == ProcWild::TERRAIN_FOREST &&
             !road_tile?(chunk, x, y)
            map.data[map_x, map_y, 1] = TILE_TREE
          end
        end
      end
    end
  end

  return map
end


def render_cliff_overlay(map, chunk, x, y, map_x, map_y)
  marker = chunk.cliffPath[x][y]
  return if marker.nil? || marker.empty?

  tile_id = cliff_tile_for(marker, chunk, x, y)
  return if tile_id.nil?

  map.data[map_x, map_y, 1] = tile_id
end


def debug_cliff_cell(chunk, x, y)
  size = ProcWild::CHUNK_SIZE

  return if x < 0 || y < 0 || x >= size || y >= size

  h = chunk.height[x][y]

  north = y > 0      ? chunk.height[x][y - 1] : nil
  south = y < size-1 ? chunk.height[x][y + 1] : nil
  west  = x > 0      ? chunk.height[x - 1][y] : nil
  east  = x < size-1 ? chunk.height[x + 1][y] : nil

  marker = chunk.cliffPath[x][y]

  echoln "CLIFF DEBUG (#{x},#{y})"
  echoln "  height=#{h} N=#{north} S=#{south} W=#{west} E=#{east}"
  echoln "  marker=#{marker.inspect}"
  echoln "  road=#{road_tile?(chunk, x, y)}"
  echoln "  terrain=#{chunk.terrain[x][y]}"
end


def world_x(chunk, x)
  chunk.cx * ProcWild::CHUNK_SIZE + x
end

def world_y(chunk, y)
  chunk.cy * ProcWild::CHUNK_SIZE + y
end

def chunk_x(world_x)
  world_x % ProcWild::CHUNK_SIZE
end

def chunk_y(world_y)
  world_y % ProcWild::CHUNK_SIZE
end

def chunk_coord_x(world_x)
  world_x.div(ProcWild::CHUNK_SIZE)
end

def chunk_coord_y(world_y)
  world_y.div(ProcWild::CHUNK_SIZE)
end


def generate_world_cliff_paths(grid, center_x, center_y, radius)
  size = ProcWild::CHUNK_SIZE
  min_cx = center_x - radius
  max_cx = center_x + radius
  min_cy = center_y - radius
  max_cy = center_y + radius

  min_x = min_cx * size
  max_x = (max_cx + 1) * size - 1
  min_y = min_cy * size
  max_y = (max_cy + 1) * size - 1

  width = max_x - min_x + 1
  height = max_y - min_y + 1

  # A stable seed for repeat generation of the same requested area.
  seed = ProcWild::WORLD_SEED +
         center_x * 928371 +
         center_y * 123123 +
         radius * 7919
  rng = Random.new(seed)

  directions = [
    [:north,  0, -1],
    [:south,  0,  1],
    [:west,  -1, 0],
    [:east,   1,  0]
  ]

  # Cache the participating chunks and clear their previous local paths.
  chunks = {}

  min_cx.upto(max_cx) do |cx|
    min_cy.upto(max_cy) do |cy|
      chunk = grid.get_chunk(cx, cy)
      chunks[[cx, cy]] = chunk

      size.times do |x|
        size.times do |y|
          chunk.cliffPath[x][y] = []
        end
      end
    end
  end

  # Convert a world tile to its chunk and local coordinates.
  chunk_at = lambda do |wx, wy|
    cx = chunk_coord_x(wx)
    cy = chunk_coord_y(wy)
    chunk = chunks[[cx, cy]]
    next nil unless chunk

    [chunk, chunk_x(wx), chunk_y(wy)]
  end

  # Roads, water, and bridges cannot be occupied by a cliff path.
  blocked = lambda do |wx, wy|
    next true if wx < min_x || wx > max_x
    next true if wy < min_y || wy > max_y

    cell = chunk_at.call(wx, wy)
    next true unless cell

    chunk, lx, ly = cell

    chunk.path[lx][ly] ||
      chunk.terrain[lx][ly] == ProcWild::TERRAIN_WATER ||
      (chunk.roadMask && chunk.roadMask[lx][ly]) ||
      (chunk.bridgePath && chunk.bridgePath[lx][ly])
  end

  # Find viable start tiles throughout the world area.
  starts = []

  min_x.upto(max_x) do |wx|
    min_y.upto(max_y) do |wy|
      next if blocked.call(wx, wy)

      has_neighbor = directions.any? do |_dir, dx, dy|
        !blocked.call(wx + dx, wy + dy)
      end

      starts << [wx, wy] if has_neighbor
    end
  end

  return if starts.empty?

  # Geometry is stored in world coordinates, independent of chunk edges.
  start = starts[rng.rand(starts.length)]
  path = [start]
  visited = { start => true }

  current_x, current_y = start
  max_steps = width * height
  max_steps.times do
    # Finish when the path reaches the boundary of the generated area.
    break if current_x == min_x || current_x == max_x ||
             current_y == min_y || current_y == max_y

    candidates = []

    directions.each do |dir, dx, dy|
      nx = current_x + dx
      ny = current_y + dy
      next if blocked.call(nx, ny)
      next if visited[[nx, ny]]

      # Favor continuing straight while allowing occasional turns.
      previous = path.length > 1 ? path[-2] : nil
      straight = previous &&
        (current_x - previous[0] == dx) &&
        (current_y - previous[1] == dy)

      weight = straight ? 4 : 2
      candidates << [nx, ny, weight]
    end

    break if candidates.empty?

    total_weight = candidates.inject(0) { |sum, item| sum + item[2] }
    roll = rng.rand(total_weight)
    chosen = candidates[0]

    candidates.each do |candidate|
      roll -= candidate[2]
      if roll < 0
        chosen = candidate
        break
      end
    end

    current_x, current_y = chosen[0], chosen[1]
    path << [current_x, current_y]
    visited[[current_x, current_y]] = true
  end

  # Build markers from world-space neighbors, not chunk-local neighbors.
  path_set = {}
  path.each { |wx, wy| path_set[[wx, wy]] = true }

  path.each do |wx, wy|
    connections = []

    directions.each do |dir, dx, dy|
      connections << dir if path_set[[wx + dx, wy + dy]]
    end

    # Match the marker conventions used by cliff_tile_for.
    if connections.include?(:north) && connections.include?(:south)
      marker = [:north]
    elsif connections.include?(:east) && connections.include?(:west)
      marker = [:east]
    else
      marker = connections
    end

    cell = chunk_at.call(wx, wy)
    next unless cell

    chunk, lx, ly = cell
    chunk.cliffPath[lx][ly] = marker
  end

  echoln "WORLD CLIFF PATH: tiles=#{path.length} area=#{width}x#{height}"
end


end
end