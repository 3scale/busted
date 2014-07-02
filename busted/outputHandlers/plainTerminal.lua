local s = require 'say'
local pretty = require 'pl.pretty'

return function(options, busted)
  local handler = require 'busted.outputHandlers.base'(busted)

  local successDot =  '+'
  local failureDot =  '-'
  local errorDot =  '*'
  local pendingDot = '.'

  local pendingDescription = function(pending)
    local name = handler.getFullName(pending)

    local string = s('output.pending') .. ' → ' ..
      pending.trace.short_src .. ' @ ' ..
      pending.trace.currentline  ..
      '\n' .. name

    return string
  end

  local failureDescription = function(failure, isError)
    local string = s('output.failure') .. ' → '

    if isError then
      string = s('output.error')

      if failure.message then
        string = string .. ' → ' ..  failure.message .. '\n'
      end
    else
      string = string ..
        failure.trace.short_src .. ' @ ' ..
        failure.trace.currentline .. '\n' ..
        handler.getFullName(failure) .. '\n'

      if type(failure.message) == 'string' then
        string = string .. failure.message
      elseif failure.message == nil then
        string = string .. 'Nil error'
      else
        string = string .. pretty.write(failure.message)
      end
    end

    if options.verbose then
      string = string .. '\n' .. failure.trace.traceback
    end

    return string
  end

  local statusString = function()
    local successString = s('output.success_plural')
    local failureString = s('output.failure_plural')
    local pendingString = s('output.pending_plural')
    local errorString = s('output.error_plural')

    local ms = handler.getDuration()
    local successes = handler.successesCount
    local pendings = handler.pendingsCount
    local failures = handler.failuresCount
    local errors = handler.errorsCount

    if successes == 0 then
      successString = s('output.success_zero')
    elseif successes == 1 then
      successString = s('output.success_single')
    end

    if failures == 0 then
      failureString = s('output.failure_zero')
    elseif failures == 1 then
      failureString = s('output.failure_single')
    end

    if pendings == 0 then
      pendingString = s('output.pending_zero')
    elseif pendings == 1 then
      pendingString = s('output.pending_single')
    end

    if errors == 0 then
      errorString = s('output.error_zero')
    elseif errors == 1 then
      errorString = s('output.error_single')
    end

    local formattedTime = ('%.6f'):format(ms):gsub('([0-9])0+$', '%1')

    return successes .. ' ' .. successString .. ' / ' ..
      failures .. ' ' .. failureString .. ' / ' ..
      errors .. ' ' .. errorString .. ' / ' ..
      pendings .. ' ' .. pendingString .. ' : ' ..
      formattedTime .. ' ' .. s('output.seconds')
  end

  handler.testEnd = function(element, parent, status, debug)
    if not options.deferPrint then
      local string = successDot

      if status == 'pending' then
        string = pendingDot
      elseif status == 'failure' then
        string = failureDot
      end

      io.write(string)
      io.flush()
    end

    return nil, true
  end

  handler.suiteEnd = function(name, parent)
    print('')
    print(statusString())

    for i, pending in pairs(handler.pendings) do
      print('')
      print(pendingDescription(pending))
    end

    for i, err in pairs(handler.failures) do
      print('')
      print(failureDescription(err))
    end

    for i, err in pairs(handler.errors) do
      print('')
      print(failureDescription(err, true))
    end

    return nil, true
  end

  handler.error = function(element, parent, message, debug)
    io.write(errorString)
    io.flush()

    return nil, true
  end

  return handler
end
