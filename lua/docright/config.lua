local M = {}

M.DEFAULT_SYSTEM_PROMPT = table.concat({
  "You are DocRight, a Neovim documentation assistant.",
  "Only answer questions about programming languages, source code, APIs, libraries, frameworks, developer tooling, compilers, runtimes, and software engineering concepts.",
  "If the request is not about programming, refuse briefly and say you can only help with programming documentation.",
  "Base your answer on the provided code or symbol when possible.",
  "Use a compact documentation-reference style.",
  "No intro, no outro, no broad tutorial.",
  "Prefer bullets shaped like `name`: what it does.",
  "Mention only the important components, parameters, return values, side effects, or gotchas visible in the code.",
}, "\n")

M.presets = {
  ollama = {
    endpoint = "http://127.0.0.1:11434/api/generate",
    model = "qwen2.5-coder:7b",
  },
  openai = {
    endpoint = "https://api.openai.com/v1/chat/completions",
    model = "gpt-4o-mini",
    api_key_env = "OPENAI_API_KEY",
  },
  openrouter = {
    endpoint = "https://openrouter.ai/api/v1/chat/completions",
    model = "anthropic/claude-3.5-sonnet",
    api_key_env = "OPENROUTER_API_KEY",
  },
  anthropic = {
    endpoint = "https://api.anthropic.com/v1/messages",
    model = "claude-3-5-sonnet-latest",
    api_key_env = "ANTHROPIC_API_KEY",
  },
}

M.defaults = {
  provider = "ollama",
  model = "qwen2.5-coder:7b",
  endpoint = "http://127.0.0.1:11434/api/generate",
  api_key = nil,
  api_key_env = nil,
  extra_headers = {},
  temperature = 0.2,
  num_predict = 180,
  max_tokens = nil,
  timeout_ms = 60000,
  keep_alive = "10m",
  max_context_lines = 50,
  max_response_lines = 8,
  system_prompt = M.DEFAULT_SYSTEM_PROMPT,
  window = {
    width = 64,
    height = 0.97,
    border = "rounded",
    position = "right",
  },
  mappings = {
    document = "<leader>ad",
    ask = "<leader>aa",
  },
  model_suggestions = {
    "z-ai/glm-5.3-flash",
    "deepseek/deepseek-v4.1-flash",
    "google/gemini-2.5-flash",
    "meta-llama/llama-3.3-70b-instruct",
    "mistralai/mistral-small-2603",
  },
}

M.options = vim.deepcopy(M.defaults)
M.initialized = false

local function merge(provider, opts)
  local preset = M.presets[provider or M.defaults.provider] or {}
  local merged = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), vim.deepcopy(preset), opts or {})
  merged.provider = provider or merged.provider
  return merged
end

function M.setup(opts)
  opts = opts or {}
  M.options = merge(opts.provider or M.options.provider or M.defaults.provider, opts)
  M.initialized = true
  return M.options
end

function M.get()
  return M.options
end

function M.is_initialized()
  return M.initialized
end

function M.is_known_provider(name)
  return M.presets[name] ~= nil
end

function M.key_env_name(opts)
  opts = opts or M.options
  if type(opts.api_key_env) == "string" and opts.api_key_env ~= "" then
    return opts.api_key_env
  end

  local preset = M.presets[opts.provider or ""] or {}
  if type(preset.api_key_env) == "string" then
    return preset.api_key_env
  end

  return string.upper(tostring(opts.provider or "provider")) .. "_API_KEY"
end

function M.key_source(opts)
  opts = opts or M.options

  if type(opts.api_key) == "string" and opts.api_key:match("%S") then
    return "the `api_key` option"
  end

  return "`" .. M.key_env_name(opts) .. "`"
end

function M.api_key(opts)
  opts = opts or M.options

  if type(opts.api_key) == "string" and opts.api_key:match("%S") then
    return opts.api_key
  end

  local value = vim.env[M.key_env_name(opts)]
  if type(value) == "string" and value:match("%S") then
    return value
  end

  return nil
end

return M
