# DocRight.nvim

DocRight is a small Neovim plugin that asks a local model for concise programming documentation about the code you select or the symbol near your cursor. It keeps the current documented context only so you can ask follow-up questions.

The default provider is [Ollama](https://ollama.com/) on `http://127.0.0.1:11434` with the `qwen2.5-coder:7b` model.

## Requirements

- Neovim 0.9+
- `curl`
- Ollama running locally
- A pulled model, for example:

```sh
ollama pull qwen2.5-coder:7b
```

## Installation

With lazy.nvim:

```lua
{
  "Anirudh0616/docright.nvim",
  config = function()
    require("docright").setup({
      model = "qwen2.5-coder:7b",
      mappings = {
        document = "<leader>ad",
        ask = "<leader>aa",
      },
    })
  end,
}
```

With Neovim's built-in `vim.pack`:

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
  mappings = {
    document = "<leader>ad",
    ask = "<leader>aa",
  },
})
```

`vim.pack` expects plugins to come from Git repositories. For local development
before you publish the plugin, use the runtime path directly:

```lua
vim.opt.rtp:prepend("/Users/newton/dev/projects/docright")

require("docright").setup({
  provider = "ollama",
  model = "qwen2.5-coder:7b",
})
```

If you turn this directory into a local Git repository, you can also install it
through `vim.pack` with a `file://` source:

```lua
vim.pack.add({
  {
    src = "file:///Users/newton/dev/projects/docright",
    name = "docright.nvim",
  },
})

require("docright").setup({
  model = "qwen2.5-coder:7b",
})
```

For local development:

```lua
{
  dir = "/Users/newton/dev/projects/docright",
  config = function()
    require("docright").setup()
  end,
}
```

## Usage

- Place the cursor on code and press `<leader>ad`.
- Select code in visual mode and press `<leader>ad`.
- Press `<leader>aa` to ask a follow-up about the last generated documentation.
- Inside a DocRight response window, press `<leader>ad` on a line, or select text and press `<leader>ad`, to expand that specific item with a small title.

Commands:

- `:DocRight`
- `:DocRightAsk`

DocRight instructs the local model to answer only programming-related questions and to refuse unrelated topics.

Documentation responses are intentionally short by default. The plugin sends the selected code, or about 50 nearby lines around the cursor, rather than the whole file. This keeps responses faster and more relevant for quick lookup.

The floating window opens above or below the current cursor line, similar to a diagnostic popup. It shrinks to fit short responses, up to the configured maximum size.

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
  window = {
    width = 64,
    height = 14,
    border = "rounded",
    position = "cursor",
  },
  mappings = {
    document = "<leader>ad",
    ask = "<leader>aa",
  },
})
```
