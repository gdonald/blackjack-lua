local harness = require('tests.harness')
local support = require('tests.support')
local Hand = require('bj.hand')
local Card = require('bj.card')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false

describe('Hand', function()
  local function new_hand()
    local game = support.mock_game()
    return Hand.new(game), game
  end

  it('names the soft and hard count methods', function()
    assert_equal(Hand.CountMethod.Soft, 0)
    assert_equal(Hand.CountMethod.Hard, 1)
  end)

  it('starts with no cards and nothing played', function()
    local hand, game = new_hand()
    assert_equal(hand.game, game)
    assert_equal(#hand.cards, 0)
    assert_false(hand.stood)
    assert_false(hand.played)
  end)

  it('takes the next card from the shoe when dealt a card', function()
    local hand, game = new_hand()
    local card = Card.new(4, 0)
    game.shoe.get_next_card.return_value = card

    hand:deal_card()

    assert_equal(harness.call_count(game.shoe.get_next_card), 1)
    assert_equal(#hand.cards, 1)
    assert_equal(hand.cards[1], card)
  end)

  it('reports blackjack for an ace with any ten in either order', function()
    local hand = new_hand()
    local ace = Card.new(0, 0)

    for _, ten_value in ipairs({ 9, 10, 11, 12 }) do
      hand.cards = { ace, Card.new(ten_value, 1) }
      assert_true(hand:is_blackjack())

      hand.cards = { Card.new(ten_value, 1), ace }
      assert_true(hand:is_blackjack())
    end
  end)

  it('reports no blackjack without exactly an ace and a ten', function()
    local hand = new_hand()
    local ace = Card.new(0, 0)
    local ten = Card.new(9, 1)
    local two = Card.new(1, 0)

    hand.cards = { ace }
    assert_false(hand:is_blackjack())

    hand.cards = { ace, ten, two }
    assert_false(hand:is_blackjack())

    hand.cards = { ten, Card.new(9, 0) }
    assert_false(hand:is_blackjack())

    hand.cards = { ace, two }
    assert_false(hand:is_blackjack())

    hand.cards = {}
    assert_false(hand:is_blackjack())
  end)
end)
