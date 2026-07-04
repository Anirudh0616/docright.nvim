# DocRight.nvim

DocRight.nvim is a Neovim plugin that asks a local model for short programming documentation about code under the cursor or in a visual selection. It is built for quick lookups inside Neovim, not broad conversation.

![Demo GIF](preview.gif)

## What Changed

- `system_prompt` support for custom style instructions
- `:DocRightDebug` to inspect the assembled prompt
- `:DocRightConfigDebug` to inspect merged config and resolved prompt
- auto-load support through `plugin/docright.lua`

## Requirements

- Neovim 0.9+
- `curl`
- Ollama running locally
- A pulled model, for example:

```sh
ollama pull qwen2.5-coder:7b
```

## Installation

With `vim.pack`:

```lua
vim.pack.add({
  {
    src = "https://github.com/Anirudh0616/docright.nvim",
    name = "docright.nvim",
  },
})

require("docright").setup({
  provider = "ollama",
  model = "qwen2.5-coder:7b",
  endpoint = "http://127.0.0.1:11434/api/generate",
  system_prompt = [[
You are DocRight, a concise programming documentation assistant.
Only answer questions about code and software engineering.
]],
})
```

If you prefer auto-loading, set `vim.g.docright_opts` before `plugin/docright.lua` runs.

## Usage

- Select code in visual mode and press `<leader>ad`.
- Press `<leader>aa` for a follow-up about the last result.
- Inside a DocRight response window, press `<leader>ad` on a line or selection to go deeper.

Commands:

- `:DocRight`
- `:DocRightAsk`
- `:DocRightDebug`
- `:DocRightConfigDebug`

## Configuration

```lua
require("docright").setup({
  provider = "ollama",
  model = "qwen2.5-coder:7b",
  endpoint = "http://127.0.0.1:11434/api/generate",
  temperature = 0.2,
  num_predict = 180,
  keep_alive = "10m",
  max_context_lines = 50,
  max_response_lines = 8,
  system_prompt = [[
You are DocRight, a concise programming documentation assistant.
Only answer questions about code and software engineering.
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
})
```

Notes:

- `system_prompt` adds custom style instructions. DocRight still keeps its core code-documentation guidance.
- `max_context_lines` limits how much code near the cursor is sent.
- `max_response_lines` and `num_predict` help keep replies short.
- The response window opens on the right by default so you can keep the source visible.

## Why It Exists

- Fast docs for code under cursor
- Short follow-ups without leaving Neovim
- Local model only, no remote API needed

---
## Feel Free to Contribute

Anirudh
