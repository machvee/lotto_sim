#!/usr/local/bin/ruby

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
        multiplier: {
          name: "Fuzzball",
          cost:  1,
          picks: [2,3,4,5]
        },
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
    expect(@pick.numbers).must_equal @numbers
    assert_nil @pick.outcome
  end

  it "should have a String representation" do
    expect(@pick.to_s).must_equal "01    02    03    04    05  -  01"
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
      expect(@pick & @pick_with_matches).must_equal @matching_intersect
    end

    it "should return empty arrays when no match" do
      @pick_with_no_matches = Pick.new(@no_matching_numbers)
      expect(@pick & @pick_with_no_matches).must_equal @no_matching_intersect 
    end
  end
end

describe Generator, "A random number set generator" do
  before do
    @num = 20
    @max = 100
    @config = {
      num_picks: @num,
      picks_max: @max
    }
    @seed = 918273645 # yields the random array in @expected_pick
    @expected_pick = [8, 9, 16, 23, 29, 36, 44, 49, 51, 56, 60, 68, 71, 75, 80, 81, 86, 87, 93, 94]
    @seeded_randomizer = SeededRandomizer.new(@seed)
    @generator = Generator.new(@config, @seeded_randomizer)
    @pick = @generator.pick
  end

  it "should pick a set of numbers" do
    expect(@pick).must_equal(@expected_pick)
  end

  it "should have valid length and range" do
    expect(@pick.length).must_equal(@config[:num_picks])
    expect(@pick.max).must_be :<=, @config[:picks_max]
  end

  it "should have expected odds" do
    odds = ([*(@max-@num+1)..@max].inject(:*).to_f/[*1..@num].inject(:*)).to_i
    expect(@generator.odds).must_equal(odds)
  end

  it "should tally frequency distribution correctly" do
    (1..@max).each do |v|
      expect(@generator.freq[v]).must_equal(@expected_pick.include?(v) ? 1 : 0)
    end
  end

  it "should act as a validator for manual picks" do
    {
      is_not_long_enough:   [*1..(@num/2)],
      is_too_long:          [*1..(@num+1)],
      has_dups:             [*1..(@num-1), (@num/2)],
      is_out_of_range_low:  [*0..(@num-1)],
      is_out_of_range_high: [*1..(@num-1), @max+1]
    }.each_pair do |type, invalid_pick|
      expect(@generator.valid?(invalid_pick)).must_equal(false, "#{invalid_pick} #{type} and shouldn't be valid")
    end

    expect(@generator.valid?(@expected_pick)).must_equal(true)
  end
end


describe Lottery, "A TestLottery" do
  before do
    @seed = 1000983364347 # yields the random sets in @expected_draw
    @expected_draw = [[1,9,20,34,50],[14]]
    @lottery = TestLottery.new(randomizer: SeededRandomizer.new(@seed))
  end

  it "should have the expected draw given the seed" do
    nightly_draw, nightly_multiplier = @lottery.draw
    expect(nightly_draw.numbers).must_equal(@expected_draw)
  end

  describe Ticket, "A Test Lottery Ticket" do
    before do
      @numbers = [[[4,9,17,27,34],[14]]]
      @expected_outcome_key = [2, 1]
      @ticket = Ticket.new(@lottery, @numbers)
    end

    it "should have readers with expected values after initialize" do
      expect(@ticket.lotto).must_equal @lottery
      expect(@ticket.number).must_be :>, 0 
      expect(@ticket.num_picks).must_equal @numbers.length
      expect(@ticket.picks.length).must_equal @numbers.length
      expect(@ticket.cost).must_equal @numbers.length * @lottery.cost
      expect(@ticket.winnings).must_equal 0
      expect(@ticket.checked).must_equal false
      expect(@ticket.printer).wont_equal nil
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
        expect(@ticket.checked).must_equal(true)
      end

      it "should calculate winnings for a [2, 1] outcome" do
        expect(@ticket.winnings).must_equal(@lottery.outcomes[[2,1]].payout)
      end
    end

  end

  describe RandomTicket, "A ticket that generates easy picks" do
    before do
      @num_picks = 10
      @random_ticket = RandomTicket.new(@lottery, @num_picks)
    end

    it "should have accurate readers set" do
      expect(@random_ticket.lotto).must_equal @lottery
      expect(@random_ticket.number).must_be :>, 0 
      expect(@random_ticket.num_picks).must_equal @num_picks
      expect(@random_ticket.picks.length).must_equal @num_picks
      expect(@random_ticket.cost).must_equal @num_picks * @lottery.cost
      expect(@random_ticket.winnings).must_equal 0
      expect(@random_ticket.checked).must_equal false
      expect(@random_ticket.printer).wont_equal nil
      assert_nil @random_ticket.multiplier
    end
  end

  describe "remember tickets that have a lottery winning pick" do
    before do
      @winning_tickets = []
      @num_winning_tickets = 4
      @num_winning_tickets.times do
        @winning_tickets << @lottery.buy_ticket(picks: [@expected_draw])
      end
      @num_non_winning_tickets = 50
      @num_non_winning_tickets.times do 
        @lottery.buy_ticket(easy_picks: 5)
      end
      @draw, @multiplier = @lottery.draw
      @lottery.check_tickets
    end

    it "should have the expected number of tickets purchased" do
      expect(@lottery.tickets.length).must_equal(@num_winning_tickets + @num_non_winning_tickets)
    end

    it "should remember the num_winning_tickets" do
      expect(@draw.numbers).must_equal(@expected_draw)
      expect(@lottery.num_jackpot_winners).must_equal(@num_winning_tickets)
    end

    it "should have calculated the correct split jackpot amount to be shared" do
      expect(@lottery.current_jackpot_payout).must_equal(@lottery.current_jackpot/@num_winning_tickets)
    end

    it "should calculate each ticket winnings correctly" do
      @winning_tickets.each do |ticket|
        expect(ticket.winnings).must_equal(@lottery.current_jackpot/@num_winning_tickets)
      end
    end
  end
end
