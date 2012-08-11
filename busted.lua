require 'luassert.assert'

local json = require 'dkjson'
local ansicolors = require 'ansicolors'
local lanes = require 'lanes'
lanes.configure()

-- setup for stuff we use inside
local global_context = { type = "describe", description = "global" }
local current_context = global_context
local busted_options = {}
local tests = {}
local linda = lanes.linda()

local successes = 0
local failures = 0

output = require('output.utf_terminal')()

-- Internal functions

local test = function(description, callback)
  local debug_info = debug.getinfo(callback)

  local info = {
    source = debug_info.source,
    short_src = debug_info.short_src,  
    linedefined = debug_info.linedefined,
  }

  local status, err = pcall(callback)

  local test_status = {}

  if err then
    test_status = { type = "failure", description = description, info = info, trace = debug.traceback(), err = err }
    failures = failures + 1
  else
    successes = successes + 1
    test_status = { type = "success", description = description, info = info }
  end

  if not busted_options.defer_print then
    output.currently_executing(test_status, busted_options)
  end

  return test_status
end

local num_tests = 0
run_context = function(context)
  local status = { description = context.description, type = "description" }

  local function set_status(astatus)
    linda:send("result", astatus)
  end

  for i,v in ipairs(context) do
    if v.type == "test" then
      num_tests = num_tests + 1
      table.insert(tests, function()
        if context.before_each ~= nil then
          context.before_each()
        end
        set_status(test(v.description, v.callback))
        if context.after_each ~= nil then
          context.after_each()
        end
      end)
    else
      if context.before_each ~= nil then
        context.before_each()
      end

      if v.type == "describe" then
        table.insert(status, run_context(v))
      elseif v.type == "pending" then
      local pending_test_status = { type = "pending", description = v.description, info = v.info }
      v.callback(pending_test_status)
      table.insert(status, pending_test_status)
      end

      if context.after_each ~= nil then
        context.after_each()
      end
    end
  end

  return status
end

local play_sound = function(failures)
  local failure_messages = {
    "You have %d busted specs",
    "Your specs are busted",
    "Your code is bad and you should feel bad",
    "Your code is in the Danger Zone",
    "Strange game. The only way to win is not to test",
    "My grandmother wrote better specs on a 3 86",
    "Every time there's a failure, drink another beer",
    "Feels bad man"
  }

  local success_messages = {
    "Aww yeah, passing specs",
    "Doesn't matter, had specs",
    "Feels good, man",
    "Great success",
    "Tests pass, drink another beer",
  }

  math.randomseed(os.time())

  if failures then
    os.execute("say \""..string.format(failure_messages[math.random(1, #failure_messages)], failures).."\"")
  else
    os.execute("say \""..success_messages[math.random(1, #failure_messages)].."\"")
  end
end

local busted = function()
  local ms = os.clock()

  if not busted_options.defer_print then
    print(output.header(global_context))
  end

  local statuses = run_context(global_context)
  for k,v in pairs(tests) do
    lanes.gen(v())()
  end

  while num_tests ~= 0 do
    num_tests = num_tests-1
    table.insert(status, linda:receive("result"))
  end

  ms = os.clock() - ms

  if busted_options.sound then
    play_sound(failures)
  end

  if busted_options.defer_print then
    print(output.header(global_context))
  end

  successes = 0
  failures = 0
  return output.formatted_status(statuses, busted_options, ms)
end

-- External functions

describe = function(description, callback)
  local local_context = { description = description, callback = callback, type = "describe"  }

  table.insert(current_context, local_context)

  current_context = local_context

  callback()

  current_context = global_context
end

it = function(description, callback)
  if current_context.description ~= nil then
    table.insert(current_context, { description = description, callback = callback, type = "test" })
  else
    test(description, callback)
  end
end

pending = function(description, callback)
  local debug_info = debug.getinfo(callback)

  local info = {
    source = debug_info.source,
    short_src = debug_info.short_src,  
    linedefined = debug_info.linedefined,
  }

  local test_status = {
    description = description,
    type = "pending",
    info = info,
    callback = function(self)
  if not busted_options.defer_print then
        output.currently_executing(self, busted_options)
  end
end
  }

  table.insert(current_context, test_status)
end

spy_on = function(object, method)
  error("Not implemented yet!")
end

mock = function(object)
  error("Not implemented yet!")
end

before_each = function(callback)
  current_context.before_each = callback
end

after_each = function(callback)
  current_context.after_each = callback
end

set_busted_options = function(options)
  busted_options = options

  if options.output_lib then
    output = require('output.'..options.output_lib)()
  end
end

return busted
