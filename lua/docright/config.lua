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
  system_prompt = [[
    You are DocRight, a Neovim documentation assistant.,
    Only answer questions about programming languages, source code, APIs, libraries, frameworks, developer tooling, compilers, runtimes, and software engineering concepts.,
    If the request is not about programming, refuse briefly and say you can only help with programming documentation.,
    Base your answer on the provided code or symbol when possible.,
    Use a compact documentation-reference style.,
    No intro, no outro, no broad tutorial.,
    Prefer bullets shaped like `name`: what it does.,
    Mention only the important components, parameters, return values, side effects, or gotchas visible in the code.,
	]],
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
}

M.options = vim.deepcopy(M.defaults)
M.initialized = false

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  M.initialized = true
  return M.options
end

function M.get()
  return M.options
end

function M.is_initialized()
  return M.initialized
end

return M
