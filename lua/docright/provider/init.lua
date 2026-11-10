local config = require("docright.config")
local http = require("docright.provider.http")

local M = {}

local registry = {
  anthropic = "docright.provider.anthropic",
  ollama = "docright.provider.ollama",
  openai = "docright.provider.openai",
  openrouter = "docright.provider.openai",
}

function M.names()
  local names = {}
  for name in pairs(registry) do
    table.insert(names, name)
  end
  table.sort(names)
  return names
end

function M.get(name)
  local module = registry[name or ""]
  if not module then
    error("Unsupported DocRight provider: " .. tostring(name) .. ". Available: " .. table.concat(M.names(), ", "), 0)
  end

  return require(module)
end

function M.key_error(opts)
  local module = M.get(opts.provider)
  if not module.requires_api_key then
    return nil
  end

  if config.api_key(opts) then
    return nil
  end

  local env_name = config.key_env_name(opts)
  return table.concat({
    "No API key found for provider '" .. tostring(opts.provider) .. "'.",
    "Export " .. env_name .. " or set `api_key` in setup().",
  }, "\n")
end

function M.describe(opts, failure)
  local message = failure.message or "The model request failed."
  local status = failure.status

  if status == 401 or status == 403 then
    return table.concat({
      "Authentication failed for " .. tostring(opts.provider) .. " (HTTP " .. tostring(status) .. ").",
      "Check " .. config.key_source(opts) .. ".",
      message,
    }, "\n")
  end

  if status == 404 then
    return table.concat({
      "Endpoint or model not found (HTTP 404).",
      "model: " .. tostring(opts.model),
      "endpoint: " .. tostring(opts.endpoint),
      message,
    }, "\n")
  end

  if status == 429 then
    return "Rate limited by " .. tostring(opts.provider) .. ". Try again shortly.\n" .. message
  end

  return message
end

function M.generate(opts, prompt, callback)
  if type(opts.model) ~= "string" or not opts.model:match("%S") then
    callback(nil, table.concat({
      "No model set for provider '" .. tostring(opts.provider) .. "'.",
      "Run `:DocRightModel <name>` or set `model` in setup().",
    }, "\n"))
    return
  end

  local key_error = M.key_error(opts)
  if key_error then
    callback(nil, key_error)
    return
  end

  local module = M.get(opts.provider)
  local ok, spec = pcall(module.build, opts, prompt)
  if not ok then
    callback(nil, "Could not build the request: " .. tostring(spec))
    return
  end

  local function handle(result, failure)
    if failure then
      callback(nil, M.describe(opts, failure))
      return
    end

    local answer, err = module.parse(result.decoded)
    callback(answer, err)
  end

  local function post(current)
    http.post(current, function(result, failure)
      local blocked = failure ~= nil
        and current.body.reasoning ~= nil
        and module.reasoning_mandatory ~= nil
        and module.reasoning_mandatory(failure.message)

      if blocked then
        -- Reasoning-mandatory models reject `reasoning: { enabled = false }`.
        -- Retry once without it instead of surfacing the HTTP error.
        current.body.reasoning = nil
        post(current)
        return
      end

      handle(result, failure)
    end)
  end

  post(spec)
end

return M
