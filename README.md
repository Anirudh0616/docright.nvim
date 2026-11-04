# DocRight.nvim

DocRight.nvim is a Neovim plugin that asks a model for short programming documentation about code under the cursor or in a visual selection. It is built for quick lookups inside Neovim, not broad conversation.

Runs fully local with Ollama, or against a hosted API with your own key (OpenRouter, OpenAI, Anthropic).

See `FEATURES.md` for the complete behavior reference.

![Demo GIF](preview.gif)

## What Changed

- multiple providers: `ollama`, `openrouter`, `openai`, `anthropic`
- API keys from an environment variable or `api_key`
- `:DocRightProvider` and `:DocRightModel` to switch at runtime
- `system_prompt` support for custom style instructions
- `:DocRightDebug` to inspect the assembled prompt
- `:DocRightConfigDebug` to inspect merged config and resolved prompt
- auto-load support through `plugin/docright.lua`

## Requirements

- Neovim 0.9+
- `curl`
- one of:
  - Ollama running locally, plus a pulled model, for example `ollama pull qwen2.5-coder:7b`
  - an API key for OpenRouter, OpenAI, or Anthropic

## Installation

With `vim.pack`:

```lua
vim.pack.add({
  {
    src = "https://github.com/Anirudh0616/docright.nvim",
    name = "docright.nvim",
  },
})
```

## Providers

| provider | default endpoint | key env var | default model |
| --- | --- | --- | --- |
| `ollama` | `http://127.0.0.1:11434/api/generate` | none | `qwen2.5-coder:7b` |
| `openrouter` | `https://openrouter.ai/api/v1/chat/completions` | `OPENROUTER_API_KEY` | `anthropic/claude-3.5-sonnet` |
| `openai` | `https://api.openai.com/v1/chat/completions` | `OPENAI_API_KEY` | `gpt-4o-mini` |
| `anthropic` | `https://api.anthropic.com/v1/messages` | `ANTHROPIC_API_KEY` | `claude-3-5-sonnet-latest` |

Default models are only a starting point. Set `model` to anything the provider serves.

### Ollama (local, default)

```lua
require("docright").setup({
  provider = "ollama",
  model = "qwen2.5-coder:7b",
})
```

### OpenRouter

```sh
export OPENROUTER_API_KEY=sk-or-...
```

```lua
require("docright").setup({
  provider = "openrouter",
  model = "anthropic/claude-3.5-sonnet",
})
```

Any OpenRouter model slug works, for example `openai/gpt-4o-mini`, `google/gemini-2.0-flash-001`, `meta-llama/llama-3.3-70b-instruct`.

### OpenAI

```sh
export OPENAI_API_KEY=sk-...
```

```lua
require("docright").setup({
  provider = "openai",
  model = "gpt-4o-mini",
})
```

### Anthropic

```sh
export ANTHROPIC_API_KEY=sk-ant-...
```

```lua
require("docright").setup({
  provider = "anthropic",
  model = "claude-3-5-sonnet-latest",
})
```

### Switching without restarting

```vim
:DocRightProvider            " print the active provider and model
:DocRightProvider openrouter " switch provider, applying its defaults
:DocRightModel gpt-4o-mini   " change only the model
```

`:DocRightModel` completes against `model_suggestions` (five low-cost or free models by
default). Matching is substring and case-insensitive; you can still type any model name the
provider serves. Edit `model_suggestions` in setup() to change the list.

Switching provider resets `endpoint`, `model`, and `api_key_env` to that provider's defaults. Everything else (temperature, window, mappings, `system_prompt`) is kept. Pass overrides from Lua if you need both:

```lua
require("docright").set_provider("anthropic", { model = "claude-3-5-sonnet-latest" })
```

## Usage

- Select code in visual mode and press `<leader>ad`.
- Press `<leader>aa` for a follow-up about the last result.
- Inside a DocRight response window, press `<leader>ad` on a line or selection to go deeper.

Commands:

- `:DocRight`
- `:DocRightAsk`
- `:DocRightProvider [name]`
- `:DocRightModel [name]`
- `:DocRightDebug`
- `:DocRightConfigDebug`

## Configuration

```lua
require("docright").setup({
  provider = "openrouter",
  model = "anthropic/claude-3.5-sonnet",
  endpoint = "https://openrouter.ai/api/v1/chat/completions",
  api_key_env = "OPENROUTER_API_KEY", -- env var to read the key from
  api_key = nil,                      -- or set the key directly (prefer the env var)
  extra_headers = {},                 -- e.g. { "X-Custom: 1" }
  temperature = 0.2,
  num_predict = 180,
  max_tokens = nil,                   -- defaults to num_predict
  timeout_ms = 60000,
  keep_alive = "10m",                 -- ollama only
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
  model_suggestions = {              -- offered by :DocRightModel completion
    "z-ai/glm-5.3-flash",
    "deepseek/deepseek-v4.1-flash",
    "google/gemini-2.5-flash",
    "meta-llama/llama-3.3-70b-instruct",
    "mistralai/mistral-small-2603",
  },
})
```

Notes:

- The key is read from `api_key` first, then `api_key_env`, then the provider's default env var. Keys are never written to the debug buffers.
- `system_prompt` replaces the built-in style instructions.
- `max_context_lines` limits how much code near the cursor is sent.
- `max_response_lines` and `num_predict` / `max_tokens` keep replies short.
- The response window opens on the right by default so you can keep the source visible.
- If you prefer auto-loading, set `vim.g.docright_opts` before `plugin/docright.lua` runs.

## Why It Exists

- Fast docs for code under cursor
- Short follow-ups without leaving Neovim
- Local model by default, hosted model if you bring a key

---
## Feel Free to Contribute

Anirudh
