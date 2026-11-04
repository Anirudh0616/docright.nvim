local config = require("docright.config")

local M = {}

M.requires_api_key = true

local function headers(opts)
  local list = {
    "anthropic-version: 2023-06-01",
  }

  local key = config.api_key(opts)
  if key then
    table.insert(list, "x-api-key: " .. key)
  end

  for _, header in ipairs(opts.extra_headers or {}) do
    table.insert(list, header)
  end

  return list
end

function M.build(opts, prompt)
  return {
    url = opts.endpoint,
    timeout_ms = opts.timeout_ms,
    headers = headers(opts),
    body = {
      model = opts.model,
      system = prompt.system,
      max_tokens = opts.max_tokens or opts.num_predict,
      temperature = opts.temperature,
      messages = {
        { role = "user", content = prompt.user },
      },
    },
  }
end

function M.parse(decoded)
  if type(decoded) ~= "table" then
    return nil, "Unexpected response from the model provider."
  end

  if type(decoded.content) ~= "table" then
    return nil, "Response did not contain content."
  end

  local parts = {}
  for _, block in ipairs(decoded.content) do
    if type(block) == "table" and block.type == "text" and type(block.text) == "string" then
      table.insert(parts, block.text)
    end
  end

  if #parts == 0 then
    return nil, "Response did not contain text content."
  end

  return table.concat(parts, "\n"), nil
end

return M
