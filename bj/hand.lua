local Hand = {}
Hand.__index = Hand

Hand.CountMethod = { Soft = 0, Hard = 1 }

function Hand.new(game)
  return setmetatable({ game = game, cards = {}, stood = false, played = false }, Hand)
end

function Hand:deal_card()
  table.insert(self.cards, self.game.shoe:get_next_card())
end

function Hand:is_blackjack()
  if #self.cards ~= 2 then
    return false
  end

  if self.cards[1]:is_ace() and self.cards[2]:is_ten() then
    return true
  end

  return self.cards[2]:is_ace() and self.cards[1]:is_ten()
end

return Hand
