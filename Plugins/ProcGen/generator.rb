module ProcWild

class WorldGenerator
DEBUG_CLIFF_RENDER = false
DEBUG_CLIFF_CORNER_CLASSIFIER = false
DEBUG_CLIFF_CORNER_REPORT = true
CLIFF_CORNER_REPORT_FILE = "cliff_corner_assignments_report.txt"

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
TILE_CLIFF_BR = 1188
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

def reset_corner_report!(center_x = nil, center_y = nil, radius = nil)
  @corner_report_counts = {}
  @corner_report_samples = {}
  @corner_report_meta = {
    :center_x => center_x,
    :center_y => center_y,
    :radius => radius,
    :time => Time.now
  }
end

def corner_turn_from_faces(face_in, face_out)
  in_vec = movement_vector_for_face(face_in)
  out_vec = movement_vector_for_face(face_out)
  return [:unknown, nil] if in_vec.nil? || out_vec.nil?

  cross = in_vec[0] * out_vec[1] - in_vec[1] * out_vec[0]
  return [:straight, 0] if cross == 0

  # Positive cross indicates a clockwise/right turn in screen-space (y-down).
  turn = cross > 0 ? :right : :left
  [turn, cross]
end

def record_corner_assignment(chunk, x, y, dirs, face_out, face_in,
                             corner_type, corner_key, tile_id, source)
  return unless DEBUG_CLIFF_CORNER_REPORT

  @corner_report_counts ||= {}
  @corner_report_samples ||= {}

  wx = chunk.nil? ? x : world_x(chunk, x)
  wy = chunk.nil? ? y : world_y(chunk, y)
  dirs_key = dirs.map { |d| d.to_s }.sort.join("+")
  turn, cross = corner_turn_from_faces(face_in, face_out)

  signature = [
    source,
    corner_key,
    corner_type,
    dirs_key,
    face_in,
    face_out,
    turn,
    cross,
    tile_id
  ]

  @corner_report_counts[signature] ||= 0
  @corner_report_counts[signature] += 1

  @corner_report_samples[signature] ||= []
  samples = @corner_report_samples[signature]
  samples << [wx, wy] if samples.length < 8
end

def flush_corner_report!
  return unless DEBUG_CLIFF_CORNER_REPORT
  return if @corner_report_counts.nil? || @corner_report_counts.empty?

  File.open(CLIFF_CORNER_REPORT_FILE, "w") do |f|
    meta = @corner_report_meta || {}
    f.puts("CLIFF CORNER ASSIGNMENT REPORT")
    f.puts("generated_at=#{meta[:time]}")
    f.puts("center=(#{meta[:center_x]},#{meta[:center_y]}) radius=#{meta[:radius]}")
    f.puts("fields: count | source | key | type | dirs | in_face | out_face | turn | cross | tile | samples")
    f.puts("")

    entries = @corner_report_counts.keys.sort_by do |signature|
      -@corner_report_counts[signature]
    end

    entries.each do |signature|
      count = @corner_report_counts[signature]
      samples = (@corner_report_samples[signature] || []).map do |wx, wy|
        "(#{wx},#{wy})"
      end.join(" ")

      source, key, type, dirs_key, face_in, face_out, turn, cross, tile_id = signature
      f.puts(
        "#{count} | #{source} | #{key} | #{type} | #{dirs_key} | " +
        "#{face_in} | #{face_out} | #{turn} | #{cross} | #{tile_id} | #{samples}"
      )
    end
  end

  echoln("CLIFF CORNER REPORT: wrote #{CLIFF_CORNER_REPORT_FILE} (#{@corner_report_counts.length} signatures)")
end



def cliff_tile_for(marker, chunk = nil, x = nil, y = nil)
  dirs = marker_to_dirs(marker)
  return nil if dirs.empty?

  north = dirs.include?(:north)
  south = dirs.include?(:south)
  west  = dirs.include?(:west)
  east  = dirs.include?(:east)

  corner_key = cliff_corner_key_for_dirs(dirs)
  if corner_key && !x.nil? && !y.nil?
    face = nil
    face_in = nil
    if chunk.respond_to?(:cliffFace) && chunk.cliffFace && chunk.cliffFace[x]
      face = chunk.cliffFace[x][y]
    end
    if chunk.respond_to?(:cliffFaceIn) && chunk.cliffFaceIn && chunk.cliffFaceIn[x]
      face_in = chunk.cliffFaceIn[x][y]
    end

    corner = classify_cliff_corner(chunk, x, y, dirs, face, face_in)
    if corner && corner[:type] && corner[:key]
      tile_id = corner_tile_id(corner[:type], corner[:key], face, face_in)
      if !tile_id.nil?
        record_corner_assignment(
          chunk,
          x,
          y,
          dirs,
          face,
          face_in,
          corner[:type],
          corner[:key],
          tile_id,
          :classifier
        )
      end
      return tile_id
    end
  end

  # Fallback to the direct corner-sheet mapping if the corner classifier is not
  # available for a given path state.
  if north && west && !east && !south
    tile_id = TILE_CLIFF_CORNER_4
    record_corner_assignment(chunk, x, y, dirs, nil, nil, :fallback, :nw, tile_id, :fallback)
    return tile_id
  elsif north && east && !west && !south
    tile_id = TILE_CLIFF_CORNER_3
    record_corner_assignment(chunk, x, y, dirs, nil, nil, :fallback, :ne, tile_id, :fallback)
    return tile_id
  elsif south && west && !north && !east
    tile_id = TILE_CLIFF_CORNER_2
    record_corner_assignment(chunk, x, y, dirs, nil, nil, :fallback, :sw, tile_id, :fallback)
    return tile_id
  elsif south && east && !north && !west
    tile_id = TILE_CLIFF_CORNER_1
    record_corner_assignment(chunk, x, y, dirs, nil, nil, :fallback, :se, tile_id, :fallback)
    return tile_id
  end

  face = nil
  if chunk && chunk.respond_to?(:cliffFace) && chunk.cliffFace &&
     !x.nil? && !y.nil? && chunk.cliffFace[x]
    face = chunk.cliffFace[x][y]
  end

  return TILE_CLIFF_S if face == :south
  return TILE_CLIFF_N if face == :north
  # Face labels are mirrored relative to the tilesheet's E/W wall art.
  return TILE_CLIFF_E if face == :west
  return TILE_CLIFF_W if face == :east

  # Legacy marker fallback for straight walls.
  return TILE_CLIFF_N if north && !south && !east && !west
  return TILE_CLIFF_S if south && !north && !east && !west
  return TILE_CLIFF_E if west && !east && !north && !south
  return TILE_CLIFF_W if east && !west && !north && !south

  return TILE_CLIFF_TOP if north && south && !east && !west
  return TILE_CLIFF_TOP if east && west && !north && !south
  return TILE_CLIFF_TOP if north && east && south && west

  nil
end

def marker_to_dirs(marker)
  marker.is_a?(Array) ? marker.compact.uniq : [marker].compact.uniq
end

def cliff_marker_dirs_at(chunk, x, y)
  return [] if chunk.nil?
  return [] if x.nil? || y.nil?
  return [] if x < 0 || y < 0
  return [] if x >= ProcWild::CHUNK_SIZE || y >= ProcWild::CHUNK_SIZE

  marker = chunk.cliffPath[x][y]
  marker_to_dirs(marker)
end

def cliff_has_marker_at?(chunk, x, y)
  !cliff_marker_dirs_at(chunk, x, y).empty?
end

def cliff_corner_key_for_dirs(dirs)
  north = dirs.include?(:north)
  south = dirs.include?(:south)
  west  = dirs.include?(:west)
  east  = dirs.include?(:east)

  return :nw if north && west && !east && !south
  return :ne if north && east && !west && !south
  return :sw if south && west && !north && !east
  return :se if south && east && !north && !west

  nil
end

def rotate_corner_key_clockwise(corner_key)
  return corner_key if corner_key.nil?

  # Exact 90° clockwise rotation in the cliff tilesheet quadrants:
  # TL -> TR -> BR -> BL -> TL
  {
    :nw => :ne,
    :ne => :se,
    :se => :sw,
    :sw => :nw
  }[corner_key] || corner_key
end

def corner_tile_id(corner_type, corner_key, face = nil, face_in = nil)
  return nil if corner_type.nil? || corner_key.nil?

  rotated_key = rotate_corner_key_clockwise(corner_key)

  if corner_type == :convex
    return {
      :nw => TILE_CLIFF_BL,
      :ne => TILE_CLIFF_BR,
      :sw => TILE_CLIFF_TR,
      :se => TILE_CLIFF_TL
    }[rotated_key]
  end

  {
    :nw => TILE_CLIFF_CORNER_4,
    :ne => TILE_CLIFF_CORNER_3,
    :sw => TILE_CLIFF_CORNER_1,
    :se => TILE_CLIFF_CORNER_2
  }[rotated_key]
end

def movement_vector_for_face(face)
  # Inverse of the counterclockwise cliff-face mapping used by the generator.
  return [0, -1] if face == :west
  return [1, 0] if face == :north
  return [0, 1] if face == :east
  return [-1, 0] if face == :south
  nil
end

def classify_cliff_corner(chunk, x, y, dirs, face_out = nil, face_in = nil)
  return nil if chunk.nil?
  return nil if x.nil? || y.nil?

  corner_key = cliff_corner_key_for_dirs(dirs)
  return nil if corner_key.nil?

  # Primary classifier: use ordered turn direction from path flow.
  # With this tileset's cliff-face convention, left turns are concave and
  # right turns are convex.
  in_vec = movement_vector_for_face(face_in)
  out_vec = movement_vector_for_face(face_out)

  if in_vec && out_vec
    cross = in_vec[0] * out_vec[1] - in_vec[1] * out_vec[0]
    if cross != 0
      # The tileset's corner semantics are reversed relative to the raw
      # screen-space turn sign, so the sign must be flipped here to keep
      # concave corners in concave slots and convex corners in convex slots.
      corner_type = cross > 0 ? :convex : :concave
      if DEBUG_CLIFF_CORNER_CLASSIFIER
        echoln(
          "CLIFF CORNER (#{x},#{y}) key=#{corner_key} type=#{corner_type} " +
          "via=turn cross=#{cross} in=#{face_in} out=#{face_out}"
        )
      end
      return {
        :type => corner_type,
        :key => corner_key
      }
    end
  end

  # Fallback: infer from local diagonal occupancy when flow data is ambiguous.
  dx = 0
  dy = 0
  if corner_key == :nw
    dx = -1
    dy = -1
  elsif corner_key == :ne
    dx = 1
    dy = -1
  elsif corner_key == :sw
    dx = -1
    dy = 1
  elsif corner_key == :se
    dx = 1
    dy = 1
  end

  inner_dirs = cliff_marker_dirs_at(chunk, x + dx, y + dy)
  inner_corner = !cliff_corner_key_for_dirs(inner_dirs).nil?
  inner_segment = !inner_dirs.empty?

  corner_type = (inner_corner || inner_segment) ? :convex : :concave

  if DEBUG_CLIFF_CORNER_CLASSIFIER
    echoln(
      "CLIFF CORNER (#{x},#{y}) key=#{corner_key} type=#{corner_type} " +
      "via=fallback inner_dirs=#{inner_dirs.inspect} in=#{face_in} out=#{face_out}"
    )
  end

  {
    :type => corner_type,
    :key => corner_key
  }
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
        tile_id = cliff_tile_for(chunk.cliffPath[x][y], chunk, x, y)
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
  reset_corner_report!(center_x, center_y, radius)

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

          if DEBUG_CLIFF_RENDER &&
             chunk.cliffPath[x][y] &&
             !chunk.cliffPath[x][y].empty?
            debug_cliff_cell(chunk, x, y)
          end

          # Trees are a layer-1 decoration and must not occupy cliff cells.
          if terrain == ProcWild::TERRAIN_FOREST &&
             !road_tile?(chunk, x, y) &&
             (chunk.cliffPath[x][y].nil? || chunk.cliffPath[x][y].empty?)
            map.data[map_x, map_y, 1] = TILE_TREE
          end

          # Render cliffs last so the wall face wins over decorations.
          render_cliff_overlay(map, chunk, x, y, map_x, map_y)
        end
      end
    end
  end

  flush_corner_report!

  return map
end


def render_cliff_overlay(map, chunk, x, y, map_x, map_y)
  marker = chunk.cliffPath[x][y]
  return if marker.nil? || marker.empty?

  tile_id = cliff_tile_for(marker, chunk, x, y)
  return if tile_id.nil?

  # RMXP cliff overlays belong on the top/face layer, not the ground layer.
  # This is the actual rendering layer used for wall/edge tiles.
  map.data[map_x, map_y, 1] = tile_id

  if defined?(ProcWild::CliffMomentumDebug)
    momentum_dir = nil
    marker = chunk.cliffPath[x][y]
    if marker
      momentum_dir = ProcWild::CliffMomentumDebug.instance.direction_from_marker(marker)
    end

    @cliff_momentum_debug ||= ProcWild::CliffMomentumDebug.instance
    @cliff_momentum_debug.paint_debug_tile(map, map_x, map_y, momentum_dir) if momentum_dir
  end
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
  req_min_cx = center_x - radius
  req_max_cx = center_x + radius
  req_min_cy = center_y - radius
  req_max_cy = center_y + radius

  chunk_cache = {}
  fetch_chunk = lambda do |cx, cy|
    key = [cx, cy]
    return chunk_cache[key] if chunk_cache.key?(key)
    chunk_cache[key] = grid.get_chunk(cx, cy)
  end

  requested_chunks = {}

  req_min_cx.upto(req_max_cx) do |cx|
    req_min_cy.upto(req_max_cy) do |cy|
      chunk = fetch_chunk.call(cx, cy)
      next unless chunk

      requested_chunks[[cx, cy]] = chunk

      size.times do |x|
        size.times do |y|
          chunk.cliffPath[x][y] = []
          chunk.cliffFace[x][y] = nil if chunk.respond_to?(:cliffFace) && chunk.cliffFace
          chunk.cliffFaceIn[x][y] = nil if chunk.respond_to?(:cliffFaceIn) && chunk.cliffFaceIn
        end
      end
    end
  end

  chunk_at = lambda do |wx, wy|
    cx = wx.div(size)
    cy = wy.div(size)
    fetch_chunk.call(cx, cy)
  end

  active_min_x = req_min_cx * size
  active_max_x = (req_max_cx + 1) * size - 1
  active_min_y = req_min_cy * size
  active_max_y = (req_max_cy + 1) * size - 1

  min_x = active_min_x
  max_x = active_max_x
  min_y = active_min_y
  max_y = active_max_y

  claimed = {}

  blocked = lambda do |wx, wy|
    if wx < active_min_x || wx > active_max_x ||
       wy < active_min_y || wy > active_max_y
      true
    else
      chunk = chunk_at.call(wx, wy)
      if !chunk
        true
      else
        # Multiple cliff strings are allowed, but they may not overlap.
        claimed.key?([wx, wy])
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

  near_existing_cliff = lambda do |wx, wy, radius|
    (-radius..radius).each do |dx|
      remaining = radius - dx.abs
      (-remaining..remaining).each do |dy|
        return true if claimed.key?([wx + dx, wy + dy])
      end
    end

    false
  end

  same_lane_overlap = lambda do |wx, wy, dir|
    case dir
    when :east, :west
      claimed.each_key.any? do |x, y|
        y == wy && (x - wx).abs <= 1
      end
    when :north, :south
      claimed.each_key.any? do |x, y|
        x == wx && (y - wy).abs <= 1
      end
    else
      false
    end
  end

  write_marker = lambda do |wx, wy, marker, face, face_in|
    next if wx < active_min_x || wx > active_max_x ||
            wy < active_min_y || wy > active_max_y

    claimed[[wx, wy]] = true

    cx = wx.div(size)
    cy = wy.div(size)
    chunk = requested_chunks[[cx, cy]]
    next unless chunk

    lx = wx % size
    ly = wy % size
    existing = chunk.cliffPath[lx][ly]
    existing_markers = existing.is_a?(Array) ? existing :
      (existing.nil? ? [] : [existing])
    new_markers = marker.is_a?(Array) ? marker :
      (marker.nil? ? [] : [marker])

    chunk.cliffPath[lx][ly] = (existing_markers + new_markers).compact.uniq
    if chunk.respond_to?(:cliffFace) && chunk.cliffFace
      chunk.cliffFace[lx][ly] = face if chunk.cliffFace[lx][ly].nil?
    end
    if chunk.respond_to?(:cliffFaceIn) && chunk.cliffFaceIn
      chunk.cliffFaceIn[lx][ly] = face_in if chunk.cliffFaceIn[lx][ly].nil?
    end
  end

  max_height = 0
  requested_chunks.each_value do |chunk|
    next unless chunk.respond_to?(:height)
    chunk.height.each do |row|
      row.each do |h|
        next if h.nil?
        max_height = [max_height, h.to_i].max
      end
    end
  end

  path_count = [max_height, 1].max
  total_tiles = 0

  path_count.times do |index|
    path_rng = Random.new(ProcWild.world_seed.to_i ^ (center_x * 131071) ^ (center_y * 524287) ^ (index * 131071))
    path = ProcWild::CliffPathBuilder.generate(
      min_x,
      max_x,
      min_y,
      max_y,
      path_rng,
      blocked,
      noise_at,
      write_marker,
      near_existing_cliff,
      same_lane_overlap
    )

    if path.respond_to?(:length) && !path.empty?
      total_tiles += path.length
      echoln "WORLD CLIFF PATH: branch=#{index} tiles=#{path.length}"
    end
  end

  echoln "WORLD CLIFF PATH: total active-window tiles=#{total_tiles}"
end



end
end