local M = {}

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function visual_range()
  local mode = vim.fn.mode()
  local in_visual = mode == "v" or mode == "V" or mode == "\22"
  local start_pos = in_visual and vim.fn.getpos("v") or vim.fn.getpos("'<")
  local end_pos = in_visual and vim.fn.getpos(".") or vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local start_col = start_pos[3]
  local end_line = end_pos[2]
  local end_col = end_pos[3]

  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  return start_line, start_col, end_line, end_col, mode
end

function M.selection()
  local start_line, start_col, end_line, end_col, mode = visual_range()
  if start_line == 0 or end_line == 0 then
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if vim.tbl_isempty(lines) then
    return nil
  end

  if mode == "V" then
    start_col = 1
    end_col = #lines[#lines]
  end

  lines[1] = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)

  local text = trim(table.concat(lines, "\n"))
  if text == "" then
    return nil
  end

  return text
end

function M.cursor_context(max_lines)
  local bufnr = 0
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local half = math.floor((max_lines or 80) / 2)
  local start_line = math.max(row - half, 1)
  local end_line = math.min(row + half, vim.api.nvim_buf_line_count(bufnr))
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local word = vim.fn.expand("<cword>")
  local filetype = vim.bo.filetype
  local path = vim.api.nvim_buf_get_name(bufnr)

  return trim(table.concat({
    "File: " .. (path ~= "" and path or "[No Name]"),
    "Filetype: " .. (filetype ~= "" and filetype or "unknown"),
    "Cursor symbol: " .. (word ~= "" and word or "unknown"),
    "Nearby code:",
    table.concat(lines, "\n"),
  }, "\n"))
end

return M
