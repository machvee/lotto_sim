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
      print_picks
    end

    def print_picks
      numbers.map { |n_set|
        n_set.map {|n| "%02d" % n}.join("    ")
      }.join("  -  ")
    end

    def matches(lotto_draw)
      draws = lotto_draw.numbers.each
      numbers.map do |set|
        set & draws.next
      end
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
      @printer = lotto.printer
      @winnings = 0
      @checked = false
    end

    def print(only_winners=false)
      print_header
      print_picks(only_winners)
      print_footer
      nil
    end

    def wins
      return unless checked
      print(only_winners=true)
    end

    def print_header
      puts "\n"
      printer.top
      printer.center(" #{display_name}   Ticket: \##{number}")
      printer.sep
      if lotto.played
        printer.lbreak
        printer.center("**  %s  **" % lotto.official_draw)
      end
      printer.lbreak
      printer.ljust("Plays: #{num_picks}")
      printer.lbreak
    end

    def print_picks(only_winners=false)
      picks.each do |pick|
        next if only_winners && pick.outcome.payout == 0
        if checked
          printer.ljust("  %s%s" % [pick.print_picks, pick.outcome.nil? ? "" : ("   %s" % pick.outcome.print)])
        else
          printer.center("%s" % pick)
        end
      end
    end

    def print_footer
      printer.lbreak
      opt_winnings = checked ? ((" "*14) + "Winnings:  %s" % Lottery.currency_fmt(winnings)) : ""
      printer.ljust("Cost:  %s%s" % [Lottery.currency_fmt(cost), opt_winnings])
      printer.bottom
    end

    def display_name
      @dn ||= lotto.name.upcase.gsub(/(.)/, '\1 ')
    end

    def check
      unless lotto.played
        puts "lottery not drawn yet"
        return
      end
      return if checked
      picks.each do |pick|
        pick.outcome = lotto.pick_outcome(pick)
        @winnings += pick.outcome.payout
      end
      @checked = true
    end

    def inspect
      "Ticket #{number}: #{num_picks} picks for #{Lottery.currency_fmt(cost)}%s" % (checked ? (", winnings: %s" % Lottery.currency_fmt(winnings)) : "")
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
      @_odds ||= choose_multiple.to_f/picks_multiple
    end

    private 

    def picks_multiple
      @_npf ||= [*1..num_picks].inject(:*)
    end

    def choose_multiple
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
      jackpot? ? lotto.current_jackpot : pays
    end

    def jackpot?
      pays == JACKPOT
    end

    def to_s
      match.join("+")
    end

    def payout_s
      payout.zero? ? '' : ("%s%s" % [jackpot? ? "*** JACKPOT *** " : '', Lottery.currency_fmt(payout)])
    end

    def inspect
      to_s
    end

    def print
      " (%s)   %s" % [self, payout_s]
    end

    def stat
      perc = (count.to_f / lotto.plays) * 100.0
      puts "[%s] - %8s: %20s %20s %10.4f%%" % [
        self,
        Lottery.comma_sep_num(count),
        Lottery.currency_fmt(payout),
        Lottery.currency_fmt(count * payout),
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

    TICKET_PRINT_WIDTH=70
    TICKET_BORDER_COLOR=:green

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
    attr_reader     :printer
   
    def initialize(options={})
      config = options[:config]||DEFAULT_CONFIG
      @name = config[:name]
      @printer = BoxPrinter.new(TICKET_PRINT_WIDTH, TICKET_BORDER_COLOR)
      @game_picker = GamePicker.new(config[:numbers])
      @ticket_picker = GamePicker.new(config[:numbers])
      @start_jackpot = config[:start_jackpot]
      @bank = Bank.new(start_jackpot)
      @payouts = config[:payouts]
      @cost = config[:cost]
      init_setup
    end

    def next_ticket_number
      @ticket_counter += 1
    end

    def numbers_to_pick
    end

    def one_in_how_many_jackpot_odds
      @game_picker.odds
    end

    def odds_of_winning_jackpot
      "Odds of winning the JACKPOT are 1 in %s" % Lottery.comma_sep_num(@game_picker.odds)
    end

    def how_to_play
      puts @game_picker
      puts odds_of_winning_jackpot
    end

    def draw
      played_check
      @official_draw = @game_picker.pick
      @played = true
      official_draw
    end

    def pick_outcome(pick)
      match(pick)
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

    def random_picks(num_picks)
      (1..num_picks).map {|n| @ticket_picker.pick}
    end

    def calculate_cost(num_picks)
      num_picks * cost
    end

    def match(pick)
      raise "no offical_draw" if official_draw.nil?

      matching_numbers = pick.matches(official_draw)
      numbers_matched = matching_numbers.map(&:length)
      outcome = outcomes[numbers_matched]
      outcome.count += 1
      bank.debit(outcome.payout)
      outcome
    end

    def played_check
      raise "already drawn" if played
    end

    def init_outcomes
      @outcomes = {}
      payouts.each_pair { |numbers_matched, payout| 
        outcomes[numbers_matched] = Outcome.new(self, numbers_matched, payout)
      }
    end

    NUM_TOP_WINNERS_TO_SHOW=10
    REPORT_INTERVAL=1000
    REPORTING_THRESHOLD=10000
    DEFAULT_TICKETS_TO_PLAY=5
    DEFAULT_DRAWS_PER_TICKET=1

    def play(options={})
      num_tickets = options[:num_tickets]||DEFAULT_TICKETS_TO_PLAY
      num_draws_per_ticket = options[:num_draws_per_ticket]||DEFAULT_DRAWS_PER_TICKET
      quiet = options[:quiet]||false

      num_tickets.times {|i|
        buy_ticket(num_draws_per_ticket)
        puts(i) if i%REPORT_INTERVAL == 0 && num_tickets > REPORTING_THRESHOLD unless quiet
      }
      puts num_tickets unless quiet

      draw

      puts "Checking tickets...." unless quiet
      check_tickets(quiet: quiet)
      winning_tickets(NUM_TOP_WINNERS_TO_SHOW).each {|t| t.wins}
      self
    end

    def check_tickets(options={})
      quiet = options[:quiet] || false
      num_tickets = tickets.length
      tickets.each_with_index {|ticket, i|
        ticket.check
        puts(i) if i%REPORT_INTERVAL == 0 && num_tickets > REPORTING_THRESHOLD unless quiet
      }
      puts num_tickets unless quiet
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
      self
    end

    def inspect
      to_s
    end

    def to_s
      "%s: %s tickets purchased, %s plays, current jackpot: %s" % 
        [name,
         Lottery.comma_sep_num(tickets.length),
         Lottery.comma_sep_num(plays),
         Lottery.currency_fmt(current_jackpot)]
    end

    def self.comma_sep_num(num)
      num.to_s.chars.reverse.each_slice(3).map(&:join).join(",").reverse
    end

    def self.currency_fmt(amt)
      "$%s.00" % Lottery.comma_sep_num(amt)
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
      "balance: #{Lottery.currency_fmt(balance)}  (credits: #{Lottery.currency_fmt(credits)}, debits: #{Lottery.currency_fmt(debits)})"
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
