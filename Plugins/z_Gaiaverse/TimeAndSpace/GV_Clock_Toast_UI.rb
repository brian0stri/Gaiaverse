class GV_ClockUnlockUI
  def self.show(id)
    return if !$scene || !$scene.is_a?(Scene_Map)

    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 100_000

    sprite = Sprite.new(viewport)
    sprite.bitmap = Bitmap.new(300, 40)

    pbSetSystemFont(sprite.bitmap)

    text = "New Clock Added!"
    pbDrawTextPositions(
      sprite.bitmap,
      [[text, 150, 8, :center, Color.white, Color.black]]
    )

    sprite.x = (Graphics.width - 300) / 2
    sprite.y = Graphics.height

    # slide up
    duration = 0.5
    start = System.uptime

    loop do
      t = (System.uptime - start) / duration
      break if t >= 1.0

      sprite.y = Graphics.height - (t * 60)
      Graphics.update
    end

    # hold
    hold_start = System.uptime
    while System.uptime - hold_start < 1.5
      Graphics.update
    end

    # fade out
    fade_start = System.uptime
    while System.uptime - fade_start < 0.5
      t = (System.uptime - fade_start) / 0.5
      sprite.opacity = 255 * (1 - t)
      Graphics.update
    end

    sprite.dispose
    viewport.dispose
  end
end