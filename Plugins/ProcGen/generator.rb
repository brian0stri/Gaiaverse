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
  ProcWild::Chunk.generate_world_cliff_paths(grid, center_x, center_y, radius)
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


end
end
