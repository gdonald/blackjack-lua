package.path = './?.lua;' .. package.path

local harness = require('tests.harness')

require('tests.test_card')
require('tests.test_shoe')
require('tests.test_hand')
require('tests.test_dealer_hand')
require('tests.test_player_hand')
require('tests.test_game')

os.exit(harness.report())
