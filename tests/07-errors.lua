local function foo(i)
  error 'uh-oh' -- trace: i
end

local function bar(i)
  foo(i)
end

local function baz(i)
  bar(i)
end

for i = 1, 10 do
  pcall(baz, i)
end
