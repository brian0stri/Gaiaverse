
module ProcWild
  module CliffPathBuilder
    DIRECTIONS = [
      [:north,  0, -1],
      [:south,  0,  1],
      [:west,  -1, 0],
      [:east,   1,  0]
    ]

    OPPOSITE = {
      :north => :south,
      :south => :north,
      :west  => :east,
      :east  => :west
    }

    def self.generate(min_x, max_x, min_y, max_y,
                      rng, blocked, noise_at, write_marker,
                      near_existing_cliff = nil,
                      same_lane_overlap = nil)
      width  = max_x - min_x + 1
      height = max_y - min_y + 1

      directions = DIRECTIONS
      opposite = OPPOSITE

      on_edge = lambda do |x, y|
        x == min_x || x == max_x ||
          y == min_y || y == max_y
      end

      dir_for_delta = lambda do |dx, dy|
        return :east  if dx == 1
        return :west  if dx == -1
        return :south if dy == 1
        return :north if dy == -1
        nil
      end

      same_lane_conflict = lambda do |x, y, dir, history = []|
        return false if dir.nil?
        history.any? do |px, py|
          next false if px == x && py == y
          case dir
          when :east, :west
            py == y && (px - x).abs <= 6
          when :north, :south
            px == x && (py - y).abs <= 6
          else
            false
          end
        end
      end

      # Weight the start positions toward higher heightmap values and the local noise
      # field, rather than the lower elevations. This gives the cliff seed a more
      # natural terrain-driven origin without forcing a straight run.
      start_candidates = []
      min_x.upto(max_x) do |x|
        min_y.upto(max_y) do |y|
          next if blocked.call(x, y)

          has_neighbor = directions.any? do |_dir, dx, dy|
            nx = x + dx
            ny = y + dy
            nx >= min_x && nx <= max_x &&
              ny >= min_y && ny <= max_y &&
              !blocked.call(nx, ny)
          end
          next unless has_neighbor

          hill = noise_at.call(x, y).to_f
          score = hill + (rng.rand * 0.5) + 0.25
          start_candidates << { :x => x, :y => y, :score => score }
        end
      end

      if start_candidates.empty?
        echoln "CLIFF PATH: no valid starting tiles"
        return []
      end

      total_seed_score = start_candidates.inject(0.0) { |sum, c| sum + c[:score] }
      seed_roll = rng.rand * total_seed_score
      start = nil
      running = 0.0
      start_candidates.each do |candidate|
        running += candidate[:score]
        if seed_roll <= running
          start = [candidate[:x], candidate[:y]]
          break
        end
      end
      start ||= start_candidates.first
      start_x, start_y = start

      path = [start]
      visited = { start => true }
      current_x, current_y = start
      closed_loop = false
      reached_edge = on_edge.call(current_x, current_y)
      edge_extended = false

      direction_history = []
      last_direction = nil
      run_length = 0
      max_history = 16
      max_steps = width * height * 2

      max_steps.times do
        if path.length >= [width, height].max * 2 && on_edge.call(current_x, current_y)
          reached_edge = true
          break
        end

        previous_dir = nil
        if path.length > 1
          px, py = path[-2]
          previous_dir = dir_for_delta.call(current_x - px, current_y - py)
        end

        candidates = []
        directions.each do |dir, dx, dy|
          nx = current_x + dx
          ny = current_y + dy

          next if nx < min_x || nx > max_x
          next if ny < min_y || ny > max_y

          point = [nx, ny]
          if point == start && path.length >= 8
            candidates << { :x => nx, :y => ny, :dir => dir, :closes_loop => true }
            next
          end

          next if blocked.call(nx, ny)
          next if visited[point]

          if previous_dir && dir == opposite[previous_dir]
            next
          end

          if same_lane_overlap && same_lane_overlap.call(nx, ny, dir)
            next
          end

          if same_lane_conflict.call(nx, ny, dir, path)
            next
          end

          # Parallel band rejection: a second cliff string tracking just behind the
          # main wall is disallowed, but the generator may still curve naturally.
          parallel_overlap = false
          path.each do |px, py|
            next if px == current_x && py == current_y
            if dir == :east || dir == :west
              if py == ny && (px - nx).abs <= 6
                parallel_overlap = true
                break
              end
            elsif dir == :north || dir == :south
              if px == nx && (py - ny).abs <= 6
                parallel_overlap = true
                break
              end
            end
          end
          next if parallel_overlap

          local_height = noise_at.call(nx, ny).to_f
          weight = 1.0 + local_height * 0.12

          if last_direction == dir
            weight *= 1.6
          elsif last_direction && opposite[last_direction] == dir
            weight *= 0.45
          end

          if previous_dir && dir != previous_dir && dir != opposite[previous_dir]
            weight *= 1.0 + [local_height * 0.05, 0.0].max
          end

          unless direction_history.empty?
            same_count = direction_history.count { |d| d == dir }
            reverse_count = direction_history.count { |d| d == opposite[dir] }
            net_bias = (same_count - reverse_count).to_f / direction_history.length
            weight *= (1.0 + 1.25 * net_bias)
          end

          # Orthogonal turn selection is driven by local noise and the current path
          # momentum. We exclude the incoming direction itself from the candidate set,
          # but still allow gentle bends when the noise rewards them.
          if previous_dir && dir != previous_dir && dir != opposite[previous_dir]
            weight *= (1.0 + ((local_height + 1.0) * 0.15))
          end

          candidate = {
            :x => nx,
            :y => ny,
            :dir => dir,
            :closes_loop => false,
            :noise => local_height,
            :weight => weight
          }

          candidates << candidate
        end

        break if candidates.empty?

        total = candidates.inject(0.0) { |sum, candidate| sum + (candidate[:weight] || 0.0) }
        break if total <= 0.0

        roll = rng.rand * total
        chosen = nil
        candidates.each do |candidate|
          roll -= candidate[:weight].to_f
          if roll <= 0.0
            chosen = candidate
            break
          end
        end
        break unless chosen

        if chosen[:closes_loop]
          closed_loop = true
          break
        end

        current_x = chosen[:x]
        current_y = chosen[:y]
        path << [current_x, current_y]
        visited[[current_x, current_y]] = true

        if last_direction == chosen[:dir]
          run_length += 1
        else
          last_direction = chosen[:dir]
          run_length = 1
        end

        direction_history << chosen[:dir]
        direction_history.shift while direction_history.length > max_history

        if on_edge.call(current_x, current_y)
          reached_edge = true
          break
        end
      end

      # No forced straight-edge extension during the core path build. This is kept
      # intentionally out so the path can meander and curve naturally until it reaches
      # an actual edge or closes into a loop.
      edge_extended = false

      path.each_with_index do |point, i|
        x, y = point
        connections = []

        previous = if i > 0
                     path[i - 1]
                   elsif closed_loop
                     path[-1]
                   end

        following = if i < path.length - 1
                      path[i + 1]
                    elsif closed_loop
                      path[0]
                    end

        [previous, following].compact.each do |other|
          dx = other[0] - x
          dy = other[1] - y
          connections << :east  if dx == 1
          connections << :west  if dx == -1
          connections << :south if dy == 1
          connections << :north if dy == -1
        end

        if connections.include?(:north) && connections.include?(:south)
          connections = [:north]
        elsif connections.include?(:east) && connections.include?(:west)
          connections = [:east]
        end

        incoming_movement = nil
        if previous
          dx = x - previous[0]
          dy = y - previous[1]
          incoming_movement = :east  if dx == 1
          incoming_movement = :west  if dx == -1
          incoming_movement = :south if dy == 1
          incoming_movement = :north if dy == -1
        end

        outgoing_movement = nil
        if following
          dx = following[0] - x
          dy = following[1] - y
          outgoing_movement = :east  if dx == 1
          outgoing_movement = :west  if dx == -1
          outgoing_movement = :south if dy == 1
          outgoing_movement = :north if dy == -1
        end

        default_face_for_movement = {
          :north => :east,
          :east  => :south,
          :south => :west,
          :west  => :north
        }

        westbound_face_for_movement = {
          :north => :west,
          :east  => :north,
          :south => :east,
          :west  => :south
        }

        movement_dir = incoming_movement || outgoing_movement
        face_for_movement = default_face_for_movement
        face_for_movement = westbound_face_for_movement if movement_dir == :west

        incoming_face = face_for_movement[incoming_movement]
        outgoing_face = face_for_movement[outgoing_movement]

        face = outgoing_face || incoming_face
        incoming_face = incoming_face || outgoing_face
        write_marker.call(x, y, connections, face, incoming_face)
      end

      echoln(
        "CLIFF PATH: tiles=#{path.length} " +
        "loop=#{closed_loop} edge=#{reached_edge} " +
        "extended=#{edge_extended} " +
        "start=(#{start_x},#{start_y})"
      )

      path
    end

  end
end
