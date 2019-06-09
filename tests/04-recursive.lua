local function fib(n)
  assert(n >= 1)

  if n == 1 or n == 2 then
    return 1
  end

  return fib(n - 2) + fib(n - 1) -- trace: n
end

fib(10)
