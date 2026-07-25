-- `vim.pack` is Neovim's built-in plugin manager (see `:help vim.pack`).
-- This module holds the shared `gh()` helper and the post-install/update
-- build-step autocmd, since every file under lua/plugins/ needs both.

---Because most plugins are hosted on GitHub, this helper cuts down repetition.
---@param repo string
---@return string
local function gh(repo)
	return "https://github.com/" .. repo
end

local function run_build(name, cmd, cwd)
	local result = vim.system(cmd, { cwd = cwd }):wait()
	if result.code ~= 0 then
		local stderr = result.stderr or ""
		local stdout = result.stdout or ""
		local output = stderr ~= "" and stderr or stdout
		if output == "" then
			output = "No output from build command."
		end
		vim.notify(("Build failed for %s:\n%s"):format(name, output), vim.log.levels.ERROR)
	end
end

-- Runs the appropriate build step after a plugin is installed or updated.
-- See `:help vim.pack-events`
vim.api.nvim_create_autocmd("PackChanged", {
	callback = function(ev)
		local name = ev.data.spec.name
		local kind = ev.data.kind
		if kind ~= "install" and kind ~= "update" then
			return
		end

		if name == "telescope-fzf-native.nvim" and vim.fn.executable("make") == 1 then
			run_build(name, { "make" }, ev.data.path)
			return
		end

		if name == "LuaSnip" then
			if vim.fn.has("win32") ~= 1 and vim.fn.executable("make") == 1 then
				run_build(name, { "make", "install_jsregexp" }, ev.data.path)
			end
			return
		end

		if name == "nvim-treesitter" then
			if not ev.data.active then
				vim.cmd.packadd("nvim-treesitter")
			end
			vim.cmd("TSUpdate")
			return
		end
	end,
})

---Build-time hook for modules that defer `vim.pack.add` until first use.
---
---Lazy loading is right on a workstation, but the portable bundle
---(build-portable.sh) has to contain every plugin up front — on the target
---machine there may be no network to fetch a missing one, and the first
---keypress that needs it would just fail. Setting NVIM_PREFETCH=1 during the
---build forces those modules to load so their plugins get baked in. Nothing
---sets it at normal runtime, so lazy loading is unaffected.
---@param ensure_loaded fun()
local function prefetch(ensure_loaded)
	if vim.env.NVIM_PREFETCH == "1" then
		ensure_loaded()
	end
end

return { gh = gh, prefetch = prefetch }
