class Pick 
  attr_reader    :lotto
  attr_reader    :numbers
  attr_accessor  :power
  attr_accessor  :outcome

  PICK_COLOR=:red

  def initialize(numbers)
    @lotto = lotto
    @numbers = numbers
    @power = nil
    @outcome = nil
  end

  def to_s
    print_picks
  end

  def print_picks
    output = ""
    output << numbers.map { |n| 
      n_str = "%02d" % n
      n_str
    }.join("    ") 

    unless power.nil? 
      p_str = "  -  %02d"  % power
      output << p_str
    end
    output
  end

  def inspect
    to_s
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
    "balance: #{LottoSim.currency_fmt(balance)}  (credits: #{LottoSim.currency_fmt(credits)}, debits: #{LottoSim.currency_fmt(debits)})"
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


class Ticket 
  attr_reader  :lotto
  attr_reader  :number
  attr_reader  :num_picks
  attr_reader  :picks
  attr_reader  :cost
  attr_reader  :winnings
  attr_reader  :checked

  TICKET_PRINT_WIDTH=70

  def initialize(lotto, num_picks)
    @lotto = lotto
    @number = lotto.next_ticket_number
    @num_picks = num_picks
    @picks = lotto.random_picks(num_picks)
    @cost = lotto.calculate_cost(num_picks)
    @printer = BoxPrinter.new(TICKET_PRINT_WIDTH, :green)
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
    @printer.top
    @printer.center(" #{display_name}   Ticket: \##{number}")
    @printer.sep
    if lotto.played
      @printer.lbreak
      @printer.center("**  %s  **" % lotto.official_draw)
    end
    @printer.lbreak
    @printer.ljust("Plays: #{num_picks}")
    @printer.lbreak
  end

  def print_picks(only_winners=false)
    picks.each do |pick|
      next if only_winners && pick.outcome.payout == 0
      if checked
        @printer.ljust("  %s%s" % [pick.print_picks, pick.outcome.nil? ? "" : ("   %s" % pick.outcome)])
      else
        @printer.center("%s" % pick)
      end
    end
  end

  def print_footer
    @printer.lbreak
    opt_winnings = checked ? ((" "*14) + "Winnings:  %s" % LottoSim.currency_fmt(winnings)) : ""
    @printer.ljust("Cost:  %s%s" % [LottoSim.currency_fmt(cost), opt_winnings])
    @printer.bottom
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
    "Ticket #{number}: #{num_picks} picks for #{LottoSim.currency_fmt(cost)}%s" % (checked ? (", winnings: %s" % LottoSim.currency_fmt(winnings)) : "")
  end
end


class Generator

  attr_reader   :num_picks
  attr_reader   :pick_array
  attr_reader   :power_range
  attr_reader   :power_array
  attr_accessor :power_max
  attr_reader   :numbers_prng
  attr_reader   :power_prng

  def initialize(options={})
    #
    # usage: Generator.new(5, 69[, 26])
    #    generates 5 numbers chosen from 1 to 69, and 1 number 1 to 26
    #
    #
    @num_picks = options[:num_picks]
    @pick_array = [*1..options[:picks_max]]
    if options[:power_max]
      self.power_max = options[:power_max]
    end
    @numbers_prng = Random.new
    @power_prng = Random.new
  end

  def power_max=(val)
    @power_max = val.to_i
    @power_range = 1..@power_max
    @power_array = [*power_range]
  end

  def pick
    # returns Hash {numbers: [n,..., n][, power: m} randomly
    pick = Pick.new(gen_numbers)
    pick.power = gen_power if has_power?
    pick
  end

  def has_power?
    !@power_range.nil?
  end
  
  private 

  def gen_numbers
    pick_array.shuffle(random: numbers_prng)[0...num_picks].sort
  end

  def gen_power
    power_array.shuffle(random: power_prng)[0]
  end
end

JACKPOT = 'J'

class Outcome
  attr_reader :numbers_matched
  attr_reader :power_match
  attr_reader :lotto
  attr_reader :pays

  attr_accessor :count

  def initialize(lotto, numbers_matched, power_match, pays)
    @lotto = lotto
    @numbers_matched = numbers_matched
    @power_match = power_match
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
    "(%s%s)  %s" % [numbers_matched, power_fmt, payout_s]
  end

  def payout_s
    payout.zero? ? '' : ("%s%s" % [jackpot? ? "*** JACKPOT *** " : '', LottoSim.currency_fmt(payout)])
  end

  def inspect
    to_s
  end

  def power_fmt
    power_match.nil? ? '' : "+#{power_match}"
  end

  def print
    puts "[%d%s] - %8s: %20s" % [
      numbers_matched,
      power_fmt,
      LottoSim.comma_sep_num(count),
      LottoSim.currency_fmt(count * payout)
    ]
  end
end

class LottoSim

  POWERBALL = {
    name: "PowerBall",
    cost:  2,
    start_jackpot: 40_000_000,
    numbers: {
      num_picks: 5,
      picks_max: 69,
      power_max: 26,
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

  MEGA_MILLIONS = {
    name: "Mega Millions",
    cost:  1,
    start_jackpot: 15_000_000,
    numbers: {
      num_picks: 5,
      picks_max: 75,
      power_max: 15,
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

  FLORIDA_LOTTO = {
    name: "Florida Lotto",
    cost:  1,
    start_jackpot: 1_000_000,
    numbers: {
      num_picks: 6,
      picks_max: 53
    },
    payouts: {
      [6, nil] =>   JACKPOT,
      [5, nil] =>     5_000,
      [4, nil] =>        70,
      [3, nil] =>         5,
      [2, nil] =>         0,
      [1, nil] =>         0,
      [0, nil] =>         0
    }
  }

  DEFAULT_CONFIG = MEGA_MILLIONS

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
 
  def initialize(options={})
    config = options[:config]||DEFAULT_CONFIG
    @name = config[:name]
    @game_picker = Generator.new(config[:numbers])
    @ticket_picker = Generator.new(config[:numbers])
    @start_jackpot = config[:start_jackpot]
    @bank = Bank.new(start_jackpot)
    @payouts = config[:payouts]
    @cost = config[:cost]
    init_setup
  end

  def next_ticket_number
    @ticket_counter += 1
  end

  def self.powerball
    new(config: POWERBALL)
  end

  def self.mega_millions
    new(config: MEGA_MILLIONS)
  end

  def self.florida
    new(config: FLORIDA_LOTTO)
  end

  def draw
    played_check
    @official_draw = @game_picker.pick
    @played = true
    official_draw
  end

  def pick_outcome(pick)
    outcome = match(pick)
    outcome
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

  def check_tickets
    tickets.each {|ticket| ticket.check}
    self
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
    matching_numbers, matching_power = matches(pick)
    numbers_matched = matching_numbers.length
    power_match = case matching_power
      when nil,0
        matching_power
      else
        1
    end
    outcome = outcomes[[numbers_matched, power_match]]
    outcome.count += 1
    bank.debit(outcome.payout)
    outcome
  end

  def matches(pick)
    matching_numbers = official_draw.numbers & pick.numbers
    matching_power = has_power? ? (official_draw.power == pick.power ? pick.power : 0) : nil
    [matching_numbers, matching_power]
  end

  def has_power?
    @game_picker.has_power?
  end

  def played_check
    raise "already drawn" if played
  end

  def init_outcomes
    @outcomes = {}
    payouts.each_pair { |(numbers_matched, power_match), payout| 
      outcomes[[numbers_matched, power_match]] = Outcome.new(self, numbers_matched, power_match, payout)
    }
  end

  def play(num_tickets=5, num_draws_per_ticket=1)
    num_tickets.times {|i| 
      buy_ticket(num_draws_per_ticket)
      puts(i) if i%1000 == 0 && num_tickets > 10000
    }
    draw
    check_tickets
    winning_tickets(10).each {|t| t.wins}
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
    outcomes.each_pair { |k,v|
      v.print
    }
    self
  end

  def inspect
    to_s
  end

  def to_s
    "%s: %s tickets purchased, %s plays, current jackpot: %s" % 
      [name,
       LottoSim.comma_sep_num(tickets.length),
       LottoSim.comma_sep_num(plays),
       LottoSim.currency_fmt(current_jackpot)]
  end

  def self.comma_sep_num(num)
    num.to_s.chars.reverse.each_slice(3).map(&:join).join(",").reverse
  end

  def self.currency_fmt(amt)
    "$%s.00" % LottoSim.comma_sep_num(amt)
  end
end

class Powerball < LottoSim
  def initialize(options={})
    super(options.merge(config: POWERBALL))
  end
end

class MegaMillions < LottoSim
  def initialize(options={})
    super(options.merge(config: MEGA_MILLIONS))
  end
end

class FloridaLotto < LottoSim
  def initialize(options={})
    super(options.merge(config: FLORIDA_LOTTO))
  end
end
