local test_files = {
  "test/config_test.lua",
  "test/initialize_test.lua",
  "test/mappings_test.lua",
  "test/prompt_test.lua",
  "test/provider_test.lua",
  "test/switch_test.lua",
}

local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/test/?.lua",
  root .. "/test/?/init.lua",
  package.path,
}, ";")

for _, file in ipairs(test_files) do
  package.loaded["test.helpers"] = nil

  local helpers = require("test.helpers")
  helpers.reset_modules()

  dofile(root .. "/" .. file)
end

print("DocRight tests passed\n")
