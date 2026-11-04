local helpers = require("test.helpers")
helpers.bootstrap()
vim.opt.rtp:prepend(vim.fn.getcwd())

local config = require("docright.config")
local docright = require("docright")

vim.env.OPENROUTER_API_KEY = "sk-or-switch"

docright.setup({ provider = "ollama" })
helpers.assert_eq(config.get().provider, "ollama", "setup should keep the requested provider")
helpers.assert_eq(config.get().endpoint, "http://127.0.0.1:11434/api/generate", "setup should apply the ollama preset")

local switched = docright.set_provider("openrouter")
helpers.assert_eq(switched.provider, "openrouter", "set_provider should switch the provider")
helpers.assert_eq(switched.endpoint, "https://openrouter.ai/api/v1/chat/completions", "set_provider should apply the openrouter endpoint")
helpers.assert_eq(switched.model, config.presets.openrouter.model, "set_provider should apply the openrouter model")
helpers.assert_eq(switched.api_key_env, "OPENROUTER_API_KEY", "set_provider should apply the openrouter key env")
helpers.assert_eq(switched.system_prompt, config.DEFAULT_SYSTEM_PROMPT, "set_provider should keep the system prompt")

local _, err = docright.set_provider("nope")
helpers.assert_contains(err, "unknown provider", "set_provider should reject unknown providers")
helpers.assert_eq(config.get().provider, "openrouter", "a rejected switch should not change the provider")

docright.set_model("some/model")
helpers.assert_eq(config.get().model, "some/model", "set_model should change the model")
helpers.assert_eq(config.get().provider, "openrouter", "set_model should keep the provider")

local overridden = docright.set_provider("anthropic", { model = "custom-model" })
helpers.assert_eq(overridden.model, "custom-model", "set_provider overrides should win over the preset")
helpers.assert_eq(overridden.api_key_env, "ANTHROPIC_API_KEY", "set_provider should still apply the key env")

local suggestions = config.get().model_suggestions
helpers.assert_eq(type(suggestions), "table", "model suggestions should exist")
helpers.assert_eq(#suggestions, 5, "there should be five model suggestions")
helpers.assert_eq(#docright.complete_models(""), 5, "empty lead should return all suggestions")
helpers.assert_eq(#docright.complete_models("flash"), 3, "flash should match three suggestions")
helpers.assert_contains(table.concat(docright.complete_models("GLM"), ","), "z-ai/glm-5.3-flash", "matching should be case-insensitive")

local custom = docright.setup({
  provider = "openrouter",
  model = "openai/gpt-4o-mini",
  api_key_env = "MY_KEY",
  extra_headers = { "X-Custom: 1" },
})
helpers.assert_eq(custom.model, "openai/gpt-4o-mini", "explicit model should win over the preset")
helpers.assert_eq(custom.endpoint, "https://openrouter.ai/api/v1/chat/completions", "preset endpoint should survive")
helpers.assert_eq(custom.api_key_env, "MY_KEY", "explicit api_key_env should win over the preset")
helpers.assert_eq(#custom.extra_headers, 1, "extra headers should be stored")
helpers.assert_eq(vim.fn.exists(":DocRightProvider"), 2, "DocRightProvider command should exist")
helpers.assert_eq(vim.fn.exists(":DocRightModel"), 2, "DocRightModel command should exist")

-- completion can be replaced through the option
local edited = docright.setup({ model_suggestions = { "one", "two" } })
helpers.assert_eq(#edited.model_suggestions, 2, "setup should override model_suggestions")
helpers.assert_eq(#docright.complete_models(""), 2, "completion should read the overridden list")
