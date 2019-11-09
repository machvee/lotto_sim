#!/usr/local/bin/ruby
require 'lotto_sim'

MEGA_MILLIONS_CONFIG = {
  name: "Mega Millions",
  cost:  2,
  start_jackpot: 40_000_000,
  numbers: [
    {
      num_picks: 5,
      picks_max: 70
    },
    {
      num_picks: 1,
      picks_max: 25
    }
  ],
  multiplier: {
    name: "Megaplier",
    cost:  1,
    picks: [*[2]*2,*[3]*4,*[4]*3,*[5]*6]
  },
  payouts: {
    [5, 1] =>   LottoSim::JACKPOT,
    [5, 0] => 1_000_000,
    [4, 1] =>     5_000,
    [4, 0] =>       500,
    [3, 1] =>        50,
    [3, 0] =>         5,
    [2, 1] =>         5,
    [1, 1] =>         2,
    [0, 1] =>         1,
    [2, 0] =>         0,
    [1, 0] =>         0,
    [0, 0] =>         0
  }
}

class MegaMillions < LottoSim::Lottery
  def initialize(options={})
    super(options.merge(config: MEGA_MILLIONS_CONFIG))
  end
end

m = MegaMillions.new
m.play(tickets: ARGV[0]||25000, picks: 10)
