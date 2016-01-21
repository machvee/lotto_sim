Pick = Struct.new(:numbers, :power, :outcome) do
  def to_s
    numbers.map {|n| "%02d" % n}.join("  ") + (power.nil? ? "" : " - %02d" % power)
  end
  def inspect
    to_s
  end
end

Outcome = Struct.new(:result, :winnings) do
  def to_s
    "(%d%s)   $%d.00" % [result[0], (result[1].nil? ? "" : ("+%d" % result[1])), winnings]
  end
end

class Bank
  attr_reader  :credits
  attr_reader  :debits
  attr_reader  :balance

  def initialize(start_balance)
    @balance = start_balance
    @credits = 0
    @debits = 0
  end

  def credit(amt)
    @credits += amt
    @balance += amt
  end

  def debit(amt)
    @debits += amt
    @balance -= amt
  end

  def to_s
    "balance: $#{balance}  (credits: $#{credits}.00, debits: $#{debits}.00)"
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
  attr_reader  :outcomes
  attr_reader  :cost
  attr_reader  :winnings
  attr_reader  :checked

  def initialize(lotto, num_picks)
    @lotto = lotto
    @number = lotto.next_ticket_number
    @num_picks = num_picks
    @picks = lotto.random_picks(num_picks)
    @cost = lotto.calculate_cost(num_picks)
    @winnings = 0
    @checked = false
  end

  def print(wins=false)
    len = print_header
    print_picks(checked ? 2 : 6, wins)
    puts "\n"
    puts "   Cost:  $#{cost}.00%s" % (checked ? ("      Winnings:  $%d.00" % winnings) : "")
    puts "="*len
    nil
  end

  def wins
    print(true)
  end

  def print_header
    puts "\n"
    header = ("="*8) + " #{lotto.name} Ticket \##{number} " + ("="*8)  
    puts header
    if lotto.played
      puts "\n"
      puts " DRAW  %s  DRAW" % lotto.official_draw
    end
    puts "\n"
    header.length
  end

  def print_picks(lead=8, winners=false)
    picks.each do |pick|
      next if winners && pick.outcome.winnings == 0
      puts "%s %s%s" % [" "*lead, pick, pick.outcome.nil? ? "" : (" %s" % pick.outcome)]
    end
  end

  def check
    unless lotto.played
      puts "lottery not drawn yet"
      return
    end
    return if checked
    picks.each do |pick|
      pick.outcome = Outcome.new
      pick.outcome.result, pick.outcome.winnings = lotto.pick_pays(pick)
      @winnings += pick.outcome.winnings
    end
    @checked = true
  end

  def inspect
    "Ticket #{number}: #{num_picks} picks for $#{cost}.00%s" % (checked ? (", winnings: $%d.00" % winnings) : "")
  end
end


class Generator

  attr_reader   :num_picks
  attr_reader   :pick_range
  attr_reader   :power_range
  attr_accessor :power_max
  attr_reader   :prng

  def initialize(options={})
    #
    # usage: Generator.new(5, 69[, 26])
    #    generates 5 numbers chosen from 1 to 69, and 1 number 1 to 26
    #
    #
    @num_picks = options[:num_picks]
    @pick_range = 1..options[:picks_max]
    if options[:power_max]
      self.power_max = options[:power_max]
    end
    @prng = Random.new
  end

  def power_max=(val)
    @power_max = val.to_i
    @power_range = 1..@power_max
  end

  def pick
    # returns Hash {numbers: [n,..., n][, power: m} randomly
    pick = Pick.new
    numbers = []
    while numbers.length < num_picks
      num = prng.rand(pick_range)
      numbers << num unless numbers.include?(num)
    end
    numbers.sort!
    pick.numbers = numbers
    unless power_range.nil?
      pick.power = prng.rand(power_range)
    end
    pick.outcome = nil
    pick
  end

  def has_power?
    !@power_range.nil?
  end

end

class Play
  #
  # - choose the lotto game
  # - create the sim
  # - buy tickets
  #   - keep track of $ spent
  #   - allow a variable # of tickets
  #   - keep draws
  # - offical draw
  # - determine # tickets won
  # - keep $ value won
  # - stats on winners/losers
  #    - 0 0  num occurences  money won/lost
  #    - 0 1
  #       ...
  #
end

class LottoSim

  JACKPOT = 'J'

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

  GAMES = {
         mega: MEGA_MILLIONS,
    powerball: POWERBALL,
      florida: FLORIDA_LOTTO
  }

  attr_reader     :played
  attr_reader     :official_draw # the current, official evening draw
  attr_reader     :name
  attr_reader     :cost
  attr_reader     :tickets
  attr_reader     :payouts
  attr_reader     :start_jackpot
  attr_accessor   :current_jackpot
  attr_reader     :ticket_counter
  attr_reader     :bank
 
  def initialize(options={})
    config = options[:config]||DEFAULT_CONFIG
    @name = config[:name]
    @game_picker = Generator.new(config[:numbers])
    @ticket_picker = Generator.new(config[:numbers])
    @start_jackpot = config[:start_jackpot]
    @payouts = config[:payouts]
    @cost = config[:cost]
    reset
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

  def pick_pays(pick)
    matches = match(pick)
    amt_won = payout(matches)
    bank.debit(amt_won)
    [matches, amt_won]
  end

  def payout(result)
    amt = payouts[result]
    amt == JACKPOT ? current_jackpot : amt
  end

  def buy_ticket(num_picks=1)
    played_check
    bank.credit(calculate_cost(num_picks))
    t = Ticket.new(self, num_picks)
    tickets << t
    t
  end

  def check_tickets
    tickets.each {|ticket| ticket.check}
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
    #
    # compare the pick against the current official draw
    # return a Result(:numbers_matched, :power_matched)
    #
    raise "no offical_draw" if official_draw.nil?
    result = []
    result[0] = (official_draw.numbers & pick.numbers).length
    result[1] = has_power? ? (official_draw.power == pick.power ? 1 : 0) : nil
    result
  end

  def has_power?
    @game_picker.has_power?
  end

  def played_check
    raise "already drawn" if played
  end

  def reset
    @current_jackpot = @start_jackpot
    @official_draw = nil
    @played = false
    @tickets = []
    @ticket_counter = 0
    @bank = Bank.new(start_jackpot)
  end

  def pick_till_win(desired_numbers, desired_power_ball, max_tries=-1)
    validate(desired_numbers, desired_power_ball)
    clear_stats
    desired_numbers.sort!
    while @count < max_tries || max_tries < 0 do
      p = pickem
      r = results(desired_numbers, desired_power_ball)
      stats(r)
      puts "#@count: #{p.inspect}" + " ==> " +
            r[:matched].inspect + " #{r[:power_matched] ? desired_power_ball : '*'}" if notable?(r)
      break if winner?(r)
    end
    puts desired_numbers.inspect + " - #{desired_power_ball}"
    print_stats
  end

  def notable?(res)
    rl = res[:matched].length
    rl >= @notables[0] || (res[:power_matched] && rl >= @notables[1])
  end

  def winner?(res)
    res[:matched].length == num_chosen && res[:power_matched]
  end

  def validate(numbers, power_ball)
    raise "too few numbers" if numbers.length < num_chosen
    raise "numbers must be unique" if numbers.uniq.length < numbers.length
    raise "invalid numbers" if numbers.any? {|n| n > max || n < 1}
    raise "invalid power ball" if power_ball > power_max || power_ball < 1
  end

  def clear_stats
    @count = 0
    @numbers_matched = [0]*(num_chosen+1)
    @numbers_matched_plus = [0]*(num_chosen+1)
    @power_balls_matched = 0
  end

  def stats(res)
    @count += 1
    if res[:power_matched]
      @numbers_matched_plus[res[:matched].length] += 1 
      @power_balls_matched += 1 
    else
      @numbers_matched[res[:matched].length] += 1
    end
  end

  def print_stats
    puts "#@count rolls"
    (num_chosen+1).times do |i|
      puts "#{i} numbers matched: #{@numbers_matched[i]}/#{@numbers_matched_plus[i]}*"
    end
    puts "power balls matched: #@power_balls_matched"
  end

  def results(desired_numbers, desired_power_ball)
    {:matched => numbers & desired_numbers, :power_matched => power_ball == desired_power_ball}
  end
end
