local M = {}

M.defaults = {
  provider = "ollama",
  model = "qwen2.5-coder:7b",
  endpoint = "http://127.0.0.1:11434/api/generate",
  temperature = 0.2,
  num_predict = 180,
  keep_alive = "10m",
  max_context_lines = 50,
  max_response_lines = 8,
  window = {
    width = 64,
    height = 14,
    border = "rounded",
    position = "right",
  },
  mappings = {
    document = "<leader>ad",
    ask = "<leader>aa",
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return M.options
end

function M.get()
  return M.options
end

return M
