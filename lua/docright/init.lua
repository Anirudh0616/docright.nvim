local config = require("docright.config")
local context = require("docright.context")
local prompts = require("docright.prompt")
local providers = require("docright.provider")
local ui = require("docright.ui")

local M = {}

local last = {
  context = nil,
  answer = nil,
}

local active_request = 0
local installed_mappings = {}
local mapping_augroup = vim.api.nvim_create_augroup("DocRightMappings", { clear = true })

local function clear_installed_mappings()
  for _, mapping in ipairs(installed_mappings) do
    pcall(vim.keymap.del, mapping.mode, mapping.lhs)
  end
  installed_mappings = {}
end

local function set_mapping(mode, lhs, rhs, opts)
  vim.keymap.set(mode, lhs, rhs, opts)
  table.insert(installed_mappings, { mode = mode, lhs = lhs })
end

local function install_mappings(merged)
  clear_installed_mappings()

  set_mapping("n", merged.mappings.document, M.document_cursor, {
    desc = "DocRight document cursor context",
    silent = true,
  })
  set_mapping("v", merged.mappings.document, M.document_selection, {
    desc = "DocRight document selection",
    silent = true,
  })
  set_mapping("n", merged.mappings.ask, M.ask_followup, {
    desc = "DocRight ask follow-up",
    silent = true,
  })
end

local function max_display_width(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

local function open_debug_buffer(title, text)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"

  local lines = vim.split(text or "", "\n", { plain = true })
  local content = { "# " .. title, "" }
  vim.list_extend(content, lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false

  local width = math.min(math.max(max_display_width(vim.list_extend({ title }, lines)) + 6, 60), math.max(vim.o.columns - 4, 40))
  local height = math.min(math.max(#lines + 2, 8), math.max(vim.o.lines - 4, 8))

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    border = config.get().window.border,
    style = "minimal",
    title = " DocRight Debug ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true })
end

local function redact(value)
  if type(value) ~= "string" or value == "" then
    return "not set"
  end

  if #value <= 4 then
    return "set"
  end

  return "set (ends " .. value:sub(-4) .. ")"
end

local function config_debug_text()
  local opts = config.get()
  local lines = {
    "Config:",
    vim.inspect({
      provider = opts.provider,
      model = opts.model,
      endpoint = opts.endpoint,
      api_key = redact(config.api_key(opts)),
      api_key_env = config.key_env_name(opts),
      max_context_lines = opts.max_context_lines,
      max_response_lines = opts.max_response_lines,
      max_tokens = opts.max_tokens,
      num_predict = opts.num_predict,
      timeout_ms = opts.timeout_ms,
      system_prompt = prompts.system(opts),
    }),
    "",
    "Resolved system prompt:",
    prompts.system(opts),
    "",
  }
  return table.concat(lines, "\n")
end

local function ask_model(title, prompt, on_answer, show_actions)
  local opts = config.get()
  active_request = active_request + 1
  local request_id = active_request

  ui.loading("Asking " .. (opts.model ~= "" and opts.model or opts.provider) .. "...", opts, show_actions)

  providers.generate(opts, prompt, function(answer, err)
    vim.schedule(function()
      if request_id ~= active_request then
        return
      end

      if err then
        ui.show("Error", err, opts)
        return
      end

      if on_answer then
        on_answer(answer)
      end
      local actions = vim.tbl_extend("force", { document = M.expand_response, focus = true }, show_actions or {})
      ui.show(title, answer, opts, actions)
    end)
  end)
end

local function document_context(code_context, show_actions)
  last.context = code_context
  ask_model("Documentation", prompts.documentation(code_context, config.get()), function(answer)
    last.answer = answer
  end, show_actions)
end

local function current_response_topic()
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local selected = context.selection()
    if selected and selected ~= "" then
      return selected
    end
  end

  local line = vim.api.nvim_get_current_line()
  line = line:gsub("^%s*#%s*", ""):gsub("^%s*[-*]%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if line == "" or line == "Documentation" or line == "Follow-up" or line == "Working" then
    return nil
  end

  return line
end

function M.expand_response()
  if not last.context or not last.answer then
    vim.notify("DocRight: no previous documentation to expand", vim.log.levels.WARN)
    return
  end

  local topic = current_response_topic()
  if not topic then
    vim.notify("DocRight: select a response line or place the cursor on one", vim.log.levels.WARN)
    return
  end

  local opts = config.get()
  local title = "More: " .. topic:gsub("%s+", " "):sub(1, 42)
  ask_model(title, prompts.expansion(topic, opts, last), function(answer)
    last.answer = answer
  end, { focus = true })
end

function M.document_selection()
  local selected = context.selection_details()
  if not selected then
    vim.notify("DocRight: no visual selection found", vim.log.levels.WARN)
    return
  end

  document_context(selected.text, {
    anchor_row = context.screen_row_for_line(selected.start_line),
  })
end

function M.document_cursor()
  local opts = config.get()
  local current = context.cursor_context(opts.max_context_lines)
  document_context(current, {
    anchor_row = math.max(vim.fn.winline() - 1, 0),
  })
end

function M.ask_followup()
  if not last.context then
    vim.notify("DocRight: document a selection or cursor context first", vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = "DocRight follow-up: " }, function(question)
    if not question or question == "" then
      return
    end

    ask_model("Follow-up", prompts.followup(question, config.get(), last), function(answer)
      last.answer = answer
    end)
  end)
end

function M.debug_prompt()
  local opts = config.get()
  local current = context.cursor_context(opts.max_context_lines)
  local prompt = prompts.documentation(current, opts)
  open_debug_buffer("DocRight Prompt Debug", table.concat({
    "provider: " .. tostring(opts.provider),
    "model: " .. tostring(opts.model),
    "endpoint: " .. tostring(opts.endpoint),
    "",
    prompts.text(prompt),
  }, "\n"))
end

function M.debug_config()
  open_debug_buffer("DocRight Config Debug", config_debug_text())
end

function M.set_provider(name, overrides)
  if not config.is_known_provider(name) then
    return nil, "unknown provider '" .. tostring(name) .. "' (available: " .. table.concat(providers.names(), ", ") .. ")"
  end

  local current = vim.deepcopy(config.get())
  current.provider = name
  current.model = nil
  current.endpoint = nil
  current.api_key_env = nil
  current.keep_alive = nil

  for key, value in pairs(overrides or {}) do
    current[key] = value
  end

  config.setup(current)
  return config.get()
end

function M.set_model(name)
  if type(name) ~= "string" or not name:match("%S") then
    return nil, "model name is required"
  end

  local current = vim.deepcopy(config.get())
  current.model = name
  config.setup(current)
  return config.get()
end

function M.complete_models(arg_lead)
  local suggestions = config.get().model_suggestions or {}

  if type(arg_lead) ~= "string" or arg_lead == "" then
    return vim.deepcopy(suggestions)
  end

  local lead = arg_lead:lower()
  local matches = {}
  for _, model in ipairs(suggestions) do
    if model:lower():find(lead, 1, true) then
      table.insert(matches, model)
    end
  end
  return matches
end

function M.setup(opts)
  local merged = config.setup(opts)

  vim.api.nvim_create_user_command("DocRight", function()
    M.document_cursor()
  end, { desc = "Document code under the cursor with the configured model", force = true })

  vim.api.nvim_create_user_command("DocRightAsk", function()
    M.ask_followup()
  end, { desc = "Ask a follow-up about the last DocRight documentation", force = true })

  vim.api.nvim_create_user_command("DocRightProvider", function(args)
    if args.args == "" then
      local opts = config.get()
      vim.notify("DocRight provider: " .. opts.provider .. " / " .. tostring(opts.model), vim.log.levels.INFO)
      return
    end

    local _, err = M.set_provider(args.args)
    if err then
      vim.notify("DocRight: " .. err, vim.log.levels.ERROR)
      return
    end

    local opts = config.get()
    vim.notify("DocRight provider: " .. opts.provider .. " / " .. tostring(opts.model), vim.log.levels.INFO)
  end, {
    desc = "Switch the DocRight provider",
    nargs = "?",
    force = true,
    complete = function()
      return providers.names()
    end,
  })

  vim.api.nvim_create_user_command("DocRightModel", function(args)
    if args.args == "" then
      vim.notify("DocRight model: " .. tostring(config.get().model), vim.log.levels.INFO)
      return
    end

    local _, err = M.set_model(args.args)
    if err then
      vim.notify("DocRight: " .. err, vim.log.levels.ERROR)
      return
    end

    vim.notify("DocRight model: " .. config.get().model, vim.log.levels.INFO)
  end, {
    desc = "Set the DocRight model name",
    nargs = "?",
    force = true,
    complete = M.complete_models,
  })

  vim.api.nvim_create_user_command("DocRightDebug", function()
    M.debug_prompt()
  end, { desc = "Show the assembled DocRight prompt", force = true })

  vim.api.nvim_create_user_command("DocRightConfigDebug", function()
    M.debug_config()
  end, { desc = "Show DocRight configuration values", force = true })

  vim.api.nvim_clear_autocmds({ group = mapping_augroup })
  if vim.v.vim_did_enter == 1 then
    install_mappings(merged)
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      group = mapping_augroup,
      once = true,
      callback = function()
        install_mappings(merged)
      end,
    })
  end

  return merged
end

return M
