# DocRight.nvim

DocRight.nvim is a Neovim plugin that asks a local model for short programming documentation about the code you select (with v). It is currently in beta: useful, working, and still missing a lot of lofty features. Basically a better Shift+K.

![Demo GIF](preview.gif)

It is built for quick lookups inside Neovim and not broad conversation, although there is a rabbit hole feature. The plugin keeps answers focused on programming topics only.

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
  model = "qwen2.5-coder:7b", -- or the model name that you are using
  endpoint = "http://127.0.0.1:11434/api/generate",
  system_prompt = [[
You are DocRight, a concise programming documentation assistant.
Only answer questions about code and software engineering.
]],
})
```

If you prefer auto-loading through `plugin/docright.lua`, set `vim.g.docright_opts`
before the plugin is sourced.


## Usage

- Select code in visual mode and press `<leader>ad`.
- Press `<leader>aa` for a follow-up about the last result.
- Inside a DocRight response window, press `<leader>ad` on a line or selection to go down a rabbit hole.

Commands:

- `:DocRight`
- `:DocRightAsk`
- `:DocRightDebug`
- `:DocRightConfigDebug`

By default, the result window opens on the right so you can still see the code you are asking about. It grows tall for larger answers and stays compact when the response is short.

## Configuration

DocRight registers its default commands and mappings when Neovim loads the
plugin. Call `setup()` only when you want to override defaults:

```lua
require("docright").setup({
  provider = "ollama", -- or provider of your choice
  model = "qwen2.5-coder:7b", -- or model of your choice
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

## Notes

- DocRight only answers programming-related questions.
- The current release is beta, so the surface is intentionally small and still evolving.
- The response window is tuned for fast reading rather than long-form explanation.


## Want to implement 

- Complete Codebase Context 
- Larger Models through API integration
- Run faster 


---
Feel free to contribute

Anirudh
