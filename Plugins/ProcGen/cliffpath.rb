
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
                      rng, blocked, noise_at, write_marker)

      width  = max_x - min_x + 1
      height = max_y - min_y + 1
      min_path_length = ProcWild::CHUNK_SIZE * 2

      directions = DIRECTIONS
      opposite = OPPOSITE

      on_edge = lambda do |x, y|
        x == min_x || x == max_x ||
          y == min_y || y == max_y
      end

      starts = []

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

          starts << [x, y] if has_neighbor
        end
      end

      if starts.empty?
        echoln "CLIFF PATH: no valid starting tiles"
        return []
      end

      start = starts[rng.rand(starts.length)]
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
        if path.length >= min_path_length &&
           on_edge.call(current_x, current_y)
          reached_edge = true
          break
        end

        candidates = []

        directions.each do |dir, dx, dy|
          nx = current_x + dx
          ny = current_y + dy

          next if nx < min_x || nx > max_x
          next if ny < min_y || ny > max_y

          point = [nx, ny]

          if point == start
            if path.length >= 8
              candidates << {
                :x => nx, :y => ny, :dir => dir,
                :closes_loop => true, :weight => 0.8
              }
            end
            next
          end

          next if blocked.call(nx, ny)
          next if visited[point]

          candidates << {
            :x => nx, :y => ny, :dir => dir,
            :closes_loop => false,
            :noise => noise_at.call(nx, ny)
          }
        end

        break if candidates.empty?

        ordinary = candidates.reject do |candidate|
          candidate[:closes_loop]
        end

        unless ordinary.empty?
          min_noise = ordinary.map { |c| c[:noise] }.min

          ordinary.each do |candidate|
            dir = candidate[:dir]
            nx = candidate[:x]
            ny = candidate[:y]

            weight = 1.0 + candidate[:noise] - min_noise
            
            # Stronger directional momentum.
            unless direction_history.empty?
            same_count = direction_history.count { |d| d == dir }
            reverse_count = direction_history.count do |d|
                d == opposite[dir]
            end

            net_bias = (same_count - reverse_count).to_f /
                        direction_history.length

            weight *= (1.0 + 1.5 * net_bias)
            end

            # Strongly favor continuing straight to produce longer runs.
            if last_direction == dir
            weight *= 2.2
            elsif last_direction && opposite[last_direction] == dir
            weight *= (run_length < 4 ? 0.15 : 0.45)
            end

            # Avoid touching older sections of the path.
            too_close = false
            path[0, [path.length - 2, 0].max].each do |px, py|
              if (px - nx).abs + (py - ny).abs <= 1
                too_close = true
                break
              end
            end

            candidate[:weight] = [weight, 0.02].max unless too_close
          end
        end

        total = candidates.inject(0.0) do |sum, c|
          sum + (c[:weight] || 0.0)
        end

        break if total <= 0.0

        roll = rng.rand * total
        chosen = nil

        candidates.each do |candidate|
          roll -= (candidate[:weight] || 0.0)
          if roll < 0
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
        direction_history.shift while
          direction_history.length > max_history
      end

      reached_edge = on_edge.call(current_x, current_y)


  # If the path stalls before reaching the global boundary,
  # extend it in a straight horizontal or vertical line.
  edge_extended = false

  unless closed_loop || reached_edge
    straight_extensions = []

    directions.each do |dir, dx, dy|
      extension = []
      x = current_x
      y = current_y
      valid = true

      loop do
        x += dx
        y += dy
        point = [x, y]

        # Stop if this direction leaves the generated area.
        if x < min_x || x > max_x ||
           y < min_y || y > max_y
          valid = false
          break
        end

        # A straight extension must not cross water or
        # double back through the existing path.
        if blocked.call(x, y) || visited[point]
          valid = false
          break
        end

        extension << point

        if on_edge.call(x, y)
          break
        end
      end

      next unless valid
      next if extension.empty?

      straight_extensions << {
        :dir => dir,
        :tiles => extension,
        :distance => extension.length,
        :continues_direction => (dir == last_direction)
      }
    end

    unless straight_extensions.empty?
      # Prefer continuing the current direction. If that is
      # impossible, use the shortest clear straight route.
      continuing = straight_extensions.select do |candidate|
        candidate[:continues_direction]
      end

      choices = continuing.empty? ?
        straight_extensions : continuing

      chosen_extension = choices.min do |a, b|
        a[:distance] <=> b[:distance]
      end

      chosen_extension[:tiles].each do |x, y|
        path << [x, y]
        visited[[x, y]] = true
      end

      current_x, current_y = path[-1]
      reached_edge = on_edge.call(current_x, current_y)
      edge_extended = true
    end
  end

      # Derive connections from the path sequence.
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

        if connections.include?(:north) &&
           connections.include?(:south)
          connections = [:north]
        elsif connections.include?(:east) &&
              connections.include?(:west)
          connections = [:east]
        end

        write_marker.call(x, y, connections)
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
