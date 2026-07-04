local config = require("docright.config")
local context = require("docright.context")
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

local function provider()
  local opts = config.get()
  if opts.provider == "ollama" then
    return require("docright.provider.ollama")
  end
  error("Unsupported DocRight provider: " .. tostring(opts.provider))
end

local function default_system_prompt()
  return table.concat({
    "You are DocRight, a Neovim documentation assistant.",
    "Only answer questions about programming languages, source code, APIs, libraries, frameworks, developer tooling, compilers, runtimes, and software engineering concepts.",
    "If the request is not about programming, refuse briefly and say you can only help with programming documentation.",
    "Base your answer on the provided code or symbol when possible.",
    "Use a compact documentation-reference style.",
    "No intro, no outro, no broad tutorial.",
    "Prefer bullets shaped like `name`: what it does.",
    "Mention only the important components, parameters, return values, side effects, or gotchas visible in the code.",
  }, "\n")
end

local function system_prompt()
  local opts = config.get()
  if type(opts.system_prompt) == "string" and opts.system_prompt:match("%S") then
    return opts.system_prompt
  end

  return default_system_prompt()
end

local function documentation_prompt(code_context, opts)
  return table.concat({
    system_prompt(),
    "",
    "Write at most " .. tostring(opts.max_response_lines) .. " short lines.",
    "",
    "Programming context:",
    "```",
    code_context,
    "```",
  }, "\n")
end

local function expansion_prompt(topic, opts)
  return table.concat({
    system_prompt(),
    "",
    "The user selected one part of a previous programming explanation and wants more detail.",
    "Explain only this selected item, using the original code context as background.",
    "Start with a short markdown heading that names the exact thing being explained.",
    "Write at most " .. tostring(math.max(opts.max_response_lines, 8)) .. " short lines.",
    "",
    "Original programming context:",
    "```",
    last.context or "",
    "```",
    "",
    "Previous answer:",
    last.answer or "",
    "",
    "Selected item to expand:",
    topic,
  }, "\n")
end

local function followup_prompt(question)
  return table.concat({
    system_prompt(),
    "",
    "Previous programming context:",
    "```",
    last.context or "",
    "```",
    "",
    "Previous answer:",
    last.answer or "",
    "",
    "Follow-up question:",
    question,
    "",
    "Answer briefly unless more detail is necessary.",
  }, "\n")
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

local function config_debug_text()
  local opts = config.get()
  local lines = {
    "Config:",
    vim.inspect({
      provider = opts.provider,
      model = opts.model,
      system_prompt = opts.system_prompt,
      max_context_lines = opts.max_context_lines,
      max_response_lines = opts.max_response_lines,
    }),
    "",
    "Resolved system prompt:",
    system_prompt(),
    "",
  }
  return table.concat(lines, "\n")
end

local function ask_model(title, prompt, on_answer, show_actions)
  local opts = config.get()
  active_request = active_request + 1
  local request_id = active_request

  ui.loading("Asking " .. opts.model .. "...", opts, show_actions)

  provider().generate(opts, prompt, function(answer, err)
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
  ask_model("Documentation", documentation_prompt(code_context, config.get()), function(answer)
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
  ask_model(title, expansion_prompt(topic, opts), function(answer)
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

    ask_model("Follow-up", followup_prompt(question), function(answer)
      last.answer = answer
    end)
  end)
end

function M.debug_prompt()
  local opts = config.get()
  local current = context.cursor_context(opts.max_context_lines)
  local prompt = documentation_prompt(current, opts)
  open_debug_buffer("DocRight Prompt Debug", prompt)
end

function M.debug_config()
  open_debug_buffer("DocRight Config Debug", config_debug_text())
end

function M.setup(opts)
  local merged = config.setup(opts)

  vim.api.nvim_create_user_command("DocRight", function()
    M.document_cursor()
  end, { desc = "Document code under the cursor with a local model", force = true })

  vim.api.nvim_create_user_command("DocRightAsk", function()
    M.ask_followup()
  end, { desc = "Ask a follow-up about the last DocRight documentation", force = true })

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
end

return M
