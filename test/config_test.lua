local helpers = require("test.helpers")
helpers.bootstrap()
vim.opt.rtp:prepend(vim.fn.getcwd())

local docright = require("docright")
local config = require("docright.config")

docright.setup({
  system_prompt = "X",
  mappings = {
    document = "<leader>xd",
    ask = "<leader>xa",
  },
})

helpers.assert_eq(config.get().system_prompt, "X", "system prompt should be stored in config")
helpers.assert_eq(config.get().mappings.document, "<leader>xd", "document mapping should be merged")
helpers.assert_eq(config.get().mappings.ask, "<leader>xa", "ask mapping should be merged")

docright.debug_config()
local buf_lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
helpers.assert_contains(table.concat(buf_lines, "\n"), "X", "debug config should show resolved system prompt")
