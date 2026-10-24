SaveData.register(:LS_system) do
  load_in_bootup
  ensure_class :LSSettings
  save_value { $LSSettings }
  load_value { |value| $LSSettings = value }
  new_game_value { LSSettings.new }
end