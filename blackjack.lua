#!/usr/bin/env lua

local script_dir = (arg and arg[0] and arg[0]:match('(.*/)')) or './'
package.path = script_dir .. '?.lua;' .. package.path

local Game = require('bj.game')

Game.new():run()
