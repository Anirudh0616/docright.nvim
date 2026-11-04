local config = require("docright.config")

local M = {}

function M.system(opts)
  opts = opts or config.get()

  if type(opts.system_prompt) == "string" and opts.system_prompt:match("%S") then
    return opts.system_prompt
  end

  return config.DEFAULT_SYSTEM_PROMPT
end

function M.documentation(code_context, opts)
  return {
    system = M.system(opts),
    user = table.concat({
      "Write at most " .. tostring(opts.max_response_lines) .. " short lines.",
      "",
      "Programming context:",
      "```",
      code_context,
      "```",
    }, "\n"),
  }
end

function M.expansion(topic, opts, last)
  last = last or {}

  return {
    system = M.system(opts),
    user = table.concat({
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
    }, "\n"),
  }
end

function M.followup(question, opts, last)
  last = last or {}

  return {
    system = M.system(opts),
    user = table.concat({
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
    }, "\n"),
  }
end

function M.text(prompt)
  if type(prompt) == "string" then
    return prompt
  end

  return table.concat({ prompt.system or "", "", prompt.user or "" }, "\n")
end

return M
