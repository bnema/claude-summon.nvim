if vim.g.loaded_claude_summon then
  return
end
vim.g.loaded_claude_summon = true

local ok, summon = pcall(require, "claude-summon")
if not ok then
  return
end

vim.api.nvim_create_user_command("ClaudeSend", function()
  summon.send()
end, {})
vim.api.nvim_create_user_command("ClaudeOpen", function()
  summon.open()
end, {})
vim.api.nvim_create_user_command("ClaudeClose", function()
  summon.close()
end, {})
vim.api.nvim_create_user_command("ClaudeToggle", function()
  summon.toggle()
end, {})
vim.api.nvim_create_user_command("ClaudeStop", function()
  summon.stop()
end, {})
vim.api.nvim_create_user_command("ClaudeClear", function()
  summon.clear()
end, {})
