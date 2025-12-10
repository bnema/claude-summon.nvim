if vim.g.loaded_claude_summon then
  return
end
vim.g.loaded_claude_summon = true

pcall(require, "claude-summon")
