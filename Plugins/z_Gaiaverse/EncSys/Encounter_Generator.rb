class EncounterGenerator
attr_reader :habitat, :region, :rod, :time
attr_accessor :spawn_data
attr_accessor :fallbacks
attr_accessor :spawn_cache
attr_accessor :habitat_fallbacks

  def initialize
    @spawn_data = JSON.parse(File.read('biome_pools.json'), symbolize_names: true)
    @habitat_fallbacks = PYTHON.parse(File.read('models.py'))[:HABITAT_FALLBACKS]
  end

  def get_spawn_pool(region, habitat, tier)

  pool = @spawn_data.dig(region, habitat, tier)

  while pool.nil? && @habitat_fallbacks[habitat]
    habitat = @habitat_fallbacks[habitat]
    pool = @spawn_data.dig(region, habitat, tier)
  end

  return pool
end

def effective_tickets(entry, context)

  tickets = entry["tickets"]

  tickets *= entry["region_mult"][context[:region]]
  tickets *= entry["rod_mult"][context[:rod]]
  tickets *= entry["time_mult"][context[:time]]

  return tickets
end

def roll_spawn(region, habitat, rod, time)
  r = rand(table["total"])

  i = table["weights"].bsearch_index{ |w| w > r }

  table["species"][i]
end

def get_spawn_table(region, habitat, rod, time)

  key = context_key(region, habitat, rod, time)

  return @spawn_cache[key] if @spawn_cache[key]

  base_pool = @spawn_data.dig(region, habitat)

  species = []
  weights = []
  total = 0

  base_pool["species"].each_with_index do |entry, i|

    name, form = entry

    base_weight = base_pool["weights"][i]
    prev = i > 0 ? base_pool["weights"][i-1] : 0
    tickets = base_weight - prev

    tickets *= rod_multiplier(rod)
    tickets *= time_multiplier(time)

    next if tickets <= 0

    total += tickets
    species << entry
    weights << total
  end

  table = {
    "species" => species,
    "weights" => weights,
    "total" => total
  }

  @spawn_cache[key] = table

  table
  end
end