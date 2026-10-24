module ProcWild
  class HeightMap
    def initialize(seed = WORLD_SEED)
      @seed = seed
    end

    def height_at(wx, wy)
      base = smooth_noise(wx * 0.08, wy * 0.08)
      detail = smooth_noise(wx * 0.18 + 1000, wy * 0.18 + 1000) * 0.35

      value = (base + detail)/1.35

      case value
      when ...0.28 then 0
      when ...0.48 then 1
      when ...0.70 then 2
      else 3
      end
    end

    def smooth_noise(x, y)
      x0 = x.floor
      y0 = y.floor
      x1 = x0 + 1
      y1 = y0 + 1

      sx = x - x0
      sy = y - y0

      n00 = value_noise(x0, y0)
      n10 = value_noise(x1, y0)
      n01 = value_noise(x0, y1)
      n11 = value_noise(x1, y1)

      ix0 = lerp(n00, n10, fade(sx))
      ix1 = lerp(n01, n11, fade(sx))

      lerp(ix0, ix1, fade(sy))
    end

    def value_noise(x, y)
      n = (
        x * 374761393 +
        y * 668265263 +
        @seed * 982451653
      ) & 0xffffffff

      n = (n ^ (n >> 13)) * 1274126177
      n &= 0xffffffff

      (n.to_f / 0xffffffff)
    end

    def lerp(a, b, t)
      a + (b - a) * t
    end

    def fade(t)
      t * t * (3 - 2 * t)
    end

  end
end