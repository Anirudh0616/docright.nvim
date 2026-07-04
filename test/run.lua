local test_files = {
  "test/config_test.lua",
  "test/initialize_test.lua",
  "test/mappings_test.lua",
}

local root = vim.fn.getcwd()
package.path = table.concat({
  root .. "/test/?.lua",
  root .. "/test/?/init.lua",
  package.path,
}, ";")

for _, file in ipairs(test_files) do
  package.loaded["test.helpers"] = nil
  package.loaded["docright"] = nil
  package.loaded["docright.config"] = nil
  package.loaded["docright.context"] = nil
  package.loaded["docright.ui"] = nil
  package.loaded["docright.provider.ollama"] = nil

  dofile(root .. "/" .. file)
end

print("DocRight tests passed\n")
