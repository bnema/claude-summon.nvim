-- luacheck: globals vim

local M = {}

function M.setup(cfg, api)
	local keys = cfg.keymaps or {}

	local send = function()
		api.send()
	end

	local function map(lhs, rhs, desc)
		if not lhs then
			return
		end
		if type(lhs) == "table" then
			for _, key in ipairs(lhs) do
				map(key, rhs, desc)
			end
			return
		end
		if lhs == "" then
			return
		end
		vim.keymap.set("n", lhs, rhs, { silent = true, noremap = true, desc = desc })
	end

	map(keys.send, send, "Claude send")
	map(keys.open, api.open, "Claude open")
	map(keys.close, api.close, "Claude close")
	map(keys.toggle, api.toggle, "Claude toggle")
end

return M
