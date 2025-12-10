-- luacheck: globals vim

local M = {}

function M.save(_conversation_id)
	vim.notify("History save not implemented yet", vim.log.levels.INFO)
end

function M.load(_conversation_id)
	vim.notify("History load not implemented yet", vim.log.levels.INFO)
end

function M.list()
	vim.notify("History list not implemented yet", vim.log.levels.INFO)
	return {}
end

function M.export_markdown(_path)
	vim.notify("History export not implemented yet", vim.log.levels.INFO)
end

function M.delete(_conversation_id)
	vim.notify("History delete not implemented yet", vim.log.levels.INFO)
end

return M
