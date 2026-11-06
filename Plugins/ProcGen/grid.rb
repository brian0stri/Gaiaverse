module ProcWild

  def self.biome_for_world_tile(wx, wy)
    region_x = wx.div(12)
    region_y = wy.div(12)
    macro_x = wx.div(CHUNK_SIZE * 3)
    macro_y = wy.div(CHUNK_SIZE * 3)

    value = (
      (region_x * 374761) ^
      (region_y * 668265) ^
      (macro_x * 144269) ^
      (macro_y * 700001) ^
      world_seed
    ) & 0xffffffff

    r = value % 100

    case r
    when 0..29
      BIOME_FOREST
    when 30..59
      BIOME_PLAINS
    when 60..84
      BIOME_WETLAND
    else
      BIOME_HILLS
    end
  end

  def self.road_biome_cost(wx, wy)
    case biome_for_world_tile(wx, wy)
    when BIOME_PLAINS
      0
    when BIOME_FOREST
      0.75
    when BIOME_HILLS
      1.0
    when BIOME_WETLAND
      2.0
    else
      0
    end
  end

  class Grid

    attr_reader :chunks
    attr_reader :biome
    attr_accessor :routes

    def initialize
      @chunks = {}
      @left_chunk = false
      @routes = {}
      @biome_cache = {}
      @dirs = {}
      @generating = {}
      @anchors = {
        city_a: {x:0, y:0},
        city_b: {x:8, y:2},
        city_c: {x:-3, y:4}
      }
      @connections = [
        [:city_a, :city_b],
        [:city_a, :city_c]
      ]
      @route_chunks = {}
      @route_links = Hash.new { |hash, key| hash[key] = {} }
      main_connection = longest_connection

      @connections.each do |a_id, b_id|
        a = @anchors[a_id]
        b = @anchors[b_id]
        raise "Anchor missing!" if a.nil? || b.nil?

        rng = Random.new((a[:x] * 9999 + b[:x] * 7777) ^ ProcWild.world_seed)
        points = route_between(a, b)
        register_route(points)

        if [a_id, b_id] == main_connection
          rng.rand(1..2).times do
            register_route(add_loops_to_route(points, rng))
          end
        end
      end

      normalize_route_graph!
    end

    def get_tile(wx, wy)

      cx = wx / CHUNK_SIZE
      cy = wy / CHUNK_SIZE

      tx = wx % CHUNK_SIZE
      ty = wy % CHUNK_SIZE

      chunk = get_chunk(cx, cy)

      return chunk.tiles[tx][ty]

    end

    def world_coords(chunk_x, chunk_y, local_x, local_y)
      [
        chunk_x * CHUNK_SIZE + local_x,
        chunk_y * CHUNK_SIZE + local_y
      ]
    end

    def local_coords(world_x, world_y)
      chunk_x = world_x.div(CHUNK_SIZE)
      chunk_y = world_y.div(CHUNK_SIZE)

      local_x = world_x % CHUNK_SIZE
      local_y = world_y % CHUNK_SIZE

      [chunk_x, chunk_y, local_x, local_y]
    end

    def get_chunk(cx, cy)

      key = [cx,cy]
      return @chunks[key] if @chunks[key]
      return nil if @generating[key]
      @generating[key] = true
      biome = biome_at(cx,cy)
      chunk = Chunk.new(cx,cy,biome)
      @chunks[key] = chunk

      if route_chunk?(cx, cy)
        center_x = ProcWild::CHUNK_SIZE / 2
        center_y = ProcWild::CHUNK_SIZE / 2
        links = route_links_for(cx, cy)

        if links.empty?
          chunk.path_start = [0, center_y]
          chunk.path_end = [ProcWild::CHUNK_SIZE - 1, center_y]
        end

        if links[:west]
          chunk.west_entry = [0, center_y]
          chunk.path_start = [0, center_y]
        end

        if links[:east]
          chunk.east_exit = [ProcWild::CHUNK_SIZE - 1, center_y]
          chunk.path_end = [ProcWild::CHUNK_SIZE - 1, center_y]
        end

        if links[:north]
          chunk.north_entry = [center_x, 0]
          chunk.north_exit = [center_x, 0]
        end

        if links[:south]
          chunk.south_entry = [center_x, ProcWild::CHUNK_SIZE - 1]
          chunk.south_exit = [center_x, ProcWild::CHUNK_SIZE - 1]
        end
      end

      chunk.generate
      echoln "Generating chunk #{cx},#{cy}"

      @generating.delete(key)

      return chunk

    end

    def route_chunk?(cx, cy)
      return true if @route_chunks[[cx, cy]] == true

      west_neighbor  = @route_links[[cx - 1, cy]]
      east_neighbor  = @route_links[[cx + 1, cy]]
      north_neighbor = @route_links[[cx, cy - 1]]
      south_neighbor = @route_links[[cx, cy + 1]]

      return true if west_neighbor[:east]
      return true if east_neighbor[:west]
      return true if north_neighbor[:south]
      return true if south_neighbor[:north]

      return false
    end

    def route_links_for(cx, cy)
      links = @route_links[[cx, cy]].dup
      links[:west]  = true if route_chunk?(cx - 1, cy)
      links[:east]  = true if route_chunk?(cx + 1, cy)
      links[:north] = true if route_chunk?(cx, cy - 1)
      links[:south] = true if route_chunk?(cx, cy + 1)
      links
    end

    def normalize_route_graph!
      all_route_nodes = @route_chunks.keys.dup

      @route_links.each do |(cx, cy), links|
        all_route_nodes << [cx - 1, cy] if links[:west]
        all_route_nodes << [cx + 1, cy] if links[:east]
        all_route_nodes << [cx, cy - 1] if links[:north]
        all_route_nodes << [cx, cy + 1] if links[:south]
      end

      all_route_nodes.uniq.each { |node| @route_chunks[node] = true }

      @route_chunks.keys.each do |cx, cy|
        connect_orthogonal_chunks([cx, cy], [cx - 1, cy]) if @route_chunks[[cx - 1, cy]]
        connect_orthogonal_chunks([cx, cy], [cx + 1, cy]) if @route_chunks[[cx + 1, cy]]
        connect_orthogonal_chunks([cx, cy], [cx, cy - 1]) if @route_chunks[[cx, cy - 1]]
        connect_orthogonal_chunks([cx, cy], [cx, cy + 1]) if @route_chunks[[cx, cy + 1]]
      end
    end

    def longest_connection
      @connections.max_by do |a_id, b_id|
        a = @anchors[a_id]
        b = @anchors[b_id]
        (a[:x] - b[:x]).abs + (a[:y] - b[:y]).abs
      end
    end

    def register_route(points)
      compact_points = points.compact
      compact_points.each do |cx, cy|
        @route_chunks[[cx, cy]] = true
      end

      compact_points.each_cons(2) do |from, to|
        connect_route_chunks(from, to)
      end
    end

    def connect_route_chunks(from, to)
      return if from.nil? || to.nil?

      fx, fy = from
      tx, ty = to
      dx = tx - fx
      dy = ty - fy
      manhattan = dx.abs + dy.abs

      if manhattan == 1
        connect_orthogonal_chunks(from, to)
      elsif dx.abs == 1 && dy.abs == 1
        pivot = diagonal_pivot(from, to)
        @route_chunks[pivot] = true
        connect_orthogonal_chunks(from, pivot)
        connect_orthogonal_chunks(pivot, to)
      end
    end

    def diagonal_pivot(from, to)
      fx, fy = from
      tx, ty = to

      hash = ((fx * 92821) ^ (fy * 68917) ^ (tx * 1237) ^ (ty * 3253) ^ ProcWild.world_seed)
      if (hash & 1) == 0
        [tx, fy]
      else
        [fx, ty]
      end
    end

    def connect_orthogonal_chunks(from, to)
      fx, fy = from
      tx, ty = to
      dx = tx - fx
      dy = ty - fy
      return if dx.abs + dy.abs != 1

      if dx == 1
        @route_links[[fx, fy]][:east] = true
        @route_links[[tx, ty]][:west] = true
      elsif dx == -1
        @route_links[[fx, fy]][:west] = true
        @route_links[[tx, ty]][:east] = true
      elsif dy == 1
        @route_links[[fx, fy]][:south] = true
        @route_links[[tx, ty]][:north] = true
      elsif dy == -1
        @route_links[[fx, fy]][:north] = true
        @route_links[[tx, ty]][:south] = true
      end
    end

    def biome_at(cx, cy)
      key = [cx, cy]
      return @biome_cache[key] if @biome_cache[key]

      sample_offsets = [4, ProcWild::CHUNK_SIZE / 2, ProcWild::CHUNK_SIZE - 5]
      counts = Hash.new(0)

      sample_offsets.each do |local_x|
        sample_offsets.each do |local_y|
          world_x, world_y = world_coords(cx, cy, local_x, local_y)
          counts[ProcWild.biome_for_world_tile(world_x, world_y)] += 1
        end
      end

      biome = counts.max_by { |biome_name, count| [count, biome_name.to_s] }[0]
      @biome_cache[key] = biome
      return biome
    end

    def chunk_at_tile(tx, ty)

      cx = tx / ProcWild::CHUNK_SIZE
      cy = ty / ProcWild::CHUNK_SIZE

      return [cx, cy]

    end

    def ensure_chunks(cx, cy, radius)

      (-radius..radius).each do |dx|
        (-radius..radius).each do |dy|
          get_chunk(cx + dx, cy + dy)
        end
      end
    end

    def update_player_area(player_x, player_y)

      cx = player_x / ProcWild::CHUNK_SIZE
      cy = player_y / ProcWild::CHUNK_SIZE

      ensure_chunks(cx, cy, 2)

    end

    def route_between(a, b)
      x0, y0 =
        if a.is_a?(Array)
          a
        else
          [a[:x], a[:y]]
        end

      x1, y1 =
        if b.is_a?(Array)
          b
        else
          [b[:x], b[:y]]
        end

      points = []

      dx = (x1 - x0).abs
      dy = (y1 - y0).abs
      sx = x0 < x1 ? 1 : -1
      sy = y0 < y1 ? 1 : -1
      err = dx - dy

      loop do
        points << [x0, y0]
        break if x0 == x1 && y0 == y1

        e2 = 2 * err
        if e2 > -dy
          err -= dy
          x0 += sx
        end
        if e2 < dx
          err += dx
          y0 += sy
        end
      end

      return points
    end

    def add_loops_to_route(points, rng)
      echoln "Adding loops to route from #{points.first} to #{points.last}"
      return [] if points.length < 4

      spine_lookup = {}
      points.each { |p| spine_lookup[p] = true }
      min_x = points.map { |p| p[0] }.min
      max_x = points.map { |p| p[0] }.max
      min_y = points.map { |p| p[1] }.min
      max_y = points.map { |p| p[1] }.max
      min_bound_x = min_x - 1
      max_bound_x = [min_x + 1, max_x].max
      min_bound_y = min_y - 1
      max_bound_y = max_y + 1

      10.times do
        max_start_index = [points.length - 3, 1].min
        start_index = rng.rand(0..max_start_index)
        end_index = start_index + rng.rand(1..2)
        end_index = [end_index, points.length - 1].min
        next if end_index <= start_index

        start = points[start_index]
        finish = points[end_index]

        dx = finish[0] - start[0]
        dy = finish[1] - start[1]

        perp = if dx.abs >= dy.abs
          [0, 1]
        else
          [1, 0]
        end

        sign = rng.rand < 0.5 ? -1 : 1
        distance = 1

        detour_start = [
          start[0] + perp[0] * distance * sign,
          start[1] + perp[1] * distance * sign
        ]

        detour_end = [
          finish[0] + perp[0] * distance * sign,
          finish[1] + perp[1] * distance * sign
        ]

        next if detour_start[0] < min_bound_x || detour_start[0] > max_bound_x
        next if detour_start[1] < min_bound_y || detour_start[1] > max_bound_y
        next if detour_end[0] < min_bound_x || detour_end[0] > max_bound_x
        next if detour_end[1] < min_bound_y || detour_end[1] > max_bound_y

        loop_path = []
        loop_path += route_between(start, detour_start)
        loop_path += route_between(detour_start, detour_end)
        loop_path += route_between(detour_end, finish)

        novel_tiles = loop_path.uniq.count { |p| !spine_lookup[p] }
        next if novel_tiles < 2

        spine_intersections = loop_path.uniq.select { |p| spine_lookup[p] }
        next if spine_intersections.any? { |p| p != start && p != finish }

        return loop_path
      end

      return []
    end

  end
end