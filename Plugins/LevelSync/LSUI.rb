class Battle::Battle_Scene_Objects

   def refresh_hp
    @hpNumbers.bitmap.clear
    return if !@battler.pokemon
    # Show HP numbers
    if @show_hp_numbers
      pbDrawNumber(self.hp, @hpNumbers.bitmap, 54, 2, :right)
      pbDrawNumber(-1, @hpNumbers.bitmap, 54, 2)   # / char
      pbDrawNumber(@battler.totalhp, @hpNumbers.bitmap, 70, 2)
      if @battle.level_sync_enabled
        self.hpNumbers.bitmap.font.color = $LSSettings.LSTextColor
        self.hpNumbers.bitmap.font.shadow_color = $LSSettings.LSTextShadowColor
      end
    end
    # Resize HP bar
    w = 0
    if self.hp > 0
      w = @hpBarBitmap.width.to_f * self.hp / @battler.totalhp
      w = 1 if w < 1
      # NOTE: The line below snaps the bar's width to the nearest 2 pixels, to
      #       fit in with the rest of the graphics which are doubled in size.
      w = ((w / 2.0).round) * 2
    end
    @hpBar.src_rect.width = w
    hpColor = 0                                      # Green bar
    hpColor = 1 if self.hp <= @battler.totalhp / 2   # Yellow bar
    hpColor = 2 if self.hp <= @battler.totalhp / 4   # Red bar
    @hpBar.src_rect.y = hpColor * @hpBarBitmap.height / 3
  end

  def draw_level(*args)
    #This method will draw the level sync text on the battle screen if the level sync is enabled for the current battle. 
    #The plugin will check if the level sync is enabled for the current battle, and if so, it will draw the level sync text on the battle screen using the colors defined in this module. 
    #It is important to ensure that the level sync text is displayed clearly and prominently on the battle screen to alert players that their Pokemon's stats have been synced, which can be important for gameplay and strategy decisions.
     # "Lv" graphic
    pbDrawImagePositions(self.bitmap, [[_INTL("Graphics/UI/Battle/overlay_lv"), @spriteBaseX + 140, 16]])
    # Level number
    if @battle.level_sync_enabled
      self.bitmap.font.color = $LSSettings.LSTextColor
      self.bitmap.font.shadow_color = $LSSettings.LSTextShadowColor
      pbDrawNumber(@battler.level, self.bitmap, @spriteBaseX + 162, 16)
    else
      pbDrawNumber(@battler.level, self.bitmap, @spriteBaseX + 162, 16)
    end
  end

end

class PokemonSummary_Scene
  attr_accessor :level_color
  attr_accessor :shadow_color
  def draw_sync_overlay
  overlay = @sprites["overlay"].bitmap
  overlay.clear_rect(46, 98, 64, 24)

  pbDrawTextPositions(overlay, [
    [@pokemon.display_level.to_s,
     46, 98,
     :left,
     $LSSettings.LSTextColor,
     $LSSettings.LSTextShadowColor]
  ])

  pbDrawImagePositions(overlay, [
    ["Plugins/LevelSync/Graphics/UI/Battle/synclabel",
     98, 98]
  ])
end

 alias ls_drawPageOne drawPageOne

 def drawPageOne
    
    return unless @pokemon
    ls_drawPageOne
    return unless @pokemon.synced?
  
    draw_sync_overlay
    echoln("Drawing sync overlay with color #{$LSSettings.LSTextColor}") if $DEBUG
  end

  alias ls_drawPageTwo drawPageTwo
  def drawPageTwo
    return unless @pokemon
        ls_drawPageTwo
    return unless @pokemon.synced?
    overlay = @sprites["overlay"].bitmap
    
    draw_sync_overlay
  end

  alias ls_draw_PageThree drawPageThree
    def drawPageThree

  return unless @pokemon
  ls_draw_PageThree

  return unless @pokemon.synced?

  overlay = @sprites["overlay"].bitmap

  overlay.clear_rect(46, 98, 64, 24)
  draw_sync_overlay


  # Re-draw only stat values with new color
  base   = $LSSettings.LSTextColor
  shadow = $LSSettings.LSTextShadowColor

   # Preserve nature shadow logic
  statshadows = {}
  default_shadow = Color.new(104, 104, 104)
  GameData::Stat.each_main { |s| statshadows[s.id] = default_shadow }

  if !@pokemon.shadowPokemon? || @pokemon.heartStage <= 3
    @pokemon.nature_for_stats.stat_changes.each do |change|
      statshadows[change[0]] = Color.new(136, 96, 72) if change[1] > 0
      statshadows[change[0]] = Color.new(64, 120, 152) if change[1] < 0
  end
end

 stats = {
    ATTACK:  [@pokemon.attack, 456, 126],
    DEFENSE: [@pokemon.defense, 456, 158],
    SPECIAL_ATTACK:  [@pokemon.spatk, 456, 190],
    SPECIAL_DEFENSE: [@pokemon.spdef, 456, 222],
    SPEED:   [@pokemon.speed, 456, 254]
  }

  stats.each do |stat, (value, x, y)|
    overlay.clear_rect(x - 50, y - 2, 100, 24)
    pbDrawTextPositions(overlay, [
      [value.to_s, x, y, :right, base, statshadows[stat]]
    ])
  end
end

alias ls_draw_PageFour drawPageFour
def drawPageFour
  return unless @pokemon
  ls_draw_PageFour

  return unless @pokemon.synced?

  draw_sync_overlay
end

  alias ls_drawSelectedMove drawSelectedMove
  def drawSelectedMove(move_to_learn, selected_move)
    ls_drawSelectedMove(move_to_learn, selected_move)
    overlay = @sprites["overlay"].bitmap
    base = Color.new(64, 64, 64)
    shadow = Color.new(176, 176, 176)
    cap = @pokemon.ls_bp_cap
    echoln("Drawing move details for #{selected_move.name}") if $DEBUG
    damage = selected_move.display_damage(@pokemon) || 0
    echoln("Synced? #{@pokemon.synced?}") if $DEBUG
    echoln("Battle exists? #{$battle != nil}") if $DEBUG    
    if @pokemon.synced? && cap && damage > 1
    damage = [damage, cap].min
      echoln("Applied BP cap: #{cap}. Display damage is now #{damage}") if $DEBUG
    end
    real_bp = selected_move.power || 0
    textpos = []
    if @pokemon.synced? && damage > 1 && real_bp > damage 
    width = overlay.text_size("000").width
    overlay.clear_rect(216 - width, 150, width + 10, 40)
    textpos.push([damage.to_s, 216, 160, :right, $LSSettings.LSTextColor, $LSSettings.LSTextShadowColor])
    else
    case damage
    when 0 then textpos.push(["---", 216, 160, :right, base, shadow])   # Status move
    when 1 then textpos.push(["???", 216, 160, :right, base, shadow])   # Variable power move
    else        textpos.push([real_bp.to_s, 216, 160, :right, base, shadow])
    end
    end
    if selected_move.display_accuracy(@pokemon) == 0
      textpos.push(["---", 216, 192, :right, base, shadow])
    else
      textpos.push(["#{selected_move.display_accuracy(@pokemon)}%", 216 + overlay.text_size("%").width, 192, :right, base, shadow])
    end
    # Draw all text
    echoln("Final display damage: #{damage}") if $DEBUG
    pbDrawTextPositions(overlay, textpos)

  end


  alias ls_draw_PageFive drawPageFive
  def drawPageFive
    ls_draw_PageFive
    if @pokemon.synced?
      draw_sync_overlay
    end
  end
end

  class Battle::Scene::PokemonDataBox
  
  alias ls_refresh refresh
  def refresh
   if syncing
    @numbersBitmap&.dispose
    @numbersBitmap = AnimatedBitmap.new(
      "Plugins/LevelSync/Graphics/UI/Battle/icon_numbers_sync"
    )
    else
    @numbersBitmap&.dispose
    @numbersBitmap = AnimatedBitmap.new(
      "Graphics/UI/Battle/icon_numbers"
    )
    end

    ls_refresh
    draw_sync_label if syncing
  end

  def syncing
  pkmn = @battler&.pokemon
  return false unless pkmn
  return pkmn.synced?
  end

  def draw_sync_label
    pbDrawImagePositions(self.bitmap, [
      ["Plugins/LevelSync/Graphics/UI/Battle/synclabel",
       @spriteBaseX, 36]
    ])
  end
end

class PokemonPartyPanel

    alias ls_draw_level draw_level
    def draw_level
      ls_draw_level
    return if @pokemon.egg?
    # "Lv" graphic
    return unless @pokemon.synced?
    display_level = @pokemon.display_level
    
    @overlaysprite.bitmap.clear_rect(20, 70, 22, 14)
    pbDrawImagePositions(@overlaysprite.bitmap,
                         [[_INTL("Graphics/UI/Party/overlay_lv"), 20, 70, 0, 0, 22, 14]])
    pbDrawTextPositions(@overlaysprite.bitmap,
                        [[@pokemon.name, 96, 22, :left, $LSSettings.LSTextColor, $LSSettings.LSTextShadowColor]])          
    pbSetSmallFont(@overlaysprite.bitmap)
    @overlaysprite.bitmap.clear_rect(42, 68, 32, 16)
    pbDrawTextPositions(@overlaysprite.bitmap,
                        [[display_level.to_s, 42, 68, :left, $LSSettings.LSTextColor, $LSSettings.LSTextShadowColor]])
    pbSetSystemFont(@overlaysprite.bitmap)
    pbDrawImagePositions(@overlaysprite.bitmap, [
      ["Plugins/LevelSync/Graphics/UI/Battle/synclabel",
       76, 70]
    ])
    end

end