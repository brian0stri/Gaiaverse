class PokemonTrainerCard_Scene
  alias GV_pbStartScene pbStartScene
  def pbStartScene
    self.GV_pbStartScene
    @exp_rank_bar = Sprite.new(@viewport)
    @exp_rank_bar_bitmap = AnimatedBitmap.new(_INTL("Graphics/Pictures/exp_rank_bar"))
    @exp_rank_bar.bitmap = @exp_rank_bar_bitmap.bitmap
    @exp_rank_bar.src_rect.width = @exp_rank_bar.bitmap.width / 10
    @exp_rank_bar.src_rect.height = @exp_rank_bar.bitmap.height
    @exp_rank_bar.x = 72
    @sprites["exp_rank_bar"] = @exp_rank_bar
  end

  alias GV_pbDrawTrainerCardFront pbDrawTrainerCardFront
  def pbDrawTrainerCardFront
    self.GV_pbDrawTrainerCardFront
    @exp_rank_bar.bitmap.clear
    baseColor   = Color.new(72, 72, 72)
    shadowColor = Color.new(160, 160, 160)
    totalsec = $stats.play_time.to_i
    hour = totalsec / 60 / 60
    min = totalsec / 60 % 60
    region = $player.get_current_region(0)
    current_rank = $player.get_current_expedition_rank(region)
    time = (hour > 0) ? _INTL("{1}h {2}m", hour, min) : _INTL("{1}m", min)
    $PokemonGlobal.startTime = Time.now if !$PokemonGlobal.startTime
    starttime = _INTL("{1} {2}, {3}",
                      pbGetAbbrevMonthName($PokemonGlobal.startTime.mon),
                      $PokemonGlobal.startTime.day,
                      $PokemonGlobal.startTime.year)
    case region
     when 0
      region_name = _INTL("Alpha")
      when 1
      region_name = _INTL("Beta")
      when 2
      region_name = _INTL("Gamma")
      when 3
      region_name = _INTL("Delta")
      else
        region_name = _INTL("Unknown")
    end
    textPositions = [
      [_INTL("Name"), 34, 70, :left, baseColor, shadowColor],
      [$player.name, 302, 70, :right, baseColor, shadowColor],
      [_INTL("ID No."), 332, 70, :left, baseColor, shadowColor],
      [sprintf("%05d", $player.public_ID), 468, 70, :right, baseColor, shadowColor],
      [_INTL("Money"), 34, 118, :left, baseColor, shadowColor],
      [_INTL("${1}", $player.money.to_s_formatted), 302, 118, :right, baseColor, shadowColor],
      [_INTL("Pokédex"), 34, 166, :left, baseColor, shadowColor],
      [sprintf("%d/%d", $player.pokedex.owned_count, $player.pokedex.seen_count), 302, 166, :right, baseColor, shadowColor],
      [_INTL("Time"), 34, 214, :left, baseColor, shadowColor],
      [time, 302, 214, :right, baseColor, shadowColor],
      [_INTL("Started"), 34, 262, :left, baseColor, shadowColor],
      [starttime, 302, 262, :right, baseColor, shadowColor],
      [_INTL(region_name + " Expedition Rank"), 34, 310, :left, baseColor, shadowColor],
      [current_rank.to_s, 302, 310, :right, baseColor, shadowColor],
      [_INTL(region_name + " Expedition Points"), 34, 358, :left, baseColor, shadowColor],
      [$player.expedition_points(region).to_s, 302, 358, :right, baseColor, shadowColor],
      [_INTL(region_name + " Expedition Progress"), 34, 406, :left, baseColor, shadowColor],
      [sprintf("%d%%", $player.expedition_progress(region)), 302, 406, :right, baseColor, shadowColor]
    ]
    pbDrawTextPositions(overlay, textPositions)
    x = 72
    @exp_rank_bar.src_rect.width *= $player.get_current_expedition_rank(region)
    pbDrawTextPositions(overlay, textPositions)
  end
end

class PokemonLoadPanel < Sprite
  alias GV_refresh refresh
  def refresh
    return if @refreshing
    return if disposed?
    @refreshing = true
    if !self.bitmap || self.bitmap.disposed?
      self.bitmap = Bitmap.new(@bgbitmap.width, 222)
      pbSetSystemFont(self.bitmap)
    end
    if @refreshBitmap
      @refreshBitmap = false
      self.bitmap&.clear
      if @isContinue
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, (@selected) ? 222 : 0, @bgbitmap.width, 222))
      else
        self.bitmap.blt(0, 0, @bgbitmap.bitmap, Rect.new(0, 444 + ((@selected) ? 46 : 0), @bgbitmap.width, 46))
      end
      textpos = []
      if @isContinue
        rank_for_region = proc do |region_idx|
          if @trainer.respond_to?(:get_current_expedition_rank)
            @trainer.get_current_expedition_rank(region_idx)
          elsif @trainer.respond_to?(:expedition_ranks)
            @trainer.expedition_ranks[region_idx] || 0
          else
            0
          end
        end
        textpos.push([@title, 32, 16, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([_INTL("Expedition Ranks:"), 32, 108, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([rank_for_region.call(0).to_s + ", ", 64,134, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([rank_for_region.call(1).to_s + ", ", 96, 134, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([rank_for_region.call(2).to_s + ", ", 128, 134, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([rank_for_region.call(3).to_s, 150, 134, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([_INTL("Pokédex:"), 32, 164, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([@trainer.pokedex.seen_count.to_s, 206, 164, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        textpos.push([_INTL("Time:"), 32, 188, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
        hour = @totalsec / 60 / 60
        min  = @totalsec / 60 % 60
        if hour > 0
          textpos.push([_INTL("{1}h {2}m", hour, min), 206, 188, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        else
          textpos.push([_INTL("{1}m", min), 206, 188, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
        end
        if @trainer.male?
          textpos.push([@trainer.name, 112, 70, :left, MALE_TEXT_COLOR, MALE_TEXT_SHADOW_COLOR])
        elsif @trainer.female?
          textpos.push([@trainer.name, 112, 70, :left, FEMALE_TEXT_COLOR, FEMALE_TEXT_SHADOW_COLOR])
        else
          textpos.push([@trainer.name, 112, 70, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
        end
        mapname = pbGetMapNameFromId(@mapid)
        mapname.gsub!(/\\PN/, @trainer.name)
        textpos.push([mapname, 386, 16, :right, TEXT_COLOR, TEXT_SHADOW_COLOR])
      else
        textpos.push([@title, 32, 14, :left, TEXT_COLOR, TEXT_SHADOW_COLOR])
      end
      pbDrawTextPositions(self.bitmap, textpos)
    end
    @refreshing = false
  self.GV_refresh
  end
end

class PokemonSave_Scene
  alias GV_pbStartScreen pbStartScreen
  def pbStartScreen
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}
    totalsec = $stats.play_time.to_i
    hour = totalsec / 60 / 60
    min = totalsec / 60 % 60
    mapname = $game_map.name
    if $player.male?
      text_tag = shadowc3tag(MALE_TEXT_BASE, MALE_TEXT_SHADOW)
    elsif $player.female?
      text_tag = shadowc3tag(FEMALE_TEXT_BASE, FEMALE_TEXT_SHADOW)
    else
      text_tag = shadowc3tag(OTHER_TEXT_BASE, OTHER_TEXT_SHADOW)
    end
    location_tag = shadowc3tag(LOCATION_TEXT_BASE, LOCATION_TEXT_SHADOW)
    loctext = location_tag + "<ac>" + mapname + "</ac></c3>"
    loctext += _INTL("Player") + "<r>" + text_tag + $player.name + "</c3><br>"
    if hour > 0
      loctext += _INTL("Time") + "<r>" + text_tag + _INTL("{1}h {2}m", hour, min) + "</c3><br>"
    else
      loctext += _INTL("Time") + "<r>" + text_tag + _INTL("{1}m", min) + "</c3><br>"
    end
    loctext += _INTL("Alpha Expedition Rank") + "<r>" + text_tag + $player.get_current_expedition_rank(0).to_s + "</c3><br>"
    loctext += _INTL("Beta Expedition Rank") + "<r>" + text_tag + $player.get_current_expedition_rank(1).to_s + "</c3><br>"
    loctext += _INTL("Gamma Expedition Rank") + "<r>" + text_tag + $player.get_current_expedition_rank(2).to_s + "</c3><br>"
    loctext += _INTL("Delta Expedition Rank") + "<r>" + text_tag + $player.get_current_expedition_rank(3).to_s + "</c3><br>"
    loctext += _INTL("Alpha Expedition Points") + "<r>" + text_tag + $player.expedition_points(0).to_s + "</c3><br>"
    loctext += _INTL("Beta Expedition Points") + "<r>" + text_tag + $player.expedition_points(1).to_s + "</c3><br>"
    loctext += _INTL("Gamma Expedition Points") + "<r>" + text_tag + $player.expedition_points(2).to_s + "</c3><br>"
    loctext += _INTL("Delta Expedition Points") + "<r>" + text_tag + $player.expedition_points(3).to_s + "</c3><br>" 
    if $player.has_pokedex
      loctext += _INTL("Pokédex") + "<r>" + text_tag + $player.pokedex.owned_count.to_s + "/" + $player.pokedex.seen_count.to_s + "</c3>"
    end
    @sprites["locwindow"] = Window_AdvancedTextPokemon.new(loctext)
    @sprites["locwindow"].viewport = @viewport
    @sprites["locwindow"].x = 0
    @sprites["locwindow"].y = 0
    @sprites["locwindow"].width = 228 if @sprites["locwindow"].width < 228
    @sprites["locwindow"].visible = true
  end
end

MenuHandlers.add(:debug_menu, :player_menu, {
  "name"        => _INTL("Player options..."),
  "parent"      => :main,
  "description" => _INTL("Set money, expedition rank, Pokédexes, player's appearance and name, etc."),
  "always_show" => false
})

MenuHandlers.add(:debug_menu, :set_expedition_rank, {
  "name"        => _INTL("Set Expedition Rank"),
  "parent"      => :player_menu,
  "description" => _INTL("Toggle possession of each Expedition Rank."),
  "effect"      => proc {
    eRankcmd = 0
    loop do
      eRankcmds = {}
      eRankcmds.push(_INTL("Give all"))
      eRankcmds.push(_INTL("Remove all"))
      input = ChooseNumberParams.new
      input.setRange(0, $game_settings.EXPEDITION_RANK_CAP+1)
      cancelValue = $game_settings.EXPEDITION_RANK_CAP + 1
      input.setDefaultValue($player.expedition_rank(pbGetCurrentRegion(0)))
      if input >= cancelValue
        break
      else
      4.times do |i|
        eRankcmds.push($player.expedition_ranks[i], input)
      end
      eRankcmd = pbShowCommands(nil, eRankcmds, -1, eRankcmd)
      break if eRankcmd < 0
      case eRankcmd
      when 0   # Give all
        4.times { |i| $player.expedition_ranks[i] = 10}
        4.times { |i| $player.expedition_points[i] = $game_settings.EXPEDITION_POINTS_PER_RANK.last }
      when 1   # Remove all
        4.times { |i| $player.expedition_ranks[i] = 0 }
        4.times { |i| $player.expedition_points[i] = 0 }
      else
        $player.expedition_ranks[eRankcmd - 2] = !$player.expedition_ranks[eRankcmd - 2]
        $player.expedition_points[eRankcmd - 2] = $game_settings.EXPEDITION_POINTS_PER_RANK.last if $player.expedition_ranks[eRankcmd - 2]
        end
      end
    end
  }
})

