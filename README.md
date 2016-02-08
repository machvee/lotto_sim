# lotto_sim


##Supports the following Lotteries:
- LottoSim::Powerball.new
- LottoSim::MegaMillions.new
- LottoSim::FloridaLotto.new

##Quick Runs
   - Run the Powerball with 12,000 ticket purchases, each with 10 plays
   
```
$ ruby -I. run_powerball.rb 12000
Buying tickets...
0
1000
2000
3000
4000
5000
6000
7000
8000
9000
10000
11000
Checking tickets....
0
1000
2000
3000
4000
5000
6000
7000
8000
9000
10000
11000

╔══════════════════════════════════════════════════════════════════════╗
║                  P O W E R B A L L    Ticket: #9680                  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║              **  01    11    19    54    59  -  10  **               ║
║                                                                      ║
║  Plays: 10                                                           ║
║                                                                      ║
║    11    18    19    41    59  -  10    (3+1)   $100.00              ║
║                                                                      ║
║  Cost:  $20.00              Winnings:  $100.00                       ║
╚══════════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════════╗
║                  P O W E R B A L L    Ticket: #2752                  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║              **  01    11    19    54    59  -  10  **               ║
║                                                                      ║
║  Plays: 10                                                           ║
║                                                                      ║
║    01    11    19    21    45  -  10    (3+1)   $100.00              ║
║                                                                      ║
║  Cost:  $20.00              Winnings:  $100.00                       ║
╚══════════════════════════════════════════════════════════════════════╝
...
[5+1] -           0:         $40,000,000.00                  $0.00   0.000000%
[5+0] -           0:          $1,000,000.00                  $0.00   0.000000%
[4+1] -           0:             $50,000.00                  $0.00   0.000000%
[4+0] -           7:                $100.00                $700.00   0.005833%
[3+1] -           9:                $100.00                $900.00   0.007500%
[3+0] -         195:                  $7.00              $1,365.00   0.162500%
[2+1] -         150:                  $7.00              $1,050.00   0.125000%
[1+1] -       1,366:                  $4.00              $5,464.00   1.138333%
[0+1] -       3,135:                  $4.00             $12,540.00   2.612500%
[2+0] -       4,322:                  $0.00                  $0.00   3.601667%
[1+0] -      32,562:                  $0.00                  $0.00  27.135000%
[0+0] -      78,254:                  $0.00                  $0.00  65.211667%
PowerBall: 12,000 tickets purchased, 120,000 plays, current jackpot: $40,000,000.00
balance: $40,217,981.00  (credits: $240,000.00, debits: $22,019.00)
```

##Configuring New Lotteries
```ruby
  require 'lotto_sim'
  
  MY_STATE_LOTTERY_CONFIG = {
    name: "My State",
    cost:  1,
    start_jackpot: 1_000_000,
    numbers: [
      {
        num_picks: 5, # pick 5 numbers between 1 and 60
        picks_max: 60
      },
      {
        num_picks: 1, # and 1 number between 1 and 20
        picks_max: 20
      }
    ],
    payouts: {
      [5, 1] =>   JACKPOT,      [5, 0] => 1_000_000,
      [4, 1] =>    10_000,      [4, 0] =>       100,
      [3, 1] =>       100,      [3, 0] =>         3,
      [2, 1] =>         3,      [1, 1] =>         2,
      [0, 1] =>         1,      [2, 0] =>         0,
      [1, 0] =>         0,      [0, 0] =>         0
    }
  }
  
  class MyStateLottery < LottoSim::Lottery
    def initialize(options={})
      super(options.merge(config: MY_STATE_LOTTERY_CONFIG))
    end
  end
  
  ms = MyStateLottery.new
  ms.buy_ticket
  ms.draw
  ms.stats
```

##Usage:
```ruby
> require 'lotto_sim'
> p = LottoSim::Powerball.new
> p.how_to_play

Pick 5 numbers between 1 and 69, then pick 1 number between 1 and 26

Odds of winning the JACKPOT are 1 in 292,201,338

=> PowerBall: 0 tickets purchased, 0 plays, current jackpot: $40,000,000.00
> t = p.buy_ticket(num_picks: 5)
> t.print
╔══════════════════════════════════════════════════════════════════════╗
║                    P O W E R B A L L    Ticket: #1                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Plays: 5                                                            ║
║                                                                      ║
║                  20    38    39    43    61  -  06                   ║
║                  18    19    24    31    57  -  21                   ║
║                  42    50    61    63    69  -  06                   ║
║                  01    07    10    25    34  -  19                   ║
║                  05    13    17    20    35  -  19                   ║
║                                                                      ║
║  Cost:  $20.00                                                       ║
╚══════════════════════════════════════════════════════════════════════╝
> t2 = p.buy_ticket(
    numbers: [[[ 1,17,31,45,62], [11]], 
              [[31,46,54,57,68], [20]]]
  )
> t2.print
╔══════════════════════════════════════════════════════════════════════╗
║                    P O W E R B A L L    Ticket: #2                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Plays: 2                                                            ║
║                                                                      ║
║                  01    17    31    45    62  -  11                   ║
║                  31    46    54    57    68  -  20                   ║
║                                                                      ║
║  Cost:  $4.00                                                        ║
╚══════════════════════════════════════════════════════════════════════╝
> p.draw
=> 32    33    42    54    63  -  03
> p.check_tickets
> p.winning_tickets.map(&:print)

╔══════════════════════════════════════════════════════════════════════╗
║                    P O W E R B A L L    Ticket: #4                   ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║              **  32    33    42    54    63  -  03  **               ║
║                                                                      ║
║  Plays: 1                                                            ║
║                                                                      ║
║    18    27    28    35    36  -  03    (0+1)   $4.00                ║
║                                                                      ║
║  Cost:  $2.00              Winnings:  $4.00                          ║
╚══════════════════════════════════════════════════════════════════════╝
> p.stats
[5+1] -           0:         $40,000,000.00                  $0.00   0.000000%
[5+0] -           0:          $1,000,000.00                  $0.00   0.000000%
[4+1] -           0:             $50,000.00                  $0.00   0.000000%
[4+0] -           0:                $100.00                  $0.00   0.000000%
[3+1] -           0:                $100.00                  $0.00   0.000000%
[3+0] -           0:                  $7.00                  $0.00   0.000000%
[2+1] -           0:                  $7.00                  $0.00   0.000000%
[1+1] -           0:                  $4.00                  $0.00   0.000000%
[0+1] -           1:                  $4.00                  $4.00   7.692308%
[2+0] -           1:                  $0.00                  $0.00   7.692308%
[1+0] -           2:                  $0.00                  $0.00  15.384615%
[0+0] -           9:                  $0.00                  $0.00  69.230769%
PowerBall: 4 tickets purchased, 13 plays, current jackpot: $40,000,000.00
balance: $40,000,022.00  (credits: $26.00, debits: $4.00)
=> PowerBall: 4 tickets purchased, 13 plays, current jackpot: $40,000,000.00
>
```

## Lottery Runs with Repeatable Random Sequences
The default Lottery Randomizer will generate tickets and draws from a system seed and yields varying sequences each time a lottery is run.   If you want repeatable sequences for testing or for comparisons between different runs, use the SeededRandomizer
```ruby
require 'lotto_sim'
include LottoSim
my_seed = 98762345
p = Powerball.new(randomizer: SeededRandomizer.new(my_seed))
10.times {p.buy_ticket(num_picks: 10)}
p.draw
=> 04    31    33    40    51  -  25
p.check_tickets
p.stats
[5+1] -           0:         $40,000,000.00                  $0.00   0.000000%
[5+0] -           0:          $1,000,000.00                  $0.00   0.000000%
[4+1] -           0:             $50,000.00                  $0.00   0.000000%
[4+0] -           0:                $100.00                  $0.00   0.000000%
[3+1] -           0:                $100.00                  $0.00   0.000000%
[3+0] -           1:                  $7.00                  $7.00   1.000000%
[2+1] -           0:                  $7.00                  $0.00   0.000000%
[1+1] -           0:                  $4.00                  $0.00   0.000000%
[0+1] -           1:                  $4.00                  $4.00   1.000000%
[2+0] -           2:                  $0.00                  $0.00   2.000000%
[1+0] -          19:                  $0.00                  $0.00  19.000000%
[0+0] -          77:                  $0.00                  $0.00  77.000000%
PowerBall: 10 tickets purchased, 100 plays, current jackpot: $40,000,000.00
balance: $40,000,189.00  (credits: $200.00, debits: $11.00)
=> PowerBall: 10 tickets purchased, 100 plays, current jackpot: $40,000,000.00
```
All Powerball lotteries run with the same my_seed above in the SeededRandomizer will yield the same outcomes

