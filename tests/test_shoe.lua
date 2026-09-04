local harness = require('tests.harness')
local Shoe = require('bj.shoe')

local describe, it = harness.describe, harness.it
local assert_equal, assert_true, assert_false = harness.assert_equal, harness.assert_true, harness.assert_false

local function placeholder_cards(count)
  local cards = {}
  for index = 1, count do
    table.insert(cards, { value = index })
  end
  return cards
end

local function values_present(cards)
  local seen = {}
  for _, card in ipairs(cards) do
    seen[card.value] = true
  end
  return seen
end

describe('Shoe', function()
  local shoe

  local function fresh()
    shoe = Shoe.new()
    return shoe
  end

  it('starts with eight empty decks of fifty two cards', function()
    fresh()
    assert_equal(shoe.num_decks, 8)
    assert_equal(#shoe.cards, 0)
    assert_equal(shoe.cards_per_deck, 52)
  end)

  it('keeps a shuffle threshold for each deck count', function()
    local expected = { 80, 81, 82, 84, 86, 89, 92, 95 }
    assert_equal(#Shoe.shuffle_specs, #expected)
    for index, spec in ipairs(expected) do
      assert_equal(Shoe.shuffle_specs[index], spec)
    end
  end)

  it('needs a shuffle when no cards are left', function()
    fresh()
    assert_true(shoe:need_to_shuffle())
  end)

  it('needs a shuffle once eight decks pass their threshold', function()
    fresh()
    shoe.cards = placeholder_cards(21)
    assert_false(shoe:need_to_shuffle())

    shoe.cards = placeholder_cards(20)
    assert_true(shoe:need_to_shuffle())
  end)

  it('needs a shuffle once a single deck passes its threshold', function()
    fresh()
    shoe.num_decks = 1
    shoe.cards = placeholder_cards(11)
    assert_false(shoe:need_to_shuffle())

    shoe.cards = placeholder_cards(10)
    assert_true(shoe:need_to_shuffle())
  end)

  it('keeps every card when shuffling', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_regular()
    local before = {}
    for _, card in ipairs(shoe.cards) do
      before[card] = true
    end

    shoe:shuffle()

    assert_equal(#shoe.cards, 52)
    for _, card in ipairs(shoe.cards) do
      assert_true(before[card])
    end
  end)

  it('deals the card off the front of the shoe', function()
    fresh()
    shoe.cards = placeholder_cards(5)
    local first = shoe.cards[1]

    local dealt = shoe:get_next_card()

    assert_equal(dealt, first)
    assert_equal(#shoe.cards, 4)
    for _, card in ipairs(shoe.cards) do
      harness.assert_not_equal(card, dealt)
    end
  end)

  it('counts the total cards across the decks', function()
    fresh()
    shoe.num_decks = 6
    assert_equal(shoe:get_total_cards(), 312)

    shoe.num_decks = 1
    assert_equal(shoe:get_total_cards(), 52)
  end)

  it('fills the shoe with only the requested values', function()
    fresh()
    shoe.num_decks = 2
    shoe:new_shoe({ 0, 1, 2 })

    assert_equal(#shoe.cards, 104)
    for value in pairs(values_present(shoe.cards)) do
      assert_true(value == 0 or value == 1 or value == 2)
    end
  end)

  it('builds a regular deck holding every value', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_regular()

    assert_equal(#shoe.cards, 52)
    local seen = values_present(shoe.cards)
    for value = 0, 12 do
      assert_true(seen[value])
    end
  end)

  it('builds a shoe of only aces', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_aces()

    assert_equal(#shoe.cards, 52)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 0)
    end
  end)

  it('builds a shoe of only jacks', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_jacks()

    assert_equal(#shoe.cards, 52)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 10)
    end
  end)

  it('builds a shoe of aces and jacks', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_aces_jacks()

    assert_equal(#shoe.cards, 52)
    local seen = values_present(shoe.cards)
    assert_true(seen[0])
    assert_true(seen[10])
    for value in pairs(seen) do
      assert_true(value == 0 or value == 10)
    end
  end)

  it('builds a shoe of only sevens', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_sevens()

    assert_equal(#shoe.cards, 52)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 6)
    end
  end)

  it('builds a shoe of only eights', function()
    fresh()
    shoe.num_decks = 1
    shoe:new_eights()

    assert_equal(#shoe.cards, 52)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 7)
    end
  end)

  it('builds a full regular shoe for deck type one', function()
    fresh()
    shoe:build_new_shoe(1)

    assert_equal(#shoe.cards, 416)
    assert_true(values_present(shoe.cards)[12])
  end)

  it('builds a full shoe of aces for deck type two', function()
    fresh()
    shoe:build_new_shoe(2)

    assert_equal(#shoe.cards, 416)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 0)
    end
  end)

  it('builds a full shoe of jacks for deck type three', function()
    fresh()
    shoe:build_new_shoe(3)

    assert_equal(#shoe.cards, 416)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 10)
    end
  end)

  it('builds a full shoe of aces and jacks for deck type four', function()
    fresh()
    shoe:build_new_shoe(4)

    assert_equal(#shoe.cards, 416)
    local seen = values_present(shoe.cards)
    assert_true(seen[0])
    assert_true(seen[10])
  end)

  it('builds a full shoe of sevens for deck type five', function()
    fresh()
    shoe:build_new_shoe(5)

    assert_equal(#shoe.cards, 416)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 6)
    end
  end)

  it('builds a full shoe of eights for deck type six', function()
    fresh()
    shoe:build_new_shoe(6)

    assert_equal(#shoe.cards, 416)
    for _, card in ipairs(shoe.cards) do
      assert_equal(card.value, 7)
    end
  end)

  it('builds a regular shoe for an unknown deck type', function()
    fresh()
    shoe:build_new_shoe(99)

    assert_equal(#shoe.cards, 416)
    assert_true(values_present(shoe.cards)[12])
  end)
end)
