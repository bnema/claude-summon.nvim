# claude-summon.nvim

> ⚠️ Alpha preview — very early, expect breakage.

Summon Claude Code from your comments in Neovim via the `claude-code-lua` SDK. Streaming and prompt delivery are still unstable.

## Status
- Alpha-quality; no API stability.
- Known issues: streaming may buffer until completion and user prompts can be lost (see `/issue/2025-streaming-and-prompt-loss.md`).
- Designed for local experimentation only.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "bnema/claude-summon.nvim",
  dependencies = {
    "bnema/claude-agent-sdk-lua",
  },
  config = function()
    require("claude-summon").setup({
      -- Optional: customize keymaps, model defaults, etc.
    })
  end,
}
```

## Usage (experimental)
- In a comment, type `@claude` / `@opus` / `@sonnet` / `@haiku` followed by your prompt, then press `<C-CR>` or `<leader>as` to send.
- Commands: `:ClaudeOpen`, `:ClaudeClose`, `:ClaudeToggle`, `:ClaudeStop`, `:ClaudeClear`.
- Code actions: `:ClaudeApply`, `:ClaudeYank`, `:ClaudeDiff`, `:ClaudePreview`.
- History: `:ClaudeHistory` lists recent Claude sessions for the current project via the SDK.

Default keymaps (normal mode):
- Send: `<C-CR>` / `<leader>as`
- Open/Close/Toggle: `<leader>ao` / `<leader>ac` / `<leader>at`
- Apply/Yank/Diff/Preview: `<leader>aa` / `<leader>ay` / `<leader>ad` / `<leader>ap`

## Requirements
- Neovim 0.10+
- Claude Code CLI in PATH
