local gh = require('config.pack').gh

vim.pack.add { gh 'stevearc/conform.nvim' }
require('conform').setup {
  notify_on_error = false,
  format_on_save = function(bufnr)
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
  end,
  default_format_opts = {
    lsp_format = 'fallback', -- Use external formatters if configured below, otherwise use LSP formatting.
  },
  formatters_by_ft = {
    lua = { 'stylua' },
    go = { 'goimports', 'gofumpt' },
    python = { 'ruff_format' },
    rust = { 'rustfmt' },
    toml = { 'taplo' },
    yaml = { 'yamlfmt' },
  },
}

vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })
