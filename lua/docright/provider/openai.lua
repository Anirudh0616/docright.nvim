local config = require("docright.config")

local M = {}

M.requires_api_key = true

local function headers(opts)
  local list = {}
  local key = config.api_key(opts)

  if key then
    table.insert(list, "Authorization: Bearer " .. key)
  end

  if opts.provider == "openrouter" then
    table.insert(list, "HTTP-Referer: https://github.com/Anirudh0616/docright.nvim")
    table.insert(list, "X-Title: DocRight.nvim")
  end

  for _, header in ipairs(opts.extra_headers or {}) do
    table.insert(list, header)
  end

  return list
end

function M.build(opts, prompt)
  local body = {
    model = opts.model,
    stream = false,
    temperature = opts.temperature,
    max_tokens = opts.max_tokens or opts.num_predict,
    messages = {
      { role = "system", content = prompt.system },
      { role = "user", content = prompt.user },
    },
  }

  -- Reasoning models (qwen3, etc.) can spend the whole token budget on
  -- hidden reasoning and return nil content. DocRight wants short answers.
  if opts.provider == "openrouter" then
    body.reasoning = { enabled = false }
  end

  return {
    url = opts.endpoint,
    timeout_ms = opts.timeout_ms,
    headers = headers(opts),
    body = body,
  }
end

function M.reasoning_mandatory(message)
  if type(message) ~= "string" then
    return false
  end

  local lowered = message:lower()
  local mentions_reasoning = lowered:find("reasoning", 1, true) ~= nil
  local refuses_disable = lowered:find("mandatory", 1, true) ~= nil
    or lowered:find("cannot be disabled", 1, true) ~= nil

  return mentions_reasoning and refuses_disable
end

function M.parse(decoded)
  if type(decoded) ~= "table" then
    return nil, "Unexpected response from the model provider."
  end

  local choice = type(decoded.choices) == "table" and decoded.choices[1] or nil
  if type(choice) ~= "table" or type(choice.message) ~= "table" then
    return nil, "Response did not contain a message."
  end

  local content = choice.message.content
  if type(content) == "table" then
    local parts = {}
    for _, part in ipairs(content) do
      if type(part) == "table" and type(part.text) == "string" then
        table.insert(parts, part.text)
      end
    end
    content = table.concat(parts, "\n")
  end

  if type(content) ~= "string" then
    return nil, "Response did not contain text content."
  end

  return content, nil
end

return M
