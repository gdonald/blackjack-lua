local harness = require('tests.harness')
local support = require('tests.support')
local Game = require('bj.game')
local Card = require('bj.card')
local Shoe = require('bj.shoe')
local Hand = require('bj.hand')
local PlayerHand = require('bj.player_hand')
local DealerHand = require('bj.dealer_hand')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false
local assert_contains, spy, call_count = harness.assert_contains, harness.spy, harness.call_count
local Soft, Hard = Hand.CountMethod.Soft, Hand.CountMethod.Hard
local HandStatus = PlayerHand.HandStatus

local scratch_save_file = 'tests/tmp/bj.txt'

local function new_game()
  local load_game = Game.load_game
  Game.load_game = function() end
  local game = Game.new()
  Game.load_game = load_game

  game.clear = spy()
  game.write = spy()
  game.buffer = spy()
  game.unbuffer = spy()
  game.save_game = spy()
  game.read_char = support.no_keys()

  return game
end

local function fake_dealer_hand(fields)
  local dealer_hand = fields or {}
  dealer_hand.get_value = dealer_hand.get_value or spy(18)
  dealer_hand.is_busted = dealer_hand.is_busted or spy(false)
  dealer_hand.is_blackjack = dealer_hand.is_blackjack or spy(false)
  dealer_hand.deal_card = dealer_hand.deal_card or spy()
  dealer_hand.to_string = dealer_hand.to_string or spy(' A♠ ?? ⇒  11')
  return dealer_hand
end

local function fake_player_hand(fields)
  local player_hand = fields or {}
  player_hand.bet = player_hand.bet or 1000
  if player_hand.paid == nil then
    player_hand.paid = false
  end
  player_hand.get_value = player_hand.get_value or spy(20)
  player_hand.is_busted = player_hand.is_busted or spy(false)
  player_hand.is_blackjack = player_hand.is_blackjack or spy(false)
  player_hand.is_done = player_hand.is_done or spy(false)
  player_hand.deal_card = player_hand.deal_card or spy()
  player_hand.get_action = player_hand.get_action or spy()
  player_hand.process = player_hand.process or spy()
  player_hand.to_string = player_hand.to_string or spy(' 5♣ 6♦ ⇒  11 $5.00\n')
  return player_hand
end

local function write_save_file(contents)
  os.execute('mkdir -p tests/tmp')
  local file = io.open(scratch_save_file, 'w')
  file:write(contents)
  file:close()
end

describe('Game', function()
  it('starts with a shoe, a bankroll, and no hands dealt', function()
    local game = new_game()
    assert_equal(getmetatable(game.shoe), Shoe)
    assert_equal(game.deck_type, 1)
    assert_equal(game.face_type, 1)
    assert_equal(game.money, 10000)
    assert_equal(game.current_bet, 500)
    assert_equal(game.dealer_hand, nil)
    assert_equal(game.current_player_hand, 0)
    assert_equal(#game.player_hands, 0)
    assert_false(game.quitting)
  end)

  it('keeps the save file name and betting limits', function()
    assert_equal(Game.save_file, 'bj.txt')
    assert_equal(Game.min_bet, 500)
    assert_equal(Game.max_bet, 10000000)
  end)

  it('totals the bets across every hand', function()
    local game = new_game()
    game.player_hands = { { bet = 500 }, { bet = 1000 }, { bet = 750 } }

    assert_equal(game:all_bets(), 2250)
  end)

  it('totals no bets with no hands', function()
    local game = new_game()
    game.player_hands = {}

    assert_equal(game:all_bets(), 0)
  end)

  it('draws the plain card face for face type one', function()
    local game = new_game()
    game.face_type = 1

    assert_equal(game:card_face(0, 0), Card.faces[1][1])
    assert_equal(game:card_face(13, 0), Card.faces[14][1])
  end)

  it('draws the alternate card face for face type two', function()
    local game = new_game()
    game.face_type = 2

    assert_equal(game:card_face(0, 0), Card.faces2[1][1])
  end)

  it('draws the dealer hand, the money, and every player hand', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand()
    game.player_hands = { fake_player_hand() }
    game.money = 10000

    game:draw_hands()

    assert_equal(call_count(game.clear), 1)
    local out = game.write.calls[1][2]
    assert_contains(out, 'Dealer:')
    assert_contains(out, 'Player $100.00:')
    assert_contains(out, '$5.00')
  end)

  it('raises a bet under the minimum', function()
    local game = new_game()
    game.current_bet = 100

    game:normalize_bet()

    assert_equal(game.current_bet, Game.min_bet)
  end)

  it('caps a bet over the maximum', function()
    local game = new_game()
    game.money = 20000000
    game.current_bet = 20000000

    game:normalize_bet()

    assert_equal(game.current_bet, Game.max_bet)
  end)

  it('caps a bet at the money on hand', function()
    local game = new_game()
    game.money = 1000
    game.current_bet = 2000

    game:normalize_bet()

    assert_equal(game.current_bet, 1000)
  end)

  it('leaves a bet within the limits alone', function()
    local game = new_game()
    game.money = 10000
    game.current_bet = 1000

    game:normalize_bet()

    assert_equal(game.current_bet, 1000)
  end)

  it('has more hands to play before the last hand', function()
    local game = new_game()
    game.player_hands = { {}, {}, {} }
    game.current_player_hand = 1

    assert_true(game:more_hands_to_play())
  end)

  it('has no more hands to play on the last hand', function()
    local game = new_game()
    game.player_hands = { {}, {}, {} }
    game.current_player_hand = 2

    assert_false(game:more_hands_to_play())
  end)

  it('plays the dealer hand when a hand is still live', function()
    local game = new_game()
    game.player_hands = {
      fake_player_hand({ is_busted = spy(false), is_blackjack = spy(false) }),
      fake_player_hand({ is_busted = spy(true), is_blackjack = spy(false) }),
    }

    assert_true(game:need_to_play_dealer_hand())
  end)

  it('skips the dealer hand when every hand is busted or blackjack', function()
    local game = new_game()
    game.player_hands = {
      fake_player_hand({ is_busted = spy(true), is_blackjack = spy(false) }),
      fake_player_hand({ is_busted = spy(false), is_blackjack = spy(true) }),
    }

    assert_false(game:need_to_play_dealer_hand())
  end)

  it('pays a hand that beats the dealer', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(18) })
    local hand = fake_player_hand({ get_value = spy(20), bet = 1000 })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_true(hand.paid)
    assert_equal(hand.status, HandStatus.Won)
    assert_equal(game.money, 11000)
  end)

  it('takes the bet from a hand that loses to the dealer', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(20) })
    local hand = fake_player_hand({ get_value = spy(18), bet = 1000 })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_true(hand.paid)
    assert_equal(hand.status, HandStatus.Lost)
    assert_equal(game.money, 9000)
  end)

  it('leaves the money alone on a push', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(20) })
    local hand = fake_player_hand({ get_value = spy(20), bet = 1000 })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_true(hand.paid)
    assert_equal(hand.status, HandStatus.Push)
    assert_equal(game.money, 10000)
  end)

  it('pays a blackjack three to two', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(18) })
    local hand = fake_player_hand({ get_value = spy(21), is_blackjack = spy(true), bet = 1000 })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_equal(hand.status, HandStatus.Won)
    assert_equal(hand.bet, 1500)
    assert_equal(game.money, 11500)
  end)

  it('pays every hand when the dealer busts', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(24), is_busted = spy(true) })
    local hand = fake_player_hand({ get_value = spy(18), bet = 1000 })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_true(hand.paid)
    assert_equal(hand.status, HandStatus.Won)
    assert_equal(game.money, 11000)
  end)

  it('skips a hand that was already paid', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ get_value = spy(18) })
    local hand = fake_player_hand({ get_value = spy(20), bet = 1000, paid = true })
    game.player_hands = { hand }
    game.money = 10000

    game:pay_hands()

    assert_equal(game.money, 10000)
  end)

  it('reveals the down card when the dealer has blackjack', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand({ is_blackjack = spy(true), hide_down_card = true })
    game.need_to_play_dealer_hand = spy(false)
    game.pay_hands = spy()

    game:play_dealer_hand()

    assert_false(game.dealer_hand.hide_down_card)
    assert_true(game.dealer_hand.played)
  end)

  it('pays out without drawing when the dealer does not need to play', function()
    local game = new_game()
    game.dealer_hand = fake_dealer_hand()
    game.need_to_play_dealer_hand = spy(false)
    game.pay_hands = spy()

    game:play_dealer_hand()

    assert_true(game.dealer_hand.played)
    assert_equal(call_count(game.pay_hands), 1)
    assert_equal(call_count(game.dealer_hand.deal_card), 0)
  end)

  it('draws until the dealer reaches a standing count', function()
    local game = new_game()
    local counts = spy()
    counts.results = { 16, 16, 18, 18 }
    game.dealer_hand = fake_dealer_hand({ get_value = counts, hide_down_card = true })
    game.need_to_play_dealer_hand = spy(true)
    game.pay_hands = spy()

    game:play_dealer_hand()

    assert_false(game.dealer_hand.hide_down_card)
    assert_equal(call_count(game.dealer_hand.deal_card), 1)
    assert_true(game.dealer_hand.played)
  end)

  it('writes the settings to the save file', function()
    local save_file = Game.save_file
    Game.save_file = scratch_save_file
    os.execute('mkdir -p tests/tmp')

    local game = new_game()
    game.save_game = Game.save_game
    game.shoe.num_decks = 6
    game.money = 15000
    game.current_bet = 1000
    game.deck_type = 2
    game.face_type = 1

    game:save_game()

    local file = io.open(scratch_save_file, 'r')
    local contents = file:read('a')
    file:close()
    Game.save_file = save_file

    assert_equal(contents, '6|15000|1000|2|1')
  end)

  it('reads the settings back from the save file', function()
    local save_file = Game.save_file
    Game.save_file = scratch_save_file
    write_save_file('6|15000|1000|2|1')

    local game = new_game()
    game:load_game()
    Game.save_file = save_file

    assert_equal(game.shoe.num_decks, 6)
    assert_equal(game.money, 15000)
    assert_equal(game.current_bet, 1000)
    assert_equal(game.deck_type, 2)
    assert_equal(game.face_type, 1)
  end)

  it('keeps the current settings when the save file is malformed', function()
    local save_file = Game.save_file
    Game.save_file = scratch_save_file
    write_save_file('invalid|data')

    local game = new_game()
    local money = game.money
    game:load_game()
    Game.save_file = save_file

    assert_equal(game.money, money)
  end)

  it('keeps the current settings when there is no save file', function()
    local save_file = Game.save_file
    Game.save_file = 'tests/tmp/does-not-exist.txt'

    local game = new_game()
    local money = game.money
    game:load_game()
    Game.save_file = save_file

    assert_equal(game.money, money)
  end)

  it('refills the bankroll when the saved money is under the minimum bet', function()
    local save_file = Game.save_file
    Game.save_file = scratch_save_file
    write_save_file('6|100|100|2|1')

    local game = new_game()
    game:load_game()
    Game.save_file = save_file

    assert_equal(game.money, 10000)
    assert_equal(game.current_bet, Game.min_bet)
  end)

  it('deals a second hand from the split pair', function()
    local game = new_game()
    game.draw_hands = spy()
    game.current_bet = 1000
    local hand = PlayerHand.new(game, 1000)
    hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    hand.get_action = spy()
    game.player_hands = { hand }
    game.current_player_hand = 0
    game.shoe.cards = { Card.new(2, 0), Card.new(3, 0) }

    game:split_current_hand()

    assert_equal(#game.player_hands, 2)
    assert_equal(#game.player_hands[1].cards, 2)
    assert_equal(game.player_hands[1].cards[1].value, 6)
    assert_equal(game.player_hands[1].cards[2].value, 2)
    assert_equal(#game.player_hands[2].cards, 1)
    assert_equal(game.player_hands[2].cards[1].value, 6)
  end)

  it('shifts the later hands up when splitting an earlier hand', function()
    local game = new_game()
    game.draw_hands = spy()
    game.current_bet = 1000

    local first = PlayerHand.new(game, 1000)
    first.cards = { Card.new(6, 0), Card.new(6, 1) }
    first.get_action = spy()
    local second = PlayerHand.new(game, 1000)
    second.cards = { Card.new(9, 0), Card.new(4, 1) }
    game.player_hands = { first, second }
    game.current_player_hand = 0
    game.shoe.cards = { Card.new(2, 0), Card.new(3, 0) }

    game:split_current_hand()

    assert_equal(#game.player_hands, 3)
    assert_equal(game.player_hands[3].cards[1].value, 9)
    assert_equal(game.player_hands[3].cards[2].value, 4)
  end)

  it('asks for an action on the next hand', function()
    local game = new_game()
    game.draw_hands = spy()
    local first = fake_player_hand()
    local second = fake_player_hand({ is_done = spy(false) })
    game.player_hands = { first, second }
    game.current_player_hand = 0

    game:play_more_hands()

    assert_equal(game.current_player_hand, 1)
    assert_equal(call_count(second.deal_card), 1)
    assert_equal(call_count(second.get_action), 1)
  end)

  it('processes the next hand when it is already done', function()
    local game = new_game()
    game.draw_hands = spy()
    local first = fake_player_hand()
    local second = fake_player_hand({ is_done = spy(true) })
    game.player_hands = { first, second }
    game.current_player_hand = 0

    game:play_more_hands()

    assert_equal(game.current_player_hand, 1)
    assert_equal(call_count(second.deal_card), 1)
    assert_equal(call_count(second.process), 1)
  end)

  it('deals two cards to the player and the dealer', function()
    local game = new_game()
    game.draw_hands = spy()
    game.play_dealer_hand = spy()
    game.bet_options = spy()
    game.shoe:build_new_shoe(6)
    game.read_char = support.keys('s')

    game:deal_new_hand()

    assert_equal(#game.player_hands, 1)
    assert_equal(#game.player_hands[1].cards, 2)
    assert_equal(#game.dealer_hand.cards, 2)
    assert_equal(game.current_player_hand, 0)
  end)

  it('offers insurance on a dealer ace', function()
    local game = new_game()
    game.draw_hands = spy()
    game.ask_insurance = spy()
    game.shoe:build_new_shoe(2)

    game:deal_new_hand()

    assert_equal(call_count(game.ask_insurance), 1)
  end)

  it('pays the hand out when the player is dealt a blackjack', function()
    local game = new_game()
    game.draw_hands = spy()
    game.pay_hands = spy()
    game.bet_options = spy()
    game.shoe.cards = { Card.new(0, 0), Card.new(5, 0), Card.new(9, 0), Card.new(6, 0) }
    game.shoe.need_to_shuffle = function() return false end

    game:deal_new_hand()

    assert_false(game.dealer_hand.hide_down_card)
    assert_equal(call_count(game.pay_hands), 1)
    assert_equal(call_count(game.bet_options), 1)
  end)

  it('takes half the bet as insurance', function()
    local game = new_game()
    game.draw_hands = spy()
    game.bet_options = spy()
    local hand = PlayerHand.new(game, 1000)
    game.player_hands = { hand }
    game.money = 10000

    game:insure_hand()

    assert_equal(hand.bet, 500)
    assert_true(hand.played)
    assert_true(hand.paid)
    assert_equal(hand.status, HandStatus.Lost)
    assert_equal(game.money, 9500)
  end)

  it('insures the hand when the player presses y', function()
    local game = new_game()
    game.insure_hand = spy()
    game.read_char = support.keys('y')

    game:ask_insurance()

    assert_equal(call_count(game.insure_hand), 1)
  end)

  it('declines insurance when the player presses n', function()
    local game = new_game()
    game.no_insurance = spy()
    game.read_char = support.keys('x', 'n')

    game:ask_insurance()

    assert_equal(call_count(game.no_insurance), 1)
  end)

  it('pays the hands out when the dealer has blackjack and insurance was declined', function()
    local game = new_game()
    game.draw_hands = spy()
    game.pay_hands = spy()
    game.bet_options = spy()
    game.dealer_hand = fake_dealer_hand({ is_blackjack = spy(true), hide_down_card = true })

    game:no_insurance()

    assert_false(game.dealer_hand.hide_down_card)
    assert_true(game.dealer_hand.played)
    assert_equal(call_count(game.pay_hands), 1)
  end)

  it('plays the dealer hand when the player hand is already done', function()
    local game = new_game()
    game.draw_hands = spy()
    game.play_dealer_hand = spy()
    game.bet_options = spy()
    game.dealer_hand = fake_dealer_hand()
    game.player_hands = { fake_player_hand({ is_done = spy(true) }) }

    game:no_insurance()

    assert_equal(call_count(game.play_dealer_hand), 1)
    assert_equal(call_count(game.bet_options), 1)
  end)

  it('asks for an action when the player hand is still live', function()
    local game = new_game()
    game.draw_hands = spy()
    game.dealer_hand = fake_dealer_hand()
    local hand = fake_player_hand({ is_done = spy(false) })
    game.player_hands = { hand }

    game:no_insurance()

    assert_equal(call_count(hand.get_action), 1)
  end)

  it('deals the next hand when the player presses d', function()
    local game = new_game()
    game.read_char = support.keys('d')

    game:bet_options()

    assert_false(game.quitting)
  end)

  it('asks for a new bet when the player presses b', function()
    local game = new_game()
    game.get_new_bet = spy()
    game.read_char = support.keys('b')

    game:bet_options()

    assert_equal(call_count(game.get_new_bet), 1)
  end)

  it('opens the options when the player presses o', function()
    local game = new_game()
    game.game_options = spy()
    game.read_char = support.keys('o')

    game:bet_options()

    assert_equal(call_count(game.game_options), 1)
  end)

  it('quits when the player presses q', function()
    local game = new_game()
    game.read_char = support.keys('z', 'q')

    game:bet_options()

    assert_true(game.quitting)
  end)

  it('asks for a deck count from the options', function()
    local game = new_game()
    game.draw_hands = spy()
    game.get_new_num_decks = spy()
    game.read_char = support.keys('n')

    game:game_options()

    assert_equal(call_count(game.get_new_num_decks), 1)
  end)

  it('asks for a deck type from the options', function()
    local game = new_game()
    game.draw_hands = spy()
    game.get_new_deck_type = spy()
    game.read_char = support.keys('t')

    game:game_options()

    assert_equal(call_count(game.get_new_deck_type), 1)
  end)

  it('asks for a face type from the options', function()
    local game = new_game()
    game.draw_hands = spy()
    game.get_new_face_type = spy()
    game.read_char = support.keys('f')

    game:game_options()

    assert_equal(call_count(game.get_new_face_type), 1)
  end)

  it('goes back to the betting options from the options', function()
    local game = new_game()
    game.draw_hands = spy()
    game.bet_options = spy()
    game.read_char = support.keys('x', 'b')

    game:game_options()

    assert_equal(call_count(game.bet_options), 1)
  end)

  it('takes a new deck count', function()
    local game = new_game()
    game.draw_hands = spy()
    game.game_options = spy()
    game.read_char = support.keys('x', '4')

    game:get_new_num_decks()

    assert_equal(game.shoe.num_decks, 4)
    assert_equal(call_count(game.game_options), 1)
  end)

  it('raises a deck count under one', function()
    local game = new_game()
    game.draw_hands = spy()
    game.game_options = spy()
    game.read_char = support.keys('0')

    game:get_new_num_decks()

    assert_equal(game.shoe.num_decks, 1)
  end)

  it('takes a new face type', function()
    local game = new_game()
    game.draw_hands = spy()
    game.bet_options = spy()
    game.read_char = support.keys('x', '2')

    game:get_new_face_type()

    assert_equal(game.face_type, 2)
    assert_equal(call_count(game.bet_options), 1)
  end)

  it('takes a new deck type and builds a matching shoe', function()
    local game = new_game()
    game.draw_hands = spy()
    game.bet_options = spy()
    game.read_char = support.keys('9', '5')

    game:get_new_deck_type()

    assert_equal(game.deck_type, 5)
    assert_equal(game.shoe.num_decks, 8)
    assert_equal(#game.shoe.cards, 416)
    assert_equal(game.shoe.cards[1].value, 6)
  end)

  it('keeps the deck count on a regular deck type', function()
    local game = new_game()
    game.draw_hands = spy()
    game.bet_options = spy()
    game.shoe.num_decks = 2
    game.read_char = support.keys('1')

    game:get_new_deck_type()

    assert_equal(game.deck_type, 1)
    assert_equal(game.shoe.num_decks, 2)
  end)

  it('takes a new bet in dollars', function()
    local game = new_game()
    game.draw_hands = spy()
    game.deal_new_hand = spy()
    local original_read = io.read
    io.read = function() return '25' end

    game:get_new_bet()

    io.read = original_read
    assert_equal(game.current_bet, 2500)
    assert_equal(call_count(game.deal_new_hand), 1)
  end)

  it('keeps the current bet when the entry is not a number', function()
    local game = new_game()
    game.draw_hands = spy()
    game.deal_new_hand = spy()
    game.current_bet = 1000
    local original_read = io.read
    io.read = function() return 'abc' end

    game:get_new_bet()

    io.read = original_read
    assert_equal(game.current_bet, 1000)
  end)

  it('deals hands until the player quits', function()
    local game = new_game()
    local deals = spy()
    deals.impl = function()
      game.quitting = true
    end
    game.deal_new_hand = deals

    game:run()

    assert_equal(call_count(deals), 1)
    assert_equal(call_count(game.unbuffer), 1)
    assert_equal(call_count(game.buffer), 1)
  end)

  it('shuffles a spent shoe before dealing', function()
    local game = new_game()
    game.draw_hands = spy()
    game.play_dealer_hand = spy()
    game.bet_options = spy()
    game.shoe.cards = {}
    game.read_char = support.keys('s')

    game:deal_new_hand()

    assert_equal(#game.shoe.cards, 416 - 4)
  end)

  it('caps a deck count over eight', function()
    local game = new_game()
    game.draw_hands = spy()
    game.game_options = spy()
    game.read_char = support.keys('9')

    game:get_new_num_decks()

    assert_equal(game.shoe.num_decks, 8)
  end)

  it('processes the split hand when the split card completes it', function()
    local game = new_game()
    game.draw_hands = spy()
    game.current_bet = 1000
    local hand = PlayerHand.new(game, 1000)
    hand.cards = { Card.new(0, 0), Card.new(0, 1) }
    hand.process = spy()
    game.player_hands = { hand }
    game.current_player_hand = 0
    game.shoe.cards = { Card.new(9, 0) }

    game:split_current_hand()

    assert_equal(call_count(hand.process), 1)
    assert_true(hand.played)
  end)

  it('leaves the settings unsaved when the save file cannot be opened', function()
    local save_file = Game.save_file
    Game.save_file = 'tests/tmp/no-such-directory/bj.txt'

    local game = new_game()
    game.save_game = Game.save_game
    game:save_game()

    Game.save_file = save_file
  end)
end)

describe('Game terminal handling', function()
  local function capture(replacements, body)
    local originals = {}

    for _, replacement in ipairs(replacements) do
      local holder, key, value = replacement[1], replacement[2], replacement[3]
      table.insert(originals, { holder, key, holder[key] })
      holder[key] = value
    end

    local ok, err = pcall(body)

    for _, original in ipairs(originals) do
      original[1][original[2]] = original[3]
    end

    if not ok then
      error(err, 0)
    end
  end

  it('writes to standard output', function()
    local game = new_game()
    local written = {}

    capture({ { io, 'write', function(text) table.insert(written, text) end } }, function()
      Game.write(game, ' Insurance?')
    end)

    assert_equal(written[1], ' Insurance?')
  end)

  it('reads a single character from standard input', function()
    local game = new_game()
    local key

    capture({ { io, 'read', function(count) return 'h' .. count end } }, function()
      key = Game.read_char(game)
    end)

    assert_equal(key, 'h1')
  end)

  it('clears the screen', function()
    local game = new_game()
    local commands = {}

    capture({ { os, 'execute', function(command) table.insert(commands, command) end } }, function()
      Game.clear(game)
    end)

    assert_contains(commands[1], 'clear')
  end)

  it('remembers the terminal settings when taking single keystrokes', function()
    local game = new_game()
    local commands = {}
    local handle = { read = function() return 'saved-settings' end, close = function() end }

    capture({
      { io, 'popen', function() return handle end },
      { os, 'execute', function(command) table.insert(commands, command) end },
    }, function()
      Game.unbuffer(game)
    end)

    assert_equal(game.saved_term_settings, 'saved-settings')
    assert_contains(commands[1], '-icanon')
  end)

  it('takes single keystrokes even when the terminal settings cannot be read', function()
    local game = new_game()
    local commands = {}

    capture({
      { io, 'popen', function() return nil end },
      { os, 'execute', function(command) table.insert(commands, command) end },
    }, function()
      Game.unbuffer(game)
    end)

    assert_equal(game.saved_term_settings, nil)
    assert_contains(commands[1], '-icanon')
  end)

  it('restores the remembered terminal settings', function()
    local game = new_game()
    local commands = {}
    game.saved_term_settings = 'saved-settings'

    capture({ { os, 'execute', function(command) table.insert(commands, command) end } }, function()
      Game.buffer(game)
    end)

    assert_equal(commands[1], 'stty saved-settings')
  end)

  it('resets the terminal when there are no remembered settings', function()
    local game = new_game()
    local commands = {}
    game.saved_term_settings = nil

    capture({ { os, 'execute', function(command) table.insert(commands, command) end } }, function()
      Game.buffer(game)
    end)

    assert_equal(commands[1], 'stty sane')
  end)
end)
