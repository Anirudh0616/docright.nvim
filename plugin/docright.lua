if vim.g.loaded_docright == 1 then
  return
end

vim.g.loaded_docright = 1

require("docright").setup(vim.g.docright_opts)
