# blackjack-lua

[![CI](https://github.com/gdonald/blackjack-lua/actions/workflows/ci.yml/badge.svg)](https://github.com/gdonald/blackjack-lua/actions/workflows/ci.yml)

Command line blackjack written in Lua.  Requires Lua 5.4 or later.

## Clone

    git clone https://github.com/gdonald/blackjack-lua.git

## Run

    cd blackjack-lua

    ./blackjack.lua

## Run tests

    ./run_tests.sh

Coverage comes from [LuaCov](https://lunarmodules.github.io/luacov/):

    luarocks install luacov

The runner prints coverage per module, writes the annotated report to `luacov.report.out`, and exits non-zero if any line goes uncovered.

## Terminal

Increase your terminal font size to see the cards better:

![Blackjack](https://raw.githubusercontent.com/gdonald/blackjack-lua/main/ss1.png)

![Blackjack](https://raw.githubusercontent.com/gdonald/blackjack-lua/main/ss2.png)

### Features

* Alternate Deck Types
* Variable Number of Decks
* Hand Splitting
* Vegas-style Dealer Play (Dealer hits on soft 16)
* Options Saving

### Bugs / Issues / Feature Requests

[https://github.com/gdonald/blackjack-lua/issues](https://github.com/gdonald/blackjack-lua/issues)

## License

[![GitHub](https://img.shields.io/github/license/gdonald/blackjack-lua?color=aa0000)](https://github.com/gdonald/blackjack-lua/blob/master/LICENSE)

### Other Blackjack Implementations:

I've written Blackjack in [some other programming languages](https://github.com/gdonald?tab=repositories&q=blackjack&type=public&language=&sort=stargazers) too.  Check them out!
