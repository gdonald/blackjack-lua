local harness = require('tests.harness')
local support = require('tests.support')
local DealerHand = require('bj.dealer_hand')
local Hand = require('bj.hand')
local Card = require('bj.card')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false
local Soft, Hard = Hand.CountMethod.Soft, Hand.CountMethod.Hard

describe('DealerHand', function()
  local function new_dealer_hand()
    local game = support.mock_game()
    return DealerHand.new(game), game
  end

  it('starts with no cards and the down card hidden', function()
    local dealer_hand, game = new_dealer_hand()
    assert_equal(dealer_hand.game, game)
    assert_equal(#dealer_hand.cards, 0)
    assert_false(dealer_hand.stood)
    assert_false(dealer_hand.played)
    assert_true(dealer_hand.hide_down_card)
  end)

  it('is busted over twenty one', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = { Card.new(9, 0), Card.new(9, 1), Card.new(1, 0) }
    dealer_hand.hide_down_card = false

    assert_true(dealer_hand:is_busted())
  end)

  it('is not busted at or under twenty one', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = { Card.new(9, 0), Card.new(9, 1) }
    dealer_hand.hide_down_card = false
    assert_false(dealer_hand:is_busted())

    dealer_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    assert_false(dealer_hand:is_busted())
  end)

  it('leaves the hidden down card out of the count', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = { Card.new(9, 0), Card.new(0, 1) }
    dealer_hand.hide_down_card = true

    assert_equal(dealer_hand:get_value(Soft), 10)
    assert_equal(dealer_hand:get_value(Hard), 10)
  end)

  it('counts an ace as eleven in a soft count', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.hide_down_card = false

    dealer_hand.cards = { Card.new(0, 0), Card.new(5, 1) }
    assert_equal(dealer_hand:get_value(Soft), 17)

    dealer_hand.cards = { Card.new(0, 0), Card.new(5, 1), Card.new(4, 0) }
    assert_equal(dealer_hand:get_value(Soft), 12)

    dealer_hand.cards = { Card.new(0, 0), Card.new(0, 1) }
    assert_equal(dealer_hand:get_value(Soft), 12)
  end)

  it('counts an ace as one in a hard count', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.hide_down_card = false

    dealer_hand.cards = { Card.new(0, 0), Card.new(5, 1) }
    assert_equal(dealer_hand:get_value(Hard), 7)

    dealer_hand.cards = { Card.new(0, 0), Card.new(0, 1) }
    assert_equal(dealer_hand:get_value(Hard), 2)

    dealer_hand.cards = { Card.new(10, 0), Card.new(11, 1), Card.new(12, 0) }
    assert_equal(dealer_hand:get_value(Hard), 30)
  end)

  it('falls back to the hard count when the soft count busts', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.hide_down_card = false
    dealer_hand.cards = { Card.new(0, 0), Card.new(5, 1), Card.new(5, 0) }

    assert_equal(dealer_hand:get_value(Soft), 13)
    assert_equal(dealer_hand:get_value(Hard), 13)
  end)

  it('draws the down card face down while it is hidden', function()
    local dealer_hand, game = new_dealer_hand()
    dealer_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    dealer_hand.hide_down_card = true

    local out = dealer_hand:to_string()

    assert_true(harness.called_with(game.card_face, 0, 0))
    assert_true(harness.called_with(game.card_face, 13, 0))
    harness.assert_contains(out, '11')
  end)

  it('draws both cards once the down card is revealed', function()
    local dealer_hand, game = new_dealer_hand()
    dealer_hand.cards = { Card.new(0, 0), Card.new(9, 1) }
    dealer_hand.hide_down_card = false

    local out = dealer_hand:to_string()

    assert_true(harness.called_with(game.card_face, 0, 0))
    assert_true(harness.called_with(game.card_face, 9, 1))
    harness.assert_contains(out, '21')
  end)

  it('reports an ace upcard', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = { Card.new(0, 0), Card.new(9, 1) }

    assert_true(dealer_hand:upcard_is_ace())
  end)

  it('reports no ace upcard for any other card', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = { Card.new(9, 0), Card.new(0, 1) }

    assert_false(dealer_hand:upcard_is_ace())
  end)

  it('raises an error asking for an ace upcard with no cards', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.cards = {}

    harness.assert_error(function()
      dealer_hand:upcard_is_ace()
    end)
  end)

  it('counts tens and face cards as ten', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.hide_down_card = false

    for _, value in ipairs({ 9, 10, 11, 12 }) do
      dealer_hand.cards = { Card.new(value, 0) }
      assert_equal(dealer_hand:get_value(Hard), 10)
    end
  end)

  it('counts a number card as its face value', function()
    local dealer_hand = new_dealer_hand()
    dealer_hand.hide_down_card = false

    for value = 1, 8 do
      dealer_hand.cards = { Card.new(value, 0) }
      assert_equal(dealer_hand:get_value(Hard), value + 1)
    end
  end)
end)
