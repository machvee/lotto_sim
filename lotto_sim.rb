module LottoSim

  JACKPOT = 'J'

  class Pick 
    attr_reader    :numbers
    attr_accessor  :outcome

    PICK_COLOR=:red

    def initialize(numbers)
      @numbers = numbers # eg. [ [3,10,23,49,54], [18] ]
      @outcome = nil
    end

    def to_s
      numbers.map { |n_set|
        n_set.map {|n| "%02d" % n}.join("    ")
      }.join("  -  ")
    end

    def matches(lotto_draw)
      lotto_draw.numbers.zip(numbers).map {|a| a.reduce(&:&)}
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
    attr_reader  :cost
    attr_reader  :winnings
    attr_reader  :checked
    attr_reader  :printer

    def initialize(lotto, num_picks)
      @lotto = lotto
      @number = lotto.next_ticket_number
      @num_picks = num_picks
      @picks = lotto.random_picks(num_picks)
      @cost = lotto.calculate_cost(num_picks)
      @printer = lotto.ticket_printer
      @winnings = 0
      @checked = false
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
      lotto.not_drawn_check
      return if checked
      picks.each do |pick|
        outcome = lotto.match(pick)
        @winnings += outcome.payout unless outcome.jackpot?
      end
      @checked = true
    end

    def award_any_jackpot
      lotto.not_drawn_check
      picks.each do |pick|
        if pick.outcome.jackpot?
          @winnings += pick.outcome.payout
          lotto.bank.debit(pick.outcome.payout) 
        end
      end
    end

    def inspect
      "Ticket #{number}: #{num_picks} picks for #{cost.money}%s" % (checked ? (", winnings: %s" % winnings.money) : "")
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
      end
      printer.lbreak
      printer.ljust("Plays: #{ticket.num_picks}")
      printer.lbreak
    end

    def print_picks(ticket, only_winners=false)
      ticket.picks.each do |pick|
        next if only_winners && pick.outcome.payout == 0
        if ticket.checked
          printer.ljust("  %s%s" % [pick, pick.outcome.nil? ? "" : ("   %s" % pick.outcome.print)])
        else
          printer.center("%s" % pick)
        end
      end
    end

    def print_footer(ticket)
      printer.lbreak
      opt_winnings = ticket.checked ? ((" "*14) + "Winnings:  %s" % ticket.winnings.money) : ""
      printer.ljust("Cost:  %s%s" % [ticket.cost.money, opt_winnings])
      printer.bottom
    end

    def display_name
      @dn ||= lotto.name.upcase.gsub(/(.)/, '\1 ')
    end
  end


  class Generator
    #
    # generates a sorted array of <options[:num_picks]> numbers chosen 
    # from 1 to <options[:picks_max]>.   Optionally can be seeded with
    # options[:seed]
    #
    attr_reader   :num_picks
    attr_reader   :pick_array
    attr_reader   :max

    def initialize(options={})
      @num_picks = options[:num_picks]
      @max = options[:picks_max]
      raise "num_picks must be less than #{max}" if num_picks > max

      @pick_array = [*1..max]
      @prng = Random.new(options[:seed]||Random.new_seed)
    end

    def pick
      pick_array.shuffle(random: @prng)[0...num_picks].sort
    end

    def odds
      #
      # returns n as a Float, where n is the odds 1/n of guessing
      # the contents of a pick in any order
      #
      @_odds ||= odds_choose_multiple.to_f/odds_picks_multiple
    end

    private 

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


  class GamePicker
    #
    # picks one or more sets of numbers chosen via Generators
    # e.g.  Picks a set of numbers between 1 and 53, and a Powerball
    # number from 1 to 26
    #
    def initialize(configs)
      @generators = configs.map {|config| Generator.new(config)}
    end

    def pick
      Pick.new(@generators.map(&:pick))
    end

    def odds
      @_odds ||= @generators.map(&:odds).inject(:*).to_i
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
  end


  class Outcome
    attr_reader :match
    attr_reader :lotto
    attr_reader :pays

    attr_accessor :count

    def initialize(lotto, match, pays)
      @lotto = lotto
      @match = match # [3] or [4,1]
      @pays = pays
      @count = 0
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
      payout.zero? ? '' : ("%s%s" % [jackpot? ? "*** JACKPOT *** " : '', payout.money])
    end

    def inspect
      to_s
    end

    def print
      " (%s)   %s" % [self, payout_s]
    end

    def stat
      perc = (count.to_f / lotto.plays) * 100.0
      puts "[%s] - %8s: %22s %22s %10.6f%%" % [
        self,
        count.comma,
        payout.money,
        (count * payout).money,
        perc
      ]
    end
  end

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


  class Lottery

    DEFAULT_CONFIG = FLORIDA_LOTTO_CONFIG

    attr_reader     :played
    attr_reader     :official_draw # the current, official evening draw
    attr_reader     :name
    attr_reader     :cost
    attr_reader     :tickets
    attr_reader     :plays
    attr_reader     :payouts
    attr_reader     :start_jackpot
    attr_accessor   :current_jackpot
    attr_reader     :ticket_counter
    attr_reader     :bank
    attr_reader     :outcomes
    attr_reader     :ticket_printer
    attr_reader     :quiet

    def initialize(options={})
      config = options[:config]||DEFAULT_CONFIG
      @quiet = options.fetch(:quiet) {false}
      @name = config[:name]
      @game_picker = GamePicker.new(config[:numbers])
      @ticket_picker = GamePicker.new(config[:numbers])
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
      not_drawn_check
      jackpot_outcome.count.zero? ? current_jackpot : (current_jackpot / jackpot_outcome.count)
    end

    def one_in_how_many_jackpot_odds
      @game_picker.odds
    end

    def odds_of_winning_jackpot
      "Odds of winning the JACKPOT are 1 in %s" % @game_picker.odds.comma
    end

    def how_to_play
      puts "\n%s\n\n" % @game_picker
      puts "%s\n\n" % odds_of_winning_jackpot 
      self
    end

    def draw
      played_check
      @official_draw = @game_picker.pick
      @played = true
      official_draw
    end

    def payout(result)
      outcomes[result].payout
    end

    def buy_ticket(num_picks=1)
      played_check
      @plays += num_picks
      bank.credit(calculate_cost(num_picks))
      t = Ticket.new(self, num_picks)
      tickets << t
      t
    end

    def winning_tickets(top=3)
      tickets.sort {|a,b| b.winnings <=> a.winnings}[0...top]
    end

    def award_jackpot
      tickets.each do |ticket|
        ticket.award_any_jackpot
      end
    end

    def random_picks(num_picks)
      (1..num_picks).map {|n| @ticket_picker.pick}
    end

    def calculate_cost(num_picks)
      num_picks * cost
    end

    def match(pick)
      not_drawn_check

      matching_numbers = pick.matches(official_draw)
      numbers_matched = matching_numbers.map(&:length)
      pick.outcome = outcomes[numbers_matched]
      pick.outcome.count += 1
      bank.debit(pick.outcome.payout) unless pick.outcome.jackpot?
      pick.outcome
    end

    def played_check
      puts "already drawn" if played
    end

    def not_drawn_check
      puts "lottery not yet drawn" unless played
    end

    def init_outcomes
      @outcomes = {}
      payouts.each_pair { |numbers_matched, payout| 
        outcomes[numbers_matched] = Outcome.new(self, numbers_matched, payout)
      }
    end

    def jackpot_outcome
      @_jo ||= outcomes.values.select {|v| v.jackpot?}.first
    end

    NUM_TOP_WINNERS_TO_SHOW=10
    REPORT_INTERVAL=1000
    REPORTING_THRESHOLD=10000
    DEFAULT_TICKETS_TO_PLAY=1000
    DEFAULT_DRAWS_PER_TICKET=5

    def play(options={})
      num_tickets = options[:tickets].to_i||DEFAULT_TICKETS_TO_PLAY
      num_draws_per_ticket = options[:draws].to_i||DEFAULT_DRAWS_PER_TICKET

      report_msg("Buying tickets...", num_tickets)
      num_tickets.times {|i|
        buy_ticket(num_draws_per_ticket)
        report_count(i, num_tickets)
      }

      draw

      check_tickets
      winning_tickets(NUM_TOP_WINNERS_TO_SHOW).each {|t| t.wins}
      stats
      self
    end

    def check_tickets(options={})
      num_tickets = tickets.length
      report_msg("Checking tickets....", num_tickets)
      tickets.each_with_index {|ticket, i|
        ticket.check
        report_count(i, num_tickets)
      }
      self
    end

    def init_setup
      @current_jackpot = @start_jackpot
      @official_draw = nil
      @played = false
      @tickets = []
      @plays = 0
      @ticket_counter = 0
      init_outcomes
      self
    end

    def reset
      bank.reset
      init_setup
    end

    def stats
      outcomes.values.each { |v| v.stat}
      puts self
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
      "%s: %s tickets purchased, %s plays, current jackpot: %s" % 
        [name,
         tickets.length.comma,
         plays.comma,
         current_jackpot.money]
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
      "balance: #{balance.money}  (credits: #{credits.money}, debits: #{debits.money})"
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
      output @top_s
    end

    def sep
      output @sep_s
    end

    def bottom
      output @bottom_s
    end

    def lbreak
      output @lbreak_s
    end

    def center(str)
      side = width - 2 - str.length
      lmargin = side/2
      rmargin = side - lmargin
      output "%s %s%s%s %s" % [@vert_s, " "*lmargin, str, " "*rmargin, @vert_s]
    end

    def ljust(str)
      center(" %s%s" % [str, " "*(width-3-str.length)])
    end

    def output(str)
      puts str
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

