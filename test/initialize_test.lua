local helpers = require("test.helpers")
helpers.bootstrap()

vim.g.loaded_docright = nil
vim.g.docright_opts = {
  system_prompt = "from-g",
}

vim.opt.rtp:prepend(vim.fn.getcwd())
vim.cmd.runtime("plugin/docright.lua")

helpers.assert_eq(require("docright.config").get().system_prompt, "from-g", "plugin loader should apply vim.g.docright_opts")
helpers.assert_eq(vim.fn.exists(":DocRight"), 2, "DocRight command should exist after plugin load")
