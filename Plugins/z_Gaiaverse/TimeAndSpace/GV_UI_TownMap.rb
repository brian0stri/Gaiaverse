#===============================================================================
#
#===============================================================================
GV_TOWN_MAP_SKIP_TRANSITIONS = false if !defined?(GV_TOWN_MAP_SKIP_TRANSITIONS)
GV_TOWN_MAP_INITIAL_PAGE = 0 if !defined?(GV_TOWN_MAP_INITIAL_PAGE)

class MapBottomSprite < Sprite
  attr_reader :mapname, :maplocation

    TEXT_MAIN_COLOR   = Color.new(64, 64, 64)
    TEXT_SHADOW_COLOR = Color.new(128, 128, 128)

  def initialize(viewport = nil)
    super(viewport)
    @mapname     = ""
    @maplocation = ""
    @mapdetails  = ""
    self.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(self.bitmap)
    refresh
  end

  def mapname=(value)
    return if @mapname == value
    @mapname = value
    refresh
  end

  def maplocation=(value)
    return if @maplocation == value
    @maplocation = value
    refresh
  end

  # From Wichu
  def mapdetails=(value)
    return if @mapdetails == value
    @mapdetails = value
    refresh
  end

  def refresh
    bitmap.clear
    textpos = [
      [@mapdetails, 36, 360, :right, TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR]
    ]
    pbDrawTextPositions(bitmap, textpos)
  end
end

class PokemonGlobalMetadata
  attr_writer :gv_town_map_intro_seen

  def gv_town_map_intro_seen
    @gv_town_map_intro_seen = {} if !@gv_town_map_intro_seen.is_a?(Hash)
    return @gv_town_map_intro_seen
  end
end

#===============================================================================
#
#===============================================================================
class PokemonRegionMap_Scene

  @@region_asset_cache = {} if !defined?(@@region_asset_cache)
  @@region_intro_seen = {} if !defined?(@@region_intro_seen)

  LEFT          = 0
  TOP           = 0
  RIGHT         = 59
  BOTTOM        = 33
  SQUARE_WIDTH  = 16
  SQUARE_HEIGHT = 16
  TEXT_MAIN_COLOR   = Color.new(64, 64, 64)
  TEXT_SHADOW_COLOR = Color.new(128, 128, 128)
  
  def initialize(region = - 1, wallmap = true)
    @region  = region
    @wallmap = wallmap
    @overlayTiles = []
    @opacity = 0.5
    @tile_cache ||= {}   # stores last drawn color per tile
    @dirty_tiles ||= []  # tiles that need redraw
    @pixel_cache ||= {}  # base pixel color per tile, built once
    @static_light_cache ||= {}  # temp color per location, never changes
    @sun_times_cache ||= {}     # [region, latitude, yday] => solar data; cleared daily
    @effective_hour_cache ||= {} # [region, latitude, tz, yday, hour, min, sec, polar] => state
    @sun_times_cache_day ||= nil
    @location_entries ||= []
    game_time = pbGetTimeNow()
    @universal_time = Time.at(game_time.to_i)
    @location_light_cache ||= {}
    @location_grid ||= {}
    @time_update_delay = 60
    @polar_state ||= {}
    @page_index = (GV_TOWN_MAP_INITIAL_PAGE == 1) ? 1 : 0
    @selected_clock = 0
    @clocks = []
    @clock_x = 0
    @clock_y = 0
    @disable_info_box = false
    @containers = []
    @selected_container = 0
    @last_selected_clock = nil
    @region_map_assets_ready = false
  end

  def town_map_timing_start
    return System.uptime
  end

  def town_map_timing_log(label, started_at)
    elapsed_ms = ((System.uptime - started_at) * 1000.0).round(1)
    echoln "[TownMapTiming] #{label}: #{elapsed_ms}ms"
    return System.uptime
  end

  def skip_town_map_transitions?
    return GV_TOWN_MAP_SKIP_TRANSITIONS
  end

  def region_cache_key
    return [@mapindex, @map ? @map.filename : nil]
  end

  def cached_region_assets
    return @@region_asset_cache[region_cache_key]
  end

  def cache_region_assets
    @@region_asset_cache[region_cache_key] = {
      location_grid: @location_grid,
      location_entries: @location_entries,
      static_light_cache: @static_light_cache,
      overlay_tiles: @overlay_tiles,
      pixel_cache: @pixel_cache
    }
  end

  def apply_cached_region_assets(cache)
    @location_grid = cache[:location_grid] || {}
    @location_entries = cache[:location_entries] || []
    @static_light_cache = cache[:static_light_cache] || {}
    @overlay_tiles = cache[:overlay_tiles] || []
    @pixel_cache = cache[:pixel_cache] || {}
    @tile_cache = {}
  end

  def loading_overlay_needed?
    return true
  end

  def loading_overlay_seen_store
    return $PokemonGlobal.gv_town_map_intro_seen if $PokemonGlobal
    return @@region_intro_seen
  end

  def mark_region_intro_seen
    loading_overlay_seen_store[region_cache_key] = true
  end

  def loading_overlay_full_intro?
    return !loading_overlay_seen_store[region_cache_key]
  end

  def set_loading_overlay_input_lock(locked)
    @loading_input_locked = locked
    return if !@sprites
    return if !@sprites["cursor"]

    @sprites["cursor"].visible = !locked && @page_index == 0
  end

  def play_loading_overlay_bgm
    return if @loading_overlay_bgm_playing

    @loading_overlay_previous_bgm = $game_system.getPlayingBGM if $game_system
    pbBGMPlay("Evolution")
    @loading_overlay_bgm_playing = true
  end

  def stop_loading_overlay_bgm
    return if !@loading_overlay_bgm_playing

    if @loading_overlay_previous_bgm
      pbBGMPlay(@loading_overlay_previous_bgm)
    else
      pbBGMStop
    end
    @loading_overlay_previous_bgm = nil
    @loading_overlay_bgm_playing = false
  end

  def create_loading_overlay
    return if @loading_overlay_viewport && !@loading_overlay_viewport.disposed?

    set_loading_overlay_input_lock(true)
    @loading_overlay_full_intro = loading_overlay_full_intro?
    @loading_phase_index = 0
    @loading_phase_ratio = 0.0
    @loading_text_reveal_started_at = System.uptime
    @loading_overlay_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @loading_overlay_viewport.z = 100001
    @loading_overlay = Sprite.new(@loading_overlay_viewport)
    @loading_overlay.bitmap = Bitmap.new(Graphics.width, Graphics.height)
    pbSetSystemFont(@loading_overlay.bitmap)
    play_loading_overlay_bgm
    redraw_loading_overlay(0.0, 0.0)
    Graphics.update
    Input.update
  end

  def loading_overlay_steps
    return [
      _INTL("Booting survey uplink..."),
      _INTL("Scanning regional atlas..."),
      _INTL("Locking coordinates..."),
      _INTL("Aligning solar data..."),
      _INTL("Rendering terrain mesh...")
    ]
  end

  def set_loading_overlay_phase(phase_index, phase_ratio = 0.0)
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    max_index = loading_overlay_steps.length - 1
    new_phase_index = [[phase_index, 0].max, max_index].min
    new_phase_ratio = [[phase_ratio, 0.0].max, 1.0].min
    previous_phase_index = @loading_phase_index

    if previous_phase_index && new_phase_index > previous_phase_index
      @loading_text_reveal_started_at = System.uptime
      phase_linger_duration = @loading_overlay_full_intro ? 1.2 : 0.12
      phase_linger_started_at = System.uptime
      loop do
        elapsed = System.uptime - phase_linger_started_at
        linger_progress = [[elapsed / phase_linger_duration.to_f, 0.0].max, 1.0].min
        @loading_phase_index = new_phase_index
        @loading_phase_ratio = (new_phase_ratio * linger_progress).clamp(0.0, 1.0)
        tick_loading_overlay
        break if linger_progress >= 1.0
      end
    else
      @loading_phase_index = new_phase_index
      @loading_phase_ratio = new_phase_ratio
      tick_loading_overlay
    end
  end

  def tick_loading_overlay
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    redraw_loading_overlay(0.0, overlay_total_progress)
    Graphics.update
    Input.update
  end

  def overlay_total_progress
    total_steps = loading_overlay_steps.length
    return 1.0 if total_steps <= 1
    return ((@loading_phase_index + @loading_phase_ratio) / (total_steps - 1).to_f).clamp(0.0, 1.0)
  end

  def loading_spiral_cells(frame_x, frame_y, frame_w, frame_h, tile_size)
    cols = [(frame_w / tile_size.to_f).floor, 1].max
    rows = [(frame_h / tile_size.to_f).floor, 1].max
    cache_key = [frame_w, frame_h, tile_size, cols, rows]
    if @loading_spiral_cache_key != cache_key || !@loading_spiral_cells
      @loading_spiral_cells = []
      left = 0
      right = cols - 1
      top = 0
      bottom = rows - 1
      while left <= right && top <= bottom
        x = left
        while x <= right
          @loading_spiral_cells << [x, top]
          x += 1
        end
        y = top + 1
        while y <= bottom
          @loading_spiral_cells << [right, y]
          y += 1
        end
        if top < bottom
          x = right - 1
          while x >= left
            @loading_spiral_cells << [x, bottom]
            x -= 1
          end
        end
        if left < right
          y = bottom - 1
          while y > top
            @loading_spiral_cells << [left, y]
            y -= 1
          end
        end
        left += 1
        right -= 1
        top += 1
        bottom -= 1
      end
      @loading_spiral_cache_key = cache_key
    end

    return @loading_spiral_cells, cols, rows
  end

  def redraw_loading_overlay(reveal_ratio, sweep_ratio)
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    bmp = @loading_overlay.bitmap
    bmp.clear

    bg_color = Color.new(7, 11, 18)
    panel_color = Color.new(20, 34, 45)
    accent_color = Color.new(204, 170, 92)
    glow_color = Color.new(88, 168, 190)
    inactive_color = Color.new(66, 82, 92)
    shadow_color = Color.new(0, 0, 0)
    text_color = Color.new(244, 244, 244)
    dim_text_color = Color.new(148, 158, 164)

    bmp.fill_rect(0, 0, Graphics.width, Graphics.height, bg_color)

    frame_x = (Graphics.width - 420) / 2
    frame_y = (Graphics.height - 180) / 2
    frame_w = 420
    frame_h = 180
    bmp.fill_rect(frame_x, frame_y, frame_w, frame_h, panel_color)

    tile_size = 12
    spiral_cells, cols, rows = loading_spiral_cells(frame_x, frame_y, frame_w, frame_h, tile_size)
    reveal_count = (spiral_cells.length * sweep_ratio).to_i
    reveal_count = [[reveal_count, 0].max, spiral_cells.length].min
    i = 0
    while i < reveal_count
      cx, cy = spiral_cells[i]
      tx = frame_x + (cx * tile_size)
      ty = frame_y + (cy * tile_size)
      tw = [tile_size, frame_x + frame_w - tx].min
      th = [tile_size, frame_y + frame_h - ty].min
      # Blend through two alpha bands to keep the effect visible without obscuring UI text.
      tile_color = ((cx + cy) % 3 == 0) ? Color.new(88, 168, 190, 34) : Color.new(204, 170, 92, 24)
      bmp.fill_rect(tx, ty, tw, th, tile_color)
      i += 1
    end

    bmp.fill_rect(frame_x, frame_y, frame_w, 3, accent_color)
    bmp.fill_rect(frame_x, frame_y + frame_h - 3, frame_w, 3, accent_color)
    bmp.fill_rect(frame_x, frame_y, 3, frame_h, accent_color)
    bmp.fill_rect(frame_x + frame_w - 3, frame_y, 3, frame_h, accent_color)

    scanner_x = frame_x + 18
    scanner_y = frame_y + 18
    scanner_w = 112
    scanner_h = 112
    bmp.fill_rect(scanner_x, scanner_y, scanner_w, scanner_h, Color.new(12, 22, 29))
    bmp.fill_rect(scanner_x, scanner_y + (scanner_h / 2), scanner_w, 1, inactive_color)
    bmp.fill_rect(scanner_x + (scanner_w / 2), scanner_y, 1, scanner_h, inactive_color)
    live_scan_ratio = (System.uptime * 1.7) % 1.0
    sweep_line_y = scanner_y + ((scanner_h - 8) * live_scan_ratio).to_i
    bmp.fill_rect(scanner_x + 10, sweep_line_y, scanner_w - 20, 4, glow_color)
    bmp.fill_rect(scanner_x + 20, scanner_y + 20, 72, 72, Color.new(18, 32, 38, 120))

    indicator_y = frame_y + 22
    steps = loading_overlay_steps
    steps.each_with_index do |_label, idx|
      light_x = frame_x + 156 + (idx * 42)
      light_color = inactive_color
      light_color = accent_color if idx < @loading_phase_index
      light_color = glow_color if idx == @loading_phase_index
      bmp.fill_rect(light_x, indicator_y, 22, 8, light_color)
    end

    bar_x = frame_x + 156
    bar_y = frame_y + 118
    bar_w = 230
    bar_h = 10
    bmp.fill_rect(bar_x, bar_y, bar_w, bar_h, Color.new(28, 42, 50))
    filled_w = (bar_w * sweep_ratio).to_i
    bmp.fill_rect(bar_x, bar_y, filled_w, bar_h, accent_color) if filled_w > 0
    pulse_w = [32, (bar_w * 0.14).to_i].max
    pulse_x = bar_x + ((bar_w - pulse_w) * live_scan_ratio).to_i
    bmp.fill_rect(pulse_x, bar_y, pulse_w, bar_h, glow_color)

    slit_half = (Graphics.width * 0.5 * reveal_ratio).to_i
    if slit_half > 0
      center_x = Graphics.width / 2
      bmp.fill_rect(0, 0, center_x - slit_half, Graphics.height, Color.new(0, 0, 0, 180))
      bmp.fill_rect(center_x + slit_half, 0, Graphics.width - (center_x + slit_half), Graphics.height, Color.new(0, 0, 0, 180))
    end

    textpos = [
      [_INTL("Cartography Device Mk.II"), frame_x + 156, frame_y + 18, :left, text_color, shadow_color],
      [_INTL("Survey link active"), frame_x + 156, frame_y + 38, :left, glow_color, shadow_color]
    ]

    textpos = []
    active_label = steps[@loading_phase_index] || steps[-1]
    if active_label
      text_reveal_ratio = @loading_phase_ratio
      if @loading_text_reveal_started_at
        elapsed = System.uptime - @loading_text_reveal_started_at
        reveal_duration = @loading_overlay_full_intro ? 1.2 : 0.12
        text_reveal_ratio = [[elapsed / reveal_duration, 0.0].max, 1.0].min
      end
      shown_chars = (active_label.length * text_reveal_ratio).ceil
      shown_chars = 1 if @loading_phase_ratio > 0.0 && shown_chars <= 0
      shown_label = active_label[0, shown_chars]
      if shown_label && !shown_label.empty?
        textpos << [shown_label, frame_x + 156, frame_y + 66, :left, glow_color, shadow_color]
      end
    end
    pbDrawTextPositions(bmp, textpos)

    status_text = _INTL("Synchronizing telemetry...")
    pbDrawTextPositions(
      bmp,
      [[status_text, frame_x + frame_w - 18, frame_y + frame_h - 24, :right, text_color, shadow_color]]
    )
  end

  def animate_loading_overlay_out
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    @loading_phase_index = loading_overlay_steps.length - 1
    @loading_phase_ratio = 1.0
    first_leg_duration = @loading_overlay_full_intro ? 5.0 : 0.35
    first_leg_started_at = System.uptime
    loop do
      elapsed = System.uptime - first_leg_started_at
      progress = [[elapsed / first_leg_duration.to_f, 0.0].max, 1.0].min
      redraw_loading_overlay(0.0, 1.0)
      @loading_overlay.opacity = 255
      pbUpdateSpriteHash(@sprites)
      Graphics.update
      Input.update
      break if progress >= 1.0
    end
    duration = @loading_overlay_full_intro ? 6.0 : 0.75
    started_at = System.uptime
    loop do
      elapsed = System.uptime - started_at
      progress = [[elapsed / duration.to_f, 0.0].max, 1.0].min
      redraw_loading_overlay(progress, 1.0)
      @loading_overlay.opacity = ((1.0 - progress/4) * 255).to_i
      pbUpdateSpriteHash(@sprites)
      Graphics.update
      Input.update
      break if progress >= 1.0
    end
    play_loading_overlay_finish_impact
    show_loading_overlay_completion
    dispose_loading_overlay
  end

  def play_loading_overlay_finish_impact
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    started_at = System.uptime
    duration = 0.28
    loop do
      elapsed = System.uptime - started_at
      progress = [[elapsed / duration.to_f, 0.0].max, 1.0].min
      intensity = (1.0 - progress)
      shake = (Math.sin(elapsed * 70.0) * 6.0 * intensity).to_i
      @loading_overlay.x = shake
      @loading_overlay.color = Color.new(255, 255, 255, (150 * intensity).to_i)
      pbUpdateSpriteHash(@sprites)
      Graphics.update
      Input.update
      break if progress >= 1.0
    end
    @loading_overlay.x = 0
    @loading_overlay.color = Color.new(0, 0, 0, 0)
  end

  def show_loading_overlay_completion
    return if !@loading_overlay || pbDisposed?(@loading_overlay)

    pbMEPlay("Evolution success") if @loading_overlay_full_intro
    redraw_loading_overlay(1.0, 1.0)
    bmp = @loading_overlay.bitmap
    return if !bmp || bmp.disposed?

    message = _INTL("Region {1} Successfully Scanned!", @map ? @map.name : _INTL("Unknown"))
    box_w = 360
    box_h = 32
    box_x = (Graphics.width - box_w) / 2
    box_y = (Graphics.height / 2) + 72
    bmp.fill_rect(box_x, box_y, box_w, box_h, Color.new(8, 16, 22, 210))
    bmp.fill_rect(box_x, box_y, box_w, 2, Color.new(204, 170, 92))
    bmp.fill_rect(box_x, box_y + box_h - 2, box_w, 2, Color.new(204, 170, 92))
    pbDrawTextPositions(
      bmp,
      [[message, Graphics.width / 2, box_y + 6, :center, Color.new(244, 244, 244), Color.new(0, 0, 0)]]
    )

    if @loading_overlay_full_intro
      started_at = System.uptime
      duration = 1.6
      loop do
        elapsed = System.uptime - started_at
        break if elapsed >= duration
        pbUpdateSpriteHash(@sprites)
        Graphics.update
        Input.update
      end
    else
      pbUpdateSpriteHash(@sprites)
      Graphics.update
      Input.update
    end
  end

  def dispose_loading_overlay
    stop_loading_overlay_bgm
    set_loading_overlay_input_lock(false)
    if @loading_overlay
      @loading_overlay.bitmap.dispose if @loading_overlay.bitmap && !@loading_overlay.bitmap.disposed?
      @loading_overlay.dispose if !pbDisposed?(@loading_overlay)
      @loading_overlay = nil
    end
    if @loading_overlay_viewport && !@loading_overlay_viewport.disposed?
      @loading_overlay_viewport.dispose
      @loading_overlay_viewport = nil
    end
  end

  def ensure_world_map_assets
    return if @sprites["world_map"] && @sprites["world_map_frame"] && @sprites["clock_line"]

    @sprites["world_map"] = IconSprite.new(0, 0, @viewport)
    @sprites["world_map"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/world_map")
    @sprites["world_map"].x = (Graphics.width - @sprites["world_map"].bitmap.width) / 2
    @sprites["world_map"].y = (Graphics.height - @sprites["world_map"].bitmap.height) / 2
    @sprites["world_map"].visible = false

    @sprites["world_map_frame"] = IconSprite.new(0,0, @viewport)
    @sprites["world_map_frame"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/mapbg")
    @sprites["world_map_frame"].x = 0
    @sprites["world_map_frame"].y = 0
    @sprites["world_map_frame"].z = @sprites["world_map"].z + 1
    @sprites["world_map_frame"].visible = true

    @sprites["clock_line"] = Sprite.new(@viewport)
    @sprites["clock_line"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    @sprites["clock_line"].z = 99998
    @sprites["clock_line"].visible = false

    @sprites["world_label"] ||= BitmapSprite.new(Graphics.width, 48, @viewport)
    pbSetSystemFont(@sprites["world_label"].bitmap)
    @sprites["world_label"].z = 100002
    @sprites["world_label"].visible = true
  end

  def refresh_world_label(text,time)
    return if !@sprites["world_label"]

    bmp = @sprites["world_label"].bitmap
    bmp.clear

    pbDrawTextPositions(
      bmp,
      [[text, 12, 16, :left, TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR],
      [time, Graphics.width-32, 16, :right, TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR]]
    )
  end

  def ensure_region_map_assets
    return if @region_map_assets_ready

    phase_started_at = town_map_timing_start
    set_loading_overlay_phase(0, 0.2) if @loading_overlay
    @sprites["map"] = IconSprite.new(0, 0, @viewport)
    @sprites["map"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/#{@map.filename}")
    @sprites["map"].x += (Graphics.width - @sprites["map"].bitmap.width) / 2
    @sprites["map"].y += (Graphics.height - @sprites["map"].bitmap.height) / 2
    Settings::REGION_MAP_EXTRAS.each do |graphic|
      next if graphic[0] != @mapindex || !location_shown?(graphic)
      if !@sprites["map2"]
        @sprites["map2"] = BitmapSprite.new(480, 320, @viewport)
        @sprites["map2"].x = @sprites["map"].x
        @sprites["map2"].y = @sprites["map"].y
      end
      pbDrawImagePositions(
        @sprites["map2"].bitmap,
        [["Graphics/UI/Town Map/#{graphic[4]}", graphic[2] * SQUARE_WIDTH, graphic[3] * SQUARE_HEIGHT]]
      )
    end
    phase_started_at = town_map_timing_log("region_map.ensure_assets.map_sprite_setup", phase_started_at)

    cached_assets = cached_region_assets
    if cached_assets
      set_loading_overlay_phase(1, 0.8) if @loading_overlay
      apply_cached_region_assets(cached_assets)
      phase_started_at = town_map_timing_log("region_map.ensure_assets.cache_hit", phase_started_at)
    else
      set_loading_overlay_phase(1, 0.2) if @loading_overlay
      build_location_grid()
      phase_started_at = town_map_timing_log("region_map.ensure_assets.build_location_grid", phase_started_at)
      set_loading_overlay_phase(1, 0.7) if @loading_overlay
      build_pixel_cache()
      phase_started_at = town_map_timing_log("region_map.ensure_assets.build_pixel_cache", phase_started_at)
    end

    set_loading_overlay_phase(2, 0.2) if @loading_overlay
    @sprites["tile_overlay"] = Sprite.new(@viewport)
    map_bitmap = @sprites["map"].bitmap
    @sprites["tile_overlay"].bitmap = Bitmap.new(map_bitmap.width, map_bitmap.height)
    @sprites["tile_overlay"].x = @sprites["map"].x
    @sprites["tile_overlay"].y = @sprites["map"].y
    @sprites["tile_overlay"].z = @sprites["map"].z + 2
    phase_started_at = town_map_timing_log("region_map.ensure_assets.tile_overlay_setup", phase_started_at)

    if !cached_assets
      set_loading_overlay_phase(2, 0.65) if @loading_overlay
      generate_map_grid_overlay()
      phase_started_at = town_map_timing_log("region_map.ensure_assets.generate_map_grid_overlay", phase_started_at)
      cache_region_assets
      phase_started_at = town_map_timing_log("region_map.ensure_assets.cache_store", phase_started_at)
    end
    set_loading_overlay_phase(3, 0.2) if @loading_overlay
    compute_location_lighting()
    phase_started_at = town_map_timing_log("region_map.ensure_assets.compute_location_lighting", phase_started_at)
    set_loading_overlay_phase(3, 0.6) if @loading_overlay
    mark_dirty_tiles()
    phase_started_at = town_map_timing_log("region_map.ensure_assets.mark_dirty_tiles", phase_started_at)
    set_loading_overlay_phase(3, 0.9) if @loading_overlay
    redraw_dirty_tiles()
    phase_started_at = town_map_timing_log("region_map.ensure_assets.redraw_dirty_tiles", phase_started_at)

    set_loading_overlay_phase(4, 0.3) if @loading_overlay
    @sprites["mapbottom"] = MapBottomSprite.new(@viewport)
    @sprites["mapbottom"].mapname     = @map.name
    @sprites["mapbottom"].maplocation = pbGetMapLocation(@map_x, @map_y)
    @sprites["mapbottom"].mapdetails  = pbGetMapDetails(@map_x, @map_y)
    @sprites["mapbottom"].z = @sprites["tile_overlay"].z + 1
    if @playerpos && @mapindex == @playerpos[0]
      @sprites["player"] = IconSprite.new(0, 0, @viewport)
      @sprites["player"].setBitmap(GameData::TrainerType.player_map_icon_filename($player.trainer_type))
      @sprites["player"].x = point_x_to_screen_x(@map_x)
      @sprites["player"].y = point_y_to_screen_y(@map_y)
    end

    k = 0
    (LEFT..RIGHT).each do |i|
      (TOP..BOTTOM).each do |j|
        healspot = pbGetHealingSpot(i, j)
        next if !healspot || !$PokemonGlobal.visitedMaps[healspot[0]]
        @sprites["point#{k}"] = AnimatedSprite.create("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_fly", 2, 16)
        @sprites["point#{k}"].viewport = @viewport
        @sprites["point#{k}"].x        = point_x_to_screen_x(i)
        @sprites["point#{k}"].y        = point_y_to_screen_y(j)
        @sprites["point#{k}"].visible  = @mode == 1
        @sprites["point#{k}"].play
        k += 1
      end
    end
    phase_started_at = town_map_timing_log("region_map.ensure_assets.player_and_fly_points", phase_started_at)

    @sprites["cursor"] = AnimatedSprite.create("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/cursor", 2, 5)
    @sprites["cursor"].viewport = @viewport
    @sprites["cursor"].x        = point_x_to_screen_x(@map_x) - (SQUARE_WIDTH / 2)
    @sprites["cursor"].y        = point_y_to_screen_y(@map_y) - (SQUARE_HEIGHT / 2)
    @sprites["cursor"].z = @sprites["tile_overlay"].z + 1
    @sprites["cursor"].play

    @sprites["info_box"] = MapCursorInfo.new
    @sprites["info_box"].pbStartScene(@viewport)
    @sprites["info_box"].move_to(@sprites["cursor"].x + 16, @sprites["cursor"].y)
    @sprites["info_box"].visible = false

    @sprites["overlay_frame"] = IconSprite.new(0, 0, @viewport)
    @sprites["overlay_frame"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/overlay_frame")
    @sprites["overlay_frame"].z = @sprites["tile_overlay"].z

    refresh_fly_screen
    set_loading_overlay_phase(4, 1.0) if @loading_overlay
    town_map_timing_log("region_map.ensure_assets.remaining_ui_setup", phase_started_at)
    @region_map_assets_ready = true
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
    if Graphics.frame_count % @time_update_delay == 0 && @page_index == 0
      game_time = pbGetTimeNow()
      @universal_time = Time.at(game_time.to_i)
      #echoln "Updating time: #{@location_grid.length} locations to update lighting for."
      compute_location_lighting()
      mark_dirty_tiles()
      redraw_dirty_tiles()
      pbUpdateCursorInfo(@sprites["info_box"], @map_x, @map_y)
    end
    if @page_index == 1
      clock = current_clock

      if clock != @last_selected_clock
        draw_clock_line
        @last_selected_clock = clock
        if clock && clock.data[:local_time]
          time_text = clock.data[:local_time].to_s 
        else
          t = pbGetTimeNow
          h = (t.hour % 24 + clock.data[:time_zone]).to_i
          if h < 10
            h.to_s
            h = "0#{h}"
          end
          m = t.min
          time_text = _INTL("{1}:{2}", h, m)
        end
        refresh_world_label(clock.data[:name], time_text)
      end
      container = @containers[@selected_container]
      container.update if container
    end 
  end

  def pbStartScene(as_editor = false, fly_map = false)
    scene_started_at = town_map_timing_start
    @first_map_scene_tick_logged = false
    @editor   = as_editor
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    @fly_map = fly_map
    @mode    = fly_map ? 1 : 0
    map_metadata = $game_map.metadata
    playerpos = (map_metadata) ? map_metadata.town_map_position : nil
    if !playerpos
      mapindex = 0
      @map     = GameData::TownMap.get(0)
      @map_x   = LEFT
      @map_y   = TOP
    elsif @region >= 0 && @region != playerpos[0] && GameData::TownMap.exists?(@region)
      mapindex = @region
      @map     = GameData::TownMap.get(@region)
      @map_x   = LEFT
      @map_y   = TOP
    else
      mapindex = playerpos[0]
      @map     = GameData::TownMap.get(playerpos[0])
      @map_x   = playerpos[1]
      @map_y   = playerpos[2]
      mapsize  = map_metadata.town_map_size
      if mapsize && mapsize[0] && mapsize[0] > 0
        sqwidth  = mapsize[0]
        sqheight = (mapsize[1].length.to_f / mapsize[0]).ceil
        @map_x += ($game_player.x * sqwidth / $game_map.width).floor if sqwidth > 1
        @map_y += ($game_player.y * sqheight / $game_map.height).floor if sqheight > 1
      end
    end
    if !@map
      pbMessage(_INTL("The map data cannot be found."))
      return false
    end
    @playerpos = playerpos
    @mapindex = mapindex
    create_loading_overlay if loading_overlay_needed?
    phase_started_at = town_map_timing_log("scene.resolve_map_data", scene_started_at)
    addBackgroundOrColoredPlane(@sprites, "background", "Town Map/bg", Color.black, @viewport)
    @sprites["help"] = BitmapSprite.new(Graphics.width, 32, @viewport)
    pbSetSystemFont(@sprites["help"].bitmap)
    @changed = false
    if @page_index == 0
      ensure_region_map_assets
      phase_started_at = town_map_timing_log("scene.initial_region_page_setup", phase_started_at)
      setup_region_map
    else
      setup_world_map
      phase_started_at = town_map_timing_log("scene.initial_world_page_setup", phase_started_at)
    end
    town_map_timing_log("scene.remaining_ui_setup", phase_started_at)
    town_map_timing_log("scene.total_before_fade", scene_started_at)
    fade_started_at = town_map_timing_start
    if skip_town_map_transitions?
      pbUpdateSpriteHash(@sprites)
      town_map_timing_log("scene.fade_in_and_show_skipped", fade_started_at)
    else
      pbFadeInAndShow(@sprites) { pbUpdate }
      town_map_timing_log("scene.fade_in_and_show", fade_started_at)
    end
    animate_loading_overlay_out if @loading_overlay
    mark_region_intro_seen
    town_map_timing_log("scene.total_with_fade", scene_started_at)
  end

  def pbEndScene
    dispose_loading_overlay
    if skip_town_map_transitions?
      @sprites.each_value do |sprite|
        next if !sprite || pbDisposed?(sprite)
        sprite.visible = false
      end
    else
      pbFadeOutAndHide(@sprites)
    end
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def point_x_to_screen_x(x)
    return (x * SQUARE_WIDTH) + ((Graphics.width - @sprites["map"].bitmap.width) / 2)
  end

  def point_y_to_screen_y(y)
    return (y * SQUARE_HEIGHT) + ((Graphics.height - @sprites["map"].bitmap.height) / 2)
  end

  def location_shown?(point)
    return point[5] if @wallmap
    return point[1] > 0 && $game_switches[point[1]]
  end

  def pbSaveMapData
    GameData::TownMap.save
    Compiler.write_town_map
  end

  def pbChangeMapLocation(x, y)
    return "" if !@editor || !@map.point
    point = @map.point.select { |loc| loc[0] == x && loc[1] == y }[0]
    currentobj  = point
    currentname = (point) ? point[2] : ""
    currentname = pbMessageFreeText(_INTL("Set the name for this point."), currentname, false, 250) { pbUpdate }
    if currentname
      if currentobj
        currentobj[2] = currentname
      else
        newobj = [x, y, currentname, ""]
        @map.point.push(newobj)
      end
      @changed = true
    end
  end

  def pbGetMapDetails(x, y)
    return "" if !@map.point
    @map.point.each do |point|
      next if point[0] != x || point[1] != y
      return "" if point[7] && (@wallmap || point[7] <= 0 || !$game_switches[point[7]])
      return "" if !point[3]
      mapdesc = pbGetMessageFromHash(MessageTypes::REGION_LOCATION_DESCRIPTIONS, point[3])
      return (@editor) ? point[3] : mapdesc
    end
    return ""
  end

  def pbGetHealingSpot(x, y)
    return nil if !@map.point
    @map.point.each do |point|
      next if point[0] != x || point[1] != y
      return nil if point[7] && (@wallmap || point[7] <= 0 || !$game_switches[point[7]])
      return (point[4] && point[5] && point[6]) ? [point[4], point[5], point[6]] : nil
    end
    return nil
  end

  def refresh_fly_screen
    return if @fly_map || !Settings::CAN_FLY_FROM_TOWN_MAP || !pbCanFly?
    @sprites["help"].bitmap.clear
    text = (@mode == 0) ? _INTL("ACTION: Fly") : _INTL("ACTION: Cancel Fly")
    pbDrawTextPositions(
      @sprites["help"].bitmap,
      [[text, Graphics.width - 16, 4, :right, Color.new(248, 248, 248), Color.black]]
    )
    @sprites.each do |key, sprite|
      next if !key.include?("point")
      sprite.visible = (@mode == 1)
      sprite.frame   = 0
    end
  end

  def build_location_grid
    return if @page_index != 0
    @location_grid = {}
    @location_entries = []

    return if !@map.point

    tick_counter = 0

    @map.point.each do |line|
      parts = line.split(",", 6).map(&:strip)

      next if parts.length < 5

      x1 = parts[0].to_i
      y1 = parts[1].to_i
      x2 = parts[2].to_i
      y2 = parts[3].to_i
      time_zone = parts[4].to_i
      name = parts[5] || "Unknown"

      #echoln "Processing point: (#{x1},#{y1}) to (#{x2},#{y2})"
      key = [x1, y1, x2, y2]
      cx = ((x1.to_f + x2.to_f) / 2).to_i
      cy = ((y1.to_f + y2.to_f) / 2).to_i
      latitude = pbGetLatitude(cx, cy)
      temp = kelvin_to_rgb(6000 + 50 * latitude)
      entry = {
        key: key,
        name: name,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        time_zone: time_zone,
        latitude: latitude,
        temp: temp
      }
      @location_entries << entry
      @static_light_cache[key] = {
        latitude: latitude,
        temp: temp,
        time_zone: time_zone
      }

      min_x, max_x = [x1, x2].minmax
      min_y, max_y = [y1, y2].minmax

      (min_x..max_x).each do |tx|
        (min_y..max_y).each do |ty|
          @location_grid[[tx, ty]] = entry
          tick_counter += 1
          tick_loading_overlay if @loading_overlay && (tick_counter % 160).zero?
        end
      end
    end
  end

  def calculate_effective_hour_ui_cached(latitude, universal_time_year, universal_time_month, universal_time_day,
                                         universal_time_hour, universal_time_min, universal_time_sec, time_zone)
    if @sun_times_cache_day != universal_time_day
      @sun_times_cache = {}
      @effective_hour_cache = {}
      @sun_times_cache_day = universal_time_day
    end

    sun_key = [@region, latitude, universal_time_day]
    sun_data = @sun_times_cache[sun_key]
    if !sun_data
      decl_noon = SimulatedTime.calculate_solar_declination(universal_time_year, universal_time_day, 12.0)
      sunrise, sunset = SimulatedTime.find_sun_times(latitude, universal_time_day, universal_time_year)
      elev_noon = SimulatedTime.calculate_solar_elevation(latitude, decl_noon, 12.0)
      polar = :normal
      polar = :polar_day if sunrise == 0 && sunset == 24 && elev_noon > 0
      polar = :polar_night if sunrise == 0 && sunset == 0 && elev_noon < 0
      sun_data = {
        sunrise: sunrise,
        sunset:  sunset,
        decl_noon: decl_noon,
        polar: polar
      }
      @sun_times_cache[sun_key] = sun_data
    end

    cache_key = [@region, latitude, time_zone, universal_time_day,
                 universal_time_hour, universal_time_min, universal_time_sec, sun_data[:polar]]
    cached = @effective_hour_cache[cache_key]
    return cached if cached

    time_in_hours = universal_time_hour + (universal_time_min / 60.0) +
                    (universal_time_sec / 3600.0) + time_zone
    state = {
      effective_hour: time_in_hours,
      sun_state: sun_data[:polar]
    }

    case sun_data[:polar]
    when :polar_day
      elev = SimulatedTime.calculate_solar_elevation(latitude, sun_data[:decl_noon], time_in_hours)
      t = elev / (Math::PI / 2)
      state[:effective_hour] = 5 + t * 15
    when :polar_night
      decl = SimulatedTime.calculate_solar_declination(universal_time_year, universal_time_day, time_in_hours)
      elev = SimulatedTime.calculate_solar_elevation(latitude, decl, time_in_hours)
      t = (elev + Math::PI / 2) / (Math::PI / 2)
      state[:effective_hour] = SimulatedTime.wrap_hour(20 + t * 9)
    else
      state[:effective_hour] = SimulatedTime.equivalent_hour(time_in_hours, sun_data[:sunrise], sun_data[:sunset])
      state[:sun_state] = :normal
    end

    @effective_hour_cache[cache_key] = state
    return state
  end

    def compute_location_lighting
      return if @page_index != 0
      @location_light_cache = {}
      @polar_state = {}

      y     = @universal_time.year
      month = @universal_time.month
      day   = @universal_time.yday
      hour  = @universal_time.hour
      min   = @universal_time.min
      sec   = @universal_time.sec

      @location_entries.each do |loc|
        key = loc[:key]
        static = @static_light_cache[key]
        lat = static[:latitude]
        tz  = static[:time_zone]
        state = calculate_effective_hour_ui_cached(lat, y, month, day, hour, min, sec, tz)
        local_effective_hour = state[:effective_hour]
        @polar_state[key] = state[:sun_state]

        darkness = calculate_night_shadow(local_effective_hour)

        @location_light_cache[key] = {
          temp:     static[:temp],
          darkness: darkness,
          tod:      local_effective_hour,
        }
      end
    end

  def pbGetMapLocation(x, y)
    location = @location_grid[[x, y]]
    return location ? location[:name] : ""
  end

  def get_location_center(location)
    cx = (location[:x1] + location[:x2]) / 2
    cy = (location[:y1] + location[:y2]) / 2
    return [cx, cy]
  end

  def kelvin_to_rgb(temp_k)
    t = temp_k / 100.0

    # Red
    if t <= 66
      r = 255
    else
      r = 329.698727446 * ((t - 60) ** -0.1332047592)
      r = [[r, 0].max, 255].min
    end

      # Green
    if t <= 66
      g = 99.4708025861 * Math.log(t) - 161.1195681661
    else
      g = 288.1221695283 * ((t - 60) ** -0.0755148492)
    end
    g = [[g, 0].max, 255].min

    # Blue
    if t >= 66
      b = 255
    elsif t <= 19
      b = 0
    else
      b = 138.5177312231 * Math.log(t - 10) - 305.0447927307
      b = [[b, 0].max, 255].min
    end

    return Color.new(r.to_i, g.to_i, b.to_i)
  end

    def calculate_night_shadow(hour)
      return if @page_index != 0
      # Normalize hour to radians (peak at noon)
      angle = (hour - 12) * Math::PI / 12

      # Cosine gives smooth daylight curve
      light = Math.cos(angle)

      # Clamp and invert to darkness
      darkness = 1 - [[light, 0].max, 1].min

      return darkness
    end
  
    def pbGetLocationTOD(x, y)
      loc = @location_grid[[x, y]]
      return nil unless loc

      key = [loc[:x1], loc[:y1], loc[:x2], loc[:y2]]
      light = @location_light_cache[key]
      return nil unless light

      return light[:tod].to_i % 24
    end

  def softlight_channel(base, blend)
    b = base / 255.0
    l = blend / 255.0

    if l < 0.5
      result = b - (1 - 2 * l) * b * (1 - b)
    else
      result = b + (2 * l - 1) * (Math.sqrt(b) - b)
    end

    return (result * 255).clamp(0, 255).to_i
  end

  def softlight_color(base_color, blend_color, opacity)
    r_blend = softlight_channel(base_color.red,   blend_color.red)
    g_blend = softlight_channel(base_color.green, blend_color.green)
    b_blend = softlight_channel(base_color.blue,  blend_color.blue)

    r = base_color.red   + ((r_blend - base_color.red)   * opacity).to_i
    g = base_color.green + ((g_blend - base_color.green) * opacity).to_i
    b = base_color.blue  + ((b_blend - base_color.blue)  * opacity).to_i

    return Color.new(r, g, b)
  end

  def generate_map_grid_overlay
    return if @page_index != 0
    @overlay_tiles ||= []
    @overlay_tiles.clear
    tick_counter = 0
    #echoln "Location grid size: #{@location_grid.length}"

    (LEFT..RIGHT).each do |i|
      (TOP..BOTTOM).each do |j|
        # @location_grid[[i, j]] ? "Processing tile at (#{i}, #{j}) with location data." : "Processing tile at (#{i}, #{j}) with NO location data."
        if !@location_grid[[i, j]].nil?
          loc = @location_grid[[i, j]]
          #echoln "Adding overlay tile at (#{i}, #{j})"
          max_x = loc[:x2].to_i
          max_y = loc[:y2].to_i
          min_x = loc[:x1].to_i
          min_y = loc[:y1].to_i
          next unless loc[:x1].to_i <= max_x || loc[:x2].to_i <= max_x
          next unless loc[:y1].to_i <= max_y || loc[:y2].to_i <= max_y
          next unless loc[:x1].to_i >= min_x || loc[:x2].to_i >= min_x
          next unless loc[:y1].to_i >= min_y || loc[:y2].to_i >= min_y

          @overlay_tiles << [i, j, point_x_to_screen_x(i), point_y_to_screen_y(j)]
          tick_counter += 1
          tick_loading_overlay if @loading_overlay && (tick_counter % 120).zero?
        else
          #echoln "No location data for tile at (#{i}, #{j}), skipping overlay."
        end
      end
    end

    #echoln "Generated map grid overlay with #{@overlay_tiles.length} tiles."
    #echoln "Location grid size: #{@location_grid.length}"
  end


  def mark_dirty_tiles()
    return if @page_index != 0
    @dirty_tiles.clear
    tick_counter = 0

    (LEFT..RIGHT).each do |i|
      (TOP..BOTTOM).each do |j|
        next unless @location_grid[[i, j]]   # skip non-location tiles

        new_color = compute_tile_color_fast(i, j)
        next unless new_color

        if @tile_cache[[i, j]] != new_color
          @tile_cache[[i, j]] = new_color
          @dirty_tiles << [i, j]
        end
        tick_counter += 1
        tick_loading_overlay if @loading_overlay && (tick_counter % 120).zero?
      end
    end
  end

  def build_pixel_cache
    @pixel_cache = {}
    map_bitmap = @sprites["map"].bitmap
    tick_counter = 0
    (LEFT..RIGHT).each do |i|
      (TOP..BOTTOM).each do |j|
        next unless @location_grid[[i, j]]
        screen_x = point_x_to_screen_x(i) - @sprites["map"].x
        screen_y = point_y_to_screen_y(j) - @sprites["map"].y
        px = (screen_x + SQUARE_WIDTH / 2).clamp(0, map_bitmap.width - 1)
        py = (screen_y + SQUARE_HEIGHT / 2).clamp(0, map_bitmap.height - 1)
        @pixel_cache[[i, j]] = map_bitmap.get_pixel(px, py)
        tick_counter += 1
        tick_loading_overlay if @loading_overlay && (tick_counter % 120).zero?
      end
    end
  end

  def redraw_dirty_tiles()
    return if @page_index != 0
    bmp = @sprites["tile_overlay"].bitmap
    tick_counter = 0

    @dirty_tiles.each do |i, j|
      loc = @location_grid[[i, j]]
      next unless loc

      key = [loc[:x1], loc[:y1], loc[:x2], loc[:y2]]
      light = @location_light_cache[key]
      next unless light

      base = @pixel_cache[[i, j]]
      next unless base

      temp_color = light[:temp]
      darkness   = light[:darkness]

      screen_x = point_x_to_screen_x(i) - @sprites["map"].x
      screen_y = point_y_to_screen_y(j) - @sprites["map"].y

      blend = Color.new(
        (temp_color.red   * darkness).to_i,
        (temp_color.green * darkness).to_i,
        (temp_color.blue  * darkness).to_i
      )

      final = softlight_color(base, blend, 1.0)
      final.alpha = (@opacity * 255).to_i

      bmp.fill_rect(screen_x, screen_y, SQUARE_WIDTH, SQUARE_HEIGHT, final)
      tick_counter += 1
      tick_loading_overlay if @loading_overlay && (tick_counter % 80).zero?
    end
  end
 
  def redraw_map_overlay 
    bmp = @sprites["tile_overlay"].bitmap 
    bmp.clear 
    @overlay_tiles.each do |i, j, x, y| 
      draw_x = x - @sprites["map"].x 
      draw_y = y - @sprites["map"].y 
      next if draw_x < 0 || draw_y < 0 
      local_x = draw_x.clamp(0, @sprites["map"].bitmap.width - 1) 
      local_y = draw_y.clamp(0, @sprites["map"].bitmap.height - 1) 
      base = @sprites["map"].bitmap.get_pixel(local_x, local_y) 
      color = Color.new(255, 0, 0, (@opacity*255).to_i) # TEMP TEST 
      bmp.fill_rect(draw_x, draw_y, SQUARE_WIDTH, SQUARE_HEIGHT, color) 
    end 
  end

  def compute_tile_color_fast(i, j)
    location = @location_grid[[i, j]]
    return nil unless location

    key = [location[:x1], location[:y1], location[:x2], location[:y2]]
    light = @location_light_cache[key]
    return nil unless light

    temp = light[:temp]
    darkness = light[:darkness]

    return Color.new(
      (temp.red   * darkness).to_i,
      (temp.green * darkness).to_i,
      (temp.blue  * darkness).to_i
    )
  end


  def pbGetTimeZone(x, y)
    loc = @location_grid[[x, y]]
    return loc ? loc[:time_zone] : 0
  end

  def pbGetLatitude(x, y)
    # Placeholder implementation, replace with actual logic to determine latitude based on coordinates
    if @region == 0
      return 65 - (y/16).floor
    elsif @region == 1
      return 45-(y/16).floor
    elsif @region == 2
      return 17-(y/16).floor
    else
      return 32 - (y/16).floor
    end
  end

  def pbUpdateCursorInfo(info_box, x, y)
    if !@disable_info_box
      info_box.move_to(@sprites["cursor"].x+16, @sprites["cursor"].y)

      if @location_grid[[x, y]].nil?
        info_box.visible = false
        return
      else
        if info_box.visible == false
          info_box.visible = true
        end
        info_box.updateClock(@universal_time.hour+pbGetTimeZone(x, y), @universal_time.min, @polar_state[[x, y]])
        info_box.updateLocationName(pbGetMapLocation(x, y))
        info_box.tod_from_effective_hour(pbGetLocationTOD(x, y), @polar_state[[x, y]])
        location_name = pbGetMapLocation(@map_x, @map_y)
        info_box.refresh
      end
    end
  end

  def refresh_page
    if @page_index == 0
      setup_region_map
    else
      setup_world_map
    end
  end

  def setup_region_map
    ensure_region_map_assets
  # restore original sprites / logic
    @sprites["map"].visible = true
    @sprites["world_map"].visible = false if @sprites["world_map"]
    if !@containers.empty?
      @containers.each_with_index do |container|
        container.hide
      end
    end
    if @disable_info_box
      @disable_info_box = false
    end
    @sprites["cursor"].visible = !@loading_input_locked
    @sprites["mapbottom"].visible = true
    pbUpdateCursorInfo(@sprites["info_box"], @map_x, @map_y)
    @sprites["tile_overlay"].visible = true
    @sprites["clock_line"].visible = false if @sprites["clock_line"]
    @sprites["world_label"].visible = false if @sprites["world_label"]
    @sprites["world_map_frame"].visible = false if @sprites["world_map_frame"]
    @sprites["overlay_frame"].visible = true if @sprites["overlay_frame"]
  end

  def setup_world_map
    setup_started_at = town_map_timing_start
    phase_started_at = town_map_timing_start
    ensure_world_map_assets
    phase_started_at = town_map_timing_log("world_map.ensure_assets", phase_started_at)
    @sprites["map"].visible = false if @sprites["map"]
    @sprites["world_map"].visible = true
    @sprites["clock_line"].visible = true
    @sprites["world_map_frame"].visible = true if @sprites["world_map_frame"]
    @sprites["world_label"].visible = true if @sprites["world_label"]
    @sprites["overlay_frame"].visible = false if @sprites["overlay_frame"]

    # Build containers once
    if @containers.empty?
      phase_started_at = town_map_timing_start
      build_clocks
      phase_started_at = town_map_timing_log("world_map.build_clocks", phase_started_at)
      build_containers   # ← you need this method
      town_map_timing_log("world_map.build_containers", phase_started_at)
    end

    # Layout containers every time
    phase_started_at = town_map_timing_start
    @containers.each_with_index do |container, i|
      cx, cy = quadrant_position(container.region_id)
      is_active = (i == @selected_container)
      container.layout(cx, cy, is_active)
    end
    phase_started_at = town_map_timing_log("world_map.layout_containers", phase_started_at)

    # Hide region map UI
    if @sprites["info_box"] && @sprites["info_box"].visible
      @disable_info_box = true
      @sprites["info_box"].visible = false
    end

    @sprites["mapbottom"].visible = false if @sprites["mapbottom"]
    @sprites["cursor"].visible = false if @sprites["cursor"]
    @sprites["tile_overlay"].visible = false if @sprites["tile_overlay"]
    town_map_timing_log("world_map.total_setup", setup_started_at)
  end

def build_clocks
  @clock_data = []
  unlock_data = $PokemonGlobal.gv_unlocked_clocks

  GameData::WorldMap.load if GameData::WorldMap::DATA.nil? || GameData::WorldMap::DATA.empty?

  GameData::WorldMap.each do |map|
    next if !map[:point]

    map[:point].each do |point|
      region_id = map[:region_id] || map[:id]
      id = "#{region_id}_#{point[:x]}_#{point[:y]}"
      always_unlocked = point[:always_unlocked] || false

      @clock_data << {
        :id => id,
        :region_id => region_id,
        :point => { :x => point[:x], :y => point[:y] },
        :time_zone => point[:time_zone],
        :name => point[:name],
        :always_unlocked => always_unlocked,
        :unlocked => (always_unlocked || unlock_data[id] == true)
      }
    end
  end
end

 def build_containers
  groups = {}

  @clock_data.each do |data|
    next if !data[:unlocked]
    region = data[:region_id] || 0
    groups[region] ||= []
    groups[region] << data
  end

  @containers = []

  groups.each do |region_id, clocks|
    @containers << ClockContainer.new(region_id, clocks, @viewport, @scene)
  end
end

  def quadrant_position(region_id)
    #========================
    # STACK SETTINGS
    #========================
    base_x = 88                      # left anchor
    base_y = Graphics.height - 164   # bottom anchor

    row_spacing = 40                 # distance between rows

    #========================
    # COMPUTE POSITION
    #========================
    x = base_x
    y = base_y + (region_id * row_spacing)

    return [x, y]
  end

  def current_clock
    return nil if @containers.empty?

    container = @containers[@selected_container]
    return nil if !container
    return nil if container.clocks.empty?

    idx = container.index
    return nil if idx.nil?
    return nil if idx < 0 || idx >= container.clocks.length

    clock = container.clocks[idx]
    return nil if !clock

    return clock
  end

  def draw_clock_line
    bmp = @sprites["clock_line"].bitmap
    bmp.clear

    clock = current_clock
    return if !clock
    return if !clock.sprite
    return if !clock.sprite.bitmap

    x1 = clock.sprite.x + (clock.sprite.bitmap.width / 2)
    y1 = clock.sprite.y + (clock.sprite.bitmap.height / 2)

    px = clock.data[:point][:x]
    py = clock.data[:point][:y]

    x2, y2 = world_to_screen(px, py)

    draw_line(bmp, x1, y1, x2, y2, Color.new(180, 140, 60))
  end

  def world_to_screen(px, py)
    map_sprite = @sprites["world_map"]
    return [0, 0] if !map_sprite || !map_sprite.bitmap

    sx = map_sprite.x + px
    sy = map_sprite.y + py

    return [sx, sy]
  end

  def draw_line(bitmap, x1, y1, x2, y2, color, thickness = 3)
    dx = x2 - x1
    dy = y2 - y1

    steps = [dx.abs, dy.abs].max
    return if steps == 0

    x_inc = dx.to_f / steps
    y_inc = dy.to_f / steps

    x = x1.to_f
    y = y1.to_f

    offset = thickness / 2

    steps.times do
      (-offset..offset).each do |ox|
        (-offset..offset).each do |oy|
          bitmap.set_pixel(x.to_i + ox, y.to_i + oy, color)
        end
      end

      x += x_inc
      y += y_inc
    end
  end

  def refresh_world_map_layout
    @containers.each_with_index do |container, i|
      cx, cy = quadrant_position(container.region_id)
      is_active = (i == @selected_container)
      container.layout(cx, cy, is_active)
    end
  end

  def pbMapScene
    map_scene_started_at = town_map_timing_start
    x_offset = 0
    y_offset = 0
    new_x    = 0
    new_y    = 0
    timer_start = System.uptime
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if !@first_map_scene_tick_logged
        town_map_timing_log("scene.first_pbMapScene_tick", map_scene_started_at)
        @first_map_scene_tick_logged = true
      end
      next if @loading_input_locked
      if (x_offset != 0 || y_offset != 0) && @page_index == 0
        if x_offset != 0
          @sprites["cursor"].x = lerp(new_x - x_offset, new_x, 0.1, timer_start, System.uptime)
          x_offset = 0 if @sprites["cursor"].x == new_x
        end
        if y_offset != 0
          @sprites["cursor"].y = lerp(new_y - y_offset, new_y, 0.1, timer_start, System.uptime)
          y_offset = 0 if @sprites["cursor"].y == new_y
        end
        next if x_offset != 0 || y_offset != 0
        if !@disable_info_box
        @sprites["info_box"].move_to(@sprites["cursor"].x+16, @sprites["cursor"].y)
        end
      end
      ox = 0
      oy = 0
      if @page_index == 0
        case Input.dir8
        when 1, 2, 3
          oy = 1 if @map_y < BOTTOM
        when 7, 8, 9
          oy = -1 if @map_y > TOP
        end
        case Input.dir8
        when 1, 4, 7
          ox = -1 if @map_x > LEFT
        when 3, 6, 9
          ox = 1 if @map_x < RIGHT
        end
        if ox != 0 || oy != 0
          @map_x += ox
          @map_y += oy
          x_offset = ox * SQUARE_WIDTH
          y_offset = oy * SQUARE_HEIGHT
          new_x = @sprites["cursor"].x + x_offset
          new_y = @sprites["cursor"].y + y_offset
          timer_start = System.uptime
        end
      end
      if @page_index == 0
      @sprites["mapbottom"].maplocation = pbGetMapLocation(@map_x, @map_y)
      @sprites["mapbottom"].mapdetails  = pbGetMapDetails(@map_x, @map_y)
      end
      if Input.trigger?(Input::AUX1)   # or whatever button you want
        @page_index = (@page_index + 1) % 2
        refresh_page
      end
      if Input.trigger?(Input::AUX2)   # or whatever button you want
        @page_index = (@page_index - 1) % 2
        refresh_page
      end
      if @page_index == 0
      if Input.trigger?(Input::BACK)
          if @editor && @changed
            pbSaveMapData if pbConfirmMessage(_INTL("Save changes?")) { pbUpdate }
            break if pbConfirmMessage(_INTL("Exit from the map?")) { pbUpdate }
          else
            break
          end
        elsif Input.trigger?(Input::USE) && @mode == 1   # Choosing an area to fly to
          healspot = pbGetHealingSpot(@map_x, @map_y)
          if healspot && ($PokemonGlobal.visitedMaps[healspot[0]] ||
            ($DEBUG && Input.press?(Input::CTRL)))
            return healspot if @fly_map
            name = pbGetMapNameFromId(healspot[0])
            return healspot if pbConfirmMessage(_INTL("Would you like to use Fly to go to {1}?", name)) { pbUpdate }
          end
        elsif Input.trigger?(Input::USE) && @editor   # Intentionally after other USE input check
          pbChangeMapLocation(@map_x, @map_y)
        elsif Input.trigger?(Input::ACTION) && Settings::CAN_FLY_FROM_TOWN_MAP &&
              !@wallmap && !@fly_map && pbCanFly?
          pbPlayDecisionSE
          @mode = (@mode == 1) ? 0 : 1
          refresh_fly_screen
        end
      end
      if @page_index == 1 && @containers.length > 0
        current = @containers[@selected_container]

        if Input.trigger?(Input::LEFT)
          echoln "Left input detected on container #{@selected_container}"
          result = current.move_left

          if result == :ok
            current.play_arrow(:left)
          end
          refresh_world_map_layout

          if result == :overflow_left
           @selected_container -= 1
          @selected_container %= @containers.length

          new_container = @containers[@selected_container]
          next if !new_container || new_container.clocks.empty?

          new_container.index = new_container.clocks.length - 1
          new_container.adjust_scroll
          end

        elsif Input.trigger?(Input::RIGHT)
          echoln "Right input detected on container #{@selected_container}"
          result = current.move_right
          if result == :ok
            current.play_arrow(:right)
          end
          refresh_world_map_layout

          if result == :overflow_right
            @selected_container += 1
            @selected_container %= @containers.length
            refresh_world_map_layout
            new_container = @containers[@selected_container]
            # jump to start of next container
            new_container.index = 0
            new_container.adjust_scroll
          end
        end

        # Optional: keep UP/DOWN as direct container switching
        if Input.trigger?(Input::UP)
          @selected_container -= 1
          refresh_world_map_layout
        elsif Input.trigger?(Input::DOWN)
          @selected_container += 1
          refresh_world_map_layout
        end

        @selected_container %= @containers.length
      end
    end
    pbPlayCloseMenuSE
    return nil
  end
end

#===============================================================================
#
#===============================================================================
class PokemonRegionMapScreen
  def initialize(scene)
    @scene = scene
  end

  def pbStartFlyScreen
    @scene.pbStartScene(false, true)
    ret = @scene.pbMapScene
    @scene.pbEndScene
    return ret
  end

  def pbStartScreen
    @scene.pbStartScene($DEBUG)
    ret = @scene.pbMapScene
    @scene.pbEndScene
    return ret
  end
end

#===============================================================================
#
#===============================================================================
def pbShowMap(region = -1, wallmap = true)
  show_map_started_at = System.uptime
  map_block = proc do
    inner_started_at = System.uptime
    scene = PokemonRegionMap_Scene.new(region, wallmap)
    screen = PokemonRegionMapScreen.new(scene)
    ret = screen.pbStartScreen
    $game_temp.fly_destination = ret if ret && !wallmap
    echoln "[TownMapTiming] pbShowMap.inner_block: #{((System.uptime - inner_started_at) * 1000.0).round(1)}ms"
  end
  if GV_TOWN_MAP_SKIP_TRANSITIONS
    map_block.call
  else
    pbFadeOutIn do
      map_block.call
    end
  end
  echoln "[TownMapTiming] pbShowMap.total_with_outer_fade: #{((System.uptime - show_map_started_at) * 1000.0).round(1)}ms"
end
