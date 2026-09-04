local Card = require('bj.card')

local Shoe = {}
Shoe.__index = Shoe

Shoe.shuffle_specs = { 80, 81, 82, 84, 86, 89, 92, 95 }

function Shoe.new()
  return setmetatable({ num_decks = 8, cards = {}, cards_per_deck = 52 }, Shoe)
end

function Shoe:need_to_shuffle()
  if #self.cards == 0 then
    return true
  end

  local total_cards = self.num_decks * 52
  local cards_dealt = total_cards - #self.cards
  local used = (cards_dealt / total_cards) * 100.0

  return used > Shoe.shuffle_specs[self.num_decks]
end

function Shoe:shuffle()
  for _ = 1, 7 do
    for index = #self.cards, 2, -1 do
      local swap = math.random(index)
      self.cards[index], self.cards[swap] = self.cards[swap], self.cards[index]
    end
  end
end

function Shoe:get_next_card()
  return table.remove(self.cards, 1)
end

function Shoe:build_new_shoe(deck_type)
  if deck_type == 2 then
    self:new_aces()
  elseif deck_type == 3 then
    self:new_jacks()
  elseif deck_type == 4 then
    self:new_aces_jacks()
  elseif deck_type == 5 then
    self:new_sevens()
  elseif deck_type == 6 then
    self:new_eights()
  else
    self:new_regular()
  end

  self:shuffle()
end

function Shoe:get_total_cards()
  return self.num_decks * self.cards_per_deck
end

function Shoe:new_shoe(values)
  local total_cards = self:get_total_cards()
  self.cards = {}

  while #self.cards < total_cards do
    for _ = 1, self.num_decks do
      for suit = 0, 3 do
        if #self.cards >= total_cards then
          break
        end
        for _, value in ipairs(values) do
          if #self.cards >= total_cards then
            break
          end
          table.insert(self.cards, Card.new(value, suit))
        end
      end
    end
  end
end

function Shoe:new_regular()
  local values = {}
  for value = 0, 12 do
    table.insert(values, value)
  end
  self:new_shoe(values)
end

function Shoe:new_aces()
  self:new_shoe({ 0 })
end

function Shoe:new_jacks()
  self:new_shoe({ 10 })
end

function Shoe:new_aces_jacks()
  self:new_shoe({ 0, 10 })
end

function Shoe:new_sevens()
  self:new_shoe({ 6 })
end

function Shoe:new_eights()
  self:new_shoe({ 7 })
end

return Shoe
