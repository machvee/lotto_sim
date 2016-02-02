require 'lotto_sim'
include LottoSim
p = Powerball.new
p.play(tickets: ARGV[0]||25000, draws: 10)
