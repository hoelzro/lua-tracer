local function find_tracepoints(filename)
  local f, err = io.open(filename, 'r')

  if not f then
    return nil, err
  end

  local tracepoints = {}

  local line_no = 1
  for line in f:lines() do
    local trace_var = string.match(line, '--%s*trace:%s*(%w+)%s*$')

    if trace_var then
      tracepoints[#tracepoints + 1] = {
        filename = filename,
        line_no  = line_no,
        variable = trace_var,
      }
    elseif string.match(line, '--%s*trace:') then
      error(string.format("%q looks like a trace comment, but it doesn't match the pattern", line))
    end

    line_no = line_no + 1
  end
  f:close()

  return tracepoints
end

return find_tracepoints
