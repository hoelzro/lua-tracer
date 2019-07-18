-- Copyright 2019 Rob Hoelz

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

local d_gethook  = debug.gethook
local d_getlocal = debug.getlocal
local d_getinfo  = debug.getinfo
local d_sethook  = debug.sethook

local m_huge = math.huge
local m_max  = math.max
local m_min  = math.min

local assert = assert
local pairs  = pairs
local print  = print

--local DEBUG = print
local function DEBUG() end

--[[local]] function trace(target_filename, target_line, target_variable_name, emit)
  emit = emit or print
  assert(not d_gethook(), 'a debug hook is already active on this thread')

  local inner_handler
  local outer_handler

  local untraced_functions = setmetatable({}, {__mode = 'k'})
  local traced_functions   = setmetatable({}, {__mode = 'k'})

  local function is_tracee(info)
    local fn = info.func

    if untraced_functions[fn] then
      return false
    elseif traced_functions[fn] then
      return true
    else
      -- if we don't know anything about the current function, see if we should trace it
      -- or not

      DEBUG('considering', fn)

      -- we can't trace C functions
      if info.source == '=[C]' then
        DEBUG 'C function - nope'
        untraced_functions[fn] = true
        return false
      end

      -- if the function is not in our target file, ignore it
      if string.sub(info.source, 1, 1) ~= '@' or string.sub(info.source, 2) ~= target_filename then
        DEBUG('wrong file - nope', target_filename, info.source)
        untraced_functions[fn] = true
        return false
      end

      -- XXX I think you can use linedefined and lastlinedefined unless it's main
      local first_line = m_huge
      local last_line  = 0

      for line in pairs(info.activelines) do
        first_line = m_min(first_line, line)
        last_line  = m_max(last_line, line)
      end

      -- ignore functions whose line ranges don't overlap the target line
      if target_line < first_line or target_line > last_line then
        DEBUG 'outside of line range - nope'
        untraced_functions[fn] = true
        return false
      end

      -- XXX error out if this line will never come up during a hook execution
      if not info.activelines[target_line] then
        DEBUG 'target line is not active - nope'
        untraced_functions[fn] = true
        return false
      end

      DEBUG 'yup!'
      traced_functions[fn] = true
      return true
    end
  end

  --[[local]] function inner_handler(event, line)
    if event == 'line' then
      if line == target_line then
        local i = 1

        while true do
          local name, value = d_getlocal(2, i)

          if not name then
            break
          end

          if name == target_variable_name then
            emit(name, value)
            break
          end

          i = i + 1
        end

        -- XXX complain if we couldn't find the traced variable?
        -- XXX maintain the local index of the traced variable after you've found it?
      end
    elseif event == 'return' then
      local info = d_getinfo(3, 'fSL') -- 3 is the function we're returning into

      if not is_tracee(info) then
        -- XXX you might need to change the mask if there's a tracee on the stack
        DEBUG 'setting outer handler [1]'
        d_sethook(outer_handler, 'cr')
      end
    else -- call or tail call
      local info = d_getinfo(2, 'fSL') -- 2 is the function we've just called into

      if not is_tracee(info) then
        -- XXX you might need to change the mask if there's a tracee on the stack
        DEBUG 'setting outer handler [2]'
        d_sethook(outer_handler, 'cr') -- XXX 'cr'?
      end
    end
  end

  --[[local]] function outer_handler(event)
    -- XXX most of the time, we should hit untraced_functions or traced_functions
    -- in a lookup - how bad is it to use 'SL' in the mask vs leaving it off?
    -- should I inline the checks to untraced_functions and traced_functions and
    -- reinvoke d_getinfo in this case?
    if event == 'return' then
      local info = d_getinfo(3, 'fSL') -- 3 is the function we're returning into

      if is_tracee(info) then
        DEBUG 'setting inner handler [1]'
        d_sethook(inner_handler, 'clr')
      end
    else -- call or tail call
      local info = d_getinfo(2, 'fSL') -- 2 is the function we've just called into

      if is_tracee(info) then
        DEBUG 'setting inner handler [2]'
        d_sethook(inner_handler, 'clr')
      end
    end
  end

  -- XXX you might need to change the mask if there's a tracee on the stack
  --     you might need to change the hook to inner_handler if our caller is a tracee
  DEBUG 'setting outer handler[3]'
  d_sethook(outer_handler, 'c')
end

return trace
