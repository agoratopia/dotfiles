-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- Pick up edits made to a file outside the editor. 'autoread' is already on
-- by default, but it only *acts* when Neovim happens to stat the file —
-- which it does on buffer re-entry or after a shell command, and nothing
-- else. So a buffer you're sitting in while `git pull` runs in another pane
-- stays stale indefinitely. These events force the check.
local autoread = vim.api.nvim_create_augroup("autoread-external-changes", { clear = true })

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "TermClose", "TermLeave" }, {
	desc = "Check whether any open file changed on disk",
	group = autoread,
	callback = function()
		-- :checktime is not safe from cmdline mode or the command-line window
		if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
			vim.cmd("checktime")
		end
	end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	desc = "Don't reload a buffer silently",
	group = autoread,
	callback = function()
		vim.notify("File changed on disk, buffer reloaded", vim.log.levels.WARN)
	end,
})
