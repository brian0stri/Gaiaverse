module Settings
  #-----------------------------------------------------------------------------
  # Expedition Rank
  #-----------------------------------------------------------------------------

  NUM_EXPEDITIONRANK_BOOST_ATK = NUM_BADGES_BOOST_ATTACK  
  NUM_EXPEDITIONRANK_BOOST_DEFENSE = NUM_BADGES_BOOST_DEFENSE
  NUM_EXPEDITIONRANK_BOOST_SPATK = NUM_BADGES_BOOST_SPATK
  NUM_EXPEDITIONRANK_BOOST_SPDEF = NUM_BADGES_BOOST_SPDEF
  NUM_EXPEDITIONRANK_BOOST_SPEED = NUM_BADGES_BOOST_SPEED

  FIELD_MOVES_REQUIRE_EXPEDITION_RANK = true
  EXPEDITION_RANK_CAP = 10
  EXPEDITION_RANK_FOR_HEADBUTT = 0
  EXPEDITION_RANK_FOR_CUT = 1
  EXPEDITION_RANK_FOR_ROCKSMASH = 2
  EXPEDITION_RANK_FOR_SURF = 3
  EXPEDITION_RANK_FOR_FLY = 5
  EXPEDITION_RANK_FOR_DIVE = 4
  EXPEDITION_RANK_FOR_STRENGTH = 5
  EXPEDITION_RANK_FOR_WATERFALL = 7
  EXPEDITION_RANK_FOR_FLASH = 1

  EXPEDITION_POINT_VALUES = { :CUT => 1, :DIG => 1, :HEADBUTT => 1, :ROCKSMASH => 1, :SURF => 0, :FLY => 0, :DIVE => 2, :STRENGTH => 2, :WATERFALL => 2, :FLASH => 1, :SWEETSCENT => 1, :TELEPORT => 1, :WHIRLPOOL => 2, :ROCKCLIMB => 2 }
  EXPEDITION_POINTS_PER_RANK = [0, 100, 300, 600, 1000, 1500, 2100, 2800, 3600, 4500, 7000]
  MAX_EXPEDITION_POINTS = 50000

  SWITCH_START_COLLECTING_EXPEDITION_POINTS = 50
  
  def self.calculate_expedition_rank_boosts(region)
    rank = $player.get_current_expedition_rank(region)
    atk_boost = rank >= NUM_EXPEDITIONRANK_BOOST_ATK+1 ? 1 : 0
    def_boost = rank >= NUM_EXPEDITIONRANK_BOOST_DEFENSE+1 ? 1 : 0
    spatk_boost = rank >= NUM_EXPEDITIONRANK_BOOST_SPATK+1 ? 1 : 0
    spdef_boost = rank >= NUM_EXPEDITIONRANK_BOOST_SPDEF+1 ? 1 : 0
    speed_boost = rank >= NUM_EXPEDITIONRANK_BOOST_SPEED+1 ? 1 : 0
    return atk_boost, def_boost, spatk_boost, spdef_boost, speed_boost
  end
end

class Battle

  alias GV_pbGainMoney pbGainMoney
  def pbGainMoney(amount)
    if $game_switches[Settings::SWITCH_START_COLLECTING_EXPEDITION_POINTS]
      region = $player.get_current_region()
      multiplier = [8, 16, 24, 36, 48, 64, 80, 100, 120, 148, 164]
      idxMultiplier = [$player.get_current_expedition_rank(region), multiplier.length - 1].min
      tmoney *= (1.0 + (idxMultiplier * 0.02))
      pointsEarned = (amount * multiplier[idxMultiplier] / 100.0).floor
      $player.pbAddExpeditionPoints(region, pointsEarned)
    else 
      idxMultiplier *= 1
      tmoney *= (amount * idxMultiplier)
    end
    GV_pbGainMoney(amount)
  end
  
  alias GV_pbLoseMoney pbLoseMoney
  def pbLoseMoney(amount)
    if $game_switches[Settings::SWITCH_START_COLLECTING_EXPEDITION_POINTS]
      region = $player.get_current_region()
      multiplier = [8, 16, 24, 36, 48, 64, 80, 100, 120, 148, 164]
      idxMultiplier = [pbPlayer.get_current_expedition_rank(region), multiplier.length - 1].min
    end
    GV_pbLoseMoney(amount)
  end
end

class Battle::Battler

  alias GV_pbSpeed pbSpeed
  def pbSpeed
    speed = GV_pbSpeed()
    if $game_switches[Settings::SWITCH_START_COLLECTING_EXPEDITION_POINTS]
      region = @battle.pbPlayer.get_current_region()
      _, _, _, _, speed_boost = Settings.calculate_expedition_rank_boosts(region)
      speedMult *= (1.1 + (@battle.pbPlayer.get_current_expedition_rank(region) * 0.02))
    end
    return speed
  end

  alias GV_pbObedienceCheck? pbObedienceCheck?
    def pbObedienceCheck?(pokemon)
      if $game_switches[Settings::SWITCH_START_COLLECTING_EXPEDITION_POINTS]
        badge_level = 10 * (@battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()))
        badge_level = GameData::GrowthRate.max_level if @battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()) >= 10
      end
      return GV_pbObedienceCheck?(pokemon)
    end

end

class Battle::Move

  alias  GV_pbCalcDamageMultipliers pbCalcDamageMultipliers
  def pbCalcDamageMultipliers(user, target, move)
    if @battle.internalBattle
      if user.pbOwnedByPlayer?
        if physicalMove? && @battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_ATTACK
          multipliers[:attack_multiplier] *= 1.1
        elsif specialMove? && @battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_SPATK
          multipliers[:attack_multiplier] *= 1.1
        end
      end
      if target.pbOwnedByPlayer?
        if physicalMove? && @battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_DEFENSE
          multipliers[:defense_multiplier] *= 1.1
        elsif specialMove? && @battle.pbPlayer.get_current_expedition_rank(@battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_SPDEF
          multipliers[:defense_multiplier] *= 1.1
        end
      end
    end
  end

end

class Battle::AI::AIMove

  alias GV_rough_damage rough_damage
    def rough_damage(user, target)
      damage = GV_rough_damage(user, target)
      if $game_switches[Settings::SWITCH_START_COLLECTING_EXPEDITION_POINTS]
        if physicalMove?(calc_type) && @ai.battle.pbPlayer.get_current_expedition_rank(@ai.battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_DEFENSE
          multipliers[:defense_multiplier] *= 1.1
        elsif specialMove?(calc_type) && @ai.battle.pbPlayer.get_current_expedition_rank(@ai.battle.pbPlayer.get_current_region()) >= Settings::NUM_EXPEDITIONRANK_BOOST_SPDEF
          multipliers[:defense_multiplier] *= 1.1
        end
      end
      return damage
    end
end

module RecordedBattleModule

    alias GV_pbGetTrainerInfo pbGetTrainerInfo
    def pbGetTrainerInfo(trainer)
      if trainer.is_a?(Array)
        ret = []
        trainer.each do |tr|
          if tr.is_a?(Player)
            ret.push([tr.trainer_type, tr.name.clone, tr.id, tr.get_current_expedition_rank(tr.get_current_region()).clone])
          else   # NPCTrainer
            ret.push([tr.trainer_type, tr.name.clone, tr.id, tr.lose_text || "...", tr.win_text || "..."])
          end
        end
        return ret
      elsif trainer.is_a?(Player)
        return [[trainer.trainer_type, trainer.name.clone, trainer.id, trainer.get_current_expedition_rank(trainer.get_current_region()).clone]]
      else
        return [[trainer.trainer_type, trainer.name.clone, trainer.id, trainer.lose_text || "...", trainer.win_text || "..."]]
      end
   end
end

  def pbCheckHiddenMoveExpeditionRank(rank = -1, showmsg = true)
    return true if rank < 0   # No rank requirement
    return true if $DEBUG
    if (Settings::FIELD_MOVES_REQUIRE_EXPEDITION_RANK) ? $player.get_current_expedition_rank($player.get_current_region()) >= rank : $player.ranks[rank]
      return true
    end
    pbMessage(_INTL("Sorry, a higher Expedition Rank is required to use this move.")) if showmsg
    return false
  end

  alias GV_pbCut pbCut
  def pbCut
    move = :CUT
    movefinder = $player.get_pokemon_with_move(move)
    if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_CUT, false) || (!$DEBUG && !movefinder)
      pbMessage(_INTL("This tree looks like it can be cut down."))
      return false
    end
    if pbConfirmMessage(_INTL("This tree looks like it can be cut down!\nWould you like to cut it?"))
      $stats.cut_count += 1
      speciesname = (movefinder) ? movefinder.name : $player.name
      pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
      pbHiddenMoveAnimation(movefinder)
      $player.pbHMPointBonus(move)
      return true
    end
  return false
  end

  HiddenMoveHandlers::CanUseMove.add(:CUT, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_CUT, showmsg)
  facingEvent = $game_player.pbFacingEvent
  if !facingEvent || !facingEvent.name[/cuttree/i]
    pbMessage(_INTL("You can't use that here.")) if showmsg
    next false
  end
  next true
  })

  HiddenMoveHandlers::UseMove.add(:CUT, proc { |move, pokemon|
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  $stats.cut_count += 1
  facingEvent = $game_player.pbFacingEvent
  pbSmashEvent(facingEvent) if facingEvent
  $player.pbHMPointBonus(move)
  next true
  })

  alias GV_pbDive pbDive
  def pbDive
    GV_pbDive
  map_metadata = $game_map.metadata
  return false if !map_metadata || !map_metadata.dive_map_id
  move = :DIVE
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_DIVE, false) || (!$DEBUG && !movefinder)
    pbMessage(_INTL("The sea is deep here. A Pokémon may be able to go underwater."))
    return false
  end
  if pbConfirmMessage(_INTL("The sea is deep here. Would you like to use Dive?"))
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbHiddenMoveAnimation(movefinder)
    pbFadeOutIn do
      $game_temp.player_new_map_id    = map_metadata.dive_map_id
      $game_temp.player_new_x         = $game_player.x
      $game_temp.player_new_y         = $game_player.y
      $game_temp.player_new_direction = $game_player.direction
      $PokemonGlobal.surfing = false
      $PokemonGlobal.diving  = true
      $stats.dive_count += 1
      $player.pbHMPointBonus(move)
      pbUpdateVehicle
      $scene.transfer_player(false)
      $game_map.autoplay
      $game_map.refresh
    end
    return true
  end
  return false
end

alias GV_pbSurfacing pbSurfacing
def pbSurfacing
  GV_pbSurfacing
  return if !$PokemonGlobal.diving
  surface_map_id = nil
  GameData::MapMetadata.each do |map_data|
    next if !map_data.dive_map_id || map_data.dive_map_id != $game_map.map_id
    surface_map_id = map_data.id
    break
  end
  return if !surface_map_id
  move = :DIVE
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_DIVE, false) || (!$DEBUG && !movefinder)
    pbMessage(_INTL("Light is filtering down from above. A Pokémon may be able to surface here."))
    return false
  end
  if pbConfirmMessage(_INTL("Light is filtering down from above. Would you like to use Dive?"))
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbHiddenMoveAnimation(movefinder)
    pbFadeOutIn do
      $game_temp.player_new_map_id    = surface_map_id
      $game_temp.player_new_x         = $game_player.x
      $game_temp.player_new_y         = $game_player.y
      $game_temp.player_new_direction = $game_player.direction
      $PokemonGlobal.surfing = true
      $PokemonGlobal.diving  = false
      $player.pbHMPointBonus(move)
      pbUpdateVehicle
      $scene.transfer_player(false)
      surfbgm = GameData::Metadata.get.surf_BGM
      (surfbgm) ? pbBGMPlay(surfbgm) : $game_map.autoplayAsCue
      $game_map.refresh
    end
    return true
  end
  return false
end

HiddenMoveHandlers::CanUseMove.add(:FLASH, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_FLASH, showmsg)
  if !$game_map.metadata&.dark_map
    pbMessage(_INTL("You can't use that here.")) if showmsg
    next false
  end
  if $PokemonGlobal.flashUsed
    pbMessage(_INTL("Flash is already being used.")) if showmsg
    next false
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:FLASH, proc { |move, pokemon|
  darkness = $game_temp.darkness_sprite
  next false if !darkness || darkness.disposed?
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  $PokemonGlobal.flashUsed = true
  $stats.flash_count += 1
  $player.pbHMPointBonus(move)
  duration = 0.7
  pbWait(duration) do |delta_t|
    darkness.radius = lerp(darkness.radiusMin, darkness.radiusMax, duration, delta_t)
  end
  darkness.radius = darkness.radiusMax
  next true
})

HiddenMoveHandlers::UseMove.add(:DIG, proc { |move, pokemon|
  escape = ($PokemonGlobal.escapePoint rescue nil)
  if escape
    if !pbHiddenMoveAnimation(pokemon)
      pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
      $player.pbHMPointBonus(move)
    end
    pbFadeOutIn do
      $game_temp.player_new_map_id    = escape[0]
      $game_temp.player_new_x         = escape[1]
      $game_temp.player_new_y         = escape[2]
      $game_temp.player_new_direction = escape[3]
      pbDismountBike
      $scene.transfer_player
      $game_map.autoplay
      $game_map.refresh
    end
    pbEraseEscapePoint
    next true
  end
  next false
})

alias GV_pbCanFly? pbCanFly?
def pbCanFly?(pkmn = nil, show_messages = false)
  GV_pbCanFly?(pkmn, show_messages)
  return false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_FLY, show_messages)
  return false if !$DEBUG && !pkmn && !$player.get_pokemon_with_move(:FLY)
  if !$game_player.can_map_transfer_with_follower?
    pbMessage(_INTL("It can't be used when you have someone with you.")) if show_messages
    return false
  end
  if !$game_map.metadata&.outdoor_map
    pbMessage(_INTL("You can't use that here.")) if show_messages
    return false
  end
  return true
end

alias GV_pbFlyToNewLocation pbFlyToNewLocation
def pbFlyToNewLocation(pkmn = nil, move = :FLY)
  GV_pbFlyToNewLocation(pkmn, move)
  return false if $game_temp.fly_destination.nil?
  pkmn = $player.get_pokemon_with_move(move) if !pkmn
  if !$DEBUG && !pkmn
    $game_temp.fly_destination = nil
    yield if block_given?
    return false
  end
  if !pkmn || !pbHiddenMoveAnimation(pkmn)
    name = pkmn&.name || $player.name
    pbMessage(_INTL("{1} used {2}!", name, GameData::Move.get(move).name))
  end
  $stats.fly_count += 1
  pbFadeOutIn do
    pbSEPlay("Fly")
    $game_temp.player_new_map_id    = $game_temp.fly_destination[0]
    $game_temp.player_new_x         = $game_temp.fly_destination[1]
    $game_temp.player_new_y         = $game_temp.fly_destination[2]
    $game_temp.player_new_direction = 2
    $player.pbHMPointBonus(move)
    pbDismountBike
    $scene.transfer_player
    $game_map.autoplay
    $game_map.refresh
    yield if block_given?
    pbWait(0.25)
  end
  pbEraseEscapePoint
  $game_temp.fly_destination = nil
  return true
end

alias GV_pbHeadbuttEffect pbHeadbuttEffect
def pbHeadbuttEffect(event = nil)
  GV_pbHeadbuttEffect(event)
  pbSEPlay("Headbutt")
  pbWait(1.0)
  $player.pbHMPointBonus(:HEADBUTT)
  event = $game_player.pbFacingEvent(true) if !event
  a = (event.x + (event.x / 24).floor + 1) * (event.y + (event.y / 24).floor + 1)
  a = (a * 2 / 5) % 10   # Even 2x as likely as odd, 0 is 1.5x as likely as odd
  b = $player.public_ID % 10   # Practically equal odds of each value
  chance = 1                 # ~50%
  if a == b                    # 10%
    chance = 8
  elsif a > b && (a - b).abs < 5   # ~30.3%
    chance = 5
  elsif a < b && (a - b).abs > 5   # ~9.7%
    chance = 5
  end
  if rand(10) >= chance
    pbMessage(_INTL("Nope. Nothing..."))
  else
    enctype = (chance == 1) ? :HeadbuttLow : :HeadbuttHigh
    if pbEncounter(enctype)
      $stats.headbutt_battles += 1
    else
      pbMessage(_INTL("Nope. Nothing..."))
    end
  end
end

alias GV_pbRockSmash pbRockSmash
def pbRockSmash
  GV_pbRockSmash
  move = :ROCKSMASH
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_ROCKSMASH, false) || (!$DEBUG && !movefinder)
    pbMessage(_INTL("It's a rugged rock, but a Pokémon may be able to smash it."))
    return false
  end
  if pbConfirmMessage(_INTL("This rock seems breakable with a hidden move.\nWould you like to use Rock Smash?"))
    $stats.rock_smash_count += 1
    $player.pbHMPointBonus(move)
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbHiddenMoveAnimation(movefinder)
    $player.pbHMPointBonus(move)
    return true
  end
  return false
end

HiddenMoveHandlers::CanUseMove.add(:ROCKSMASH, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_ROCKSMASH, showmsg)
  facingEvent = $game_player.pbFacingEvent
  if !facingEvent || !facingEvent.name[/smashrock/i]
    pbMessage(_INTL("You can't use that here.")) if showmsg
    next false
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:ROCKSMASH, proc { |move, pokemon|
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_ROCKSMASH, false)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  $stats.rock_smash_count += 1
  $player.pbHMPointBonus(move)
  facingEvent = $game_player.pbFacingEvent
  if facingEvent
    pbSmashEvent(facingEvent)
    pbRockSmashRandomEncounter
  end
  next true
})

alias GV_pbStrength pbStrength
def pbStrength
  GV_pbStrength
  if $PokemonMap.strengthUsed
    pbMessage(_INTL("Strength made it possible to move boulders around."))
    return false
  end
  move = :STRENGTH
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_STRENGTH, false) || (!$DEBUG && !movefinder)
    pbMessage(_INTL("It's a big boulder, but a Pokémon may be able to push it aside."))
    return false
  end
  pbMessage(_INTL("It's a big boulder, but you may be able to push it aside with a hidden move.") + "\1")
  if pbConfirmMessage(_INTL("Would you like to use Strength?"))
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbHiddenMoveAnimation(movefinder)
    $player.pbHMPointBonus(move)
    pbMessage(_INTL("Strength made it possible to move boulders around!"))
    $PokemonMap.strengthUsed = true
    return true
  end
  return false
end

HiddenMoveHandlers::CanUseMove.add(:STRENGTH, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_STRENGTH, showmsg)
  if $PokemonMap.strengthUsed
    pbMessage(_INTL("Strength is already being used.")) if showmsg
    next false
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:STRENGTH, proc { |move, pokemon|
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name) + "\1")
  end
  pbMessage(_INTL("Strength made it possible to move boulders around!"))
  $PokemonMap.strengthUsed = true
  $player.pbHMPointBonus(move)
  next true
})

alias GV_pbSurf pbSurf
def pbSurf
  GV_pbSurf
  return false if !$game_player.can_ride_vehicle_with_follower?
  move = :SURF
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_SURF, false) || (!$DEBUG && !movefinder)
    return false
  end
  if pbConfirmMessage(_INTL("The water is a deep blue color... Would you like to use Surf on it?"))
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbCancelVehicles
    $player.pbHMPointBonus(move)
    pbHiddenMoveAnimation(movefinder)
    surfbgm = GameData::Metadata.get.surf_BGM
    pbCueBGM(surfbgm, 0.5) if surfbgm
    pbStartSurfing
    return true
  end
  return false
end

HiddenMoveHandlers::CanUseMove.add(:SURF, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_SURF, showmsg)
  if $PokemonGlobal.surfing
    pbMessage(_INTL("You're already surfing.")) if showmsg
    next false
  end
  if !$game_player.can_ride_vehicle_with_follower?
    pbMessage(_INTL("It can't be used when you have someone with you.")) if showmsg
    next false
  end
  if $game_map.metadata&.always_bicycle
    pbMessage(_INTL("Let's enjoy cycling!")) if showmsg
    next false
  end
  if !$game_player.pbFacingTerrainTag.can_surf_freely ||
     !$game_map.passable?($game_player.x, $game_player.y, $game_player.direction, $game_player)
    pbMessage(_INTL("No surfing here!")) if showmsg
    next false
  end
  next true
})

HiddenMoveHandlers::UseMove.add(:SURF, proc { |move, pokemon|
  $game_temp.in_menu = false
  pbCancelVehicles
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  surfbgm = GameData::Metadata.get.surf_BGM
  pbCueBGM(surfbgm, 0.5) if surfbgm
  pbStartSurfing
  $player.pbHMPointBonus(move)
  next true
})

HiddenMoveHandlers::UseMove.add(:SWEETSCENT, proc { |move, pokemon|
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  pbSweetScent
  $player.pbHMPointBonus(move)
  next true
})

HiddenMoveHandlers::UseMove.add(:TELEPORT, proc { |move, pokemon|
  healing = $PokemonGlobal.healingSpot
  healing = GameData::PlayerMetadata.get($player.character_ID)&.home if !healing
  healing = GameData::Metadata.get.home if !healing   # Home
  next false if !healing
  if !pbHiddenMoveAnimation(pokemon)
    pbMessage(_INTL("{1} used {2}!", pokemon.name, GameData::Move.get(move).name))
  end
  pbFadeOutIn do
    $game_temp.player_new_map_id    = healing[0]
    $game_temp.player_new_x         = healing[1]
    $game_temp.player_new_y         = healing[2]
    $game_temp.player_new_direction = 2
    pbDismountBike
    $scene.transfer_player
    $game_map.autoplay
    $game_map.refresh
  end
  pbEraseEscapePoint
  $player.pbHMPointBonus(move)
  next true
})

alias GV_pbAscendWaterfall pbAscendWaterfall
def pbAscendWaterfall
  GV_pbAscendWaterfall
  return if $game_player.direction != 8   # Can't ascend if not facing up
  terrain = $game_player.pbFacingTerrainTag
  return if !terrain.waterfall && !terrain.waterfall_crest
  $stats.waterfall_count += 1
  $PokemonGlobal.ascending_waterfall = true
  $game_player.through = true
  $player.pbHMPointBonus(:WATERFALL)
end

alias GV_pbTraverseWaterfall pbTraverseWaterfall
def pbTraverseWaterfall
  GV_pbTraverseWaterfall
  if $game_player.direction == 2   # Facing down; descending
    terrain = $game_player.pbTerrainTag
    if ($DEBUG && Input.press?(Input::CTRL)) ||
       (!terrain.waterfall && !terrain.waterfall_crest)
      $PokemonGlobal.descending_waterfall = false
      $game_player.through = false
      return
    end
    $stats.waterfalls_descended += 1 if !$PokemonGlobal.descending_waterfall
    $player.pbHMPointBonus(:WATERFALL)
    $PokemonGlobal.descending_waterfall = true
    $game_player.through = true
  elsif $PokemonGlobal.ascending_waterfall
    terrain = $game_player.pbTerrainTag
    if ($DEBUG && Input.press?(Input::CTRL)) ||
       (!terrain.waterfall && !terrain.waterfall_crest)
      $PokemonGlobal.ascending_waterfall = false
      $game_player.through = false
      return
    end
    $PokemonGlobal.ascending_waterfall = true
    $game_player.through = true
  end
end

alias GV_pbWaterfall pbWaterfall
def pbWaterfall
  GV_pbWaterfall
  move = :WATERFALL
  movefinder = $player.get_pokemon_with_move(move)
  if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_WATERFALL, false) || (!$DEBUG && !movefinder)
    pbMessage(_INTL("A wall of water is crashing down with a mighty roar."))
    return false
  end
  if pbConfirmMessage(_INTL("It's a large waterfall. Would you like to use Waterfall?"))
    speciesname = (movefinder) ? movefinder.name : $player.name
    pbMessage(_INTL("{1} used {2}!", speciesname, GameData::Move.get(move).name))
    pbHiddenMoveAnimation(movefinder)
    pbAscendWaterfall
    return true
  end
  return false
end

HiddenMoveHandlers::CanUseMove.add(:WATERFALL, proc { |move, pkmn, showmsg|
  next false if !pbCheckHiddenMoveExpeditionRank(Settings::EXPEDITION_RANK_FOR_WATERFALL, showmsg)
  if !$game_player.pbFacingTerrainTag.waterfall
    pbMessage(_INTL("You can't use that here.")) if showmsg
    next false
  end
  next true
})

