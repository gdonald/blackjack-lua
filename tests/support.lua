local harness = require('tests.harness')

local support = {}

function support.mock_shoe()
  return { get_next_card = harness.spy() }
end

function support.mock_game()
  return {
    shoe = support.mock_shoe(),
    money = 10000,
    current_bet = 500,
    deck_type = 1,
    face_type = 1,
    player_hands = {},
    current_player_hand = 0,
    all_bets = harness.spy(500),
    card_face = harness.spy('??'),
    draw_hands = harness.spy(),
    play_more_hands = harness.spy(),
    play_dealer_hand = harness.spy(),
    bet_options = harness.spy(),
    more_hands_to_play = harness.spy(false),
    split_current_hand = harness.spy(),
    write = harness.spy(),
    read_char = support.no_keys(),
  }
end

function support.keys(...)
  local queued = { ... }
  local index = 0
  local reader = harness.spy()

  reader.impl = function()
    index = index + 1
    if index > #queued then
      error('read a key past the end of the queued keys')
    end
    return queued[index]
  end

  return reader
end

function support.no_keys()
  local reader = harness.spy()

  reader.impl = function()
    error('read a key without any queued keys')
  end

  return reader
end

return support
