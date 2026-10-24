module ProcWild
class Chunk

def world_coords(local_x, local_y)
	[
		@cx * ProcWild::CHUNK_SIZE + local_x,
		@cy * ProcWild::CHUNK_SIZE + local_y
	]
end

def local_coords(world_x, world_y)
	[
		world_x - (@cx * ProcWild::CHUNK_SIZE),
		world_y - (@cy * ProcWild::CHUNK_SIZE)
	]
end

def clamp_to_chunk_interior(x, y, margin=2)
	min = margin
	max = ProcWild::CHUNK_SIZE - 1 - margin
	cx = [[x, min].max, max].min
	cy = [[y, min].max, max].min
	[cx, cy]
end

def terrain_cost(tile,x,y,from=nil)
	world_x, world_y = world_coords(x, y)

	cost =
		case tile
		when TERRAIN_WATER then 999
		when TERRAIN_FOREST then 3
		when TERRAIN_GRASS then 1
		else 2
		end

	cost += ProcWild.road_biome_cost(world_x, world_y)

	# discourage zig-zagging
	if from
		fx,fy = from
		dx = (x - fx).abs
		dy = (y - fy).abs
		cost += 0.2 if dx == 1 && dy == 1
	end

	return cost

end

def smooth_path

	new_path = Marshal.load(Marshal.dump(@path))
	openings = connection_points
	protected = {}

	# Keep a short interior lead from each chunk-edge opening so transitions
	# between chunks don't get clipped by dead-end cleanup.
	openings.each do |ox, oy|
		(-1..1).each do |dx|
			(-1..1).each do |dy|
				px = ox + dx
				py = oy + dy
				next if px < 0 || py < 0
				next if px >= ProcWild::CHUNK_SIZE || py >= ProcWild::CHUNK_SIZE
				protected[[px, py]] = true
			end
		end
	end

	ProcWild::CHUNK_SIZE.times do |x|
		ProcWild::CHUNK_SIZE.times do |y|

			next unless @path[x][y]

			neighbors = 0

			(-1..1).each do |dx|
				(-1..1).each do |dy|

					nx = x + dx
					ny = y + dy

					next if nx < 0 || ny < 0
					next if nx >= ProcWild::CHUNK_SIZE
					next if ny >= ProcWild::CHUNK_SIZE

					neighbors += 1 if @path[nx][ny]

				end
			end

			# Only remove isolated specks. One-neighbor tiles are often valid road
			# segments in narrow connectors and should be preserved.
			if neighbors == 0 && !protected[[x, y]]
				new_path[x][y] = false
			end

		end
	end

	@path = new_path

end

def build_road_mask
	size = ProcWild::CHUNK_SIZE
	mask = Array.new(size) { Array.new(size, false) }

	size.times do |x|
		size.times do |y|
			next unless @path[x][y]
			mask[x][y] = true
		end
	end

	size.times do |x|
		size.times do |y|
			next unless @path[x][y]

			left  = (x > 0) && @path[x - 1][y]
			right = (x < size - 1) && @path[x + 1][y]
			up    = (y > 0) && @path[x][y - 1]
			down  = (y < size - 1) && @path[x][y + 1]

			horizontal_straight = left && right && !up && !down
			vertical_straight = up && down && !left && !right

			if horizontal_straight
				[[x, y - 1], [x, y + 1]].each do |nx, ny|
					next if nx < 0 || ny < 0
					next if nx >= size || ny >= size
					next if @terrain[nx][ny] == TERRAIN_WATER
					mask[nx][ny] = true
				end
			elsif vertical_straight
				[[x - 1, y], [x + 1, y]].each do |nx, ny|
					next if nx < 0 || ny < 0
					next if nx >= size || ny >= size
					next if @terrain[nx][ny] == TERRAIN_WATER
					mask[nx][ny] = true
				end
			end
		end
	end

	@roadMask = mask
end

def connection_points
	[@path_start, @path_end, @north_entry, @south_entry, @west_entry, @east_exit, @north_exit, @south_exit].compact.uniq
end

def near_path?(x,y,radius=3)

	search_neighbors(x, y, radius) do |nx, ny|
		@path[nx][ny]
	end
end

 def generate_path(rng)

	openings = connection_points
	if openings.empty?
		generate_center_loop(rng)
		return
	end

	hub = path_hub_for(openings)

	# Always stamp route openings so they stay visible even if pathfinding fails.
	(openings + [hub]).compact.uniq.each do |x, y|
		next if x < 0 || y < 0
		next if x >= ProcWild::CHUNK_SIZE || y >= ProcWild::CHUNK_SIZE
		@path[x][y] = true
		@terrain[x][y] = ProcWild::TERRAIN_GRASS
	end

	reinforce_opening_connectors(openings, hub)

	openings.each do |opening|
		next if opening == hub

		echoln "opening #{opening.inspect} hub #{hub.inspect}"
		generate_single_path(opening, hub)
	end

		generate_local_side_route(rng, openings, hub)
		bridge_disconnected_path_components(hub)
		enforce_strict_route_connectivity(hub) if ProcWild::STRICT_ROUTE_CONNECTIVITY
		smooth_path()

end

def enforce_strict_route_connectivity(hub)
	iterations = 0
	max_iterations = 32

	while iterations < max_iterations
		components = path_components
		return if components.length <= 1

		base_index = components.each_with_index.min_by { |comp, _i| min_distance_to_point(comp, hub) }[1]
		break if base_index.nil?
		connected = components.delete_at(base_index)

		next_index, a_point, b_point = nearest_component_bridge(connected, components)
		break if next_index.nil? || a_point.nil? || b_point.nil?

		carved = carve_segment(a_point, b_point)
		carved = carve_segment(a_point, b_point, true) if !carved
		break if !carved

		iterations += 1
	end

	prune_disconnected_road_islands(hub)
end

def prune_disconnected_road_islands(hub)
	components = path_components
	return if components.length <= 1

	main_index = components.each_with_index.min_by { |comp, _i| min_distance_to_point(comp, hub) }[1]
	return if main_index.nil?

	components.each_with_index do |component, idx|
		next if idx == main_index
		component.each do |x, y|
			@path[x][y] = false
		end
	end
end

def bridge_disconnected_path_components(hub)
	components = path_components
	return if components.length <= 1

	# Start from the component closest to the hub, then connect all others.
	base_index = components.each_with_index.min_by { |comp, _i| min_distance_to_point(comp, hub) }[1]
	connected = components.delete_at(base_index)

	while !components.empty?
		next_index, a_point, b_point = nearest_component_bridge(connected, components)
		break if next_index.nil? || a_point.nil? || b_point.nil?

		carved = carve_segment(a_point, b_point)
		# Last-resort fallback: if strict carving fails, allow crossing water so
		# road components do not remain permanently disconnected.
		if !carved
			carved = carve_segment(a_point, b_point, true)
		end

		if carved
			connected.concat(components.delete_at(next_index))
		else
			# Couldn't connect this component; stop rather than falsely marking it connected.
			break
		end
	end
end

def path_components
	visited = {}
	components = []

	ProcWild::CHUNK_SIZE.times do |x|
		ProcWild::CHUNK_SIZE.times do |y|
			next unless @path[x][y]
			key = [x, y]
			next if visited[key]

			queue = [key]
			visited[key] = true
			component = []

			while !queue.empty?
				cx, cy = queue.shift
				component << [cx, cy]

				[[1,0],[-1,0],[0,1],[0,-1]].each do |dx, dy|
					nx = cx + dx
					ny = cy + dy
					next if nx < 0 || ny < 0
					next if nx >= ProcWild::CHUNK_SIZE || ny >= ProcWild::CHUNK_SIZE
					next unless @path[nx][ny]

					nkey = [nx, ny]
					next if visited[nkey]
					visited[nkey] = true
					queue << nkey
				end
			end

			components << component
		end
	end

	components
end

def min_distance_to_point(component, point)
	px, py = point
	component.map { |x, y| (x - px).abs + (y - py).abs }.min || 9999
end

def nearest_component_bridge(base_component, remaining_components)
	best = nil

	remaining_components.each_with_index do |component, idx|
		base_component.each do |ax, ay|
			component.each do |bx, by|
				dist = (ax - bx).abs + (ay - by).abs
				if best.nil? || dist < best[0]
					best = [dist, idx, [ax, ay], [bx, by]]
				end
			end
		end
	end

	return [nil, nil, nil] if best.nil?
	return [best[1], best[2], best[3]]
end

def reinforce_opening_connectors(openings, hub)
	hx, hy = hub

	openings.each do |ox, oy|
		inward = [ox, oy]

		if ox == 0
			inward = [2, oy]
		elsif ox == ProcWild::CHUNK_SIZE - 1
			inward = [ProcWild::CHUNK_SIZE - 3, oy]
		elsif oy == 0
			inward = [ox, 2]
		elsif oy == ProcWild::CHUNK_SIZE - 1
			inward = [ox, ProcWild::CHUNK_SIZE - 3]
		end

		# Bridge any tiny seam gaps by forcing a short inward corridor.
		carve_segment([ox, oy], inward)

		# Also nudge the stub toward the local hub for continuity.
		step_x = inward[0] + (hx < inward[0] ? -2 : (hx > inward[0] ? 2 : 0))
		step_y = inward[1] + (hy < inward[1] ? -2 : (hy > inward[1] ? 2 : 0))
		step_x = [[step_x, 1].max, ProcWild::CHUNK_SIZE - 2].min
		step_y = [[step_y, 1].max, ProcWild::CHUNK_SIZE - 2].min
		carve_segment(inward, [step_x, step_y])
	end
end

def generate_center_loop(rng)
	center_x = ProcWild::CHUNK_SIZE / 2
	center_y = ProcWild::CHUNK_SIZE / 2
	half_w = rng.rand(5..8)
	half_h = rng.rand(4..7)

	left = [center_x - half_w, 3].max
	right = [center_x + half_w, ProcWild::CHUNK_SIZE - 4].min
	top = [center_y - half_h, 3].max
	bottom = [center_y + half_h, ProcWild::CHUNK_SIZE - 4].min

	return if right - left < 4 || bottom - top < 4

	loop_points = [
		[left, top],
		[right, top],
		[right, bottom],
		[left, bottom],
		[left, top]
	]

	carve_polyline(loop_points)

	# Connect the fallback loop toward the world's main area (origin-facing edge)
	# so this road feature doesn't remain isolated.
	gate = [center_x, top]
	carve_segment([center_x, center_y], gate)

	edge_target = origin_facing_edge_point(center_x, center_y)
	carve_segment([center_x, center_y], edge_target) if edge_target

	smooth_path()
end

def origin_facing_edge_point(center_x, center_y)
	last = ProcWild::CHUNK_SIZE - 1
	wx, wy = world_coords(center_x, center_y)

	if wx.abs >= wy.abs
		return (wx > 0) ? [0, center_y] : [last, center_y]
	end

	return (wy > 0) ? [center_x, 0] : [center_x, last]
end

def path_hub_for(openings)
	return [ProcWild::CHUNK_SIZE / 2, ProcWild::CHUNK_SIZE / 2] if openings.nil? || openings.empty?

	world_points = openings.map { |x, y| world_coords(x, y) }
	sum_wx = world_points.inject(0) { |acc, p| acc + p[0] }
	sum_wy = world_points.inject(0) { |acc, p| acc + p[1] }
	avg_wx = (sum_wx.to_f / world_points.length).round
	avg_wy = (sum_wy.to_f / world_points.length).round

	lx, ly = local_coords(avg_wx, avg_wy)
	clamp_to_chunk_interior(lx, ly)
end

def generate_local_side_route(rng, openings, hub)
	return if openings.empty?

	return if generate_local_loop(rng, openings, hub)
	generate_local_spur(rng, openings, hub)
end

def generate_local_loop(rng, openings, hub)
	return false if openings.length < 2

	horizontal = openings.select { |point| point[1] == hub[1] }
	vertical = openings.select { |point| point[0] == hub[0] }

	loop_points = nil
	if horizontal.length >= 2
		loop_points = horizontal_loop_points(rng, hub)
	elsif vertical.length >= 2
		loop_points = vertical_loop_points(rng, hub)
	end

	return false if loop_points.nil? || loop_points.length < 4

	carve_polyline(loop_points)
	smooth_path()
	return true
end

def generate_local_spur(rng, openings, hub)
	center_x, center_y = hub

	horizontal = openings.select { |point| point[1] == center_y }
	vertical = openings.select { |point| point[0] == center_x }

	if horizontal.length >= vertical.length
		sign = choose_spur_sign(rng, center_y, @north_entry || @north_exit, @south_entry || @south_exit)
		length = choose_spur_length(center_y, sign)
		return if length <= 0
		target = [center_x, center_y + sign * length]
	else
		sign = choose_spur_sign(rng, center_x, @west_entry, @east_exit)
		length = choose_spur_length(center_x, sign)
		return if length <= 0
		target = [center_x + sign * length, center_y]
	end

	carve_segment(hub, target)
end

def choose_spur_sign(rng, center, negative_blocker, positive_blocker)
	negative_space = center - 3
	positive_space = (ProcWild::CHUNK_SIZE - 4) - center

	if negative_blocker && !positive_blocker
		return 1
	elsif positive_blocker && !negative_blocker
		return -1
	elsif positive_space > negative_space
		return 1
	elsif negative_space > positive_space
		return -1
	end

	return rng.rand < 0.5 ? -1 : 1
end

def choose_spur_length(center, sign)
	available = if sign < 0
		center - 3
	else
		(ProcWild::CHUNK_SIZE - 4) - center
	end

	return 0 if available <= 0
	return [available, 8].min
end

def horizontal_loop_points(rng, hub)
	center_x, center_y = hub
	span = rng.rand(5..7)
	start_x = [center_x - span, 5].max
	end_x = [center_x + span, ProcWild::CHUNK_SIZE - 6].min
	return nil if end_x - start_x < 6

	offset = choose_loop_offset(rng, center_y, @north_entry || @north_exit, @south_entry || @south_exit)
	return nil if offset.nil?

	loop_y = center_y + offset
	return nil if loop_y < 4 || loop_y > ProcWild::CHUNK_SIZE - 5

	return [
		[start_x, center_y],
		[start_x, loop_y],
		[end_x, loop_y],
		[end_x, center_y]
	]
end

def vertical_loop_points(rng, hub)
	center_x, center_y = hub
	span = rng.rand(5..7)
	start_y = [center_y - span, 5].max
	end_y = [center_y + span, ProcWild::CHUNK_SIZE - 6].min
	return nil if end_y - start_y < 6

	offset = choose_loop_offset(rng, center_x, @west_entry, @east_exit)
	return nil if offset.nil?

	loop_x = center_x + offset
	return nil if loop_x < 4 || loop_x > ProcWild::CHUNK_SIZE - 5

	return [
		[center_x, start_y],
		[loop_x, start_y],
		[loop_x, end_y],
		[center_x, end_y]
	]
end

def choose_loop_offset(rng, center, negative_blocker, positive_blocker)
	negative_space = center - 4
	positive_space = (ProcWild::CHUNK_SIZE - 5) - center
	return nil if negative_space < 4 && positive_space < 4

	if negative_blocker && !positive_blocker
		sign = 1
	elsif positive_blocker && !negative_blocker
		sign = -1
	elsif positive_space > negative_space
		sign = 1
	elsif negative_space > positive_space
		sign = -1
	else
		sign = rng.rand < 0.5 ? -1 : 1
	end

	available_space = (sign < 0) ? negative_space : positive_space
	min_gap = [6, available_space].min
	max_gap = [8, available_space].min
	return nil if max_gap < 4

	magnitude = if min_gap <= max_gap
		rng.rand(min_gap..max_gap)
	else
		rng.rand(4..max_gap)
	end
	return sign * magnitude
end

def carve_polyline(points)
	points.each_cons(2) do |from, to|
		carve_segment(from, to)
	end
end

def carve_segment(from, to, allow_water=false)
    mid = switchback_midpoint(from, to)

    path1 = a_star_path(from, mid, allow_water)
    path2 = a_star_path(mid, to, allow_water)

    path = (path1 || []) + (path2 || [])
	return false if path.nil? || path.empty?

	path.each do |x, y|
		stamp_path_tile(x, y)
	end

	return true
end

def a_star_path(start, goal, allow_water=false)
	return nil if start.nil? || goal.nil?

	sx, sy = start
	gx, gy = goal
	return nil if sx < 0 || sy < 0 || gx < 0 || gy < 0
	return nil if sx >= ProcWild::CHUNK_SIZE || sy >= ProcWild::CHUNK_SIZE
	return nil if gx >= ProcWild::CHUNK_SIZE || gy >= ProcWild::CHUNK_SIZE

	open = [start]
	came_from = {}
	g_cost = { start => 0 }

	until open.empty?
		current = open.min_by { |node| g_cost[node] + heuristic(node, goal) }
		return nil if current.nil?
		return reconstruct_path(came_from, current) if current == goal

		open.delete(current)
		cx, cy = current

		[[1,0],[-1,0],[0,1],[0,-1]].each do |dx, dy|
			nx = cx + dx
			ny = cy + dy
			next if nx < 0 || ny < 0
			next if nx >= ProcWild::CHUNK_SIZE || ny >= ProcWild::CHUNK_SIZE

			tile = @terrain[nx][ny]
			next if tile.nil?
			next if tile == TERRAIN_WATER && !allow_water

			tentative = g_cost[current] + terrain_cost(tile, nx, ny, current)
			neighbor = [nx, ny]

			if !g_cost.key?(neighbor) || tentative < g_cost[neighbor]
				g_cost[neighbor] = tentative
				came_from[neighbor] = current
				open << neighbor unless open.include?(neighbor)
			end
		end
	end

	return nil
end

def reconstruct_path(came_from, current)
	path = [current]
	while came_from[current]
		current = came_from[current]
		path << current
	end
	return path.reverse
end

def stamp_path_tile(x, y)
	return if x < 0 || y < 0
	return if x >= ProcWild::CHUNK_SIZE || y >= ProcWild::CHUNK_SIZE

	@path[x][y] = true
	@terrain[x][y] = ProcWild::TERRAIN_GRASS
end

def carve_line(a,b)

	x,y = a
	tx,ty = b

	while x != tx
		@path[x][y] = true
		x += (tx > x ? 1 : -1)
	end

	while y != ty
		@path[x][y] = true
		y += (ty > y ? 1 : -1)
	end

	@terrain[x][y] = ProcWild::TERRAIN_GRASS
	@path[x][y] = true

end

def heuristic(a,b)
	return 0 if a.nil? || b.nil?
	ax,ay = a
	bx,by = b
	return (ax-bx).abs + (ay-by).abs
end

def generate_single_path(start, goal)
	open = [start]
	came_from = {}
	cost = { start => 0 }

	reached = false

	while !open.empty?

		open.compact!
		return if open.empty?

		current = open.min_by { |node| cost[node] + heuristic(node, goal) }
		if current == goal
			reached = true
			break
		end

		if open.any? { |n| n.nil? }
			echoln "NIL IN OPEN: #{open.inspect}"
		end

		return if current.nil?

		open.delete(current)

		x,y = current
		next if x.nil? || y.nil?
		next if x < 0 || y < 0

		neighbors = [
			[x+1,y],
			[x-1,y],
			[x,y+1],
			[x,y-1]
		].shuffle(random: @rng)

		neighbors.each do |nx,ny|

			next if nx.nil? || ny.nil?
			next if nx < 0 || ny < 0
			next if nx >= ProcWild::CHUNK_SIZE
			next if ny >= ProcWild::CHUNK_SIZE

			terrain = @terrain[nx][ny]
			next if terrain.nil?

			next if terrain == TERRAIN_WATER

			new_cost = cost[current] + terrain_cost(terrain,nx,ny, current)

			if !cost.key?([nx,ny]) || new_cost < cost[[nx,ny]]
				cost[[nx,ny]] = new_cost
				came_from[[nx,ny]] = current
				open << [nx,ny]
			end

		end

	end

	if reached
		carve_path(goal, came_from)
	else
		# Fallback still respects terrain (water blocked by default).
		carve_segment(start, goal)
	end
	smooth_path()

end

def carve_path(node, came_from)

	while came_from[node]

		x,y = node
		@terrain[x][y] = ProcWild::TERRAIN_GRASS
		@path[x][y] = true

		node = came_from[node]
	end
end

def smooth_road_heights
  size = ProcWild::CHUNK_SIZE
 # Deep copy so we don't modify while iterating
  new_height = Marshal.load(Marshal.dump(@height))

  size.times do |x|
    size.times do |y|
      next unless @path[x][y]

      center = @height[x][y]

      # --- Horizontal check ---
      if x > 0 && x < size - 1
        next unless @path[x - 1][y] && @path[x + 1][y]

        left  = @height[x - 1][y]
        right = @height[x + 1][y]

        if left == right && left != center
          new_height[x][y] = left
          next
        end
      end

      # --- Vertical check ---
      if y > 0 && y < size - 1
        next unless @path[x][y - 1] && @path[x][y + 1]

        up   = @height[x][y - 1]
        down = @height[x][y + 1]

        if up == down && up != center
          new_height[x][y] = up
        end
      end
    end
  end

  @height = new_height

end

end
end
