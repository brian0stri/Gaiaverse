unless defined?(ClockContainerEntry)
  ClockContainerEntry = Struct.new(:data, :sprite, :hour_hand, :minute_hand)
end

class ClockContainer
  attr_reader :region_id, :clocks
  attr_accessor :index

  def initialize(region_id, clocks, viewport, scene)
    @region_id = region_id
    @viewport = viewport
    @clocks = clocks.map { |data| ClockContainerEntry.new(data, nil) }
    @index = 0
    @scroll_offset = 0
    @visible_count = 4
    @scene = scene

    @bg_sprite = Sprite.new(@viewport)
    @bg_sprite.z = 99998
    width  = @visible_count * 32 + 16
    height = 40

    @bg_sprite.bitmap = Bitmap.new(width, height)

    color = Color.new(0, 0, 0, 140) # tweak opacity here
    @bg_sprite.bitmap.fill_rect(0, 0, width, height, color)
    @bg_sprite.visible = true
    @bg_sprite.viewport = @viewport
    @bg_sprite.z = 99998

    @arrow_left_frames = 8
    @arrow_right_frames = 8


    @arrow_left = AnimatedSprite.new(
      "Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/leftarrow",
      8,
      40,  # ← FULL frame width (including padding)
      28,  # ← frame height (confirm this)
      2,
      @viewport
    )
    @arrow_left.z = 100001
    @arrow_left.stop
    @arrow_left.frame = 0

    @arrow_right = AnimatedSprite.new(
      "Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/rightarrow",
      8,
      40,
      28,
      2,
      @viewport
    )
    @arrow_right.z = 100001
    @arrow_right.stop
    @arrow_right.frame = 0
    @arrow_left_playing = false
    @arrow_right_playing = false
    @arrow_right.visible = true
  end

  def update
    t = System.uptime

    @arrow_left.opacity  = 180 + (Math.sin(t * 4) * 40)
    @arrow_right.opacity = 180 + (Math.sin(t * 4) * 40)
      if @arrow_left
      @arrow_left.update

      if @arrow_left_animating && @arrow_left.frame >= @arrow_left_frames - 1
        @arrow_left.stop
        @arrow_left.frame = 0
        @arrow_left_animating = false
      end
    end

    if @arrow_right
      @arrow_right.update

      if @arrow_right_animating && @arrow_right.frame >= @arrow_right_frames - 1
        @arrow_right.stop
        @arrow_right.frame = 0
        @arrow_right_animating = false
      end
    end

    @clocks.each_with_index do |clock, i|
      next if !clock.sprite

      base_y = clock.data[:base_y] || clock.sprite.y

      if i == @index
        bob = Math.sin(t * 2.5) * 4
        clock.sprite.y = base_y + bob
      else
        clock.sprite.y = base_y
      end
      apply_clock_tone(clock)
      tz = clock.data[:time_zone]
      time = pbGetTimeNow

      hour = (time.hour + tz) % 12
      minute = time.min
      second = time.sec
      clock.data[:local_time] = sprintf("%02d:%02d", hour, minute)

      hour_angle   = -(hour + minute / 60.0) * 30    # 360 / 12
      minute_angle = -minute * 6                     # 360 / 60

      if clock.hour_hand
        clock.hour_hand.angle = hour_angle
      end

      if i == @index && clock.minute_hand
       clock.minute_hand.angle = minute_angle
      end

      center_x = clock.sprite.x+ clock.sprite.bitmap.width / 2
      center_y = clock.sprite.y

      if clock.hour_hand
        clock.hour_hand.x = center_x
        clock.hour_hand.y = center_y
        clock.hour_hand.visible = true
      end

      if clock.minute_hand
        clock.minute_hand.x = center_x
        clock.minute_hand.y = center_y
        clock.minute_hand.visible = true
      end
    end
  end

  def apply_clock_tone(clock)
    px = clock.data[:point][:x]
    py = clock.data[:point][:y]
    tz = clock.data[:time_zone]

    lat = WorldMath.pbGetGlobalLatitude(px, py)

    time = pbGetTimeNow

    y     = time.year
    month = time.month
    day   = time.yday
    hour  = time.hour
    min   = time.min
    sec   = time.sec

    state = SimulatedTime.calculateEffectiveHourUI(
      lat, y, month, day, hour, min, sec, tz
    )

    effective_hour = state[:effective_hour]

    hour_f = effective_hour % 24
    h1 = hour_f.floor
    h2 = (h1 + 1) % 24
    t  = hour_f - h1

    tone1 = PBDayNight::HOURLY_TONES[h1]
    tone2 = PBDayNight::HOURLY_TONES[h2]
    #echoln "Applying tone to clock at (#{px}, #{py}) with effective hour #{hour_f.round(2)} (#{h1} to #{h2} transition, t=#{t.round(2)})"

    tone = Tone.new(
      tone1.red   + (tone2.red   - tone1.red)   * t,
      tone1.green + (tone2.green - tone1.green) * t,
      tone1.blue  + (tone2.blue  - tone1.blue)  * t,
      tone1.gray  + (tone2.gray  - tone1.gray)  * t
    )

    clock.sprite.tone = tone
  end

  def layout(cx, cy, active)
    hide

    clock_spacing = 32
    visible = @visible_count

    total_width = visible * clock_spacing

    left_edge  = cx
    right_edge = cx + total_width

    panel_x = left_edge - 8
    panel_y = cy - 20

    arrow_offset = 12

    @arrow_left.x  = left_edge  - arrow_offset
    @arrow_right.x = right_edge + arrow_offset

    @arrow_left.y  = cy
    @arrow_right.y = cy

    @bg_sprite.x = panel_x
    @bg_sprite.y = panel_y
    @bg_sprite.visible = true
    start_idx = @scroll_offset
    end_idx = start_idx + @visible_count - 1
    @arrow_left.ox = 20
    @arrow_right.ox = 20
    @arrow_left.oy = 14
    @arrow_right.oy = 14

    if active
      @arrow_left.visible  = true
      @arrow_right.visible = true

      # dim if cannot scroll
      @arrow_left.opacity  = (@scroll_offset > 0) ? 255 : 100
      @arrow_right.opacity = (@scroll_offset + @visible_count < @clocks.length) ? 255 : 100
    else
      @arrow_left.visible  = false
      @arrow_right.visible = false
    end

    (start_idx..end_idx).each do |clock_index|
      next if clock_index >= @clocks.length

      clock = get_clock(clock_index)
      sprite = clock.sprite
      sprite.x = left_edge + ((clock_index - start_idx) * clock_spacing)
      sprite.y = cy
      clock.hour_hand.x = sprite.x
      clock.hour_hand.y = cy

      clock.minute_hand.x = sprite.x
      clock.minute_hand.y = cy
      clock.data[:base_y] = cy
      sprite.visible = true
        clock.hour_hand.opacity = 255
        clock.minute_hand.opacity = 255
      apply_clock_tone(clock)

      is_active_clock = active && clock_index == @index

      sprite.zoom_x = is_active_clock ? 1.2 : 1.0
      sprite.zoom_y = is_active_clock ? 1.2 : 1.0

      # hour hand ALWAYS visible
      clock.hour_hand.visible = true if clock.hour_hand

      # minute hand ONLY for active
      clock.minute_hand.visible = is_active_clock if clock.minute_hand
    end
  end

  def get_clock(clock_index)
    clock = @clocks[clock_index]
    return nil if !clock
    return clock if clock.sprite

    sprite = IconSprite.new(0, 0, @viewport)
    sprite.setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/clock")
    sprite.z = 99999
    clock.sprite = sprite
    sprite.oy = sprite.bitmap.height / 2
    apply_clock_tone(clock)  
    # hour hand
    if !clock.hour_hand
      hour_hand = Sprite.new(@viewport)
      hour_hand.bitmap = Bitmap.new(3, 10)
      hour_hand.bitmap.fill_rect(1, 0, 3, 10, Color.black)
      hour_hand.ox = 1
      hour_hand.oy = hour_hand.bitmap.height
      hour_hand.z = sprite.z + 1
      hour_hand.tone = Tone.new(0, 0, 0, -40)
      clock.hour_hand = hour_hand
    end

    # minute hand
    if !clock.minute_hand
      minute_hand = Sprite.new(@viewport)
      minute_hand.bitmap = Bitmap.new(3, 14)
      minute_hand.bitmap.fill_rect(1, 0, 3, 14, Color.black)
      minute_hand.ox = 1
      minute_hand.oy = minute_hand.bitmap.height
      minute_hand.z = sprite.z + 2
      minute_hand.tone = Tone.new(0, 0, 0, -60)
      clock.minute_hand = minute_hand
    end
      return clock
  end

  def hide
    @clocks.each do |clock|
      next if !clock
      if clock.sprite
        clock.sprite.visible = false
      end

      if clock.hour_hand
        clock.hour_hand.visible = false
        clock.hour_hand.opacity = 0
      end

      if clock.minute_hand
        clock.minute_hand.visible = false
              clock.minute_hand.opacity = 0

      end
    end
  end

  def play_arrow(direction)
    if direction == :left && @arrow_left
      @arrow_left.frame = 0
      @arrow_left.play
      @arrow_left_animating = true
    elsif direction == :right && @arrow_right
      @arrow_right.frame = 0
      @arrow_right.play
      @arrow_right_animating = true
    end
  end

  def move_left
    if @index > 0
      @index -= 1
      adjust_scroll
      return :ok
    end
    return :overflow_left
  end

  def move_right
    if @index < @clocks.length - 1
      @index += 1
      adjust_scroll
      return :ok
    end
    return :overflow_right
  end

  def adjust_scroll
    if @index < @scroll_offset
      @scroll_offset = @index
    elsif @index >= @scroll_offset + @visible_count
      @scroll_offset = @index - @visible_count + 1
    end
  end
end

module WorldMath
  def self.pbGetGlobalLatitude(x, y)
    # find nearest tile row
    y = (y / 4.0).ceil * 4
    return 65 - (y / 4)
  end
end