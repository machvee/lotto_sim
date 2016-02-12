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


describe Ticket, "A lottery Ticket" do
  before do
    @seed = 1000983364347
    @lottery = TestLottery.new(randomizer: SeededRandomizer.new(@seed))
    @numbers = [[4,9,17,27,31],[18]]
    @ticket = Ticket.new(@lottery, [@numbers])
  end

  it "should have readers" do
    @ticket.lotto.must_equal @lottery
    @ticket.number.must_be :>, 0 
    @ticket.num_picks.must_equal 1
    @ticket.picks.length.must_equal 1
    @ticket.cost.must_equal 1
    @ticket.winnings.must_equal 0
    @ticket.checked.must_equal false
    @ticket.printer.wont_equal nil
  end
end
