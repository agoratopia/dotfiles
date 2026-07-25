local gh = require("config.pack").gh

vim.pack.add({ gh("stevearc/conform.nvim") })

local function format_on_save(bufnr)
	local enabled_filetypes = {
		lua = true,
		go = true,
		python = true,
		rust = true,
		toml = true,
		yaml = true,
	}
	if enabled_filetypes[vim.bo[bufnr].filetype] then
		return { timeout_ms = 500 }
	else
		return nil
	end
end

-- Never reformat on save under the server profile. The files you open on a box
-- you SSH into are usually someone else's, and turning a one-line fix into a
-- whole-file reformat is both rude and hard to review. `<leader>f` still
-- formats on request.
if require("config.profile").server then
	format_on_save = nil
end

require("conform").setup({
	notify_on_error = false,
	format_on_save = format_on_save,
	default_format_opts = {
		lsp_format = "fallback", -- Use external formatters if configured below, otherwise use LSP formatting.
	},
	formatters_by_ft = {
		lua = { "stylua" },
		go = { "goimports", "gofumpt" },
		python = { "ruff_format" },
		rust = { "rustfmt" },
		toml = { "taplo" },
		yaml = { "yamlfmt" },
	},
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true })
end, { desc = "[F]ormat buffer" })
