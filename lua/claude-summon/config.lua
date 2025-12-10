-- luacheck: globals vim

local M = {}

M.defaults = {
	-- SDK
	bin_path = "claude",
	sdk_path = vim.fn.expand("~/projects/claude-code-lua"),

	-- Models
	default_model = "sonnet",
	model_map = {
		["@claude"] = "sonnet",
		["@opus"] = "opus",
		["@sonnet"] = "sonnet",
		["@haiku"] = "haiku",
	},

	-- Context
	context_lines = 20,
	include_related_files = true,

	-- UI
	panel = {
		position = "right",
		width = 0.4,
		border = "rounded",
	},

	-- Keymaps
	keymaps = {
		send = { "<C-CR>", "<leader>as" },
		open = "<leader>ao",
		close = "<leader>ac",
		toggle = "<leader>at",
	},

	-- Persistence
	history_dir = vim.fn.stdpath("data") .. "/claude-summon",
	auto_save = false,
}

local function validate_keymaps(keymaps)
	vim.validate({
		send = { keymaps.send, { "string", "table" }, true },
		open = { keymaps.open, { "string" }, true },
		close = { keymaps.close, { "string" }, true },
		toggle = { keymaps.toggle, { "string" }, true },
	})
end

local function validate_panel(panel)
	vim.validate({
		position = { panel.position, { "string" }, true },
		width = { panel.width, { "number" }, true },
		border = { panel.border, { "string", "table" }, true },
	})
	if panel.width and (panel.width <= 0 or panel.width >= 1) then
		error("claude-summon: panel.width must be between 0 and 1")
	end
end

function M.merge(user_opts)
	local cfg = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})

	vim.validate({
		bin_path = { cfg.bin_path, "string" },
		sdk_path = { cfg.sdk_path, "string" },
		default_model = { cfg.default_model, "string" },
		model_map = { cfg.model_map, "table" },
		context_lines = { cfg.context_lines, "number" },
		include_related_files = { cfg.include_related_files, "boolean" },
		history_dir = { cfg.history_dir, "string" },
		auto_save = { cfg.auto_save, "boolean" },
	})

	validate_panel(cfg.panel or {})
	validate_keymaps(cfg.keymaps or {})

	return cfg
end

return M
