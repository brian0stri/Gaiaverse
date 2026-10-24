class ClockSprite
  attr_reader :data
  attr_accessor :sprite
  attr_accessor :is_active

  def initialize(data, viewport)
    @data = data
    @sprite = IconSprite.new(0, 0, viewport)
    @is_active = false
    @sprite.setBitmap("Plugins/z_Gaiaverse/TimeAndSpace/Graphics/UI/Town Map/clock")
  end

  def set_position(x, y)
    @sprite.x = x
    @sprite.y = y
  end

  def selected=(is_active)
    if is_active == true
      @sprite.zoom_x = 1.5
      @sprite.zoom_y = 1.5
    else
      is_active = false
      @sprite.zoom_x = 1.0 
      @sprite.zoom_y = 1.0
    end
  end

  def visible=(v)
    @sprite.visible = v
  end
end