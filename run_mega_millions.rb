require 'lotto_sim'
include LottoSim
m = MegaMillions.new
m.play(tickets: ARGV[0]||25000, draws: 10)
