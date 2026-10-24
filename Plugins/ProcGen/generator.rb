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
