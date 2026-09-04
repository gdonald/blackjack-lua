local harness = require('tests.harness')
local support = require('tests.support')
local PlayerHand = require('bj.player_hand')
local Hand = require('bj.hand')
local Card = require('bj.card')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false
local assert_contains, assert_not_contains = harness.assert_contains, harness.assert_not_contains
local Soft, Hard = Hand.CountMethod.Soft, Hand.CountMethod.Hard
local HandStatus = PlayerHand.HandStatus

describe('PlayerHand', function()
  local function new_player_hand(bet)
    local game = support.mock_game()
    local player_hand = PlayerHand.new(game, bet or 500)
    game.player_hands = { player_hand }
    return player_hand, game
  end

  it('names the hand statuses', function()
    assert_equal(HandStatus.Unknown, 0)
    assert_equal(HandStatus.Won, 1)
    assert_equal(HandStatus.Lost, 2)
    assert_equal(HandStatus.Push, 3)
  end)

  it('starts unplayed and unpaid with the given bet', function()
    local player_hand, game = new_player_hand(500)
    assert_equal(player_hand.game, game)
    assert_equal(player_hand.bet, 500)
    assert_equal(player_hand.status, HandStatus.Unknown)
    assert_false(player_hand.paid)
    assert_equal(#player_hand.cards, 0)
    assert_false(player_hand.stood)
    assert_false(player_hand.played)
  end)

  it('allows at most seven hands', function()
    assert_equal(PlayerHand.max_player_hands, 7)
  end)

  it('is busted over twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }

    assert_true(player_hand:is_busted())
  end)

  it('is not busted at or under twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1) }
    assert_false(player_hand:is_busted())

    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    assert_false(player_hand:is_busted())
  end)

  it('counts an ace as eleven in a soft count', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(5, 1) }
    assert_equal(player_hand:get_value(Soft), 17)

    player_hand.cards = { Card.new(0, 0), Card.new(5, 1), Card.new(4, 0) }
    assert_equal(player_hand:get_value(Soft), 12)
  end)

  it('counts an ace as one in a hard count', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(5, 1) }
    assert_equal(player_hand:get_value(Hard), 7)

    player_hand.cards = { Card.new(10, 0), Card.new(11, 1) }
    assert_equal(player_hand:get_value(Hard), 20)
  end)

  it('takes the bet from the player when the hand busts', function()
    local player_hand, game = new_player_hand(500)
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }

    assert_true(player_hand:is_done())
    assert_true(player_hand.played)
    assert_true(player_hand.paid)
    assert_equal(player_hand.status, HandStatus.Lost)
    assert_equal(game.money, 9500)
  end)

  it('is done on blackjack without paying yet', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_true(player_hand:is_done())
    assert_true(player_hand.played)
    assert_false(player_hand.paid)
  end)

  it('counts a soft twenty one as twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_true(player_hand:is_twenty_one())
  end)

  it('counts a hard twenty one as twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1), Card.new(6, 2) }

    assert_true(player_hand:is_twenty_one())
  end)

  it('counts anything short of twenty one as less', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }

    assert_false(player_hand:is_twenty_one())
  end)

  it('is done on twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1), Card.new(6, 2) }

    assert_true(player_hand:is_done())
    assert_true(player_hand.played)
  end)

  it('is done once the hand has stood', function()
    local player_hand = new_player_hand()
    player_hand.stood = true

    assert_true(player_hand:is_done())
    assert_true(player_hand.played)
  end)

  it('is not done on a playable hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }

    assert_false(player_hand:is_done())
    assert_false(player_hand.played)
  end)

  it('can split a pair with money left to cover the bet', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    game.all_bets.return_value = 500
    game.money = 2000

    assert_true(player_hand:can_split())
  end)

  it('cannot split a hand that has stood', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    player_hand.stood = true

    assert_false(player_hand:can_split())
  end)

  it('cannot split past the hand limit', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    game.player_hands = {}
    for _ = 1, 7 do
      table.insert(game.player_hands, PlayerHand.new(game, 500))
    end

    assert_false(player_hand:can_split())
  end)

  it('cannot split without money for another bet', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    game.all_bets.return_value = 1000
    game.money = 1000

    assert_false(player_hand:can_split())
  end)

  it('cannot split two different values', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(7, 1) }

    assert_false(player_hand:can_split())
  end)

  it('cannot split more than two cards', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1), Card.new(6, 2) }

    assert_false(player_hand:can_split())
  end)

  it('can double on two cards with money to cover the bet', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.money = 2000
    game.all_bets.return_value = 500

    assert_true(player_hand:can_dbl())
  end)

  it('cannot double without money for another bet', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.money = 500
    game.all_bets.return_value = 500

    assert_false(player_hand:can_dbl())
  end)

  it('cannot double a hand that has stood', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    player_hand.stood = true

    assert_false(player_hand:can_dbl())
  end)

  it('cannot double more than two cards', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1), Card.new(2, 0) }

    assert_false(player_hand:can_dbl())
  end)

  it('cannot double a busted hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(9, 2) }

    assert_false(player_hand:can_dbl())
  end)

  it('cannot double a blackjack', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_false(player_hand:can_dbl())
  end)

  it('can stand on a playable hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }

    assert_true(player_hand:can_stand())
  end)

  it('cannot stand twice', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    player_hand.stood = true

    assert_false(player_hand:can_stand())
  end)

  it('cannot stand on a busted hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }

    assert_false(player_hand:can_stand())
  end)

  it('cannot stand on a blackjack', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_false(player_hand:can_stand())
  end)

  it('can hit a playable hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }

    assert_true(player_hand:can_hit())
  end)

  it('cannot hit a played hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    player_hand.played = true

    assert_false(player_hand:can_hit())
  end)

  it('cannot hit a hand that has stood', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    player_hand.stood = true

    assert_false(player_hand:can_hit())
  end)

  it('cannot hit a hard twenty one', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1), Card.new(6, 2) }

    assert_false(player_hand:can_hit())
  end)

  it('cannot hit a blackjack', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_false(player_hand:can_hit())
  end)

  it('cannot hit a busted hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }

    assert_false(player_hand:can_hit())
  end)

  it('asks for another action after hitting a playable hand', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.shoe.get_next_card.return_value = Card.new(1, 0)
    local get_action = harness.spy()
    player_hand.get_action = get_action

    player_hand:hit()

    assert_equal(#player_hand.cards, 3)
    assert_equal(harness.call_count(game.draw_hands), 1)
    assert_equal(harness.call_count(get_action), 1)
  end)

  it('processes the hand after hitting into a bust', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1) }
    game.shoe.get_next_card.return_value = Card.new(9, 2)
    local process = harness.spy()
    player_hand.process = process

    player_hand:hit()

    assert_equal(harness.call_count(process), 1)
  end)

  it('doubles the bet and plays the hand out when doubling', function()
    local player_hand, game = new_player_hand(500)
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.shoe.get_next_card.return_value = Card.new(9, 2)
    local process = harness.spy()
    player_hand.process = process

    player_hand:dbl()

    assert_true(player_hand.played)
    assert_equal(player_hand.bet, 1000)
    assert_equal(harness.call_count(process), 1)
  end)

  it('moves to the next hand when standing with hands left to play', function()
    local player_hand, game = new_player_hand()
    game.more_hands_to_play.return_value = true

    player_hand:stand()

    assert_true(player_hand.stood)
    assert_true(player_hand.played)
    assert_equal(harness.call_count(game.play_more_hands), 1)
  end)

  it('plays the dealer hand when standing on the last hand', function()
    local player_hand, game = new_player_hand()
    game.more_hands_to_play.return_value = false

    player_hand:stand()

    assert_true(player_hand.stood)
    assert_true(player_hand.played)
    assert_equal(harness.call_count(game.play_dealer_hand), 1)
    assert_equal(harness.call_count(game.draw_hands), 1)
    assert_equal(harness.call_count(game.bet_options), 1)
  end)

  it('draws the hand value and bet', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    player_hand.bet = 1000

    local out = player_hand:to_string()

    assert_contains(out, '21')
    assert_contains(out, '$10.00')
    assert_true(harness.call_count(game.card_face) > 0)
  end)

  it('draws a won blackjack', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    player_hand.status = HandStatus.Won

    assert_contains(player_hand:to_string(), 'Blackjack!')
  end)

  it('draws an ordinary win', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1) }
    player_hand.status = HandStatus.Won

    local out = player_hand:to_string()

    assert_contains(out, 'Win!')
    assert_not_contains(out, 'Blackjack!')
  end)

  it('draws a busted hand', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }
    player_hand.status = HandStatus.Lost

    assert_contains(player_hand:to_string(), 'Busted!')
  end)

  it('draws an ordinary loss', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(8, 0), Card.new(8, 1) }
    player_hand.status = HandStatus.Lost

    local out = player_hand:to_string()

    assert_contains(out, 'Lose!')
    assert_not_contains(out, 'Busted!')
  end)

  it('draws a push', function()
    local player_hand = new_player_hand()
    player_hand.cards = { Card.new(9, 0), Card.new(9, 1) }
    player_hand.status = HandStatus.Push

    assert_contains(player_hand:to_string(), 'Push!')
  end)

  it('marks the hand waiting on the player', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    player_hand.played = false
    game.current_player_hand = 0

    assert_contains(player_hand:to_string(), '⇐')
  end)

  it('offers every available action', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    game.money = 5000
    game.read_char = support.keys('s')

    player_hand:get_action()

    local offered = game.write.calls[1][2]
    assert_contains(offered, '(H) Hit')
    assert_contains(offered, '(S) Stand')
    assert_contains(offered, '(P) Split')
    assert_contains(offered, '(D) Double')
  end)

  it('hits the hand when the player presses h', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.read_char = support.keys('h')
    local hit = harness.spy()
    player_hand.hit = hit

    player_hand:get_action()

    assert_equal(harness.call_count(hit), 1)
  end)

  it('stands the hand when the player presses s', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.read_char = support.keys('s')
    local stand = harness.spy()
    player_hand.stand = stand

    player_hand:get_action()

    assert_equal(harness.call_count(stand), 1)
  end)

  it('splits the hand when the player presses p on a pair', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    game.money = 5000
    game.read_char = support.keys('p')

    player_hand:get_action()

    assert_equal(harness.call_count(game.split_current_hand), 1)
  end)

  it('ignores p on a hand that cannot split', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(6, 0), Card.new(7, 1) }
    game.read_char = support.keys('p', 's')
    local stand = harness.spy()
    player_hand.stand = stand

    player_hand:get_action()

    assert_equal(harness.call_count(game.split_current_hand), 0)
    assert_equal(harness.call_count(stand), 1)
  end)

  it('doubles the hand when the player presses d', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.read_char = support.keys('d')
    local dbl = harness.spy()
    player_hand.dbl = dbl

    player_hand:get_action()

    assert_equal(harness.call_count(dbl), 1)
  end)

  it('ignores a key that is not an action', function()
    local player_hand, game = new_player_hand()
    player_hand.cards = { Card.new(4, 0), Card.new(5, 1) }
    game.read_char = support.keys('x', 's')
    local stand = harness.spy()
    player_hand.stand = stand

    player_hand:get_action()

    assert_equal(harness.call_count(stand), 1)
  end)

  it('copies the cards and state onto a new hand', function()
    local player_hand = new_player_hand(500)
    player_hand.cards = { Card.new(6, 0), Card.new(6, 1) }
    player_hand.stood = true
    player_hand.status = HandStatus.Won

    local copy = player_hand:copy()

    assert_equal(copy.bet, 500)
    assert_equal(copy.stood, true)
    assert_equal(copy.status, HandStatus.Won)
    assert_equal(#copy.cards, 2)
    assert_equal(copy.cards[1], player_hand.cards[1])
    harness.assert_not_equal(copy, player_hand)
  end)
end)
