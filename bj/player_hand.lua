local Hand = require('bj.hand')

local CountMethod = Hand.CountMethod

local PlayerHand = setmetatable({}, { __index = Hand })
PlayerHand.__index = PlayerHand

PlayerHand.HandStatus = { Unknown = 0, Won = 1, Lost = 2, Push = 3 }

local HandStatus = PlayerHand.HandStatus

PlayerHand.max_player_hands = 7

function PlayerHand.new(game, bet)
  local hand = Hand.new(game)
  hand.bet = bet
  hand.status = HandStatus.Unknown
  hand.paid = false
  return setmetatable(hand, PlayerHand)
end

function PlayerHand:copy()
  local hand = PlayerHand.new(self.game, self.bet)
  hand.status = self.status
  hand.paid = self.paid
  hand.stood = self.stood
  hand.played = self.played
  for _, card in ipairs(self.cards) do
    table.insert(hand.cards, card)
  end
  return hand
end

function PlayerHand:is_busted()
  return self:get_value(CountMethod.Soft) > 21
end

function PlayerHand:get_value(count_method)
  local total = 0

  for _, card in ipairs(self.cards) do
    local value = card.value + 1
    if value > 9 then
      value = 10
    end
    if count_method == CountMethod.Soft and value == 1 and total < 11 then
      value = 11
    end
    total = total + value
  end

  if count_method == CountMethod.Soft and total > 21 then
    return self:get_value(CountMethod.Hard)
  end

  return total
end

function PlayerHand:is_twenty_one()
  return self:get_value(CountMethod.Soft) == 21 or self:get_value(CountMethod.Hard) == 21
end

function PlayerHand:is_done()
  if self.played or self.stood or self:is_blackjack() or self:is_busted() or self:is_twenty_one() then
    self.played = true

    if not self.paid and self:is_busted() then
      self.paid = true
      self.status = HandStatus.Lost
      self.game.money = self.game.money - self.bet
    end

    return true
  end

  return false
end

function PlayerHand:can_split()
  if self.stood or #self.game.player_hands >= PlayerHand.max_player_hands then
    return false
  end

  if self.game.money < self.game:all_bets() + self.bet then
    return false
  end

  return #self.cards == 2 and self.cards[1].value == self.cards[2].value
end

function PlayerHand:can_dbl()
  if self.game.money < self.game:all_bets() + self.bet then
    return false
  end

  if self.stood or #self.cards ~= 2 or self:is_busted() or self:is_blackjack() then
    return false
  end

  return true
end

function PlayerHand:can_stand()
  return not (self.stood or self:is_busted() or self:is_blackjack())
end

function PlayerHand:can_hit()
  if self.played or self.stood or self:is_blackjack() or self:is_busted() then
    return false
  end

  return self:get_value(CountMethod.Hard) ~= 21
end

function PlayerHand:hit()
  self:deal_card()

  if self:is_done() then
    self:process()
    return
  end

  self.game:draw_hands()
  self.game.player_hands[self.game.current_player_hand + 1]:get_action()
end

function PlayerHand:dbl()
  self:deal_card()
  self.played = true
  self.bet = self.bet * 2

  if self:is_done() then
    self:process()
  end
end

function PlayerHand:stand()
  self.stood = true
  self.played = true
  self:process()
end

function PlayerHand:process()
  if self.game:more_hands_to_play() then
    self.game:play_more_hands()
    return
  end

  self.game:play_dealer_hand()
  self.game:draw_hands()
  self.game:bet_options()
end

function PlayerHand:to_string()
  local out = ' '

  for _, card in ipairs(self.cards) do
    out = out .. self.game:card_face(card.value, card.suit) .. ' '
  end

  out = string.format('%s ⇒  %d ', out, self:get_value(CountMethod.Soft))

  if self.status == HandStatus.Lost then
    out = out .. '-'
  elseif self.status == HandStatus.Won then
    out = out .. '+'
  end

  out = string.format('%s$%.2f', out, self.bet / 100.0)

  if not self.played and self == self.game.player_hands[self.game.current_player_hand + 1] then
    out = out .. ' ⇐'
  end

  out = out .. ' '

  if self.status == HandStatus.Lost then
    out = out .. (self:is_busted() and 'Busted!' or 'Lose!')
  elseif self.status == HandStatus.Won then
    out = out .. (self:is_blackjack() and 'Blackjack!' or 'Win!')
  elseif self.status == HandStatus.Push then
    out = out .. 'Push!'
  end

  return out .. '\n'
end

PlayerHand.__tostring = PlayerHand.to_string

function PlayerHand:get_action()
  local out = ' '

  if self:can_hit() then
    out = out .. '(H) Hit  '
  end
  if self:can_stand() then
    out = out .. '(S) Stand  '
  end
  if self:can_split() then
    out = out .. '(P) Split  '
  end
  if self:can_dbl() then
    out = out .. '(D) Double  '
  end

  self.game:write(out .. '\n')

  while true do
    local key = self.game:read_char()

    if key == 'h' then
      self:hit()
      return
    elseif key == 's' then
      self:stand()
      return
    elseif key == 'p' then
      if self:can_split() then
        self.game:split_current_hand()
        return
      end
    elseif key == 'd' then
      self:dbl()
      return
    end
  end
end

return PlayerHand
