local function make_counter()
  local counter = 1

  return function()
    local value = counter
    counter = counter + 1 -- trace: value
    return value
  end
end

local a = make_counter()
local b = make_counter()

for i = 1, 10 do
  a()
  b()
end
