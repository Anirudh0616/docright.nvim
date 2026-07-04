local M = {}

function M.bootstrap()
  package.loaded["docright"] = nil
  package.loaded["docright.config"] = nil
  package.loaded["docright.context"] = nil
  package.loaded["docright.ui"] = nil
  package.loaded["docright.provider.ollama"] = nil
end

function M.assert_contains(haystack, needle, message)
  if not tostring(haystack):find(needle, 1, true) then
    error(message or ("expected to find " .. needle), 2)
  end
end

function M.assert_eq(actual, expected, message)
  if actual ~= expected then
    error(message or ("expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual)), 2)
  end
end

return M
