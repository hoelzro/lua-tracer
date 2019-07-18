local tracee

local function deepest()
  tracee(false)
end

--[[local]] function tracee(go_deeper)
  if go_deeper then
    deepest()
  end

  local b = 1 -- trace: go_deeper
end

local function deep()
  tracee(true)
end

deep()
