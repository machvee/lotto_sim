require 'minitest/autorun'
require 'lotto_sim'
include LottoSim


class TestLottery < Lottery
  def initialize(options={})
    super(options.merge(
      config: {
        name: "TestLotto",
        cost:  1,
        start_jackpot: 1_000_000,
        numbers: [
          {
            num_picks: 5,
            picks_max: 50
          },
          {
            num_picks: 1,
            picks_max: 20
          }
        ],
        payouts: {
          [5, 1] =>  JACKPOT, [5, 0] =>  100_000,
          [4, 1] =>   10_000, [4, 0] =>      100,
          [3, 1] =>       50, [3, 0] =>        5,
          [2, 1] =>        5, [1, 1] =>        2,
          [0, 1] =>        2, [2, 0] =>        0,
          [1, 0] =>        0, [0, 0] =>        0
        }
      }
    ))
  end
end


describe Pick, "A Lotto Pick" do
  before do
    @numbers = [[1,2,3,4,5],[1]]
    @pick = Pick.new(@numbers)
  end

  it "should have a readers" do
    @pick.numbers.must_equal @numbers
    @pick.outcome.must_equal nil
  end

  it "should have a String representation" do
    @pick.to_s.must_equal "01    02    03    04    05  -  01"
  end

  describe "supports an & operator that produces a set of intersections" do
    before do
      @matching_numbers      = [[1,3,5,7,9],[1]]
      @matching_intersect    = [[1,3,5],[1]]
      @no_matching_numbers   = [[11,13,15,17,19],[11]]
      @no_matching_intersect = [[],[]]
    end

    it "should return matches when there is a match" do
      @pick_with_matches = Pick.new(@matching_numbers)
      (@pick & @pick_with_matches).must_equal @matching_intersect
    end

    it "should return empty arrays when no match" do
      @pick_with_no_matches = Pick.new(@no_matching_numbers)
      (@pick & @pick_with_no_matches).must_equal @no_matching_intersect 
    end
  end
end

describe Generator, "A random number set generator" do
  before do
    @config = {
      num_picks: 20,
      picks_max: 100
    }
    @seed = 918273645 # yields the random array in @expected_pick
    @expected_pick = [8, 9, 16, 23, 29, 36, 44, 49, 51, 56, 60, 68, 71, 75, 80, 81, 86, 87, 93, 94]
    @seeded_randomizer = SeededRandomizer.new(@seed)
    @generator = Generator.new(@config, @seeded_randomizer)
    @pick = @generator.pick
  end

  it "should pick a set of numbers" do
    @pick.must_equal(@expected_pick)
  end

  it "should have valid length and range" do
    @pick.length.must_equal(@config[:num_picks])
    @pick.max.must_be :<=, @config[:picks_max]
  end

  it "should have expected odds" do
    odds = ([*(100-20+1)..100].inject(:*).to_f/[*1..20].inject(:*)).to_i
    @generator.odds.must_equal(odds)
  end

  it "should tally frequency distribution correctly" do
    (1..100).each do |v|
      @generator.freq[v].must_equal(@expected_pick.include?(v) ? 1 : 0)
    end
  end

  it "should act as a validator for manual picks" do
    {
      is_not_long_enough:   [*1..10],
      is_too_long:          [*1..21],
      has_dups:             [*1..19, 15],
      is_out_of_range_low:  [*0..19],
      is_out_of_range_high: [*1..19, 101]
    }.each_pair do |type, invalid_pick|
      @generator.valid?(invalid_pick).must_equal(false, "#{invalid_pick} #{type} and shouldn't be valid")
    end

    @generator.valid?(@expected_pick).must_equal(true)
  end
end


describe Lottery, "A TestLottery" do
  before do
    @seed = 1000983364347 # yields the random sets in @expected_draw
    @expected_draw = [[1,9,20,34,50],[14]]
    @lottery = TestLottery.new(randomizer: SeededRandomizer.new(@seed))
  end

  it "should have the expected draw given the seed" do
    nightly_draw = @lottery.draw
    nightly_draw.numbers.must_equal(@expected_draw)
  end

  describe Ticket, "A Test Lottery Ticket" do
    before do
      @numbers = [[[4,9,17,27,34],[14]]]
      @expected_outcome_key = [2, 1]
      @ticket = Ticket.new(@lottery, @numbers)
    end

    it "should have readers with expected values after initialize" do
      @ticket.lotto.must_equal @lottery
      @ticket.number.must_be :>, 0 
      @ticket.num_picks.must_equal @numbers.length
      @ticket.picks.length.must_equal @numbers.length
      @ticket.cost.must_equal @numbers.length * @lottery.cost
      @ticket.winnings.must_equal 0
      @ticket.checked.must_equal false
      @ticket.printer.wont_equal nil
    end

    it "should print a message when a ticket is checked before the lottery is drawn" do
      assert_output(stdout="lottery not yet drawn\n") { @ticket.check }
    end

    describe "when the lottery is drawn and ticket checked" do
      before do
        @lottery.draw
        @ticket.check
      end

      it "should set checked" do
        @ticket.checked.must_equal(true)
      end

      it "should calculate winnings for a [2, 1] outcome" do
        @ticket.winnings.must_equal(@lottery.outcomes[[2,1]].payout)
      end
    end
  end

  describe RandomTicket, "A ticket that generates easy picks" do
    before do
      @num_picks = 10
      @random_ticket = RandomTicket.new(@lottery, @num_picks)
    end

    it "should have accurate readers set" do
      @random_ticket.lotto.must_equal @lottery
      @random_ticket.number.must_be :>, 0 
      @random_ticket.num_picks.must_equal @num_picks
      @random_ticket.picks.length.must_equal @num_picks
      @random_ticket.cost.must_equal @num_picks * @lottery.cost
      @random_ticket.winnings.must_equal 0
      @random_ticket.checked.must_equal false
      @random_ticket.printer.wont_equal nil
    end
  end
end
