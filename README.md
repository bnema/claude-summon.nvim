# claude-summon.nvim

> ⚠️ Alpha preview — very early, expect breakage.

Summon Claude Code from your comments in Neovim via the `claude-code-lua` SDK. Streaming and prompt delivery are still unstable.

## Status
- Alpha-quality; no API stability.
- Known issues: streaming may buffer until completion and user prompts can be lost (see `/issue/2025-streaming-and-prompt-loss.md`).
- Designed for local experimentation only.

## Quick install (dev)
Lazy.nvim example:

```lua
{
  dir = "/home/brice/projects/claude-summon.nvim",
  name = "claude-summon.nvim",
  config = function()
    require("claude-summon").setup({
      sdk_path = "/home/brice/projects/claude-code-lua",
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
- `claude-code-lua` SDK available at the configured `sdk_path`
