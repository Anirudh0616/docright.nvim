local M = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function build_body(opts, prompt)
  return vim.fn.json_encode({
    model = opts.model,
    prompt = prompt,
    stream = false,
    keep_alive = opts.keep_alive,
    options = {
      temperature = opts.temperature,
      num_predict = opts.num_predict,
    },
  })
end

function M.generate(opts, prompt, callback)
  local body = build_body(opts, prompt)
  local stderr = {}
  local completed = false
  local command = {
    "curl",
    "-sS",
    "--fail",
    "-X",
    "POST",
    opts.endpoint,
    "-H",
    "Content-Type: application/json",
    "-d",
    body,
  }

  local job_id = vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      local output = table.concat(data or {}, "\n")
      if output == "" then
        return
      end

      local ok, decoded = pcall(vim.fn.json_decode, output)
      if not ok then
        completed = true
        callback(nil, "Could not parse model response.")
        return
      end

      completed = true
      callback(decoded.response or "", nil)
    end,
    on_stderr = function(_, data)
      vim.list_extend(stderr, data or {})
    end,
    on_exit = function(_, code)
      if code ~= 0 and not completed then
        local message = trim(table.concat(stderr, "\n"))
        if message == "" then
          message = "Local model request failed. Is Ollama running and is the model pulled?"
        end
        callback(nil, message)
      end
    end,
  })

  if job_id <= 0 then
    callback(nil, "Could not start curl. Make sure curl is installed and available in PATH.")
  end
end

return M
