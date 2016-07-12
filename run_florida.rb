require 'lotto_sim'

FLORIDA_LOTTO_CONFIG = {
  name: "Florida Lotto",
  cost:  1,
  start_jackpot: 1_000_000,
  numbers: [
    {
      num_picks: 6,
      picks_max: 53
    }
  ],
  multiplier: {
    name: "Xtra",
    cost:  1,
    picks: [2,3,4,5]
  },
  payouts: {
    [6] =>  LottoSim::JACKPOT,
    [5] =>    5_000,
    [4] =>       70,
    [3] =>        5,
    [2] =>        0,
    [1] =>        0,
    [0] =>        0
  }
}

class FloridaLotto < LottoSim::Lottery
  def initialize(options={})
    super(options.merge(config: FLORIDA_LOTTO_CONFIG))
  end
end

f = FloridaLotto.new
f.play(tickets: ARGV[0]||25000, picks: 10)
