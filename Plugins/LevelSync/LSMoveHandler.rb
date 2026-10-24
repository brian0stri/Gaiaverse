class Battle::Move
  attr_accessor :ls_temp_base_damage
  alias ls_pbBaseDamage pbBaseDamage

  def pbBaseDamage(baseDmg, user, target)
    damage = ls_pbBaseDamage(baseDmg, user, target)

    return damage unless @battle&.level_sync_enabled
    caps = @battle.level_sync_caps
    return damage unless caps && caps[:bp]

    capped = [damage, caps[:bp]].min
    @ls_temp_base_damage = capped
   echoln("Capping BP #{damage} -> #{capped}")
    echoln("LS hook triggered")
    echoln("Sync enabled? #{@battle&.level_sync_enabled}")
    echoln("Caps: #{@battle&.level_sync_caps.inspect}")
    #echoln("=== DAMAGE DEBUG ===")
    #echoln("User species: #{user.pokemon.species}")
    #echoln("User level: #{user.level}")
    #echoln("User SpAtk (used): #{user.spatk}")
    #echoln("Target species: #{target.pokemon.species}")
    #echoln("Target SpDef (used): #{target.spdef}")
    #echoln("Target HP total: #{target.totalhp}")
    #echoln("=====================")
    return capped
  end

   def display_damage_with_sync(pokemon)
    echoln("Move class loaded") if $DEBUG
    damage = display_damage(pokemon)

    return damage unless pokemon.synced?
    return damage unless $battle&.level_sync_caps&.dig(:bp)
    return damage if damage <= 1   # status or variable

    cap = $battle.level_sync_caps[:bp]
    return [damage, cap].min
  end

end