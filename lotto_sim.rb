module LottoSim

  JACKPOT = 'J'

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
      [5, 1] =>   JACKPOT,
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

  MEGA_MILLIONS_CONFIG = {
    name: "Mega Millions",
    cost:  1,
    start_jackpot: 15_000_000,
    numbers: [
      {
        num_picks: 5,
        picks_max: 75
      },
      {
        num_picks: 1,
        picks_max: 15
      }
    ],
    multiplier: {
      name: "Megaplier",
      cost:  1,
      picks: [*[2]*2,*[3]*4,*[4]*3,*[5]*6]
    },
    payouts: {
      [5, 1] =>   JACKPOT,
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
      [6] =>  JACKPOT,
      [5] =>    5_000,
      [4] =>       70,
      [3] =>        5,
      [2] =>        0,
      [1] =>        0,
      [0] =>        0
    }
  }


  class Pick 
    attr_reader    :ticket
    attr_reader    :numbers
    attr_accessor  :outcome

    PICK_COLOR=:red
    PSEP="    "
    NSEP="  -  "

    def initialize(numbers)
      @numbers = numbers # eg. [ [3,10,23,49,54], [18] ]
      @outcome = nil
    end

    def to_s
      numbers.map { |n_set|
        n_set.map {|n| "%02d" % n}.join(PSEP)
      }.join(NSEP)
    end

    def colorized(draw)
      #
      # return colorized/formatted pick string with outcome, display_length
      #
      colorized_pick_str = numbers.each_with_index.map do |n_set, i|
        d_set = draw.numbers[i]
        n_set.map { |n|
          nstr = "%02d" % n
          d_set.include?(n) ? nstr.send(PICK_COLOR) : nstr
        }.join(PSEP)
      end.join(NSEP)
      pick_display_length = to_s.length
      outcome_str = outcome.nil? ? "" : ("   %s" % outcome.print)
      display_length = pick_display_length + outcome_str.length + 2
      ["  %s%s" % [colorized_pick_str, outcome_str], display_length]
    end

    def &(other_pick)
      other_pick.numbers.zip(numbers).map {|a| a.reduce(&:&)}
    end

    def inspect
      to_s
    end
  end


  class Ticket 
    attr_reader  :lotto
    attr_reader  :number
    attr_reader  :num_picks
    attr_reader  :picks
    attr_reader  :multiplier
    attr_reader  :cost
    attr_reader  :winnings
    attr_reader  :checked
    attr_reader  :printer

    def initialize(lotto, numbers, multiplier=nil)
      @lotto      = lotto
      @number     = lotto.next_ticket_number
      @picks      = gen_picks(numbers)
      @multiplier = multiplier
      @num_picks  = picks.length
      @cost       = lotto.calculate_cost(self)
      @printer    = lotto.ticket_printer
      @winnings   = 0
      @checked    = false
    end

    def print(only_winners=false)
      printer.print(self, only_winners)
      self
    end

    def wins
      return unless checked
      print(only_winners=true)
    end

    def check
      return if lotto.not_drawn_check
      return if checked
      picks.each do |pick|
        outcome = lotto.match(pick)
        #
        # if jackpot, we need to postpone award of winnings
        # until we know how many jackpots winners there might be
        # as they all split the jackpot
        #
        outcome.count += 1
        outcome.multiplier_count += 1 if multiplier_match?

        if outcome.jackpot?
          lotto.jackpot_tickets[self] << pick
        else
          @winnings += payout(outcome)
          lotto.bank.debit(outcome.payout)
        end
      end
      @checked = true
    end

    def payout(outcome)
      #
      # lotto.payout(outcome) * lotto.multiplier if played and matched on ticket
      #
      outcome.payout * (multiplier_match? ? multiplier : 1)
    end

    def multiplier_match?
      if multiplier.nil?
        false
      else
        multiplier == lotto.official_multiplier
      end
    end

    def award_jackpot
      @winnings += lotto.current_jackpot_payout
    end

    def inspect
      "Ticket %d: %d pick%s for #{cost.money}%s%s" % [
        number,
        num_picks,
        num_picks == 1 ? "" : "s",
        (checked ? (", winnings: %s" % winnings.money) : ""),
        multiplier.nil? ? "" : ", #{lotto.game_multiplier.name}: #{multiplier}"
      ]
    end

    private

    def gen_picks(picks)
      picks.map {|p| Pick.new(p)}
    end
  end


  class RandomTicket < Ticket
    def initialize(lotto, num_picks, multiplier=false)
      mult_arg = case multiplier
        when true
          lotto.random_multiplier
        when false
          nil
        else
          multiplier
      end
      super(lotto, lotto.random_picks(num_picks), mult_arg)
    end
  end

  class TicketPrinter

    TICKET_PRINT_WIDTH=70
    TICKET_BORDER_COLOR=:green

    attr_reader   :printer
    attr_reader   :lotto

    def initialize(lotto)
      @lotto = lotto
      @printer = BoxPrinter.new(TICKET_PRINT_WIDTH, TICKET_BORDER_COLOR)
    end

    def print(ticket, only_winners=false)
      print_header(ticket)
      print_picks(ticket, only_winners)
      print_footer(ticket)
    end

    private

    def print_header(ticket)
      puts "\n"
      printer.top
      printer.center(" #{display_name}   Ticket: \##{ticket.number}")
      printer.sep
      if lotto.played
        printer.lbreak
        printer.center("**  %s  **" % lotto.official_draw)
        printer.center("%s  x  %d" % [lotto.game_multiplier.name, lotto.official_multiplier])
      end
      printer.lbreak
      printer.lrjust("Plays: #{ticket.num_picks}",
                     "%s: %s" % [lotto.game_multiplier.name, ticket.multiplier.nil? ? "not played" : " #{ticket.multiplier}"])
      printer.lbreak
    end

    def print_picks(ticket, only_winners=false)
      ticket.picks.each do |pick|
        next if only_winners && pick.outcome.payout == 0
        if ticket.checked
          printer.ljust(*pick.colorized(lotto.official_draw))
        else
          printer.center("%s" % pick)
        end
      end
    end

    def print_footer(ticket)
      printer.lbreak
      opt_winnings = ticket.checked ? ((" "*14) + "Winnings:  %s" % ticket.winnings.money) : ""
      printer.lrjust("Cost:  %s" % ticket.cost.money, opt_winnings)
      printer.bottom
    end

    def display_name
      @dn ||= lotto.name.upcase.gsub(/(.)/, '\1 ')
    end
  end


  class Generator
    #
    # generates a sorted array of <config[:num_picks]> numbers chosen 
    # from 1 to <config[:picks_max]>.
    #
    attr_reader   :num_picks
    attr_reader   :range
    attr_reader   :pick_array
    attr_reader   :max
    attr_reader   :freq

    def initialize(config, randomizer)
      @num_picks = config[:num_picks]
      @max = config[:picks_max]
      raise "num_picks must be less than #{max}" if num_picks > max

      @range = 1..max
      @freq = Array.new(max+1) {0}
      @pick_array = [*range]
      @prng = randomizer.new_prng
    end

    def pick
      tally(randomize(pick_array)[0...num_picks].sort)
    end

    def odds
      #
      # returns n as a Float, where n is the odds 1/n of guessing
      # the contents of a pick in any order
      #
      @_odds ||= odds_choose_multiple.to_f/odds_picks_multiple
    end

    def valid?(numbers)
      numbers.uniq.length == num_picks && numbers.all? {|n| range.include?(n)}
    end

    private 

    def randomize(picks)
      picks.shuffle(random: @prng)
    end

    def tally(picks)
      picks.each {|n| freq[n] += 1}
      picks
    end

    def odds_picks_multiple
      @_npf ||= [*1..num_picks].inject(:*)
    end

    def odds_choose_multiple
      @_ch ||= begin 
        start = max - num_picks + 1
        [*start..max].inject(:*)
      end 
    end
  end


  class DrawGenerator < Generator
    #
    # do some extra shuffling for the draw to simulate
    # the randomness of the number balls bouncing around
    # before being selected
    #
    DRAW_SHUFFLER_RANGE=10..20
    private

    def randomize(picks)
      @prng.rand(DRAW_SHUFFLER_RANGE).times { picks.shuffle!(random: @prng) }
      picks
    end
  end


  class MultiplierGenerator
    attr_reader :picks
    attr_reader :cost
    attr_reader :name

    MULTI_SHUFFLER_RANGE=5..10

    def initialize(config, randomizer)
      @picks = config[:picks]
      @name  = config[:name]
      @cost  = config[:cost]
      @prng  = randomizer.new_prng
    end

    def pick
      @prng.rand(MULTI_SHUFFLER_RANGE).times {@picks.shuffle!(random: @prng)}
      @picks.first
    end

    def invalid?(mult)
      !(mult.nil? || picks.include?(mult))
    end

    def to_s
      ("For %s more, play the \"%s\" by selecting %s\n" +
       "If matched, your ticket winnings are multiplied by that number") % [
        cost.money,
        name,
        or_list(picks)
      ]
    end

    private

    def or_list(nums)
      n = nums.uniq.sort
      cl = n.map(&:to_s)[0..-2]
      [cl.any? ? cl.join(", ") : nil, n.last.to_s].compact.join(" or ")
    end
  end


  class GamePicker
    #
    # picks one or more sets of numbers chosen via Generators
    # e.g.  Picks a set of numbers between 1 and 53, and a Powerball
    # number from 1 to 26
    #
    def initialize(configs, randomizer, generator_class=Generator)
      @randomizer = randomizer
      @generators = configs.map {|config| generator_class.new(config, @randomizer)}
    end

    def pick
      @generators.map(&:pick)
    end

    def odds
      @_odds ||= @generators.map(&:odds).inject(:*).to_i
    end

    def invalid?(numbers)
      e = numbers.each
      @generators.map do |g|
        n = e.next
        !g.valid?(n)
      end.any?
    end

    def to_s
      @generators.map do |g|
        "pick %d number%s between 1 and %d" % [
          g.num_picks,
          g.num_picks > 1 ? "s" : "",
          g.max
        ]
      end.join(", then ").capitalize
    end

    def stats
      stats_cols = 8
      puts "\nSorted Picks Frequency Distribution"
      @generators.each do |gen|
        puts "  Numbers from #{gen.range}"
        gen.freq[1..-1].each_with_index.
            sort {|(val1, ind1), (val2, ind2)| val2 <=> val1}.
            each_slice(stats_cols)  do |cols|
          buf = "    "
          cols.each do |freq, num|
            buf << "%02d:%7d   " % [num+1, freq]
          end
          puts buf
        end
      end
    end
  end


  class Outcome
    attr_reader :match
    attr_reader :lotto
    attr_reader :pays

    attr_accessor :count
    attr_accessor :multiplier_count

    def initialize(lotto, match, pays)
      @lotto = lotto
      @match = match # [3] or [4,1]
      @pays = pays
      @count = 0
      @multiplier_count = 0
    end

    def payout
      jackpot? ? lotto.current_jackpot_payout : pays
    end

    def jackpot?
      pays == JACKPOT
    end

    def to_s
      match.join("+")
    end

    def payout_s
      payout.zero? ? '' : ("%s" % payout.money)
    end

    def inspect
      to_s
    end

    def print
      " (%s)   %s" % [self, payout_s]
    end

    def stat
      perc = (count.to_f / lotto.num_plays) * 100.0
      multi_stat = jackpot? ? "%58s"  % " ":  "%11s: %22s %22s" % [
        multiplier_count.comma,
        (payout * lotto.official_multiplier).money,
        (multiplier_count * payout * lotto.official_multiplier).money
      ]
      non_multiple_count = count - multiplier_count
      puts "[%s] - %11s: %22s %22s %s  %10.6f%%" % [
        self,
        non_multiple_count.comma,
        payout.money,
        (non_multiple_count * payout).money,
        multi_stat,
        perc
      ]
    end
  end


  class Lottery

    class TicketFactory
      def initialize(lotto)
        @lotto = lotto
      end

      def build(options)
        if options[:picks].nil?
          multiplier = options.fetch(:multiplier) {true}
          RandomTicket.new(@lotto, options.fetch(:easy_picks) {1}, multiplier)
        else
          multiplier = options.fetch(:multiplier) {nil}
          Ticket.new(@lotto, options[:picks].map {|s| s.map(&:sort)}, multiplier)
        end
      end
    end

    DEFAULT_CONFIG = POWERBALL_CONFIG

    attr_reader     :name
    attr_reader     :bank
    attr_reader     :cost
    attr_reader     :official_draw
    attr_reader     :official_multiplier
    attr_reader     :played
    attr_reader     :tickets
    attr_reader     :outcomes
    attr_reader     :payouts
    attr_reader     :num_plays
    attr_reader     :start_jackpot
    attr_accessor   :current_jackpot
    attr_reader     :jackpot_tickets
    attr_reader     :ticket_printer
    attr_reader     :ticket_counter
    attr_reader     :game_multiplier
    attr_reader     :ticket_factory
    attr_reader     :quiet


    def initialize(options={})
      config = options[:config]||DEFAULT_CONFIG
      @quiet = options.fetch(:quiet) {false}
      @name = config[:name]
      @randomizer = options.fetch(:randomizer) {Randomizer.new}
      @game_picker = GamePicker.new(config[:numbers], @randomizer, DrawGenerator)
      @ticket_picker = GamePicker.new(config[:numbers], @randomizer)
      @game_multiplier = MultiplierGenerator.new(config[:multiplier], @randomizer)
      @ticket_multiplier = MultiplierGenerator.new(config[:multiplier], @randomizer)
      @ticket_factory = TicketFactory.new(self)
      @start_jackpot = config[:start_jackpot]
      @bank = Bank.new(start_jackpot)
      @payouts = config[:payouts]
      @cost = config[:cost]
      @ticket_printer = TicketPrinter.new(self)
      init_setup
    end

    def next_ticket_number
      @ticket_counter += 1
    end

    def current_jackpot_payout
      num_jackpot_winners.zero? ? current_jackpot : (current_jackpot / num_jackpot_winners)
    end

    def num_jackpot_winners
      jackpot_tickets.inject(0) {|memo, (ticket, picks)| memo += picks.length}
    end

    def one_in_how_many_jackpot_odds
      @game_picker.odds
    end

    def odds_of_winning_jackpot
      "Odds of winning the JACKPOT are 1 in %s" % @game_picker.odds.comma
    end

    def how_to_play
      puts "\n%s\n\n" % @game_picker
      puts "\n%s\n\n" % game_multiplier
      puts "%s\n\n" % odds_of_winning_jackpot 
      self
    end

    def draw
      return if played_check
      @official_draw = Pick.new(@game_picker.pick)
      @official_multiplier = game_multiplier.pick
      @played = true
      [official_draw, official_multiplier]
    end

    def payout(result)
      outcomes[result].payout
    end

    def buy_ticket(options={})
      #
      # buy_ticket(easy_picks: 10)                  # 10 random selections with random multiplier
      # buy_ticket(easy_picks: 10, multiplier: nil) # 10 random selections with no multiplier
      # buy_ticket(easy_picks: 10, multiplier: 2)   # 10 random selections with multiplier 2
      #
      #   --or--
      #
      # buy_ticket(picks: [[[7,17,33,38,44],[11]], ...], multiplier: 3) # play picks number(s) with multiplier 3
      #
      return if played_check
      return nil if invalid_picks?(options)

      create_ticket(options)
    end

    def invalid_picks?(options)
      numbers = options[:numbers]
      multiplier = options[:multiplier]
      if game_multiplier.invalid?(multiplier)
        puts "%d is not a valid multiplier" % multiplier
        how_to_play
        return true
      else
        numbers.each do |set|
          if @game_picker.invalid?(set)
            puts "%s is not a valid pick" % numbers
            how_to_play
            return true
          end
        end unless numbers.nil?
      end
      false
    end

    def create_ticket(options)
      ticket_factory.build(options).tap do |t|
        bank.credit(calculate_cost(t))
        @num_plays += t.num_picks
        tickets << t
      end
    end

    def winning_tickets(top=3)
      tickets.sort {|a,b| b.winnings <=> a.winnings}[0...top]
    end

    def random_picks(num_picks)
      (1..num_picks).map {|n| @ticket_picker.pick}
    end

    def random_multiplier
      @ticket_multiplier.pick
    end

    def calculate_cost(ticket)
      (ticket.num_picks * cost) + ((ticket.multiplier.nil? ? 0 : 1) * game_multiplier.cost)
    end

    def match(pick)
      return if not_drawn_check

      matching_numbers = pick & official_draw
      numbers_matched = matching_numbers.map(&:length)
      pick.outcome = outcomes[numbers_matched]
      pick.outcome
    end

    def played_check
      puts "already drawn" if played
      played
    end

    def not_drawn_check
      puts "lottery not yet drawn" unless played
      !played
    end

    def init_outcomes
      @outcomes = {}
      payouts.each_pair { |numbers_matched, payout| 
        outcomes[numbers_matched] = Outcome.new(self, numbers_matched, payout)
      }
    end

    NUM_TOP_WINNERS_TO_SHOW=3
    REPORT_INTERVAL=5000
    REPORTING_THRESHOLD=10000
    DEFAULT_TICKETS_TO_PLAY=1000
    DEFAULT_PICKS_PER_TICKET=5

    def play(options={})
      num_tickets = (options.fetch(:tickets) {DEFAULT_TICKETS_TO_PLAY}).to_i
      num_draws_per_ticket = (options.fetch(:picks) {DEFAULT_PICKS_PER_TICKET}).to_i

      report_msg("Buying tickets...", num_tickets)
      num_tickets.times {|i|
        buy_ticket(easy_picks: num_draws_per_ticket)
        report_count(i, num_tickets)
      }

      nd, multi = draw
      puts "\nThe Nightly Draw is...\n%s%s\n%s%s x %d\n\n" % [
        " "*2,
        nd,
        " "*2,
        game_multiplier.name,
        multi
      ]

      check_tickets
      stats
      winning_tickets(NUM_TOP_WINNERS_TO_SHOW).each {|t| t.wins}
      self
    end

    PLAY_UNTIL_CONFIG = {
      report_payout: 100,
      max_picks: 25_000_000
    }

    def play_until_jackpot(options={})
      #
      # draw the lottery, then generate picks until one
      # matches the draw and wins the jackpot.   Report
      # any picks that win > $100 along the way
      #
      opts = PLAY_UNTIL_CONFIG.merge(options)
      count = 0
      reset
      d,_ = draw
      puts d
      loop {
        count += 1
        pick = Pick.new(@ticket_picker.pick)
        outcome = match(pick)
        if outcome.payout >= opts[:report_payout]
          result, _ = pick.colorized(official_draw)
          puts "%s: %s" % [count.comma, result]
        end
        break if outcome.jackpot? || count == opts[:max_picks]
      }
      self
    end

    def check_tickets(options={})
      num_tickets = tickets.length
      report_msg("Checking tickets....", num_tickets)
      tickets.each_with_index {|ticket, i|
        ticket.check
        report_count(i, num_tickets)
      }
      award_any_jackpots
      self
    end

    def award_any_jackpots
      jackpot_tickets.each_pair do |ticket, picks|
        picks.each do |pick|
          ticket.award_jackpot
          bank.debit(pick.outcome.payout) 
        end
      end
    end

    def init_setup
      @current_jackpot = @start_jackpot
      @official_draw = nil
      @played = false
      @tickets = []
      @jackpot_tickets = Hash.new {|h,k| h[k] = []}
      @num_plays = 0
      @ticket_counter = 0
      init_outcomes
      self
    end

    def reset
      bank.reset
      init_setup
    end

    def stats
      puts self
      puts "\n"
      outcomes.values.each { |v| v.stat}
      @ticket_picker.stats
      puts "\n"
      puts bank
      self
    end

    def inspect
      to_s
    end

    def report_count(i, max)
      puts(i) if i%REPORT_INTERVAL == 0 && max > REPORTING_THRESHOLD unless quiet
    end

    def report_msg(msg, max)
      puts(msg) if max > REPORTING_THRESHOLD unless quiet
    end

    def to_s
      any_draw = if played
        "\n\nDraw:  %s" % official_draw
        "\n\n%s:  %d" % [game_multiplier.name, official_multiplier]
      else
        ""
      end

      "%s: %s tickets purchased, %s plays, current jackpot: %s%s" % 
        [name,
         tickets.length.comma,
         num_plays.comma,
         current_jackpot.money,
         any_draw]
    end
  end


  class Randomizer
    def new_prng
      Random.new(new_seed)
    end

    def new_seed
      Random.new_seed
    end
  end


  class SeededRandomizer < Randomizer
    #
    # Used to get repeatable outcome in successive lottery runs
    #
    # usage:  l = Lottery.new(randomizer: SeededRandomizer.new(<some number>))
    #
    attr_reader   :seeder
    attr_reader   :init_seed
    BIG_NUM = 6347349345764256326431348018374

    def initialize(seed)
      @init_seed = seed
      @seeder = Random.new(init_seed)
    end

    def new_seed
      @seeder.rand(BIG_NUM)
    end
  end


  class Bank
    attr_reader  :credits
    attr_reader  :debits
    attr_reader  :start_balance
    attr_reader  :balance

    def initialize(start_balance)
      @start_balance = start_balance
      reset
    end

    def credit(amt)
      @credits += amt
      @balance += amt
      self
    end

    def debit(amt)
      @debits += amt
      @balance -= amt
      self
    end

    def to_s
      "Lottery Bank - Balance: #{balance.money}  (Credits: #{credits.money}, Debits: #{debits.money})"
    end

    def inspect
      to_s
    end

    def reset
      @balance = @start_balance
      @credits = 0
      @debits = 0
      self
    end
  end


  class Powerball < Lottery
    def initialize(options={})
      super(options.merge(config: POWERBALL_CONFIG))
    end
  end


  class MegaMillions < Lottery
    def initialize(options={})
      super(options.merge(config: MEGA_MILLIONS_CONFIG))
    end
  end


  class FloridaLotto < Lottery
    def initialize(options={})
      super(options.merge(config: FLORIDA_LOTTO_CONFIG))
    end
  end


  class BoxPrinter
    attr_reader   :width
    attr_reader   :color

    BLEFT="\u255A"
    TLEFT="\u2554"
    BRIGHT="\u255D"
    TRIGHT="\u2557"
    HORIZ="\u2550"
    LSEP="\u2560"
    RSEP="\u2563"
    VERT="\u2551"
    SPACE=" "

    def initialize(width, color=:green)
      @color    = color
      @width    = width
      @top_s    = (TLEFT + (HORIZ*width) + TRIGHT).send(color)
      @bottom_s = (BLEFT + (HORIZ*width) + BRIGHT).send(color)
      @lbreak_s = (VERT  + (SPACE*width) + VERT).send(color)
      @sep_s    = (LSEP  + (HORIZ*width) + RSEP).send(color)
      @vert_s   = VERT.send(color)
    end

    def top
      puts @top_s
    end

    def sep
      puts @sep_s
    end

    def bottom
      puts @bottom_s
    end

    def lbreak
      puts @lbreak_s
    end

    def center(str, disp_len=str.length)
      margin = width - disp_len
      #   |<----------- width ---------->|
      #         |<-   disp_len   ->|
      #   |<--->| margin/2
      #  ||                              ||
      lmargin = margin/2
      rmargin = margin - lmargin
      output "%*s%s%*s" % [
        lmargin, SPACE,
        str,
        rmargin, SPACE
      ]
    end

    def ljust(str, disp_len=str.length)
      #   |<-------------- width -------------->|
      #   |<-   disp_len   ->|
      #   |<---------  str.length ------------>|
      #  ||                                     ||
      offset = str.length - disp_len
      output "%-*s" % [width+offset, str]
    end

    def lrjust(left_str, right_str)
      mid_spacing = width - left_str.length - right_str.length - 6
      center("%s%*s%s  " % [left_str, mid_spacing, SPACE, right_str])
    end

    def output(str)
      puts "%s%s%s" % [@vert_s, str, @vert_s]
    end
  end
end


module Formatters
  def money
    "$%s.00" % comma
  end

  def comma
    to_s.chars.reverse.each_slice(3).map(&:join).join(",").reverse
  end
end


class Bignum
  include Formatters
end


class Fixnum
  include Formatters
end


class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def blue
    colorize(34)
  end

  def light_blue
    colorize(36)
  end
end

