local harness = {}

local passed = 0
local failures = {}
local context_names = {}

local function context_path()
  return table.concat(context_names, ' ')
end

function harness.describe(name, body)
  table.insert(context_names, name)
  body()
  table.remove(context_names)
end

harness.context = harness.describe

function harness.it(name, body)
  table.insert(context_names, name)
  local description = context_path()
  local ok, err = xpcall(body, function(message)
    return debug.traceback(tostring(message), 2)
  end)
  table.remove(context_names)

  if ok then
    passed = passed + 1
    io.write('.')
  else
    table.insert(failures, { description = description, err = err })
    io.write('F')
  end
  io.stdout:flush()
end

local function fail(message)
  error(message, 3)
end

local function render(value)
  if type(value) == 'table' then
    local parts = {}
    for _, item in ipairs(value) do
      table.insert(parts, tostring(item))
    end
    return '{' .. table.concat(parts, ', ') .. '}'
  end
  return tostring(value)
end

function harness.assert_equal(actual, expected)
  if actual ~= expected then
    fail(string.format('expected %s, got %s', render(expected), render(actual)))
  end
end

function harness.assert_not_equal(actual, expected)
  if actual == expected then
    fail(string.format('expected a value other than %s', render(expected)))
  end
end

function harness.assert_true(value)
  if value ~= true then
    fail(string.format('expected true, got %s', render(value)))
  end
end

function harness.assert_false(value)
  if value ~= false then
    fail(string.format('expected false, got %s', render(value)))
  end
end

function harness.assert_nil(value)
  if value ~= nil then
    fail(string.format('expected nil, got %s', render(value)))
  end
end

function harness.assert_contains(haystack, needle)
  if not string.find(haystack, needle, 1, true) then
    fail(string.format('expected %q to contain %q', haystack, needle))
  end
end

function harness.assert_not_contains(haystack, needle)
  if string.find(haystack, needle, 1, true) then
    fail(string.format('expected %q to not contain %q', haystack, needle))
  end
end

function harness.assert_error(body)
  local ok = pcall(body)
  if ok then
    fail('expected an error to be raised')
  end
end

function harness.assert_count(list, expected)
  if #list ~= expected then
    fail(string.format('expected %d items, got %d', expected, #list))
  end
end

function harness.spy(return_value)
  local recorder = { calls = {}, return_value = return_value }

  return setmetatable(recorder, {
    __call = function(self, ...)
      table.insert(self.calls, table.pack(...))
      if self.impl then
        return self.impl(...)
      end
      if self.results then
        return self.results[#self.calls]
      end
      return self.return_value
    end,
  })
end

function harness.call_count(recorder)
  return #recorder.calls
end

function harness.called_with(recorder, ...)
  local wanted = table.pack(...)

  for _, call in ipairs(recorder.calls) do
    local matched = call.n - 1 == wanted.n
    if matched then
      for index = 1, wanted.n do
        if call[index + 1] ~= wanted[index] then
          matched = false
          break
        end
      end
    end
    if matched then
      return true
    end
  end

  return false
end

function harness.report()
  io.write('\n')

  for _, failure in ipairs(failures) do
    io.write(string.format('\nFAILED: %s\n%s\n', failure.description, failure.err))
  end

  io.write(string.format('\n%d passed, %d failed\n', passed, #failures))

  return #failures == 0
end

return harness
