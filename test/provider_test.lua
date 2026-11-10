local helpers = require("test.helpers")
helpers.bootstrap()
vim.opt.rtp:prepend(vim.fn.getcwd())

local config = require("docright.config")
local providers = require("docright.provider")

local prompt = { system = "SYSTEM", user = "USER" }

local function has_header(headers, needle)
  for _, header in ipairs(headers) do
    if header:find(needle, 1, true) then
      return true
    end
  end
  return false
end

helpers.assert_contains(table.concat(providers.names(), ","), "anthropic", "anthropic should be a known provider")
helpers.assert_contains(table.concat(providers.names(), ","), "openrouter", "openrouter should be a known provider")

-- ollama
local ollama_opts = config.setup({ provider = "ollama" })
local ollama_spec = require("docright.provider.ollama").build(ollama_opts, prompt)
helpers.assert_eq(ollama_spec.url, "http://127.0.0.1:11434/api/generate", "ollama should use the generate endpoint")
helpers.assert_eq(ollama_spec.body.prompt, "SYSTEM\n\nUSER", "ollama should send one flat prompt")
helpers.assert_eq(ollama_spec.body.stream, false, "ollama should not stream")
helpers.assert_eq(ollama_spec.body.options.num_predict, 180, "ollama should pass num_predict")
helpers.assert_eq(#ollama_spec.headers, 0, "ollama should not need auth headers")

-- openai
vim.env.OPENAI_API_KEY = "sk-openai-test"
local openai_opts = config.setup({ provider = "openai" })
local openai_spec = require("docright.provider.openai").build(openai_opts, prompt)
helpers.assert_eq(openai_spec.url, "https://api.openai.com/v1/chat/completions", "openai should use chat completions")
helpers.assert_eq(openai_spec.body.messages[1].role, "system", "openai should send a system message")
helpers.assert_eq(openai_spec.body.messages[1].content, "SYSTEM", "openai system message should hold the system prompt")
helpers.assert_eq(openai_spec.body.messages[2].role, "user", "openai should send a user message")
helpers.assert_eq(openai_spec.body.messages[2].content, "USER", "openai user message should hold the user prompt")
helpers.assert_eq(openai_spec.body.max_tokens, 180, "openai should map num_predict to max_tokens")
helpers.assert_eq(has_header(openai_spec.headers, "Authorization: Bearer sk-openai-test"), true, "openai should send a bearer token")
helpers.assert_eq(has_header(openai_spec.headers, "HTTP-Referer"), false, "openai should not send OpenRouter headers")

-- openrouter
vim.env.OPENROUTER_API_KEY = "sk-or-test"
local openrouter_opts = config.setup({ provider = "openrouter" })
local openrouter_spec = require("docright.provider.openai").build(openrouter_opts, prompt)
helpers.assert_eq(openrouter_spec.url, "https://openrouter.ai/api/v1/chat/completions", "openrouter should use its own endpoint")
helpers.assert_eq(has_header(openrouter_spec.headers, "Authorization: Bearer sk-or-test"), true, "openrouter should send the env key")
helpers.assert_eq(has_header(openrouter_spec.headers, "HTTP-Referer"), true, "openrouter should send attribution headers")
helpers.assert_eq(openrouter_opts.api_key_env, "OPENROUTER_API_KEY", "openrouter should default to its env var")
helpers.assert_eq(openrouter_spec.body.reasoning.enabled, false, "openrouter should disable reasoning for short answers")
helpers.assert_eq(openai_spec.body.reasoning, nil, "openai should not send the reasoning field")

-- reasoning_mandatory
local openai_module = require("docright.provider.openai")
local mandatory = "Reasoning is mandatory for this endpoint and cannot be disabled."
helpers.assert_eq(openai_module.reasoning_mandatory(mandatory), true, "reasoning_mandatory should match the OpenRouter refusal")
helpers.assert_eq(openai_module.reasoning_mandatory("Bad request"), false, "reasoning_mandatory should ignore unrelated errors")
helpers.assert_eq(openai_module.reasoning_mandatory(nil), false, "reasoning_mandatory should tolerate nil messages")

-- anthropic
vim.env.ANTHROPIC_API_KEY = "sk-ant-test"
local anthropic_opts = config.setup({ provider = "anthropic" })
local anthropic_spec = require("docright.provider.anthropic").build(anthropic_opts, prompt)
helpers.assert_eq(anthropic_spec.url, "https://api.anthropic.com/v1/messages", "anthropic should use the messages endpoint")
helpers.assert_eq(anthropic_spec.body.system, "SYSTEM", "anthropic should use a native system field")
helpers.assert_eq(anthropic_spec.body.messages[1].content, "USER", "anthropic should send the user prompt")
helpers.assert_eq(has_header(anthropic_spec.headers, "x-api-key: sk-ant-test"), true, "anthropic should send x-api-key")
helpers.assert_eq(has_header(anthropic_spec.headers, "anthropic-version"), true, "anthropic should send an api version")

-- literal api_key wins over the environment
local literal_opts = config.setup({ provider = "anthropic", api_key = "literal-key" })
helpers.assert_eq(config.api_key(literal_opts), "literal-key", "literal api_key should win")
helpers.assert_eq(has_header(require("docright.provider.anthropic").build(literal_opts, prompt).headers, "x-api-key: literal-key"), true, "literal api_key should be used in headers")

-- missing key is reported without touching the network
vim.env.OPENAI_API_KEY = nil
local missing_opts = config.setup({ provider = "openai", api_key = nil })
helpers.assert_contains(providers.key_error(missing_opts), "OPENAI_API_KEY", "missing key error should name the env var")

local captured = nil
providers.generate(missing_opts, prompt, function(answer, err)
  captured = err
  helpers.assert_eq(answer, nil, "missing key should not produce an answer")
end)
helpers.assert_contains(captured, "No API key found", "generate should fail fast without a key")

-- missing model is reported without touching the network
local no_model = config.setup({ provider = "anthropic", model = "" })
local model_err = nil
providers.generate(no_model, prompt, function(answer, err)
  model_err = err
  helpers.assert_eq(answer, nil, "missing model should not produce an answer")
end)
helpers.assert_contains(model_err, "No model set", "generate should fail fast without a model")

-- response parsing
local openai = require("docright.provider.openai")
local anthropic = require("docright.provider.anthropic")
local ollama = require("docright.provider.ollama")

local answer, err = openai.parse({ choices = { { message = { content = "hi" } } } })
helpers.assert_eq(answer, "hi", "openai parse should read message content")
helpers.assert_eq(err, nil, "openai parse should not report an error")

answer = openai.parse({ choices = { { message = { content = { { text = "a" }, { text = "b" } } } } } })
helpers.assert_eq(answer, "a\nb", "openai parse should join content parts")

answer, err = openai.parse({})
helpers.assert_eq(answer, nil, "openai parse should not invent content")
helpers.assert_eq(type(err), "string", "openai parse should report a broken response")

answer = anthropic.parse({ content = { { type = "text", text = "a" }, { type = "text", text = "b" } } })
helpers.assert_eq(answer, "a\nb", "anthropic parse should join text blocks")

answer, err = anthropic.parse({ content = {} })
helpers.assert_eq(answer, nil, "anthropic parse should not invent content")
helpers.assert_eq(type(err), "string", "anthropic parse should report empty content")

answer = ollama.parse({ response = "ok" })
helpers.assert_eq(answer, "ok", "ollama parse should read response")

answer, err = ollama.parse({ error = "model not found" })
helpers.assert_eq(answer, nil, "ollama parse should not invent an answer")
helpers.assert_contains(err, "model not found", "ollama parse should surface errors")
