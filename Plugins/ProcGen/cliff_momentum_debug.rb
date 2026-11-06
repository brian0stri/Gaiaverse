module ProcWild
  class CliffMomentumDebug
    DEBUG_ENABLED = true
    DEBUG_TILE_N = 1156
    DEBUG_TILE_S = 1155
    DEBUG_TILE_W = 1163
    DEBUG_TILE_E = 1164

    class << self
      def instance
        @instance ||= new
      end
    end

    def initialize
      @sprites = {}
    end

    def tile_id_for(direction)
      return nil unless DEBUG_ENABLED
      case direction
      when :north then DEBUG_TILE_N
      when :south then DEBUG_TILE_S
      when :west  then DEBUG_TILE_W
      when :east  then DEBUG_TILE_E
      else nil
      end
    end

    def direction_from_marker(marker)
      dirs = Array(marker).compact.uniq
      return nil if dirs.empty?
      return dirs.first if dirs.length == 1

      # Momentum debug must follow the generation direction, not the visual face.
      # Prefer the last cardinal direction in the marker order, which tracks the
      # current leading vector for the cliff run more faithfully than the face.
      dirs.last
    end

    def paint_debug_tile(map, map_x, map_y, momentum_dir)
      return unless DEBUG_ENABLED
      return if map.nil? || map_x.nil? || map_y.nil?

      direction = momentum_dir
      tile_id = tile_id_for(direction)
      return if tile_id.nil?

      # Cliff tiles live on layer 1. Debug arrows must sit above them on layer 2
      # so the underlying cliff remains visible beneath the indicator.
      map.data[map_x, map_y, 2] = tile_id
    end

    def draw_cell(map_x, map_y, face, layer = 2, z = nil)
      return unless DEBUG_ENABLED
      return if face.nil?

      # Deprecated: tileset-based debug arrows are painted directly into the map.
      # This method is kept as a no-op to avoid older callers crashing.
      nil
    end

    def clear
      @sprites.clear if @sprites
    end

    def hide_cell(map_x, map_y)
      nil
    end
  end
end
