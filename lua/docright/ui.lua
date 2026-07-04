local M = {}

local state = {
  win = nil,
  buf = nil,
  source_win = nil,
}

local function display_width(lines)
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  return width
end

local function resolve_size(value, total)
  if value <= 1 then
    return math.floor(total * value)
  end

  return value
end

local function centered_dimensions(opts, content)
  local max_width = math.min(resolve_size(opts.window.width, vim.o.columns), vim.o.columns - 4)
  local max_height = math.min(resolve_size(opts.window.height, vim.o.lines), vim.o.lines - 4)
  local width = math.min(math.max(display_width(content) + 4, 30), max_width)
  local height = math.min(math.max(#content, 4), max_height)

  return {
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
  }
end

local function cursor_dimensions(opts, content)
  local max_width = math.max(vim.api.nvim_win_get_width(0) - 4, 20)
  local max_height = math.max(vim.api.nvim_win_get_height(0) - 2, 4)
  local max_configured_width = math.min(resolve_size(opts.window.width, vim.o.columns), max_width)
  local max_configured_height = math.min(resolve_size(opts.window.height, vim.o.lines), max_height)
  local width = math.min(math.max(display_width(content) + 4, 30), max_configured_width)
  local height = math.min(math.max(#content, 4), max_configured_height)
  local row = math.max(vim.fn.winline() - 1, 0)
  local col = math.max(vim.fn.wincol() - 1, 0)
  local win_height = vim.api.nvim_win_get_height(0)
  local win_width = vim.api.nvim_win_get_width(0)
  local below = row + height + 2 <= win_height
  local final_width = math.min(math.max(width, 30), max_width)
  local final_height = math.min(math.max(height, 6), max_height)

  return {
    width = final_width,
    height = final_height,
    row = below and row + 1 or math.max(row - final_height - 1, 0),
    col = math.min(col, math.max(win_width - final_width - 2, 0)),
  }
end

local function window_options(opts, content)
  local size
  if opts.window.position == "center" then
    size = centered_dimensions(opts, content)
    return {
      relative = "editor",
      width = size.width,
      height = size.height,
      row = size.row,
      col = size.col,
    }
  end

  size = cursor_dimensions(opts, content)
  return {
    relative = "win",
    win = 0,
    width = size.width,
    height = size.height,
    row = size.row,
    col = size.col,
  }
end

function M.show(title, lines, opts, actions)
  opts = opts or require("docright.config").get()
  actions = actions or {}
  local focus = actions.focus ~= false

  if focus and not (state.win and vim.api.nvim_get_current_win() == state.win) then
    state.source_win = vim.api.nvim_get_current_win()
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "markdown"

  local content = vim.split(lines or "", "\n", { plain = true })
  if title and title ~= "" then
    table.insert(content, 1, "")
    table.insert(content, 1, "# " .. title)
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, content)
  vim.bo[state.buf].modifiable = false

  local win_opts = vim.tbl_extend("force", window_options(opts, content), {
    border = opts.window.border,
    style = "minimal",
    title = " DocRight ",
    title_pos = "center",
  })
  state.win = vim.api.nvim_open_win(state.buf, focus, win_opts)

  vim.wo[state.win].wrap = true
  vim.keymap.set("n", "q", function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_close(state.win, true)
    end
    if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
      vim.api.nvim_set_current_win(state.source_win)
    end
  end, { buffer = state.buf, silent = true })

  if actions and actions.document then
    vim.keymap.set("n", opts.mappings.document, actions.document, {
      buffer = state.buf,
      desc = "DocRight explain this line",
      silent = true,
    })
    vim.keymap.set("v", opts.mappings.document, actions.document, {
      buffer = state.buf,
      desc = "DocRight explain selection",
      silent = true,
    })
  end
end

function M.loading(message, opts)
  M.show("Working", message or "Asking the local model...", opts, { focus = false })
end

return M
