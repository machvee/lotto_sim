#!/usr/local/bin/ruby
require 'lotto_sim'
m = LottoSim::MegaMillions.new
m.play(tickets: ARGV[0]||25000, picks: 10)
