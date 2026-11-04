local M = {}

local SENTINEL = "__DOCRIGHT_STATUS__"

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function decode(value)
  if value == nil or value == "" then
    return nil
  end

  local ok, result = pcall(vim.fn.json_decode, value)
  if not ok then
    return nil
  end

  return result
end

function M.error_message(decoded)
  if type(decoded) ~= "table" then
    return nil
  end

  if type(decoded.error) == "string" and decoded.error ~= "" then
    return decoded.error
  end

  if type(decoded.error) == "table" then
    local message = decoded.error.message or decoded.error.type
    if type(message) == "string" and message ~= "" then
      return message
    end
  end

  if type(decoded.message) == "string" and decoded.message ~= "" then
    return decoded.message
  end

  return nil
end

local function parse_stdout(data)
  local status = nil
  local body_lines = {}

  for _, line in ipairs(data or {}) do
    local code = line:match("^" .. SENTINEL .. "(%d+)$")
    if code then
      status = tonumber(code)
    elseif line ~= "" or #body_lines > 0 then
      table.insert(body_lines, line)
    end
  end

  return status, trim(table.concat(body_lines, "\n"))
end

function M.post(spec, callback)
  local command = { "curl", "-sS", "-X", "POST", spec.url, "-H", "Content-Type: application/json" }

  for _, header in ipairs(spec.headers or {}) do
    table.insert(command, "-H")
    table.insert(command, header)
  end

  local timeout = math.floor((spec.timeout_ms or 60000) / 1000)
  if timeout > 0 then
    table.insert(command, "--max-time")
    table.insert(command, tostring(timeout))
  end

  table.insert(command, "-d")
  table.insert(command, vim.fn.json_encode(spec.body))
  table.insert(command, "-w")
  table.insert(command, "\n" .. SENTINEL .. "%{http_code}")

  local stderr = {}
  local status = nil
  local body = ""
  local finished = false

  local function finish(payload, err)
    if finished then
      return
    end
    finished = true
    callback(payload, err)
  end

  local job_id = vim.fn.jobstart(command, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      status, body = parse_stdout(data)
    end,
    on_stderr = function(_, data)
      vim.list_extend(stderr, data or {})
    end,
    on_exit = function(_, code)
      if code ~= 0 then
        local message = trim(table.concat(stderr, "\n"))
        finish(nil, {
          message = message ~= "" and message or "curl exited with code " .. tostring(code) .. ".",
        })
        return
      end

      if status == nil then
        finish(nil, { message = "Could not read the model response." })
        return
      end

      local decoded = decode(body)

      if status < 200 or status > 299 then
        finish(nil, {
          status = status,
          message = M.error_message(decoded) or ("Request failed with HTTP " .. tostring(status) .. "."),
        })
        return
      end

      if decoded == nil then
        finish(nil, { status = status, message = "Could not parse the model response." })
        return
      end

      finish({ decoded = decoded, status = status }, nil)
    end,
  })

  if job_id <= 0 then
    finish(nil, { message = "Could not start curl. Make sure curl is installed and available in PATH." })
  end
end

return M
