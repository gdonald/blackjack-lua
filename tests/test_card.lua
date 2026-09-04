local harness = require('tests.harness')
local Card = require('bj.card')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false

describe('Card', function()
  it('stores the value and suit it was created with', function()
    local card = Card.new(0, 0)
    assert_equal(card.value, 0)
    assert_equal(card.suit, 0)

    card = Card.new(12, 3)
    assert_equal(card.value, 12)
    assert_equal(card.suit, 3)
  end)

  it('reports an ace only for the lowest value', function()
    assert_true(Card.new(0, 0):is_ace())
    assert_false(Card.new(12, 0):is_ace())
    assert_false(Card.new(1, 0):is_ace())
  end)

  it('reports a ten for tens and face cards', function()
    assert_true(Card.new(9, 0):is_ten())
    assert_true(Card.new(10, 0):is_ten())
    assert_true(Card.new(11, 0):is_ten())
    assert_true(Card.new(12, 0):is_ten())
    assert_false(Card.new(8, 0):is_ten())
    assert_false(Card.new(0, 0):is_ten())
  end)

  it('has fourteen rows of four faces', function()
    assert_equal(#Card.faces, 14)
    for _, row in ipairs(Card.faces) do
      assert_equal(#row, 4)
    end
  end)

  it('has fourteen rows of four alternate faces', function()
    assert_equal(#Card.faces2, 14)
    for _, row in ipairs(Card.faces2) do
      assert_equal(#row, 4)
    end
  end)
end)
