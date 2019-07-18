local lfs = require 'lfs'

local trace = require 'trace'

local find_tracepoints = require 'tools.find_tracepoints'

-- XXX deterministic test order?
local function gather_tests()
  local tests = {}

  for filename in lfs.dir 'tests/' do
    if string.sub(filename, -4) == '.lua' then
      tests[#tests + 1] = {
        script = filename,
        output = string.sub(filename, 1, -5) .. '.out',
      }
    end
  end

  return tests
end

local tests = gather_tests()

for i = 1, #tests do
  local script = tests[i].script
  local output = tests[i].output

  -- XXX invoke in a subprocess?
  local tracee = assert(loadfile('tests/' .. script))

  local tracepoints = assert(find_tracepoints('tests/' .. script))

  assert(#tracepoints > 0, 'you forgot to trace something in ' .. script)
  assert(#tracepoints == 1, 'tracing multiple variables is not yet implemented')

  local got = {}
  local function emit(name, value)
    got[#got + 1] = name .. '\t' .. tostring(value)
  end

  for i = 1, #tracepoints do
    trace(tracepoints[i].filename, tracepoints[i].line_no, tracepoints[i].variable, emit)
  end

  f = io.open('tests/' .. output, 'r')

  if f then
    expected = f:read '*a'

    f:close()

    tracee() -- XXX pcall?

    got = table.concat(got, '\n') .. '\n'

    assert(got == expected, 'got ~= expected for ' .. script)
  end

  debug.sethook() -- poor man's "untrace"
end

-- XXX don't trace lines that aren't in the same file (what if you chdir and loadfile a file of the same name?)
-- XXX what about tracing files by absolute path?
-- XXX fail to trace if the target line isn't traceable
-- XXX test tail calls (non-recursive ones - I'm currently testing recursive ones)
-- XXX mutually recursive functions
-- XXX multiple locals with the same name
-- XXX printing upvalues
-- XXX "mock" debug.sethook for calling our hook upon appropriate events, make sure line hook isn't active unless it's in the right function, profiling our tracer
-- XXX I'm thinking of printing out the line of traced source at emit() time - what happens if the user changes the underlying file?
--     - a) don't care - they shouldn't do that
--     - b) recompile the file and check that the string.dump contents of things match
--
-- XXX nargs for trace(fn) - 5.3ism, first nargs locals
-- XXX test above handler handling tail calls
-- XXX use "mock" hook to run trace hooks, make sure emit is called at right time (in addition to raw output comparison - this is for extra diagnostics)
-- XXX below handler can bear brunt if traced function is high up in the call stack
-- XXX assert(untraced_functions[fn] or traced_functions[fn]) in below handler
-- XXX what about a Lua function that's called by a C function called by a Lua function?
