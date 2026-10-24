class MapCursorInfo < Sprite
  attr_reader :map_id, :x, :y

    TEXT_MAIN_COLOR   = Color.new(64, 64, 64)
    TEXT_SHADOW_COLOR = Color.new(128, 128, 128)

  def initialize(viewport = nil)
      super(viewport)
    @viewport =  Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @map_id = nil
    @tile_x = nil
    @tile_y = nil
    @x_offset = 16
    @screen_x = 0
    @screen_y = 0
    @clock_x = 14
    @clock_y = 16
    @clock_offset_x = 16
    @time_icon_x = @clock_x-1
    @time_icon_y = 60
    @sprites = {}
    @cursor_cache = {}
    @clock_pivot = [0, 0]
    @time_hint = ""
    @location_name = ""
    @visible = true
  end

  def pbUpdate(map_id, tile_x, tile_y, screen_x, screen_y, time)
    if map_id != @map_id || tile_x != @tile_x || tile_y != @tile_y
      @map_id = map_id
      @tile_x = tile_x
      @tile_y = tile_y
      @screen_x = screen_x
      @screen_y = screen_y
      @sprites = {}
      refresh
    end
  end

  def pbStartScene(viewport)
    @viewport = viewport
    @viewport.z = 99999
    addBackgroundOrColoredPlane(@sprites, "background", "Town Map/cursor_info_bg", Color.black, @viewport)
    @sprites["background"] = IconSprite.new(0, 0, @viewport)
    @sprites["background"].setBitmap(
      "Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/cursor_info_bg"
    )
    @sprites["background"].x = @screen_x + @x_offset
    @sprites["background"].y = @screen_y
    @sprites["background"].z = 5
    @sprites["clock"] = IconSprite.new(0, 0, @viewport)    
    @sprites["clock"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/clock")
    @sprites["clock"].x = @sprites["background"].x + 10
    @sprites["clock"].y = @sprites["background"].y + 8
    @sprites["clock"].z = @sprites["background"].z + 1
    @clock_pivot[0] = @sprites["clock"].x + 16
    @clock_pivot[1] = @sprites["clock"].y + 16
    @sprites["hour_hand"] = Sprite.new(@viewport)
    @sprites["hour_hand"].bitmap = Bitmap.new(4, 20)
    @sprites["hour_hand"].bitmap.fill_rect(0, 0, 3, 10, Color.black)
    @sprites["hour_hand"].bitmap.fill_rect(0, 0, 3, 10, Color.new(0, 0, 0))
    @sprites["hour_hand"].x = @clock_pivot[0]
    @sprites["hour_hand"].y = @clock_pivot[1]
    @sprites["hour_hand"].ox = 2
    @sprites["hour_hand"].oy = 10 
    @sprites["minute_hand"] = Sprite.new(@viewport)
    @sprites["minute_hand"].bitmap = Bitmap.new(2, 30)
    @sprites["minute_hand"].bitmap.fill_rect(0, 0, 2, 15, Color.black)
    @sprites["minute_hand"].bitmap.fill_rect(0, 0, 2, 15, Color.new(0, 0, 0))
    @sprites["minute_hand"].x = @clock_pivot[0]
    @sprites["minute_hand"].y = @clock_pivot[1]
    @sprites["minute_hand"].ox = 1
    @sprites["minute_hand"].oy = 15
    @sprites["hour_hand"].z = @sprites["clock"].z + 1
    @sprites["minute_hand"].z = @sprites["clock"].z + 2
    @sprites["time_icon"] = IconSprite.new(@viewport)
    @sprites["time_icon"].bitmap = Bitmap.new(16,16)
    @sprites["time_icon"].z = @sprites["background"].z + 1
    @sprites["text"] = Sprite.new(@viewport)
    @sprites["text"].bitmap = Bitmap.new(
      @sprites["background"].bitmap.width,
      @sprites["background"].bitmap.height
    )    
    @sprites["text"].x = @sprites["background"].x
    @sprites["text"].y = @sprites["background"].y
    @sprites["text"].z = @sprites["background"].z + 1

    pbSetSystemFont(@sprites["text"].bitmap)
    @sprites["text"].bitmap.font.size = 24
    refresh
    self.visible = @visible unless @visible.nil?  
  end
    # Placeholder for any future logic to update the cursor info display.
    # For now, it simply updates the internal state.
  def refresh
      return if !@sprites["background"]
      return if !@sprites["text"]

      @sprites["text"].bitmap.clear
      base_x = @sprites["background"].x
      base_y = @sprites["background"].y

      @sprites["text"].x = base_x
      @sprites["text"].y = base_y

      textpos = [
      [@location_name.to_s, 72, 18,  :left,  TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR],
      [@current_hour.to_s, 16, 80, :left,  TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR]
      ]
      pbDrawTextPositions(@sprites["text"].bitmap, textpos)

      lines = wrap_text(@time_hint.to_s, 90, @sprites["text"].bitmap)

      y = 42
      lines.each do |line|
        pbDrawTextPositions(@sprites["text"].bitmap, [
          [line, 72, y, :left, TEXT_MAIN_COLOR, TEXT_SHADOW_COLOR]
        ])
        y += 18
      end
    end   

  def wrap_text(text, width, bitmap)
    words = text.split(" ")
    lines = []
    current = ""

    words.each do |word|
      test = current.empty? ? word : current + " " + word
      if bitmap.text_size(test).width > width
        lines << current
        current = word
      else
        current = test
      end
    end

    lines << current unless current.empty?
    return lines
  end

  def updateClock(hour, minute, polar = nil)
    hour_agle = (-hour.to_f / 12) * 360 + 180
    minute_angle = (-minute.to_f / 60) * 360 + 180
    @sprites["hour_hand"].angle = hour_agle
    @sprites["minute_hand"].angle = minute_angle
    @current_hour = (hour.to_i % 24).to_s + ":" + minute.to_s.rjust(2, "0")
  end

  def move_to(x, y)
    return unless @sprites["background"]
    return unless @sprites["time_icon"]
    end_width = Graphics.width - @x_offset
    new_x = x + @x_offset
    y_offset = 8
    new_y = y
    delta = 0
    if x >= end_width - @sprites["background"].bitmap.width
      new_x -= (@sprites["background"].bitmap.width + 3*@x_offset)
      echoln "Moving cursor info to left side: #{new_x}"
      @sprites["background"].x = new_x
      @sprites["clock"].x = new_x + @clock_x
      @sprites["time_icon"].x = new_x + @clock_x + @sprites["time_icon"].bitmap.width/2
      @sprites["text"].x = new_x
      new_x -= @clock_x
    else
      new_x += @x_offset
      @sprites["background"].x = new_x
      @sprites["clock"].x = new_x + @clock_x
      @sprites["time_icon"].x = new_x + @clock_x + @sprites["time_icon"].bitmap.width/2
      @sprites["text"].x = new_x
      new_x -= @clock_x 
    end

    if y >= @sprites["background"].bitmap.height - y_offset
      new_y = Graphics.height - @sprites["background"].bitmap.height
      delta = 256 - @sprites["background"].bitmap.height
      @sprites["background"].y = @sprites["background"].bitmap.height - delta
      @sprites["clock"].y = @sprites["background"].bitmap.height - delta + @clock_y
      @sprites["time_icon"].y = @sprites["background"].bitmap.height - delta + @time_icon_y
      @sprites["text"].y = @sprites["background"].bitmap.height - delta
          update_clock_pivot(new_x,new_y-delta+3*@clock_y/2)
    else
      @sprites["background"].y = new_y
      @sprites["clock"].y = new_y + @clock_y    
      @sprites["time_icon"].y = new_y + @time_icon_y
      @sprites["text"].y = new_y
      update_clock_pivot(new_x,new_y+@clock_y/2)
    end

  end

  def update_clock_pivot(x, y)
    @sprites["hour_hand"].x = @clock_pivot[0] + x
    @sprites["hour_hand"].y = @clock_pivot[1] + y

    @sprites["minute_hand"].x = @clock_pivot[0] + x
    @sprites["minute_hand"].y = @clock_pivot[1] + y
  end

  def visible=(value)
    @visible = value
    return if !@sprites

    @sprites.each_value do |sprite|
      sprite.visible = value if sprite
    end
  end

  def visible
    return @visible
  end

  def updateLocationName(location)
    @location_name = location
  end

  def tod_from_effective_hour(h, polar)
    if polar == :polar_day
      @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_polar_day")
      @time_hint = "The Day of Eternal Sunlight"
    elsif polar == :polar_night
      @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_polar_night")
      @time_hint = "The Night of Eternal Darkness"
    else
      case h
      when 5...10
        @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_morning")
        @time_hint = "The sun is rising, bringing light and warmth to the world."
      when 10...17
        @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_day")
        @time_hint = "The sun is high in the sky, illuminating the world."
      when 17...20
        @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_evening")
        @time_hint = "The sun is setting, casting long shadows and painting the sky with warm colors."

      else
        @sprites["time_icon"].setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/icon_night")
        @time_hint = "The night has fallen, bringing darkness and tranquility."
      end
    end
  end
end