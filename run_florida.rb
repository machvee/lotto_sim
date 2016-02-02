require 'lotto_sim'
include LottoSim
f = FloridaLotto.new
f.play(tickets: ARGV[0]||25000, draws: 10)
