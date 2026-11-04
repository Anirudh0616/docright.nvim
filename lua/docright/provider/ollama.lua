local M = {}

function M.build(opts, prompt)
  return {
    url = opts.endpoint,
    timeout_ms = opts.timeout_ms,
    headers = {},
    body = {
      model = opts.model,
      prompt = table.concat({ prompt.system, "", prompt.user }, "\n"),
      stream = false,
      keep_alive = opts.keep_alive,
      options = {
        temperature = opts.temperature,
        num_predict = opts.max_tokens or opts.num_predict,
      },
    },
  }
end

function M.parse(decoded)
  if type(decoded) ~= "table" then
    return nil, "Unexpected response from the local model."
  end

  if type(decoded.error) == "string" and decoded.error ~= "" then
    return nil, decoded.error
  end

  return decoded.response or "", nil
end

return M
