local function foo(a)
  local c = 1

  local function bar(a)
    local function baz(a)
      local b = a -- trace: a
    end

    baz(a)
  end

  bar(a)
end

foo(6)
