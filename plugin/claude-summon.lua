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
  summon.history()
end, {})
vim.api.nvim_create_user_command("ClaudeLoad", function(opts)
  local lines = require("claude-summon.history").load(opts.args)
  if lines and #lines > 0 then
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.notify("Loaded conversation into current buffer", vim.log.levels.INFO)
  end
end, { nargs = 1 })
vim.api.nvim_create_user_command("ClaudeDelete", function(opts)
  require("claude-summon.history").delete(opts.args)
  vim.notify("Deleted conversation " .. opts.args, vim.log.levels.INFO)
end, { nargs = 1 })
