local Hand = require('bj.hand')

local CountMethod = Hand.CountMethod

local DealerHand = setmetatable({}, { __index = Hand })
DealerHand.__index = DealerHand

function DealerHand.new(game)
  local hand = Hand.new(game)
  hand.hide_down_card = true
  return setmetatable(hand, DealerHand)
end

function DealerHand:is_busted()
  return self:get_value(CountMethod.Soft) > 21
end

function DealerHand:get_value(count_method)
  local total = 0

  for index, card in ipairs(self.cards) do
    if not (index == 2 and self.hide_down_card) then
      local value = card.value + 1
      if value > 9 then
        value = 10
      end
      if count_method == CountMethod.Soft and value == 1 and total < 11 then
        value = 11
      end
      total = total + value
    end
  end

  if count_method == CountMethod.Soft and total > 21 then
    return self:get_value(CountMethod.Hard)
  end

  return total
end

function DealerHand:to_string()
  local out = ' '

  for index, card in ipairs(self.cards) do
    if index == 2 and self.hide_down_card then
      out = out .. self.game:card_face(13, 0) .. ' '
    else
      out = out .. self.game:card_face(card.value, card.suit) .. ' '
    end
  end

  return string.format('%s ⇒  %d', out, self:get_value(CountMethod.Soft))
end

DealerHand.__tostring = DealerHand.to_string

function DealerHand:upcard_is_ace()
  return self.cards[1]:is_ace()
end

return DealerHand
