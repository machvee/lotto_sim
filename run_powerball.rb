#!/usr/local/bin/ruby
require 'lotto_sim'
p = LottoSim::Powerball.new
p.play(tickets: ARGV[0]||25000, picks: 10)
