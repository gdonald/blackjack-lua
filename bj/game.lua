local Card = require('bj.card')
local DealerHand = require('bj.dealer_hand')
local Hand = require('bj.hand')
local PlayerHand = require('bj.player_hand')
local Shoe = require('bj.shoe')

local CountMethod = Hand.CountMethod
local HandStatus = PlayerHand.HandStatus

local Game = {}
Game.__index = Game

Game.save_file = 'bj.txt'
Game.min_bet = 500
Game.max_bet = 10000000

function Game.new()
  local game = setmetatable({
    shoe = Shoe.new(),
    deck_type = 1,
    face_type = 1,
    money = 10000,
    current_bet = 500,
    saved_term_settings = nil,
  }, Game)

  game:load_game()

  game.dealer_hand = nil
  game.current_player_hand = 0
  game.player_hands = {}
  game.quitting = false

  return game
end

function Game:write(text)
  io.write(text)
  io.stdout:flush()
end

function Game:read_char()
  return io.read(1)
end

function Game:clear()
  os.execute('export TERM=${TERM:-linux}; clear')
end

function Game:unbuffer()
  local stty = io.popen('stty -g')
  if stty then
    self.saved_term_settings = stty:read('l')
    stty:close()
  end
  os.execute('stty -icanon -echo min 1 time 0')
end

function Game:buffer()
  if self.saved_term_settings then
    os.execute('stty ' .. self.saved_term_settings)
  else
    os.execute('stty sane')
  end
end

function Game:all_bets()
  local bets = 0

  for _, hand in ipairs(self.player_hands) do
    bets = bets + hand.bet
  end

  return bets
end

function Game:ask_insurance()
  self:write(' Insurance?  (Y) Yes  (N) No\n')

  while true do
    local key = self:read_char()

    if key == 'y' then
      self:insure_hand()
      return
    elseif key == 'n' then
      self:no_insurance()
      return
    end
  end
end

function Game:card_face(value, suit)
  if self.face_type == 2 then
    return Card.faces2[value + 1][suit + 1]
  end

  return Card.faces[value + 1][suit + 1]
end

function Game:deal_new_hand()
  if self.shoe:need_to_shuffle() then
    self.shoe:build_new_shoe(self.deck_type)
  end

  self.player_hands = { PlayerHand.new(self, self.current_bet) }
  self.current_player_hand = 0
  self.dealer_hand = DealerHand.new(self)

  for _ = 1, 2 do
    self.player_hands[1]:deal_card()
    self.dealer_hand:deal_card()
  end

  if self.dealer_hand:upcard_is_ace() then
    self:draw_hands()
    self:ask_insurance()
    return
  end

  if self.player_hands[1]:is_done() then
    self.dealer_hand.hide_down_card = false
    self:pay_hands()
    self:draw_hands()
    self:bet_options()
    return
  end

  self:draw_hands()
  self.player_hands[1]:get_action()
  self:save_game()
end

function Game:draw_hands()
  self:clear()

  local out = string.format('\n Dealer:\n%s\n', self.dealer_hand:to_string())
  out = string.format('%s\n Player $%.2f:\n', out, self.money / 100.0)

  for _, hand in ipairs(self.player_hands) do
    out = out .. hand:to_string() .. '\n'
  end

  self:write(out)
end

function Game:bet_options()
  self:write(' (D) Deal Hand  (B) Change Bet  (O) Options  (Q) Quit\n')

  while true do
    local key = self:read_char()

    if key == 'd' then
      return
    elseif key == 'b' then
      self:get_new_bet()
      return
    elseif key == 'o' then
      self:game_options()
      return
    elseif key == 'q' then
      self.quitting = true
      self:clear()
      return
    end
  end
end

function Game:game_options()
  self:clear()
  self:draw_hands()
  self:write(' (N) Number of Decks  (T) Deck Type  (F) Face Type  (B) Back\n')

  while true do
    local key = self:read_char()

    if key == 'n' then
      self:get_new_num_decks()
      return
    elseif key == 't' then
      self:get_new_deck_type()
      return
    elseif key == 'f' then
      self:get_new_face_type()
      return
    elseif key == 'b' then
      self:clear()
      self:draw_hands()
      self:bet_options()
      return
    end
  end
end

function Game:get_new_num_decks()
  self:clear()
  self:draw_hands()
  self:write(string.format('  Number of Decks: %d  Enter New Number of Decks (1-8): ', self.shoe.num_decks))

  while true do
    local num_decks = tonumber(self:read_char())

    if num_decks then
      if num_decks < 1 then
        num_decks = 1
      end
      if num_decks > 8 then
        num_decks = 8
      end
      self.shoe.num_decks = num_decks
      self:save_game()
      self:game_options()
      return
    end
  end
end

function Game:get_new_face_type()
  self:clear()
  self:draw_hands()
  self:write('(1) A♠  (2) 🂡\n')

  while true do
    local key = self:read_char()

    if key == '1' or key == '2' then
      self.face_type = tonumber(key)
      self:save_game()
      self:draw_hands()
      self:bet_options()
      return
    end
  end
end

function Game:get_new_deck_type()
  self:clear()
  self:draw_hands()
  self:write(' (1) Regular  (2) Aces  (3) Jacks  (4) Aces & Jacks  (5) Sevens  (6) Eights\n')

  while true do
    local deck_type = tonumber(self:read_char())

    if deck_type and deck_type > 0 and deck_type < 7 then
      self.deck_type = deck_type
      if deck_type > 1 then
        self.shoe.num_decks = 8
      end
      self.shoe:build_new_shoe(self.deck_type)
      self:save_game()
      self:draw_hands()
      self:bet_options()
      return
    end
  end
end

function Game:get_new_bet()
  self:clear()
  self:draw_hands()
  self:write(string.format('  Current Bet: $%.2f  Enter New Bet: $', self.current_bet / 100.0))

  self:buffer()
  local entered = tonumber(io.read('l'))
  self:unbuffer()

  if entered then
    self.current_bet = math.floor(entered) * 100
  end

  self:normalize_bet()
  self:deal_new_hand()
end

function Game:insure_hand()
  local hand = self.player_hands[self.current_player_hand + 1]
  hand.bet = hand.bet // 2
  hand.played = true
  hand.paid = true
  hand.status = HandStatus.Lost
  self.money = self.money - hand.bet

  self:draw_hands()
  self:bet_options()
end

function Game:more_hands_to_play()
  return self.current_player_hand < #self.player_hands - 1
end

function Game:need_to_play_dealer_hand()
  for _, hand in ipairs(self.player_hands) do
    if not (hand:is_busted() or hand:is_blackjack()) then
      return true
    end
  end

  return false
end

function Game:no_insurance()
  if self.dealer_hand:is_blackjack() then
    self.dealer_hand.hide_down_card = false
    self.dealer_hand.played = true
    self:pay_hands()
    self:draw_hands()
    self:bet_options()
    return
  end

  local hand = self.player_hands[self.current_player_hand + 1]

  if hand:is_done() then
    self:play_dealer_hand()
    self:draw_hands()
    self:bet_options()
    return
  end

  self:draw_hands()
  hand:get_action()
end

function Game:normalize_bet()
  if self.current_bet < Game.min_bet then
    self.current_bet = Game.min_bet
  elseif self.current_bet > Game.max_bet then
    self.current_bet = Game.max_bet
  end

  if self.current_bet > self.money then
    self.current_bet = self.money
  end
end

function Game:pay_hands()
  local dealer_value = self.dealer_hand:get_value(CountMethod.Soft)
  local dealer_busted = self.dealer_hand:is_busted()

  for _, hand in ipairs(self.player_hands) do
    if not hand.paid then
      hand.paid = true
      local hand_value = hand:get_value(CountMethod.Soft)

      if dealer_busted or hand_value > dealer_value then
        if hand:is_blackjack() then
          hand.bet = math.floor(hand.bet * 1.5)
        end
        self.money = self.money + hand.bet
        hand.status = HandStatus.Won
      elseif hand_value < dealer_value then
        self.money = self.money - hand.bet
        hand.status = HandStatus.Lost
      else
        hand.status = HandStatus.Push
      end
    end
  end

  self:normalize_bet()
  self:save_game()
end

function Game:play_dealer_hand()
  if self.dealer_hand:is_blackjack() then
    self.dealer_hand.hide_down_card = false
  end

  if not self:need_to_play_dealer_hand() then
    self.dealer_hand.played = true
    self:pay_hands()
    return
  end

  self.dealer_hand.hide_down_card = false

  local soft_count = self.dealer_hand:get_value(CountMethod.Soft)
  local hard_count = self.dealer_hand:get_value(CountMethod.Hard)

  while soft_count < 18 and hard_count < 17 do
    self.dealer_hand:deal_card()
    soft_count = self.dealer_hand:get_value(CountMethod.Soft)
    hard_count = self.dealer_hand:get_value(CountMethod.Hard)
  end

  self.dealer_hand.played = true
  self:pay_hands()
end

function Game:play_more_hands()
  self.current_player_hand = self.current_player_hand + 1
  local hand = self.player_hands[self.current_player_hand + 1]
  hand:deal_card()

  if hand:is_done() then
    hand:process()
    return
  end

  self:draw_hands()
  hand:get_action()
end

function Game:split_current_hand()
  local hand_count = #self.player_hands
  table.insert(self.player_hands, PlayerHand.new(self, self.current_bet))

  while hand_count > self.current_player_hand do
    self.player_hands[hand_count + 1] = self.player_hands[hand_count]:copy()
    hand_count = hand_count - 1
  end

  local current_hand = self.player_hands[self.current_player_hand + 1]
  local split_hand = self.player_hands[self.current_player_hand + 2]

  split_hand.cards = { current_hand.cards[2] }
  current_hand.cards = { current_hand.cards[1] }
  current_hand:deal_card()

  if current_hand:is_done() then
    current_hand:process()
    return
  end

  self:draw_hands()
  current_hand:get_action()
end

function Game:run()
  math.randomseed(os.time())
  self:unbuffer()

  while not self.quitting do
    self:deal_new_hand()
  end

  self:buffer()
end

function Game:save_game()
  local file = io.open(Game.save_file, 'w')
  if not file then
    return
  end

  file:write(string.format('%d|%d|%d|%d|%d',
    self.shoe.num_decks,
    math.floor(self.money),
    math.floor(self.current_bet),
    self.deck_type,
    self.face_type))
  file:close()
end

function Game:load_game()
  local file = io.open(Game.save_file, 'r')
  local contents = ''

  if file then
    contents = file:read('a') or ''
    file:close()
  end

  local fields = {}
  for field in contents:gmatch('[^|]+') do
    table.insert(fields, (field:gsub('%s+$', '')))
  end

  local num_decks = tonumber(fields[1])
  local money = tonumber(fields[2])
  local current_bet = tonumber(fields[3])
  local deck_type = tonumber(fields[4])
  local face_type = tonumber(fields[5])

  if #fields == 5 and num_decks and money and current_bet and deck_type and face_type then
    self.shoe.num_decks = math.floor(num_decks)
    self.money = money
    self.current_bet = math.floor(current_bet)
    self.deck_type = math.floor(deck_type)
    self.face_type = math.floor(face_type)
  end

  if self.money < Game.min_bet then
    self.money = 10000
    self.current_bet = Game.min_bet
  end
end

return Game
