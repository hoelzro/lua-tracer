local lfs = require 'lfs'

local trace = require 'trace'

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

  local f = assert(io.open('tests/' .. script, 'r'))

  local is_tracing = false

  local got = {}
  local function emit(name, value)
    got[#got + 1] = name .. '\t' .. tostring(value)
  end

  local line_no = 1
  for line in f:lines() do
    local trace_var = string.match(line, '--%s*trace:%s*(%w+)%s*$')

    if trace_var then
      if is_tracing then
        error 'tracing multiple variable is not yet implemented'
      end

      is_tracing = true

      -- XXX I'd rather load up a table of locations to trace...
      trace('tests/' .. script, line_no, trace_var, emit)
    elseif string.match(line, '--%s*trace:') then
      error(string.format("%q looks like a trace comment, but it doesn't match the pattern", line))
    end

    line_no = line_no + 1
  end

  f:close()

  assert(is_tracing, 'you forgot to trace something in ' .. script)

  f = assert(io.open('tests/' .. output, 'r'))

  expected = f:read '*a'

  f:close()

  tracee() -- XXX pcall?

  got = table.concat(got, '\n') .. '\n'

  assert(got == expected, 'got ~= expected for ' .. script)

  debug.sethook() -- poor man's "untrace"
end

-- XXX don't trace lines that aren't in the same file
-- XXX fail to trace if the target line isn't traceable
-- XXX one function nested inside another
-- XXX recursive functions
-- XXX test tail calls
-- XXX mutually recursive functions
-- XXX multiple locals with the same name
