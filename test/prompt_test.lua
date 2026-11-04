local helpers = require("test.helpers")
helpers.bootstrap()
vim.opt.rtp:prepend(vim.fn.getcwd())

local config = require("docright.config")
local prompts = require("docright.prompt")

local opts = config.setup({
  system_prompt = "CUSTOM",
  max_response_lines = 5,
})

helpers.assert_eq(prompts.system(opts), "CUSTOM", "custom system prompt should be used")

local documentation = prompts.documentation("local x = 1", opts)
helpers.assert_eq(documentation.system, "CUSTOM", "documentation prompt should carry the system prompt")
helpers.assert_contains(documentation.user, "Write at most 5 short lines.", "documentation prompt should budget lines")
helpers.assert_contains(documentation.user, "Programming context:", "documentation prompt should label context")
helpers.assert_contains(documentation.user, "local x = 1", "documentation prompt should include the code")

local followup = prompts.followup("what is x?", opts, { context = "CTX", answer = "ANS" })
helpers.assert_contains(followup.user, "CTX", "follow-up prompt should reuse context")
helpers.assert_contains(followup.user, "ANS", "follow-up prompt should reuse the previous answer")
helpers.assert_contains(followup.user, "what is x?", "follow-up prompt should include the question")
helpers.assert_eq(followup.system, "CUSTOM", "follow-up prompt should carry the system prompt")

local expansion = prompts.expansion("x", opts, { context = "CTX", answer = "ANS" })
helpers.assert_contains(expansion.user, "Selected item to expand:", "expansion prompt should label the selection")
helpers.assert_contains(expansion.user, "Write at most 8 short lines.", "expansion prompt should have a floor of 8 lines")

local blank = config.setup({ system_prompt = "   " })
helpers.assert_eq(prompts.system(blank), config.DEFAULT_SYSTEM_PROMPT, "blank system prompt should fall back to the default")

helpers.assert_contains(prompts.text(documentation), "CUSTOM", "text() should flatten the system prompt")
helpers.assert_contains(prompts.text(documentation), "Programming context:", "text() should flatten the user prompt")
