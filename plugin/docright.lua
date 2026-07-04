if vim.g.loaded_docright == 1 then
  return
end

vim.g.loaded_docright = 1

local config = require("docright.config")

if not config.is_initialized() then
  require("docright").setup(vim.g.docright_opts)
end
