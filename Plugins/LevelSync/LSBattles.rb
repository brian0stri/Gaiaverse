class Battle
  attr_accessor :level_sync_caps
  attr_accessor :level_sync_enabled
  attr_accessor :level_sync_base_stats
  attr_accessor :level_sync_max_hp_base_stat
  attr_accessor :level_sync_max_attack_base_stat
  attr_accessor :level_sync_max_defense_base_stat
  attr_accessor :level_sync_max_special_attack_base_stat
  attr_accessor :level_sync_max_special_defense_base_stat
  attr_accessor :level_sync_max_speed_base_stat
  attr_accessor :level_sync_max_level
  attr_accessor :level_sync_max_ev
  attr_accessor :level_sync_max_iv
  attr_accessor :level_sync_max_bp
  attr_accessor :level_sync_overlay_shown
  attr_accessor :level_sync_battle_message

  alias ls_initialize initialize
  def initialize(*args)
    ls_initialize(*args)
    @level_sync_warning_shown = $LSSettings.LSDisplayWarning ? false : true
    @level_sync_warning_text = $LSSettings.LSWarningText
    @level_sync_warning_window = nil
    @level_sync_level_enabled = $LSSettings.LSLevel
    @level_sync_iv_enabled = $LSSettings.LSIVs
    @level_sync_ev_enabled = $LSSettings.LSEVs
    @level_sync_bp_enabled = $LSSettings.LSMoveBP
    @level_sync_base_stats_enabled = $LSSettings.LSBaseStats

    @level_sync_mode_enabled = $LSSettings.LSModeEnabled
    @ls_sync_experience = $LSSettings.LSExperience
    @ls_sync_exp_mode = $LSSettings.LSSyncExpMode
    @ls_battle_message = $LSSettings.LSBattleMessage
  end

  def evaluate_level_sync
    if $LSSettings.LSEnabled && $LSSettings.LSEnabledGlobal
      return @level_sync_enabled = true 
    elsif $LSSettings.LSEnabled && $LSSettings.LSEnabledGlobal && $LSSettings.LSWildPokemonGlobal && wild_battle?
      return @level_sync_enabled = true
    elsif $LSSettings.LSEnabled && !$LSSettings.LSEnabledGlobal && !$LSSettings.LSWildPokemonGlobal && wild_battle? && ($LSSettings.LSSpecificWild == :Encounters && @LSEncounterTypes.include?(EncounterType.new($game_player.encounter_type)) || $LSSettings.LSSpecificWild == :Maps && @LSMapsWildArr.include?($game_map.map_id))
      return @level_sync_enabled = true
    elsif $LSSettings.LSEnabled && $LSSettings.LSEnabledGlobal && $LSSettings.LSTrainerPokemonGlobal && trainer_battle?
      return @level_sync_enabled = true
    elsif $LSSettings.LSEnabled && !$LSSettings.LSEnabledGlobal && !$LSSettings.LSTrainerPokemonGlobal && trainer_battle? && (@LSTrainerClasses.include?($game_trainer.trainer_class) && $LSSettings.LSSpecificTrainers == :Class || $LSSettings.LSSpecificTrainers == :Maps && @LSMapsTrainersArr.include?($game_map.map_id))
      return @level_sync_enabled = true
    else
      return @level_sync_enabled = false
    end
  end

  def determine_level_sync_caps
    #pbMessage("Determining level sync caps...") if $DEBUG
    #pbMessage("Battlers total: #{@battlers.length}") if $DEBUG
    @battlers.each do |b|
    next unless b
    #pbMessage("Battler exists. Opposes? #{b.opposes?}")
    end
    return unless @level_sync_enabled

   
    opponent_pokemon = []

    opponent_pokemon = []

    @battlers.each do |b|
      next unless b
      next unless b.opposes?
      opponent_pokemon << b.pokemon
    end

    #pbMessage("Opponent count: #{opponent_pokemon.length}") if $DEBUG
    #pbMessage("BP enabled? #{@level_sync_bp_enabled}") if $DEBUG
    if $DEBUG
      opponent_pokemon.each do |p|
    p.moves.each do |m|
    #pbMessage("Move: #{m.id} | BP: #{m.base_damage.inspect}")
      end
    end
    end
     opponent_levels = []
    
    opponent_pokemon.each do |pkmn|
    next unless pkmn
    opponent_levels << pkmn.level
    
    end 

    @level_sync_caps = {}   # force initialize

    if @level_sync_level_enabled
    case @level_sync_mode_enabled
    when :Max
    @level_sync_caps[:level] = opponent_levels.max 
    when :Min
    @level_sync_caps[:level] = opponent_levels.min
    when :Random
    @level_sync_caps[:level] = opponent_levels.sample
    when :BadgeCount
    badge_count = $LSSettings_variables[LevelCapsByBadgeCount] || 0
    @level_sync_caps[:level] = LevelCapsByBadgeCount[badge_count] || 50
    when :UserValue
    @level_sync_caps[:level] = LSUserLevelCap
    end
    end 

    if @level_sync_base_stats_enabled
    case @level_sync_mode_enabled
    when :Max
    @level_sync_caps[:hp]  = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:HP] }.max
    @level_sync_caps[:atk] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:ATTACK] }.max
    @level_sync_caps[:def] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:DEFENSE] }.max
    @level_sync_caps[:spa] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_ATTACK] }.max
    @level_sync_caps[:spd] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_DEFENSE] }.max
    @level_sync_caps[:spe] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPEED] }.max
    when :Min
    @level_sync_caps[:hp]  = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:HP] }.min
    @level_sync_caps[:atk] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:ATTACK] }.min
    @level_sync_caps[:def] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:DEFENSE] }.min
    @level_sync_caps[:spa] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_ATTACK] }.min
    @level_sync_caps[:spd] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_DEFENSE] }.min
    @level_sync_caps[:spe] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPEED] }.min
    when :Random
    chosen = opponent_pokemon.sample
    @level_sync_caps[:hp]  = chosen.get_base_stats(chosen.species)[:HP]
    @level_sync_caps[:atk] = chosen.get_base_stats(chosen.species)[:ATTACK]
    @level_sync_caps[:def] = chosen.get_base_stats(chosen.species)[:DEFENSE]
    @level_sync_caps[:spa] = chosen.get_base_stats(chosen.species)[:SPECIAL_ATTACK]
    @level_sync_caps[:spd] = chosen.get_base_stats(chosen.species)[:SPECIAL_DEFENSE]
    @level_sync_caps[:spe] = chosen.get_base_stats(chosen.species)[:SPEED]
    when :BadgeCount #defaults to max if badge count mode is on.
    @level_sync_caps[:hp]  = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:HP] }.max
    @level_sync_caps[:atk] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:ATTACK] }.max
    @level_sync_caps[:def] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:DEFENSE] }.max
    @level_sync_caps[:spa] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_ATTACK] }.max
    @level_sync_caps[:spd] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPECIAL_DEFENSE] }.max
    @level_sync_caps[:spe] = opponent_pokemon.map { |p| p.get_base_stats(p.species)[:SPEED] }.max
    when :UserValue
    @level_sync_caps[:hp]  = LSMaxHPBaseStat
    @level_sync_caps[:atk] = LSMaxAttackBaseStat
    @level_sync_caps[:def] = LSMaxDefenseBaseStat
    @level_sync_caps[:spa] = LSMaxSpecialAttackBaseStat
    @level_sync_caps[:spd] = LSMaxSpecialDefenseBaseStat
    @level_sync_caps[:spe] = LSMaxSpeedBaseStat
    end
    end

    if @level_sync_ev_enabled
    case @level_sync_mode_enabled
    when :Max
    @level_sync_caps[:ev] = opponent_pokemon.map { |p| p.ev.values }.transpose.map(&:max).max
    when :Min
    @level_sync_caps[:ev] = opponent_pokemon.map { |p| p.ev.values }.transpose.map(&:min).min
    when :Random  
    @level_sync_caps[:ev] = opponent_pokemon.map { |p| p.ev.values }.transpose.map { |vals| vals.sample }.max
    when :BadgeCount #defaults to max if badge count mode is on.
    @level_sync_caps[:ev] = opponent_pokemon.map { |p| p.ev.values }.transpose.map(&:max).max
    when :UserValue
    @level_sync_caps[:ev] = LSMaxEV
    end
    end

    if @level_sync_iv_enabled
    case @level_sync_mode_enabled
    when :Max
    @level_sync_caps[:iv] = opponent_pokemon.map { |p| p.iv.values }.transpose.map(&:max).max
    when :Min
    @level_sync_caps[:iv] = opponent_pokemon.map { |p| p.iv.values }.transpose.map(&:min).min
    when :Random
    chosen = opponent_pokemon.sample
    @level_sync_caps[:iv] = chosen.iv.values.transpose.map { |vals| vals.sample }.max
    when :BadgeCount #defaults to max if badge count mode is on.
    @level_sync_caps[:iv] = opponent_pokemon.map { |p| p.iv.values }.transpose.map(&:max).max
    when :UserValue
    @level_sync_caps[:iv] = LSMaxIV
    end
    end

    if @level_sync_bp_enabled
      bp_values = []

      opponent_pokemon.each do |p|
      p.moves.each do |move|
      next unless move
      move_data = GameData::Move.get(move.id)
      bp = move_data.base_damage
      next if bp.nil? || bp <= 0
      bp_values << bp
      end
      end
      
      case @level_sync_mode_enabled
      when :Max
        @level_sync_caps[:bp] = bp_values.max
      when :Min
        @level_sync_caps[:bp] = bp_values.min
      when :Random
        @level_sync_caps[:bp] = bp_values.sample
      when :BadgeCount
        @level_sync_caps[:bp] = bp_values.max # For now, badge count mode will just default to max BP cap since it doesn't make as much sense to tie it to badge count.
      when :UserValue
        @level_sync_caps[:bp] = LSMaxBP
      end
    end
  end

  def refresh_battlers_after_sync
      @battlers.each do |b|
      next unless b && b.pokemon

      b.pokemon.apply_level_sync(@level_sync_caps, @level_sync_base_stats_enabled)
      b.pokemon.calc_stats

      b.instance_variable_set(:@level,   b.pokemon.battle_level)
      b.instance_variable_set(:@attack,  b.pokemon.attack)
      b.instance_variable_set(:@defense, b.pokemon.defense)
      b.instance_variable_set(:@spatk,   b.pokemon.spatk)
      b.instance_variable_set(:@spdef,   b.pokemon.spdef)
      b.instance_variable_set(:@speed,   b.pokemon.speed)
      b.instance_variable_set(:@totalhp, b.pokemon.totalhp)
      b.instance_variable_set(:@hp,      b.pokemon.hp)
      echoln("Refreshed stats for #{b.pokemon.name}: Level #{b.level}, HP #{b.hp}/#{b.totalhp}, Atk #{b.attack}, Def #{b.defense}, SpAtk #{b.spatk}, SpDef #{b.spdef}, Spe #{b.speed}") if $DEBUG
      end
      @ls_sync_applied = true
    end

  alias ls_pbStartBattleCore pbStartBattleCore

  def pbStartBattleCore
    sendOuts = pbSetUpSides
    @level_sync_enabled = evaluate_level_sync
    @battleAI.create_ai_objects
    @scene.pbStartBattle(self)
    pbStartBattleSendOut(sendOuts)
    pbOnAllBattlersEnteringBattle

       #Level Sync slider

   # Battlers now exist here
    if @level_sync_enabled
      determine_level_sync_caps
      refresh_battlers_after_sync


      #pbMessage("Battlers: #{@battlers.length}")

      pbParty(0).each do |pkmn|
        next unless pkmn
        if pkmn != @battlers[0].pokemon
        pkmn.apply_level_sync(@level_sync_caps, @level_sync_base_stats_enabled)
        end
        #pbMessage("Applied level sync to #{pkmn.name}. Caps: #{@level_sync_caps.inspect}") if $DEBUG
      end
      
      if  !@level_sync_overlay_shown
        @battlers.each do |b|
        next unless b && b.is_Syncing? && !b.opposes?

        @scene.pbCommonAnimation("StatUp", b)
        @scene.pbRefreshOne(b.index)
        end
      end

      if !@level_sync_overlay_shown
          @scene.pbDisplayMessage(_INTL("#{@ls_battle_message}"))      
          @level_sync_overlay_shown = true
      end
    end

    pbBattleLoop
  end


  alias ls_pbBattleLoop pbBattleLoop
def pbBattleLoop
  ls_pbBattleLoop

  # Cleanup AFTER battle finishes
  if @level_sync_enabled
    echoln("Running Level Sync cleanup") if $DEBUG

    pbParty(0).each do |pkmn|
      next unless pkmn
      pkmn.clear_level_sync
    end
  end
end
end

class Battle::Battler
  attr_accessor :ls_temp_level
  attr_accessor :ls_temp_ev
  attr_accessor :ls_temp_iv
  attr_accessor :ls_temp_base_stats
  attr_accessor :ls_temp_delta

  def level
    return @pokemon.battle_level
  end

  def is_Syncing?
    return false unless @pokemon && @battle.level_sync_enabled
    return false unless @pokemon
    return false unless @battle.level_sync_enabled
    return true if @pokemon.ls_temp_level
    return true if @pokemon.ls_temp_ev
    return true if @pokemon.ls_temp_iv
    return true if @pokemon.ls_temp_base_stats
    return true if @pokemon.ls_temp_delta
    return false
  end
end


class Battle::Experience
  def pbGainExpOne(idxParty, defeatedBattler, numPartic, expShare, expAll, showMessages = true)
    pkmn = pbParty(0)[idxParty]   # The Pokémon gaining Exp from defeatedBattler
    @originalLevel = $gamedata.get_pokemon(pkmn).level
    growth_rate = pkmn.growth_rate
    # Don't bother calculating if gainer is already at max Exp
    if pkmn.exp >= growth_rate.maximum_exp
      pkmn.calc_stats   # To ensure new EVs still have an effect
      return
    end
    isPartic    = defeatedBattler.participants.include?(idxParty)
    hasExpShare = expShare.include?(idxParty)
    level = defeatedBattler.level
    # Main Exp calculation
    exp = 0
    if pkmn.is_Syncing? && @ls_sync_experience && @ls_sync_exp_mode == :Reduced && @originalLevel < 100
      a = pkmn.ls_temporary_level * defeatedBattler.pokemon.base_exp
    elsif pkmn.is_Syncing? && @ls_sync_experience && @ls_sync_exp_mode == :Skip
      a = 0
    else
      a = level * defeatedBattler.pokemon.base_exp
    end
    if expShare.length > 0 && (isPartic || hasExpShare)
      if numPartic == 0   # No participants, all Exp goes to Exp Share holders
        exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? expShare.length : 1)
      elsif Settings::SPLIT_EXP_BETWEEN_GAINERS   # Gain from participating and/or Exp Share
        exp = a / (2 * numPartic) if isPartic
        exp += a / (2 * expShare.length) if hasExpShare
      else   # Gain from participating and/or Exp Share (Exp not split)
        exp = (isPartic) ? a : a / 2
      end
    elsif isPartic   # Participated in battle, no Exp Shares held by anyone
      exp = a / (Settings::SPLIT_EXP_BETWEEN_GAINERS ? numPartic : 1)
    elsif expAll   # Didn't participate in battle, gaining Exp due to Exp All
      # NOTE: Exp All works like the Exp Share from Gen 6+, not like the Exp All
      #       from Gen 1, i.e. Exp isn't split between all Pokémon gaining it.
      exp = a / 2
    end
    return if exp <= 0
    # Pokémon gain more Exp from trainer battles
    exp = (exp * 1.5).floor if Settings::MORE_EXP_FROM_TRAINER_POKEMON && trainerBattle?
    # Scale the gained Exp based on the gainer's level (or not)
    if Settings::SCALED_EXP_FORMULA
      exp /= 5
      levelAdjust = ((2 * level) + 10.0) / (pkmn.level + level + 10.0)
      levelAdjust **= 5
      levelAdjust = Math.sqrt(levelAdjust)
      exp *= levelAdjust
      exp = exp.floor
      exp += 1 if isPartic || hasExpShare
    else
      exp /= 7
    end
    # Foreign Pokémon gain more Exp
    isOutsider = (pkmn.owner.id != pbPlayer.id ||
                 (pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language))
    if isOutsider
      if pkmn.owner.language != 0 && pkmn.owner.language != pbPlayer.language
        exp = (exp * 1.7).floor
      else
        exp = (exp * 1.5).floor
      end
    end
    # Exp. Charm increases Exp gained
    exp = exp * 3 / 2 if $bag.has?(:EXPCHARM)
    # Modify Exp gain based on pkmn's held item
    i = Battle::ItemEffects.triggerExpGainModifier(pkmn.item, pkmn, exp)
    if i < 0
      i = Battle::ItemEffects.triggerExpGainModifier(@initialItems[0][idxParty], pkmn, exp)
    end
    exp = i if i >= 0
    # Boost Exp gained with high affection
    if Settings::AFFECTION_EFFECTS && @internalBattle && pkmn.affection_level >= 4 && !pkmn.mega?
      exp = exp * 6 / 5
      isOutsider = true   # To show the "boosted Exp" message
    end
    # Make sure Exp doesn't exceed the maximum
    expFinal = growth_rate.add_exp(pkmn.exp, exp)
    expGained = expFinal - pkmn.exp
    return if expGained <= 0
    # "Exp gained" message
    if showMessages
      if isOutsider
        pbDisplayPaused(_INTL("{1} got a boosted {2} Exp. Points!", pkmn.name, expGained))
      else
        pbDisplayPaused(_INTL("{1} got {2} Exp. Points!", pkmn.name, expGained))
      end
    end
    curLevel = pkmn.level
    newLevel = growth_rate.level_from_exp(expFinal)
    if newLevel < curLevel
      debugInfo = "Levels: #{curLevel}->#{newLevel} | Exp: #{pkmn.exp}->#{expFinal} | gain: #{expGained}"
      raise _INTL("{1}'s new level is less than its current level, which shouldn't happen.", pkmn.name) + "\n[#{debugInfo}]"
    end
    # Give Exp
    if pkmn.shadowPokemon?
      if pkmn.heartStage <= 3
        pkmn.exp += expGained
        $stats.total_exp_gained += expGained
      end
      return
    end
    $stats.total_exp_gained += expGained
    tempExp1 = pkmn.exp
    battler = pbFindBattler(idxParty)
    loop do   # For each level gained in turn...
      # EXP Bar animation
      levelMinExp = growth_rate.minimum_exp_for_level(curLevel)
      levelMaxExp = growth_rate.minimum_exp_for_level(curLevel + 1)
      tempExp2 = (levelMaxExp < expFinal) ? levelMaxExp : expFinal
      pkmn.exp = tempExp2
      @scene.pbEXPBar(battler, levelMinExp, levelMaxExp, tempExp1, tempExp2)
      tempExp1 = tempExp2
      curLevel += 1
      if curLevel > newLevel
        # Gained all the Exp now, end the animation
        pkmn.calc_stats
        battler&.pbUpdate(false)
        @scene.pbRefreshOne(battler.index) if battler
        break
      end
      # Levelled up
      pbCommonAnimation("LevelUp", battler) if battler
      oldTotalHP = pkmn.totalhp
      oldAttack  = pkmn.attack
      oldDefense = pkmn.defense
      oldSpAtk   = pkmn.spatk
      oldSpDef   = pkmn.spdef
      oldSpeed   = pkmn.speed
      battler.pokemon.changeHappiness("levelup") if battler&.pokemon
      pkmn.calc_stats
      battler&.pbUpdate(false)
      @scene.pbRefreshOne(battler.index) if battler
      pbDisplayPaused(_INTL("{1} grew to Lv. {2}!", pkmn.name, curLevel)) { pbSEPlay("Pkmn level up") }
      @scene.pbLevelUp(pkmn, battler, oldTotalHP, oldAttack, oldDefense,
                       oldSpAtk, oldSpDef, oldSpeed)
      # Learn all moves learned at this level
      moveList = pkmn.getMoveList
      moveList.each { |m| pbLearnMove(idxParty, m[1]) if m[0] == curLevel }
    end
  end
end

# Helper module for UI classes to access player battler stats during level sync
module LevelSyncHelper
  def self.battle_active?
    return false unless $game_battle
    return false unless $game_battle.instance_variable_defined?(:@level_sync_enabled)
    $game_battle.instance_variable_get(:@level_sync_enabled)
    echoln("Battle active: #{return $game_battle.instance_variable_get(:@level_sync_enabled)}") if $DEBUG
  end

   def self.synced?(pokemon)
    return false unless pokemon
    return false unless pokemon.ls_temp_level
    return pokemon.ls_temp_level < pokemon.level
  end

  def self.display_level(pokemon)
    return pokemon.ls_temp_level || pokemon.level
  end

  def self.synced_bp(move)
    return move.base_damage unless battle_active?
    caps = $game_battle.level_sync_caps rescue nil
    return move.base_damage unless caps && caps[:bp]
    [move.base_damage, caps[:bp]].min
  end

  def self.display_level(pokemon)
    return pokemon.level unless battle_active?
    pokemon.ls_temp_level || pokemon.level
  end
  def self.battle_will_sync?
    return false unless $game_battle
    return false unless $game_battle.instance_variable_defined?(:@level_sync_enabled)
    return $game_battle.instance_variable_get(:@level_sync_enabled)
    echoln("Battle will sync: #{return $game_battle.instance_variable_get(:@level_sync_enabled)}") if $DEBUG
  end
  # Get the current player's active Pokemon from battle
  def self.get_current_player_battler
    # Check if we're in a battle and if there's a scene with player battler data
    if $game_battle && $game_battle.scene && $game_battle.scene.respond_to?(:player_battler)
      return $game_battle.scene.player_battler
    end
    return nil
  end

  # Check if level sync is enabled for player in current battle
  def self.player_level_sync_enabled?
    battler = get_current_player_battler
    return battler && battler.respond_to?(:level_sync_enabled) && battler.level_sync_enabled
  end

  # Get player's level sync max values
  def self.player_level_sync_max_level
    battler = get_current_player_battler
    return battler&.level_sync_max_level || 100
  end

  def self.player_level_sync_max_hp
    battler = get_current_player_battler
    return battler&.totalhp || 0
  end

  # Check if a specific stat has been capped/modified by level sync
  def self.stat_was_capped?(pokemon, stat_type)
    return false unless pokemon && player_level_sync_enabled?
    
    battler = get_current_player_battler
    return false unless battler
    
    case stat_type
    when :level
      return pokemon.level >= battler.level_sync_max_level
    when :ev
      return pokemon.ev.any? { |ev| ev > battler.level_sync_max_ev }
    when :iv
      return pokemon.iv.any? { |iv| iv > battler.level_sync_max_iv }
    when :hp_base_stat
      return pokemon.base_stats[0] > battler.level_sync_max_hp_base_stat
    when :attack_base_stat
      return pokemon.base_stats[1] > battler.level_sync_max_attack_base_stat
    when :defense_base_stat
      return pokemon.base_stats[2] > battler.level_sync_max_defense_base_stat
    when :special_attack_base_stat
      return pokemon.base_stats[3] > battler.level_sync_max_special_attack_base_stat
    when :special_defense_base_stat
      return pokemon.base_stats[4] > battler.level_sync_max_special_defense_base_stat
    when :speed_base_stat
      return pokemon.base_stats[5] > battler.level_sync_max_speed_base_stat
    else
      return false
    end
  end
end

class Battle::StartAndEnd
  def pbEndOfBattle
    oldDecision = @decision
    @decision = 4 if @decision == 1 && wildBattle? && @caughtPokemon.length > 0
    case oldDecision
    ##### WIN #####
    when 1
      PBDebug.log("")
      PBDebug.log_header("===== Player won =====")
      PBDebug.log("")
      if trainerBattle?
        @scene.pbTrainerBattleSuccess
        case @opponent.length
        when 1
          pbDisplayPaused(_INTL("You defeated {1}!", @opponent[0].full_name))
        when 2
          pbDisplayPaused(_INTL("You defeated {1} and {2}!", @opponent[0].full_name,
                                @opponent[1].full_name))
        when 3
          pbDisplayPaused(_INTL("You defeated {1}, {2} and {3}!", @opponent[0].full_name,
                                @opponent[1].full_name, @opponent[2].full_name))
        end
        @opponent.each_with_index do |trainer, i|
          @scene.pbShowOpponent(i)
          msg = trainer.lose_text
          msg = "..." if !msg || msg.empty?
          pbDisplayPaused(msg.gsub(/\\[Pp][Nn]/, pbPlayer.name))
        end
        PBDebug.log("")
      end
      # Gain money from winning a trainer battle, and from Pay Day
      pbGainMoney if @decision != 4
      # Hide remaining trainer
      @scene.pbShowOpponent(@opponent.length) if trainerBattle? && @caughtPokemon.length > 0
    ##### LOSE, DRAW #####
    when 2, 5
      PBDebug.log("")
      PBDebug.log_header("===== Player lost =====") if @decision == 2
      PBDebug.log_header("===== Player drew with opponent =====") if @decision == 5
      PBDebug.log("")
      if @internalBattle
        pbDisplayPaused(_INTL("You have no more Pokémon that can fight!"))
        if trainerBattle?
          case @opponent.length
          when 1
            pbDisplayPaused(_INTL("You lost against {1}!", @opponent[0].full_name))
          when 2
            pbDisplayPaused(_INTL("You lost against {1} and {2}!",
                                  @opponent[0].full_name, @opponent[1].full_name))
          when 3
            pbDisplayPaused(_INTL("You lost against {1}, {2} and {3}!",
                                  @opponent[0].full_name, @opponent[1].full_name, @opponent[2].full_name))
          end
        end
        # Lose money from losing a battle
        pbLoseMoney
        pbDisplayPaused(_INTL("You blacked out!")) if !@canLose
      elsif @decision == 2   # Lost in a Battle Frontier battle
        if @opponent
          @opponent.each_with_index do |trainer, i|
            @scene.pbShowOpponent(i)
            msg = trainer.win_text
            msg = "..." if !msg || msg.empty?
            pbDisplayPaused(msg.gsub(/\\[Pp][Nn]/, pbPlayer.name))
          end
          PBDebug.log("")
        end
      end
    ##### CAUGHT WILD POKÉMON #####
    when 4
      PBDebug.log("")
      PBDebug.log_header("===== Pokémon caught =====")
      PBDebug.log("")
      @scene.pbWildBattleSuccess if !Settings::GAIN_EXP_FOR_CAPTURE
    end
    # Register captured Pokémon in the Pokédex, and store them
    pbRecordAndStoreCaughtPokemon
    # Collect Pay Day money in a wild battle that ended in a capture
    pbGainMoney if @decision == 4
    # Pass on Pokérus within the party
    if @internalBattle
      infected = []
      $player.party.each_with_index do |pkmn, i|
        infected.push(i) if pkmn.pokerusStage == 1
      end
      infected.each do |idxParty|
        strain = $player.party[idxParty].pokerusStrain
        if idxParty > 0 && $player.party[idxParty - 1].pokerusStage == 0 && rand(3) == 0   # 33%
          $player.party[idxParty - 1].givePokerus(strain)
        end
        if idxParty < $player.party.length - 1 && $player.party[idxParty + 1].pokerusStage == 0 && rand(3) == 0   # 33%
          $player.party[idxParty + 1].givePokerus(strain)
        end
      end
    end
    # Clean up battle stuff
    @scene.pbEndBattle(@decision)
    @level_sync_overlay_shown = false
    @battlers.each do |b|
      next if !b
      pbCancelChoice(b.index)   # Restore unused items to Bag
      Battle::AbilityEffects.triggerOnSwitchOut(b.ability, b, true) if b.abilityActive?
    end
    echoln("pbEndBattle running") if $DEBUG
    pbParty(0).each_with_index do |pkmn, i|
      next if !pkmn
      old_ratio = pkmn.hp.to_f / pkmn.totalhp
      echoln("Clearing sync for #{pkmn.name}") if $DEBUG
      pkmn.pokemon.clear_level_sync
      pkmn.calc_stats
      @peer.pbOnLeavingBattle(self, pkmn, @usedInBattle[0][i], true)   # Reset form
      pkmn.item = @initialItems[0][i]
      pkmn.hp = (pkmn.totalhp * old_ratio).round
      pkmn.hp = 1 if pkmn.hp < 1 && pkmn.able?
  
    end
    return @decision
  end
end
