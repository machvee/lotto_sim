require 'lotto_sim'

POWERBALL_CONFIG = {
  name: "PowerBall",
  cost:  2,
  start_jackpot: 40_000_000,
  numbers: [
    {
      num_picks: 5,
      picks_max: 69
    },
    {
      num_picks: 1,
      picks_max: 26
    }
  ],
  multiplier: {
    name: "PowerPlay",
    cost:  1,
    picks: [2,3,4,5]
  },
  payouts: {
    [5, 1] =>   LottoSim::JACKPOT,
    [5, 0] => 1_000_000,
    [4, 1] =>    50_000,
    [4, 0] =>       100,
    [3, 1] =>       100,
    [3, 0] =>         7,
    [2, 1] =>         7,
    [1, 1] =>         4,
    [0, 1] =>         4,
    [2, 0] =>         0,
    [1, 0] =>         0,
    [0, 0] =>         0
  }
}

class Powerball < LottoSim::Lottery
  def initialize(options={})
    super(options.merge(config: POWERBALL_CONFIG))
  end
end

p = Powerball.new
p.play(tickets: ARGV[0]||25000, picks: 10)
