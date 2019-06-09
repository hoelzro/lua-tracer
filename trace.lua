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

local function trace(target_filename, target_line, target_variable_name, emit)
  emit = emit or print
  assert(not d_gethook(), 'a debug hook is already active on this thread')

  local untraced_functions = setmetatable({}, {__mode = 'k'})
  local traced_functions   = setmetatable({}, {__mode = 'k'})

  local level_handler
  local below_handler

  -- this function does the heavy lifting - it detects
  -- if a function being called merits further attention,
  -- and sets the debug hook to level_handler if the function
  -- is one that contains a line we're tracing
  local function above_handler()
    local info = d_getinfo(2, 'fSL')
    local current_fn = info.func

    -- if we don't know anything about the current function, see if we should trace it
    -- or not
    if not untraced_functions[current_fn] and not traced_functions[current_fn] then
      -- we can't trace C functions
      if info.source == '=[C]' then
        untraced_functions[current_fn] = true
        return
      end

      -- if the function is not in our target file, ignore it
      if string.sub(info.source, 1, 1) ~= '@' or string.sub(info.source, 2) ~= target_filename then
        untraced_functions[current_fn] = true
        return
      end

      local first_line = m_huge
      local last_line  = 0

      for line in pairs(info.activelines) do
        first_line = m_min(first_line, line)
        last_line  = m_max(last_line, line)
      end

      -- ignore functions whose line ranges don't overlap the target line
      if target_line < first_line or target_line > last_line then
        untraced_functions[current_fn] = true
        return
      end

      -- error out if this line will never come up during a hook execution
      if not info.activelines[target_line] then
        untraced_functions[current_fn] = true
        return
      end

      traced_functions[current_fn] = true
    end

    -- XXX for testing
    assert(traced_functions[current_fn] or untraced_functions[current_fn])

    if untraced_functions[current_fn] then
      return
    end

    -- if we're here, it means current_fn is a tracee
    d_sethook(level_handler, 'clr')
  end

  -- this function runs when we're in a function that contains
  -- a line we're tracing
  --[[local]] function level_handler(event, line)
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
      d_sethook(above_handler, 'c')
    else -- call or tail call
      d_sethook(below_handler, 'r')
    end
  end

  -- this function runs if we're below a tracee on the call stack
  --[[local]] function below_handler()
    local info = d_getinfo(3, 'f') -- 3 is the function we're returning into

    if traced_functions[info.func] then
      d_sethook(level_handler, 'clr')
    end
  end

  d_sethook(above_handler, 'c')
end

return trace
