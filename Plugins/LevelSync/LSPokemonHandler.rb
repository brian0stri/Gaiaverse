class Pokemon
  attr_accessor :ls_temp_base_stats
  attr_accessor :ls_temp_delta
  attr_accessor :ls_temp_level
  attr_accessor :ls_temp_iv
  attr_accessor :ls_temp_ev
  attr_accessor :ls_bp_cap
  attr_accessor :ls_sync_applied
  attr_accessor :sync_applied

  alias ls_baseStats baseStats

  def synced?
    return @ls_sync_applied
  end

  def baseStats
    return @ls_temp_base_stats if @ls_temp_base_stats
    return ls_baseStats
  end

  def get_base_stats(species)
   return GameData::Species.get(species).base_stats
  end

  def determine_mega_delta
    species_data = GameData::Species.get(@species)
    return {} if species_data.form == 0

    base_species  = GameData::Species.get(species_data.species)
    base_stats    = base_species.base_stats
    current_stats = species_data.base_stats

    delta = {}
    current_stats.each do |stat, value|
      delta[stat] = value - base_stats[stat]
    end
    delta
  end

  def battle_level
    return @ls_temp_level || @level
  end

  alias ls_calc_stats calc_stats
  def calc_stats
    ls_calc_stats
    @ls_temp_delta = determine_mega_delta

    base_stats =
      if @ls_temp_base_stats
        @ls_temp_base_stats
      else
        GameData::Species.get(@species).base_stats
      end
    old_eV = @ev.clone
    this_level = @ls_temp_level || self.level
    this_IV    = @ls_temp_iv || self.calcIV
    this_EV    = @ls_temp_ev || old_eV
    @ev = this_EV

    nature_mod = {}
    GameData::Stat.each_main { |s| nature_mod[s.id] = 100 }

    this_nature = self.nature_for_stats
    if this_nature
      this_nature.stat_changes.each { |change| nature_mod[change[0]] += change[1] }
    end

    stats = {}
    GameData::Stat.each_main do |s|
      if s.id == :HP
        echoln("THIS_LEVEL USED IN FORMULA = #{this_level}") if $DEBUG
        stats[s.id] = calcHP(base_stats[s.id], this_level, this_IV[s.id], @ev[s.id])
      else
        stats[s.id] = calcStat(base_stats[s.id], this_level, this_IV[s.id], @ev[s.id], nature_mod[s.id])
      end
    end

    echoln("calc_stats sees @ls_temp_level = #{@ls_temp_level.inspect}") if $DEBUG

    old_totalhp = @totalhp
    old_hp      = @hp

    new_totalhp = stats[:HP]

    hp_ratio = old_totalhp > 0 ? old_hp.to_f / old_totalhp : 1.0

    @totalhp = new_totalhp
    @hp = (new_totalhp * hp_ratio).round

    # Clamp safely
    @hp = 1 if @hp < 1
    @hp = @totalhp if @hp > @totalhp

    @totalhp = stats[:HP]
    @attack  = stats[:ATTACK]
    @defense = stats[:DEFENSE]
    @spatk   = stats[:SPECIAL_ATTACK]
    @spdef   = stats[:SPECIAL_DEFENSE]
    @speed   = stats[:SPEED]
    echoln("Calculated stats for #{self.name}: Level #{this_level}, HP #{hp}/#{totalhp}, Atk #{attack}, Def #{defense}, SpAtk #{spatk}, SpDef #{spdef}, Spe #{speed}") if $DEBUG
  end


 alias ls_original_level level

  def apply_level_sync(caps, level_sync_base_stats_enabled)
   return unless caps
   return if @ls_sync_applied

   # --- Level ---
   if caps[:level]
   synced_level = [self.level, caps[:level]].min
   self.ls_temp_level = synced_level
   end

   # --- EV ---
   if caps[:ev]
     self.ev.each_key do |stat|
      self.ev[stat] = [self.ev[stat], caps[:ev]].min
     end
   end

   # --- IV ---
   if caps[:iv]
    self.iv.each_key do |stat|
      self.iv[stat] = [self.iv[stat], caps[:iv]].min
    end
   end

   # --- Base Stats ---
   if level_sync_base_stats_enabled
    self.ls_temp_base_stats ||= GameData::Species.get(self.species).base_stats.clone

    self.ls_temp_base_stats.each_key do |stat|
      delta = self.ls_temp_delta&.dig(stat) || 0

      max_stat = case stat
      when :HP
        (caps[:hp] || 255) + delta
      when :ATTACK
        (caps[:atk] || 255) + delta
      when :DEFENSE
        (caps[:def] || 255) + delta
      when :SPECIAL_ATTACK
        (caps[:spa] || 255) + delta
      when :SPECIAL_DEFENSE
        (caps[:spd] || 255) + delta
      when :SPEED
        (caps[:spe] || 255) + delta
      else
        255
        end

        self.ls_temp_base_stats[stat] =
        [self.ls_temp_base_stats[stat], max_stat].min
        end
      end

   if caps[:bp]
     self.ls_bp_cap = caps[:bp]
    end
    # --- Recalculate ---
    self.calc_stats

    @hp      = self.hp
    @totalhp = self.totalhp
    @attack  = self.attack
    @defense = self.defense
    @spatk   = self.spatk
    @spdef   = self.spdef
    @speed   = self.speed
    @ls_sync_applied = true
      echoln("apply_level_sync on #{self.name} (#{object_id}) setting temp level to #{synced_level}") if $DEBUG
  end

  def clear_level_sync
  echoln("clear_level_sync called for #{self.name}") if $DEBUG

  @ls_temp_level = nil
  @ls_temp_base_stats = nil
  @ls_temp_iv = nil
  @ls_temp_ev = nil
  @ls_original_level = nil
  @ls_sync_applied = false


  calc_stats
  echoln("Cleared level sync for #{self.name} (#{object_id}), restored level to #{self.level}") if $DEBUG
end

def display_level
  @ls_temp_level || @level
end

end