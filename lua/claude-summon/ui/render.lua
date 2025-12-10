-- luacheck: globals vim

local M = {}

function M.setup(_cfg) end

function M.start_stream(_payload) end

function M.on_message(_msg) end

function M.on_error(err)
	local message = (err and (err.message or err.desc)) or "Unknown error"
	vim.notify("Claude error: " .. message, vim.log.levels.ERROR)
end

function M.on_complete() end

function M.on_stop() end

function M.clear() end

function M.apply_code() end

function M.save() end

function M.export() end

return M
