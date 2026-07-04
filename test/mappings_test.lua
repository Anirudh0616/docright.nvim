local helpers = require("test.helpers")
helpers.bootstrap()

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.rtp:prepend(vim.fn.getcwd())

require("docright").setup({
  system_prompt = "X",
})

helpers.assert_eq(vim.fn.maparg("<leader>ad", "n"), "", "normal document mapping should be deferred until VimEnter")
helpers.assert_eq(vim.fn.maparg("<leader>aa", "n"), "", "ask mapping should be deferred until VimEnter")

vim.api.nvim_exec_autocmds("VimEnter", { modeline = false })

helpers.assert_contains(vim.inspect(vim.fn.maparg("<leader>ad", "n", false, true)), "DocRight document cursor context", "normal document mapping should be installed")
helpers.assert_contains(vim.inspect(vim.fn.maparg("<leader>aa", "n", false, true)), "DocRight ask follow-up", "ask mapping should be installed")
helpers.assert_contains(vim.inspect(vim.fn.maparg("<leader>ad", "v", false, true)), "DocRight document selection", "visual document mapping should be installed")
