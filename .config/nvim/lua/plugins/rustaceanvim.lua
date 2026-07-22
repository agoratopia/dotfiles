local gh = require('config.pack').gh

-- Richer Rust experience than bare rust_analyzer: cargo runnables via code
-- lens, better hover/inlay hints, macro expansion. Owns its own LSP client
-- (see lsp.lua for why rust_analyzer is absent from the plain server list)
-- and auto-detects the Mason-installed rust-analyzer/codelldb binaries.
-- This plugin's own ftplugin/rust.lua only runs when a .rs buffer opens, so
-- there's no need to defer the vim.pack.add call here.
vim.g.rustaceanvim = {
  server = {
    default_settings = {
      ['rust-analyzer'] = {
        cargo = { allFeatures = true },
        checkOnSave = true,
        check = { command = 'clippy' },
      },
    },
  },
}

vim.pack.add { gh 'mrcjkb/rustaceanvim' }
