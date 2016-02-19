#!/usr/local/bin/ruby
require 'lotto_sim'
f = LottoSim::FloridaLotto.new
f.play(tickets: ARGV[0]||25000, picks: 10)
