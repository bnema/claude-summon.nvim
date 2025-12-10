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
vim.api.nvim_create_user_command("ClaudeApply", function()
  summon.apply_code()
end, {})
vim.api.nvim_create_user_command("ClaudeYank", function()
  summon.yank_code()
end, {})
vim.api.nvim_create_user_command("ClaudeDiff", function()
  summon.diff_code()
end, {})
vim.api.nvim_create_user_command("ClaudeSave", function(opts)
  summon.save_conversation(opts.args)
end, { nargs = "?" })
vim.api.nvim_create_user_command("ClaudeExport", function(opts)
  summon.export_markdown(opts.args)
end, { nargs = "?" })
vim.api.nvim_create_user_command("ClaudeHistory", function()
  local list = require("claude-summon.history").list()
  vim.notify("Saved conversations:\n" .. table.concat(list, "\n"), vim.log.levels.INFO)
end, {})
