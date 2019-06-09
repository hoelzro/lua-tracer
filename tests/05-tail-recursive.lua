local function length(list, accum)
  accum = accum or 0

  if not list then -- trace: accum
    return accum
  else
    return length(list.next, accum + 1)
  end
end

local list = {}

do
  local node = list

  for i = 1, 5 do
    node.next = {}
    node = node.next
  end
end

length(list)
