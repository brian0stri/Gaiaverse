  class DustCloud
  end

#     def rollItemDrop()
#       region = $game_player.get_current_region()
#       drop = nil
#       randNum = rand(200)
#       if randNum < 90
#         #start encounter
#         return nil
#       elsif randNum < 120
#         return EVOLUTION_STONES.to_a.sample
#       elsif randNum < 140
#         return ARCEUSPLATES.to_a.sample
#       elsif randNum < 160
#         return GEMDROPS.to_a.sample
#       elsif randNum < 181
#         case region
#         when 0
#         return ALPHAFOSSILS.to_a.sample
#         when 1
#         return BETAFOSSILS.to_a.sample
#         when 2
#         return GAMMAFOSSILS.to_a.sample
#         when 3
#         return DELTAFOSSILS.to_a.sample
#         else 
#           return nil
#         end
#       elsif randNum < 186
#         return HELD_DROP.to_a.sample 
#       elsif randNum < 188 && RARE_DROPS.any?
#         drop = RARE_DROPS.to_a.sample
#         if $game_player.collectedRedOrb && drop == REDORB
#           RARE_DROPS.delete(REDORB)
#           return nil
#         elsif $game_player.collectedBlueOrb && drop == BLUEORB
#           RARE_DROPS.delete(BLUEORB)
#           return nil
#         elsif $game_player.collectedLustrousOrb && drop == LUSTROUSORB
#           RARE_DROPS.delete(LUSTROUSORB)
#           return nil
#         elsif $game_player.collectedGriseousOrb && drop == GRISEOUSORB
#           RARE_DROPS.delete(GRISEOUSORB)
#           return nil
#         elsif $game_player.collectedAdamantOrb && drop == ADAMANTORB
#           RARE_DROPS.delete(ADAMANTORB)
#           return nil
#         elsif region != 0 && (drop == AUSPICIOUSARMOR || drop == MASTERPIECETEACUP)
#             return nil
#         elsif region != 1 && drop == CHIPPEDPOT
#           return nil
#         elsif region != 3 && drop == MALICIOUSARMOR
#           return nil
#         else 
#           return nil
#         end
#         return RARE_DROPS.to_a.sample
#       else
#         if $game_player.foundOddKeystone
#           RARE_DROPS.delete(ODDKEYSTONE)
#           return RARE_DROPS.to_a.sample
#         else
#           drop = RARE_DROPS.to_a.sample
#           if drop == ODDKEYSTONE
#             $game_player.foundOddKeystone = true
#             return drop
#           else
#             return TREASURE_DROPS.to_a.sample
#           end
#       end

#       end
#     end
# end