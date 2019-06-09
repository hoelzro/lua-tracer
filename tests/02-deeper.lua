local function foo(a)
  local b = a -- trace: a
end

local function bar(a)
  foo(a)
end

local function baz(a)
  bar(a)
end

baz(2)
bar(4)
